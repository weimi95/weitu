import 'package:aves/model/source/section_keys.dart';
import 'package:aves/widgets/common/grid/sections/section_layout.dart';
import 'package:flutter/material.dart';

/// A section layout where each row has its own known extent,
/// e.g. a single column grid with adaptive card heights.
class VariedExtentSectionLayout extends SectionLayout {
  final List<double> rowExtents;

  // layout offset of each row, plus a trailing entry (== maxOffset)
  final List<double> rowOffsets;

  @override
  List<Object?> get props => [...super.props, rowExtents];

  VariedExtentSectionLayout({
    required super.sectionKey,
    required super.firstIndex,
    required super.lastIndex,
    required super.minOffset,
    required super.maxOffset,
    required super.headerExtent,
    required super.spacing,
    required super.builder,
    required this.rowExtents,
  }) : rowOffsets = _computeRowOffsets(rowExtents, minOffset + headerExtent, spacing);

  static List<double> _computeRowOffsets(List<double> extents, double start, double spacing) {
    final offsets = List<double>.filled(extents.length + 1, 0);
    var offset = start;
    for (var i = 0; i < extents.length; i++) {
      offsets[i] = offset;
      offset += extents[i] + spacing;
    }
    offsets[extents.length] = extents.isEmpty ? start : offset - spacing;
    return offsets;
  }

  int _rowAt(double offset) {
    // last row whose start offset is <= the given offset
    var lo = 0, hi = rowExtents.length - 1, res = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (rowOffsets[mid] <= offset) {
        res = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return res;
  }

  int _rowBefore(double offset) {
    // last row whose start offset is strictly below the given offset
    var lo = 0, hi = rowExtents.length - 1, res = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (rowOffsets[mid] < offset) {
        res = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return res;
  }

  @override
  double indexToLayoutOffset(int index) {
    index -= bodyFirstIndex;
    if (index < 0) return minOffset;
    if (index >= rowExtents.length) return maxOffset + spacing;
    return rowOffsets[index];
  }

  @override
  double indexToMainAxisExtent(int index) {
    index -= bodyFirstIndex;
    if (index < 0) return headerExtent;
    if (index >= rowExtents.length) return spacing;
    return rowExtents[index];
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    scrollOffset -= bodyMinOffset;
    if (!scrollOffset.isFinite || scrollOffset < 0) return firstIndex;
    if (rowExtents.isEmpty) return lastIndex;
    final row = _rowAt(scrollOffset);
    return row < 0 ? firstIndex : bodyFirstIndex + row;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    scrollOffset -= bodyMinOffset;
    if (!scrollOffset.isFinite || scrollOffset < 0) return firstIndex;
    if (rowExtents.isEmpty) return lastIndex;
    final row = _rowBefore(scrollOffset);
    return row < 0 ? firstIndex : bodyFirstIndex + row;
  }
}
