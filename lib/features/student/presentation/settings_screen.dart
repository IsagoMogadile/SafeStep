import 'package:flutter/material.dart';

import '../../../core/accessibility/font_scale_controller.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/auth/biometric_lock_prefs.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/l10n/app_locale_controller.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'notification_preferences_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  bool _biometricSupported = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await BiometricService.isDeviceSupported();
    final enabled = await BiometricLockPrefs.isEnabled();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometricEnabled(bool value) async {
    // Require a successful auth before turning the lock on, so the
    // student can't lock themselves out with an unenrolled sensor.
    if (value) {
      final ok = await BiometricService.authenticate(
        reason: 'Verify it\'s you to enable app lock',
      );
      if (!ok) return;
    }
    await BiometricLockPrefs.setEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  Future<void> _pickLanguage(BuildContext context, Locale? current) async {
    final picked = await showDialog<Locale>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a language'),
        children: supportedLocales.map((locale) {
          final selected = (current?.languageCode ?? 'en') == locale.languageCode;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(locale),
            child: Row(
              children: [
                if (selected)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 10),
                Text(localeNames[locale.languageCode]!),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null) await AppLocaleController.instance.setLocale(picked);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 36,
        ),
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, trusted contacts, '
          'reports, walk history, and group memberships. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      await SupabaseService.client
          .from('students')
          .delete()
          .eq('student_id', userId);
      await SupabaseService.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete account. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance,
            builder: (context, mode, _) {
              return SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) =>
                    ThemeController.instance.setMode(selection.first),
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Accessibility', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: FontScaleController.instance,
            builder: (context, scale, _) {
              final currentLabel = FontScaleController.steps.entries
                  .firstWhere(
                    (e) => e.value == scale,
                    orElse: () => const MapEntry('Default', 1.0),
                  )
                  .key;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Text size'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: FontScaleController.steps.keys
                        .map((label) => ButtonSegment(value: label, label: Text(label)))
                        .toList(),
                    selected: {currentLabel},
                    onSelectionChanged: (selection) => FontScaleController.instance
                        .setScale(FontScaleController.steps[selection.first]!),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: TtsService.instance,
            builder: (context, enabled, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Text-to-speech'),
                subtitle: const Text(
                  'Adds a "Listen" button to read key screens aloud',
                ),
                value: enabled,
                onChanged: TtsService.instance.setEnabled,
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Locale?>(
            valueListenable: AppLocaleController.instance,
            builder: (context, locale, _) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_outlined),
                title: const Text('Language'),
                subtitle: Text(localeNames[locale?.languageCode] ?? 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context, locale),
              );
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen(),
              ),
            ),
          ),
          if (_biometricSupported) ...[
            const SizedBox(height: 24),
            Text('Security', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Require Face/Touch ID to open app'),
              subtitle: const Text('Adds a lock screen on launch and after backgrounding'),
              value: _biometricEnabled,
              onChanged: _setBiometricEnabled,
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              title: Text(
                'Delete Account',
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Permanently remove your account and data'),
              trailing: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isDeleting ? null : _confirmDelete,
            ),
          ),
        ],
      ),
    );
  }
}
