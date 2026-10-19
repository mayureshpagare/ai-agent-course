import '../../core/utils/json.dart';

/// `GET /api/auth`.
class AuthStatus {
  const AuthStatus({required this.required, required this.authorized, required this.local});

  factory AuthStatus.fromJson(Json json) => AuthStatus(
        required: asBool(json['required']),
        authorized: asBool(json['authorized']),
        local: asBool(json['local']),
      );

  /// Whether remote access (and so a token) is switched on.
  final bool required;

  /// Whether this request's credentials were accepted.
  final bool authorized;

  /// True only for the browser on the host computer itself.
  final bool local;
}
