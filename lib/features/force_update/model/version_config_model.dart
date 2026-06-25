class VersionConfigModel {
  final String minRequiredVersion;
  final String updateMessage;
  final String playStoreUrl;

  const VersionConfigModel({
    required this.minRequiredVersion,
    required this.updateMessage,
    required this.playStoreUrl,
  });

  factory VersionConfigModel.fromMap(Map<String, dynamic> map) {
    return VersionConfigModel(
      minRequiredVersion: map['min_required_version'] as String? ?? '0.0.0',
      updateMessage: map['update_message'] as String? ??
          'A new version is available. Please update to continue.',
      playStoreUrl: map['play_store_url'] as String? ??
          'https://play.google.com/store/apps/details?id=com.anuj.knowyourexpenses',
    );
  }
}
