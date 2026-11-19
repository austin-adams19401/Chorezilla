part of 'app_state.dart';

extension AppStatePins on AppState {
  bool get hasParentPin =>
      _parentPinKnown &&
      (_parentPinSet ||
          (_parentPinHash != null && _parentPinHash!.trim().isNotEmpty));

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  Future<void> updateMemberPin({required String memberId, String? pin}) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when updating kid PIN');
    }
    final trimmed = pin?.trim();
    if (trimmed != null && trimmed.isNotEmpty && !_isValidPin(trimmed)) {
      throw ArgumentError('PIN must be exactly 4 digits (0–9).');
    }
    await BackendFunctions.setKidPin(
      familyId: famId,
      memberId: memberId,
      pin: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }

  bool kidRequiresPin(String memberId) {
    final m = _findMemberById(memberId);
    if (m == null) return false;
    return m.hasPin;
  }

  Future<bool> verifyKidPin({
    required String memberId,
    required String pin,
  }) async {
    final famId = _familyId;
    final trimmed = pin.trim();
    if (famId == null || !_isValidPin(trimmed)) return false;

    final ok = await BackendFunctions.verifyKidPin(
      familyId: famId,
      memberId: memberId,
      pin: trimmed,
    );

    if (ok) {
      _unlockedKidIds.add(memberId);
      _notifyStateChanged();
    }
    return ok;
  }

  Future<void> updateParentPin({required String? pin}) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when updating parent PIN');
    }
    final trimmed = pin?.trim();
    if (trimmed != null && trimmed.isNotEmpty && !_isValidPin(trimmed)) {
      throw ArgumentError('PIN must be exactly 4 digits (0–9).');
    }
    final clearing = trimmed == null || trimmed.isEmpty;
    await BackendFunctions.setParentPin(
      familyId: famId,
      pin: clearing ? null : trimmed,
    );

    _parentPinSet = !clearing;
    _parentPinHash = null;
    _parentPinKnown = true;
    _notifyStateChanged();
  }

  Future<bool> verifyParentPin(String pin) async {
    final famId = _familyId;
    final candidate = pin.trim();
    if (famId == null || !_isValidPin(candidate)) return false;

    final ok = await BackendFunctions.verifyParentPin(
      familyId: famId,
      pin: candidate,
    );

    if (ok && !_parentUnlocked) {
      _parentUnlocked = true;
      _notifyStateChanged();
    }
    return ok;
  }
}
