class GroupModel {
  final String id;
  final String name;
  final String adminId;
  final List<String> members;
  final Map<String, double> memberLimits;
  final String type; // 'split', 'business', or 'wages'
  final List<String> admins;

  GroupModel({
    required this.id,
    required this.name,
    required this.adminId,
    required this.members,
    required this.memberLimits,
    required this.type,
    this.admins = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'adminId': adminId,
      'members': members,
      'memberLimits': memberLimits,
      'type': type,
      'admins': admins.isEmpty ? [adminId] : admins,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    final adminsList = List<String>.from(map['admins'] ?? []);
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
      admins: adminsList.isEmpty && map['adminId'] != null
          ? [map['adminId'] as String]
          : adminsList,
    );
  }
}
