import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/updater.dart';
import '../../shared/widgets/update_prompt.dart';
import '../chat/chat_page.dart';
import '../persona/persona_page.dart';
import '../timeline/timeline_page.dart';
import '../today/today_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    TodayPage(),
    TimelinePage(),
    PersonaPage(),
    ChatPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 只在 release 里自动查：开发时天天改版本号，弹窗只会碍事。
    if (kReleaseMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    }
  }

  /// 启动后晚几秒再查，别和首屏抢带宽，也不打断刚开始写的那句话。
  Future<void> _checkUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final check = await Updater.check();
    if (!mounted || !check.hasUpdate) return;
    final info = check.info!;
    final local = await Updater.localVersionCode();
    if (!mounted) return;
    await UpdatePrompt.show(
      context,
      info,
      mandatory: info.isMandatoryFor(local),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: '今天',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '时光',
          ),
          NavigationDestination(
            icon: Icon(Icons.fingerprint),
            selectedIcon: Icon(Icons.fingerprint),
            label: '画像',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '知己',
          ),
        ],
      ),
    );
  }
}
