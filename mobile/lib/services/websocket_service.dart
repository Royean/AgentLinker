import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'agent_command_executor.dart';
import 'device_service.dart';
import 'foreground_callbacks.dart';

/// 与 [server/main_v2.py] `/ws/client` 协议对齐。
class WebSocketService extends ChangeNotifier {
  WebSocketService(this._deviceService);

  final DeviceService _deviceService;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _keepAliveTimer;
  Timer? _registerTimeout;
  bool _connecting = false;
  bool _connected = false;
  String? _lastError;
  final List<String> _logLines = [];

  bool get isConnecting => _connecting;
  bool get isConnected => _connected;
  String? get lastError => _lastError;
  List<String> get logLines => List.unmodifiable(_logLines);

  void _log(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logLines.add('[$ts] $line');
    if (_logLines.length > 80) {
      _logLines.removeAt(0);
    }
    notifyListeners();
  }

  /// 将底层 WebSocket / Socket 异常转成可读说明（APK 上常因 IP、Wi‑Fi、路径或明文策略导致）。
  static String describeConnectionError(Object e) {
    if (e is SocketException) {
      final m = e.message;
      if (m.contains('Connection refused') || m.contains('errno = 111')) {
        return '连接被拒绝（$m）。对端未在该地址监听 TCP。请在本机运行 main_v2（监听 0.0.0.0:8080），地址使用 ws://电脑局域网IP:8080/ws/client；Android 模拟器用 ws://10.0.2.2:8080/ws/client。可在电脑浏览器访问 http://电脑IP:8080/health 自测。';
      }
      return '无法连接服务器（$m）。请确认：手机与电脑同一 Wi‑Fi；地址为 ws://电脑局域网IP:8080/ws/client；本机防火墙放行 8080。';
    }
    if (e is WebSocketException) {
      return 'WebSocket 握手失败（${e.message}）。请确认中继已启动且路径为 /ws/client；不要用 http:// 代替 ws://。';
    }
    final s = e.toString();
    if (s.contains('WebSocketException') || s.contains('WebSocket')) {
      if (s.contains('Connection refused') || s.contains('errno = 111')) {
        return '$s。含义：电脑 192.168.x.x:8080 上没有服务在监听（或 IP 已变）。请启动 main_v2 并核对 WebSocket 地址与端口；模拟器勿用局域网 IP，请用 10.0.2.2。';
      }
      return '$s。请核对地址含 /ws/client；默认 IP 与电脑不一致时请在本页修改后重连。';
    }
    return s;
  }

  Future<void> connect() async {
    if (_connecting || _connected) return;
    _connecting = true;
    _lastError = null;
    notifyListeners();

    final url = _deviceService.serverUrl.trim();
    if (url.isEmpty) {
      _connecting = false;
      _lastError = '服务器地址为空';
      notifyListeners();
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      _connecting = false;
      _lastError = '地址需为 ws:// 或 wss://，例如 ws://192.168.1.5:8080/ws/client';
      notifyListeners();
      return;
    }
    if (!uri.path.contains('ws/client')) {
      _connecting = false;
      _lastError = '路径须与服务端一致，需包含 /ws/client';
      notifyListeners();
      return;
    }

    try {
      _channel = WebSocketChannel.connect(uri);

      final reg = jsonEncode({
        'type': 'register',
        'device_id': _deviceService.self.deviceId,
        'device_name': _deviceService.self.deviceName,
        'token': _deviceService.token,
        'platform': 'Android',
        'device_info': {
          'device_id': _deviceService.self.deviceId,
          'device_name': _deviceService.self.deviceName,
          'platform': 'Android',
        },
      });
      _channel!.sink.add(reg);

      _registerTimeout?.cancel();
      _registerTimeout = Timer(const Duration(seconds: 20), () {
        if (_connecting && !_connected) {
          _lastError = '注册超时';
          _log('注册超时');
          unawaited(disconnect());
        }
      });

      var registered = false;
      _subscription = _channel!.stream.listen(
        (raw) async {
          if (raw is! String) return;
          Map<String, dynamic> data;
          try {
            data = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return;
          }
          final type = data['type'] as String?;

          if (!registered) {
            if (type == 'registered') {
              registered = true;
              _registerTimeout?.cancel();
              _registerTimeout = null;
              final key = data['pairing_key'] as String?;
              _deviceService.setConnected(true, pairingKey: key);
              _connected = true;
              _connecting = false;
              _log('已注册，配对码：$key');
              notifyListeners();
              await _startForeground();
              return;
            }
            if (type == 'error') {
              _lastError = data['msg']?.toString() ?? '注册失败';
              _log('错误：$_lastError');
              await disconnect();
              return;
            }
            _lastError = '非预期首包：$type';
            await disconnect();
            return;
          }

          await _handleServerMessage(data);
        },
        onError: (e) {
          _lastError = describeConnectionError(e);
          _log('通道错误：$_lastError');
          unawaited(disconnect());
        },
        onDone: () {
          _log('连接已关闭');
          unawaited(disconnect());
        },
        cancelOnError: false,
      );

      _keepAliveTimer = Timer.periodic(const Duration(seconds: 28), (_) {
        if (_connected) {
          _channel?.sink.add(jsonEncode({
            'type': 'pong',
            'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
          }));
        }
      });
    } catch (e) {
      _connecting = false;
      _lastError = describeConnectionError(e);
      _log('连接异常：$_lastError');
      notifyListeners();
    }
  }

  Future<void> _handleServerMessage(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (type == 'ping') {
      _deviceService.touchPing();
      _channel?.sink.add(jsonEncode({
        'type': 'pong',
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
      }));
      return;
    }
    if (type == 'exec') {
      final reqId = data['req_id'];
      final action = data['action'] as String? ?? '';
      final params = (data['params'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      _log('exec: $action');
      final executor = AgentCommandExecutor(
        deviceId: _deviceService.self.deviceId,
        deviceName: _deviceService.self.deviceName,
        allowShell: _deviceService.allowShell,
        allowSmsRead: _deviceService.allowSmsRead,
      );
      final result = await executor.execute(action, params);
      _channel?.sink.add(jsonEncode({
        'type': 'result',
        'req_id': reqId,
        'success': result['success'] == true,
        'data': result,
      }));
      return;
    }
  }

  Future<void> _startForeground() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        return;
      }
      final r = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'AgentLinker',
        notificationText: '已连接中继服务器',
        callback: agentLinkerForegroundStartCallback,
      );
      if (r is ServiceRequestFailure) {
        _log('前台服务未启动：${r.error}');
      }
    } catch (e) {
      _log('前台服务异常：$e');
    }
  }

  Future<void> _stopForeground() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _registerTimeout?.cancel();
    _registerTimeout = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _connected = false;
    _deviceService.setConnected(false, pairingKey: null);
    await _stopForeground();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
