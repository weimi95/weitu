import 'package:aves/app_mode.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/format.dart';
import 'package:aves/theme/text.dart';
import 'package:aves/utils/file_utils.dart';
import 'package:aves/utils/mime_utils.dart';
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
  final int columnCount;
  final double? cellHeight;
  final ValueNotifier<bool>? isScrollingNotifier;

  const InteractiveTile({
    super.key,
    required this.collection,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.columnCount = 2,
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
          columnCount: columnCount,
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
  final int columnCount;
  final double? cellHeight;
  final bool selectable, highlightable;
  final ValueNotifier<bool>? isScrollingNotifier;
  final Object? Function()? heroTagger;

  // height reserved under the thumbnail for the entry details in a single column
  static const double singleColumnInfoHeight = 52;

  const Tile({
    super.key,
    required this.entry,
    required this.thumbnailExtent,
    required this.tileLayout,
    this.columnCount = 2,
    this.cellHeight,
    this.selectable = false,
    this.highlightable = false,
    this.isScrollingNotifier,
    this.heroTagger,
  });

  @override
  Widget build(BuildContext context) {
    if (columnCount == 1 && tileLayout == TileLayout.grid) return _buildSingleColumnCard(context);

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

  // single column layout: thumbnail on top, entry details underneath
  Widget _buildSingleColumnCard(BuildContext context) {
    final cellHeight = this.cellHeight ?? (thumbnailExtent + singleColumnInfoHeight);
    final imageHeight = cellHeight - singleColumnInfoHeight;
    return SizedBox(
      height: cellHeight,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Expanded(
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
          SizedBox(
            height: singleColumnInfoHeight,
            child: _buildSingleColumnInfo(context),
          ),
        ],
      ),
    );
  }

  // title (falling back to the file name), then date-time, file size and format
  Widget _buildSingleColumnInfo(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final date = entry.bestDate;
    final size = entry.sizeBytes;
    final meta = [
      if (date != null) formatDateTime(date, settings.avesLocale, MediaQuery.alwaysUse24HourFormatOf(context)),
      if (size != null) formatFileSize(settings.avesLocale, size),
      MimeUtils.displayType(entry.mimeType),
    ].join(AText.separator);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // the info block is clipped rather than scrolled when the text does not fit
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Text(
            entry.bestTitle ?? '',
            style: baseStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: metaStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
