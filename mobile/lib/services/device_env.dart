import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android 原生环境探测（模拟器等）
class DeviceEnv {
  static const MethodChannel _channel = MethodChannel('com.agentlinker.mobile/env');

  /// 仅在 Android 上可判真；失败或非 Android 返回 false。
  static Future<bool> isAndroidEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isEmulator');
      return v == true;
    } catch (_) {
      return false;
    }
  }
}
