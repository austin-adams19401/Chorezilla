enum MemberRole { parent, child }

class Member {
  final String id;
  final String familyId;
  String name;
  MemberRole role;
  String avatar;        // emoji or asset key
  bool usesThisDevice;  // will use this device
  String? pinHash;      // null => no PIN set

  Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    required this.avatar,
    this.usesThisDevice = true,
    this.pinHash,
  });
}
