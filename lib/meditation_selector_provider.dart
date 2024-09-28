import 'package:hooks_riverpod/hooks_riverpod.dart';

class MeditationDuration {
  final int minutes;
  const MeditationDuration(this.minutes);
}
class MeditationSelectorState {
  final List<MeditationDuration> meditationMinsOptions;
  final MeditationDuration selectedMins;

  MeditationSelectorState({
    required this.meditationMinsOptions,
    required this.selectedMins,
  });

  MeditationSelectorState copyWith({
    List<MeditationDuration>? meditationMinsOptions,
    MeditationDuration? selectedMins,
  }) {
    return MeditationSelectorState(
      meditationMinsOptions: meditationMinsOptions ?? this.meditationMinsOptions,
      selectedMins: selectedMins ?? this.selectedMins,
    );
  }
}

class MeditationSelectorNotifier extends StateNotifier<MeditationSelectorState> {
  MeditationSelectorNotifier()
      : super(MeditationSelectorState(
          meditationMinsOptions: const [
            MeditationDuration(3),
            MeditationDuration(6),
            MeditationDuration(9),
            MeditationDuration(12),
            MeditationDuration(15),
            MeditationDuration(18),
            MeditationDuration(21),
          ],
          selectedMins: const MeditationDuration(9),
        ));

  void updateSelectedMins(int index) {
    final newSelectedMins = state.meditationMinsOptions[index];
    state = state.copyWith(selectedMins: newSelectedMins);
  }
}

final meditationSelectorProvider =
    StateNotifierProvider<MeditationSelectorNotifier, MeditationSelectorState>(
  (ref) => MeditationSelectorNotifier(),
);
