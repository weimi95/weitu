import 'package:aves/model/source/section_keys.dart';
import 'package:aves/widgets/common/grid/sections/list_layout.dart';
import 'package:aves/widgets/common/grid/sections/varied/section_layout.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Sectioned list layout with per-row extents, used by a single column grid
/// with adaptive card heights.
class VariedExtentSectionedListLayout<T> extends SectionedListLayout<T> {
  final double tileWidth;

  const VariedExtentSectionedListLayout({
    required super.sections,
    required super.showHeaders,
    required this.tileWidth,
    required super.spacing,
    required super.horizontalPadding,
    required super.sectionLayouts,
  });

  @override
  Rect? getTileRect(T item) {
    final MapEntry<SectionKey?, List<T>>? section = sections.entries.firstWhereOrNull((kv) => kv.value.contains(item));
    if (section == null) return null;

    final sectionKey = section.key;
    final sectionLayout = sectionLayouts.firstWhereOrNull((sl) => sl.sectionKey == sectionKey);
    if (sectionLayout is! VariedExtentSectionLayout) return null;

    final row = section.value.indexOf(item);
    if (row < 0 || row >= sectionLayout.rowExtents.length) return null;

    final listIndex = sectionLayout.firstIndex + 1 + row;
    final top = sectionLayout.indexToLayoutOffset(listIndex);
    return Rect.fromLTWH(horizontalPadding, top, tileWidth, sectionLayout.rowExtents[row]);
  }

  @override
  T? getItemAt(Offset position) {
    var dy = position.dy;
    final sectionLayout = getSectionAt(dy);
    if (sectionLayout is! VariedExtentSectionLayout) return null;

    final section = sections[sectionLayout.sectionKey];
    if (section == null) return null;

    dy -= sectionLayout.minOffset + sectionLayout.headerExtent;
    if (dy < 0) return null;

    // last row starting at or above the given offset
    final offsets = sectionLayout.rowOffsets;
    var lo = 0, hi = sectionLayout.rowExtents.length - 1, row = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (offsets[mid] <= dy) {
        row = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (row < 0 || row >= section.length) return null;

    return section[row];
  }
}
