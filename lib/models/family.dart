class Family {
  final String id;
  String name;
  final DateTime createdAt;
  Family({
    required this.id,
    required this.name,
    required this.createdAt,
  });


  factory Family.fromMap(Map<String, dynamic> m, String id) => Family(
  id: id, name: '', createdAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {

  };


}