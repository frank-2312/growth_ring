import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/settings/settings_store.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';

class GrowthRingApp extends StatelessWidget {
  const GrowthRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(settingsStore: SettingsStore())..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: '年轮',
            debugShowCheckedModeBanner: false,
            theme: RingTheme.light(),
            darkTheme: RingTheme.dark(),
            themeMode: state.settings.themeMode,
            home: !state.booted
                ? const _BootstrapScreen()
                : state.bootError != null
                    ? _BootErrorScreen(error: state.bootError!, onRetry: state.init)
                    : const HomeShell(),
          );
        },
      ),
    );
  }
}

/// 首帧只做一件事：把本地数据读出来。刻意不放转圈动画，安静地等一下。
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '年 轮',
          style: TextStyle(fontSize: 20, letterSpacing: 10),
        ),
      ),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(context).textTheme.bodySmall?.color;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 32, color: soft?.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              const Text(
                '打不开本地日记库',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.7, color: soft),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => onRetry(),
                child: const Text('再试一次'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
