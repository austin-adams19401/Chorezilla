enum MemberRole { parent, child }

class Member {
  final String id;
  final String familyId;
  String name;
  MemberRole role;
  String avatar; 
  bool usesThisDevice;

  Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    required this.avatar,
    this.usesThisDevice = true,
  });
}