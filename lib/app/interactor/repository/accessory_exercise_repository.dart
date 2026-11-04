import '../models/accessory_exercise_model.dart';

abstract class AccessoryExerciseRepository {
  Future<List<AccessoryExerciseModel>> getAll();
  Future<AccessoryExerciseModel> insert(AccessoryExerciseModel exercise);
  Future<AccessoryExerciseModel> update(AccessoryExerciseModel exercise);
  Future<bool> delete(String name);
  Future<void> saveAll(List<AccessoryExerciseModel> exercises);
}
