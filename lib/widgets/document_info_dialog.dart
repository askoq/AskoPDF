import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class DocumentInfoDialog extends StatelessWidget {
  final String documentTitle;
  final String filePath;
  final int totalPages;
  final List<Size> pageSizes;
  final PdfMetadata? metadata;

  const DocumentInfoDialog({
    super.key,
    required this.documentTitle,
    required this.filePath,
    required this.totalPages,
    required this.pageSizes,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.properties,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(l10n.file, [
                        _buildInfoItem(context, l10n.name, documentTitle),
                        _buildInfoItem(context, l10n.path, filePath),
                        _buildInfoItem(
                          context,
                          l10n.size,
                          metadata != null
                              ? _formatFileSize(metadata!.fileSize)
                              : l10n.unknown,
                        ),
                        if (metadata?.lastModified != null)
                          _buildInfoItem(
                            context,
                            l10n.modified,
                            _formatDateTime(metadata!.lastModified!),
                          ),
                        if (metadata?.lastAccessed != null)
                          _buildInfoItem(
                            context,
                            l10n.accessed,
                            _formatDateTime(metadata!.lastAccessed!),
                            isLast: true,
                          )
                        else
                          _buildInfoItem(
                            context,
                            l10n.modified,
                            metadata?.lastModified != null
                                ? _formatDateTime(metadata!.lastModified!)
                                : l10n.unknown,
                            isLast: true,
                          ),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection(l10n.document, [
                        _buildInfoItem(context, l10n.pagesCount, '$totalPages'),
                        _buildInfoItem(
                          context,
                          l10n.pageSize,
                          _getPageSizeInfo(l10n),
                        ),
                        if (metadata?.pdfVersion != null)
                          _buildInfoItem(
                            context,
                            l10n.pdfVersion,
                            metadata!.pdfVersion!,
                            isLast: true,
                          )
                        else
                          _buildInfoItem(
                            context,
                            l10n.pageSize,
                            _getPageSizeInfo(l10n),
                            isLast: true,
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageSizeInfo(AppLocalizations l10n) {
    if (pageSizes.isEmpty) return l10n.unknown;
    final width = pageSizes.first.width.round();
    final height = pageSizes.first.height.round();
    final pageSizeName = _detectPageSizeName(
      width.toDouble(),
      height.toDouble(),
    );
    if (pageSizeName != null) {
      return '$width × $height pt ($pageSizeName)';
    }
    return '$width × $height pt';
  }

  String? _detectPageSizeName(double width, double height) {
    const tolerance = 5.0;
    final sizes = {
      'A4': [595.0, 842.0],
      'A3': [842.0, 1191.0],
      'A5': [420.0, 595.0],
      'Letter': [612.0, 792.0],
      'Legal': [612.0, 1008.0],
      'Tabloid': [792.0, 1224.0],
    };

    for (var entry in sizes.entries) {
      final w = entry.value[0];
      final h = entry.value[1];
      if ((width - w).abs() < tolerance && (height - h).abs() < tolerance) {
        return entry.key;
      }
      if ((width - h).abs() < tolerance && (height - w).abs() < tolerance) {
        return '${entry.key} (Landscape)';
      }
    }
    return null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    final filteredChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      filteredChildren.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: filteredChildren),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
