part of '../gelide.dart';

const String _workerOperationOpen = 'open';
const String _workerOperationClose = 'close';
const String _workerOperationRenderPage = 'renderPage';
const String _workerOperationRenderPageSized = 'renderPageSized';
const String _workerOperationRenderTile = 'renderTile';
const String _workerOperationShutdown = 'shutdown';

class _WorkerDocumentDescriptor {
  final int documentId;
  final int pageCount;
  final String? title;
  final String? author;
  final List<PageSize> pageSizes;

  const _WorkerDocumentDescriptor({
    required this.documentId,
    required this.pageCount,
    required this.title,
    required this.author,
    required this.pageSizes,
  });
}

class _GelideWorkerClient {
  final ReceivePort _messages = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exits = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};

  Isolate? _isolate;
  SendPort? _requests;
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<dynamic>? _exitSubscription;
  int _nextRequestId = 1;
  bool _closing = false;
  bool _finished = false;
  Future<void>? _shutdownFuture;

  _GelideWorkerClient._();

  static Future<_GelideWorkerClient> start(String pdfiumPath) async {
    final client = _GelideWorkerClient._();
    client._listen();

    try {
      client._isolate = await Isolate.spawn<Map<String, Object?>>(
        _gelideWorkerMain,
        <String, Object?>{
          'replyPort': client._messages.sendPort,
          'pdfiumPath': pdfiumPath,
        },
        onError: client._errors.sendPort,
        onExit: client._exits.sendPort,
        errorsAreFatal: true,
        debugName: 'gelide-pdf-worker',
      );
      client._requests = await client._ready.future;
      return client;
    } catch (_) {
      client._isolate?.kill(priority: Isolate.immediate);
      client._finish(StateError('Gelide worker failed to start'));
      rethrow;
    }
  }

  void _listen() {
    _messageSubscription = _messages.listen(_handleMessage);
    _errorSubscription = _errors.listen(_handleIsolateError);
    _exitSubscription = _exits.listen((dynamic _) {
      if (_finished) return;
      final error = _closing
          ? StateError('Gelide worker stopped during shutdown')
          : StateError('Gelide worker stopped unexpectedly');
      if (!_ready.isCompleted) {
        _ready.completeError(error, StackTrace.current);
      }
      _finish(error);
    });
  }

  void _handleMessage(dynamic rawMessage) {
    if (rawMessage is! Map) return;
    final message = rawMessage.cast<Object?, Object?>();
    final event = message['event'];

    if (event == 'ready') {
      final port = message['port'];
      if (port is SendPort && !_ready.isCompleted) {
        _ready.complete(port);
      }
      return;
    }

    if (event == 'startupError') {
      final error = StateError(
        message['error']?.toString() ?? 'Gelide worker failed to start',
      );
      final stack = StackTrace.fromString(message['stack']?.toString() ?? '');
      if (!_ready.isCompleted) {
        _ready.completeError(error, stack);
      }
      _finish(error, stack);
      return;
    }

    final requestId = message['requestId'];
    if (requestId is! int) return;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) return;

    if (message['ok'] == true) {
      completer.complete(message['result']);
      return;
    }

    final error = message['errorType'] == 'documentOpen'
        ? GelideNativeOpenException(
            path: message['path']?.toString() ?? '',
            details:
                message['error']?.toString() ?? 'Failed to open PDF document',
            issue: GelideNativeOpenIssue.values.firstWhere(
              (issue) => issue.name == message['openIssue'],
              orElse: () => GelideNativeOpenIssue.unknown,
            ),
          )
        : StateError(
            message['error']?.toString() ?? 'Gelide worker operation failed',
          );
    final stack = StackTrace.fromString(message['stack']?.toString() ?? '');
    completer.completeError(error, stack);
  }

  void _handleIsolateError(dynamic rawError) {
    Object error = StateError('Gelide worker failed');
    StackTrace? stack;
    if (rawError is List && rawError.isNotEmpty) {
      error = StateError(rawError.first.toString());
      if (rawError.length > 1) {
        stack = StackTrace.fromString(rawError[1].toString());
      }
    }

    if (!_ready.isCompleted) {
      _ready.completeError(error, stack ?? StackTrace.current);
    }
    _finish(error, stack);
  }

  Future<Object?> _request(
    String operation, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) {
    if (_closing || _finished || _requests == null) {
      return Future<Object?>.error(
        StateError('Gelide worker is not available'),
      );
    }
    return _sendRequest(operation, payload);
  }

  Future<Object?> _sendRequest(
    String operation,
    Map<String, Object?> payload,
  ) {
    final requestId = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[requestId] = completer;
    _requests!.send(<String, Object?>{
      'requestId': requestId,
      'operation': operation,
      ...payload,
    });
    return completer.future;
  }

  Future<_WorkerDocumentDescriptor> openDocument(
    String path, {
    String? password,
  }) async {
    final rawResult = await _request(
      _workerOperationOpen,
      <String, Object?>{'path': path, 'password': password},
    );
    final result = (rawResult as Map).cast<Object?, Object?>();
    final rawSizes = result['pageSizes'] as List<dynamic>? ?? const <dynamic>[];
    return _WorkerDocumentDescriptor(
      documentId: result['documentId']! as int,
      pageCount: result['pageCount']! as int,
      title: result['title'] as String?,
      author: result['author'] as String?,
      pageSizes: rawSizes.map((dynamic rawSize) {
        final size = rawSize as List<dynamic>;
        return PageSize(
          width: (size[0] as num).toDouble(),
          height: (size[1] as num).toDouble(),
          rotation: size[2] as int,
        );
      }).toList(growable: false),
    );
  }

  Future<void> closeDocument(int documentId) async {
    await _request(
      _workerOperationClose,
      <String, Object?>{'documentId': documentId},
    );
  }

  Future<_RenderedBytes> renderPage(
    int documentId,
    int pageIndex,
    double dpi,
  ) async {
    final result = await _request(
      _workerOperationRenderPage,
      <String, Object?>{
        'documentId': documentId,
        'pageIndex': pageIndex,
        'dpi': dpi,
      },
    );
    return _decodeRenderedBytes(result);
  }

  Future<_RenderedBytes> renderPageSized(
    int documentId,
    int pageIndex,
    int width,
    int height,
  ) async {
    final result = await _request(
      _workerOperationRenderPageSized,
      <String, Object?>{
        'documentId': documentId,
        'pageIndex': pageIndex,
        'width': width,
        'height': height,
      },
    );
    return _decodeRenderedBytes(result);
  }

  Future<_RenderedBytes> renderTile(
    int documentId, {
    required int pageIndex,
    required int x,
    required int y,
    required int width,
    required int height,
    required int fullWidth,
    required int fullHeight,
  }) async {
    final result = await _request(
      _workerOperationRenderTile,
      <String, Object?>{
        'documentId': documentId,
        'pageIndex': pageIndex,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fullWidth': fullWidth,
        'fullHeight': fullHeight,
      },
    );
    return _decodeRenderedBytes(result);
  }

  Future<void> shutdown() {
    final existing = _shutdownFuture;
    if (existing != null) return existing;
    if (_finished || _requests == null) {
      return Future<void>.value();
    }

    final request = _sendRequest(
      _workerOperationShutdown,
      const <String, Object?>{},
    );
    _closing = true;
    final future = request.then<void>((Object? _) {}).whenComplete(() {
      _finish(null);
    });
    _shutdownFuture = future;
    return future;
  }

  _RenderedBytes _decodeRenderedBytes(Object? rawResult) {
    final result = (rawResult as Map).cast<Object?, Object?>();
    final data = result['data'] as TransferableTypedData;
    return _RenderedBytes(
      data.materialize().asUint8List(),
      result['width']! as int,
      result['height']! as int,
    );
  }

  void _finish([Object? error, StackTrace? stack]) {
    if (_finished) return;
    _finished = true;
    _requests = null;

    final completionError = error ??
        StateError('Gelide worker stopped before completing the operation');
    final effectiveStack = stack ?? StackTrace.current;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(completionError, effectiveStack);
      }
    }
    _pending.clear();

    _messages.close();
    _errors.close();
    _exits.close();
    unawaited(_messageSubscription?.cancel() ?? Future<void>.value());
    unawaited(_errorSubscription?.cancel() ?? Future<void>.value());
    unawaited(_exitSubscription?.cancel() ?? Future<void>.value());
  }
}

@pragma('vm:entry-point')
Future<void> _gelideWorkerMain(Map<String, Object?> bootstrap) async {
  final replyPort = bootstrap['replyPort']! as SendPort;
  final pdfiumPath = bootstrap['pdfiumPath']! as String;
  final requests = ReceivePort();
  final engine = _GelideEngine();
  final documents = <int, _GelideDocument>{};
  var nextDocumentId = 1;

  try {
    await engine.init(pdfiumPath);
  } catch (error, stack) {
    engine.dispose();
    replyPort.send(<String, Object?>{
      'event': 'startupError',
      'error': error.toString(),
      'stack': stack.toString(),
    });
    Isolate.exit();
  }

  replyPort.send(<String, Object?>{
    'event': 'ready',
    'port': requests.sendPort,
  });

  Future<void> queue = Future<void>.value();
  requests.listen((dynamic rawMessage) {
    queue = queue.then((_) async {
      if (rawMessage is! Map) return;
      final message = rawMessage.cast<Object?, Object?>();
      final requestId = message['requestId'];
      if (requestId is! int) return;

      try {
        final operation = message['operation'];
        final documentId = message['documentId'];
        final document = documentId is int ? documents[documentId] : null;

        Object? result;
        switch (operation) {
          case _workerOperationOpen:
            final opened = engine.openDocument(
              message['path']! as String,
              password: message['password'] as String?,
            );
            try {
              final pageCount = opened.pageCount;
              final pageSizes = opened.getPageInfos();
              final title = opened.title;
              final author = opened.author;
              final newDocumentId = nextDocumentId++;
              documents[newDocumentId] = opened;
              result = <String, Object?>{
                'documentId': newDocumentId,
                'pageCount': pageCount,
                'title': title,
                'author': author,
                'pageSizes': pageSizes
                    .map((size) => <Object?>[
                          size.width,
                          size.height,
                          size.rotation,
                        ])
                    .toList(growable: false),
              };
            } catch (_) {
              opened.close();
              rethrow;
            }
            break;
          case _workerOperationClose:
            if (documentId is! int) {
              throw ArgumentError('Missing document id');
            }
            documents.remove(documentId)?.close();
            break;
          case _workerOperationRenderPage:
            final rendered = await _requireWorkerDocument(document)._renderPage(
              message['pageIndex']! as int,
              (message['dpi']! as num).toDouble(),
            );
            result = _encodeRenderedBytes(rendered);
            break;
          case _workerOperationRenderPageSized:
            final rendered =
                await _requireWorkerDocument(document)._renderPageSized(
              message['pageIndex']! as int,
              message['width']! as int,
              message['height']! as int,
            );
            result = _encodeRenderedBytes(rendered);
            break;
          case _workerOperationRenderTile:
            final rendered = await _requireWorkerDocument(document)._renderTile(
              message['pageIndex']! as int,
              message['x']! as int,
              message['y']! as int,
              message['width']! as int,
              message['height']! as int,
              message['fullWidth']! as int,
              message['fullHeight']! as int,
            );
            result = _encodeRenderedBytes(rendered);
            break;
          case _workerOperationShutdown:
            requests.close();
            for (final openDocument in documents.values) {
              openDocument.close();
            }
            documents.clear();
            engine.dispose();
            replyPort.send(<String, Object?>{
              'requestId': requestId,
              'ok': true,
              'result': null,
            });
            Isolate.exit();
          default:
            throw UnsupportedError(
              'Unknown Gelide worker operation: $operation',
            );
        }

        replyPort.send(<String, Object?>{
          'requestId': requestId,
          'ok': true,
          'result': result,
        });
      } catch (error, stack) {
        replyPort.send(<String, Object?>{
          'requestId': requestId,
          'ok': false,
          'error': error.toString(),
          'stack': stack.toString(),
          if (error is GelideNativeOpenException) ...<String, Object?>{
            'errorType': 'documentOpen',
            'path': error.path,
            'openIssue': error.issue.name,
          },
        });
      }
    });
  });
}

_GelideDocument _requireWorkerDocument(_GelideDocument? document) {
  if (document == null) {
    throw StateError('Gelide worker document is closed');
  }
  return document;
}

Map<String, Object?> _encodeRenderedBytes(_RenderedBytes rendered) {
  return <String, Object?>{
    'data': TransferableTypedData.fromList(<Uint8List>[rendered.data]),
    'width': rendered.width,
    'height': rendered.height,
  };
}
