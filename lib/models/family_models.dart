// lib/models/family_models.dart
enum MemberRole { parent, child }

class Family {
  final String id;
  String name;
  final DateTime createdAt;
  Family({
    required this.id,
    required this.name,
    required this.createdAt,
  });
}

class Member {
  final String id;
  final String familyId;
  String name;
  MemberRole role;
  String avatar;        // emoji or asset key
  bool usesThisDevice;
  bool requiresPin;
  String? pin;          // store hashed later; plaintext for MVP

  Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    required this.avatar,
    this.usesThisDevice = true,
    this.requiresPin = false,
    this.pin,
  });
}
