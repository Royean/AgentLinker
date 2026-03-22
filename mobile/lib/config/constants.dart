/// 与服务端 [server/main_v2.py] `LINUX_DEVICE_TOKEN` 默认值保持一致。
const String kDefaultDeviceToken = 'ah_device_token_change_in_production';

/// 本机当前 Wi‑Fi IP（变更网络后需改）
const String kDefaultServerUrl = 'ws://192.168.1.103:8080/ws/client';

/// Android 模拟器访问宿主机上中继（等同电脑 localhost:8080）
const String kDefaultServerUrlEmulator = 'ws://10.0.2.2:8080/ws/client';

const String kPrefsServerUrl = 'server_url';
const String kPrefsToken = 'device_token';
const String kPrefsDeviceId = 'device_id';
const String kPrefsDeviceName = 'device_name';
const String kPrefsAllowShell = 'allow_shell';
const String kPrefsAllowSmsRead = 'allow_sms_read';
/// 已做过模拟器默认地址探测（只跑一次，避免覆盖用户手改）
const String kPrefsEnvProbeDone = 'env_probe_done';

/// 服务端关闭配对要求时不展示配对密钥（与 main_v2 REQUIRE_DEVICE_PAIRING 策略一致）
const bool kShowPairingKeyInUi = false;
