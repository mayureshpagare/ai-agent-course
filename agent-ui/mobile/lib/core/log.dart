import 'package:flutter/foundation.dart';

/// Logs something unexpected that the app recovered from (unknown events, bad JSON).
void logWarning(String message) => debugPrint('[agent_ui] $message');
