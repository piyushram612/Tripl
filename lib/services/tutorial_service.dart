import 'package:flutter/material.dart';

class TutorialService {
  // Home Screen Targets
  static final GlobalKey homeAccountsKey = GlobalKey();
  static final GlobalKey homeSummaryKey = GlobalKey();

  // Main Screen Targets
  static final GlobalKey mainFabKey = GlobalKey();
  static final GlobalKey mainNavHomeKey = GlobalKey();
  static final GlobalKey mainNavBudgetsKey = GlobalKey();
  static final GlobalKey mainNavInsightsKey = GlobalKey();
  static final GlobalKey mainNavTimelineKey = GlobalKey();
  static final GlobalKey mainNavToolkitKey = GlobalKey();

  // Budgets Screen Targets
  static final GlobalKey budgetsRingKey = GlobalKey();
  static final GlobalKey budgetsManageKey = GlobalKey();

  // Insights Screen Targets
  static final GlobalKey insightsDonutKey = GlobalKey();

  // Timeline Screen Targets
  static final GlobalKey timelineSearchKey = GlobalKey();

  // Toolkit Screen Targets
  static final GlobalKey toolkitDataConfigKey = GlobalKey();
  static final GlobalKey toolkitToolsKey = GlobalKey();
  static final GlobalKey toolkitNotificationsKey = GlobalKey();
  static final GlobalKey toolkitExportKey = GlobalKey();
  static final GlobalKey toolkitShortcutKey = GlobalKey();
  static final GlobalKey toolkitDangerKey = GlobalKey();
  static final GlobalKey toolkitReplayKey = GlobalKey();

  // New Home Targets
  static final GlobalKey homeCategoryKey = GlobalKey();
  static final GlobalKey homeRecentTxKey = GlobalKey();

  // New Budgets Targets
  static final GlobalKey budgetsEnvelopesListKey = GlobalKey();
  static final GlobalKey budgetsRecentKey = GlobalKey();

  // New Insights Targets
  static final GlobalKey insightsPillEssentialKey = GlobalKey();
  static final GlobalKey insightsPillJoyfulKey = GlobalKey();
  static final GlobalKey insightsPillAvoidableKey = GlobalKey();
  static final GlobalKey insightsPillInvestKey = GlobalKey();
  static final GlobalKey insightsBudgetSplitKey = GlobalKey();
  static final GlobalKey insightsDailyKey = GlobalKey();
  static final GlobalKey insightsCategoryBreakdownKey = GlobalKey();

  // Create Transaction Targets
  static final GlobalKey createTxAmountKey = GlobalKey();
  static final GlobalKey createTxCategoryKey = GlobalKey();
  static final GlobalKey createTxSaveKey = GlobalKey();
  static final GlobalKey createTxFinishLaterKey = GlobalKey();

  // Recurring Transaction Targets
  static final GlobalKey recurringTxListKey = GlobalKey();
  static final GlobalKey recurringTxFabKey = GlobalKey();

  // Create Recurring Transaction Targets
  static final GlobalKey createRecurringTemplateKey = GlobalKey();
  static final GlobalKey createRecurringAutoLogKey = GlobalKey();
  static final GlobalKey createRecurringSaveKey = GlobalKey();

  // Recurring Details Targets
  static final GlobalKey recurringDetailsTimelineKey = GlobalKey();
  static final GlobalKey recurringDetailsActionsKey = GlobalKey();

  // Adjust Budget Targets
  static final GlobalKey adjustBudgetGlobalKey = GlobalKey();
  static final GlobalKey adjustBudgetCategoryKey = GlobalKey();

  // Expense Splitter Targets
  static final GlobalKey splitterAmountKey = GlobalKey();
  static final GlobalKey splitterResultKey = GlobalKey();

  // Tip Calculator Targets
  static final GlobalKey tipAmountKey = GlobalKey();
  static final GlobalKey tipSliderKey = GlobalKey();
  static final GlobalKey tipSplitKey = GlobalKey();

  // Ledger Targets
  static final GlobalKey ledgerWhoOwesMeKey = GlobalKey();
  static final GlobalKey ledgerWhoIOweKey = GlobalKey();

  // Triple Tap Targets
  static final GlobalKey tripleTapDragHandleKey = GlobalKey();
  static final GlobalKey tripleTapControlsKey = GlobalKey();
}
