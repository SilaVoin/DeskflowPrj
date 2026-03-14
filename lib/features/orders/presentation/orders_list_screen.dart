import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/models/paginated_list.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/empty_state_widget.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/floating_island_nav.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_chip.dart';
import 'package:deskflow/core/widgets/glass_floating_action_button.dart';
import 'package:deskflow/core/widgets/pill_search_bar.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/orders_list_controls.dart';
import 'package:deskflow/features/orders/presentation/status_change_sheet.dart';

final _log = AppLogger.getLogger('OrdersListScreen');

enum _OrdersTopPanel { none, sort, period }

enum _OrdersSortMode { byDate, byAmount }

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  static const _monthNames = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  String? _selectedStatusId;
  String _debouncedQuery = '';
  Timer? _debounceTimer;
  final _scrollController = ScrollController();
  final _singleDateController = TextEditingController();
  final _rangeStartController = TextEditingController();
  final _rangeEndController = TextEditingController();

  _OrdersTopPanel _activePanel = _OrdersTopPanel.none;
  _OrdersSortMode _sortMode = _OrdersSortMode.byDate;
  _OrdersSortMode? _expandedSortMode = _OrdersSortMode.byDate;
  bool _isRangeMode = false;
  bool _showsManualInput = false;
  DateTime? _draftRangeStart;
  late DateTime _visibleMonth;
  RangeValues _amountDraftValues = const RangeValues(
    OrderAmountRange.boundsMin,
    OrderAmountRange.boundsMax,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _singleDateController.dispose();
    _rangeStartController.dispose();
    _rangeEndController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _log.d('searchOrders triggered: query="$query"');
      setState(() => _debouncedQuery = query.trim());
    });
  }

  void _onScroll() {
    if (_debouncedQuery.isNotEmpty || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref.read(ordersListProvider(statusId: _selectedStatusId).notifier).loadMore();
    }
  }

  String _monthLabel(DateTime month) {
    return '${_monthNames[month.month - 1]} ${month.year}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _dateSummary(OrdersListControls controls) {
    if (controls.selectedDateRange != null) {
      final range = controls.selectedDateRange!.normalized();
      return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
    }
    if (controls.selectedDate != null) {
      return _formatDate(controls.selectedDate!);
    }
    if (_isRangeMode && _draftRangeStart != null) {
      return '${_formatDate(_draftRangeStart!)} - ...';
    }
    return 'По дате';
  }

  String _amountSummary(OrderAmountRange? range) {
    if (range == null || range.isFullRange) return 'По сумме';
    return 'По сумме · ${CurrencyFormatter.formatCompact(range.min)} - '
        '${CurrencyFormatter.formatCompact(range.max)}';
  }

  String _sortSummary(OrdersListControls controls) {
    switch (_sortMode) {
      case _OrdersSortMode.byDate:
        return _dateSummary(controls);
      case _OrdersSortMode.byAmount:
        return _amountSummary(controls.amountRange);
    }
  }

  double _sheetHorizontalInset(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth < 380 ? DeskflowSpacing.lg : DeskflowSpacing.xl;
  }

  double _sheetBottomOffset(BuildContext context) {
    return FloatingIslandNav.totalHeight(context) + DeskflowSpacing.xl;
  }

  void _syncManualInputs(OrdersListControls controls) {
    _singleDateController.text = controls.selectedDate == null
        ? ''
        : _formatDate(controls.selectedDate!);
    _rangeStartController.text = controls.selectedDateRange == null
        ? (_draftRangeStart == null ? '' : _formatDate(_draftRangeStart!))
        : _formatDate(controls.selectedDateRange!.normalizedStart);
    _rangeEndController.text = controls.selectedDateRange == null
        ? ''
        : _formatDate(controls.selectedDateRange!.normalizedEnd);
  }

  DateTime _calendarSeed(OrdersListControls controls) {
    return controls.selectedDate ??
        controls.selectedDateRange?.normalizedStart ??
        _draftRangeStart ??
        DateTime.now();
  }

  void _prepareSortSheet(OrdersListControls controls) {
    setState(() {
      _showsManualInput = false;
      _expandedSortMode = _sortMode;
      if (_sortMode == _OrdersSortMode.byDate) {
        final seed = _calendarSeed(controls);
        _visibleMonth = DateTime(seed.year, seed.month);
        _syncManualInputs(controls);
      } else {
        final initial = controls.amountRange ?? OrderAmountRange.full;
        _amountDraftValues = RangeValues(initial.min, initial.max);
      }
    });
  }

  void _refreshSheetState(StateSetter sheetSetState, VoidCallback updater) {
    if (mounted) {
      setState(updater);
    }
    sheetSetState(() {});
  }

  Future<T?> _showOverlaySheet<T>({
    required WidgetBuilder builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: DeskflowColors.modalBackdrop,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animationContext, secondaryAnimationContext) =>
          Padding(
            padding: EdgeInsets.fromLTRB(
              _sheetHorizontalInset(dialogContext),
              0,
              _sheetHorizontalInset(dialogContext),
              _sheetBottomOffset(dialogContext),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: builder(dialogContext),
            ),
          ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showPeriodSheet() async {
    if (mounted) {
      setState(() => _activePanel = _OrdersTopPanel.period);
    }

    await _showOverlaySheet<void>(
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final controls = sheetRef.watch(ordersListControlsProvider);
          return _OrdersBottomSheetScaffold(
            title: 'Период',
            wrapContent: true,
            maxHeightFactor: 0.38,
            child: _PeriodPanel(
              selectedPreset: controls.periodPreset,
              onSelectPreset: (preset) {
                _applyPeriodPreset(controls, preset);
                Navigator.of(sheetContext).pop();
              },
            ),
          );
        },
      ),
    );

    if (mounted) {
      setState(() => _activePanel = _OrdersTopPanel.none);
    }
  }

  Future<void> _showSortSheet() async {
    final controls = ref.read(ordersListControlsProvider);
    _prepareSortSheet(controls);
    if (mounted) {
      setState(() => _activePanel = _OrdersTopPanel.sort);
    }

    await _showOverlaySheet<void>(
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final liveControls = sheetRef.watch(ordersListControlsProvider);
          return StatefulBuilder(
            builder: (context, sheetSetState) => _OrdersBottomSheetScaffold(
              title: 'Сортировка',
              wrapContent: false,
              maxHeightFactor: 0.62,
              child: _SortPanel(
                expandedMode: _expandedSortMode,
                onToggleSection: (mode) {
                  _toggleSortSection(mode, liveControls);
                  sheetSetState(() {});
                },
                dateChild: _DatePanel(
                  monthLabel: _monthLabel(_visibleMonth),
                  visibleMonth: _visibleMonth,
                  selectedDate: liveControls.selectedDate,
                  selectedDateRange: liveControls.selectedDateRange,
                  draftRangeStart: _draftRangeStart,
                  isRangeMode: _isRangeMode,
                  showsManualInput: _showsManualInput,
                  singleDateController: _singleDateController,
                  rangeStartController: _rangeStartController,
                  rangeEndController: _rangeEndController,
                  onPreviousMonth: () {
                    _changeVisibleMonth(-1);
                    sheetSetState(() {});
                  },
                  onNextMonth: () {
                    _changeVisibleMonth(1);
                    sheetSetState(() {});
                  },
                  onPickYear: () async {
                    await _pickYear();
                    sheetSetState(() {});
                  },
                  onToggleManualInput: () => _refreshSheetState(
                    sheetSetState,
                    () {
                      _showsManualInput = !_showsManualInput;
                      _syncManualInputs(liveControls);
                    },
                  ),
                  onToggleRangeMode: () {
                    _toggleRangeMode(liveControls);
                    sheetSetState(() {});
                  },
                  onApplyManualInput: () {
                    _applyManualDateInput(liveControls);
                    sheetSetState(() {});
                  },
                  onDateTap: (date) {
                    _handleCalendarTap(liveControls, date);
                    sheetSetState(() {});
                  },
                  onClear: () {
                    _clearDateFilters(liveControls);
                    sheetSetState(() {});
                  },
                ),
                amountChild: _AmountPanel(
                  amountDraftValues: _amountDraftValues,
                  currentRange: liveControls.amountRange,
                  onChanged: (values) => _refreshSheetState(
                    sheetSetState,
                    () => _amountDraftValues = values,
                  ),
                  onApply: () {
                    _applyAmountDraft(liveControls);
                    Navigator.of(sheetContext).pop();
                  },
                  onClear: () {
                    _clearAmountDraft(liveControls);
                    sheetSetState(() {});
                  },
                ),
              ),
            ),
          );
        },
      ),
    );

    if (mounted) {
      setState(() => _activePanel = _OrdersTopPanel.none);
    }
  }

  void _setSortMode(_OrdersSortMode mode, OrdersListControls controls) {
    if (mode == _sortMode) return;

    if (mode == _OrdersSortMode.byDate && controls.amountRange != null) {
      ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
        clearAmountRange: true,
      );
    }
    if (mode == _OrdersSortMode.byAmount &&
        (controls.selectedDate != null || controls.selectedDateRange != null)) {
      ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
        clearSelectedDate: true,
        clearSelectedDateRange: true,
      );
    }

    setState(() {
      _sortMode = mode;
      _showsManualInput = false;
      if (mode == _OrdersSortMode.byDate) {
        final seed = _calendarSeed(controls);
        _visibleMonth = DateTime(seed.year, seed.month);
        _syncManualInputs(controls);
      } else {
        final initial = controls.amountRange ?? OrderAmountRange.full;
        _amountDraftValues = RangeValues(initial.min, initial.max);
      }
    });
  }

  void _toggleSortSection(
    _OrdersSortMode mode,
    OrdersListControls controls,
  ) {
    if (_expandedSortMode == mode) {
      setState(() {
        _expandedSortMode = null;
      });
      return;
    }

    _setSortMode(mode, controls);
    setState(() {
      _expandedSortMode = mode;
    });
  }

  void _applyPeriodPreset(
    OrdersListControls controls,
    OrdersPeriodPreset preset,
  ) {
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      periodPreset: preset,
      clearSelectedDate: true,
      clearSelectedDateRange: true,
    );
    setState(() {
      _draftRangeStart = null;
    });
  }

  void _applySelectedDate(OrdersListControls controls, DateTime date) {
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      selectedDate: date,
      clearSelectedDateRange: true,
    );
    setState(() {
      _draftRangeStart = null;
      _visibleMonth = DateTime(date.year, date.month);
    });
  }

  void _applyDateRange(
    OrdersListControls controls,
    OrderDateRange dateRange,
  ) {
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      selectedDateRange: dateRange,
      clearSelectedDate: true,
    );
    setState(() {
      _draftRangeStart = null;
      _visibleMonth = DateTime(
        dateRange.normalizedStart.year,
        dateRange.normalizedStart.month,
      );
    });
  }

  void _handleCalendarTap(OrdersListControls controls, DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (!_isRangeMode) {
      _applySelectedDate(controls, normalized);
      return;
    }

    if (_draftRangeStart == null || controls.selectedDateRange != null) {
      setState(() {
        _draftRangeStart = normalized;
      });
      ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
        clearSelectedDate: true,
        clearSelectedDateRange: true,
      );
      return;
    }

    _applyDateRange(
      controls,
      OrderDateRange(start: _draftRangeStart!, end: normalized),
    );
  }

  void _toggleRangeMode(OrdersListControls controls) {
    final nextMode = !_isRangeMode;
    if (!nextMode) {
      final fallback =
          controls.selectedDateRange?.normalizedStart ?? _draftRangeStart;
      if (fallback != null) {
        ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
          selectedDate: fallback,
          clearSelectedDateRange: true,
        );
      }
    } else {
      _draftRangeStart =
          controls.selectedDateRange?.normalizedStart ?? controls.selectedDate;
    }

    setState(() {
      _isRangeMode = nextMode;
      _showsManualInput = false;
      if (!_isRangeMode) {
        _draftRangeStart = null;
      }
      _syncManualInputs(controls);
    });
  }

  void _applyAmountDraft(OrdersListControls controls) {
    final nextRange = OrderAmountRange(
      min: _amountDraftValues.start,
      max: _amountDraftValues.end,
    );
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      amountRange: nextRange.isFullRange ? null : nextRange,
      clearAmountRange: nextRange.isFullRange,
    );
  }

  void _clearAmountDraft(OrdersListControls controls) {
    setState(() {
      _amountDraftValues = const RangeValues(
        OrderAmountRange.boundsMin,
        OrderAmountRange.boundsMax,
      );
    });
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      clearAmountRange: true,
    );
  }

  void _clearDateFilters(OrdersListControls controls) {
    ref.read(ordersListControlsProvider.notifier).state = controls.copyWith(
      clearSelectedDate: true,
      clearSelectedDateRange: true,
    );
    setState(() {
      _draftRangeStart = null;
    });
  }

  void _changeVisibleMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _pickYear() async {
    final controller = TextEditingController(text: '${_visibleMonth.year}');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DeskflowColors.modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeskflowRadius.overlay),
        ),
        title: const Text('Выбрать год'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Год',
            hintText: 'Например, 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final year = int.tryParse(controller.text.trim());
              if (year == null || year < 2000 || year > 2100) return;
              Navigator.of(dialogContext).pop(year);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _visibleMonth = DateTime(result, _visibleMonth.month);
    });
  }

  DateTime? _parseDateInput(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  void _applyManualDateInput(OrdersListControls controls) {
    if (!_isRangeMode) {
      final parsed = _parseDateInput(_singleDateController.text);
      if (parsed == null) return;
      _applySelectedDate(controls, parsed);
      return;
    }

    final start = _parseDateInput(_rangeStartController.text);
    final end = _parseDateInput(_rangeEndController.text);
    if (start == null || end == null) return;
    _applyDateRange(
      controls,
      OrderDateRange(start: start, end: end),
    );
  }

  Future<void> _showOrderActions(Order order) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: GlassCard(
          elevated: true,
          margin: const EdgeInsets.all(DeskflowSpacing.lg),
          borderRadius: DeskflowRadius.overlay,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.formattedNumber, style: DeskflowTypography.h3),
              const SizedBox(height: DeskflowSpacing.md),
              _SheetAction(
                icon: Icons.open_in_new_rounded,
                label: 'Открыть заказ',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/orders/${order.id}');
                },
              ),
              _SheetAction(
                icon: Icons.edit_rounded,
                label: 'Редактировать',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/orders/${order.id}/edit');
                },
              ),
              _SheetAction(
                icon: Icons.swap_horiz_rounded,
                label: 'Сменить статус',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => StatusChangeSheet(
                      orderId: order.id,
                      currentStatusId: order.statusId,
                    ),
                  );
                },
              ),
              _SheetAction(
                icon: Icons.copy_all_rounded,
                label: 'Дублировать',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    final composition = await ref.read(
                      duplicateOrderCompositionProvider(order.id).future,
                    );
                    if (!mounted) return;
                    context.push('/orders/create', extra: composition);
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Не удалось подготовить дубликат заказа'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(ordersListProvider);
    if (_debouncedQuery.isNotEmpty) {
      ref.invalidate(ordersSearchProvider(_debouncedQuery, _selectedStatusId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controls = ref.watch(ordersListControlsProvider);
    final pipelineAsync = ref.watch(pipelineProvider);
    final ordersAsync = ref.watch(
      ordersListProvider(statusId: _selectedStatusId),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: DeskflowColors.primarySolid,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DeskflowSpacing.lg,
                  DeskflowSpacing.lg,
                  DeskflowSpacing.lg,
                  DeskflowSpacing.sm,
                ),
                child: PillSearchBar(
                  hintText: 'Поиск по заказам',
                  height: 42,
                  horizontalPadding: DeskflowSpacing.sm,
                  gapAfterIcon: DeskflowSpacing.xs,
                  onChanged: _onSearchChanged,
                ),
              ),
              SizedBox(
                height: 40,
                child: pipelineAsync.when(
                  data: (pipeline) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DeskflowSpacing.lg,
                    ),
                    children: [
                      GlassChip(
                        label: 'Все',
                        selected: _selectedStatusId == null,
                        onTap: () => setState(() => _selectedStatusId = null),
                      ),
                      ...pipeline.map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(left: DeskflowSpacing.sm),
                          child: GlassChip(
                            label: status.name,
                            selected: _selectedStatusId == status.id,
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: status.materialColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            onTap: () => setState(() => _selectedStatusId = status.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: DeskflowSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactFilterTrigger(
                        title: 'Сортировка',
                        value: _sortSummary(controls),
                        active: _activePanel == _OrdersTopPanel.sort,
                        onTap: () => _showSortSheet(),
                      ),
                    ),
                    const SizedBox(width: DeskflowSpacing.md),
                    Expanded(
                      child: _CompactFilterTrigger(
                        title: 'Период',
                        value: controls.periodPreset.label,
                        active: _activePanel == _OrdersTopPanel.period,
                        onTap: () => _showPeriodSheet(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DeskflowSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.lg),
                child: _debouncedQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildPaginatedList(ordersAsync),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: FloatingIslandNav.totalHeight(context) + 16,
        ),
        child: GlassFloatingActionButton(
          icon: Icons.add_rounded,
          onPressed: () => context.push('/orders/create'),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchAsync = ref.watch(
      ordersSearchProvider(_debouncedQuery, _selectedStatusId),
    );

    return searchAsync.when(
      data: (orders) {
        _log.d(
          'searchOrders results: ${orders.length} orders for query="$_debouncedQuery"',
        );

        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'Ничего не найдено',
            description: 'Попробуйте изменить запрос',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
          itemBuilder: (_, index) => _OrderCard(
            order: orders[index],
            onMoreTap: () => _showOrderActions(orders[index]),
          ),
        );
      },
      loading: () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: SkeletonLoader(child: SkeletonLoader.box(height: 72)),
        ),
      ),
      error: (error, _) => ErrorStateWidget(
        message: 'Ошибка поиска заказов',
        onRetry: () => ref.invalidate(
          ordersSearchProvider(_debouncedQuery, _selectedStatusId),
        ),
      ),
    );
  }

  Widget _buildPaginatedList(AsyncValue<PaginatedList<Order>> ordersAsync) {
    return ordersAsync.when(
      data: (paginated) {
        final orders = paginated.items;

        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: _selectedStatusId != null
                ? 'Нет заказов с этим статусом'
                : 'Нет заказов',
            description: _selectedStatusId != null
                ? 'Попробуйте другой фильтр'
                : 'Создайте первый заказ!',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length + (paginated.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: DeskflowSpacing.sm),
          itemBuilder: (_, index) {
            if (index >= orders.length) {
              return const Padding(
                padding: EdgeInsets.all(DeskflowSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DeskflowColors.primarySolid,
                    ),
                  ),
                ),
              );
            }
            return _OrderCard(
              order: orders[index],
              onMoreTap: () => _showOrderActions(orders[index]),
            );
          },
        );
      },
      loading: () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
          child: SkeletonLoader(child: SkeletonLoader.box(height: 72)),
        ),
      ),
      error: (error, _) => ErrorStateWidget(
        message: 'Ошибка загрузки заказов',
        onRetry: () => ref.invalidate(ordersListProvider),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onMoreTap});

  final Order order;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/orders/${order.id}'),
      color: DeskflowColors.shellGlassSurface,
      borderColor: DeskflowColors.glassBorderStrong.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(DeskflowSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(order.formattedNumber, style: DeskflowTypography.h3),
                    const SizedBox(width: DeskflowSpacing.sm),
                    Expanded(
                      child: Text(
                        order.customerName ?? 'Без клиента',
                        style: DeskflowTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                Text(
                  CurrencyFormatter.formatCompact(order.totalAmount),
                  style: DeskflowTypography.body,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoreTap,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: DeskflowColors.textSecondary,
            ),
          ),
          if (order.status != null)
            StatusPillBadge(
              label: order.status!.name,
              color: order.status!.materialColor,
            ),
        ],
      ),
    );
  }
}

class _CompactFilterTrigger extends StatelessWidget {
  const _CompactFilterTrigger({
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeskflowRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.md,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active
              ? DeskflowColors.shellGlassSurface
              : DeskflowColors.glassSurface,
          borderRadius: BorderRadius.circular(DeskflowRadius.card),
          border: Border.all(
            color: active
                ? DeskflowColors.glassBorderStrong.withValues(alpha: 0.62)
                : DeskflowColors.glassBorderStrong.withValues(alpha: 0.42),
            width: 0.75,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? 0.1 : 0.06),
              blurRadius: active ? 14 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DeskflowTypography.caption),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DeskflowTypography.bodySmall.copyWith(
                      color: DeskflowColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              active
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: DeskflowColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersBottomSheetScaffold extends StatelessWidget {
  const _OrdersBottomSheetScaffold({
    required this.title,
    required this.child,
    this.wrapContent = false,
    this.maxHeightFactor,
  });

  final String title;
  final Widget child;
  final bool wrapContent;
  final double? maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height *
        (maxHeightFactor ?? (wrapContent ? 0.35 : 0.46));
    final sheetBody = GlassCard(
        elevated: true,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: DeskflowRadius.overlay,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.fromLTRB(
              DeskflowSpacing.md,
              DeskflowSpacing.xs,
              DeskflowSpacing.md,
              DeskflowSpacing.sm + mediaQuery.viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: DeskflowSpacing.xs),
                    decoration: BoxDecoration(
                      color: DeskflowColors.textTertiary.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(DeskflowRadius.pill),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: DeskflowTypography.h2.copyWith(fontSize: 17),
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                child,
              ],
            ),
          ),
        ),
      );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: sheetBody,
    );
  }
}

class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel({
    required this.selectedPreset,
    required this.onSelectPreset,
  });

  final OrdersPeriodPreset selectedPreset;
  final ValueChanged<OrdersPeriodPreset> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    return _SheetPanelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...OrdersPeriodPreset.values.map(
            (preset) => _OptionRow(
              label: preset.label,
              selected: selectedPreset == preset,
              onTap: () => onSelectPreset(preset),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortPanel extends StatelessWidget {
  const _SortPanel({
    required this.expandedMode,
    required this.onToggleSection,
    required this.dateChild,
    required this.amountChild,
  });

  final _OrdersSortMode? expandedMode;
  final ValueChanged<_OrdersSortMode> onToggleSection;
  final Widget dateChild;
  final Widget amountChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExpandableSortSection(
          label: 'По дате',
          expanded: expandedMode == _OrdersSortMode.byDate,
          onTap: () => onToggleSection(_OrdersSortMode.byDate),
          child: dateChild,
        ),
        const SizedBox(height: DeskflowSpacing.xs),
        _ExpandableSortSection(
          label: 'По сумме',
          expanded: expandedMode == _OrdersSortMode.byAmount,
          onTap: () => onToggleSection(_OrdersSortMode.byAmount),
          child: amountChild,
        ),
      ],
    );
  }
}

class _ExpandableSortSection extends StatelessWidget {
  const _ExpandableSortSection({
    required this.label,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SheetPanelSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DeskflowRadius.field),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    color: DeskflowColors.textSecondary,
                  ),
                  const SizedBox(width: DeskflowSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: DeskflowTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: DeskflowSpacing.xs),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SheetPanelSurface extends StatelessWidget {
  const _SheetPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DeskflowColors.glassSurface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(DeskflowRadius.card),
        border: Border.all(
          color: DeskflowColors.glassBorderStrong.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.sm,
        vertical: DeskflowSpacing.xs,
      ),
      child: child,
    );
  }
}

class _DatePanel extends StatelessWidget {
  const _DatePanel({
    required this.monthLabel,
    required this.visibleMonth,
    required this.selectedDate,
    required this.selectedDateRange,
    required this.draftRangeStart,
    required this.isRangeMode,
    required this.showsManualInput,
    required this.singleDateController,
    required this.rangeStartController,
    required this.rangeEndController,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickYear,
    required this.onToggleManualInput,
    required this.onToggleRangeMode,
    required this.onApplyManualInput,
    required this.onDateTap,
    required this.onClear,
  });

  final String monthLabel;
  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final OrderDateRange? selectedDateRange;
  final DateTime? draftRangeStart;
  final bool isRangeMode;
  final bool showsManualInput;
  final TextEditingController singleDateController;
  final TextEditingController rangeStartController;
  final TextEditingController rangeEndController;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickYear;
  final VoidCallback onToggleManualInput;
  final VoidCallback onToggleRangeMode;
  final VoidCallback onApplyManualInput;
  final ValueChanged<DateTime> onDateTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final range = selectedDateRange?.normalized();
    final isShortViewport = MediaQuery.sizeOf(context).height < 620;

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showsManualInput) ...[
          if (!isRangeMode)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: singleDateController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Дата',
                      hintText: 'ДД.ММ.ГГГГ',
                    ),
                  ),
                ),
                const SizedBox(width: DeskflowSpacing.sm),
                TextButton(
                  onPressed: onApplyManualInput,
                  child: const Text('OK'),
                ),
              ],
            )
          else
            Column(
              children: [
                TextField(
                  controller: rangeStartController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'От',
                    hintText: 'ДД.ММ.ГГГГ',
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.sm),
                TextField(
                  controller: rangeEndController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'До',
                    hintText: 'ДД.ММ.ГГГГ',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onApplyManualInput,
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: DeskflowSpacing.xs),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _IconChipButton(
              icon: Icons.keyboard_rounded,
              active: showsManualInput,
              onTap: onToggleManualInput,
            ),
            const SizedBox(width: DeskflowSpacing.xs),
            _IconChipButton(
              icon: Icons.date_range_rounded,
              active: isRangeMode,
              onTap: onToggleRangeMode,
            ),
            const SizedBox(width: DeskflowSpacing.xs),
            _IconChipButton(
              icon: Icons.close_rounded,
              active: false,
              onTap: onClear,
            ),
          ],
        ),
        const SizedBox(height: DeskflowSpacing.xs),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 372 : 320,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onPreviousMonth,
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            monthLabel,
                            style: DeskflowTypography.bodySmall.copyWith(
                              fontSize: isShortViewport ? 14 : 15,
                              color: DeskflowColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: onPickYear,
                            borderRadius:
                                BorderRadius.circular(DeskflowRadius.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DeskflowSpacing.sm,
                                vertical: 2,
                              ),
                              child: Text(
                                '${visibleMonth.year}',
                                style: DeskflowTypography.caption.copyWith(
                                  fontSize: isShortViewport ? 9 : 10,
                                  color: DeskflowColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onNextMonth,
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                _InlineOrdersCalendar(
                  visibleMonth: visibleMonth,
                  selectedDate: selectedDate,
                  selectedDateRange: range,
                  draftRangeStart: draftRangeStart,
                  isRangeMode: isRangeMode,
                  onDateTap: onDateTap,
                  compact: !isWide,
                ),
              ],
            ),
          ),
        ),
        if (isRangeMode && draftRangeStart != null && range == null) ...[
          const SizedBox(height: DeskflowSpacing.sm),
          Text(
            'Выберите вторую дату диапазона',
            style: DeskflowTypography.caption,
          ),
        ],
      ],
    );
  }
}

class _AmountPanel extends StatefulWidget {
  const _AmountPanel({
    required this.amountDraftValues,
    required this.currentRange,
    required this.onChanged,
    required this.onApply,
    required this.onClear,
  });

  final RangeValues amountDraftValues;
  final OrderAmountRange? currentRange;
  final ValueChanged<RangeValues> onChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  State<_AmountPanel> createState() => _AmountPanelState();
}

class _AmountPanelState extends State<_AmountPanel> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  bool _editingMin = false;
  bool _editingMax = false;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: _formatAmount(widget.amountDraftValues.start),
    );
    _maxController = TextEditingController(
      text: _formatAmount(widget.amountDraftValues.end),
    );
  }

  @override
  void didUpdateWidget(covariant _AmountPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountDraftValues != widget.amountDraftValues) {
      if (!_editingMin) {
        _minController.text = _formatAmount(widget.amountDraftValues.start);
      }
      if (!_editingMax) {
        _maxController.text = _formatAmount(widget.amountDraftValues.end);
      }
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(0);
  }

  void _applyManualValues() {
    final min = double.tryParse(
          _minController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        widget.amountDraftValues.start;
    final max = double.tryParse(
          _maxController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        widget.amountDraftValues.end;

    final clampedMin = min.clamp(
      OrderAmountRange.boundsMin,
      OrderAmountRange.boundsMax,
    );
    final clampedMax = max.clamp(
      OrderAmountRange.boundsMin,
      OrderAmountRange.boundsMax,
    );
    final effectiveMin = clampedMin <= clampedMax ? clampedMin : clampedMax;
    final effectiveMax = clampedMin <= clampedMax ? clampedMax : clampedMin;

    widget.onChanged(RangeValues(effectiveMin, effectiveMax));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            if (widget.currentRange != null)
              TextButton(
                onPressed: widget.onClear,
                child: const Text('Сбросить'),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'От',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.sm,
                    vertical: DeskflowSpacing.sm,
                  ),
                ),
                onTap: () => _editingMin = true,
                onEditingComplete: () {
                  _editingMin = false;
                  _applyManualValues();
                },
                onSubmitted: (_) {
                  _editingMin = false;
                  _applyManualValues();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DeskflowSpacing.sm,
              ),
              child: Text('—', style: DeskflowTypography.bodySmall),
            ),
            Expanded(
              child: TextField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'До',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.sm,
                    vertical: DeskflowSpacing.sm,
                  ),
                ),
                onTap: () => _editingMax = true,
                onEditingComplete: () {
                  _editingMax = false;
                  _applyManualValues();
                },
                onSubmitted: (_) {
                  _editingMax = false;
                  _applyManualValues();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: DeskflowSpacing.sm),
        RangeSlider(
          values: widget.amountDraftValues,
          min: OrderAmountRange.boundsMin,
          max: OrderAmountRange.boundsMax,
          divisions: 100,
          labels: RangeLabels(
            CurrencyFormatter.formatCompact(widget.amountDraftValues.start),
            CurrencyFormatter.formatCompact(widget.amountDraftValues.end),
          ),
          onChanged: widget.onChanged,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onApply,
            child: const Text('Применить'),
          ),
        ),
      ],
    );
  }
}

class _InlineOrdersCalendar extends StatelessWidget {
  const _InlineOrdersCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.selectedDateRange,
    required this.draftRangeStart,
    required this.isRangeMode,
    required this.onDateTap,
    this.compact = false,
  });

  static const _weekDays = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final OrderDateRange? selectedDateRange;
  final DateTime? draftRangeStart;
  final bool isRangeMode;
  final ValueChanged<DateTime> onDateTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final firstWeekdayOffset = firstDay.weekday - 1;
    final firstGridDay = firstDay.subtract(Duration(days: firstWeekdayOffset));
    final today = DateTime.now();
    final range = selectedDateRange?.normalized();
    final isShortViewport = MediaQuery.sizeOf(context).height < 620;

    return Container(
      key: const Key('orders-sort-calendar'),
      padding: const EdgeInsets.fromLTRB(
        DeskflowSpacing.xs,
        DeskflowSpacing.xs,
        DeskflowSpacing.xs,
        DeskflowSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DeskflowColors.modalSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(DeskflowRadius.card),
        border: Border.all(color: DeskflowColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: _weekDays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: DeskflowTypography.caption.copyWith(
                          fontSize: isShortViewport ? 9.5 : 10.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 1),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: compact ? 0 : 1,
              crossAxisSpacing: compact ? 0 : 1,
              childAspectRatio: compact ? 1.6 : 2.15,
            ),
            itemBuilder: (context, index) {
              final day = firstGridDay.add(Duration(days: index));
              final normalizedDay = DateTime(day.year, day.month, day.day);
              final inMonth = day.month == visibleMonth.month;
              final isSelected = selectedDate != null &&
                  selectedDate!.year == day.year &&
                  selectedDate!.month == day.month &&
                  selectedDate!.day == day.day;
              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final isDraftStart = draftRangeStart != null &&
                  draftRangeStart!.year == day.year &&
                  draftRangeStart!.month == day.month &&
                  draftRangeStart!.day == day.day;
              final inRange = range != null &&
                  !normalizedDay.isBefore(range.normalizedStart) &&
                  !normalizedDay.isAfter(range.normalizedEnd);
              final isRangeEdge = range != null &&
                  (normalizedDay == range.normalizedStart ||
                      normalizedDay == range.normalizedEnd);

              return InkWell(
                onTap: () => onDateTap(normalizedDay),
                borderRadius: BorderRadius.circular(DeskflowRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: inRange
                        ? DeskflowColors.primary.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(DeskflowRadius.md),
                    border: isToday && !isSelected && !isRangeEdge && !isDraftStart
                        ? Border.all(color: DeskflowColors.glassBorderStrong)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: compact
                        ? (isShortViewport ? 24 : 26)
                        : (isShortViewport ? 19 : 22),
                    height: compact
                        ? (isShortViewport ? 24 : 26)
                        : (isShortViewport ? 19 : 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected || isRangeEdge || isDraftStart
                          ? DeskflowColors.primarySolid.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                    child: Text(
                      '${day.day}',
                      style: DeskflowTypography.bodySmall.copyWith(
                        fontSize: compact
                            ? (isShortViewport ? 12 : 13)
                            : (isShortViewport ? 10.5 : 11),
                        color: inMonth
                            ? DeskflowColors.textPrimary
                            : DeskflowColors.textTertiary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeskflowRadius.pill),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? DeskflowColors.primary.withValues(alpha: 0.24)
              : DeskflowColors.glassSurface,
          borderRadius: BorderRadius.circular(DeskflowRadius.pill),
          border: Border.all(
            color: active
                ? DeskflowColors.glassBorderStrong
                : DeskflowColors.glassBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: DeskflowColors.textPrimary),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeskflowRadius.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.chevron_right_rounded,
              color: selected
                  ? DeskflowColors.primarySolid
                  : DeskflowColors.textSecondary,
            ),
            const SizedBox(width: DeskflowSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: DeskflowTypography.bodySmall.copyWith(
                  fontSize: 15,
                  color: selected
                      ? DeskflowColors.textPrimary
                      : DeskflowColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeskflowRadius.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: DeskflowColors.textSecondary),
            const SizedBox(width: DeskflowSpacing.md),
            Expanded(child: Text(label, style: DeskflowTypography.body)),
          ],
        ),
      ),
    );
  }
}
