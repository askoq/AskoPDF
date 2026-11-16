import 'dart:math';

class ProjectDocument {
  final String id;
  final String filePath;
  String customTabName;
  int orderIndex;

  ProjectDocument({
    String? id,
    required this.filePath,
    this.customTabName = '',
    this.orderIndex = 0,
  }) : id =
           id ??
           '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

  String get fileName {
    final parts = filePath.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : filePath;
  }

  String get displayName => customTabName.isNotEmpty ? customTabName : fileName;

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      customTabName: json['customTabName'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'customTabName': customTabName,
      'orderIndex': orderIndex,
    };
  }

  ProjectDocument copyWith({
    String? id,
    String? filePath,
    String? customTabName,
    int? orderIndex,
  }) {
    return ProjectDocument(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      customTabName: customTabName ?? this.customTabName,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectDocument &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Project {
  final String id;
  String name;
  List<ProjectDocument> documents;
  DateTime createdAt;
  DateTime lastOpenedAt;

  Project({
    String? id,
    required this.name,
    List<ProjectDocument>? documents,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  }) : id =
           id ??
           '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
       documents = documents ?? [],
       createdAt = createdAt ?? DateTime.now(),
       lastOpenedAt = lastOpenedAt ?? DateTime.now();

  int get documentCount => documents.length;

  List<ProjectDocument> get sortedDocuments {
    final sorted = List<ProjectDocument>.from(documents);
    sorted.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  void addDocument(String filePath, {String customTabName = ''}) {
    if (!documents.any((d) => d.filePath == filePath)) {
      documents.add(
        ProjectDocument(
          filePath: filePath,
          customTabName: customTabName,
          orderIndex: documents.length,
        ),
      );
    }
  }

  void removeDocument(String filePath) {
    documents.removeWhere((d) => d.filePath == filePath);
    _reindexDocuments();
  }

  void removeDocumentById(String documentId) {
    documents.removeWhere((d) => d.id == documentId);
    _reindexDocuments();
  }

  void updateDocumentName(String filePath, String newName) {
    final doc = documents.firstWhere(
      (d) => d.filePath == filePath,
      orElse: () => ProjectDocument(filePath: ''),
    );
    if (doc.filePath.isNotEmpty) {
      doc.customTabName = newName;
    }
  }

  void reorderDocuments(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final doc = documents.removeAt(oldIndex);
    documents.insert(newIndex, doc);
    _reindexDocuments();
  }

  void _reindexDocuments() {
    for (int i = 0; i < documents.length; i++) {
      documents[i].orderIndex = i;
    }
  }

  ProjectDocument? getDocumentByPath(String filePath) {
    try {
      return documents.firstWhere((d) => d.filePath == filePath);
    } catch (_) {
      return null;
    }
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      documents:
          (json['documents'] as List<dynamic>?)
              ?.map((e) => ProjectDocument.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.parse(json['lastOpenedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'documents': documents.map((d) => d.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    List<ProjectDocument>? documents,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      documents: documents ?? List<ProjectDocument>.from(this.documents),
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
