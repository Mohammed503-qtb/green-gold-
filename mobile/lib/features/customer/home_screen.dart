// ============================================================
// GREEN GOLD | المتجر الرئيسية — البطل + الشرائح + البحث + شبكة الدفعات
// كل شريحة تجلب الكتالوج بالفلتر المناسب من الخادم
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/batch.dart';
import '../../services/customer_services.dart';
import '../../shared/widgets.dart';
import '../../state/cart.dart';
import 'batch_details_screen.dart';

// ───────── الشرائح ─────────

class HomeSegment {
  final String key;
  final String label;
  final String? grade;
  final String? sort;

  const HomeSegment(this.key, this.label, {this.grade, this.sort});
}

const List<HomeSegment> kHomeSegments = [
  HomeSegment('all', '🌿 الكل'),
  HomeSegment('PREMIUM', '💎 فاخر', grade: 'PREMIUM'),
  HomeSegment('EXCELLENT', '⭐ ممتاز', grade: 'EXCELLENT'),
  HomeSegment('ECONOMIC', '💰 اقتصادي', grade: 'ECONOMIC'),
  HomeSegment('popular', '🔥 الأكثر طلبًا', sort: 'popular'),
  HomeSegment('newest', '🆕 وصل حديثًا', sort: 'newest'),
];

// ───────── الحالة والمتحكم ─────────

class HomeCatalogState {
  final HomeSegment segment;
  final String search;
  final List<BatchCard> batches;
  final bool loading;
  final String? error;
  final DateTime? lastUpdated;
  final int? availableCount;
  final List<String> cartNotices;

  const HomeCatalogState({
    required this.segment,
    this.search = '',
    this.batches = const [],
    this.loading = false,
    this.error,
    this.lastUpdated,
    this.availableCount,
    this.cartNotices = const [],
  });

  static const Object _unset = Object();

  HomeCatalogState copyWith({
    HomeSegment? segment,
    String? search,
    List<BatchCard>? batches,
    bool? loading,
    Object? error = _unset,
    DateTime? lastUpdated,
    int? availableCount,
    List<String>? cartNotices,
  }) {
    return HomeCatalogState(
      segment: segment ?? this.segment,
      search: search ?? this.search,
      batches: batches ?? this.batches,
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      availableCount: availableCount ?? this.availableCount,
      cartNotices: cartNotices ?? this.cartNotices,
    );
  }
}

class HomeCatalogController extends StateNotifier<HomeCatalogState> {
  HomeCatalogController(this._ref)
      : super(HomeCatalogState(segment: kHomeSegments.first, loading: true)) {
    _load();
  }

  final Ref _ref;
  Timer? _debounce;
  int _token = 0;

  CatalogService get _catalog => _ref.read(catalogServiceProvider);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void selectSegment(HomeSegment segment) {
    if (segment.key == state.segment.key) return;
    state = state.copyWith(segment: segment);
    _load();
  }

  void setSearch(String value) {
    if (value == state.search) return;
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> refresh() => _load();

  void clearNotices() {
    if (state.cartNotices.isNotEmpty) {
      state = state.copyWith(cartNotices: const []);
    }
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final token = ++_token;
    final seg = state.segment;
    final search = state.search.trim();
    state = state.copyWith(loading: true, error: null);
    try {
      final batches = await _catalog.fetchCatalog(
        grade: seg.grade,
        search: search.isEmpty ? null : search,
        sort: seg.sort,
      );
      if (token != _token) return;
      state = state.copyWith(
        batches: batches,
        loading: false,
        lastUpdated: DateTime.now(),
      );
      // التحقق من السلة يتم دائمًا مقابل الكتالوج الكامل غير المُفلتر
      if (seg.grade == null && search.isEmpty) {
        _absorbFullCatalog(batches);
      } else {
        _silentFullFetch();
      }
    } on ApiException catch (e) {
      if (token != _token) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      if (token != _token) return;
      state = state.copyWith(loading: false, error: 'تعذر تحميل الدفعات، حاول مرة أخرى');
    }
  }

  /// جلب كامل صامت لأغراض عدّ الدفعات المتوفرة + التحقق من السلة
  Future<void> _silentFullFetch() async {
    try {
      final all = await _catalog.fetchCatalog();
      _absorbFullCatalog(all);
    } catch (_) {
      // تحقق صامت — لا يُفشل الواجهة
    }
  }

  void _absorbFullCatalog(List<BatchCard> batches) {
    final notices =
        _ref.read(cartProvider.notifier).validateAgainstCatalog(batches);
    state = state.copyWith(
      availableCount: batches.length,
      cartNotices: notices,
    );
  }
}

final homeCatalogProvider =
    StateNotifierProvider<HomeCatalogController, HomeCatalogState>((ref) {
  return HomeCatalogController(ref);
});

// ───────── الشاشة ─────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeCatalogProvider);
    final controller = ref.read(homeCatalogProvider.notifier);

    ref.listen<HomeCatalogState>(homeCatalogProvider, (prev, next) {
      final notices = next.cartNotices;
      if (notices.isNotEmpty && !identical(prev?.cartNotices, notices)) {
        showAppSnackBar(context, notices.join('\n'));
        Future.microtask(controller.clearNotices);
      }
    });

    final showSkeleton = state.loading && state.batches.isEmpty;
    final showError =
        !state.loading && state.error != null && state.batches.isEmpty;
    final showEmpty =
        !state.loading && state.error == null && state.batches.isEmpty;
    final staleError = state.error != null && state.batches.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero(state)),
              SliverToBoxAdapter(child: _searchAndChips(context, state, controller)),
              if (staleError)
                SliverToBoxAdapter(child: _errorBanner(context, state.error!, controller)),
              if (showSkeleton)
                _skeletonGrid()
              else if (showError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetryView(
                    message: state.error!,
                    onRetry: controller.refresh,
                  ),
                )
              else if (showEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyView(state))
              else
                _batchesGrid(state),
            ],
          ),
        ),
      ),
    );
  }

  // ─── البطل ───

  Widget _hero(HomeCatalogState state) {
    final count = state.availableCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        gradient: AppPalette.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.greenDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              bottom: -36,
              left: -14,
              child: Opacity(
                opacity: 0.08,
                child: Text(
                  '🌿',
                  style: TextStyle(
                    fontSize: 130,
                    color: Colors.white.withValues(alpha: 1),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -46,
              right: -34,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.gold.withValues(alpha: 0.13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroPill('🌿 دفعات مصوّرة اليوم — بشوف ما بتستلمه', strong: true),
                  const SizedBox(height: 12),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'ذهب '),
                        TextSpan(
                          text: 'أخضر',
                          style: TextStyle(color: Color(0xFFE3C558)),
                        ),
                        TextSpan(text: ' 🌿'),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'قات اليوم في عدن — بشوف ما بتستلمه قبل ما تدفع',
                    style: TextStyle(color: Color(0xFFD9EFE1), fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _heroPill(
                        count == null
                            ? '🟢 جارٍ جلب الدفعات…'
                            : '🟢 ${formatNum(count)} دفعة متوفرة الآن',
                        strong: true,
                      ),
                      _heroPill(
                        state.lastUpdated != null
                            ? 'تحديث آخر ${timeAgoAr(state.lastUpdated)}'
                            : 'جارٍ جلب الدفعات…',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroPill(String text, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: strong ? Colors.white24 : Colors.white12,
        ),
        color: strong ? Colors.white12 : Colors.white.withValues(alpha: 0.06),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          color: strong ? Colors.white : const Color(0xFFCDE7D6),
        ),
      ),
    );
  }

  // ─── البحث + الشرائح ───

  Widget _searchAndChips(
    BuildContext context,
    HomeCatalogState state,
    HomeCatalogController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: controller.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم النوع أو رقم الدفعة…',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    suffixIcon: state.search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              controller.setSearch('');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: 'تحديث الدفعات',
                  onPressed: state.loading ? null : controller.refresh,
                  icon: state.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: kHomeSegments.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final seg = kHomeSegments[i];
              final selected = seg.key == state.segment.key;
              final scheme = Theme.of(context).colorScheme;
              return Material(
                color: selected
                    ? AppPalette.green
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => controller.selectSegment(seg),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      seg.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _errorBanner(
    BuildContext context,
    String message,
    HomeCatalogController controller,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x33DC2626),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFF991B1B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          TextButton(
            onPressed: controller.refresh,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ─── الشبكة والحالات ───

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 10,
    childAspectRatio: 0.585,
  );

  Widget _batchesGrid(HomeCatalogState state) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, i) => _BatchTile(batch: state.batches[i]),
          childCount: state.batches.length,
        ),
      ),
    );
  }

  Widget _skeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, _) => const _SkeletonTile(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _emptyView(HomeCatalogState state) {
    final filtered =
        state.segment.key != 'all' || state.search.trim().isNotEmpty;
    if (filtered) {
      return EmptyState(
        emoji: '🌿',
        title: 'لا توجد دفعات مطابقة',
        subtitle: state.search.trim().isNotEmpty
            ? 'لم نجد نتائج للبحث «${state.search.trim()}» — جرّب كلمة أخرى أو تصفح تصنيفًا مختلفًا'
            : 'لا توجد دفعات في هذا التصنيف حاليًا، تصفح «الكل» أو حدّث الصفحة',
      );
    }
    return const EmptyState(
      emoji: '🌿',
      title: 'لا توجد دفعات متوفرة الآن',
      subtitle: 'الدفعات تُنشر يوميًا مع صور الصباح — عد لاحقًا اليوم أو اسحب للتحديث',
    );
  }
}

// ───────── بطاقة الدفعة ─────────

class _BatchTile extends StatelessWidget {
  final BatchCard batch;

  const _BatchTile({required this.batch});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BatchDetailsScreen(batchId: batch.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = batch.availableQty > 0;
    final low = batch.isLowStock;
    final totalUnits = batch.availableQty + batch.soldCount;
    final soldRatio = totalUnits > 0 ? batch.soldCount / totalUnits : 0.0;
    final hintColor = Theme.of(context).hintColor;

    final stockLabel = !available
        ? 'نفدت الكمية'
        : low
            ? '🟡 آخر ${formatNum(batch.availableQty)} حزم'
            : '🟢 متوفر ${formatNum(batch.availableQty)} حزمة';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: NetImage(url: batch.mainImage),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: const Alignment(0, 0.5),
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(top: 8, right: 8, child: GradeBadge(grade: batch.grade)),
                if (batch.video != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 13, color: Colors.white),
                          Text(
                            ' فيديو',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stockLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'قات ${batch.productName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (batch.reviewsCount > 0 && batch.avgRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '⭐ ${batch.avgRating!.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    batch.batchCode,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '📸 ${capturedLabel(batch.capturedAt)}',
                    style: TextStyle(fontSize: 10.5, color: hintColor),
                  ),
                  if (batch.soldCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '🔥 بيع ${formatNum(batch.soldCount)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: soldRatio.clamp(0.0, 1.0),
                              minHeight: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatYER(batch.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppPalette.green,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('للحزمة', style: TextStyle(fontSize: 9.5, color: hintColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: available ? () => _open(context) : null,
                      icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                      label: Text(available ? 'أطلب الآن' : 'نفدت'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── هيكل التحميل ─────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: Container(color: base)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14, width: double.infinity, color: base),
                const SizedBox(height: 8),
                Container(height: 10, width: 90, color: base),
                const SizedBox(height: 8),
                Container(height: 10, width: 120, color: base),
                const SizedBox(height: 10),
                Container(height: 14, width: 80, color: base),
                const SizedBox(height: 10),
                Container(height: 44, width: double.infinity, color: base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
