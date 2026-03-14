enum OrdersPeriodPreset {
  all,
  today,
  last7Days,
  last30Days;

  String get label {
    switch (this) {
      case OrdersPeriodPreset.all:
        return 'Все время';
      case OrdersPeriodPreset.today:
        return 'Сегодня';
      case OrdersPeriodPreset.last7Days:
        return '7 дней';
      case OrdersPeriodPreset.last30Days:
        return '30 дней';
    }
  }
}

class OrderDateRange {
  const OrderDateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  DateTime get normalizedStart => _stripTime(start.isBefore(end) ? start : end);
  DateTime get normalizedEnd => _stripTime(start.isBefore(end) ? end : start);

  OrderDateRange normalized() {
    return OrderDateRange(
      start: normalizedStart,
      end: normalizedEnd,
    );
  }

  static DateTime _stripTime(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderDateRange &&
        other.normalizedStart == normalizedStart &&
        other.normalizedEnd == normalizedEnd;
  }

  @override
  int get hashCode => Object.hash(normalizedStart, normalizedEnd);
}

class OrderAmountRange {
  const OrderAmountRange({
    required this.min,
    required this.max,
  });

  static const double boundsMin = 0;
  static const double boundsMax = 1000000;
  static const full = OrderAmountRange(min: boundsMin, max: boundsMax);

  final double min;
  final double max;

  bool get isFullRange => min <= boundsMin && max >= boundsMax;

  @override
  bool operator ==(Object other) {
    return other is OrderAmountRange &&
        other.min == min &&
        other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}

class OrdersListControls {
  const OrdersListControls({
    this.periodPreset = OrdersPeriodPreset.all,
    this.selectedDate,
    this.selectedDateRange,
    this.amountRange,
  });

  final OrdersPeriodPreset periodPreset;
  final DateTime? selectedDate;
  final OrderDateRange? selectedDateRange;
  final OrderAmountRange? amountRange;

  OrdersListControls copyWith({
    OrdersPeriodPreset? periodPreset,
    bool clearPeriodPreset = false,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    OrderDateRange? selectedDateRange,
    bool clearSelectedDateRange = false,
    OrderAmountRange? amountRange,
    bool clearAmountRange = false,
  }) {
    final nextSelectedDateRange = clearSelectedDateRange
        ? null
        : periodPreset != null && periodPreset != OrdersPeriodPreset.all
        ? null
        : selectedDate != null
        ? null
        : selectedDateRange ?? this.selectedDateRange;

    final nextSelectedDate = clearSelectedDate
        ? null
        : periodPreset != null && periodPreset != OrdersPeriodPreset.all
        ? null
        : selectedDateRange != null
        ? null
        : selectedDate ?? this.selectedDate;

    final nextPeriodPreset = clearPeriodPreset
        ? OrdersPeriodPreset.all
        : selectedDate != null || selectedDateRange != null
        ? OrdersPeriodPreset.all
        : periodPreset ?? this.periodPreset;

    return OrdersListControls(
      periodPreset: nextPeriodPreset,
      selectedDate: nextSelectedDate == null
          ? null
          : DateTime(
              nextSelectedDate.year,
              nextSelectedDate.month,
              nextSelectedDate.day,
            ),
      selectedDateRange: nextSelectedDateRange?.normalized(),
      amountRange: clearAmountRange ? null : amountRange ?? this.amountRange,
    );
  }
}
