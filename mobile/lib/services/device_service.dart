import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/constants.dart';
import '../models/device.dart';
import 'device_env.dart';

class DeviceService extends ChangeNotifier {
  DeviceService(this._prefs);

  final SharedPreferences _prefs;

  Device _self = Device(
    deviceId: '',
    deviceName: 'Android',
    platform: 'Android',
    isOnline: false,
  );

  Device get self => _self;

  String get serverUrl => _prefs.getString(kPrefsServerUrl) ?? kDefaultServerUrl;
  String get token => _prefs.getString(kPrefsToken) ?? kDefaultDeviceToken;
  bool get allowShell => _prefs.getBool(kPrefsAllowShell) ?? false;
  bool get allowSmsRead => _prefs.getBool(kPrefsAllowSmsRead) ?? false;

  Future<void> load() async {
    var id = _prefs.getString(kPrefsDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _prefs.setString(kPrefsDeviceId, id);
    }
    // 与本仓库 constants 同步的一次性默认端点；改 IP 后把下面版本号 +1 可再次下发
    const defaultsRev = 'endpoint_v2';
    if (_prefs.getString('applied_default_endpoint') != defaultsRev) {
      await _prefs.setString(kPrefsServerUrl, kDefaultServerUrl);
      await _prefs.setString(kPrefsToken, kDefaultDeviceToken);
      await _prefs.setString('applied_default_endpoint', defaultsRev);
    }
    await _preferEmulatorLoopbackIfNeeded();
    final name = _prefs.getString(kPrefsDeviceName) ?? 'Android';
    _self = Device(
      deviceId: id,
      deviceName: name,
      platform: 'Android',
      isOnline: false,
      pairingKey: _self.pairingKey,
    );
    notifyListeners();
  }

  /// 模拟器上若仍用仓库里的局域网默认地址，则改为 10.0.2.2 指向宿主机中继。
  Future<void> _preferEmulatorLoopbackIfNeeded() async {
    if (_prefs.getBool(kPrefsEnvProbeDone) == true) return;
    if (!Platform.isAndroid) {
      await _prefs.setBool(kPrefsEnvProbeDone, true);
      return;
    }
    final emu = await DeviceEnv.isAndroidEmulator();
    if (emu) {
      final saved = _prefs.getString(kPrefsServerUrl);
      final trimmed = saved?.trim() ?? '';
      if (trimmed.isEmpty || trimmed == kDefaultServerUrl) {
        await _prefs.setString(kPrefsServerUrl, kDefaultServerUrlEmulator);
      }
    }
    await _prefs.setBool(kPrefsEnvProbeDone, true);
  }

  Future<void> setServerUrl(String v) async {
    await _prefs.setString(kPrefsServerUrl, v.trim());
    notifyListeners();
  }

  Future<void> setToken(String v) async {
    await _prefs.setString(kPrefsToken, v.trim());
    notifyListeners();
  }

  Future<void> setDeviceName(String v) async {
    final name = v.trim().isEmpty ? 'Android' : v.trim();
    await _prefs.setString(kPrefsDeviceName, name);
    _self = Device(
      deviceId: _self.deviceId,
      deviceName: name,
      platform: _self.platform,
      isOnline: _self.isOnline,
      pairingKey: _self.pairingKey,
      connectedAt: _self.connectedAt,
      lastPing: _self.lastPing,
    );
    notifyListeners();
  }

  Future<void> setAllowShell(bool v) async {
    await _prefs.setBool(kPrefsAllowShell, v);
    notifyListeners();
  }

  Future<void> setAllowSmsRead(bool v) async {
    await _prefs.setBool(kPrefsAllowSmsRead, v);
    notifyListeners();
  }

  void setConnected(bool online, {String? pairingKey}) {
    _self = Device(
      deviceId: _self.deviceId,
      deviceName: _self.deviceName,
      platform: _self.platform,
      isOnline: online,
      pairingKey: pairingKey ?? _self.pairingKey,
      connectedAt: online ? DateTime.now() : null,
      lastPing: online ? DateTime.now() : _self.lastPing,
    );
    notifyListeners();
  }

  void updatePairingKey(String? key) {
    _self = Device(
      deviceId: _self.deviceId,
      deviceName: _self.deviceName,
      platform: _self.platform,
      isOnline: _self.isOnline,
      pairingKey: key,
      connectedAt: _self.connectedAt,
      lastPing: _self.lastPing,
    );
    notifyListeners();
  }

  void touchPing() {
    _self = Device(
      deviceId: _self.deviceId,
      deviceName: _self.deviceName,
      platform: _self.platform,
      isOnline: _self.isOnline,
      pairingKey: _self.pairingKey,
      connectedAt: _self.connectedAt,
      lastPing: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> resetDeviceId() async {
    final id = const Uuid().v4();
    await _prefs.setString(kPrefsDeviceId, id);
    _self = Device(
      deviceId: id,
      deviceName: _self.deviceName,
      platform: _self.platform,
      isOnline: false,
      pairingKey: null,
    );
    notifyListeners();
  }
}
