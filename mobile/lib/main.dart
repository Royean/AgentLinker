import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home/home_screen.dart';
import 'services/device_service.dart';
import 'services/websocket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'agentlinker_foreground',
      channelName: 'AgentLinker',
      channelDescription: '保持与中继服务器的连接',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final deviceService = DeviceService(prefs);
  await deviceService.load();

  runApp(AgentLinkerApp(deviceService: deviceService));
}

class AgentLinkerApp extends StatelessWidget {
  const AgentLinkerApp({super.key, required this.deviceService});

  final DeviceService deviceService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceService>.value(value: deviceService),
        ChangeNotifierProvider(
          create: (context) => WebSocketService(context.read<DeviceService>()),
        ),
      ],
      child: MaterialApp(
        title: 'AgentLinker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
