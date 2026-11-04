import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../interactor/models/accessory_exercise_model.dart';
import '../../interactor/repository/accessory_exercise_repository.dart';
import '../adapters/accessory_exercise_adapter.dart';

class SharedPreferencesAccessoryExerciseRepository
    implements AccessoryExerciseRepository {
  static const String _accessoryExercisesKey = 'accessoryExercises';

  @override
  Future<List<AccessoryExerciseModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final accessoryExercisesString = prefs.getString(_accessoryExercisesKey);
    if (accessoryExercisesString != null) {
      final accessoryExercisesList = List<Map<String, dynamic>>.from(
        jsonDecode(accessoryExercisesString) as List<dynamic>,
      );
      return accessoryExercisesList.map((accessoryExerciseMap) => AccessoryExerciseAdapter.fromMap(accessoryExerciseMap)).toList();
    }
    return [];
  }

  @override
  Future<AccessoryExerciseModel> insert(AccessoryExerciseModel exercise) async {
    final prefs = await SharedPreferences.getInstance();
    final exercises = await getAll();
    exercises.add(exercise);
    final exercisesString = jsonEncode(exercises.map((exercise) => AccessoryExerciseAdapter.toMap(exercise)).toList());
    await prefs.setString(_accessoryExercisesKey, exercisesString);
    return exercise;
  }

  @override
  Future<AccessoryExerciseModel> update(AccessoryExerciseModel exercise) async {
    final prefs = await SharedPreferences.getInstance();
    final exercises = await getAll();
    final index = exercises.indexWhere((e) => e.name == exercise.name);
    if (index != -1) {
      exercises[index] = exercise;
      final exercisesString = jsonEncode(exercises.map((exercise) => AccessoryExerciseAdapter.toMap(exercise)).toList());
      await prefs.setString(_accessoryExercisesKey, exercisesString);
    }
    return exercise;
  }

  @override
  Future<bool> delete(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final exercises = await getAll();
    final updatedExercises = exercises.where((exercise) => exercise.name != name).toList();
    final exercisesString = jsonEncode(updatedExercises.map((exercise) => AccessoryExerciseAdapter.toMap(exercise)).toList());
    await prefs.setString(_accessoryExercisesKey, exercisesString);
    return true;
  }

  // Full replace: used by setImportedExercises so a re-import cannot duplicate entries
  @override
  Future<void> saveAll(List<AccessoryExerciseModel> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final exercisesString = jsonEncode(exercises.map((exercise) => AccessoryExerciseAdapter.toMap(exercise)).toList());
    await prefs.setString(_accessoryExercisesKey, exercisesString);
  }
}
