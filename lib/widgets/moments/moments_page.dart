import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/titled.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/widgets/moments/moments_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MomentsPage extends StatefulWidget {
  static const routeName = '/moments';

  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  late final CollectionLens _collection;

  @override
  void initState() {
    super.initState();
    final source = context.read<CollectionSource>();
    _collection = CollectionLens(
      source: source,
      filters: {TitledFilter.instance},
    );
  }

  @override
  void dispose() {
    _collection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图记')),
      body: ListenableBuilder(
        listenable: _collection,
        builder: (context, _) {
          final groups = _group(_collection.sortedEntries);
          if (groups.isEmpty) {
            return const Center(
              child: Text(
                '还没有图文记录\n给照片加上标题或描述后会出现在这里',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groups.length,
            itemBuilder: (context, i) => MomentsCard(
              entries: groups[i],
              source: _collection.source,
            ),
          );
        },
      ),
    );
  }

  // group by (day of best date) + (trimmed lower-cased title)
  // so that same-day entries sharing a title land in one card.
  List<List<AvesEntry>> _group(List<AvesEntry> entries) {
    final sorted = List<AvesEntry>.from(entries)
      ..sort((a, b) => (b.dateModifiedMillis ?? 0).compareTo(a.dateModifiedMillis ?? 0));
    final map = <String, List<AvesEntry>>{};
    for (final e in sorted) {
      final day = _dayKey(e.bestDate ??
          (e.dateModifiedMillis != null ? DateTime.fromMillisecondsSinceEpoch(e.dateModifiedMillis!) : null));
      final title = (e.catalogMetadata?.xmpTitle?.trim() ?? '').toLowerCase();
      final key = '$day|$title';
      (map[key] ??= []).add(e);
    }
    return map.values.toList();
  }

  String _dayKey(DateTime? d) {
    if (d == null) return 'unknown';
    return '${d.year}-${d.month}-${d.day}';
  }
}
