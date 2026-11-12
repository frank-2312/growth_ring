import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/data/models/diary_entry.dart';

DiaryEntry _entry({
  String content = '今天走了很远。',
  List<String> photos = const [],
}) {
  return DiaryEntry(
    id: 'e1',
    dateKey: '2026-11-12',
    createdAt: DateTime(2026, 11, 12, 21),
    updatedAt: DateTime(2026, 11, 12, 21),
    content: content,
    mood: '平静',
    energy: 3,
    photos: photos,
  );
}

void main() {
  group('配图的存取', () {
    test('toMap / fromMap 往返不丢图', () {
      final src = _entry(photos: ['a_1.jpg', 'b_2.png']);
      final back = DiaryEntry.fromMap(src.toMap());

      expect(back.photos, ['a_1.jpg', 'b_2.png']);
      expect(back.content, src.content);
      expect(back.mood, '平静');
    });

    test('库里存的是 JSON 数组，不是拼接字符串', () {
      final map = _entry(photos: ['a_1.jpg', 'b_2.png']).toMap();
      expect(jsonDecode(map['photos'] as String), ['a_1.jpg', 'b_2.png']);
    });

    test('v1 老数据迁移后 photos 是 NULL，当作没有图', () {
      final map = _entry().toMap()..['photos'] = null;
      expect(DiaryEntry.fromMap(map).photos, isEmpty);
    });

    test('列存在但内容是坏 JSON 时不当机', () {
      final map = _entry().toMap()..['photos'] = '{不是数组';
      expect(DiaryEntry.fromMap(map).photos, isEmpty);
    });

    test('数组里混进非字符串或空串，只留下干净的文件名', () {
      final map = _entry().toMap()
        ..['photos'] = jsonEncode(['a.jpg', 3, '', '  ', 'b.jpg']);
      expect(DiaryEntry.fromMap(map).photos, ['a.jpg', 'b.jpg']);
    });
  });

  group('空日记的判定', () {
    test('只有字没有图：不算空', () {
      expect(_entry().isEmpty, isFalse);
    });

    test('只有图没有字：也不算空，那天确实记了一笔', () {
      expect(_entry(content: '', photos: ['a.jpg']).isEmpty, isFalse);
    });

    test('字和空白、也没有图：才算空', () {
      expect(_entry(content: '   ', photos: const []).isEmpty, isTrue);
    });
  });

  group('copyWith', () {
    test('不传 photos 时保留原有的图', () {
      final src = _entry(photos: ['a.jpg']);
      expect(src.copyWith(content: '改了正文').photos, ['a.jpg']);
    });

    test('传空列表是明确要清空', () {
      final src = _entry(photos: ['a.jpg']);
      expect(src.copyWith(photos: const []).photos, isEmpty);
    });
  });
}
