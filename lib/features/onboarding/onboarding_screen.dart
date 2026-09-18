import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_gate.dart';
import 'onboarding_prefs.dart';
import 'terms_screen.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.shield_moon_outlined,
    color: AppColors.seed,
    title: 'One app, campus and beyond',
    body:
        'SafeStep treats NMU\'s Summerstrand campuses and the surrounding '
        'suburb as one continuous safety area — not two separate systems.',
  ),
  _OnboardingSlide(
    icon: Icons.campaign_outlined,
    color: AppColors.alert,
    title: 'Help, one hold away',
    body:
        'Hold the SOS button for 3 seconds to alert responders covering '
        'your zone and every trusted contact you\'ve added — instantly.',
  ),
  _OnboardingSlide(
    icon: Icons.directions_walk,
    color: AppColors.safe,
    title: 'Never walk alone',
    body:
        'Invite a companion to watch your journey live, or set a timer — '
        'if you miss a check-in, we escalate automatically.',
  ),
  _OnboardingSlide(
    icon: Icons.groups_outlined,
    color: Color(0xFF7C3AED),
    title: 'Built with your community',
    body:
        'Report concerns, join walking groups, and share verified safety '
        'tips — all in one place, all private by default.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TermsScreen(onAccepted: _acceptTerms)),
    );
  }

  Future<void> _acceptTerms() async {
    await OnboardingPrefs.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: slide.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 40, color: slide.color),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ElevatedButton(
                onPressed: isLast
                    ? _finish
                    : () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      ),
                child: Text(isLast ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
