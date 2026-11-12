import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/core/updater.dart';

/// 清单是手写的，最容易错在字段上：`urls` 写成字符串、`version_code` 带了引号、
/// 地址里混进一个空串。这些都不该让整个更新链路哑掉。
void main() {
  group('UpdateInfo.fromJson', () {
    test('只有单个 url（老格式）也能解析', () {
      final info = UpdateInfo.fromJson({
        'version': '1.0.1',
        'version_code': 2,
        'url': 'https://a.example.com/app.apk',
        'notes': '修了几处',
      });

      expect(info, isNotNull);
      expect(info!.urls, ['https://a.example.com/app.apk']);
      expect(info.url, 'https://a.example.com/app.apk');
      expect(info.versionCode, 2);
      expect(info.notes, '修了几处');
      expect(info.sha256, isEmpty);
    });

    test('urls 数组优先，空串和非 http 地址被丢掉', () {
      final info = UpdateInfo.fromJson({
        'version': '1.0.1',
        'version_code': 2,
        'url': 'https://old.example.com/app.apk',
        'urls': [
          ' https://a.example.com/1.apk ',
          '',
          'ftp://b.example.com/2.apk',
          'https://c.example.com/3.apk',
        ],
      });

      expect(info!.urls, [
        'https://a.example.com/1.apk',
        'https://c.example.com/3.apk',
      ]);
      // 数组有效时不该回落到 url 字段
      expect(info.url, 'https://a.example.com/1.apk');
    });

    test('urls 全是脏数据时回落到 url', () {
      final info = UpdateInfo.fromJson({
        'version_code': 3,
        'url': 'https://a.example.com/app.apk',
        'urls': ['', '   '],
      });

      expect(info!.urls, ['https://a.example.com/app.apk']);
    });

    test('没有可用下载地址 → null（宁可静默，也不弹空窗）', () {
      expect(
        UpdateInfo.fromJson({'version_code': 3, 'url': ''}),
        isNull,
      );
      expect(
        UpdateInfo.fromJson({
          'version_code': 3,
          'urls': ['ftp://x/y.apk'],
        }),
        isNull,
      );
    });

    test('version_code 缺失或非正数 → null', () {
      expect(UpdateInfo.fromJson({'url': 'https://a/x.apk'}), isNull);
      expect(
        UpdateInfo.fromJson({'url': 'https://a/x.apk', 'version_code': 0}),
        isNull,
      );
    });

    test('version_code 写成字符串也能读', () {
      final info = UpdateInfo.fromJson({
        'url': 'https://a/x.apk',
        'version_code': ' 7 ',
      });
      expect(info!.versionCode, 7);
    });

    test('sha256 统一转小写，方便和算出来的值直接比', () {
      final info = UpdateInfo.fromJson({
        'url': 'https://a/x.apk',
        'version_code': 2,
        'sha256': '  ABC123DEF  ',
      });
      expect(info!.sha256, 'abc123def');
    });
  });

  group('版本比较', () {
    final info = UpdateInfo.fromJson({
      'url': 'https://a/x.apk',
      'version_code': 5,
      'min_version_code': 3,
    })!;

    test('比本地大才算有新版本', () {
      expect(info.isNewerThan(4), isTrue);
      expect(info.isNewerThan(5), isFalse);
      expect(info.isNewerThan(6), isFalse);
    });

    test('低于 min_version_code 才是强制更新', () {
      expect(info.isMandatoryFor(2), isTrue);
      expect(info.isMandatoryFor(3), isFalse);
      expect(info.isMandatoryFor(4), isFalse);
    });

    test('min_version_code 为 0 表示永不强制', () {
      final soft = UpdateInfo.fromJson({
        'url': 'https://a/x.apk',
        'version_code': 9,
      })!;
      expect(soft.isMandatoryFor(1), isFalse);
    });
  });
}
