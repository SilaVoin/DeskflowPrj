import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';

final _log = AppLogger.getLogger('AttachmentPreviewScreen');

/// Full-screen attachment preview — images with pinch-to-zoom,
/// files with download button.
class AttachmentPreviewScreen extends StatelessWidget {
  const AttachmentPreviewScreen({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    _log.d('build: fileName=${attachment.fileName}, '
        'isImage=${attachment.isImage}');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attachment.fileName,
              style: DeskflowTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              attachment.formattedSize,
              style: DeskflowTypography.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _downloadFile(context),
            tooltip: 'Скачать',
          ),
        ],
      ),
      body: attachment.isImage
          ? _ImagePreview(url: attachment.url)
          : _FilePreview(attachment: attachment),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    _log.d('_downloadFile: url=${attachment.url}');
    try {
      final uri = Uri.parse(attachment.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть файл')),
          );
        }
      }
    } catch (e) {
      _log.e('_downloadFile: error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

/// Full-screen image with pinch-to-zoom.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            final percent = progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null;
            return Center(
              child: CircularProgressIndicator(
                value: percent,
                color: DeskflowColors.primarySolid,
              ),
            );
          },
          errorBuilder: (_, error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                size: 64,
                color: DeskflowColors.textTertiary,
              ),
              const SizedBox(height: DeskflowSpacing.lg),
              Text(
                'Не удалось загрузить изображение',
                style: DeskflowTypography.body.copyWith(
                  color: DeskflowColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// File preview — icon + download button.
class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(),
              size: 80,
              color: DeskflowColors.primarySolid,
            ),
            const SizedBox(height: DeskflowSpacing.xl),
            Text(
              attachment.fileName,
              style: DeskflowTypography.h2,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DeskflowSpacing.sm),
            Text(
              '${attachment.formattedSize} · ${attachment.mimeType}',
              style: DeskflowTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DeskflowSpacing.xxl),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(attachment.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Скачать файл'),
                style: FilledButton.styleFrom(
                  backgroundColor: DeskflowColors.primarySolid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DeskflowRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final ext = attachment.fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'txt' => Icons.text_snippet_rounded,
      'mp4' || 'mov' || 'avi' => Icons.video_file_rounded,
      'mp3' || 'wav' || 'aac' => Icons.audio_file_rounded,
      'zip' || 'rar' || '7z' => Icons.folder_zip_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}
