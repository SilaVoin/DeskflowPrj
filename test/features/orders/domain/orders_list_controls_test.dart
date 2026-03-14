import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/features/orders/domain/orders_list_controls.dart';

void main() {
  group('OrdersListControls', () {
    test('defaults to empty date and amount filters', () {
      const controls = OrdersListControls();

      expect(controls.periodPreset, OrdersPeriodPreset.all);
      expect(controls.selectedDate, isNull);
      expect(controls.selectedDateRange, isNull);
      expect(controls.amountRange, isNull);
    });

    test('copyWith replaces date and amount filters', () {
      const controls = OrdersListControls();

      final updated = controls.copyWith(
        selectedDate: DateTime(2026, 3, 12),
        amountRange: const OrderAmountRange(min: 1000, max: 5000),
      );

      expect(updated.selectedDate, DateTime(2026, 3, 12));
      expect(updated.selectedDateRange, isNull);
      expect(
        updated.amountRange,
        const OrderAmountRange(min: 1000, max: 5000),
      );
    });

    test('setting a date resets period preset to all', () {
      const controls = OrdersListControls(
        periodPreset: OrdersPeriodPreset.last7Days,
      );

      final updated = controls.copyWith(
        selectedDate: DateTime(2026, 3, 12),
      );

      expect(updated.periodPreset, OrdersPeriodPreset.all);
      expect(updated.selectedDate, DateTime(2026, 3, 12));
      expect(updated.selectedDateRange, isNull);
    });

    test('setting a period clears selected date and range', () {
      final controls = OrdersListControls(
        selectedDate: DateTime(2026, 3, 12),
        selectedDateRange: OrderDateRange(
          start: DateTime(2026, 3, 12),
          end: DateTime(2026, 3, 18),
        ),
      );

      final updated = controls.copyWith(
        periodPreset: OrdersPeriodPreset.last30Days,
      );

      expect(updated.periodPreset, OrdersPeriodPreset.last30Days);
      expect(updated.selectedDate, isNull);
      expect(updated.selectedDateRange, isNull);
    });

    test('setting a date range resets period and clears single date', () {
      final controls = OrdersListControls(
        periodPreset: OrdersPeriodPreset.last7Days,
        selectedDate: DateTime(2026, 3, 12),
      );

      final updated = controls.copyWith(
        selectedDateRange: OrderDateRange(
          start: DateTime(2026, 3, 18),
          end: DateTime(2026, 3, 12),
        ),
      );

      expect(updated.periodPreset, OrdersPeriodPreset.all);
      expect(updated.selectedDate, isNull);
      expect(
        updated.selectedDateRange,
        OrderDateRange(
          start: DateTime(2026, 3, 12),
          end: DateTime(2026, 3, 18),
        ),
      );
    });

    test('copyWith can clear date, range, and amount filters', () {
      final controls = OrdersListControls(
        selectedDate: DateTime(2026, 3, 12),
        selectedDateRange: OrderDateRange(
          start: DateTime(2026, 3, 12),
          end: DateTime(2026, 3, 14),
        ),
        amountRange: const OrderAmountRange(min: 1000, max: 5000),
      );

      final updated = controls.copyWith(
        clearPeriodPreset: true,
        clearSelectedDate: true,
        clearSelectedDateRange: true,
        clearAmountRange: true,
      );

      expect(updated.periodPreset, OrdersPeriodPreset.all);
      expect(updated.selectedDate, isNull);
      expect(updated.selectedDateRange, isNull);
      expect(updated.amountRange, isNull);
    });
  });
}
