import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/utils/accessory_sets.dart';

void main() {
  test('all inputs blank returns null: a blank session writes no row', () {
    expect(parseAccessorySets(['', '', ''], ['', '', '']), isNull);
    expect(parseAccessorySets([], []), isNull);
    expect(parseAccessorySets(['  ', '  '], ['  ', '  ']), isNull);
  });

  test('reps 8, 8, 7 with weights 60, blank, 0 keeps every set', () {
    final sets = parseAccessorySets(['8', '8', '7'], ['60', '', '0']);

    expect(sets, isNotNull);
    expect(sets!.length, 3);
    expect(sets[0], const SetModel(setNumber: 1, reps: 8, weight: 60.0));
    expect(sets[1], const SetModel(setNumber: 2, reps: 8, weight: 0.0));
    expect(sets[2], const SetModel(setNumber: 3, reps: 7, weight: 0.0));
  });

  test('a single filled set among blanks keeps its row position', () {
    final sets = parseAccessorySets(['', '8', ''], ['', '62.5', '']);

    expect(sets, isNotNull);
    expect(sets!.length, 1);
    expect(sets.first, const SetModel(setNumber: 2, reps: 8, weight: 62.5));
  });

  test('non-numeric reps are skipped', () {
    final sets = parseAccessorySets(['abc', '10'], ['40', '45']);

    expect(sets, isNotNull);
    expect(sets!.length, 1);
    expect(sets.first, const SetModel(setNumber: 2, reps: 10, weight: 45.0));
  });

  test('reps 0 is not a filled set', () {
    expect(parseAccessorySets(['0'], ['60']), isNull);
  });

  test('a missing weight input means bodyweight', () {
    final sets = parseAccessorySets(['10'], []);

    expect(sets, isNotNull);
    expect(sets!.length, 1);
    expect(sets.first.weight, 0.0);
  });

  test('no filled row in any entry means the accessory save stays disabled', () {
    final reps = <String, List<String>>{
      'Rosca direta': ['', '', ''],
      'Paralelas': ['  ', ''],
    };
    final weights = <String, List<String>>{
      'Rosca direta': ['', '', ''],
      'Paralelas': ['0', '0'],
    };

    expect(anyAccessorySetsFilled(reps, weights), isFalse);
    expect(anyAccessorySetsFilled(<String, List<String>>{}, {}), isFalse);
  });

  test('one filled row in any entry enables the accessory save', () {
    final reps = <String, List<String>>{
      'Rosca direta': ['', '', ''],
      'Paralelas': ['', '9'],
    };
    final weights = <String, List<String>>{
      'Rosca direta': ['', '', ''],
      'Paralelas': ['', '0'],
    };

    expect(anyAccessorySetsFilled(reps, weights), isTrue);
  });

  test('weights alone do not count as a filled set', () {
    final reps = <String, List<String>>{
      'Rosca direta': ['', '', ''],
    };
    final weights = <String, List<String>>{
      'Rosca direta': ['60', '60', '60'],
    };

    expect(anyAccessorySetsFilled(reps, weights), isFalse);
  });

  test('a missing weight entry still counts when reps are filled', () {
    final reps = <String, List<String>>{
      'Rosca direta': ['12'],
    };

    expect(anyAccessorySetsFilled(reps, <String, List<String>>{}), isTrue);
  });

  test('0 is shown as BW, or 0 kg in a dense summary', () {
    expect(formatAccessoryWeight(0.0), 'BW');
    expect(formatAccessoryWeight(0.0, compact: true), '0 kg');
    expect(formatAccessoryWeight(62.5), '62.5');
  });
}
