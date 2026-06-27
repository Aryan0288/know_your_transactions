class GroupModel {
  final String id;
  final String name;
  final String adminId;
  final List<String> members;
  final Map<String, double> memberLimits;
  final String type; // 'split' or 'business'

  GroupModel({
    required this.id,
    required this.name,
    required this.adminId,
    required this.members,
    required this.memberLimits,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'adminId': adminId,
      'members': members,
      'memberLimits': memberLimits,
      'type': type,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      adminId: map['adminId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      memberLimits: Map<String, double>.from(
        (map['memberLimits'] ?? {}).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      type: map['type'] ?? 'split',
    );
  }
}
