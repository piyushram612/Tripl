import 'package:flutter/foundation.dart';

class FilterCriteria {
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final List<String> categories;
  final List<String> paymentMethods;
  final bool? needsVerification;

  FilterCriteria({
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.categories = const [],
    this.paymentMethods = const [],
    this.needsVerification,
  });

  FilterCriteria copyWith({
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    List<String>? categories,
    List<String>? paymentMethods,
    bool? needsVerification,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearNeedsVerification = false,
  }) {
    return FilterCriteria(
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      minAmount: clearMinAmount ? null : minAmount ?? this.minAmount,
      maxAmount: clearMaxAmount ? null : maxAmount ?? this.maxAmount,
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      needsVerification: clearNeedsVerification ? null : needsVerification ?? this.needsVerification,
    );
  }

  bool get isActive {
    return startDate != null ||
        endDate != null ||
        minAmount != null ||
        maxAmount != null ||
        categories.isNotEmpty ||
        paymentMethods.isNotEmpty ||
        needsVerification != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FilterCriteria &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.minAmount == minAmount &&
        other.maxAmount == maxAmount &&
        listEquals(other.categories, categories) &&
        listEquals(other.paymentMethods, paymentMethods) &&
        other.needsVerification == needsVerification;
  }

  @override
  int get hashCode {
    return startDate.hashCode ^
        endDate.hashCode ^
        minAmount.hashCode ^
        maxAmount.hashCode ^
        categories.hashCode ^
        paymentMethods.hashCode ^
        needsVerification.hashCode;
  }
}
