class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.createdAt,
    this.appIds,
  });

  final int id;
  final String name;
  final String? description;
  final String? icon;
  final String? createdAt;
  /// When loaded from GET /projects/{id}, contains the list of app ids in this project.
  final List<int>? appIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'created_at': createdAt,
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    List<int>? appIds;
    final raw = json['app_ids'];
    if (raw is List) {
      appIds = raw
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    return ProjectModel(
      id: _parseInt(json['id']) ?? 0,
      name: _parseString(json['name']) ?? '',
      description: _parseString(json['description']),
      icon: _parseString(json['icon']),
      createdAt: _parseString(json['created_at']),
      appIds: appIds,
    );
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
