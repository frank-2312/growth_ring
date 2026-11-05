import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/companion_style.dart';

/// 模型连接配置。刻意只用 OpenAI 兼容协议，
/// 这样百炼、DeepSeek、Kimi、Ollama 都只是换一行 baseUrl。
@immutable
class LlmConfig {
  const LlmConfig({
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.apiKey = '',
    this.model = 'qwen-plus',
    this.temperature = 0.7,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 规范化 baseUrl：容忍用户填 https://xxx/v1/ 或带 /chat/completions
  String get normalizedBase {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) {
      b = b.substring(0, b.length - '/chat/completions'.length);
    }
    return b;
  }

  LlmConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
  }) =>
      LlmConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
      );
}

@immutable
class AppSettings {
  const AppSettings({
    this.llm = const LlmConfig(),
    this.nickname = '',
    this.themeMode = ThemeMode.dark,
    this.autoReflect = true,
    this.companion = const CompanionStyle(),
  });

  final LlmConfig llm;

  /// 它怎么称呼你
  final String nickname;
  final ThemeMode themeMode;

  /// 保存日记后自动更新画像
  final bool autoReflect;

  /// 「知己」的性格：名字、关系、说话的倾向
  final CompanionStyle companion;

  AppSettings copyWith({
    LlmConfig? llm,
    String? nickname,
    ThemeMode? themeMode,
    bool? autoReflect,
    CompanionStyle? companion,
  }) =>
      AppSettings(
        llm: llm ?? this.llm,
        nickname: nickname ?? this.nickname,
        themeMode: themeMode ?? this.themeMode,
        autoReflect: autoReflect ?? this.autoReflect,
        companion: companion ?? this.companion,
      );
}

/// API Key 走系统安全存储；其余偏好放 SharedPreferences。
/// 若设备上安全存储不可用（少数定制 ROM），自动降级到普通存储并标记，
/// 让功能可用，同时在设置页如实提示风险。
class SettingsStore {
  SettingsStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const _kApiKey = 'llm_api_key';
  static const _kBaseUrl = 'llm_base_url';
  static const _kModel = 'llm_model';
  static const _kTemperature = 'llm_temperature';
  static const _kNickname = 'nickname';
  static const _kTheme = 'theme_mode';
  static const _kAutoReflect = 'auto_reflect';
  static const _kCompanion = 'companion_style';
  static const _kInsecureFallback = 'api_key_insecure_fallback';

  final FlutterSecureStorage _secure;

  bool secureStorageUnavailable = false;

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var apiKey = '';

    try {
      apiKey = await _secure.read(key: _kApiKey) ?? '';
    } catch (_) {
      secureStorageUnavailable = true;
      apiKey = prefs.getString(_kApiKey) ?? '';
    }

    if (apiKey.isEmpty && prefs.getBool(_kInsecureFallback) == true) {
      apiKey = prefs.getString(_kApiKey) ?? '';
    }

    final themeRaw = prefs.getString(_kTheme) ?? 'dark';
    return AppSettings(
      llm: LlmConfig(
        baseUrl: prefs.getString(_kBaseUrl) ?? const LlmConfig().baseUrl,
        apiKey: apiKey,
        model: prefs.getString(_kModel) ?? const LlmConfig().model,
        temperature: prefs.getDouble(_kTemperature) ?? 0.7,
      ),
      nickname: prefs.getString(_kNickname) ?? '',
      themeMode: switch (themeRaw) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      autoReflect: prefs.getBool(_kAutoReflect) ?? true,
      companion: CompanionStyle.fromJsonString(prefs.getString(_kCompanion)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, settings.llm.baseUrl);
    await prefs.setString(_kModel, settings.llm.model);
    await prefs.setDouble(_kTemperature, settings.llm.temperature);
    await prefs.setString(_kNickname, settings.nickname);
    await prefs.setString(_kTheme, switch (settings.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    });
    await prefs.setBool(_kAutoReflect, settings.autoReflect);
    await prefs.setString(_kCompanion, settings.companion.toJsonString());

    try {
      await _secure.write(key: _kApiKey, value: settings.llm.apiKey);
      await prefs.setBool(_kInsecureFallback, false);
      secureStorageUnavailable = false;
    } catch (_) {
      secureStorageUnavailable = true;
      await prefs.setString(_kApiKey, settings.llm.apiKey);
      await prefs.setBool(_kInsecureFallback, true);
    }
  }
}
