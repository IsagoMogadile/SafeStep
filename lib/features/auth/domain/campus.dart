class Campus {
  const Campus({required this.id, required this.name});

  final String id;
  final String name;

  factory Campus.fromRow(Map<String, dynamic> row) {
    return Campus(id: row['campus_id'] as String, name: row['name'] as String);
  }
}
