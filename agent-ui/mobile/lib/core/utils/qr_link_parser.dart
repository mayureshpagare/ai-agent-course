import '../constants.dart';

/// A server address and access token read from a pairing QR code.
class PairingLink {
  const PairingLink({required this.baseUrl, required this.token});

  /// Scheme, host, port and any path prefix in front of `/api`.
  final Uri baseUrl;
  final String token;
}

const _loginPath = '/api/login';

/// Parses the URL in the pairing QR code, which `backend/remote.py` builds as
/// `http://<lan-ip>:<port>/api/login?token=<token>`. Returns null for anything
/// else. The app never opens this URL: it only takes the address and token
/// out of it and sends the token as a Bearer header.
PairingLink? parsePairingLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !_isHttp(uri) || uri.host.isEmpty) return null;
  if (!uri.path.endsWith(_loginPath)) return null;

  final String? token;
  try {
    token = uri.queryParameters['token']?.trim();
  } on FormatException {
    return null; // malformed percent-encoding
  }
  if (token == null || token.isEmpty) return null;

  final prefix = uri.path.substring(0, uri.path.length - _loginPath.length);
  return PairingLink(
    baseUrl: Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: prefix),
    token: token,
  );
}

/// Parses a server address typed by hand, such as `192.168.1.20:8000`,
/// `my-pc.local`, `[fe80::1]:5173` or `http://100.64.0.2:8000`. Without a
/// port, http uses [defaultServerPort]. Returns null when it is not usable.
Uri? parseServerAddress(String input) {
  var text = input.trim();
  if (text.isEmpty || text.contains(' ')) return null;
  if (!text.contains('://')) text = 'http://$text';

  final uri = Uri.tryParse(text);
  if (uri == null || !_isHttp(uri) || uri.host.isEmpty) return null;
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;

  final port = uri.hasPort ? uri.port : (uri.scheme == 'http' ? defaultServerPort : 443);
  final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return Uri(scheme: uri.scheme, host: uri.host, port: port, path: path);
}

/// `host:port` for messages, with IPv6 hosts in brackets.
String displayAddress(Uri baseUrl) {
  final host = baseUrl.host.contains(':') ? '[${baseUrl.host}]' : baseUrl.host;
  return '$host:${baseUrl.port}${baseUrl.path}';
}

bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';
