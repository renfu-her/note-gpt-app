class Folder {
  final int id;
  final String name;
  final String arrowPath;
  final int sortOrder;
  final List<Folder> children;

  Folder({
    required this.id,
    required this.name,
    required this.arrowPath,
    required this.sortOrder,
    this.children = const [],
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      name: json['name'],
      arrowPath: json['arrow_path'],
      sortOrder: json['sort_order'] ?? 0,
      children: json['children'] != null
          ? List<Folder>.from(
              json['children'].map((x) => Folder.fromJson(x)),
            )
          : [],
    );
  }
} 