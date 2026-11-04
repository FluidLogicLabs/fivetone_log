import '../../interactor/models/accessory_exercise_model.dart';

class AccessoryExerciseAdapter {
  // Convert a Map to AccessoryExerciseModel
  static AccessoryExerciseModel fromMap(Map<String, dynamic> map) {
    return AccessoryExerciseModel(
      name: map['name'] as String,
      lastUsedLift: map['lastUsedLift'] as String?, // New field, may be missing
    );
  }

  // Convert AccessoryExerciseModel to a Map
  static Map<String, dynamic> toMap(AccessoryExerciseModel exercise) {
    return {
      'name': exercise.name,
      'lastUsedLift': exercise.lastUsedLift, // New field
    };
  }
}
