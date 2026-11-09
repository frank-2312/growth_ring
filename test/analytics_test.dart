import 'dart:convert';
import 'dart:io';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/core/analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端到端那一条需要真实发一次 HTTP，所以用一个假的 Aptabase 服务端接住：
///   flutter test test/analytics_test.dart --dart-define=APTABASE_KEY=A-SH-0000000000
/// 不带 dart-define 跑时，只有纯函数与「关掉时不出事」的用例。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('分桶', () {
    test('字数只给区间，不给具体数', () {
      expect(Analytics.charsBucket(1), '1-99');
      expect(Analytics.charsBucket(99), '1-99');
      expect(Analytics.charsBucket(100), '100-299');
      expect(Analytics.charsBucket(299), '100-299');
      expect(Analytics.charsBucket(800), '800+');
    });

    test('篇数同理', () {
      expect(Analytics.countBucket(0), '0');
      expect(Analytics.countBucket(1), '1-9');
      expect(Analytics.countBucket(49), '10-49');
      expect(Analytics.countBucket(1000), '200+');
    });
  });

  test('没有初始化时 track 是空操作，不抛异常', () {
    Analytics.track('app_open', {'entries': '1-9'});
    Analytics.setEnabled(false);
    expect(Analytics.active, isFalse);
  });

  test('真的发出去了：路径、App-Key、事件名、属性都对', () async {
    if (!Analytics.configured) {
      markTestSkipped('未传 --dart-define=APTABASE_KEY，跳过端到端检查');
      return;
    }

    // flutter_test 默认会把所有 HttpClient 换成「返回 400 且不发包」的假实现，
    // 这里要真的打到本地假服务端，所以把全局覆盖摘掉。
    HttpOverrides.global = null;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 41888);
    final hits = <Map<String, Object?>>[];
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      hits.add({
        'path': req.uri.path,
        'key': req.headers.value('app-key'),
        'body': body,
      });
      req.response.statusCode = 200;
      await req.response.close();
    });

    // SDK 每次上报都会读包信息，测试环境没有插件，得给它假值
    PackageInfo.setMockInitialValues(
      appName: '年轮',
      packageName: 'com.example.growth_ring',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    // 事件队列存在 SharedPreferences 里，测试环境同样要打桩
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await Analytics.start(
      enabled: true,
      options: const InitOptions(
        host: 'http://127.0.0.1:41888',
        tickDuration: Duration(milliseconds: 120),
      ),
    );
    Analytics.track('app_open', {'entries': '1-9'});

    // 队列是每 tick 批量发的，等它跑一两轮
    for (var i = 0; i < 30 && hits.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(hits, isNotEmpty, reason: '事件没有发出去');
    final first = hits.first;
    expect(first['path'], '/api/v0/events');
    expect(first['key'], 'A-SH-0000000000');

    final events = jsonDecode(first['body'] as String) as List;
    final event = events.first as Map<String, Object?>;
    expect(event['eventName'], 'app_open');
    expect((event['props'] as Map)['entries'], '1-9');
    // 会话标识是随机串，不是设备号
    expect((event['sessionId'] as String).isNotEmpty, isTrue);

    await server.close(force: true);
  });
}
