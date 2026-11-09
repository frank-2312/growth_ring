import 'dart:async';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// 匿名使用统计。
///
/// 选 Aptabase 而不是 Firebase/友盟，理由只有一条：这是个写日记的 App，
/// 用户在设置页看到的承诺是「日记不上传」。所以统计只能知道「有人打开了、
/// 有人写了、有人聊了」，不能知道「谁」——
/// - 不碰 IMEI / OAID / 广告 ID / 手机号，实例之间靠一个随机串区分；
/// - 事件只带粗粒度分桶（字数区间、篇数区间），永远不带日记正文；
/// - 没配 key、或用户在设置里关掉时，所有调用都是空操作。
///
/// 统计永远不该影响写日记本身，所以这里所有异常都吞掉。
class Analytics {
  const Analytics._();

  /// 构建时注入：flutter build apk --dart-define=APTABASE_KEY=A-EU-xxxxxxxxxx
  static const String _key = String.fromEnvironment('APTABASE_KEY');

  /// 自建 Aptabase 时配合 A-SH- 开头的 key 使用
  static const String _host = String.fromEnvironment('APTABASE_HOST');

  static bool _ready = false;
  static bool _enabled = false;

  /// 构建时是否带了 key。没带就别在界面上承诺能统计。
  static bool get configured => _key.trim().isNotEmpty;

  static bool get active => _ready && _enabled;

  /// [options] 只给测试用：默认 30 秒批量发一次，测试里需要调短。
  static Future<void> start({
    required bool enabled,
    InitOptions? options,
  }) async {
    _enabled = enabled;
    if (!enabled || !configured || _ready) return;
    try {
      final host = _host.trim();
      final opts = options ??
          (host.isEmpty ? const InitOptions() : InitOptions(host: host));
      await Aptabase.init(_key.trim(), opts);
      _ready = true;
    } catch (e) {
      // key 格式不对、网络库初始化失败……都不该让 App 起不来
      debugPrint('[analytics] 初始化失败，统计已停用：$e');
    }
  }

  /// 设置页开关。关掉后不再入队，已经在队列里的会在下次 tick 时照常发出。
  static void setEnabled(bool value) => _enabled = value;

  static void track(String event, [Map<String, Object?>? props]) {
    if (!active) return;
    // SDK 内部是「先写本地队列，每隔几十秒批量发一次」，所以这里不用等
    unawaited(
      Aptabase.instance
          .trackEvent(event, props)
          .catchError((Object e) => debugPrint('[analytics] $event 记录失败：$e')),
    );
  }

  // --- 分桶：只上报区间，不上报具体数字，减少可识别性 ---------------------

  /// 日记字数区间
  static String charsBucket(int chars) {
    if (chars < 100) return '1-99';
    if (chars < 300) return '100-299';
    if (chars < 800) return '300-799';
    return '800+';
  }

  /// 篇数 / 条数区间
  static String countBucket(int n) {
    if (n <= 0) return '0';
    if (n < 10) return '1-9';
    if (n < 50) return '10-49';
    if (n < 200) return '50-199';
    return '200+';
  }
}
