import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/utils/training_defaults.dart';

void main() {
  group('rounding step', () {
    test('a missing, zero, negative or non-finite step becomes one', () {
      expect(sanitiseRoundingStep(null), 1.0);
      expect(sanitiseRoundingStep(0), 1.0);
      expect(sanitiseRoundingStep(-0.5), 1.0);
      expect(sanitiseRoundingStep(double.nan), 1.0);
      expect(sanitiseRoundingStep(double.infinity), 1.0);
      expect(sanitiseRoundingStep(double.negativeInfinity), 1.0);
    });

    test('a usable step is left alone', () {
      expect(sanitiseRoundingStep(0.5), 0.5);
      expect(sanitiseRoundingStep(2.5), 2.5);
      expect(sanitiseRoundingStep(5), 5.0);
    });

    test('the label drops the decimal on a whole step only', () {
      expect(formatRoundingStep(1), '1');
      expect(formatRoundingStep(2.5), '2.5');
      expect(formatRoundingStep(0.5), '0.5');
    });
  });
}
