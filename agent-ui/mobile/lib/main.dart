import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/storage/secret_store.dart';
import 'data/storage/settings_store.dart';
import 'domain/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    retry: noAutomaticRetry,
    overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs, const SecureSecretStore()))],
    child: const AgentApp(),
  ));
}
