import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

import 'screens/s01_welcome.dart';
import 'screens/s02_search.dart';
import 'screens/s03_doctor_profile.dart';
import 'screens/s04_favorites.dart';
import 'screens/s05_promotions.dart';
import 'screens/s06_personal_gifts.dart';
import 'screens/s07_booking.dart';
import 'screens/s08_chat.dart';
import 'screens/s09_visit_reports.dart';
import 'screens/s10_documents.dart';
import 'screens/s11_health.dart';
import 'screens/s12_notes.dart';
import 'screens/s13_relatives.dart';
import 'screens/s14_loyalty_intro.dart';
import 'screens/s15_earn_points.dart';
import 'screens/s16_vouchers.dart';
import 'screens/s17_referral.dart';
import 'screens/s18_all_set.dart';
import 'widgets/wizard_background.dart';
import 'widgets/wizard_next_button.dart';
import 'widgets/wizard_page_dots.dart';
import 'widgets/wizard_skip_button.dart';

const int kWelcomeWizardScreenCount = 18;

/// Host page for the welcome wizard. Owns the PageController, the cubit, and
/// the chrome (skip / dots / next). Each page is a small stateful widget that
/// renders a screen-specific composition.
///
/// Caller must provide [firstName] (used on screens 01 + 18) and the entry
/// mode. On completion the cubit emits `completed = true` and this screen
/// listens for it to handle the appropriate exit (push home for firstTime,
/// pop for replay).
class WelcomeWizardScreen extends StatefulWidget {
  final WizardEntryMode entryMode;
  final String firstName;
  final VoidCallback onCompleteFirstTime; // navigates to pending-links → home
  final VoidCallback onCompleteReplay;    // Navigator.pop()

  const WelcomeWizardScreen({
    super.key,
    required this.entryMode,
    required this.firstName,
    required this.onCompleteFirstTime,
    required this.onCompleteReplay,
  });

  @override
  State<WelcomeWizardScreen> createState() => _WelcomeWizardScreenState();
}

class _WelcomeWizardScreenState extends State<WelcomeWizardScreen> {
  late final PageController _pageController;
  late final WelcomeWizardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cubit = WelcomeWizardCubit(
      entryMode: widget.entryMode,
      totalPages: kWelcomeWizardScreenCount,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cubit.close();
    super.dispose();
  }

  bool _onPopInvoked() {
    if (_cubit.state.currentPage == 0) {
      // On screen 1, treat back as skip.
      _cubit.skip();
      return false;
    }
    _cubit.previous();
    return false;
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return S01Welcome(firstName: widget.firstName);
      case 1: return S02Search(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 2: return S03DoctorProfile(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 3: return S04Favorites(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 4: return const S05Promotions();
      case 5: return const S06PersonalGifts();
      case 6: return S07Booking(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 7: return S08Chat(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 8: return S09VisitReports(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 9: return S10Documents(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 10: return const S11Health();
      case 11: return S12Notes(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 12: return S13Relatives(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 13: return const S14LoyaltyIntro();
      case 14: return const S15EarnPoints();
      case 15: return const S16Vouchers();
      case 16: return const S17Referral();
      case 17: return S18AllSet(firstName: widget.firstName);
      default: throw RangeError('Unknown screen index $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<WelcomeWizardCubit, WelcomeWizardState>(
        listenWhen: (p, c) =>
            p.completed != c.completed || p.currentPage != c.currentPage,
        listener: (context, state) {
          if (state.completed) {
            if (state.entryMode == WizardEntryMode.firstTime) {
              widget.onCompleteFirstTime();
            } else {
              widget.onCompleteReplay();
            }
            return;
          }
          // sync page controller to cubit's currentPage
          if (_pageController.hasClients &&
              _pageController.page?.round() != state.currentPage) {
            _pageController.animateToPage(
              state.currentPage,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOut,
            );
          }
        },
        builder: (context, state) {
          final isLast = state.currentPage == kWelcomeWizardScreenCount - 1;
          final nextLabel = isLast
              ? (state.entryMode == WizardEntryMode.replay
                  ? l.wizard_done
                  : l.wizard_lets_begin)
              : null;

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _onPopInvoked();
            },
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: Stack(
                  children: [
                    const WizardBackground(),
                    PageView.builder(
                      controller: _pageController,
                      itemCount: kWelcomeWizardScreenCount,
                      onPageChanged: (i) => _cubit.jumpTo(i),
                      itemBuilder: (context, index) => _buildPage(index),
                    ),
                    WizardSkipButton(onTap: _cubit.skip),
                    WizardPageDots(
                      total: kWelcomeWizardScreenCount,
                      current: state.currentPage,
                      onJump: _cubit.jumpTo,
                    ),
                    WizardNextButton(
                      onTap: _cubit.next,
                      label: nextLabel,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
