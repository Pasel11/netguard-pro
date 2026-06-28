import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lottie/lottie.dart';
import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/utils/theme.dart';
import 'package:netguard_pro/screens/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  
  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.shield,
      color: AppTheme.primary,
      titleKey: 'onboarding.welcome_title',
      descKey: 'onboarding.welcome_desc',
    ),
    _OnboardingPage(
      icon: Icons.security,
      color: AppTheme.warning,
      titleKey: 'onboarding.features_title',
      descKey: 'onboarding.features_desc',
    ),
    _OnboardingPage(
      icon: Icons.warning_amber,
      color: AppTheme.error,
      titleKey: 'onboarding.legal_title',
      descKey: 'onboarding.legal_desc',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(loc.t('common.skip')),
                ),
              ),
            ),
            
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page, loc);
                },
              ),
            ),
            
            // Indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _pages.length,
                effect: WormEffect(
                  dotColor: AppTheme.textMuted,
                  activeDotColor: _pages[_currentPage].color,
                  dotHeight: 8,
                  dotWidth: 8,
                ),
              ),
            ),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(loc.t('common.back')),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(_currentPage == _pages.length - 1 
                        ? Icons.check : Icons.arrow_forward),
                    label: Text(_currentPage == _pages.length - 1 
                        ? loc.t('common.get_started')
                        : loc.t('common.next')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPage(_OnboardingPage page, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with animated background
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            loc.t(page.titleKey),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            loc.t(page.descKey),
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String titleKey;
  final String descKey;
  
  _OnboardingPage({
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.descKey,
  });
}
