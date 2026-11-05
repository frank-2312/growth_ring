import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_ring/core/fmt.dart';
import 'package:growth_ring/core/theme.dart';
import 'package:growth_ring/data/models/chat_message.dart';
import 'package:growth_ring/data/models/diary_entry.dart';
import 'package:growth_ring/data/models/insight.dart';
import 'package:growth_ring/data/models/persona.dart';
import 'package:growth_ring/data/repositories/persona_repository.dart';
import 'package:growth_ring/data/settings/settings_store.dart';
import 'package:growth_ring/features/chat/chat_page.dart';
import 'package:growth_ring/features/export/export_page.dart';
import 'package:growth_ring/features/persona/persona_page.dart';
import 'package:growth_ring/features/settings/settings_page.dart';
import 'package:growth_ring/features/timeline/timeline_page.dart';
import 'package:growth_ring/features/today/today_page.dart';
import 'package:growth_ring/state/app_state.dart';
import 'package:provider/provider.dart';

/// 用真实中文字体渲染，否则 flutter_test 默认的 Ahem 字体
/// （每个字符都是 1em 方块）会让中文布局全部偏宽，测出假溢出。
AppState _seedState() {
  final state = AppState(settingsStore: SettingsStore());
  state.entries = [
    // 今天这一篇必须存在，否则「今天」页拿不到 echo，测的就不是真实路径
    DiaryEntry(
      id: 'e0',
      dateKey: Fmt.dateKey(DateTime.now()),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      content: '下班路上突然下起了雨，没带伞。站在便利店门口等了二十分钟，'
          '看着雨把整条街洗了一遍。奇怪的是并不烦。',
      mood: '平静',
      energy: 3,
      echo: '你等了二十分钟，但没觉得自己在浪费时间。',
      analyzed: true,
    ),
    DiaryEntry(
      id: 'e1',
      dateKey: '2026-11-03',
      createdAt: DateTime(2026, 11, 3, 22),
      updatedAt: DateTime(2026, 11, 3, 22),
      content: '今天把那个一直拖着的事做完了。做完发现只花了四十分钟。\n所以之前那三个星期到底在怕什么。',
      mood: '轻快',
      energy: 4,
      echo: '你怕的可能不是这件事本身。',
      analyzed: true,
    ),
    DiaryEntry(
      id: 'e2',
      dateKey: '2026-11-01',
      createdAt: DateTime(2026, 11, 1, 23),
      updatedAt: DateTime(2026, 11, 1, 23),
      content: '妈又打电话来问工作的事。我说挺好的，她说那就好。\n挂了以后在阳台站了很久。'
          '其实想说的是"我有点撑不住"，但话到嘴边变成了"最近挺忙的"。',
      mood: '发闷',
      energy: 2,
      analyzed: true,
    ),
  ];
  state.persona = Persona.fromJsonString('''
  {
    "version": 3,
    "updated_at": "2026-11-03T22:00:00.000",
    "entries_covered": 12,
    "summary": "一个习惯先自己消化情绪的人，对亲近的人尤其报喜不报忧。做事前容易高估难度，做完又觉得不值一提。",
    "motto": "其实想说的是\\"我有点撑不住\\"，但话到嘴边变成了\\"最近挺忙的\\"。",
    "traits": [
      {"name": "把情绪往后放，先处理事情", "detail": "遇到不顺时先想怎么办，情绪通常隔几天才浮上来。",
       "strength": 82, "evidence": "站着等了二十分钟，反而有点高兴", "trend": "稳定"},
      {"name": "对家人过滤坏消息", "detail": "怕对方担心，把求助改写成一切正常。",
       "strength": 76, "evidence": "话到嘴边变成了「最近挺忙的」", "trend": "变强"}
    ],
    "themes": [{"name": "和母亲的关系", "weight": 62, "note": "每周都会出现，语气总是轻描淡写"}],
    "patterns": [{"trigger": "当想开口求助时", "response": "你会先判断对方能不能承受", "note": "保护了别人，代价是自己一直独自扛"}],
    "people": [{"name": "妈", "role": "母亲", "dynamic": "报喜不报忧，双方都在演一切正常"}],
    "tensions": [{"between": "「想被看见」与「怕成为负担」", "detail": "所以说出的话总比心里的话轻一级"}],
    "blind_spots": ["你反复用「其实也没什么」开头，但后面跟的往往是很重的事。"],
    "growth_edges": ["开始注意到拖延的成本主要在等待里。"],
    "open_question": "那三个星期里，真正让你不敢开始的是哪一步？"
  }
  ''');
  state.insights = [
    Insight(
      id: 'i1',
      createdAt: DateTime(2026, 11, 1, 23, 50),
      dateKey: '2026-11-01',
      title: '同一件事的两种版本',
      body: '你在日记里写想说自己撑不住，在电话里说的却是挺忙的。',
      quote: '话到嘴边变成了"最近挺忙的"',
    ),
  ];
  state.chatMessages = [
    ChatMessage(
      id: 'c1',
      fromUser: true,
      text: '你觉得我是个什么样的人？',
      createdAt: DateTime(2026, 11, 4, 20),
    ),
    ChatMessage(
      id: 'c2',
      fromUser: false,
      text: '一个会先替别人想好承受能力的人。上次你妈打电话来，你想说撑不住，最后说的是挺忙的——'
          '不是不想说，是先替她算了一遍说出来会怎样。\n不过最近有件事不一样了，那个拖了三周的事，'
          '你做完了只花了四十分钟。你自己也问了句「到底在怕什么」。',
      createdAt: DateTime(2026, 11, 4, 20, 1),
    ),
  ];
  state.stats = const PersonaStats(
    entryCount: 12,
    firstDateKey: '2026-10-01',
    lastDateKey: '2026-11-03',
  );
  state.booted = true;
  return state;
}

Widget _wrap(AppState state, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: RingTheme.dark().copyWith(
        textTheme: RingTheme.dark().textTheme.apply(fontFamily: 'WenKai'),
      ),
      home: child,
    ),
  );
}

Future<void> _render(
  WidgetTester tester,
  AppState state,
  Widget page, {
  Size size = const Size(390, 844),
  void Function()? verify,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(state, page));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull, reason: '页面渲染抛异常');

  // 关键：断言在滚动与卸载之前做，否则顶部的 widget 已被回收
  verify?.call();

  // 滚到底，让所有 Sliver 都实际构建一次，才能暴露下半屏的溢出
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -1200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: '滚动时抛异常');
  }

  // 触发 dispose，清掉防抖 Timer
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('WenKai')
      ..addFont(rootBundle.load('assets/fonts/LXGWWenKai-Regular.ttf'));
    // 字体加载失败就让整组失败：说明 asset 没打进包里，这比布局假过更该报警
    await loader.load();
  });

  testWidgets('今天页：有内容 + 有回声', (tester) async {
    await _render(
      tester,
      _seedState(),
      const TodayPage(),
      verify: () {
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('它说'), findsOneWidget);
      },
    );
  });

  testWidgets('今天页：空白草稿', (tester) async {
    final state = _seedState();
    state.entries = const [];
    await _render(tester, state, const TodayPage());
  });

  testWidgets('时光页：多篇日记 + 月份分组', (tester) async {
    await _render(
      tester,
      _seedState(),
      const TimelinePage(),
      verify: () {
        expect(find.text('时光'), findsOneWidget);
        expect(find.text('2026 年 11 月'), findsOneWidget);
        expect(find.text('发闷'), findsOneWidget);
      },
    );
  });

  testWidgets('时光页：空状态', (tester) async {
    final state = _seedState();
    state.entries = const [];
    await _render(tester, state, const TimelinePage());
  });

  testWidgets('画像页：完整画像', (tester) async {
    await _render(
      tester,
      _seedState(),
      const PersonaPage(),
      verify: () {
        expect(find.text('画像'), findsOneWidget);
        expect(find.text('你可能没留意的'), findsOneWidget);
      },
    );
  });

  testWidgets('画像页：空画像 + 有日记待读', (tester) async {
    final state = _seedState();
    state.persona = Persona.empty();
    await _render(
      tester,
      state,
      const PersonaPage(),
      verify: () =>
          expect(find.text('有 ${state.writtenDays} 篇等着被读'), findsOneWidget),
    );
  });

  testWidgets('知己页：已有对话', (tester) async {
    await _render(
      tester,
      _seedState(),
      const ChatPage(),
      verify: () => expect(find.byType(TextField), findsOneWidget),
    );
  });

  testWidgets('知己页：空状态引导', (tester) async {
    final state = _seedState();
    state.chatMessages = const [];
    await _render(
      tester,
      state,
      const ChatPage(),
      verify: () =>
          expect(find.text('你觉得我是个什么样的人？'), findsOneWidget),
    );
  });

  testWidgets('设置页', (tester) async {
    await _render(tester, _seedState(), const SettingsPage());
  });

  testWidgets('导出页', (tester) async {
    await _render(tester, _seedState(), const ExportPage());
  });

  testWidgets('窄屏（320 逻辑宽）下不溢出', (tester) async {
    await _render(tester, _seedState(), const PersonaPage(),
        size: const Size(320, 720));
  });
}
