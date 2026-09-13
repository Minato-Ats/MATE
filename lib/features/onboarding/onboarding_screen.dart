import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/mate_copy.dart';
import '../../core/feedback.dart';
import '../../core/motion/mate_motion.dart';
import '../../data/local/preferences_service.dart';
import '../../state/overlay_access_controller.dart';
import '../../state/usage_access_controller.dart';

/// First-run flow stating MATE's positioning up front ("companion, not
/// blocker") before handing off to the usual app. Also reachable again from
/// Settings ("使い方をもう一度見る") in [replay] mode, which just pops back
/// instead of persisting completion again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false, this.onDone});

  final bool replay;

  /// Called once the flow finishes for a genuine first run. Ignored when
  /// [replay] is true.
  final VoidCallback? onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pageCount = 4;

  PreferencesService get _preferences => context.read<PreferencesService>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    MateFeedback.tap(_preferences);
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: MateMotion.settle, curve: MateMotion.curve);
  }

  void _back() {
    MateFeedback.tap(_preferences);
    _pageController.previousPage(duration: MateMotion.settle, curve: MateMotion.curve);
  }

  Future<void> _finish() async {
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    await _preferences.setOnboardingCompleted(true);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                children: const [
                  _WelcomePage(),
                  _HowItWorksPage(),
                  _PermissionsPage(),
                  _DonePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: MateMotion.quick,
                          curve: MateMotion.curve,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_page > 0)
                        TextButton(onPressed: _back, child: const Text(MateCopy.onboardingBack)),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                        child: Text(_page == _pageCount - 1 ? MateCopy.onboardingStart : MateCopy.onboardingNext),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.icon, required this.title, required this.body, this.child});

  final IconData icon;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(icon, size: 30, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 28),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(fontSize: 15, height: 1.6, color: colorScheme.onSurfaceVariant),
          ),
          if (child != null) ...[const SizedBox(height: 24), child!],
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingPage(
      icon: Icons.favorite_rounded,
      title: MateCopy.onboardingWelcomeTitle,
      body: MateCopy.onboardingWelcomeBody,
    );
  }
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingPage(
      icon: Icons.pause_circle_outline_rounded,
      title: MateCopy.onboardingHowTitle,
      body: MateCopy.onboardingHowBody,
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage();

  @override
  Widget build(BuildContext context) {
    final hasUsageAccess = context.watch<UsageAccessController>().hasAccess;
    final hasOverlayAccess = context.watch<OverlayAccessController>().hasAccess;

    return _OnboardingPage(
      icon: Icons.handshake_outlined,
      title: MateCopy.onboardingPermissionsTitle,
      body: MateCopy.onboardingPermissionsBody,
      child: Column(
        children: [
          _PermissionRow(
            granted: hasUsageAccess,
            title: MateCopy.onboardingPermissionUsageTitle,
            body: MateCopy.onboardingPermissionUsageBody,
            onGrant: () => context.read<UsageAccessController>().openSettings(),
          ),
          const SizedBox(height: 12),
          _PermissionRow(
            granted: hasOverlayAccess,
            title: MateCopy.onboardingPermissionOverlayTitle,
            body: MateCopy.onboardingPermissionOverlayBody,
            onGrant: () => context.read<OverlayAccessController>().openSettings(),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.granted,
    required this.title,
    required this.body,
    required this.onGrant,
  });

  final bool granted;
  final String title;
  final String body;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              granted ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: granted ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (!granted)
              TextButton(onPressed: onGrant, child: const Text(MateCopy.onboardingGrant))
            else
              Text(MateCopy.onboardingGranted, style: TextStyle(fontSize: 12, color: colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingPage(
      icon: Icons.celebration_outlined,
      title: MateCopy.onboardingDoneTitle,
      body: MateCopy.onboardingDoneBody,
    );
  }
}
