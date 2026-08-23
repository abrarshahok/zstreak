import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../auth/presentation/sign_in_screen.dart';
import '../application/onboarding_providers.dart';
import '../application/user_profile_provider.dart';

/// 4-step personalisation questionnaire shown right after the splash.
///
/// Flow:
///   Splash → Questions (4 steps) → auto sign-in as guest → Home
///
/// The user never sees a sign-in/sign-up screen unless they choose to
/// "Sync to cloud" later from Settings or the in-app banner.
class UserProfileQuestionsScreen extends ConsumerStatefulWidget {
  const UserProfileQuestionsScreen({
    super.key,
    this.skipToSignIn = false,
    this.alreadySignedIn = false,
  });

  final bool skipToSignIn;

  /// True when the user is already signed in with a real account (Google /
  /// email link) but skipped the questionnaire. In this mode the screen
  /// saves profile data directly to Firestore and then marks onboarding
  /// complete so [AuthGate] routes to Home.
  final bool alreadySignedIn;

  @override
  ConsumerState<UserProfileQuestionsScreen> createState() =>
      _UserProfileQuestionsScreenState();
}

class _UserProfileQuestionsScreenState
    extends ConsumerState<UserProfileQuestionsScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _step = 0;
  bool _isBusy = false;

  // Step 0 — Name
  final _nameCtrl = TextEditingController();

  // Step 1 — Age (drum picker)
  // Starts at 22 as a visual default. Whatever is shown when the user
  // presses Continue is saved — the wheel always has a valid selection.
  int _selectedAge = 22;

  // Step 2 — Gender
  String? _gender;

  // Step 3 — Goals (multi-select)
  final List<String> _goals = [];

  static const _totalSteps = 4;

  static const _minAge = 10;
  static const _maxAge = 80;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    // Google already told us the account's display name — prefill it
    // rather than making a just-signed-in user retype what we already
    // know. Only when there's no locally-saved name yet, so it never
    // clobbers a name someone already chose to edit.
    final googleName = widget.alreadySignedIn
        ? ref.read(authRepositoryProvider).currentUser?.displayName
        : null;
    _nameCtrl.text = profile.name.isNotEmpty
        ? profile.name
        : (googleName ?? '');
    if (profile.age.isNotEmpty) {
      final parsed = int.tryParse(profile.age);
      if (parsed != null && parsed >= _minAge && parsed <= _maxAge) {
        _selectedAge = parsed;
      }
    }
    _gender = profile.gender.isEmpty ? null : profile.gender;
    _goals
      ..clear()
      ..addAll(profile.goals);

    if (widget.skipToSignIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToSignIn());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _saveCurrentStep();
    if (_step < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finishAndEnterApp();
    }
  }

  void _back() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // This screen is the root route (e.g. AuthGate rendered it directly
      // for a signed-in user with no profile). Pop the whole app instead
      // of leaving a black screen.
      SystemNavigator.pop();
    }
  }

  void _saveCurrentStep() {
    final notifier = ref.read(userProfileProvider.notifier);
    switch (_step) {
      case 0:
        notifier.setName(_nameCtrl.text);
      case 1:
        notifier.setAge(_selectedAge.toString());
      case 2:
        if (_gender != null) notifier.setGender(_gender!);
      case 3:
        notifier.setGoals(_goals);
    }
  }

  Future<void> _finishAndEnterApp() async {
    final notifier = ref.read(userProfileProvider.notifier);
    final authRepo = ref.read(authRepositoryProvider);
    final uid = authRepo.currentUser?.uid;
    final isSignedIn =
        widget.alreadySignedIn ||
        (authRepo.currentUser != null &&
            authRepo.currentUser!.isAnonymous == false);

    // Save locally (and push to Firestore if already signed in with Google).
    await notifier.setName(_nameCtrl.text, uid: isSignedIn ? uid : null);
    await notifier.setAge(
      _selectedAge.toString(),
      uid: isSignedIn ? uid : null,
    );
    if (_gender != null) {
      await notifier.setGender(_gender!, uid: isSignedIn ? uid : null);
    }
    await notifier.setGoals(_goals, uid: isSignedIn ? uid : null);

    await markOnboardingComplete(ref);

    setState(() => _isBusy = true);
    try {
      if (authRepo.currentUser != null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
          );
        }
        return;
      }

      await authRepo.signInAnonymously();
      await ref.read(analyticsServiceProvider).logGuestStarted();
      // Navigate after successful anonymous sign-in.
      // AuthGate rebuilds via the auth stream, but UserProfileQuestionsScreen
      // is still on the stack on top of it — we must pop to AuthGate explicitly.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (e, st) {
      // This used to silently navigate to AuthGate regardless of success
      // or failure — a user on airplane mode (or hitting
      // 'operation-not-allowed' if anonymous auth were ever disabled)
      // just got bounced back to onboarding with zero explanation of
      // what went wrong, looking stuck in a loop. Staying on this screen
      // (their answers are already saved locally above) with an actual
      // error message lets them retry once conditions are fixed.
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'signInAnonymously',
        );
      } else {
        debugPrint('signInAnonymously failed: $e\n$st');
      }
      if (mounted) {
        AppSnackBar.show(
          context,
          authErrorMessage(e),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _goToSignIn() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const SignInScreen(fromOnboarding: true),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return true;
      case 2:
        return _gender != null;
      case 3:
        return _goals.isNotEmpty;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            // Left padding is 4, not 16 — this screen builds its own top
            // row instead of a real AppBar (needs the progress bar and
            // Skip inline), and stacking a 16px margin on top of the
            // button's own default touch-target padding put the icon
            // noticeably further from the edge than every other screen's
            // AppBar-based back button. Using IconButton's own default
            // sizing (instead of the tighter custom 38x38 box) plus a 4px
            // outer margin lands the icon at the same position an AppBar
            // leading icon sits at everywhere else in the app.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    tooltip: 'Back',
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: textPrimary,
                    ),
                  ),
                  // The button's own default touch-target padding already
                  // leaves ~15px between the icon and its right edge, so a
                  // smaller extra gap here (was 12, doubling up) is enough.
                  const SizedBox(width: 4),
                  // Progress bar — no glow
                  Expanded(
                    child: _ProgressBar(
                      step: _step,
                      total: _totalSteps,
                      accent: accent,
                      textMuted: textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Skip — enters app as guest without completing all steps
                  GestureDetector(
                    onTap: _finishAndEnterApp,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Question pages ────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  // Step 0 — Name
                  _NameStep(
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmit: _next,
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  ),
                  // Step 1 — Age (drum picker)
                  _AgeStep(
                    selectedAge: _selectedAge,
                    minAge: _minAge,
                    maxAge: _maxAge,
                    onChanged: (age) => setState(() {
                      _selectedAge = age;
                    }),
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                    bgColor: bgColor,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  ),
                  // Step 2 — Gender
                  _ChoiceStep(
                    question: 'How do you identify?',
                    emoji: '🙋',
                    subCopy: 'Helps us personalise your experience.',
                    choices: const [
                      'Male',
                      'Female',
                      'Non-binary',
                      'Prefer not to say',
                    ],
                    choiceEmojis: const ['👨', '👩', '🌈', '🤐'],
                    multiSelect: false,
                    selectedSingle: _gender,
                    selectedMulti: const [],
                    onSelectSingle: (v) => setState(() => _gender = v),
                    onToggleMulti: (_) {},
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  ),
                  // Step 3 — Goals (multi-select)
                  _ChoiceStep(
                    question: "What are your goals?",
                    emoji: '🎯',
                    subCopy:
                        "Pick as many as you like - we'll tailor your experience.",
                    choices: const [
                      'Build healthy habits',
                      'Stay consistent',
                      'Improve productivity',
                      'Personal growth',
                      'Mental wellness',
                      'Physical fitness',
                    ],
                    choiceEmojis: const ['💪', '🔥', '⚡', '🌱', '🧘', '🏃'],
                    multiSelect: true,
                    selectedSingle: null,
                    selectedMulti: _goals,
                    onSelectSingle: (_) {},
                    onToggleMulti: (v) => setState(() {
                      if (_goals.contains(v)) {
                        _goals.remove(v);
                      } else {
                        _goals.add(v);
                      }
                    }),
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),

            // ── Continue / Enter app button ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: _ContinueButton(
                step: _step,
                total: _totalSteps,
                enabled: _canContinue && !_isBusy,
                isBusy: _isBusy,
                onPressed: _next,
                accent: accent,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────

/// Flat segmented progress bar — no glow box shadow.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.step,
    required this.total,
    required this.accent,
    required this.textMuted,
  });
  final int step;
  final int total;
  final Color accent;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: active ? accent : textMuted.withValues(alpha: 0.2),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Name Step ────────────────────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: '👋',
      question: "What's your name?",
      subCopy: "We'd love to know who we're building streaks with.",
      textPrimary: textPrimary,
      textMuted: textMuted,
      child: _FlatTextField(
        controller: controller,
        label: 'Your name',
        icon: Icons.person_outline_rounded,
        textCapitalization: TextCapitalization.words,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        autofocus: true,
        accent: accent,
        textPrimary: textPrimary,
        textMuted: textMuted,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
      ),
    );
  }
}

// ─── Age Step (Drum Picker) ───────────────────────────────────────────────────

class _AgeStep extends StatefulWidget {
  const _AgeStep({
    required this.selectedAge,
    required this.minAge,
    required this.maxAge,
    required this.onChanged,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
  });
  final int selectedAge;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onChanged;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  State<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends State<_AgeStep> {
  late FixedExtentScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.selectedAge - widget.minAge;
    _scrollCtrl = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: '🎂',
      question: 'How old are you?',
      subCopy: 'Optional - scroll to pick your age.',
      textPrimary: widget.textPrimary,
      textMuted: widget.textMuted,
      child: _AgeDrumPicker(
        scrollCtrl: _scrollCtrl,
        minAge: widget.minAge,
        maxAge: widget.maxAge,
        selectedAge: widget.selectedAge,
        onChanged: widget.onChanged,
        accent: widget.accent,
        textMuted: widget.textMuted,
        bgColor: widget.bgColor,
        surfaceColor: widget.surfaceColor,
        borderColor: widget.borderColor,
      ),
    );
  }
}

class _AgeDrumPicker extends StatelessWidget {
  const _AgeDrumPicker({
    required this.scrollCtrl,
    required this.minAge,
    required this.maxAge,
    required this.selectedAge,
    required this.onChanged,
    required this.accent,
    required this.textMuted,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
  });

  final FixedExtentScrollController scrollCtrl;
  final int minAge;
  final int maxAge;
  final int selectedAge;
  final ValueChanged<int> onChanged;
  final Color accent;
  final Color textMuted;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    const itemHeight = 56.0;
    const visibleItems = 5;
    const pickerHeight = itemHeight * visibleItems;

    return Container(
      height: pickerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection highlight band — flat, no glow
          Positioned(
            top: (pickerHeight - itemHeight) / 2,
            left: 0,
            right: 0,
            child: Container(
              height: itemHeight,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // Wheel
          ListWheelScrollView.useDelegate(
            controller: scrollCtrl,
            itemExtent: itemHeight,
            perspective: 0.003,
            diameterRatio: 2.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => onChanged(minAge + index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: maxAge - minAge + 1,
              builder: (context, index) {
                final age = minAge + index;
                final isSelected = age == selectedAge;
                return Center(
                  child: Text(
                    '$age',
                    style: TextStyle(
                      color: isSelected
                          ? accent
                          : textMuted.withValues(alpha: 0.5),
                      fontSize: isSelected ? 28 : 20,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          ),

          // Top fade — uses solid bgColor so it blends into the background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: itemHeight * 1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surfaceColor.withValues(alpha: 0.95),
                      surfaceColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: itemHeight * 1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      surfaceColor.withValues(alpha: 0.95),
                      surfaceColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Choice Step (single or multi-select) ────────────────────────────────────

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.question,
    required this.emoji,
    required this.subCopy,
    required this.choices,
    required this.choiceEmojis,
    required this.multiSelect,
    required this.selectedSingle,
    required this.selectedMulti,
    required this.onSelectSingle,
    required this.onToggleMulti,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final String question;
  final String emoji;
  final String subCopy;
  final List<String> choices;
  final List<String> choiceEmojis;
  final bool multiSelect;
  final String? selectedSingle;
  final List<String> selectedMulti;
  final ValueChanged<String> onSelectSingle;
  final ValueChanged<String> onToggleMulti;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: emoji,
      question: question,
      subCopy: subCopy,
      textPrimary: textPrimary,
      textMuted: textMuted,
      child: Column(
        children: List.generate(choices.length, (i) {
          final choice = choices[i];
          final isSelected = multiSelect
              ? selectedMulti.contains(choice)
              : selectedSingle == choice;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                GestureDetector(
                      onTap: () => multiSelect
                          ? onToggleMulti(choice)
                          : onSelectSingle(choice),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isSelected
                              ? accent.withValues(alpha: 0.10)
                              : surfaceColor,
                          border: Border.all(
                            color: isSelected
                                ? accent.withValues(alpha: 0.6)
                                : borderColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              choiceEmojis[i],
                              style: const TextStyle(fontSize: 21),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                choice,
                                style: TextStyle(
                                  color: isSelected ? textPrimary : textMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: isSelected
                                  ? Icon(
                                      multiSelect
                                          ? Icons.check_box_rounded
                                          : Icons.check_circle_rounded,
                                      key: const ValueKey('checked'),
                                      color: accent,
                                      size: 20,
                                    )
                                  : Icon(
                                      multiSelect
                                          ? Icons
                                                .check_box_outline_blank_rounded
                                          : Icons.circle_outlined,
                                      key: const ValueKey('unchecked'),
                                      color: textMuted.withValues(alpha: 0.3),
                                      size: 20,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate(delay: (i * 60).ms)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.08, curve: Curves.easeOut),
          );
        }),
      ),
    );
  }
}

// ─── Step Shell ───────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.emoji,
    required this.question,
    required this.subCopy,
    required this.child,
    required this.textPrimary,
    required this.textMuted,
  });
  final String emoji;
  final String question;
  final String subCopy;
  final Widget child;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flat emoji — large text, no orb/glow
          Center(child: Text(emoji, style: const TextStyle(fontSize: 56)))
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: 32),

          // Question
          Text(
            question,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.1),

          const SizedBox(height: 8),

          // Sub-copy
          Text(
            subCopy,
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
          ).animate().fadeIn(delay: 140.ms, duration: 350.ms),

          const SizedBox(height: 28),

          // Input widget
          child
              .animate()
              .fadeIn(delay: 200.ms, duration: 350.ms)
              .slideY(begin: 0.08, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

// ─── Continue Button ──────────────────────────────────────────────────────────

/// Flat continue button — no box shadow.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.step,
    required this.total,
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
    required this.accent,
    required this.isDark,
  });
  final int step;
  final int total;
  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isLast = step == total - 1;
    final label = isLast ? "Let's go 🔥" : 'Continue';
    final fgColor = isDark ? Colors.black : Colors.white;
    final fgDisabled = isDark ? Colors.black45 : Colors.white54;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled ? accent : accent.withValues(alpha: 0.3),
        ),
        child: Center(
          child: isBusy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fgColor,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: enabled ? fgColor : fgDisabled,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Flat Text Field ──────────────────────────────────────────────────────────

/// Replaces the old _GlassTextField — solid surface, 1px border, no box shadow.
class _FlatTextField extends StatelessWidget {
  const _FlatTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: textMuted.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: textMuted, size: 20),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: accent.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
