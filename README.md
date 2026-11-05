<img src="design/app_icon_source.jpg" width="88" align="left" alt="年轮图标" hspace="16" vspace="4" />

# 年轮 · growth_ring

一本会越来越懂你的日记本。

写日记 → 它读 → 它对你形成一个**可被推翻的假设** → 假设随日记不断修正 → 你可以和这个「假设」对话。

三件事是它的全部：

1. **写**：一天一篇，自动保存，可选情绪与精力，不打扰。
2. **懂**：每篇日记被读成结构化事实，定期合并进一份画像（特质、模式、矛盾、盲点）。
3. **导出**：把日记和画像排成一本可以打印的 PDF 小书。

---

## 现在能跑吗

| 项目 | 状态 |
| --- | --- |
| `flutter analyze` | 0 issue |
| 单元 + UI 渲染测试 | 40 个全通过 |
| PDF 导出（含中文嵌入） | 已验证，见 `docs/sample_diary.pdf` |
| Android 构建 | **已构建成功**：`build/app/outputs/flutter-apk/app-release.apk`（68.5 MB，arm64，minSdk 24 / target 36） |
| 真机安装 | 未验证 —— 构建时没有连接设备 |

---

## 环境（本机已配好）

| 项 | 值 |
| --- | --- |
| Flutter | 3.47.9 / Dart 3.13.7，`C:\dev\flutter` |
| Android SDK | `C:\dev\android-sdk`（已 `flutter config --android-sdk` 指向） |
| SDK 组件 | platform-tools 37.0.1、platforms android-34/35/36、build-tools 36.0.0、NDK 28.2.13676358、CMake 3.22.1 |
| JDK | `C:\Program Files\Java\jdk-17` |
| pub 镜像 | `https://pub.flutter-io.cn` |

### 构建命令

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export JAVA_HOME="/c/Program Files/Java/jdk-17"
export ANDROID_HOME="C:\\dev\\android-sdk"

flutter pub get
flutter build apk --release     # 产物在 build/app/outputs/flutter-apk/
flutter test                    # 40 个测试
```

### 这台机器上的三个坑（都已修好，换机器时注意）

1. **Gradle 堆开太大**：Flutter 模板默认 `-Xmx8G`，本机物理内存只有 8G，
   JVM 会疯狂交换，构建慢到像卡死。已改为 `-Xmx3G`（见 `android/gradle.properties`）。
2. **Gradle 发行版下载卡住**：`services.gradle.org` 会 307 跳到 **github.com**，
   而这里 GitHub 直连不通。已把 `distributionUrl` 换成腾讯云镜像。
3. **Maven 依赖慢**：已在 `settings.gradle.kts` 和 `build.gradle.kts` 里
   加了阿里云镜像（google / public / gradle-plugin），官方源保留作兜底。

> 首次构建 Gradle 会自动补装 Platform 34 与 CMake 3.22.1，属正常现象，
> 之后有缓存就快得多（本次冷构建 24 分钟，热构建几十秒）。
>
> **Windows 开发者模式**未开启时 `pub get` 会警告符号链接，但这次 release
> 构建并未受阻。若日后遇到 `Building with plugins requires symlink support`，
> 用管理员身份执行 `start ms-settings:developers` 打开开关即可。

### 装到手机

APK 是 arm64 的，直接拷到手机点安装（需允许「安装未知来源应用」）。
或开 USB 调试后：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

体积 68.5 MB，其中中文字体占 19 MB。想瘦身可以二选一：

```bash
flutter build apk --release --split-per-abi   # 按架构分包，单个约 35-40 MB
```

或把 `assets/fonts/LXGWWenKai-Regular.ttf` 子集化成 GB2312 常用字（约 3-4 MB，
代价是生僻字可能缺字）。

---

## 配置模型

进入 App →「今天」页右上角 → 设置 → 填三项即可。只支持 **OpenAI 兼容协议**，所以换供应商只是换一行地址：

| 服务 | 接口地址 | 模型名示例 |
| --- | --- | --- |
| 阿里云百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Kimi | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| 本机 Ollama | `http://192.168.x.x:11434/v1` | `qwen2.5:14b` |

配好后点「测试连接」，通了会回一句「通了」。

**温度建议**：画像合并走代码里的 0.5，聊天默认 0.7～0.8。设置页的滑块影响聊天手感。

---

## 它怎么「懂」你

这是这个项目的重点，也是唯一值得解释的设计。

### 两步走，而不是一步

```
日记原文 ──[提取]──> 结构化事实 (digest) ──[合并]──> 画像 (persona)
             每篇一次调用              攒够一批才做一次
```

**为什么不直接让模型「总结一下我」？** 因为那样每次都要重读全文，贵且漂移。拆成两步后：

- 读过的日记不必再读，重算画像只花一次调用
- 单篇的提取结果可以单独检查——你能看到它到底从哪句话里得出了什么
- 画像的演进是可审计的：每一版快照都留在数据库里

### 画像长什么样

不是 MBTI，不是性格标签，是八个具体的东西：

| 字段 | 回答什么问题 |
| --- | --- |
| `summary` | 此刻的你，两三句话 |
| `traits` | 你性格里的几处，**每条必须带原文证据** |
| `patterns` | 「当 X 时，你会 Y」的反复手感 |
| `tensions` | 同时成立的矛盾，比如「想被看见」与「怕成为负担」 |
| `blind_spots` | 你写了很多次但没点明的东西 |
| `themes` | 占位置的事，带权重 |
| `people` | 反复出现的人，以及你们的相处方式 |
| `open_question` | 它还没弄明白的一件事 |

`blind_spots` 和 `open_question` 是刻意留的。一个真的了解你的人，会说出你没注意到的模式，也会承认自己还没搞懂。假装全知，是最廉价的模仿。

### 反讨好是写在 prompt 里的硬约束

`lib/llm/prompts.dart` 里明确禁止：`加油` `你很棒` `相信自己` `建议你` `抱抱`。
同时要求：每条判断必须有日记原文作为 `evidence`，写不出证据的删掉；旧结论没有新证据就保留，被推翻要标 `trend: 变弱` 并说明依据。

### 成本控制

- 少于 10 个字的日记不送模型（一句「今天累」榨不出什么，还费 token）
- 单次反思最多读 6 篇，剩下的下次继续
- 自动反思的阈值是攒够 3 篇，不是每篇都跑
- 只有你点「让它看一眼」「读一读」或聊天时才发起调用

---

## PDF 导出

中文字体已内嵌（`assets/fonts/LXGWWenKai-Regular.ttf`，霞鹜文楷，SIL OFL 1.1）。

> **这是这类需求最大的坑**：`pdf` 包不认识系统字体，不嵌 TTF 的话导出整页都是方块。字体经子集化后，3 篇日记的 PDF 约 57 KB。

排版结构：封面（含「这一刻的你」）→ 按月分章的正文（每篇带当天回声）→ 画像全文 → 洞察时间线 → 后记。

纸张可选 A5（像本小书）或 A4（便于打印）。导出后可预览、存到手机或走系统打印。

---

## 目录结构

```
lib/
├── main.dart / app.dart          入口与主题装配
├── core/
│   ├── theme.dart                纸与墨的配色，深/浅两套
│   └── fmt.dart                  日期、字数、摘要（不依赖 locale 数据）
├── data/
│   ├── db/app_database.dart      SQLite schema
│   ├── models/                   DiaryEntry / Persona / Insight / Digest
│   ├── repositories/             按聚合拆的三个仓库
│   └── settings/                 API Key 走安全存储，失败自动降级
├── llm/
│   ├── llm_client.dart           OpenAI 兼容客户端（流式/非流式/错误翻译）
│   ├── prompts.dart              四条 prompt，产品的灵魂在这里
│   └── persona_engine.dart       提取 + 合并的编排
├── services/pdf_exporter.dart    PDF 排版
├── state/app_state.dart          单一状态宿主（ChangeNotifier）
├── features/                     today / timeline / persona / chat / settings / export
└── shared/widgets/               跨页面复用的小组件
```

### 数据流

```
TodayPage ──(1.4s 防抖)──> AppState.saveEntry ──> DiaryRepository ──> SQLite
                                │
                                └──> (手动) PersonaEngine.echo ──> LlmClient
PersonaPage ──(点「读一读」)──> PersonaEngine.reflect
                                  ├─ 逐篇 digest ──> digests 表
                                  └─ merge ──> persona_snapshots（新版本）
ChatPage ──> AppState.sendMessage ──> 画像 + 近期读解 注入 system ──> 流式 SSE
```

---

## 隐私

- 日记只存在本机 SQLite，没有账号、没有同步、没有埋点。
- 只有三种情况文字会离开设备：点「让它看一眼」/「读一读」/ 在知己里发消息。
- 目标服务器是**你自己填的**，中间没有第三方。
- API Key 存系统安全存储；若设备不支持会自动降级到普通存储，并在设置页明确告知。

---

## 还没做的

- 图片 / 语音日记
- 多设备同步、备份导入
- 按标签检索、全文搜索
- 端上小模型（现在必须联网）
- iOS 的 ATS 配置（若用 http 的本地服务需要额外加白名单）

## 测试

```bash
flutter test
```

| 文件 | 覆盖 |
| --- | --- |
| `test/core_test.dart` | 日期/字数/摘要、画像与 digest 的容错解析、JSON 提取 |
| `test/llm_client_test.dart` | 请求体、SSE 跨分片拼接、401/404/超时/空响应的错误翻译 |
| `test/pdf_export_test.dart` | 真实生成 PDF 并落盘到 `build/sample_diary.pdf` |
| `test/ui_smoke_test.dart` | 六个页面在 390 与 320 逻辑宽度下渲染不溢出 |

UI 测试会加载真实中文字体——`flutter_test` 默认的 Ahem 字体每个字符都是方块宽，不换字体测出来的都是假溢出。

---

## 图标

指纹年轮：脊线既是树的一圈圈年轮，也是一个人的指纹。两者的共同点是——每一圈都不重复。

- 源图：`design/app_icon_source.jpg`
- 生成：`python tool/make_icons.py`（需要 `pip install pillow`）

脚本会先算出年轮图案的实际半径，把图案之外的区域压成统一底色，再生成
Android 传统图标（5 档）与自适应图标（foreground + 纯色背景 + `anydpi-v26` 描述），
顺带产出 15 个 iOS 尺寸。

**图案大小**由 `TARGET_PATTERN_RATIO` 控制（当前 `0.72`，实测成品图案直径占图标
可见区的 70%）。觉得图标太满就调小、太空就调大，改完重跑即可。

> 注意「可见区」不等于画布：自适应图标画布是 108dp，但 launcher 只显示中间
> 72dp 那部分。所以直接按画布比例缩放会让图案在桌面上显得偏大。

> **不做压平会怎样**：自适应图标的前景层是个正方形，被系统裁成圆形后，
> 原图自带的暗色纹理和背景色不一致，会露出一圈明显的方形接缝。

## License

[MIT](LICENSE)。

字体霞鹜文楷（LXGW WenKai）为 SIL Open Font License 1.1，可自由分发与嵌入。

