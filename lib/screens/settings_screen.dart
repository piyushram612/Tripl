import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/category_provider.dart';
import '../providers/source_provider.dart';
import '../services/platform_service.dart';
import 'calibration_screen.dart';
import 'sheets/manage_categories_sheet.dart';
import 'sheets/manage_sources_sheet.dart';
import 'sheets/manage_currency_sheet.dart';
import 'sheets/manage_profile_sheet.dart';
import 'recurring_transactions_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showManageCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageCategoriesSheet(),
    );
  }

  void _showManageSourcesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageSourcesSheet(),
    );
  }

  void _showManageCurrencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageCurrencySheet(),
    );
  }

  void _showManageProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageProfileSheet(),
    );
  }

  void _showCalibrationScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CalibrationScreen(fromSettings: true),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B17),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
        ),
        child: Icon(icon, color: TallyTapTheme.primaryMint, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: TallyTapTheme.textGray),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backTapEnabled = ref.watch(backTapEnabledProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: TallyTapTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),

            // Double Back Tap Toggle Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HARDWARE INTERACTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1B17),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.vibration_rounded,
                            color: TallyTapTheme.primaryMint,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Triple Back Tap',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Triple tap the back of your phone to trigger',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: backTapEnabled,
                          activeColor: TallyTapTheme.primaryMint,
                          onChanged: (val) {
                            ref.read(backTapEnabledProvider.notifier).toggle(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val
                                      ? "Back Tap Listener Service Started!"
                                      : "Back Tap Listener Service Stopped.",
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 32),
                    // Manual Test CTA Button
                    ElevatedButton(
                      onPressed: () => PlatformService.showPopup(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TallyTapTheme.primaryMint,
                        foregroundColor: TallyTapTheme.obsidianBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Test Quick Popup',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Re-calibrate button
                    OutlinedButton(
                      onPressed: () => _showCalibrationScreen(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TallyTapTheme.primaryMint,
                        side: BorderSide(
                          color: TallyTapTheme.primaryMint.withOpacity(0.5),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Re-calibrate Triple Tap',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card B: Data Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'DATA CONFIGURATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.person_rounded,
                      title: 'Customize Profile',
                      subtitle: 'Change your dashboard username',
                      onTap: () => _showManageProfileSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.category_rounded,
                      title: 'Manage Categories',
                      subtitle: 'Add or remove custom expense categories',
                      onTap: () => _showManageCategoriesSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Manage Payment Sources',
                      subtitle: 'Configure custom cash or bank accounts',
                      onTap: () => _showManageSourcesSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.monetization_on_rounded,
                      title: 'Manage Currency',
                      subtitle: 'Select your preferred global currency',
                      onTap: () => _showManageCurrencySheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.autorenew_rounded,
                      title: 'Manage Recurring Payments',
                      subtitle: 'View and edit your automated transactions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RecurringTransactionsListScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Shortcut Guide Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SHORTCUT GUIDE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '1. Static Shortcuts',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Long press TallyTap icon on your phone launcher, select "Quick Add" to trigger instant overlays under 100ms.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
