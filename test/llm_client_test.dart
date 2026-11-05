import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/data/settings/settings_store.dart';
import 'package:growth_ring/llm/llm_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// LlmClient 预留了 http.Client 注入口，这里用 MockClient 精确控制协议层，
/// 验证请求体长什么样、SSE 怎么切分、错误是否翻译成人话。
void main() {
  Map<String, Object?>? lastBody;
  String? lastAuth;

  LlmClient build(
    Future<http.Response> Function(http.Request req) handler, {
    String baseUrl = 'https://api.test/v1',
    String key = 'sk-test',
  }) {
    final mock = MockClient((req) async {
      lastAuth = req.headers['authorization'];
      if (req.body.isNotEmpty) {
        lastBody = jsonDecode(req.body) as Map<String, Object?>;
      }
      return handler(req);
    });
    return LlmClient(
      LlmConfig(baseUrl: baseUrl, apiKey: key, model: 'qwen-plus'),
      client: mock,
    );
  }

  http.Response json200(String content) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {'content': content}
            }
          ]
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  setUp(() {
    lastBody = null;
    lastAuth = null;
  });

  test('非流式：解析 content，携带鉴权与模型参数', () async {
    final client = build((_) async => json200('通了'));

    final reply = await client.complete([
      {'role': 'user', 'content': '在吗'}
    ]);

    expect(reply, '通了');
    expect(lastAuth, 'Bearer sk-test');
    expect(lastBody?['model'], 'qwen-plus');
    expect(lastBody?['stream'], false);
    client.dispose();
  });

  test('非流式：content 是数组时也能拼出文本', () async {
    final client = build((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': '第一段'},
                    {'type': 'text', 'text': '第二段'}
                  ]
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    expect(
      await client.complete([
        {'role': 'user', 'content': 'x'}
      ]),
      '第一段第二段',
    );
    client.dispose();
  });

  test('流式：SSE 分片按顺序拼接，[DONE] 正确收尾', () async {
    final pieces = ['你', '好', '，今天', '也没做什么。'];
    final mock = MockClient.streaming((request, bodyStream) async {
      lastBody = jsonDecode(await bodyStream.bytesToString())
          as Map<String, Object?>;
      final sse = StringBuffer();
      for (final p in pieces) {
        sse.write('data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': p}
                }
              ]
            })}\n\n');
      }
      sse.write('data: [DONE]\n\n');
      return http.StreamedResponse(
        Stream.fromIterable([utf8.encode(sse.toString())]),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

    final client = LlmClient(
      const LlmConfig(
        baseUrl: 'https://api.test/v1',
        apiKey: 'sk-test',
        model: 'qwen-plus',
      ),
      client: mock,
    );

    final collected = StringBuffer();
    await for (final chunk in client.stream([
      {'role': 'user', 'content': '说说我'}
    ])) {
      collected.write(chunk);
    }

    expect(collected.toString(), '你好，今天也没做什么。');
    expect(pieces.length, 4);
    expect(lastBody?['stream'], true);
    client.dispose();
  });

  test('流式：分片被切成多段边界也能拼对', () async {
    final full = 'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': '完整的句子'}
            }
          ]
        })}\n\ndata: [DONE]\n\n';
    final bytes = utf8.encode(full);

    final mock = MockClient.streaming((request, bodyStream) async {
      // 故意按 7 字节一段切开，制造跨行、跨字符的边界
      final chunks = <List<int>>[];
      for (var i = 0; i < bytes.length; i += 7) {
        chunks.add(bytes.sublist(i, (i + 7).clamp(0, bytes.length)));
      }
      return http.StreamedResponse(
        Stream.fromIterable(chunks),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

    final client = LlmClient(
      const LlmConfig(
          baseUrl: 'https://api.test/v1', apiKey: 'k', model: 'm'),
      client: mock,
    );

    final collected = StringBuffer();
    await for (final chunk in client.stream([
      {'role': 'user', 'content': 'x'}
    ])) {
      collected.write(chunk);
    }
    expect(collected.toString(), '完整的句子');
    client.dispose();
  });

  test('401：错误信息说人话并带上服务端原因', () async {
    final client = build((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'error': {'message': 'Incorrect API key provided'}
          })),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    try {
      await client.complete([
        {'role': 'user', 'content': 'x'}
      ]);
      fail('应该抛异常');
    } on LlmException catch (e) {
      expect(e.statusCode, 401);
      expect(e.message, contains('密钥'));
      expect(e.message, contains('Incorrect API key'));
    }
    client.dispose();
  });

  test('404 提示检查 /v1 结尾', () async {
    final client = build((_) async => http.Response('', 404));
    try {
      await client.complete([
        {'role': 'user', 'content': 'x'}
      ]);
      fail('应该抛异常');
    } on LlmException catch (e) {
      expect(e.message, contains('/v1'));
    }
    client.dispose();
  });

  test('completeJson：剥掉 markdown 围栏', () async {
    final client = build(
        (_) async => json200('好的：\n```json\n{"summary": "安静的一个人"}\n```'));

    final result = await client.completeJson([
      {'role': 'user', 'content': '给我 json'}
    ]);

    expect(result['summary'], '安静的一个人');
    client.dispose();
  });

  test('completeJson：返回非 JSON 时给出可重试的提示', () async {
    final client = build((_) async => json200('我不太确定该说什么'));
    try {
      await client.completeJson([
        {'role': 'user', 'content': '给我 json'}
      ]);
      fail('应该抛异常');
    } on LlmException catch (e) {
      expect(e.message, contains('JSON'));
    }
    client.dispose();
  });

  test('超时：换成可读提示', () async {
    final mock = MockClient((req) async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return json200('迟到的回复');
    });
    final client = LlmClient(
      const LlmConfig(
          baseUrl: 'https://api.test/v1', apiKey: 'k', model: 'm'),
      client: mock,
    );

    try {
      await client.complete(
        [
          {'role': 'user', 'content': 'x'}
        ],
        timeout: const Duration(milliseconds: 200),
      );
      fail('应该超时');
    } on LlmException catch (e) {
      expect(e.message, contains('超时'));
    }
    client.dispose();
  });

  test('未配置时立刻报错，不发请求', () async {
    var called = false;
    final mock = MockClient((req) async {
      called = true;
      return json200('不该到这里');
    });
    final client = LlmClient(const LlmConfig(), client: mock);

    try {
      await client.complete([
        {'role': 'user', 'content': 'x'}
      ]);
      fail('应该抛异常');
    } on LlmException catch (e) {
      expect(e.message, contains('设置'));
    }
    expect(called, isFalse);
    client.dispose();
  });

  test('空内容视为异常，避免把空字符串写进日记', () async {
    final client = build((_) async => json200(''));
    try {
      await client.complete([
        {'role': 'user', 'content': 'x'}
      ]);
      fail('应该抛异常');
    } on LlmException catch (e) {
      expect(e.message, contains('空内容'));
    }
    client.dispose();
  });

  test('baseUrl 规范化：容忍尾斜杠与完整路径', () {
    const a = LlmConfig(baseUrl: 'https://x.com/v1/', apiKey: 'k', model: 'm');
    expect(a.normalizedBase, 'https://x.com/v1');

    const b = LlmConfig(
      baseUrl: 'https://x.com/v1/chat/completions',
      apiKey: 'k',
      model: 'm',
    );
    expect(b.normalizedBase, 'https://x.com/v1');

    const c = LlmConfig(baseUrl: '  https://x.com/v1//  ', apiKey: 'k', model: 'm');
    expect(c.normalizedBase, 'https://x.com/v1');

    expect(const LlmConfig().isConfigured, isFalse);
    expect(a.isConfigured, isTrue);
  });
}
