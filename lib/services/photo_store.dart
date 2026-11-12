import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日记配图存在应用私有目录里：`photos/<dateKey>/<文件名>`。
///
/// 为什么不用绝对路径存库：备份恢复到新设备、或者应用目录变了以后，
/// 绝对路径会全部失效；只存文件名，拼路径这件事交给这里。
/// 为什么不进系统相册：日记配图是私事，不该莫名其妙出现在相册里。
class PhotoStore {
  const PhotoStore._();

  /// 启动时初始化一次，之后 [fileOf] 就能同步拼出路径，列表里不必堆 FutureBuilder
  static String? _rootPath;

  static String get rootPath => _rootPath ?? '';

  static bool get ready => _rootPath != null;

  static Future<void> init() async {
    if (_rootPath != null) return;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _rootPath = dir.path;
  }

  static Future<Directory> _dayDir(String dateKey) async {
    if (_rootPath == null) await init();
    final dir = Directory(p.join(_rootPath!, dateKey));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 图片的同步路径。没初始化时返回一个不存在的路径，由调用方的
  /// errorBuilder 兜底，不至于把页面搞崩。
  static File fileOf(String dateKey, String name) =>
      File(p.join(rootPath, dateKey, name));

  /// 把选择器给的临时文件搬进应用目录，返回文件名（存进 DiaryEntry.photos）。
  /// 选择器的文件在缓存目录里，随时可能被系统清掉，所以必须复制一份。
  static Future<String> import(XFile picked, String dateKey) async {
    final dir = await _dayDir(dateKey);
    final name = '${DateTime.now().millisecondsSinceEpoch}'
        '${_randSuffix()}${_ext(picked.name)}';
    await picked.saveTo(p.join(dir.path, name));
    return name;
  }

  static Future<void> remove(String dateKey, String name) async {
    try {
      final f = fileOf(dateKey, name);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 删不掉也无所谓，别把删日记这件事卡住
    }
  }

  /// 删掉一整天的图（日记被删除时调用）
  static Future<void> removeDay(String dateKey) async {
    try {
      final dir = Directory(p.join(rootPath, dateKey));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // 同上
    }
  }

  /// 「清空所有日记」时一起清掉，否则库里空了、照片还占着地方
  static Future<void> wipeAll() async {
    try {
      final dir = Directory(rootPath);
      if (rootPath.isNotEmpty && await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _rootPath = null;
    } catch (_) {
      // 同上
    }
  }

  static String _ext(String name) {
    final e = p.extension(name).toLowerCase();
    if (e == '.jpg' || e == '.jpeg' || e == '.png' || e == '.heic' || e == '.webp') {
      return e;
    }
    return '.jpg';
  }

  static String _randSuffix() {
    final r = Random();
    return '_${r.nextInt(1 << 20).toRadixString(36)}';
  }
}
