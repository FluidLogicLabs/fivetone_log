import 'package:flutter/foundation.dart';

@immutable
class AccessoryExerciseModel {
  final String name;
  final String? lastUsedLift; // New field

  const AccessoryExerciseModel({
    required this.name,
    this.lastUsedLift, // New field
  });

  AccessoryExerciseModel copyWith({
    String? name,
    String? lastUsedLift, // New field
  }) {
    return AccessoryExerciseModel(
      name: name ?? this.name,
      lastUsedLift: lastUsedLift ?? this.lastUsedLift, // New field
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessoryExerciseModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          lastUsedLift == other.lastUsedLift; // New field

  @override
  int get hashCode => name.hashCode ^ lastUsedLift.hashCode; // New field
}
