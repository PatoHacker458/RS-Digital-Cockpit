import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado inmutable del Onboarding interactivo de 4 pantallas.
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class OnboardingState {
  final int currentPageIndex;
  final bool isCompleted;

  const OnboardingState({
    this.currentPageIndex = 0,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    int? currentPageIndex,
    bool? isCompleted,
  }) {
    return OnboardingState(
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String _onboardingPrefKey = 'clio_rs_onboarding_done';

  @override
  OnboardingState build() {
    _loadPersistedStatus();
    return const OnboardingState();
  }

  Future<void> _loadPersistedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool(_onboardingPrefKey) ?? false;
      state = state.copyWith(isCompleted: done);
    } catch (_) {}
  }

  void setPageIndex(int index) {
    state = state.copyWith(currentPageIndex: index.clamp(0, 3));
  }

  void nextPage() {
    if (state.currentPageIndex < 3) {
      state = state.copyWith(currentPageIndex: state.currentPageIndex + 1);
    } else {
      completeOnboarding();
    }
  }

  void previousPage() {
    if (state.currentPageIndex > 0) {
      state = state.copyWith(currentPageIndex: state.currentPageIndex - 1);
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isCompleted: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingPrefKey, true);
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    state = const OnboardingState(currentPageIndex: 0, isCompleted: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingPrefKey, false);
    } catch (_) {}
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
