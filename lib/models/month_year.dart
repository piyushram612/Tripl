class MonthYear {
  final int year;
  final int month;

  const MonthYear(this.year, this.month);

  factory MonthYear.now() {
    final now = DateTime.now();
    return MonthYear(now.year, now.month);
  }

  factory MonthYear.fromYearMonthString(String ym) {
    // Format: "YYYY-MM"
    final parts = ym.split('-');
    if (parts.length >= 2) {
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      return MonthYear(y, m);
    }
    return MonthYear.now();
  }

  bool isAfter(MonthYear other) {
    if (year != other.year) {
      return year > other.year;
    }
    return month > other.month;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthYear && runtimeType == other.runtimeType && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;

  String get displayName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) {
      return '${months[month - 1]} $year';
    }
    return '$month $year';
  }

  String get shortName {
    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return '${shortMonths[month - 1]} $year';
    }
    return '$month $year';
  }

  String toYearMonthString() {
    return '$year-${month.toString().padLeft(2, '0')}';
  }
}
