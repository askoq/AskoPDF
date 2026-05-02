import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const MaterialApp(home: PdfViewer()));

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});
  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

typedef _PageData = ({Uint8List b, double w, double h});

class _PdfViewerState extends State<PdfViewer> {
  PdfDocument? _doc;
  String _title = '';
  double _docW = 0;
  final _cache = <int, Future<_PageData>>{};
  bool _loading = false;
  double _scale = 1.0;

  Future<void> _open() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (res?.files.single.path == null) return;

    setState(() => _loading = true);
    final doc = await PdfDocument.openFile(res!.files.single.path!);
    final p1 = await doc.getPage(1);
    
    setState(() { _doc = doc; _docW = p1.width; _title = res.files.single.name; _cache.clear(); _loading = false; });
    await p1.close();
  }

  Future<_PageData> _loadPage(int i) => _cache.putIfAbsent(i, () async {
    final p = await _doc!.getPage(i + 1);
    final img = await p.render(width: p.width * 2, height: p.height * 2);
    await p.close();
    return (b: img!.bytes, w: p.width, h: p.height);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF525659),
      appBar: _doc == null ? null : AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 16)),
        actions: [
          Center(child: Text('${(_scale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold))),
          PopupMenuButton<double>(
            icon: const Icon(Icons.zoom_in),
            onSelected: (v) => setState(() => _scale = v),
            itemBuilder: (_) => [0.5, 1.0, 1.5].map((v) => PopupMenuItem(value: v, child: Text('${(v * 100).toInt()}%'))).toList(),
          ),
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _open),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doc == null
              ? Center(child: ElevatedButton(onPressed: _open, child: const Text('Open PDF')))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (_docW * _scale + 96).clamp(MediaQuery.of(context).size.width, double.infinity),
                    child: ListView.builder(
                      itemCount: _doc!.pagesCount,
                      itemBuilder: (_, i) => FutureBuilder<_PageData>(
                        future: _loadPage(i),
                        builder: (_, snap) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(children: [
                            Card(
                              elevation: 6, shadowColor: Colors.black54,
                              child: snap.data == null 
                                ? SizedBox(width: _docW * _scale, height: _docW * 1.4 * _scale, child: const Center(child: CircularProgressIndicator()))
                                : Image.memory(snap.data!.b, width: snap.data!.w * _scale, height: snap.data!.h * _scale),
                            ),
                            const SizedBox(height: 6),
                            Text('${i + 1} / ${_doc!.pagesCount}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
