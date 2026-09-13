import 'dart:async';

import 'package:aves/app_mode.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/titled.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/widgets/common/basic/draggable_scrollbar/notifications.dart';
import 'package:aves/widgets/common/basic/query_bar.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/moments/moments_card.dart';
import 'package:aves/widgets/navigation/drawer/app_drawer.dart';
import 'package:aves/widgets/navigation/nav_bar/nav_bar.dart';
import 'package:aves/widgets/navigation/nav_bar/tab_swipe.dart';
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
  final ValueNotifier<String> _queryNotifier = ValueNotifier('');
  final StreamController<DraggableScrollbarEvent> _scrollEvents = StreamController.broadcast();

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
    _queryNotifier.dispose();
    _scrollEvents.close();
    _collection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<Settings, bool>(
      selector: (context, s) => s.enableBottomNavigationBar,
      builder: (context, enableBottomNavigationBar, child) {
        final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
        final showBottomNavigationBar = canNavigate && enableBottomNavigationBar;

        return AvesScaffold(
          appBar: AppBar(title: const Text('图记')),
          body: TabSwipeDetector(
            child: Column(
              children: [
                SizedBox(
                  height: QueryBar.getPreferredHeight(MediaQuery.textScalerOf(context)),
                  child: QueryBar(
                    queryNotifier: _queryNotifier,
                    hintText: '搜索图记标题',
                  ),
                ),
                Expanded(
                  child: _buildList(context, showBottomNavigationBar),
                ),
              ],
            ),
          ),
          drawer: canNavigate ? const AppDrawer() : null,
          bottomNavigationBar: showBottomNavigationBar
              ? AppBottomNavBar(
                  events: _scrollEvents.stream,
                )
              : null,
          resizeToAvoidBottomInset: false,
          extendBody: true,
        );
      },
    );
  }

  Widget _buildList(BuildContext context, bool showBottomNavigationBar) {
    final bottomPadding = showBottomNavigationBar
        ? AppBottomNavBar.height + MediaQuery.paddingOf(context).bottom
        : 0.0;
    return ListenableBuilder(
      listenable: Listenable.merge([_collection, _queryNotifier]),
      builder: (context, _) {
        var groups = _group(_collection.sortedEntries);
        final query = _queryNotifier.value;
        if (query.isNotEmpty) {
          final lowerQuery = query.toLowerCase();
          groups = groups
              .where((entries) => _cardTitle(entries).toLowerCase().contains(lowerQuery))
              .toList();
        }
        if (groups.isEmpty) {
          return Center(
            child: Text(
              query.isEmpty
                  ? '还没有图文记录\n给照片加上标题或描述后会出现在这里'
                  : '没有匹配「$query」的图记',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
          itemCount: groups.length,
          itemBuilder: (context, i) => MomentsCard(
            entries: groups[i],
            source: _collection.source,
          ),
        );
      },
    );
  }

  String _cardTitle(List<AvesEntry> entries) {
    return entries.first.catalogMetadata?.xmpTitle?.trim() ?? '';
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
