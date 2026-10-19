/// Errors raised by an `AgentBackend`. Widgets show [message] as-is, so every
/// message is written for the person using the app.
sealed class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The server rejected this device's credentials (HTTP 401).
final class UnauthorizedException extends BackendException {
  const UnauthorizedException([super.message = 'This device is not signed in.']);
}

/// Why the server could not be reached, so pairing can say what to check.
enum UnreachableReason {
  /// Something answered but refused the connection: wrong port, or the server is off.
  refused,

  /// Nothing answered in time: usually a different network or a firewall.
  timeout,

  /// The OS has no route to that address: almost always a different network.
  noRoute,

  /// The connection broke mid-request, or another transport failure.
  other,
}

/// The server could not be reached or the connection dropped.
final class UnreachableException extends BackendException {
  const UnreachableException(super.message, {this.reason = UnreachableReason.other});

  final UnreachableReason reason;
}

/// The server answered with an error status other than 401.
final class ServerException extends BackendException {
  const ServerException(super.message, {required this.statusCode});

  final int statusCode;
}
