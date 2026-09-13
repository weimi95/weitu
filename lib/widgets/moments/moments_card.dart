import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/format.dart';
import 'package:aves/utils/mime_utils.dart';
import 'package:aves/widgets/common/behaviour/routes.dart';
import 'package:aves/widgets/common/providers/viewer_entry_provider.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/viewer/entry_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final badge = _formatBadge(entries);

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // `ThumbnailImage.extent` is in logical pixels (it is forwarded as `widthDip`/`heightDip`),
        // so the cell size is passed as-is and the device pixel ratio is passed separately
        final areaWidth = constraints.maxWidth;
        if (entries.length == 1) {
          return _buildSingle(entries.first, dpr);
        }
        if (entries.length == 2) {
          final cellExtent = (areaWidth - 6) / 2;
          return Row(
            children: [
              Expanded(child: _buildCell(context, entries[0], cellExtent, dpr)),
              const SizedBox(width: 6),
              Expanded(child: _buildCell(context, entries[1], cellExtent, dpr)),
            ],
          );
        }
        final cellExtent = (areaWidth - 12) / 3;
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: entries.map((e) => _buildCell(context, e, cellExtent, dpr)).toList(),
        );
      },
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
            child: GestureDetector(
              onTap: () => _openViewer(context, e),
              child: SizedBox(
                width: w,
                height: h,
                child: ThumbnailImage(
                  entry: e,
                  extent: math.max(w, h),
                  devicePixelRatio: dpr,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // grid cell: square, cover crop; tap opens the viewer for the whole group
  Widget _buildCell(BuildContext context, AvesEntry e, double cellExtent, double dpr) {
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
                extent: cellExtent,
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

  Future<void> _openViewer(BuildContext context, AvesEntry entry) async {
    // track viewer entry for dynamic hero placeholder (cf collection_grid._goToViewer)
    final viewerEntryNotifier = context.read<ViewerEntryNotifier>();

    // prevent navigating again to the same entry until fully back,
    // as a workaround for the hero pop/push diversion animation issue
    if (viewerEntryNotifier.value == entry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => viewerEntryNotifier.value = entry);

    final lens = CollectionLens(
      source: source,
      fixedSelection: List.of(entries),
    );
    await Navigator.maybeOf(context)?.push(
      TransparentMaterialPageRoute(
        settings: const RouteSettings(name: EntryViewerPage.routeName),
        pageBuilder: (context, a, sa) => EntryViewerPage(
          collection: lens.copyWith(listenToSource: false),
          initialEntry: entry,
        ),
      ),
    );

    // reset track viewer entry
    if (settings.animate) {
      await Future.delayed(ADurations.pageTransitionExact);
    }
    viewerEntryNotifier.value = null;
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

  // a card may mix several formats: list the distinct ones (up to 3), then fold the rest into `+N`
  String _formatBadge(List<AvesEntry> entries) {
    final labels = <String>{};
    for (final e in entries) {
      labels.add(MimeUtils.displayType(e.mimeType));
    }
    if (labels.length <= 3) return labels.join('+');
    return '${labels.take(3).join('+')}+${labels.length - 3}';
  }

  String _formatTime(BuildContext context, AvesEntry e) {
    final date = e.bestDate ??
        (e.dateModifiedMillis != null ? DateTime.fromMillisecondsSinceEpoch(e.dateModifiedMillis!) : null);
    if (date == null) return '';
    return formatDateTime(date, settings.avesLocale, MediaQuery.alwaysUse24HourFormatOf(context));
  }
}
