import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'budget_provider.dart';
import 'dashboard_provider.dart';

// ── Alert Severity ─────────────────────────────────────────────────────────

enum BudgetAlertSeverity { warning, danger, exceeded }

extension BudgetAlertSeverityX on BudgetAlertSeverity {
  Color get color {
    switch (this) {
      case BudgetAlertSeverity.warning:
        return const Color(0xFFF59E0B); // Amber
      case BudgetAlertSeverity.danger:
        return const Color(0xFFF97316); // Orange
      case BudgetAlertSeverity.exceeded:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetAlertSeverity.warning:
        return Icons.info_outline_rounded;
      case BudgetAlertSeverity.danger:
        return Icons.warning_amber_rounded;
      case BudgetAlertSeverity.exceeded:
        return Icons.error_outline_rounded;
    }
  }

  String get label {
    switch (this) {
      case BudgetAlertSeverity.warning:
        return 'Warning';
      case BudgetAlertSeverity.danger:
        return 'High';
      case BudgetAlertSeverity.exceeded:
        return 'Exceeded';
    }
  }
}

// ── Alert Model ────────────────────────────────────────────────────────────

class BudgetAlert {
  final String category;
  final double spent;
  final double limit;
  final BudgetAlertSeverity severity;

  const BudgetAlert({
    required this.category,
    required this.spent,
    required this.limit,
    required this.severity,
  });

  double get ratio => limit > 0 ? spent / limit : 0.0;
  double get percentUsed => ratio * 100;
  double get overspendAmount => spent - limit;
  double get remainingAmount => limit - spent;
}

// ── Thresholds Provider ────────────────────────────────────────────────────

class BudgetAlertThresholds {
  final double warningPct;  // default 50%
  final double dangerPct;   // default 75%

  const BudgetAlertThresholds({
    this.warningPct = 50.0,
    this.dangerPct = 75.0,
  });
}

class BudgetAlertThresholdsNotifier extends StateNotifier<BudgetAlertThresholds> {
  BudgetAlertThresholdsNotifier() : super(const BudgetAlertThresholds()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final warning = prefs.getDouble('alert_threshold_warning') ?? 50.0;
    final danger = prefs.getDouble('alert_threshold_danger') ?? 75.0;
    state = BudgetAlertThresholds(warningPct: warning, dangerPct: danger);
  }

  Future<void> setThresholds(double warningPct, double dangerPct) async {
    state = BudgetAlertThresholds(warningPct: warningPct, dangerPct: dangerPct);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('alert_threshold_warning', warningPct);
    await prefs.setDouble('alert_threshold_danger', dangerPct);
  }
}

final budgetAlertThresholdsProvider =
    StateNotifierProvider<BudgetAlertThresholdsNotifier, BudgetAlertThresholds>(
  (ref) => BudgetAlertThresholdsNotifier(),
);

// ── Computed Alerts Provider ───────────────────────────────────────────────

final budgetAlertsProvider = Provider<List<BudgetAlert>>((ref) {
  final limits = ref.watch(budgetLimitsProvider);
  final dashboard = ref.watch(dashboardProvider);
  final thresholds = ref.watch(budgetAlertThresholdsProvider);
  final spentPerCategory = dashboard.spentPerCategory;

  final alerts = <BudgetAlert>[];

  for (final entry in limits.entries) {
    final cat = entry.key;
    final limit = entry.value;
    final spent = spentPerCategory[cat] ?? 0.0;
    if (spent <= 0 || limit <= 0) continue;

    final ratio = spent / limit;
    final pct = ratio * 100;

    BudgetAlertSeverity? severity;
    if (pct > 100) {
      severity = BudgetAlertSeverity.exceeded;
    } else if (pct >= thresholds.dangerPct) {
      severity = BudgetAlertSeverity.danger;
    } else if (pct >= thresholds.warningPct) {
      severity = BudgetAlertSeverity.warning;
    }

    if (severity != null) {
      alerts.add(BudgetAlert(
        category: cat,
        spent: spent,
        limit: limit,
        severity: severity,
      ));
    }
  }

  // Sort: exceeded first, then danger, then warning
  alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
  return alerts;
});
