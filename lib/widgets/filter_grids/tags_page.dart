import 'package:aves/locale/calendar/calendar_utils.dart';
import 'package:aves/model/dynamic_albums.dart';
import 'package:aves/model/filters/aspect_ratio.dart';
import 'package:aves/model/filters/container/dynamic_album.dart';
import 'package:aves/model/filters/covered/tag.dart';
import 'package:aves/model/filters/container/tag_group.dart';
import 'package:aves/model/filters/covered/location.dart';
import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/date.dart';
import 'package:aves/model/filters/favourite.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/mime.dart';
import 'package:aves/model/filters/missing.dart';
import 'package:aves/model/filters/rating.dart';
import 'package:aves/model/filters/recent.dart';
import 'package:aves/model/filters/type.dart';
import 'package:aves/model/filters/weekday.dart';
import 'package:aves/model/grouping/common.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/album.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/location/country.dart';
import 'package:aves/model/source/location/place.dart';
import 'package:aves/model/source/tag.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/action_mixins/vault_aware.dart';
import 'package:aves/widgets/common/expandable_filter_row.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/aves_filter_chip.dart';
import 'package:aves/widgets/common/identity/empty.dart';
import 'package:aves/widgets/common/providers/filter_group_provider.dart';
import 'package:aves/widgets/filter_grids/common/action_delegates/tag_set.dart';
import 'package:aves/widgets/filter_grids/common/enums.dart';
import 'package:aves/widgets/filter_grids/common/filter_nav_page.dart';
import 'package:aves/widgets/filter_grids/common/section_keys.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TagListPage extends StatefulWidget {
  static const routeName = '/tags';

  final Uri? initialGroup;

  const TagListPage({
    super.key,
    required this.initialGroup,
  });

  @override
  State<TagListPage> createState() => _TagListPageState();

  // common with picking page

  static List<FilterGridItem<TagBaseFilter>> getGridItems(
    CollectionSource source,
    Set<ChipType> chipTypes,
    Uri? groupUri,
  ) {
    final groupContent = tagGrouping.getDirectChildren(groupUri);

    Set<T> whereTypeRecursively<T>(Set<CollectionFilter> filters) {
      return {
        ...filters.whereType<T>(),
        ...filters.whereType<TagGroupFilter>().expand((v) => whereTypeRecursively<T>(v.filter.innerFilters)),
      };
    }

    final listedTags = <String>{};
    if (chipTypes.contains(ChipType.regular)) {
      final allTags = source.sortedTags;
      if (groupUri == null) {
        final withinGroups = whereTypeRecursively<TagFilter>(groupContent).map((v) => v.tag).toSet();
        listedTags.addAll(allTags.whereNot(withinGroups.contains));
      } else {
        // check that group content is listed from source, to prevent displaying hidden content
        listedTags.addAll(groupContent.whereType<TagFilter>().map((v) => v.tag).where(allTags.contains));
      }
    }

    // always show groups, which are needed to navigate to other types
    final tagGroupFilters = groupContent.whereType<TagGroupFilter>().whereNot(settings.hiddenFilters.contains).toSet();

    final filters = <TagBaseFilter>{
      ...tagGroupFilters,
      ...listedTags.map(TagFilter.new),
    };

    return FilterNavigationPage.sort(settings.tagSortFactor, settings.tagSortReverse, source, filters);
  }

  static Map<ChipSectionKey, List<FilterGridItem<TagBaseFilter>>> groupToSections(Iterable<FilterGridItem<TagBaseFilter>> sortedMapEntries) {
    final pinned = settings.pinnedFilters.whereType<TagFilter>();
    final byPin = groupBy<FilterGridItem<TagBaseFilter>, bool>(sortedMapEntries, (e) => pinned.contains(e.filter));
    final pinnedMapEntries = (byPin[true] ?? []);
    final unpinnedMapEntries = (byPin[false] ?? []);

    return {
      if (pinnedMapEntries.isNotEmpty || unpinnedMapEntries.isNotEmpty)
        const ChipSectionKey(): [
          ...pinnedMapEntries,
          ...unpinnedMapEntries,
        ],
    };
  }
}

class _TagListPageState extends State<TagListPage> with FeedbackMixin, VaultAwareMixin {
  final ValueNotifier<String?> _expandedSectionNotifier = ValueNotifier(null);

  // mirrors the type filters shown in the search media collections page
  static final List<CollectionFilter> typeFilters = [
    FavouriteFilter.instance,
    MimeFilter.image,
    MimeFilter.video,
    TypeFilter.animated,
    TypeFilter.motionPhoto,
    AspectRatioFilter.portrait,
    AspectRatioFilter.landscape,
    TypeFilter.panorama,
    TypeFilter.sphericalVideo,
    TypeFilter.slowMotion,
    TypeFilter.geotiff,
    TypeFilter.hdr,
    TypeFilter.raw,
  ];

  @override
  void dispose() {
    _expandedSectionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FilterGrouping>.value(value: tagGrouping),
        FilterGroupProvider(initialValue: widget.initialGroup),
      ],
      child: Builder(
        // to access filter group provider from subtree context
        builder: (context) {
          final source = context.read<CollectionSource>();
          return Selector<Settings, (ChipSortFactor, bool, Set<CollectionFilter>)>(
            selector: (context, s) => (s.tagSortFactor, s.tagSortReverse, s.pinnedFilters),
            shouldRebuild: (t1, t2) {
              // `Selector` by default uses `DeepCollectionEquality`, which does not go deep in collections within records
              const eq = DeepCollectionEquality();
              return !(eq.equals(t1.$1, t2.$1) && eq.equals(t1.$2, t2.$2) && eq.equals(t1.$3, t2.$3));
            },
            builder: (context, s, child) {
              return ListenableBuilder(
                listenable: tagGrouping,
                builder: (context, child) => StreamBuilder(
                  stream: source.eventBus.on<TagsChangedEvent>(),
                  builder: (context, snapshot) {
                    final groupUri = context.watch<FilterGroupNotifier>().value;
                    final gridItems = TagListPage.getGridItems(source, ChipType.values.toSet(), groupUri);
                    return FilterNavigationPage<TagBaseFilter, TagChipSetActionDelegate>(
                      source: source,
                      title: context.l10n.tagPageTitle,
                      sortFactor: settings.tagSortFactor,
                      actionDelegate: TagChipSetActionDelegate(gridItems),
                      filterSections: TagListPage.groupToSections(gridItems),
                      // show the app built-in filter categories below our own tags (only at the root)
                      footerSlivers: groupUri == null ? _buildFooterSlivers(context, source) : null,
                      emptyBuilder: () => EmptyContent(
                        icon: AIcons.tag,
                        text: context.l10n.tagEmpty,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onFilterTap(CollectionFilter filter) {
    _selectForFilter(context, filter).then((_) {});
  }

  Future<void> _selectForFilter(BuildContext context, CollectionFilter filter) async {
    if (!await unlockFilter(context, filter)) return;
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: CollectionPage.routeName),
        builder: (context) => CollectionPage(
          source: context.read<CollectionSource>(),
          filters: {filter},
        ),
      ),
    );
  }

  Widget _filterSliver(BuildContext context, String title, List<CollectionFilter> filters) {
    if (filters.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    return SliverToBoxAdapter(
      child: TitledExpandableFilterRow(
        title: title,
        filters: filters,
        expandedNotifier: _expandedSectionNotifier,
        onTap: _onFilterTap,
        onLongPress: AvesFilterChip.showDefaultLongPressMenu,
      ),
    );
  }

  List<Widget> _buildFooterSlivers(BuildContext context, CollectionSource source) {
    final l10n = context.l10n;
    final notHidden = (CollectionFilter f) => !settings.hiddenFilters.contains(f);

    final visibleTypeFilters = typeFilters.where(notHidden).toList();
    if (settings.hiddenFilters.contains(MimeFilter.video)) {
      [MimeFilter.image, TypeFilter.sphericalVideo].forEach(visibleTypeFilters.remove);
    }

    final mimeTypeFilters = source.visibleEntries.map((entry) => entry.mimeType).toSet().map(MimeFilter.new).toList()..sort();

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterRow(context, l10n.tagWallTypeSectionTitle, visibleTypeFilters),
            _buildDateSliver(context, notHidden),
            _filterRow(context, l10n.searchFormatSectionTitle, mimeTypeFilters.where(notHidden).toList()),
            _buildAlbumSliver(source, notHidden),
            _buildCountrySliver(source, notHidden),
            _buildStateSliver(source, notHidden),
            _buildPlaceSliver(source, notHidden),
            _filterRow(context, l10n.searchRatingSectionTitle, [5, 4, 3, 2, 1, -1].map(RatingFilter.new).toList()),
            _filterRow(
              context,
              l10n.searchMetadataSectionTitle,
              [
                MissingFilter.date,
                LocationFilter.unlocated,
                MissingFilter.fineAddress,
                TagFilter(''),
                RatingFilter(0),
                MissingFilter.title,
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _filterRow(BuildContext context, String title, List<CollectionFilter> filters) {
    if (filters.isEmpty) return const SizedBox();
    return TitledExpandableFilterRow(
      title: title,
      filters: filters,
      expandedNotifier: _expandedSectionNotifier,
      onTap: _onFilterTap,
      onLongPress: AvesFilterChip.showDefaultLongPressMenu,
    );
  }

  Widget _buildDateSliver(BuildContext context, CollectionFilterPredicate notHidden) {
    final locale = settings.avesLocale;
    final calendar = locale.calendar;
    final calOps = calendar.ops;
    final firstDayOfWeekIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    const daysPerWeek = DateTime.daysPerWeek;
    final monthFilters = List.generate(calOps.monthsPerYear, (i) => DateFilter(calendar, DateLevel.m, DateTime(1, i + 1)));
    final weekdayFilters = List.generate(daysPerWeek, (i) => WeekDayFilter((i + firstDayOfWeekIndex - 1) % daysPerWeek + 1));
    final filters = [
      DateFilter.onThisDay,
      RecentlyAddedFilter.instance,
      ...monthFilters,
      ...weekdayFilters,
    ].where(notHidden).toList();
    return _filterRow(context, context.l10n.searchDateSectionTitle, filters);
  }

  Widget _buildAlbumSliver(CollectionSource source, CollectionFilterPredicate notHidden) {
    return ListenableBuilder(
      listenable: dynamicAlbums,
      builder: (context, child) => StreamBuilder(
        stream: source.eventBus.on<AlbumsChangedEvent>(),
        builder: (context, snapshot) {
          final filters = [
            ...albumGrouping.getGroups().map(albumGrouping.uriToFilter),
            ...source.rawAlbums.map(
              (album) => StoredAlbumFilter(
                album,
                source.getStoredAlbumDisplayName(context, album),
              ),
            ),
            ...dynamicAlbums.all,
          ].nonNulls.where(notHidden).toList()..sort();
          return _filterRow(context, context.l10n.searchAlbumsSectionTitle, filters);
        },
      ),
    );
  }

  Widget _buildCountrySliver(CollectionSource source, CollectionFilterPredicate notHidden) {
    return StreamBuilder(
      stream: source.eventBus.on<CountriesChangedEvent>(),
      builder: (context, snapshot) {
        final filters = source.sortedCountries.map((s) => LocationFilter(LocationLevel.country, s)).where(notHidden).toList();
        return _filterRow(context, context.l10n.searchCountriesSectionTitle, filters);
      },
    );
  }

  Widget _buildStateSliver(CollectionSource source, CollectionFilterPredicate notHidden) {
    return StreamBuilder(
      stream: source.eventBus.on<PlacesChangedEvent>(),
      builder: (context, snapshot) {
        final filters = source.sortedStates.map((s) => LocationFilter(LocationLevel.state, s)).where(notHidden).toList();
        return _filterRow(context, context.l10n.searchStatesSectionTitle, filters);
      },
    );
  }

  Widget _buildPlaceSliver(CollectionSource source, CollectionFilterPredicate notHidden) {
    return StreamBuilder(
      stream: source.eventBus.on<PlacesChangedEvent>(),
      builder: (context, snapshot) {
        final filters = source.sortedPlaces.map((s) => LocationFilter(LocationLevel.place, s)).where(notHidden).toList();
        return _filterRow(context, context.l10n.searchPlacesSectionTitle, filters);
      },
    );
  }
}
