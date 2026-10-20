import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'log.dart';

/// Phone features the chat turn uses, behind an interface so tests can fake them.
abstract interface class DeviceServices {
  /// Keeps the screen (and so Wi-Fi) awake while a reply streams in, because
  /// the server stops a turn whose connection drops.
  void setKeepAwake(bool on);

  /// A tap of haptic feedback when a tool needs approval.
  void approvalNeeded();
}

class PlatformDeviceServices implements DeviceServices {
  const PlatformDeviceServices();

  @override
  void setKeepAwake(bool on) {
    unawaited(WakelockPlus.toggle(enable: on).catchError((Object error) {
      logWarning('Could not change the wakelock: $error');
    }));
  }

  @override
  void approvalNeeded() => unawaited(HapticFeedback.heavyImpact());
}

final deviceServicesProvider = Provider<DeviceServices>((ref) => const PlatformDeviceServices());
