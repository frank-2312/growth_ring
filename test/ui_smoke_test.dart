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
      content: '下班路上拐进菜市场，买了两根玉米和一把小葱。摊位老板多塞了一个番茄，'
          '说今天剩得多。回家把玉米煮上，厨房里全是甜味。',
      mood: '平静',
      energy: 3,
      echo: '你把一个没安排的晚上，过出了味道。',
      analyzed: true,
    ),
    DiaryEntry(
      id: 'e1',
      dateKey: '2026-11-03',
      createdAt: DateTime(2026, 11, 3, 22),
      updatedAt: DateTime(2026, 11, 3, 22),
      content: '把阳台那盆快枯的薄荷换了土，剪掉一半的枯枝。\n浇完水放在窗边，下午回来看，叶子好像立起来了一点。',
      mood: '轻快',
      energy: 4,
      echo: '剪掉的那一半，本来就留不住。',
      analyzed: true,
    ),
    DiaryEntry(
      id: 'e2',
      dateKey: '2026-11-01',
      createdAt: DateTime(2026, 11, 1, 23),
      updatedAt: DateTime(2026, 11, 1, 23),
      content: '早上开会开到十一点，方案又被打回来一次。\n下午重新排了一版，比上一版短了一半，反而说得更清楚。',
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
    "summary": "一个习惯把日子排成清单的人：先列出要做的，再一件件划掉。对细节记得久，容易被没做完的小事绊住。",
    "motto": "有时候删掉比加上难。",
    "traits": [
      {"name": "先做出来再改", "detail": "不等条件齐备，边做边调整版本。",
       "strength": 78, "evidence": "下午重新排了一版，比上一版短了一半", "trend": "稳定"},
      {"name": "对小事记得久", "detail": "别人的一个动作、一句话，会在脑子里停留很久。",
       "strength": 71, "evidence": "摊主多塞了一个番茄", "trend": "稳定"}
    ],
    "themes": [{"name": "工作节奏", "weight": 58, "note": "每周都会出现，多半和方案的版本有关"}],
    "patterns": [{"trigger": "当方案被推翻时", "response": "你会先缩到最小可行的那一版", "note": "通常比原来的更清楚"}],
    "people": [{"name": "同事", "role": "同事", "dynamic": "会上直接，会后一起改"}],
    "tensions": [{"between": "「想做得完整」与「想快点交付」", "detail": "所以总在最后一刻删东西"}],
    "blind_spots": ["你写「没什么特别的一天」的次数，比写具体事情还多。"],
    "growth_edges": ["开始注意到，删减之后方案反而更清楚。"],
    "open_question": "如果不用赶时间，你会把那版方案做成什么样？"
  }
  ''');
  state.insights = [
    Insight(
      id: 'i1',
      createdAt: DateTime(2026, 11, 1, 23, 50),
      dateKey: '2026-11-01',
      title: '删减之后才清楚',
      body: '同一件事改到第三版，篇幅少了一半，反而说明白了。你删掉的不是内容，是绕路。',
      quote: '删掉一半之后，剩下的那部分才站得住。',
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
      text: '一个先把日子排成清单的人。方案被退回那天，你没急着解释，先把它缩到最短的一版——'
          '不是认输，是知道哪部分站得住。\n阳台那盆薄荷也是，剪掉一半枯枝之后，你才看清它还活着。',
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
