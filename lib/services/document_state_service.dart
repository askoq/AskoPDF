import 'dart:ui';
import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/services/document_storage_service.dart';

export 'package:asko_pdf/services/document_storage_service.dart'
    show DocumentState;

class DocumentStateService {
  final DocumentStorageService _storageService = DocumentStorageService();

  Future<DocumentState?> getDocumentStateByIdentifier(
    FileIdentifier identifier,
  ) async {
    return await _storageService.getDocumentState(identifier);
  }

  Future<DocumentState?> getDocumentState(String filePath) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return null;
    return await _storageService.getDocumentState(identifier);
  }

  Future<DocumentData?> getDocumentData(String filePath) async {
    return await _storageService.getDocumentByPath(filePath);
  }

  Future<void> saveDocumentStateByIdentifier(
    FileIdentifier identifier, {
    required int currentPage,
    required double scale,
  }) async {
    await _storageService.saveDocumentState(
      identifier,
      currentPage: currentPage,
      scale: scale,
    );
  }

  Future<void> saveDocumentState(
    String filePath, {
    required int currentPage,
    required double scale,
  }) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;

    await _storageService.saveDocumentState(
      identifier,
      currentPage: currentPage,
      scale: scale,
    );
  }

  Future<void> saveDocumentDetails(
    String filePath, {
    String? customTitle,
    int? totalPages,
    Size? pageSize,
    PdfMetadata? metadata,
  }) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;

    await _storageService.saveDocumentDetails(
      identifier,
      customTitle: customTitle,
      totalPages: totalPages,
      pageWidth: pageSize?.width,
      pageHeight: pageSize?.height,
      metadata: metadata,
    );
  }

  Future<void> removeDocumentState(String filePath) async {}

  Future<void> clearAllStates() async {
    await _storageService.clearAllDocuments();
  }
}
