import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/core/fmt.dart';
import 'package:growth_ring/data/models/diary_entry.dart';
import 'package:growth_ring/data/models/entry_digest.dart';
import 'package:growth_ring/data/models/persona.dart';
import 'package:growth_ring/llm/llm_client.dart';

void main() {
  group('Fmt', () {
    test('日期键补零', () {
      expect(Fmt.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(Fmt.dateKey(DateTime(2026, 11, 24)), '2026-11-24');
    });

    test('中文按字、英文按词计', () {
      expect(Fmt.wordCount('今天很累'), 4);
      expect(Fmt.wordCount('hello world'), 2);
      expect(Fmt.wordCount('今天 code review 很累'), 4 + 2);
      expect(Fmt.wordCount('   '), 0);
    });

    test('星期与相对时间', () {
      expect(Fmt.weekday(DateTime(2026, 11, 4)), '周三');
      final now = DateTime(2026, 11, 4, 20);
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 分钟前');
      expect(Fmt.relative(DateTime(2026, 11, 3, 12), now: now), '昨天');
    });

    test('标题从首句推导并截断', () {
      expect(Fmt.deriveTitle('# 今天的雨\n后面还有'), '今天的雨');
      expect(Fmt.deriveTitle(''), isNull);
      final long = Fmt.deriveTitle('一' * 40);
      expect(long!.endsWith('…'), isTrue);
      expect(long.length, 25);
    });

    test('摘要优先停在标点', () {
      final s = Fmt.ellipsis('今天早上去跑步了，然后吃了早饭，接着工作', 12);
      expect(s.endsWith('…'), isTrue);
      expect(s.length, lessThanOrEqualTo(13));
    });
  });

  group('Persona 解析', () {
    test('空字符串得到空画像', () {
      expect(Persona.fromJsonString(null).isEmpty, isTrue);
      expect(Persona.fromJsonString('not json').isEmpty, isTrue);
    });

    test('缺字段不崩，类型错也能兜住', () {
      final p = Persona.fromJsonString('''
      {
        "summary": "一个把话咽回去的人",
        "traits": [
          {"name": "克制", "strength": "80", "evidence": "算了，不说了", "trend": "变强"}
        ],
        "blind_spots": "只给字符串而不是数组",
        "themes": "同样是字符串"
      }
      ''');
      expect(p.summary, '一个把话咽回去的人');
      expect(p.traits.single.strength, 80);
      expect(p.blindSpots.single, '只给字符串而不是数组');
      expect(p.themes, isEmpty); // 类型不对时安全退化为空，不抛异常
    });

    test('序列化再解析保持一致', () {
      final p = Persona.fromJsonString('''
      {
        "version": 3,
        "summary": "s",
        "motto": "m",
        "traits": [{"name":"a","detail":"b","strength":50,"evidence":"e","trend":"稳定"}],
        "themes": [{"name":"t","weight":40,"note":"n"}],
        "patterns": [{"trigger":"当A","response":"就会B","note":"c"}],
        "people": [{"name":"妈","role":"母亲","dynamic":"报喜不报忧"}],
        "tensions": [{"between":"想留下 / 想走","detail":"d"}],
        "blind_spots": ["x"],
        "growth_edges": ["y"],
        "open_question": "z"
      }
      ''');
      final again = Persona.fromJsonString(p.toJsonString());
      expect(again.version, 3);
      expect(again.traits.single.name, 'a');
      expect(again.people.single.name, '妈');
      expect(again.openQuestion, 'z');
    });
  });

  group('EntryDigest', () {
    test('数值越界会被夹紧', () {
      final d = EntryDigest.fromJson({
        'mood': '闷',
        'mood_score': 99,
        'energy': -5,
        'themes': ['工作'],
      });
      expect(d.moodScore, 3);
      expect(d.energy, 1);
      expect(d.themes.single, '工作');
    });

    test('prompt 块包含关键行', () {
      final d = EntryDigest.fromJson({
        'date': '2026-11-04',
        'mood': '平静',
        'mood_score': 1,
        'energy': 3,
        'themes': ['跑步'],
        'self_statements': ['我总是拖延'],
      });
      final block = d.toPromptBlock();
      expect(block.contains('2026-11-04'), isTrue);
      expect(block.contains('我总是拖延'), isTrue);
    });
  });

  group('JSON 提取', () {
    test('剥掉 markdown 围栏', () {
      final r = tryParseJsonObject('```json\n{"a": 1}\n```');
      expect(r?['a'], 1);
    });

    test('忽略前后废话并做括号配平', () {
      final r = tryParseJsonObject('好的，结果如下：{"a": {"b": "带}括号的字符串"}} 完毕');
      expect(r?['a'], isA<Map>());
    });

    test('完全不是 JSON 时返回 null', () {
      expect(tryParseJsonObject('不好意思我不明白'), isNull);
    });
  });

  group('DiaryEntry', () {
    test('数据库往返', () {
      final e = DiaryEntry(
        id: 'e1',
        dateKey: '2026-11-04',
        createdAt: DateTime(2026, 11, 4, 20),
        updatedAt: DateTime(2026, 11, 4, 21),
        content: '今天没做什么',
        mood: '平静',
        energy: 2,
        tags: const ['雨', '独处'],
        echo: '你把一天写成了一句话。',
        analyzed: true,
      );
      final back = DiaryEntry.fromMap(e.toMap());
      expect(back.content, e.content);
      expect(back.tags, e.tags);
      expect(back.analyzed, isTrue);
      expect(back.date, DateTime(2026, 11, 4));
    });
  });
}
