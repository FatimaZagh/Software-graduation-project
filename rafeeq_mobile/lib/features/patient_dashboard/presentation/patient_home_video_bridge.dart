/// Coordinates pausing the patient home background video before overlays/routes.
class PatientHomeVideoBridge {
  PatientHomeVideoBridge._();

  static final PatientHomeVideoBridge instance = PatientHomeVideoBridge._();

  Future<void> Function()? _pause;
  Future<void> Function()? _resume;
  int _pauseDepth = 0;

  void register({
    required Future<void> Function() pause,
    required Future<void> Function() resume,
  }) {
    _pause = pause;
    _resume = resume;
  }

  void unregister() {
    _pause = null;
    _resume = null;
  }

  /// Pauses background video, runs [action], then resumes when the outermost overlay closes.
  Future<T?> runWithPausedOverlay<T>(Future<T?> Function() action) async {
    final isOutermost = _pauseDepth == 0;
    _pauseDepth++;
    try {
      if (isOutermost) {
        await _pause?.call();
      }
      return await action();
    } finally {
      _pauseDepth--;
      if (_pauseDepth == 0) {
        await _resume?.call();
      }
    }
  }
}
