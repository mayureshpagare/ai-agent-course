import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/log.dart';
import 'session_controller.dart';

/// Client for logo downloads; overridden in tests.
final logoHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// A logo's bytes, or null when it can't be loaded (the avatar then shows the
/// agent's initial). Keyed by the URL from `AgentBackend.logoUrl`, whose `?v=`
/// changes when the file changes, so each logo downloads once per session.
///
/// Bytes rather than `Image.network` because logos may be SVG, which needs a
/// different widget, and the type is only known from the content.
final logoBytesProvider = FutureProvider.family<Uint8List?, Uri>((ref, url) async {
  final headers = ref.watch(backendProvider).authHeaders;
  try {
    final response = await ref.watch(logoHttpClientProvider).get(url, headers: headers).timeout(requestTimeout);
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) return response.bodyBytes;
    logWarning('Logo $url: HTTP ${response.statusCode}');
  } on Object catch (error) {
    logWarning('Logo $url failed: $error');
  }
  return null;
});

/// Whether [bytes] look like an SVG document rather than a raster image.
bool isSvg(Uint8List bytes) {
  final head = String.fromCharCodes(bytes.take(256)).trimLeft().replaceFirst('﻿', '').toLowerCase();
  return head.startsWith('<svg') || (head.startsWith('<?xml') && head.contains('<svg')) || head.startsWith('<!--');
}
