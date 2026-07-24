import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../model/version_config_model.dart';
import '../repository/force_update_repository.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------
final forceUpdateRepositoryProvider = Provider<ForceUpdateRepository>(
  (ref) => ForceUpdateRepository(),
);

// ---------------------------------------------------------------------------
// State: holds remote config + whether an update is required
// ---------------------------------------------------------------------------
class ForceUpdateState {
  final bool isUpdateRequired;
  final VersionConfigModel? config;

  const ForceUpdateState({
    required this.isUpdateRequired,
    this.config,
  });
}

// ---------------------------------------------------------------------------
// FutureProvider: fetches config, compares versions, returns ForceUpdateState
// ---------------------------------------------------------------------------
final forceUpdateProvider = FutureProvider<ForceUpdateState>((ref) async {
  final repository = ref.read(forceUpdateRepositoryProvider);

  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version; // e.g. "1.0.0"
  final packageName = packageInfo.packageName;

  final config = await repository.fetchVersionConfig(packageName: packageName);

  // If Firestore is unreachable or document missing → no forced update
  if (config == null) {
    return const ForceUpdateState(isUpdateRequired: false);
  }

  final isRequired = _isUpdateRequired(
    current: currentVersion,
    minRequired: config.minRequiredVersion,
  );

  return ForceUpdateState(
    isUpdateRequired: isRequired,
    config: config,
  );
});

// ---------------------------------------------------------------------------
// Semantic version comparison helper
// Returns true if current < minRequired
// ---------------------------------------------------------------------------
bool _isUpdateRequired({
  required String current,
  required String minRequired,
}) {
  try {
    final currentParts = current.split('.').map(int.parse).toList();
    final minParts = minRequired.split('.').map(int.parse).toList();

    // Pad shorter list with zeroes so lengths match
    while (currentParts.length < minParts.length) { currentParts.add(0); }
    while (minParts.length < currentParts.length) { minParts.add(0); }

    for (int i = 0; i < minParts.length; i++) {
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }

    return false; // versions are equal → no update required
  } catch (_) {
    return false; // parse error → safe fallback, don't block user
  }
}
