import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 仅用于展示前台通知保活；业务逻辑在主 Isolate 的 [WebSocketService]。
class AgentLinkerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
