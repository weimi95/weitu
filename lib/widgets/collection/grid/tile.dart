import 'package:aves/app_mode.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/format.dart';
import 'package:aves/utils/file_utils.dart';
import 'package:aves/model/selection.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/services/intent_service.dart';
import 'package:aves/widgets/collection/grid/list_details.dart';
import 'package:aves/widgets/collection/grid/list_details_theme.dart';
import 'package:aves/widgets/common/grid/scaling.dart';
import 'package:aves/widgets/common/providers/viewer_entry_provider.dart';
import 'package:aves/widgets/common/thumbnail/decorated.dart';
import 'package:aves/widgets/common/thumbnail/notifications.dart';
import 'package:aves/widgets/viewer/hero.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InteractiveTile extends StatelessWidget {
  final CollectionLens collection;
  final AvesEntry entry;
  final double thumbnailExtent;
  final TileLayout tileLayout;
  final int infoLevel;
  final double? cellHeight;
  final ValueNotifier<bool>? isScrollingNotifier;

  const InteractiveTile({
    super.key,
    required this.collection,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.infoLevel = 0,
    this.cellHeight,
    this.isScrollingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final appMode = context.read<ValueNotifier<AppMode>>().value;
        switch (appMode) {
          case .main:
            final selection = context.read<Selection<AvesEntry>>();
            if (selection.isSelecting) {
              selection.toggleSelection(entry);
            } else {
              OpenViewerNotification(entry).dispatch(context);
            }
          case .pickSingleMediaExternal:
            IntentService.submitPickedItems([entry.uri]);
          case .pickMultipleMediaExternal:
            final selection = context.read<Selection<AvesEntry>>();
            selection.toggleSelection(entry);
          case .pickFilteredMediaInternal:
          case .pickUnfilteredMediaInternal:
            Navigator.maybeOf(context)?.pop<AvesEntry>(entry);
          default:
            break;
        }
      },
      child: MetaData(
        metaData: ScalerMetadata(entry),
        child: Tile(
          entry: entry,
          thumbnailExtent: thumbnailExtent,
          tileLayout: tileLayout,
          infoLevel: infoLevel,
          cellHeight: cellHeight,
          selectable: true,
          highlightable: true,
          isScrollingNotifier: isScrollingNotifier,
          heroTagger: () => EntryHeroInfo(collection, entry).tag,
        ),
      ),
    );
  }
}

class Tile extends StatelessWidget {
  final AvesEntry entry;
  final double thumbnailExtent;
  final TileLayout tileLayout;
  final int infoLevel;
  final double? cellHeight;
  final bool selectable, highlightable;
  final ValueNotifier<bool>? isScrollingNotifier;
  final Object? Function()? heroTagger;

  const Tile({
    super.key,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.infoLevel = 0,
    this.cellHeight,
    this.selectable = false,
    this.highlightable = false,
    this.isScrollingNotifier,
    this.heroTagger,
  });

  @override
  Widget build(BuildContext context) {
    if (infoLevel >= 1) return _buildCard(context);

    switch (tileLayout) {
      case .mosaic:
      case .grid:
        return _buildThumbnail();
      case .list:
        return Row(
          crossAxisAlignment: .stretch,
          children: [
            SizedBox.square(
              dimension: context.select<EntryListDetailsThemeData, double>((v) => v.extent),
              child: _buildThumbnail(),
            ),
            Expanded(
              child: EntryListDetails(
                entry: entry,
              ),
            ),
          ],
        );
    }
  }

  // info card layout: image on top (scaled to leave room for text), details below
  // level 1: 2-column card with title (large) + description (small)
  // level 2: 1-column card with title + description + tags + format + date-time + file size
  Widget _buildCard(BuildContext context) {
    final isLarge = infoLevel == 2;
    final cellHeight = this.cellHeight ?? thumbnailExtent;
    final infoHeight = isLarge ? cellHeight * 0.35 : thumbnailExtent * 0.3;
    final imageHeight = cellHeight - infoHeight;
    final description = entry.catalogMetadata?.xmpDescription?.isNotEmpty == true ? entry.catalogMetadata!.xmpDescription : null;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SizedBox(
          width: thumbnailExtent,
          height: imageHeight,
          child: DecoratedThumbnail(
            entry: entry,
            tileExtent: imageHeight,
            fitWidth: thumbnailExtent,
            isMosaic: false,
            fit: BoxFit.contain,
            selectable: selectable,
            highlightable: highlightable,
            heroTagger: heroTagger,
            heroPlaceholderBuilder: (context, heroSize, child) => child,
            cancellableNotifier: isScrollingNotifier,
          ),
        ),
        Container(
          height: infoHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildCardInfo(context, isLarge, description),
        ),
      ],
    );
  }

  Widget _buildCardInfo(BuildContext context, bool isLarge, String? description) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final titleStyle = baseStyle.copyWith(
      fontSize: isLarge ? 15 : 13,
      fontWeight: FontWeight.w600,
    );
    final descStyle = baseStyle.copyWith(
      fontSize: isLarge ? 13 : 11,
      color: Theme.of(context).hintColor,
    );

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Text(
          entry.bestTitle ?? '',
          style: titleStyle,
          maxLines: isLarge ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: descStyle,
            maxLines: isLarge ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (isLarge) ..._buildLargeMeta(context),
      ],
    );
  }

  List<Widget> _buildLargeMeta(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall!.copyWith(color: theme.hintColor);
    final widgets = <Widget>[];

    final tags = entry.tags;
    if (tags?.isNotEmpty == true) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final tag in tags!)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tag, style: captionStyle),
                ),
            ],
          ),
        ),
      );
    }

    final metaRows = <String>[];
    if (entry.mimeType != null) metaRows.add(entry.mimeType!);
    final date = entry.bestDate;
    if (date != null) metaRows.add(formatDateTime(date, settings.avesLocale, MediaQuery.alwaysUse24HourFormatOf(context)));
    final size = entry.sizeBytes;
    if (size != null) metaRows.add(formatFileSize(settings.avesLocale, size));
    if (metaRows.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            metaRows.join('  •  '),
            style: captionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildThumbnail() => DecoratedThumbnail(
    entry: entry,
    tileExtent: thumbnailExtent,
    isMosaic: tileLayout == TileLayout.mosaic,
    // when the user is scrolling faster than we can retrieve the thumbnails,
    // the retrieval task queue can pile up for thumbnails that got disposed
    // in this case we pause the image retrieval task to get it out of the queue
    cancellableNotifier: isScrollingNotifier,
    selectable: selectable,
    highlightable: highlightable,
    heroTagger: heroTagger,
    // do not use a hero placeholder but hide the thumbnail matching the viewer entry,
    // so that it can hero out on an entry and come back with a hero to a different entry
    heroPlaceholderBuilder: (context, heroSize, child) => child,
    imageDecorator: (context, child) {
      return Selector<ViewerEntryNotifier, bool>(
        selector: (context, v) => v.value == entry,
        builder: (context, isViewerEntry, child) {
          return Visibility.maintain(
            visible: !isViewerEntry,
            child: child!,
          );
        },
        child: child,
      );
    },
  );
}
