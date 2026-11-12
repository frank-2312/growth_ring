import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 版本清单里的一条。清单本身是仓库根目录的 update.json，
/// 发版时改它、传 APK，客户端就能看到更新。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.urls,
    required this.notes,
    this.minVersionCode = 0,
    this.publishedAt = '',
    this.sha256 = '',
  });

  final String version;

  /// 对应 pubspec 里 `version: 1.0.0+2` 的那个 2
  final int versionCode;

  /// 下载地址，按顺序尝试。清单里写 `urls`（数组）或 `url`（单个）都行，
  /// 前面那个 404/超时就自动换下一个——镜像站和个人图床都不太可靠。
  final List<String> urls;

  /// 更新说明，换行会被保留
  final String notes;

  /// 低于这个 versionCode 的版本强制更新（0 表示不强制）
  final int minVersionCode;

  final String publishedAt;

  /// 安装包的 sha256（小写）。留空表示不校验；填了就必须对得上，
  /// 否则删掉重下——走第三方镜像或代理时，这是唯一能发现被换包的办法。
  final String sha256;

  /// 第一个下载地址，给日志和旧代码用
  String get url => urls.isEmpty ? '' : urls.first;

  bool isNewerThan(int localCode) => versionCode > localCode;

  bool isMandatoryFor(int localCode) =>
      minVersionCode > 0 && localCode < minVersionCode;

  /// 解析失败返回 null：清单写错时宁可什么都不弹，也别弹个空窗
  static UpdateInfo? fromJson(Map<String, Object?> j) {
    final urls = _urlList(j);
    final code = _int(j['version_code']);
    if (urls.isEmpty || code <= 0) return null;
    return UpdateInfo(
      version: _str(j['version']),
      versionCode: code,
      urls: urls,
      notes: _str(j['notes']),
      minVersionCode: _int(j['min_version_code']),
      publishedAt: _str(j['published_at']),
      sha256: _str(j['sha256']).toLowerCase(),
    );
  }
}

/// `urls` 优先，其次旧的 `url`。空串和不是 http(s) 的直接丢掉，
/// 免得一条写错的地址把整个清单拖成"没有更新"。
List<String> _urlList(Map<String, Object?> j) {
  final out = <String>[];
  final raw = j['urls'];
  if (raw is List) {
    for (final e in raw) {
      final s = _str(e);
      if (s.startsWith('http')) out.add(s);
    }
  }
  if (out.isEmpty) {
    final one = _str(j['url']);
    if (one.startsWith('http')) out.add(one);
  }
  return out;
}

class UpdateCheck {
  const UpdateCheck({this.info, this.error});

  final UpdateInfo? info;
  final String? error;

  bool get hasUpdate => info != null;
}

/// 检查更新 / 下载 / 拉起安装器。
///
/// 不做应用商店，所以没有 Play 的 in-app update；这里走的是最常见的一条路：
/// 拉一个 JSON 清单比版本号 → 下载 APK 到缓存 → 交给系统安装器。
/// 整个过程不上报任何东西。
class Updater {
  const Updater._();

  /// 构建时可覆盖：flutter build apk --dart-define=UPDATE_MANIFEST_URL=...
  /// 多个地址用逗号分隔，按顺序试。
  static const String _customUrl =
      String.fromEnvironment('UPDATE_MANIFEST_URL');

  /// Gitee 上的仓库路径（`账号/仓库名`）。换账号只改这一处；
  /// 想整体换地址，用 --dart-define=UPDATE_MANIFEST_URL 覆盖。
  static const String _giteeRepo = 'frank-2312/growth_ring';

  /// Gitee 排第一：国内直连，不经过任何第三方中转。
  /// 后两个是历史路径，只在 Gitee 不可用时兜底。
  static const List<String> _defaultUrls = [
    'https://gitee.com/$_giteeRepo/raw/main/update.json',
    'https://cdn.jsdelivr.net/gh/frank-2312/growth_ring@main/update.json',
    'https://raw.githubusercontent.com/frank-2312/growth_ring/main/update.json',
  ];

  static List<String> get manifestUrls {
    final custom = _customUrl
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.startsWith('http'))
        .toList();
    return custom.isEmpty ? _defaultUrls : custom;
  }

  /// 请求统一带普通浏览器的 UA 和 Accept。Gitee raw 目前并不拦
  /// Dart 的默认 UA（实测能取），但带上更保险：哪天加了防盗链，
  /// 老版本用户不至于因为一个 header 就集体收不到更新。
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Cache-Control': 'no-cache',
  };

  /// 自动检查的间隔。手动检查不受限制。
  static const Duration autoCheckInterval = Duration(hours: 12);

  static const _kLastCheck = 'update_last_check_at';
  static const _kCache = 'update_last_manifest';

  static Future<int> localVersionCode() async {
    final p = await PackageInfo.fromPlatform();
    return int.tryParse(p.buildNumber) ?? 0;
  }

  /// 形如 `v1.0.0 (1)`，给设置页显示
  static Future<String> localLabel() async {
    final p = await PackageInfo.fromPlatform();
    return 'v${p.version} (${p.buildNumber})';
  }

  static Future<UpdateCheck> check({bool manual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!manual) {
      final last = prefs.getInt(_kLastCheck) ?? 0;
      final cached = prefs.getString(_kCache);
      if (cached != null && now - last < autoCheckInterval.inMilliseconds) {
        return _parse(cached);
      }
    }

    Object? lastError;
    for (final url in manifestUrls) {
      try {
        final resp = await http
            .get(Uri.parse(_bust(url)), headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode}';
          continue;
        }
        final text = utf8.decode(resp.bodyBytes);
        final result = await _parse(text);
        if (result.error != null) {
          lastError = result.error;
          continue;
        }
        await prefs.setString(_kCache, text);
        await prefs.setInt(_kLastCheck, now);
        return result;
      } catch (e) {
        lastError = e;
      }
    }
    return UpdateCheck(error: '检查更新失败：${_short(lastError)}');
  }

  /// 清单只有几百字节，加个时间戳当缓存键：Gitee raw 只缓存 60 秒，
  /// 但 jsDelivr 对分支文件能缓存很久，改完清单不等它过期就看不到新版。
  static String _bust(String url) {
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<UpdateCheck> _parse(String text) async {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const UpdateCheck(error: '版本清单不是合法 JSON');
    }
    if (decoded is! Map) return const UpdateCheck(error: '版本清单格式不对');

    final info = UpdateInfo.fromJson(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (info == null) {
      return const UpdateCheck(error: '版本清单缺少下载地址或 version_code');
    }
    if (!info.isNewerThan(await localVersionCode())) {
      return const UpdateCheck();
    }
    return UpdateCheck(info: info);
  }

  /// 下载到缓存目录。返回的 File 可以直接交给安装器。
  ///
  /// 清单里给了多个地址时逐个试：前一个挂了就换下一个，
  /// 但用户主动取消（[isCancelled]）时不再继续，别让人点了取消还在后台传。
  static Future<File> download(
    UpdateInfo info, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/growth-ring-${info.versionCode}.apk');

    Object? lastError;
    for (final url in info.urls) {
      if (isCancelled()) throw const _Cancelled();
      try {
        await _fetchTo(url, file,
            onProgress: onProgress, isCancelled: isCancelled);
        final bad = await _verify(file, info.sha256);
        if (bad != null) {
          lastError = bad;
          await _deleteQuietly(file);
          continue;
        }
        return file;
      } catch (e) {
        lastError = e;
        if (isCancelledError(e)) rethrow;
        await _deleteQuietly(file);
      }
    }
    throw Exception(info.urls.length > 1
        ? '所有下载地址都失败了：${_short(lastError)}'
        : '下载失败：${_short(lastError)}');
  }

  static Future<void> _fetchTo(
    String url,
    File file, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
  }) async {
    await _deleteQuietly(file);

    final client = http.Client();
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers.addAll(_headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength;
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp.stream) {
        if (isCancelled()) throw const _Cancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      if (sink != null) {
        // 中途失败/取消时别把半截文件留着
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  /// 对得上返回 null，否则返回给用户看的原因
  static Future<String?> _verify(File file, String expected) async {
    if (expected.isEmpty) return null;
    final actual =
        (await sha256.bind(file.openRead()).first).toString().toLowerCase();
    if (actual == expected) return null;
    return '安装包校验不通过（下载可能被篡改）';
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 唤起系统安装器。返回 null 表示已交出控制权，否则是给用户看的错误提示。
  static Future<String?> install(File file) async {
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type == ResultType.done) return null;
    final msg = result.message.trim();
    return msg.isEmpty ? '没能唤起安装器' : '没能唤起安装器：$msg';
  }

  static String _short(Object? e) {
    if (e == null) return '未知原因';
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

bool isCancelledError(Object e) => e is _Cancelled;

String _str(Object? v) => v == null ? '' : v.toString().trim();

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}
