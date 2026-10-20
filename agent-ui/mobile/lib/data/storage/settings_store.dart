import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../../core/utils/json.dart';
import '../models/connection_profile.dart';
import 'secret_store.dart';

/// Saved servers, their credentials and small preferences.
///
/// Profiles are a list even though the UI uses one at a time, so more servers
/// or a hosted profile can be added later without migrating data.
class SettingsStore {
  SettingsStore(this._prefs, this._secrets);

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  static const _profilesKey = 'connection_profiles';
  static const _activeProfileKey = 'active_profile_id';
  static const _lastAgentKey = 'last_agent_id';
  static const _themeKey = 'theme_mode';

  static String _credentialKey(String profileId) => 'credential:$profileId';

  List<ConnectionProfile> profiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (asJson(item) case final Json json)
            if (ConnectionProfile.tryFromJson(json) case final ConnectionProfile profile) profile,
      ];
    } on FormatException {
      logWarning('Saved connection profiles were unreadable and have been ignored.');
      return [];
    }
  }

  ConnectionProfile? activeProfile() {
    final id = _prefs.getString(_activeProfileKey);
    for (final profile in profiles()) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Adds or replaces [profile], stores its [credential] and makes it active.
  Future<void> saveProfile(ConnectionProfile profile, {required String credential}) async {
    final others = profiles().where((p) => p.id != profile.id);
    await _secrets.write(_credentialKey(profile.id), credential);
    await _prefs.setString(_profilesKey, jsonEncode([...others.map((p) => p.toJson()), profile.toJson()]));
    await _prefs.setString(_activeProfileKey, profile.id);
  }

  Future<String?> credential(String profileId) => _secrets.read(_credentialKey(profileId));

  /// Signs out of [profileId] but keeps its address for the pairing screen.
  Future<void> deleteCredential(String profileId) => _secrets.delete(_credentialKey(profileId));

  /// Removes the profile and its credential entirely.
  Future<void> removeProfile(String profileId) async {
    await _secrets.delete(_credentialKey(profileId));
    final rest = profiles().where((p) => p.id != profileId).map((p) => p.toJson()).toList();
    await _prefs.setString(_profilesKey, jsonEncode(rest));
    if (_prefs.getString(_activeProfileKey) == profileId) await _prefs.remove(_activeProfileKey);
  }

  String? get lastAgentId => _prefs.getString(_lastAgentKey);

  Future<void> setLastAgentId(String id) => _prefs.setString(_lastAgentKey, id);

  /// `system`, `light` or `dark`.
  String get themeMode => _prefs.getString(_themeKey) ?? 'system';

  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);
}
