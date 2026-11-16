import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/services/document_storage_service.dart';

class PageGroupService {
  final DocumentStorageService _storageService = DocumentStorageService();

  Future<DocumentGroups?> getDocumentGroupsByIdentifier(
    FileIdentifier identifier,
  ) async {
    return await _storageService.getDocumentGroups(identifier);
  }

  Future<DocumentGroups?> getDocumentGroups(String filePath) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return null;
    return await _storageService.getDocumentGroups(identifier);
  }

  Future<void> saveDocumentGroupsByIdentifier(
    FileIdentifier identifier,
    DocumentGroups documentGroups,
  ) async {
    await _storageService.saveDocumentGroups(identifier, documentGroups);
  }

  Future<void> saveDocumentGroups(DocumentGroups documentGroups) async {
    final identifier = await FileIdentifier.fromFile(documentGroups.filePath);
    if (identifier == null) return;
    await _storageService.saveDocumentGroups(identifier, documentGroups);
  }

  Future<void> removeDocumentGroups(String filePath) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;

    final doc = await _storageService.getDocument(identifier);
    if (doc != null) {
      await _storageService.saveDocument(doc.copyWith(setGroupsNull: true));
    }
  }

  Future<PageGroup> createGroup(
    FileIdentifier identifier, {
    required String name,
    String icon = '📁',
  }) async {
    var documentGroups = await getDocumentGroupsByIdentifier(identifier);
    documentGroups ??= DocumentGroups(filePath: identifier.path);

    final group = PageGroup(
      id: '${DateTime.now().millisecondsSinceEpoch}_${documentGroups.groups.length}',
      name: name,
      icon: icon,
    );

    documentGroups.addGroup(group);
    await saveDocumentGroupsByIdentifier(identifier, documentGroups);

    return group;
  }

  Future<PageGroup?> createGroupByPath(
    String filePath, {
    required String name,
    String icon = '📁',
  }) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return null;
    return await createGroup(identifier, name: name, icon: icon);
  }

  Future<void> updateGroup(FileIdentifier identifier, PageGroup group) async {
    final documentGroups = await getDocumentGroupsByIdentifier(identifier);
    if (documentGroups == null) return;

    final index = documentGroups.groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      documentGroups.groups[index] = group;
      await saveDocumentGroupsByIdentifier(identifier, documentGroups);
    }
  }

  Future<void> updateGroupByPath(String filePath, PageGroup group) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;
    await updateGroup(identifier, group);
  }

  Future<void> deleteGroup(FileIdentifier identifier, String groupId) async {
    final documentGroups = await getDocumentGroupsByIdentifier(identifier);
    if (documentGroups == null) return;

    documentGroups.removeGroup(groupId);
    await saveDocumentGroupsByIdentifier(identifier, documentGroups);
  }

  Future<void> deleteGroupByPath(String filePath, String groupId) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;
    await deleteGroup(identifier, groupId);
  }

  Future<void> setActiveGroup(
    FileIdentifier identifier,
    String? groupId,
  ) async {
    var documentGroups = await getDocumentGroupsByIdentifier(identifier);
    documentGroups ??= DocumentGroups(filePath: identifier.path);

    documentGroups.activeGroupId = groupId;
    await saveDocumentGroupsByIdentifier(identifier, documentGroups);
  }

  Future<void> setActiveGroupByPath(String filePath, String? groupId) async {
    final identifier = await FileIdentifier.fromFile(filePath);
    if (identifier == null) return;
    await setActiveGroup(identifier, groupId);
  }

  Future<void> clearAllGroups() async {
    await _storageService.clearAllDocuments();
  }
}
