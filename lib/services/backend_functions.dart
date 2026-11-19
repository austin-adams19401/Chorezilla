import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Callable Cloud Functions. Subscription, PIN, loot, and family-join writes
/// that clients are not allowed to perform directly go through here.
class BackendFunctions {
  BackendFunctions._();

  static final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _fn.httpsCallable(name).call(data);
      final raw = result.data;
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('$name failed: ${e.code} ${e.message}');
      throw Exception(e.message ?? 'Request failed');
    }
  }

  static Future<void> refreshSubscription(String familyId) {
    return _call('refreshSubscription', {'familyId': familyId});
  }

  static Future<void> setParentPin({
    required String familyId,
    required String? pin,
  }) {
    return _call('setParentPin', {'familyId': familyId, 'pin': pin});
  }

  static Future<bool> verifyParentPin({
    required String familyId,
    required String pin,
  }) async {
    final data = await _call('verifyParentPin', {
      'familyId': familyId,
      'pin': pin,
    });
    return data['ok'] == true;
  }

  static Future<void> setKidPin({
    required String familyId,
    required String memberId,
    required String? pin,
  }) {
    return _call('setKidPin', {
      'familyId': familyId,
      'memberId': memberId,
      'pin': pin,
    });
  }

  static Future<bool> verifyKidPin({
    required String familyId,
    required String memberId,
    required String pin,
  }) async {
    final data = await _call('verifyKidPin', {
      'familyId': familyId,
      'memberId': memberId,
      'pin': pin,
    });
    return data['ok'] == true;
  }

  static Future<JoinCodePreview> previewJoinCode(String code) async {
    final data = await _call('previewJoinCode', {'code': code});
    final rawKids = data['kids'];
    final kids = <JoinKidPreview>[];
    if (rawKids is List) {
      for (final entry in rawKids) {
        if (entry is Map) {
          kids.add(JoinKidPreview(
            id: entry['id']?.toString() ?? '',
            displayName: entry['displayName']?.toString() ?? 'Kid',
            avatarKey: entry['avatarKey']?.toString(),
          ));
        }
      }
    }
    return JoinCodePreview(
      familyId: data['familyId']?.toString() ?? '',
      familyName: data['familyName']?.toString() ?? 'Family',
      kind: data['kind']?.toString() ?? 'child',
      kids: kids,
    );
  }

  static Future<String> redeemParentInvite({
    required String code,
    String? displayName,
  }) async {
    final data = await _call('redeemInvite', {
      'code': code,
      if (displayName != null) 'displayName': displayName,
    });
    return data['familyId']?.toString() ?? '';
  }

  static Future<({String familyId, String memberId})> joinWithFamilyCode({
    required String code,
    required String kind,
    String? memberId,
    String? displayName,
  }) async {
    final data = await _call('joinWithFamilyCode', {
      'code': code,
      'kind': kind,
      if (memberId != null) 'memberId': memberId,
      if (displayName != null) 'displayName': displayName,
    });
    return (
      familyId: data['familyId']?.toString() ?? '',
      memberId: data['memberId']?.toString() ?? '',
    );
  }

  static Future<LootBoxServerResult> openLootBox({
    required String familyId,
    required String memberId,
    required String boxId,
  }) async {
    final data = await _call('openLootBox', {
      'familyId': familyId,
      'memberId': memberId,
      'boxId': boxId,
    });
    final rolls = <String>[];
    final rawRolls = data['rolls'];
    if (rawRolls is List) {
      for (final roll in rawRolls) {
        rolls.add(roll.toString());
      }
    }
    return LootBoxServerResult(
      rolls: rolls,
      wonItemId: data['wonItemId']?.toString() ?? '',
      isDuplicate: data['isDuplicate'] == true,
      coinRefund: (data['coinRefund'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> purchaseCosmetic({
    required String familyId,
    required String memberId,
    required String itemId,
  }) {
    return _call('purchaseCosmetic', {
      'familyId': familyId,
      'memberId': memberId,
      'itemId': itemId,
    });
  }

  static Future<String?> grantLevelCosmetic({
    required String familyId,
    required String memberId,
    required int level,
  }) async {
    final data = await _call('grantLevelCosmetic', {
      'familyId': familyId,
      'memberId': memberId,
      'level': level,
    });
    final id = data['itemId']?.toString();
    if (id == null || id.isEmpty || id == 'null') return null;
    return id;
  }
}

class JoinCodePreview {
  final String familyId;
  final String familyName;
  final String kind;
  final List<JoinKidPreview> kids;
  const JoinCodePreview({
    required this.familyId,
    required this.familyName,
    required this.kind,
    required this.kids,
  });
}

class JoinKidPreview {
  final String id;
  final String displayName;
  final String? avatarKey;
  const JoinKidPreview({
    required this.id,
    required this.displayName,
    required this.avatarKey,
  });
}

class LootBoxServerResult {
  final List<String> rolls;
  final String wonItemId;
  final bool isDuplicate;
  final int coinRefund;
  const LootBoxServerResult({
    required this.rolls,
    required this.wonItemId,
    required this.isDuplicate,
    required this.coinRefund,
  });
}
