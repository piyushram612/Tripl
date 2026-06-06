import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
const String kPrefTutorialPrimary = 'has_seen_tutorial_primary';
const String kPrefTutorialCreateTx = 'has_seen_tutorial_create_tx';
const String kPrefTutorialRecurringTx = 'has_seen_tutorial_recurring_tx';
const String kPrefTutorialAdjustBudget = 'has_seen_tutorial_adjust_budget';
const String kPrefTutorialExpenseSplitter = 'has_seen_tutorial_expense_splitter';
const String kPrefTutorialTipCalc = 'has_seen_tutorial_tip_calc';
const String kPrefTutorialLedger = 'has_seen_tutorial_ledger';
const String kPrefTutorialTripleTap = 'has_seen_tutorial_triple_tap';
const String kPrefTutorialCreateRecurringTx = 'has_seen_tutorial_create_recurring_tx';
const String kPrefTutorialRecurringTxDetails = 'has_seen_tutorial_recurring_tx_details';

class TutorialFlags {
  final bool primary;
  final bool createTx;
  final bool recurringTx;
  final bool adjustBudget;
  final bool expenseSplitter;
  final bool tipCalc;
  final bool ledger;
  final bool tripleTap;
  final bool createRecurringTx;
  final bool recurringTxDetails;

  const TutorialFlags({
    required this.primary,
    required this.createTx,
    required this.recurringTx,
    required this.adjustBudget,
    required this.expenseSplitter,
    required this.tipCalc,
    required this.ledger,
    required this.tripleTap,
    required this.createRecurringTx,
    required this.recurringTxDetails,
  });

  TutorialFlags copyWith({
    bool? primary,
    bool? createTx,
    bool? recurringTx,
    bool? adjustBudget,
    bool? expenseSplitter,
    bool? tipCalc,
    bool? ledger,
    bool? tripleTap,
    bool? createRecurringTx,
    bool? recurringTxDetails,
  }) {
    return TutorialFlags(
      primary: primary ?? this.primary,
      createTx: createTx ?? this.createTx,
      recurringTx: recurringTx ?? this.recurringTx,
      adjustBudget: adjustBudget ?? this.adjustBudget,
      expenseSplitter: expenseSplitter ?? this.expenseSplitter,
      tipCalc: tipCalc ?? this.tipCalc,
      ledger: ledger ?? this.ledger,
      tripleTap: tripleTap ?? this.tripleTap,
      createRecurringTx: createRecurringTx ?? this.createRecurringTx,
      recurringTxDetails: recurringTxDetails ?? this.recurringTxDetails,
    );
  }
}

final tutorialProvider = StateNotifierProvider<TutorialNotifier, TutorialFlags>((ref) {
  return TutorialNotifier();
});

class TutorialNotifier extends StateNotifier<TutorialFlags> {
  TutorialNotifier()
      : super(const TutorialFlags(
          primary: false,
          createTx: false,
          recurringTx: false,
          adjustBudget: false,
          expenseSplitter: false,
          tipCalc: false,
          ledger: false,
          tripleTap: false,
          createRecurringTx: false,
          recurringTxDetails: false,
        )) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Migrate from the old key if it exists
    final oldSeen = prefs.getBool('has_seen_tutorial');
    if (oldSeen != null && oldSeen) {
      await prefs.setBool(kPrefTutorialPrimary, true);
      await prefs.remove('has_seen_tutorial');
    }

    state = TutorialFlags(
      primary: prefs.getBool(kPrefTutorialPrimary) ?? false,
      createTx: prefs.getBool(kPrefTutorialCreateTx) ?? false,
      recurringTx: prefs.getBool(kPrefTutorialRecurringTx) ?? false,
      adjustBudget: prefs.getBool(kPrefTutorialAdjustBudget) ?? false,
      expenseSplitter: prefs.getBool(kPrefTutorialExpenseSplitter) ?? false,
      tipCalc: prefs.getBool(kPrefTutorialTipCalc) ?? false,
      ledger: prefs.getBool(kPrefTutorialLedger) ?? false,
      tripleTap: prefs.getBool(kPrefTutorialTripleTap) ?? false,
      createRecurringTx: prefs.getBool(kPrefTutorialCreateRecurringTx) ?? false,
      recurringTxDetails: prefs.getBool(kPrefTutorialRecurringTxDetails) ?? false,
    );
  }

  Future<void> markCompleted(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);

    switch (key) {
      case kPrefTutorialPrimary:
        state = state.copyWith(primary: true);
        break;
      case kPrefTutorialCreateTx:
        state = state.copyWith(createTx: true);
        break;
      case kPrefTutorialRecurringTx:
        state = state.copyWith(recurringTx: true);
        break;
      case kPrefTutorialAdjustBudget:
        state = state.copyWith(adjustBudget: true);
        break;
      case kPrefTutorialExpenseSplitter:
        state = state.copyWith(expenseSplitter: true);
        break;
      case kPrefTutorialTipCalc:
        state = state.copyWith(tipCalc: true);
        break;
      case kPrefTutorialLedger:
        state = state.copyWith(ledger: true);
        break;
      case kPrefTutorialTripleTap:
        state = state.copyWith(tripleTap: true);
        break;
      case kPrefTutorialCreateRecurringTx:
        state = state.copyWith(createRecurringTx: true);
        break;
      case kPrefTutorialRecurringTxDetails:
        state = state.copyWith(recurringTxDetails: true);
        break;
    }
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefTutorialPrimary, false);
    await prefs.setBool(kPrefTutorialCreateTx, false);
    await prefs.setBool(kPrefTutorialRecurringTx, false);
    await prefs.setBool(kPrefTutorialAdjustBudget, false);
    await prefs.setBool(kPrefTutorialExpenseSplitter, false);
    await prefs.setBool(kPrefTutorialTipCalc, false);
    await prefs.setBool(kPrefTutorialLedger, false);
    await prefs.setBool(kPrefTutorialTripleTap, false);
    await prefs.setBool(kPrefTutorialCreateRecurringTx, false);
    await prefs.setBool(kPrefTutorialRecurringTxDetails, false);

    state = const TutorialFlags(
      primary: false,
      createTx: false,
      recurringTx: false,
      adjustBudget: false,
      expenseSplitter: false,
      tipCalc: false,
      ledger: false,
      tripleTap: false,
      createRecurringTx: false,
      recurringTxDetails: false,
    );
  }
}
