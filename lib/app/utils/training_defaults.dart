/// The numbers behind every calculated weight live here, in one place, so a
/// stored preference and a missing preference can never tell different
/// stories.

/// The smallest weight jump the app rounds to when nothing else is stored.
/// One kilo keeps the old whole-unit behaviour, so a preferences map written
/// before the step existed behaves exactly as it did.
const double defaultRoundingStep = 1.0;

/// Rounds a stored rounding step to something usable. A step of zero would
/// divide by zero and a negative step would round the wrong way, so anything
/// that is not a positive, finite number falls back to [defaultRoundingStep].
double sanitiseRoundingStep(double? step) {
  if (step == null || step.isNaN || !step.isFinite || step <= 0) {
    return defaultRoundingStep;
  }
  return step;
}

/// The step written into a label: whole steps lose their decimal, halves keep
/// it, so "0.5" reads as 0.5 and not 0.5000000001.
String formatRoundingStep(double step) {
  final double safeStep = sanitiseRoundingStep(step);
  final double trimmed = double.parse(safeStep.toStringAsFixed(3));
  return trimmed == trimmed.roundToDouble()
      ? trimmed.toStringAsFixed(0)
      : trimmed.toString();
}
