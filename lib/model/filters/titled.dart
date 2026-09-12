import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';

class TitledFilter extends CollectionFilter {
  static const type = 'titled';

  static bool _test(AvesEntry entry) {
    final title = entry.catalogMetadata?.xmpTitle?.trim() ?? '';
    final description = entry.catalogMetadata?.xmpDescription?.trim() ?? '';
    return title.isNotEmpty || description.isNotEmpty;
  }

  static const instance = TitledFilter._private();

  @override
  List<Object?> get props => [reversed];

  const TitledFilter._private({super.reversed = false});

  factory TitledFilter.fromMap(Map<String, Object?> json) => instance;

  @override
  Map<String, Object?> toJsonMap() => {
        'type': type,
      };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => type;

  @override
  String getLabel(BuildContext context) => '图记';

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) => Icon(Icons.notes, size: size);

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed';
}
