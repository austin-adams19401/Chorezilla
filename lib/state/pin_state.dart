part of 'app_state.dart';

extension AppStatePins on AppState {
  bool get hasParentPin =>
      _parentPinKnown &&
      _parentPinHash != null &&
      _parentPinHash!.trim().isNotEmpty;

  bool _isValidPin(String pin) {
    // exactly 4 digits
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  String _hashPin(String pin) {
    // Simple salt: familyId + PIN
    final famId = _familyId ?? '';
    final bytes = utf8.encode('$famId|$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> updateMemberPin({required String memberId, String? pin}) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when updating kid PIN');
    }

    await repo.updateMember(famId, memberId, {
      'pinHash': (pin == null || pin.isEmpty) ? null : pin,
    });
  }

  bool kidRequiresPin(String memberId) {
    final m = _findMemberById(memberId);
    if (m == null) return false;
    final raw = m.pinHash ?? '';
    return raw.trim().isNotEmpty;
  }

  Future<bool> verifyKidPin({
    required String memberId,
    required String pin,
  }) async {
    final trimmed = pin.trim();
    if (trimmed.isEmpty) return false;

    // 1) Parent master PIN always works
    if (await verifyParentPin(trimmed)) {
      _unlockedKidIds.add(memberId);
      _notifyStateChanged();
      return true;
    }

    // 2) Fall back to kid's own PIN
    final m = _findMemberById(memberId);
    if (m == null) return false;

    final raw = m.pinHash ?? '';
    final ok = raw.isNotEmpty && raw == trimmed;
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

    final normalized = (pin == null || pin.isEmpty) ? null : pin.trim();

    // For now we store the 4-digit PIN directly; later you can swap to hashing.
    await repo.updateFamily(famId, {'parentPinHash': normalized});

    // Keep local state in sync so AuthGate sees the change immediately.
    _parentPinHash = normalized;
    _parentPinKnown = true;
    _notifyStateChanged();
  }

  Future<bool> verifyParentPin(String pin) async {
    final candidate = pin.trim();
    if (candidate.isEmpty) return false;

    // Prefer the locally-tracked value, fall back to Family if needed.
    final stored = _parentPinHash ?? _family?.parentPinHash ?? '';
    final ok = stored.isNotEmpty && stored == candidate;
    if (ok && !_parentUnlocked) {
      _parentUnlocked = true;
      _notifyStateChanged();
    }
    return ok;
  }
}
