import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 执行服务端转发的 [action]，返回体需含 `success` 字段（与 [mobile_client.py] 一致）。
class AgentCommandExecutor {
  AgentCommandExecutor({
    required this.deviceId,
    required this.deviceName,
    required this.allowShell,
    required this.allowSmsRead,
  });

  static const MethodChannel _smsChannel = MethodChannel('com.agentlinker.mobile/sms');

  String deviceId;
  String deviceName;
  bool allowShell;
  bool allowSmsRead;

  Future<Map<String, dynamic>> execute(String action, Map<String, dynamic> params) async {
    try {
      switch (action) {
        case 'system.info':
          return _systemInfo();
        case 'shell.exec':
          return _shellExec(params);
        case 'file.read':
          return _fileRead(params);
        case 'file.write':
          return _fileWrite(params);
        case 'app.open':
          return _appOpen(params);
        case 'clipboard.get':
          return _clipboardGet();
        case 'clipboard.set':
          return _clipboardSet(params);
        case 'sms.inbox':
          return await _smsInboxRead(params);
        default:
          return {
            'success': false,
            'error': '未知动作：$action',
          };
      }
    } catch (e, st) {
      debugPrint('AgentCommandExecutor error: $e\n$st');
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _systemInfo() {
    return {
      'success': true,
      'data': {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
      },
    };
  }

  Future<Map<String, dynamic>> _shellExec(Map<String, dynamic> params) async {
    if (!allowShell) {
      return {
        'success': false,
        'error': '未开启「允许 Shell」',
      };
    }
    final cmd = params['cmd'] as String? ?? '';
    if (cmd.isEmpty) {
      return {'success': false, 'error': 'cmd 为空'};
    }
    try {
      final result = await Process.run(
        'sh',
        ['-c', cmd],
        runInShell: false,
      ).timeout(const Duration(seconds: 30));
      return {
        'success': result.exitCode == 0,
        'returncode': result.exitCode,
        'stdout': result.stdout is String ? result.stdout as String : utf8.decode(result.stdout as List<int>, allowMalformed: true),
        'stderr': result.stderr is String ? result.stderr as String : utf8.decode(result.stderr as List<int>, allowMalformed: true),
      };
    } on TimeoutException {
      return {'success': false, 'error': '命令超时（30s）'};
    }
  }

  Future<String> _sandboxRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String?> _resolveSafePath(String relOrAbs) async {
    final root = await _sandboxRoot();
    final normalized = p.normalize(relOrAbs);
    final full = p.isAbsolute(normalized) ? normalized : p.join(root, normalized);
    final rootResolved = p.normalize(root);
    if (!p.equals(full, rootResolved) && !p.isWithin(rootResolved, full)) {
      return null;
    }
    return full;
  }

  Future<Map<String, dynamic>> _fileRead(Map<String, dynamic> params) async {
    final path = params['path'] as String? ?? '';
    final full = await _resolveSafePath(path);
    if (full == null) {
      return {'success': false, 'error': '路径必须在应用文档目录内'};
    }
    final f = File(full);
    if (!await f.exists()) {
      return {'success': false, 'error': '文件不存在'};
    }
    final content = await f.readAsString();
    return {
      'success': true,
      'data': {'path': full, 'content': content, 'size': content.length},
    };
  }

  Future<Map<String, dynamic>> _fileWrite(Map<String, dynamic> params) async {
    final path = params['path'] as String? ?? '';
    final content = params['content'] as String? ?? '';
    final full = await _resolveSafePath(path);
    if (full == null) {
      return {'success': false, 'error': '路径必须在应用文档目录内'};
    }
    await Directory(p.dirname(full)).create(recursive: true);
    await File(full).writeAsString(content, flush: true);
    return {
      'success': true,
      'data': {'path': full, 'size': content.length},
    };
  }

  Future<Map<String, dynamic>> _appOpen(Map<String, dynamic> params) async {
    final urlStr = params['url'] as String? ?? '';
    if (urlStr.isEmpty) {
      return {'success': false, 'error': 'url 为空'};
    }
    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      return {'success': false, 'error': '非法 URL'};
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return {'success': ok, if (!ok) 'error': '无法打开链接'};
  }

  Future<Map<String, dynamic>> _clipboardGet() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return {
      'success': true,
      'data': {'text': data?.text ?? ''},
    };
  }

  Future<Map<String, dynamic>> _clipboardSet(Map<String, dynamic> params) async {
    final text = params['text'] as String? ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    return {'success': true};
  }

  Future<Map<String, dynamic>> _smsInboxRead(Map<String, dynamic> params) async {
    if (!allowSmsRead) {
      return {'success': false, 'error': '未开启「允许读取短信」'};
    }
    if (!Platform.isAndroid) {
      return {'success': false, 'error': 'sms.inbox 仅支持 Android'};
    }
    final limitRaw = params['limit'];
    var limit = 50;
    if (limitRaw is int) {
      limit = limitRaw;
    } else if (limitRaw is num) {
      limit = limitRaw.toInt();
    }
    if (limit < 1) limit = 1;
    if (limit > 200) limit = 200;
    try {
      final raw = await _smsChannel.invokeMethod<List<dynamic>>('readInbox', {'limit': limit});
      final messages = <Map<String, dynamic>>[];
      for (final item in raw ?? const <dynamic>[]) {
        if (item is Map) {
          messages.add(Map<String, dynamic>.from(item.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
      return {
        'success': true,
        'data': {'messages': messages, 'count': messages.length},
      };
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message ?? e.code};
    }
  }
}
