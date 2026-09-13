import 'package:aves/model/source/section_keys.dart';
import 'package:aves/widgets/common/grid/sections/fixed/row.dart';
import 'package:aves/widgets/common/grid/sections/list_layout.dart';
import 'package:aves/widgets/common/grid/sections/section_layout.dart';
import 'package:aves/widgets/common/grid/sections/section_layout_builder.dart';
import 'package:aves/widgets/common/grid/sections/varied/list_layout.dart';
import 'package:aves/widgets/common/grid/sections/varied/section_layout.dart';
import 'package:flutter/material.dart';

/// Builds section layouts with a per-row extent, resolved from each item
/// (e.g. single column grid cards adapting to the entry aspect ratio).
class VariedExtentSectionLayoutBuilder<T> extends SectionLayoutBuilder<T> {
  final double Function(T item) itemExtentResolver;
  final double minItemExtent, maxItemExtent;

  int _currentIndex = 0;
  double _currentOffset = 0;

  VariedExtentSectionLayoutBuilder({
    required super.sections,
    required super.showHeaders,
    required super.getHeaderExtent,
    required super.buildHeader,
    required super.scrollableWidth,
    required super.tileLayout,
    required super.columnCount,
    required super.spacing,
    required super.horizontalPadding,
    required super.tileWidth,
    required super.tileHeight,
    required super.tileBuilder,
    required super.tileAnimationDelay,
    required this.itemExtentResolver,
    required this.minItemExtent,
    required this.maxItemExtent,
  }) : assert(columnCount == 1);

  @override
  SectionedListLayout<T> updateLayouts(BuildContext context) {
    final sectionLayouts = sections.keys
        .map(
          (sectionKey) => buildSectionLayout(
            headerExtent: showHeaders ? getHeaderExtent(context, sectionKey) : 0.0,
            sectionKey: sectionKey,
            section: sections[sectionKey]!,
            animate: animate,
          ),
        )
        .toList();

    return VariedExtentSectionedListLayout<T>(
      sections: sections,
      showHeaders: showHeaders,
      tileWidth: tileWidth,
      spacing: spacing,
      horizontalPadding: horizontalPadding,
      sectionLayouts: sectionLayouts,
    );
  }

  @override
  SectionLayout buildSectionLayout({
    required double headerExtent,
    required SectionKey sectionKey,
    required List<T> section,
    required bool animate,
  }) {
    final rowExtents = section.map((item) => itemExtentResolver(item).clamp(minItemExtent, maxItemExtent).toDouble()).toList();
    final rowCount = rowExtents.length;
    final sectionChildCount = 1 + rowCount;

    final sectionFirstIndex = _currentIndex;
    _currentIndex += sectionChildCount;
    final sectionLastIndex = _currentIndex - 1;

    final extentsSum = rowExtents.fold(0.0, (a, b) => a + b);
    final sectionMinOffset = _currentOffset;
    _currentOffset += headerExtent + extentsSum + spacing * (rowCount - 1);
    final sectionMaxOffset = _currentOffset;

    return VariedExtentSectionLayout(
      sectionKey: sectionKey,
      firstIndex: sectionFirstIndex,
      lastIndex: sectionLastIndex,
      minOffset: sectionMinOffset,
      maxOffset: sectionMaxOffset,
      headerExtent: headerExtent,
      spacing: spacing,
      rowExtents: rowExtents,
      builder: (context, listIndex) {
        final textDirection = Directionality.of(context);
        final sectionChildIndex = listIndex - sectionFirstIndex;
        final row = sectionChildIndex - 1;
        final rowExtent = row >= 0 && row < rowExtents.length ? rowExtents[row] : 0.0;
        return buildSectionWidget(
          context: context,
          section: section,
          sectionGridIndex: listIndex * columnCount,
          sectionChildIndex: sectionChildIndex,
          itemIndexRange: () => (row, row + 1),
          sectionKey: sectionKey,
          headerExtent: headerExtent,
          itemSizes: [Size(tileWidth, rowExtent)],
          animate: animate,
          buildGridRow: (children) => FixedExtentGridRow(
            width: tileWidth,
            height: rowExtent,
            spacing: spacing,
            textDirection: textDirection,
            children: children,
          ),
        );
      },
    );
  }
}
