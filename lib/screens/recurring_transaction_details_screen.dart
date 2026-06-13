import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/recurring_transaction_model.dart';
import '../providers/currency_provider.dart';
import '../providers/recurring_transaction_provider.dart';
import 'create_recurring_transaction_screen.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tutorial_service.dart';
import '../providers/tutorial_provider.dart';
class RecurringTransactionDetailsScreen extends ConsumerStatefulWidget {
  final RecurringTransaction transaction;

  const RecurringTransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<RecurringTransactionDetailsScreen> createState() =>
      _RecurringTransactionDetailsScreenState();
}

class _RecurringTransactionDetailsScreenState extends ConsumerState<RecurringTransactionDetailsScreen> {
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorialStatus();
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TallyTapTheme.borderGreen),
        ),
        title: const Text(
          'Delete Recurring Payment?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontSize: 20,
            fontFamily: 'Outfit',
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this recurring payment? This action cannot be undone.',
          style: TextStyle(color: TallyTapTheme.textGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(
                    color: TallyTapTheme.primaryMint,
                    fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              ref
                  .read(recurringTransactionsProvider.notifier)
                  .deleteTransaction(widget.transaction.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Recurring payment deleted'),
                backgroundColor: Color(0xFFEF4444),
              ));
            },
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRecurringTransactionScreen(
            existingTransaction: widget.transaction),
      ),
    ).then((_) {
      // Screen re-renders automatically as we listen to the provider if we pass just ID, 
      // but since we pass the object, let's just pop back to list since edit screen updates the DB.
      // Wait, passing the object as parameter makes it static here unless we watch the provider for this specific ID.
      // Let's modify the build method to watch for updates.
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for updates to this specific transaction
    final transactions = ref.watch(recurringTransactionsProvider);
    final tx = transactions.firstWhere(
      (t) => t.id == widget.transaction.id,
      orElse: () => widget.transaction,
    );

    final currency = ref.watch(currencyProvider);
    final isIncome = tx.type == TransactionType.income;
    final activeColor =
        isIncome ? const Color(0xFF10B981) : TallyTapTheme.primaryMint;

    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: TallyTapTheme.textLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payment Details',
          style: TextStyle(
            color: TallyTapTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: TallyTapTheme.primaryMint, size: 28),
            onPressed: _navigateToEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444)),
            onPressed: () {
              HapticFeedback.vibrate();
              _confirmDelete();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(tx, currency, activeColor),
                    const SizedBox(height: 24),
                    Container(
                      key: TutorialService.recurringDetailsTimelineKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionLabel(label: 'Schedule Timeline'),
                          const SizedBox(height: 12),
                          _buildTimelineCard(tx, activeColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: TutorialService.recurringDetailsActionsKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionLabel(label: 'Configuration Details'),
                          const SizedBox(height: 12),
                          _buildDetailsGrid(tx),
                        ],
                      ),
                    ),
                    if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel(label: 'Notes'),
                      const SizedBox(height: 12),
                      _buildNotesCard(tx),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildQuickActionsBar(tx, activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(RecurringTransaction tx, String currency, Color activeColor) {
    String statusText = tx.status.name.toUpperCase();
    Color statusColor = TallyTapTheme.textGray;
    if (tx.status == RecurringStatus.active) statusColor = activeColor;
    if (tx.status == RecurringStatus.paused) statusColor = Colors.orange;
    if (tx.status == RecurringStatus.completed) statusColor = Colors.blue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TallyTapTheme.borderGreen),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$currency${tx.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.textLight,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tx.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TallyTapTheme.textLight,
            ),
          ),
          if (tx.merchant != null && tx.merchant!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tx.merchant!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: TallyTapTheme.textGray,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineCard(RecurringTransaction tx, Color activeColor) {
    final nextAfterDue = RecurringTransaction.calculateNextDueDate(
        tx.nextDueDate, tx.frequency,
        interval: tx.frequencyInterval);

    bool isPastDue = tx.nextDueDate.isBefore(DateTime.now()) &&
        !tx.nextDueDate.isAtSameMomentAs(DateTime.now());
    bool isDueToday = _isToday(tx.nextDueDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TallyTapTheme.borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start Date
          _TimelineStep(
            title: 'Start Date',
            date: tx.startDate,
            isCompleted: true,
            color: TallyTapTheme.textGray,
            isLast: false,
          ),
          
          // Last Processed Date
          if (tx.lastProcessedDate != null)
            _TimelineStep(
              title: 'Last Processed',
              date: tx.lastProcessedDate!,
              isCompleted: true,
              color: TallyTapTheme.textGray,
              isLast: false,
            ),
          
          // Current Due Date
          _TimelineStep(
            title: 'Next Due',
            subtitle: isPastDue ? 'Past Due' : (isDueToday ? 'Due Today' : null),
            date: tx.nextDueDate,
            isCompleted: false,
            isActive: tx.status == RecurringStatus.active,
            color: isPastDue ? Colors.orange : activeColor,
            isLast: tx.endCondition != EndConditionType.never &&
                tx.isCompleted(tx.nextDueDate, tx.occurrencesCompleted + 1),
          ),
          
          // Future Date (if applicable)
          if (!(tx.endCondition != EndConditionType.never &&
              tx.isCompleted(tx.nextDueDate, tx.occurrencesCompleted + 1)))
            _TimelineStep(
              title: 'Following Due',
              date: nextAfterDue,
              isCompleted: false,
              color: TallyTapTheme.textGray.withOpacity(0.5),
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid(RecurringTransaction tx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TallyTapTheme.borderGreen),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.repeat_rounded,
            label: 'Frequency',
            value: _getFrequencyText(tx),
          ),
          const Divider(color: TallyTapTheme.borderGreen, height: 24),
          _DetailRow(
            icon: TallyTapTheme.getIconForCategory(tx.category, false),
            label: 'Category',
            value: tx.category,
            valueColor: TallyTapTheme.getColorForCategory(tx.category),
          ),
          const Divider(color: TallyTapTheme.borderGreen, height: 24),
          _DetailRow(
            icon: TallyTapTheme.getIconForSource(tx.paymentMethod),
            label: 'Payment Method',
            value: tx.paymentMethod,
            valueColor: TallyTapTheme.getColorForSource(tx.paymentMethod),
          ),
          const Divider(color: TallyTapTheme.borderGreen, height: 24),
          _DetailRow(
            icon: Icons.auto_mode_rounded,
            label: 'Automation',
            value: tx.autoCreate ? 'Auto-log payment' : 'Manual verification',
          ),
          if (tx.reminderEnabled && tx.reminderTiming != null) ...[
            const Divider(color: TallyTapTheme.borderGreen, height: 24),
            _DetailRow(
              icon: Icons.notifications_active_outlined,
              label: 'Reminder',
              value: _getReminderText(tx.reminderTiming!),
            ),
          ],
          if (tx.endCondition != EndConditionType.never) ...[
            const Divider(color: TallyTapTheme.borderGreen, height: 24),
            _DetailRow(
              icon: Icons.flag_circle_outlined,
              label: 'End Condition',
              value: _getEndConditionText(tx),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildNotesCard(RecurringTransaction tx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TallyTapTheme.borderGreen),
      ),
      child: Text(
        tx.notes!,
        style: const TextStyle(
          color: TallyTapTheme.textLight,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar(RecurringTransaction tx, Color activeColor) {
    bool isDue = tx.nextDueDate.isBefore(DateTime.now()) ||
        tx.nextDueDate.isAtSameMomentAs(DateTime.now());
    bool canMarkPaid = tx.status == RecurringStatus.active &&
        !tx.autoCreate &&
        isDue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        border: Border(top: BorderSide(color: TallyTapTheme.borderGreen.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Pause/Resume
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: tx.status == RecurringStatus.active
                      ? Colors.orange
                      : activeColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                tx.status == RecurringStatus.active
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: tx.status == RecurringStatus.active
                    ? Colors.orange
                    : activeColor,
              ),
              label: Text(
                tx.status == RecurringStatus.active ? 'Pause' : 'Resume',
                style: TextStyle(
                  color: tx.status == RecurringStatus.active
                      ? Colors.orange
                      : activeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(recurringTransactionsProvider.notifier).togglePause(tx.id);
              },
            ),
          ),
          const SizedBox(width: 12),
          // Mark Paid / Skip
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canMarkPaid ? activeColor : TallyTapTheme.obsidianCard,
                foregroundColor: canMarkPaid ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: canMarkPaid ? Colors.transparent : TallyTapTheme.borderGreen,
                  ),
                ),
                elevation: canMarkPaid ? 8 : 0,
                shadowColor: canMarkPaid ? activeColor.withOpacity(0.5) : Colors.transparent,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                if (canMarkPaid) {
                  ref.read(recurringTransactionsProvider.notifier).markAsPaid(tx.id);
                } else {
                  // If not due, just provide option to Skip Next
                  _confirmSkip(tx);
                }
              },
              child: Text(
                canMarkPaid ? 'Mark Paid' : 'Skip Next',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSkip(RecurringTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TallyTapTheme.obsidianCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TallyTapTheme.borderGreen),
        ),
        title: const Text('Skip Next Payment?',
            style: TextStyle(color: TallyTapTheme.textLight, fontFamily: 'Outfit')),
        content: Text(
            'This will skip the payment due on ${DateFormat('MMM d, y').format(tx.nextDueDate)}. This action cannot be undone.',
            style: const TextStyle(color: TallyTapTheme.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.primaryMint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(recurringTransactionsProvider.notifier).skip(tx.id);
              Navigator.pop(ctx);
            },
            child: const Text('Skip Payment'),
          ),
        ],
      ),
    );
  }

  // Helpers
  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _getFrequencyText(RecurringTransaction tx) {
    String intervalStr = tx.frequencyInterval > 1 ? '${tx.frequencyInterval} ' : '';
    String freqStr = tx.frequency.name;
    if (tx.frequencyInterval > 1) {
      if (freqStr == 'daily') freqStr = 'days';
      if (freqStr == 'weekly') freqStr = 'weeks';
      if (freqStr == 'monthly') freqStr = 'months';
      if (freqStr == 'yearly') freqStr = 'years';
    } else {
      if (freqStr == 'daily') freqStr = 'Daily';
      if (freqStr == 'weekly') freqStr = 'Weekly';
      if (freqStr == 'monthly') freqStr = 'Monthly';
      if (freqStr == 'yearly') freqStr = 'Yearly';
    }
    
    if (tx.frequencyInterval > 1) {
      return 'Every $intervalStr$freqStr';
    }
    return freqStr;
  }

  String _getReminderText(ReminderTiming timing) {
    switch (timing) {
      case ReminderTiming.atDueTime: return 'At time of event';
      case ReminderTiming.oneHourBefore: return '1 hour before';
      case ReminderTiming.sixHoursBefore: return '6 hours before';
      case ReminderTiming.twelveHoursBefore: return '12 hours before';
      case ReminderTiming.oneDayBefore: return '1 day before';
      case ReminderTiming.threeDaysBefore: return '3 days before';
      case ReminderTiming.oneWeekBefore: return '1 week before';
    }
  }

  String _getEndConditionText(RecurringTransaction tx) {
    if (tx.endCondition == EndConditionType.onDate && tx.endDate != null) {
      return 'On ${DateFormat('MMM d, y').format(tx.endDate!)}';
    } else if (tx.endCondition == EndConditionType.afterOccurrences && tx.endOccurrences != null) {
      return 'After ${tx.endOccurrences} payments (${tx.occurrencesCompleted} done)';
    }
    return 'Never';
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialRecurringTxDetails) ?? false;
    if (!hasSeen && mounted) {
      _initTutorial();
    }
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.6,
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      beforeFocus: (target) async {
        if (target.keyTarget?.currentContext != null) {
          Scrollable.ensureVisible(
            target.keyTarget!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 350));
        }
      },
      onClickOverlay: (target) {
        tutorialCoachMark?.next();
      },
      onFinish: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialRecurringTxDetails);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialRecurringTxDetails);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  Widget _buildTutorialContent(TutorialCoachMarkController controller, String title, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => controller.next(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TallyTapTheme.primaryMint,
              foregroundColor: TallyTapTheme.obsidianBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Next"),
          ),
        ),
      ],
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    targets.add(TargetFocus(
      identify: "TargetInfo",
      keyTarget: TutorialService.recurringDetailsTimelineKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Status & Schedule", "See when the next payment is due and review the schedule details."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetHistory",
      keyTarget: TutorialService.recurringDetailsActionsKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Configuration", "View your automation settings, end conditions, and complete payment source details here."),
        ),
      ],
    ));

    return targets;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: TallyTapTheme.textGray,
          letterSpacing: 0.5,
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TallyTapTheme.textGray, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? TallyTapTheme.textLight,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DateTime date;
  final bool isCompleted;
  final bool isActive;
  final Color color;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    this.subtitle,
    required this.date,
    required this.isCompleted,
    this.isActive = false,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and dot
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isCompleted ? color : TallyTapTheme.obsidianBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: isActive ? 4 : 2,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withOpacity(isCompleted ? 0.5 : 0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive ? TallyTapTheme.textLight : TallyTapTheme.textGray,
                          fontSize: isActive ? 15 : 14,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subtitle!,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMM d, y').format(date),
                    style: TextStyle(
                      color: isActive ? color : TallyTapTheme.textGray,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
