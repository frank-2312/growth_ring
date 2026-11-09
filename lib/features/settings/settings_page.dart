import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart';
import '../../core/theme.dart';
import '../../data/settings/settings_store.dart';
import '../../state/app_state.dart';
import '../chat/companion_settings_page.dart';
import '../export/export_page.dart';
import '../../shared/widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _nickname;

  double _temperature = 0.7;
  bool _testing = false;
  String? _testResult;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _baseUrl = TextEditingController(text: s.llm.baseUrl);
    _apiKey = TextEditingController(text: s.llm.apiKey);
    _model = TextEditingController(text: s.llm.model);
    _nickname = TextEditingController(text: s.nickname);
    _temperature = s.llm.temperature;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _nickname.dispose();
    super.dispose();
  }

  AppSettings _collect(AppState state) => state.settings.copyWith(
        llm: LlmConfig(
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.trim(),
          model: _model.text.trim(),
          temperature: _temperature,
        ),
        nickname: _nickname.text.trim(),
      );

  Future<void> _save({bool quiet = false}) async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.updateSettings(_collect(state));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('存好了')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final state = context.read<AppState>();
    await state.updateSettings(_collect(state));
    try {
      final reply = await state.testConnection();
      if (!mounted) return;
      setState(() => _testResult = '通了。模型回了：$reply');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(),
            child: const Text('保存'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SectionLabel('模型'),
          const _Hint('填任意 OpenAI 兼容接口即可，例如百炼、DeepSeek、Kimi，或本机的 Ollama。'),
          const SizedBox(height: 14),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: '接口地址',
              hintText: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: 'qwen-plus / deepseek-chat / llama3.1',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('温度', style: TextStyle(fontSize: 12, color: soft)),
              Expanded(
                child: Slider(
                  value: _temperature,
                  min: 0,
                  max: 1.2,
                  divisions: 12,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _temperature = v),
                ),
              ),
              Text(
                _temperature.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const _Hint('写画像时用 0.4 左右更稳定，聊天时希望有点人味可以调高到 0.8。'),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : const Icon(Icons.bolt_outlined, size: 16),
                label: Text(_testing ? '正在试…' : '测试连接'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _testResult!,
                style: const TextStyle(fontSize: 11.5, height: 1.6),
              ),
            ),
          ],

          const SizedBox(height: 30),
          SectionLabel('习惯'),
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(
              labelText: '它怎么称呼你',
              hintText: '留空就用「你」',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('写完自动更新画像', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '每攒够 3 篇新日记，后台自动读一次。关掉就只能手动点「读一读」。',
              style: TextStyle(fontSize: 11, color: soft, height: 1.6),
            ),
            value: state.settings.autoReflect,
            onChanged: (v) async {
              await state.updateSettings(state.settings.copyWith(autoReflect: v));
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('外观', style: TextStyle(fontSize: 13, color: soft)),
              const SizedBox(width: 16),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11.5),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: ThemeMode.dark, label: Text('夜')),
                  ButtonSegment(value: ThemeMode.light, label: Text('纸')),
                  ButtonSegment(value: ThemeMode.system, label: Text('跟随')),
                ],
                selected: {state.settings.themeMode},
                onSelectionChanged: (v) async {
                  await state.updateSettings(
                    state.settings.copyWith(themeMode: v.first),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 30),
          SectionLabel('隐私'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('匿名使用统计', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '只记「打开了、开始写了、聊了几句、导出了」这类事，'
              '连字数都只记区间；不带日记内容，不带设备标识，也不知道你是谁。'
              '${Analytics.configured ? '' : '（这个安装包没有接入统计）'}',
              style: TextStyle(fontSize: 11, color: soft, height: 1.6),
            ),
            value: state.settings.analytics,
            onChanged: (v) async {
              await state.updateSettings(state.settings.copyWith(analytics: v));
            },
          ),

          const SizedBox(height: 30),
          SectionLabel('知己'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune, size: 20),
            title: const Text('它的样子', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '${state.settings.companion.displayName} · '
              '${state.settings.companion.relation.label}的口气、脾气、提不提旧事',
              style: TextStyle(fontSize: 11, color: soft),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CompanionSettingsPage()),
            ),
          ),

          const SizedBox(height: 30),
          SectionLabel('数据'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            title: const Text('导出 PDF', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '把日记和画像排成一本可以打印的书',
              style: TextStyle(fontSize: 11, color: soft),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportPage()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, size: 20),
            title: const Text('清空所有日记', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '不可撤销。导出 PDF 是唯一的备份方式。',
              style: TextStyle(fontSize: 11, color: soft),
            ),
            onTap: _confirmWipe,
          ),

          const SizedBox(height: 30),
          SectionLabel('关于你的字'),
          Text(
            '日记存在这台设备上，不上传任何服务器。\n'
            '只有在你点「让它看一眼」、「读一读」或和它聊天时，相关的文字才会发给你自己配置的模型服务商。\n'
            '匿名统计只会知道「有人打开了、开始写了、聊了几句」，既不含日记内容，也不含设备标识。\n'
            'API Key 存在系统的安全存储里${state.settingsStore.secureStorageUnavailable ? '（这台设备上安全存储不可用，已降级为普通存储，请留意）' : ''}。\n\n'
            '它不是心理医生，也不该被当成心理医生。它只是一个记性很好、愿意说实话的读者。',
            style: TextStyle(fontSize: 11.5, height: 1.9, color: soft),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '年轮 v1.0',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: soft.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确定要清空吗？'),
        content: const Text('所有日记、画像和对话都会消失，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('算了'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().wipeEverything();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已经清空了')));
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.65,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
