import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/theme/format.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/viewer/entry_viewer_page.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class MomentsCard extends StatelessWidget {
  final List<AvesEntry> entries;
  final CollectionSource source;

  const MomentsCard({
    super.key,
    required this.entries,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    final title = first.catalogMetadata?.xmpTitle?.trim() ?? '';
    final description = _mergeDescriptions(entries);
    final theme = Theme.of(context);
    final badge = _formatBadge(first);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            _buildImageArea(context),
            const SizedBox(height: 8),
            Text(
              _formatTime(context, first),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (entries.length == 1) {
      return _buildSingle(entries.first, dpr);
    }
    if (entries.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildCell(context, entries[0], dpr)),
          const SizedBox(width: 6),
          Expanded(child: _buildCell(context, entries[1], dpr)),
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: entries.map((e) => _buildCell(context, e, dpr)).toList(),
    );
  }

  // 1 image: keep original aspect ratio (contain), cap height for portraits
  Widget _buildSingle(AvesEntry e, double dpr) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = e.displayAspectRatio;
        final maxW = constraints.maxWidth;
        final maxH = 360.0;
        double w, h;
        if (ratio >= 1) {
          w = maxW;
          h = maxW / ratio;
        } else {
          h = maxH;
          w = maxH * ratio;
          if (w > maxW) {
            w = maxW;
            h = maxW / ratio;
          }
        }
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: w,
              height: h,
              child: ThumbnailImage(
                entry: e,
                extent: math.max(w, h) * dpr,
                devicePixelRatio: dpr,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  // grid cell: square, cover crop; tap opens the viewer for the whole group
  Widget _buildCell(BuildContext context, AvesEntry e, double dpr) {
    return GestureDetector(
      onTap: () => _openViewer(context, e),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ThumbnailImage(
                entry: e,
                extent: 120 * dpr,
                devicePixelRatio: dpr,
                fit: BoxFit.cover,
              ),
              if (e.isVideo)
                const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, AvesEntry entry) {
    final lens = CollectionLens(
      source: source,
      fixedSelection: List.of(entries),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryViewerPage(
          collection: lens,
          initialEntry: entry,
        ),
      ),
    );
  }

  String _mergeDescriptions(List<AvesEntry> entries) {
    final seen = <String>{};
    final parts = <String>[];
    for (final e in entries) {
      final d = e.catalogMetadata?.xmpDescription?.trim();
      if (d != null && d.isNotEmpty && seen.add(d)) {
        parts.add(d);
      }
    }
    return parts.join('\n');
  }

  String _formatBadge(AvesEntry e) {
    final mime = e.mimeType.toLowerCase();
    const map = {
      'image/jpeg': 'JPG',
      'image/jpg': 'JPG',
      'image/heic': 'HEIC',
      'image/heif': 'HEIF',
      'image/png': 'PNG',
      'image/webp': 'WEBP',
      'image/gif': 'GIF',
      'image/bmp': 'BMP',
      'image/avif': 'AVIF',
      'video/mp4': 'MP4',
      'video/m4v': 'MP4',
      'video/mov': 'MOV',
      'video/3gp': '3GP',
      'video/webm': 'WEBM',
    };
    return map[mime] ?? mime.split('/').last.toUpperCase();
  }

  String _formatTime(BuildContext context, AvesEntry e) {
    final date = e.bestDate ??
        (e.dateModifiedMillis != null ? DateTime.fromMillisecondsSinceEpoch(e.dateModifiedMillis!) : null);
    if (date == null) return '';
    return formatDateTime(date, settings.avesLocale, MediaQuery.alwaysUse24HourFormatOf(context));
  }
}
