import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/data/models/diary_entry.dart';
import 'package:growth_ring/data/models/insight.dart';
import 'package:growth_ring/data/models/persona.dart';
import 'package:growth_ring/services/pdf_exporter.dart';

/// 这个测试的意义不只是断言，而是真的产出一份 PDF。
/// 中文字体没嵌进去的话，这里就会直接崩，而不是等到用户导出时才发现。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entries = [
    DiaryEntry(
      id: 'e1',
      dateKey: '2026-10-28',
      createdAt: DateTime(2026, 10, 28, 22, 10),
      updatedAt: DateTime(2026, 10, 28, 22, 10),
      content: '下班路上突然下起了雨，没带伞。\n\n站在便利店门口等了二十分钟，'
          '看着雨把整条街洗了一遍。奇怪的是并不烦，反而有点高兴——'
          '好像终于有正当理由可以什么都不做了。',
      mood: '平静',
      energy: 3,
      echo: '你等了二十分钟，但没觉得自己在浪费时间。',
    ),
    DiaryEntry(
      id: 'e2',
      dateKey: '2026-11-01',
      createdAt: DateTime(2026, 11, 1, 23, 40),
      updatedAt: DateTime(2026, 11, 1, 23, 40),
      content: '妈又打电话来问工作的事。我说挺好的，她说那就好。\n'
          '挂了以后在阳台站了很久。其实想说的是"我有点撑不住"，'
          '但话到嘴边变成了"最近挺忙的"。\n\n'
          '好像从小就是这样，报喜不报忧，说了她也帮不上忙，还要多一个人担心。',
      mood: '发闷',
      energy: 2,
      echo: '你把想说的话翻译成了她听得懂、但你不想说的版本。',
    ),
    DiaryEntry(
      id: 'e3',
      dateKey: '2026-11-03',
      createdAt: DateTime(2026, 11, 3, 21, 0),
      updatedAt: DateTime(2026, 11, 3, 21, 0),
      content: '今天把那个一直拖着的事做完了。做完发现只花了四十分钟。\n'
          '所以之前那三个星期到底在怕什么。',
      mood: '轻快',
      energy: 4,
    ),
  ];

  final persona = Persona.fromJsonString('''
  {
    "version": 3,
    "updated_at": "2026-11-03T22:00:00.000",
    "entries_covered": 3,
    "summary": "一个习惯先自己消化情绪的人，对亲近的人尤其报喜不报忧。做事前容易高估难度，做完又觉得不值一提。",
    "motto": "其实想说的是\\"我有点撑不住\\"，但话到嘴边变成了\\"最近挺忙的\\"。",
    "traits": [
      {"name": "把情绪往后放，先处理事情", "detail": "遇到不顺时先想怎么办，情绪通常隔几天才浮上来。",
       "strength": 82, "evidence": "站着等了二十分钟，反而有点高兴", "trend": "稳定"},
      {"name": "对家人过滤坏消息", "detail": "怕对方担心，把求助改写成一切正常。",
       "strength": 76, "evidence": "话到嘴边变成了「最近挺忙的」", "trend": "变强"}
    ],
    "themes": [
      {"name": "和母亲的关系", "weight": 62, "note": "每周都会出现，语气总是轻描淡写"},
      {"name": "启动困难", "weight": 55, "note": "真正做起来比预想的轻"}
    ],
    "patterns": [
      {"trigger": "当想开口求助时", "response": "你会先判断对方能不能承受", "note": "保护了别人，代价是自己一直独自扛"}
    ],
    "people": [
      {"name": "妈", "role": "母亲", "dynamic": "报喜不报忧，双方都在演一切正常"}
    ],
    "tensions": [
      {"between": "「想被看见」与「怕成为负担」", "detail": "两件事同时成立，所以说出的话总比心里的话轻一级"}
    ],
    "blind_spots": ["你反复用「其实也没什么」开头，但后面跟的往往是很重的事。"],
    "growth_edges": ["开始注意到「拖延的成本主要在等待里」，这是一个松动的迹象。"],
    "open_question": "那三个星期里，真正让你不敢开始的是哪一步？"
  }
  ''');

  final insights = [
    Insight(
      id: 'i1',
      createdAt: DateTime(2026, 11, 1, 23, 50),
      dateKey: '2026-11-01',
      title: '同一件事的两种版本',
      body: '你在日记里写想说自己撑不住，在电话里说的却是挺忙的。这不是撒谎，是习惯性的减震。',
      quote: '话到嘴边变成了"最近挺忙的"',
    ),
    Insight(
      id: 'i2',
      createdAt: DateTime(2026, 11, 3, 21, 10),
      dateKey: '2026-11-03',
      title: '拖延的成本在等待期',
      body: '三个星期的焦虑，换来四十分钟的完成。你怕的可能不是这件事本身。',
      quote: '所以之前那三个星期到底在怕什么',
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
      nickname: 'Frank',
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
