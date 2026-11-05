import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/settings/settings_store.dart';

class LlmException implements Exception {
  LlmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 只做一件最小的事：按 OpenAI 兼容协议说话。
/// 不绑定任何供应商，因此换模型等于改一个字符串。
class LlmClient {
  LlmClient(this.config, {http.Client? client}) : _client = client ?? http.Client();

  final LlmConfig config;
  final http.Client _client;

  Uri get _endpoint => Uri.parse('${config.normalizedBase}/chat/completions');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${config.apiKey}',
      };

  void _ensureConfigured() {
    if (!config.isConfigured) {
      throw LlmException('还没填写模型配置。先去「设置」里填好接口地址、密钥和模型名。');
    }
  }

  /// 一次性拿到完整回复
  Future<String> complete(
    List<Map<String, String>> messages, {
    double? temperature,
    int maxTokens = 2048,
    Duration timeout = const Duration(seconds: 120),
    bool jsonMode = false,
  }) async {
    _ensureConfigured();

    final body = <String, Object?>{
      'model': config.model,
      'messages': messages,
      'temperature': temperature ?? config.temperature,
      'max_tokens': maxTokens,
      'stream': false,
    };
    if (jsonMode) {
      // 多数兼容实现支持；不支持的会忽略该字段，prompt 里已要求纯 JSON
      body['response_format'] = {'type': 'json_object'};
    }

    http.Response resp;
    try {
      resp = await _client
          .post(_endpoint, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw LlmException('模型响应超时（${timeout.inSeconds} 秒）。可以稍后重试，或在设置里换一个更快的模型。');
    } catch (e) {
      throw LlmException('连不上模型服务：${_humanizeNetworkError(e)}');
    }

    if (resp.statusCode != 200) {
      throw LlmException(_describeHttpError(resp), statusCode: resp.statusCode);
    }

    final text = _extractContent(resp.bodyBytes);
    if (text.trim().isEmpty) {
      throw LlmException('模型返回了空内容，可能是触发了内容过滤，换个说法再试。');
    }
    return text;
  }

  /// 要求模型返回 JSON，并容忍它偷偷加了 ```json 包裹
  Future<Map<String, Object?>> completeJson(
    List<Map<String, String>> messages, {
    double? temperature,
    int maxTokens = 4096,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final raw = await complete(
      messages,
      temperature: temperature ?? 0.3,
      maxTokens: maxTokens,
      timeout: timeout,
      jsonMode: true,
    );
    final map = tryParseJsonObject(raw);
    if (map == null) {
      throw LlmException('模型没有返回可解析的 JSON。可以重试一次；若反复出现，换一个指令遵循更好的模型。');
    }
    return map;
  }

  /// 流式：逐段吐字，用于「知己」对话
  Stream<String> stream(
    List<Map<String, String>> messages, {
    double? temperature,
    int maxTokens = 2048,
  }) async* {
    _ensureConfigured();

    final body = jsonEncode({
      'model': config.model,
      'messages': messages,
      'temperature': temperature ?? config.temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', _endpoint)
      ..headers.addAll(_headers)
      ..body = body;

    http.StreamedResponse resp;
    try {
      resp = await _client.send(request);
    } catch (e) {
      throw LlmException('连不上模型服务：${_humanizeNetworkError(e)}');
    }

    if (resp.statusCode != 200) {
      final raw = await resp.stream.bytesToString();
      throw LlmException(_describeRawError(resp.statusCode, raw),
          statusCode: resp.statusCode);
    }

    var buffer = '';
    final isSse = (resp.headers['content-type'] ?? '').contains('event-stream');

    await for (final chunk
        in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final line = chunk.trim();
      if (line.isEmpty) continue;

      if (!isSse) {
        // 少数服务端忽略 stream=true，直接返回完整 JSON
        buffer += chunk;
        continue;
      }

      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final decoded = jsonDecode(payload);
        final delta = _deltaOf(decoded);
        if (delta != null && delta.isNotEmpty) yield delta;
      } catch (_) {
        // 单条分片损坏不应中断整段回复
      }
    }

    if (!isSse && buffer.trim().isNotEmpty) {
      final text = _safeExtract(buffer);
      if (text != null && text.isNotEmpty) yield text;
    }
  }

  /// 设置页的「测试连接」：发一条最短的消息验证三要素是否正确
  Future<String> testConnection() async {
    _ensureConfigured();
    final reply = await complete(
      [
        {'role': 'user', 'content': '只回复两个字：通了'},
      ],
      maxTokens: 16,
      temperature: 0,
      timeout: const Duration(seconds: 30),
    );
    return reply.trim();
  }

  void dispose() => _client.close();

  // --- 内部 ---------------------------------------------------------------

  String _extractContent(List<int> bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    final text = _safeExtract(raw);
    if (text == null) {
      // 有些实现返回纯文本而非 JSON
      if (!raw.trimLeft().startsWith('{')) return raw;
      throw LlmException('返回格式不是预期的 chat/completions 结构，请确认接口地址是否以 /v1 结尾。');
    }
    return text;
  }

  String? _safeExtract(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      final message = first['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String) return content;
        // 部分模型返回 content 数组（多模态格式）
        if (content is List) {
          return content
              .whereType<Map>()
              .map((e) => e['text'])
              .whereType<String>()
              .join();
        }
      }
      final delta = first['delta'];
      if (delta is Map && delta['content'] is String) {
        return delta['content'] as String;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _deltaOf(Object? decoded) {
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is Map) {
      final c = delta['content'];
      if (c is String) return c;
    }
    return null;
  }

  String _describeHttpError(http.Response resp) =>
      _describeRawError(resp.statusCode, utf8.decode(resp.bodyBytes, allowMalformed: true));

  String _describeRawError(int code, String raw) {
    final hint = switch (code) {
      401 => '密钥不对或已失效，检查一下 API Key。',
      403 => '这个密钥没有调用该模型的权限。',
      404 => '接口地址可能写错了，通常应以 /v1 结尾。',
      429 => '调用太密或额度用完了，等一下再试。',
      >= 500 => '模型服务端出问题了，不是你这边的原因，过一会儿再试。',
      _ => '请求被拒绝。',
    };
    final detail = _shortServerMessage(raw);
    return '[$code] $hint${detail.isEmpty ? '' : '\n$detail'}';
  }

  String _shortServerMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return (err['message'] as String).trim();
        }
        if (decoded['message'] is String) {
          return (decoded['message'] as String).trim();
        }
      }
    } catch (_) {
      // 忽略
    }
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length > 200 ? '${clean.substring(0, 200)}…' : clean;
  }

  String _humanizeNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return '网络不通或域名解析失败。手机能上网吗？接口地址是否还有效？';
    }
    if (s.contains('HandshakeException') || s.contains('CERTIFICATE')) {
      return 'HTTPS 证书校验失败，如果用的是自建服务，请确认证书链完整。';
    }
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }
}

/// 从模型输出里挖出 JSON：去掉 ```json 围栏、前后废话，做括号配平。
Map<String, Object?>? tryParseJsonObject(String raw) {
  var text = raw.trim();

  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final fenced = fence.firstMatch(text);
  if (fenced != null) text = fenced.group(1)!.trim();

  final direct = _tryDecode(text);
  if (direct != null) return direct;

  // 括号配平扫描，跳过字符串里的花括号
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return _tryDecode(text.substring(start, i + 1));
      }
    }
  }
  return null;
}

Map<String, Object?>? _tryDecode(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
  } catch (_) {
    // 不是合法 JSON
  }
  return null;
}
