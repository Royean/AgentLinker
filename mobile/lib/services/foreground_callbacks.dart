import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground_task_handler.dart';

@pragma('vm:entry-point')
void agentLinkerForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(AgentLinkerTaskHandler());
}
