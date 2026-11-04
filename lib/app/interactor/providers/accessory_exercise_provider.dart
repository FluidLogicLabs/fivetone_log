import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fivethreeone_log/app/interactor/models/accessory_exercise_model.dart';
import 'package:fivethreeone_log/app/interactor/repository/accessory_exercise_repository.dart';
import 'package:fivethreeone_log/app/injector.dart';

class AccessoryExercisesNotifier extends StateNotifier<List<AccessoryExerciseModel>> {
  final AccessoryExerciseRepository _repository;

  AccessoryExercisesNotifier(this._repository) : super([]) {
    loadExercises();
  }

  Future<void> loadExercises() async {
    final exercises = await _repository.getAll();
    state = exercises;
  }

  // Create a catalogue entry; empty and duplicate names are ignored
  Future<void> addExercise(String name) async {
    if (name.isEmpty) return;
    if (state.any((exercise) => exercise.name == name)) return;
    final exercise = AccessoryExerciseModel(name: name);
    await _repository.insert(exercise);
    state = [...state, exercise];
  }

  // Rename a catalogue entry; empty and duplicate names are ignored
  Future<void> renameExercise(String oldName, String newName) async {
    if (newName.isEmpty) return;
    if (state.any((exercise) => exercise.name == newName)) return;
    final index = state.indexWhere((exercise) => exercise.name == oldName);
    if (index == -1) return;
    // saveAll because the stored entry is keyed by name, so delete+insert would race
    final updatedExercises = [
      for (final exercise in state)
        if (exercise.name == oldName) exercise.copyWith(name: newName) else exercise,
    ];
    await _repository.saveAll(updatedExercises);
    state = updatedExercises;
  }

  Future<void> deleteExercise(String name) async {
    await _repository.delete(name);
    state = state.where((exercise) => exercise.name != name).toList();
  }

  // Remember which lift day this exercise was last used on
  Future<void> touch(String name, String lastUsedLift) async {
    final index = state.indexWhere((exercise) => exercise.name == name);
    if (index == -1) return;
    final updatedExercise = state[index].copyWith(lastUsedLift: lastUsedLift);
    await _repository.update(updatedExercise);
    state = [
      for (final exercise in state)
        if (exercise.name == name) updatedExercise else exercise,
    ];
  }

  // Full replace of both state and storage, so re-importing cannot duplicate entries
  Future<void> setImportedExercises(List<AccessoryExerciseModel> imported) async {
    await _repository.saveAll(imported);
    state = imported;
  }
}

final accessoryExercisesProvider =
  StateNotifierProvider<AccessoryExercisesNotifier, List<AccessoryExerciseModel>>((ref) {
  final repository = injector.get<AccessoryExerciseRepository>();
  return AccessoryExercisesNotifier(repository);
});
