import 'package:flutter/material.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class GroupedPage {
  final int pageNumber;
  String customName;
  int orderIndex;

  GroupedPage({
    required this.pageNumber,
    this.customName = '',
    this.orderIndex = 0,
  });

  factory GroupedPage.fromJson(Map<String, dynamic> json) {
    return GroupedPage(
      pageNumber: json['pageNumber'] as int,
      customName: json['customName'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'customName': customName,
      'orderIndex': orderIndex,
    };
  }

  String get displayName =>
      customName.isNotEmpty ? customName : 'Page $pageNumber';
}

enum GroupColorType { solid, gradient }

class GroupColorSettings {
  final GroupColorType type;
  final Color primaryColor;
  final Color? secondaryColor;
  final Color? tertiaryColor;

  GroupColorSettings({
    this.type = GroupColorType.solid,
    this.primaryColor = AppColors.primaryBlue,
    this.secondaryColor,
    this.tertiaryColor,
  });

  factory GroupColorSettings.fromJson(Map<String, dynamic> json) {
    return GroupColorSettings(
      type: GroupColorType.values[json['type'] as int? ?? 0],
      primaryColor:
          Color(json['primaryColor'] as int? ?? AppColors.primaryBlue.value),
      secondaryColor: json['secondaryColor'] != null
          ? Color(json['secondaryColor'] as int)
          : null,
      tertiaryColor: json['tertiaryColor'] != null
          ? Color(json['tertiaryColor'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor?.value,
      'tertiaryColor': tertiaryColor?.value,
    };
  }

  BoxDecoration get decoration {
    if (type == GroupColorType.gradient && secondaryColor != null) {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            secondaryColor!,
            if (tertiaryColor != null) tertiaryColor!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      );
    }
    return BoxDecoration(
      color: primaryColor,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

class PageGroup {
  final String id;
  String name;
  String icon;
  GroupColorSettings colorSettings;
  Color navigationColor;
  List<GroupedPage> pages;
  DateTime createdAt;
  DateTime updatedAt;

  PageGroup({
    required this.id,
    required this.name,
    this.icon = '📁',
    GroupColorSettings? colorSettings,
    Color? navigationColor,
    List<GroupedPage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : colorSettings = colorSettings ?? GroupColorSettings(),
       navigationColor = navigationColor ?? AppColors.primaryBlue,
       pages = pages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PageGroup.fromJson(Map<String, dynamic> json) {
    return PageGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '📁',
      colorSettings: json['colorSettings'] != null
          ? GroupColorSettings.fromJson(
              json['colorSettings'] as Map<String, dynamic>,
            )
          : GroupColorSettings(),
      navigationColor: Color(
        json['navigationColor'] as int? ?? AppColors.primaryBlue.value,
      ),
      pages:
          (json['pages'] as List<dynamic>?)
              ?.map((e) => GroupedPage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorSettings': colorSettings.toJson(),
      'navigationColor': navigationColor.value,
      'pages': pages.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  void addPage(int pageNumber, {String customName = ''}) {
    if (!pages.any((p) => p.pageNumber == pageNumber)) {
      pages.add(
        GroupedPage(
          pageNumber: pageNumber,
          customName: customName,
          orderIndex: pages.length,
        ),
      );
      updatedAt = DateTime.now();
    }
  }

  void addPageRange(int start, int end) {
    for (int i = start; i <= end; i++) {
      addPage(i);
    }
  }

  void removePage(int pageNumber) {
    pages.removeWhere((p) => p.pageNumber == pageNumber);
    _reindexPages();
    updatedAt = DateTime.now();
  }

  void renamePage(int pageNumber, String newName) {
    final page = pages.firstWhere(
      (p) => p.pageNumber == pageNumber,
      orElse: () => GroupedPage(pageNumber: -1),
    );
    if (page.pageNumber != -1) {
      page.customName = newName;
      updatedAt = DateTime.now();
    }
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    _reindexPages();
    updatedAt = DateTime.now();
  }

  void _reindexPages() {
    for (int i = 0; i < pages.length; i++) {
      pages[i].orderIndex = i;
    }
  }

  List<GroupedPage> get sortedPages {
    final sorted = List<GroupedPage>.from(pages);
    sorted.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  List<int> get pageNumbers => sortedPages.map((p) => p.pageNumber).toList();

  bool containsPage(int pageNumber) {
    return pages.any((p) => p.pageNumber == pageNumber);
  }
}

class DocumentGroups {
  final String filePath;
  List<PageGroup> groups;
  String? activeGroupId;

  DocumentGroups({
    required this.filePath,
    List<PageGroup>? groups,
    this.activeGroupId,
  }) : groups = groups ?? [];

  factory DocumentGroups.fromJson(Map<String, dynamic> json) {
    return DocumentGroups(
      filePath: json['filePath'] as String,
      groups:
          (json['groups'] as List<dynamic>?)
              ?.map((e) => PageGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeGroupId: json['activeGroupId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'groups': groups.map((e) => e.toJson()).toList(),
      'activeGroupId': activeGroupId,
    };
  }

  PageGroup? get activeGroup {
    if (activeGroupId == null) return null;
    return groups.cast<PageGroup?>().firstWhere(
      (g) => g?.id == activeGroupId,
      orElse: () => null,
    );
  }

  void addGroup(PageGroup group) {
    groups.add(group);
  }

  void removeGroup(String groupId) {
    groups.removeWhere((g) => g.id == groupId);
    if (activeGroupId == groupId) {
      activeGroupId = null;
    }
  }

  PageGroup? getGroup(String groupId) {
    return groups.cast<PageGroup?>().firstWhere(
      (g) => g?.id == groupId,
      orElse: () => null,
    );
  }
}
