import '../../core/utils/json.dart';

/// How a profile signs in. Only [lanToken] exists today; a hosted version
/// would add kinds such as `apiKey` or `oauth` (see docs/FUTURE_REMOTE.md).
enum AuthKind {
  /// The access token from `run_ui.ps1`, sent as `Authorization: Bearer`.
  lanToken,
}

/// A server this app can talk to. The credential itself is not part of the
/// profile: it lives in secure storage, keyed by [id].
class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.authKind,
    required this.createdAt,
  });

  /// Returns null for a profile written by a newer app version with an auth
  /// kind this version does not know.
  static ConnectionProfile? tryFromJson(Json json) {
    final kind = AuthKind.values.asNameMap()[json['authKind']];
    final url = Uri.tryParse(optionalString(json, 'baseUrl') ?? '');
    final id = optionalString(json, 'id');
    if (kind == null || url == null || id == null) return null;
    return ConnectionProfile(
      id: id,
      label: optionalString(json, 'label') ?? url.host,
      baseUrl: url,
      authKind: kind,
      createdAt: DateTime.tryParse(optionalString(json, 'createdAt') ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String label;
  final Uri baseUrl;
  final AuthKind authKind;
  final DateTime createdAt;

  Json toJson() => {
        'id': id,
        'label': label,
        'baseUrl': baseUrl.toString(),
        'authKind': authKind.name,
        'createdAt': createdAt.toIso8601String(),
      };
}
