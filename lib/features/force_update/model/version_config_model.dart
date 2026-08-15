class VersionConfigModel {
  final String minRequiredVersion;
  final String updateMessage;
  final String playStoreUrl;

  const VersionConfigModel({
    required this.minRequiredVersion,
    required this.updateMessage,
    required this.playStoreUrl,
  });

  factory VersionConfigModel.fromMap(
    Map<String, dynamic> map, {
    String? packageName,
  }) {
    Map<String, dynamic>? configMap;

    if (packageName != null && map[packageName] is Map) {
      configMap = Map<String, dynamic>.from(map[packageName] as Map);
    } else if (map.containsKey('min_required_version') ||
        map.containsKey('play_store_url')) {
      configMap = map;
    } else if (map.isNotEmpty && map.values.first is Map) {
      configMap = Map<String, dynamic>.from(map.values.first as Map);
    }

    final target = configMap ?? map;

    return VersionConfigModel(
      minRequiredVersion: target['min_required_version'] as String? ?? '0.0.0',
      updateMessage:
          target['update_message'] as String? ??
          'A new version of the app is available.',
      playStoreUrl:
          target['play_store_url'] as String? ??
          (packageName != null
              ? 'https://play.google.com/store/apps/details?id=$packageName'
              : 'https://play.google.com/store/apps/details?id=com.anuj.knowyourexpenses'),
    );
  }
}
