import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/core/fmt.dart';
import 'package:growth_ring/data/models/companion_style.dart';
import 'package:growth_ring/data/models/diary_entry.dart';
import 'package:growth_ring/data/models/entry_digest.dart';
import 'package:growth_ring/data/models/persona.dart';
import 'package:growth_ring/llm/llm_client.dart';
import 'package:growth_ring/llm/prompts.dart';

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
        "people": [{"name":"老周","role":"同事","dynamic":"说话直接"}],
        "tensions": [{"between":"想留下 / 想走","detail":"d"}],
        "blind_spots": ["x"],
        "growth_edges": ["y"],
        "open_question": "z"
      }
      ''');
      final again = Persona.fromJsonString(p.toJsonString());
      expect(again.version, 3);
      expect(again.traits.single.name, 'a');
      expect(again.people.single.name, '老周');
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

  group('知己的性格配置', () {
    test('默认配置：不强调提旧事，滑杆全在中间偏低', () {
      const s = CompanionStyle();
      final block = s.toPromptBlock();
      expect(block.contains('你没有特别的名字'), isTrue);
      expect(block.contains('几乎不提'), isTrue);
      expect(block.contains('温度：'), isTrue);
    });

    test('维度越高，交代得越极端', () {
      const cold = CompanionStyle(warmth: 10);
      const hot = CompanionStyle(warmth: 95);
      expect(cold.toPromptBlock().contains('偏冷'), isTrue);
      expect(hot.toPromptBlock().contains('偏热'), isTrue);
    });

    test('名字与自定交代会进 prompt', () {
      const s = CompanionStyle(name: '老陈', note: '别老问我问题');
      final block = s.toPromptBlock();
      expect(block.contains('你叫「老陈」'), isTrue);
      expect(block.contains('别老问我问题'), isTrue);
    });

    test('序列化往返 + 坏数据回退默认', () {
      const s = CompanionStyle(
        name: '阿木',
        relation: CompanionRelation.stranger,
        warmth: 12,
        memory: 88,
        note: '可以损我',
      );
      final back = CompanionStyle.fromJsonString(s.toJsonString());
      expect(back.name, '阿木');
      expect(back.relation, CompanionRelation.stranger);
      expect(back.memory, 88);
      expect(back.note, '可以损我');

      expect(CompanionStyle.fromJsonString('坏了').relation,
          CompanionRelation.oldFriend);
      // 越界数值被夹紧，不要让滑杆外的脏数据把 UI 撑崩
      expect(CompanionStyle.fromJson({'warmth': 500}).warmth, 100);
    });

    test('预设只覆盖脾气，不动名字和备注', () {
      const base = CompanionStyle(name: '阿木', note: '别问');
      final preset = CompanionPreset.all.first.style;
      expect(preset.name, isEmpty);
      expect(base.copyWith(warmth: preset.warmth).name, '阿木');
      // 四套预设的脾气确实不同，否则这个功能是假的
      final fingerprints =
          CompanionPreset.all.map((p) => p.style.toJsonString()).toSet();
      expect(fingerprints.length, CompanionPreset.all.length);
    });
  });

  group('知己 prompt：像人而不像档案', () {
    List<Map<String, String>> build({
      CompanionStyle style = const CompanionStyle(),
      Persona? persona,
    }) =>
        Prompts.companion(
          persona: persona ?? Persona.empty(),
          nickname: 'Frank',
          style: style,
          recentDigests: const [],
          recentEntries: const [],
        );

    test('性格配置写在最前面，且原样进入 system', () {
      final msgs = build(style: const CompanionStyle(name: '老陈'));
      expect(msgs, hasLength(1));
      expect(msgs.first['content']!.startsWith('你叫「老陈」'), isTrue);
    });

    test('不再把画像整块 JSON 塞进去', () {
      final persona = Persona.fromJsonString('''
      {
        "version": 2,
        "summary": "一个把事往自己身上揽的人",
        "motto": "算了，我来吧",
        "traits": [{"name":"先做再改","detail":"不等条件齐备","strength":80,"evidence":"e","trend":"稳定"}],
        "blind_spots": ["很少承认自己累"]
      }
      ''');
      final content = build(persona: persona).first['content']!;
      // 人话式的记忆，不是可枚举的字段
      expect(content.contains('"traits"'), isFalse);
      expect(content.contains('"summary"'), isFalse);
      expect(content.contains('一个把事往自己身上揽的人'), isTrue);
      expect(content.contains('很少承认自己累'), isTrue);
    });

    test('明确要求不要硬贴旧事、不要心理复述', () {
      final content = build().first['content']!;
      expect(content.contains('默认不用'), isTrue);
      expect(content.contains('不要每次都把 TA 的话翻译成情绪结论'), isTrue);
      expect(content.contains('一轮对话里不要连着两次翻旧事'), isTrue);
      // 反面例子必须在，否则模型仍会滑回咨询师腔
      expect(content.contains('听起来你在职场中常常感到被忽视'), isTrue);
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
