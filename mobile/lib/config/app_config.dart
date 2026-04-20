/// 后端根地址（不要以 / 结尾）。
/// 真机调试请改为电脑的局域网 IP，例如 http://192.168.1.8:8000
/// PC 模拟器可用 http://10.0.2.2:8000（Android 默认指向宿主机）
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
