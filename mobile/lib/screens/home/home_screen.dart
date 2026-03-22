import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/device_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _urlCtrl = TextEditingController();
  late final TextEditingController _tokenCtrl = TextEditingController();
  late final TextEditingController _nameCtrl = TextEditingController();
  bool _controllersSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersSeeded) return;
    _controllersSeeded = true;
    final ds = context.read<DeviceService>();
    _urlCtrl.text = ds.serverUrl;
    _tokenCtrl.text = ds.token;
    _nameCtrl.text = ds.self.deviceName;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestForegroundPerms() async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _saveAndConnect() async {
    final ds = context.read<DeviceService>();
    await ds.setServerUrl(_urlCtrl.text);
    await ds.setToken(_tokenCtrl.text);
    await ds.setDeviceName(_nameCtrl.text);
    await _requestForegroundPerms();
    if (!mounted) return;
    await context.read<WebSocketService>().connect();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DeviceService>();
    final ws = context.watch<WebSocketService>();

    final self = Device(
      deviceId: ds.self.deviceId,
      deviceName: ds.self.deviceName,
      platform: ds.self.platform,
      isOnline: ws.isConnected,
      pairingKey: kShowPairingKeyInUi ? ds.self.pairingKey : null,
      connectedAt: ds.self.connectedAt,
      lastPing: ds.self.lastPing,
    );

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AgentLinker'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'WebSocket 地址',
                      hintText: kDefaultServerUrl,
                      border: OutlineInputBorder(),
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '真机：ws://电脑局域网IP:8080/ws/client；本机模拟器：${kDefaultServerUrlEmulator}。'
                    '若报 Connection refused：在电脑启动 main_v2，并用浏览器打开 http://该IP:8080/health 确认可达。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenCtrl,
                    decoration: const InputDecoration(
                      labelText: '设备 Token',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '设备显示名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许 Shell（shell.exec）'),
                    subtitle: const Text('关闭时拒绝执行 shell，仅允许白名单动作'),
                    value: ds.allowShell,
                    onChanged: (v) => ds.setAllowShell(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许读取短信（sms.inbox）'),
                    subtitle: const Text('开启后控制端可拉取收件箱最近若干条（需系统短信权限）'),
                    value: ds.allowSmsRead,
                    onChanged: (v) => ds.setAllowSmsRead(v),
                  ),
                  if (ws.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ws.lastError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: ws.isConnecting ? null : _saveAndConnect,
                          child: Text(ws.isConnecting ? '连接中…' : '连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: ws.isConnected || ws.isConnecting
                              ? () => context.read<WebSocketService>().disconnect()
                              : null,
                          child: const Text('断开'),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      await ds.resetDeviceId();
                      _nameCtrl.text = ds.self.deviceName;
                    },
                    child: const Text('重置设备 ID'),
                  ),
                ],
              ),
            ),
            DeviceCard(
              device: self,
              onTap: () {},
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '指令日志',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ws.logLines.length,
                itemBuilder: (context, i) {
                  final idx = ws.logLines.length - 1 - i;
                  return Text(
                    ws.logLines[idx],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
