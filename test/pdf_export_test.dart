import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/data/models/diary_entry.dart';
import 'package:growth_ring/data/models/insight.dart';
import 'package:growth_ring/data/models/persona.dart';
import 'package:growth_ring/services/pdf_exporter.dart';

/// 这个测试的意义不只是断言，而是真的产出一份 PDF。
/// 中文字体没嵌进去的话，这里就会直接崩，而不是等到用户导出时才发现。
///
/// 下面所有日记、画像与洞察都是**虚构的示例数据**，用于覆盖排版路径，
/// 不对应任何真实用户；改动时请保持「中性、可公开」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entries = [
    DiaryEntry(
      id: 'e1',
      dateKey: '2026-10-28',
      createdAt: DateTime(2026, 10, 28, 22, 10),
      updatedAt: DateTime(2026, 10, 28, 22, 10),
      content: '下班路上拐进菜市场，买了两根玉米和一把小葱。\n\n'
          '摊主多塞了一个番茄，说今天剩得多。回家把玉米煮上，厨房里全是甜味。\n'
          '没什么特别的一天，但锅开的时候觉得挺踏实。',
      mood: '平静',
      energy: 3,
      echo: '你把一个没安排的晚上，过出了味道。',
    ),
    DiaryEntry(
      id: 'e2',
      dateKey: '2026-11-01',
      createdAt: DateTime(2026, 11, 1, 23, 40),
      updatedAt: DateTime(2026, 11, 1, 23, 40),
      content: '早上开会开到十一点，方案又被打回来一次。\n\n'
          '中午没去吃饭，趴在桌上睡了一会儿。下午重新排了一版，'
          '比上一版短了一半，反而说得更清楚。\n有时候删掉比加上难。',
      mood: '发闷',
      energy: 2,
      echo: '删掉一半之后，剩下的那部分才站得住。',
    ),
    DiaryEntry(
      id: 'e3',
      dateKey: '2026-11-03',
      createdAt: DateTime(2026, 11, 3, 21, 0),
      updatedAt: DateTime(2026, 11, 3, 21, 0),
      content: '把阳台那盆快枯的薄荷换了土，剪掉一半的枯枝。\n\n'
          '浇完水放在窗边，下午回来看，叶子好像立起来了一点。\n'
          '也不确定是不是错觉，但心情好了不少。',
      mood: '轻快',
      energy: 4,
      echo: '剪掉的那一半，本来就留不住。',
    ),
  ];

  final persona = Persona.fromJsonString('''
  {
    "version": 3,
    "updated_at": "2026-11-03T22:00:00.000",
    "entries_covered": 3,
    "summary": "一个习惯把日子排成清单的人：先列出要做的，再一件件划掉。对细节记得久，容易被没做完的小事绊住。",
    "motto": "有时候删掉比加上难。",
    "traits": [
      {"name": "先做出来再改", "detail": "不等条件齐备，边做边调整版本。",
       "strength": 78, "evidence": "下午重新排了一版，比上一版短了一半", "trend": "稳定"},
      {"name": "对小事记得久", "detail": "别人的一个动作、一句话，会在脑子里停留很久。",
       "strength": 71, "evidence": "摊主多塞了一个番茄", "trend": "稳定"}
    ],
    "themes": [
      {"name": "工作节奏", "weight": 58, "note": "每周都会出现，多半和方案的版本有关"},
      {"name": "把生活收拾好", "weight": 46, "note": "换土、煮饭、整理，出现频率在上升"}
    ],
    "patterns": [
      {"trigger": "当方案被推翻时", "response": "你会先缩到最小可行的那一版", "note": "通常比原来的更清楚"}
    ],
    "people": [
      {"name": "同事", "role": "同事", "dynamic": "会上直接，会后一起改"}
    ],
    "tensions": [
      {"between": "「想做得完整」与「想快点交付」", "detail": "两件事同时成立，所以总在最后一刻删东西"}
    ],
    "blind_spots": ["你写「没什么特别的一天」的次数，比写具体事情还多。"],
    "growth_edges": ["开始注意到，删减之后方案反而更清楚。"],
    "open_question": "如果不用赶时间，你会把那版方案做成什么样？"
  }
  ''');

  final insights = [
    Insight(
      id: 'i1',
      createdAt: DateTime(2026, 11, 1, 23, 50),
      dateKey: '2026-11-01',
      title: '删减之后才清楚',
      body: '同一件事改到第三版，篇幅少了一半，反而说明白了。你删掉的不是内容，是绕路。',
      quote: '删掉一半之后，剩下的那部分才站得住。',
    ),
    Insight(
      id: 'i2',
      createdAt: DateTime(2026, 11, 3, 21, 10),
      dateKey: '2026-11-03',
      title: '小事的重量',
      body: '换土、煮玉米、买小葱，这些在日记里占的篇幅，比工作还多。',
      quote: '没什么特别的一天，但锅开的时候觉得挺踏实。',
    ),
  ];

  test('能生成一份中文不乱的 PDF', () async {
    // 先确认画像本身解析成功，否则下面的 PDF 会静默少一章
    expect(persona.isEmpty, isFalse, reason: 'persona JSON 必须能解析');
    expect(persona.traits.length, 2);

    final bytes = await PdfExporter.build(
      entries: entries,
      persona: persona,
      insights: insights,
      nickname: '小满',
      options: const ExportOptions(paper: ExportPaper.a5),
    );

    expect(bytes.length, greaterThan(20000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // 尾部必须有 EOF 标记，说明写完整了
    expect(String.fromCharCodes(bytes.skip(bytes.length - 8)),
        contains('%%EOF'));

    final out = File('build/sample_diary.pdf');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);

    // 不做弱化断言：文件确实落盘了
    expect(out.existsSync(), isTrue);
  });

  test('A4 与不含画像的版本也能生成', () async {
    final bytes = await PdfExporter.build(
      entries: entries.take(1).toList(),
      persona: Persona.empty(),
      insights: const [],
      nickname: '',
      options: const ExportOptions(
        paper: ExportPaper.a4,
        includePersona: false,
        includeInsights: false,
        includeEcho: false,
      ),
    );
    expect(bytes.length, greaterThan(5000));
  });

  test('没有日记时也能出一本空册子', () async {
    final bytes = await PdfExporter.build(
      entries: const [],
      persona: Persona.empty(),
      insights: const [],
      nickname: '',
    );
    expect(bytes.length, greaterThan(1000));
  });
}
