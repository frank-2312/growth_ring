<img src="design/app_icon_source.jpg" width="88" align="left" alt="年轮图标" hspace="16" vspace="4" />

# 年轮 · growth_ring

一本会越来越懂你的日记本。

写日记 → 它读 → 它对你形成一个**可被推翻的假设** → 假设随日记不断修正 → 你可以和这个「假设」对话。

三件事是它的全部：

1. **写**：一天一篇，自动保存，可选情绪与精力，不打扰。
2. **懂**：每篇日记被读成结构化事实，定期合并进一份画像（特质、模式、矛盾、盲点）。
3. **导出**：把日记和画像排成一本可以打印的 PDF 小书。

> 一个本地优先的 Flutter 日记 App：数据只存在你的设备上，没有账号、没有云同步。匿名统计只数事件、不含内容，设置页可关。LLM 能力可选，服务端地址由你自己填写，项目本身不绑定任何模型供应商。

---

## 快速开始

### 环境要求

| 项 | 说明 |
| --- | --- |
| Flutter | 3.47.9 / Dart 3.13.7（此版本下验证通过） |
| JDK | 17 |
| Android SDK | platform 36、build-tools、NDK、CMake（Android Studio 会自动补齐缺失组件） |

> 本仓库只包含 Android 工程。iOS / Web / Windows 目录已移除，需要时用
> `flutter create --platforms=ios .`（或 `web`、`windows`）重建：模板能重建，
> 但定制过的图标与显示名需要重做。

### 运行

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### 构建 Android APK

```bash
flutter build apk --release     # 产物在 build/app/outputs/flutter-apk/
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

默认 APK 约 70 MB 量级，其中中文字体占 19 MB。想瘦身可以二选一：

```bash
flutter build apk --release --split-per-abi   # 按架构分包，单个约 35-40 MB
```

或把 `assets/fonts/LXGWWenKai-Regular.ttf` 子集化成 GB2312 常用字（约 3-4 MB，代价是生僻字可能缺字）。

### 关于 Gradle 镜像

仓库里 Android 侧的构建配置默认走了国内镜像，为的是在国内网络下能稳定拉到依赖：

- `android/gradle/wrapper/gradle-wrapper.properties`：Gradle 发行版指向腾讯云镜像
- `android/settings.gradle.kts`：`pluginManagement` 优先阿里云 Maven，官方源保留作兜底
- `android/gradle.properties`：Gradle 堆上限设为 3G（按 8 GB 内存的机器调整过）

在海外网络或内存更充裕的机器上，把前两项改回 `services.gradle.org` 与 `google()` / `mavenCentral()` / `gradlePluginPortal()`，按需要调大 `-Xmx` 即可。这部分只影响构建能否拉到依赖，**不影响 App 行为**。

---

## 发布与更新

不用应用商店，靠一份放在网上的清单自查有没有新版：启动 3 秒后拉 `update.json`，
拿里面的 `version_code` 和本地 build number 比大小，大了就弹窗。整个过程纯 HTTP，
不发通知、不常驻后台。

清单地址是**编译时**写进包里的，换地址老用户不会自己知道——要换就趁早，或者换之前先发一版"多地址"的包。

### 清单放在哪儿

`lib/core/updater.dart` 里的默认顺序：

1. `https://gitee.com/frank-2312/growth_ring/raw/main/update.json`
2. `https://cdn.jsdelivr.net/gh/frank-2312/growth_ring@main/update.json`
3. `https://raw.githubusercontent.com/frank-2312/growth_ring/main/update.json`

Gitee 排第一：国内直连，不经过第三方。后两个只在 Gitee 不可用时兜底。

> 仓库路径写在 `Updater._giteeRepo`（`账号/仓库名`）。注册好 Gitee 之后先把它改成实际账号，
> 否则 Gitee 这一源会一直 404——客户端会静默跳到 jsDelivr 兜底，看起来"能用"，其实主路径没生效。

构建时可以整体覆盖，多个地址用逗号分隔、按顺序试：

```bash
flutter build apk --release \
  --dart-define=UPDATE_MANIFEST_URL=https://a.com/update.json,https://b.com/update.json
```

### 发一版新包

1. 改 `pubspec.yaml`：`version: 1.0.0+2`，`+` 后面的数字**必须**比上一版大。
2. 构建，并记下校验值：

```bash
flutter build apk --release
sha256sum build/app/outputs/flutter-apk/app-release.apk     # macOS: shasum -a 256
```

3. 把 APK 传到 Gitee 仓库的「发行版 / Release」作为附件。单个附件上限 100 MB，
   每个仓库的附件总量上限 1 GB——旧版本的包记得删，否则十几个版本就满了。
4. 改仓库根目录的 `update.json`，`version_code` 必须等于上一步的 build number：

```json
{
  "version": "1.0.1",
  "version_code": 2,
  "urls": [
    "https://gitee.com/frank-2312/growth_ring/releases/download/v1.0.1/app-release.apk",
    "https://备选地址/app-release.apk"
  ],
  "sha256": "第 2 步算出来的值",
  "notes": "更新说明，换行会保留",
  "min_version_code": 0,
  "published_at": "2026-11-20"
}
```

5. 推 Gitee，顺手同步一份到 GitHub（两边清单保持一致）。
6. 自己先在设置页点「检查更新」验一遍，再对外说。

### 几个坑

- `urls` 写多个会按顺序试：前一个 404、超时或校验不过就自动换下一个；老的单个 `url` 仍然兼容。
- `sha256` 留空表示不校验；填了就必须对得上，对不上会删掉包、换源重试，
  最后报"所有下载地址都失败了"。走第三方镜像时这条是唯一的安全线。
- `min_version_code` 大于 0 且用户版本低于它 → 强制更新，弹窗关不掉、没有「稍后」，慎用。
- Gitee raw 实测用任意 UA 都能取（含 Dart 默认 UA），代码里仍带了浏览器 UA 和 `Accept`——
  哪天它加了防盗链，老版本用户不会因为一个 header 集体收不到更新。
- Gitee raw 只有 60 秒缓存（`Cache-Control: max-age=60`），改完一两分钟就能看到；
  会拖很久的是 jsDelivr 对分支文件的缓存，所以客户端请求统一加了 `?t=时间戳` 绕开缓存。
- 清单返回 200 但内容是 HTML（登录页、404 页）时，客户端会判定"不是合法 JSON"并换下一个源，
  所以多源清单很有必要——一个源抽风不至于让所有人收不到更新。
- 签过名的包换了 keystore 会装不上（"应用未安装"），发版前确认签名没变。

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

日记的写入、时间线浏览与 PDF 导出都不经过模型；只有下面三种主动操作才会发起请求：点「让它看一眼」、点「读一读」、在知己里发消息。

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
| `tensions` | 同时成立的矛盾，比如「想独立」与「怕被落下」 |
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

中文字体已内嵌（`assets/fonts/LXGWWenKai-Regular.ttf`，霞鹜文楷；许可全文见 [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)）。

> **这是这类需求最大的坑**：`pdf` 包不认识系统字体，不嵌 TTF 的话导出整页都是方块。字体经子集化后，3 篇日记的 PDF 约 79 KB。

一份实际产物见 [`docs/sample_diary.pdf`](docs/sample_diary.pdf)（7 页，A5）。其中的日记、画像与对话都是虚构的示例数据，不对应任何真实用户。

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

- 日记只存在本机 SQLite，没有账号、没有同步。
- 匿名统计（[Aptabase](https://aptabase.com)，开源）：只上报「打开、开始写、聊天、导出、更新画像」这类事件，字数与篇数只给区间；不含日记内容，不含 IMEI / OAID / 广告 ID，靠随机安装 ID 区分实例。设置页「隐私」里可一键关闭，关掉后不再上报。
- 只有三种情况文字会离开设备：点「让它看一眼」/「读一读」/ 在知己里发消息。
- 目标服务器是**你自己填的**，中间没有第三方。
- API Key 存系统安全存储；若设备不支持会自动降级到普通存储，并在设置页明确告知。
- 统计 key 通过构建参数注入，源码里没有任何密钥；不传 key 时统计整体是空操作。

```bash
flutter build apk --release --dart-define=APTABASE_KEY=A-EU-XXXXXXXXXX
```

---

## 测试

```bash
flutter test
```

| 文件 | 覆盖 |
| --- | --- |
| `test/core_test.dart` | 日期/字数/摘要、画像与 digest 的容错解析、JSON 提取 |
| `test/llm_client_test.dart` | 请求体、SSE 跨分片拼接、401/404/超时/空响应的错误翻译 |
| `test/pdf_export_test.dart` | 真实生成 PDF 并落盘到 `build/sample_diary.pdf`（`docs/` 下的示例即由此产出） |
| `test/ui_smoke_test.dart` | 六个页面在 390 与 320 逻辑宽度下渲染不溢出 |
| `test/analytics_test.dart` | 分桶区间；带 `--dart-define=APTABASE_KEY=...` 时用本地假服务端验证事件真的按协议发出 |

UI 测试会加载真实中文字体——`flutter_test` 默认的 Ahem 字体每个字符都是方块宽，不换字体测出来的都是假溢出。

CI 由 `.github/workflows/ci.yml` 提供：静态分析 + 测试 + Android release 构建，产出 APK artifact。

---

## 当前状态

| 项目 | 状态 |
| --- | --- |
| `flutter analyze` | 0 issue |
| 单元 + UI 渲染测试 | 63 个通过 |
| PDF 导出（含中文嵌入） | 已验证 |
| Android release APK | 已构建通过 |
| 真机安装 | 未在真机验证 |
| iOS / Web / Windows | 未提供工程目录，按需用 `flutter create` 重建 |

---

## 还没做的

- 图片 / 语音日记
- 多设备同步、备份导入
- 按标签检索、全文搜索
- 端上小模型（现在必须联网）
- iOS 支持：目录已移除，重建后还需补 ATS 配置（用 http 的本地服务时需要加白名单）

---

## 图标

指纹年轮：脊线既是树的一圈圈年轮，也是一个人的指纹。两者的共同点是——每一圈都不重复。

- 源图：`design/app_icon_source.jpg`
- 生成：`python tool/make_icons.py`（需要 `pip install pillow`）

脚本会先算出年轮图案的实际半径，把图案之外的区域压成统一底色，再生成
Android 传统图标（5 档）与自适应图标（foreground + 纯色背景 + `anydpi-v26` 描述），
以及 15 个 iOS 尺寸（仓库当前不含 `ios/`，脚本检测到目录不存在会自动跳过）。

**图案大小**由 `TARGET_PATTERN_RATIO` 控制（当前 `0.72`，实测成品图案直径占图标
可见区的 70%）。觉得图标太满就调小、太空就调大，改完重跑即可。

> 注意「可见区」不等于画布：自适应图标画布是 108dp，但 launcher 只显示中间
> 72dp 那部分。所以直接按画布比例缩放会让图案在桌面上显得偏大。

> **不做压平会怎样**：自适应图标的前景层是个正方形，被系统裁成圆形后，
> 原图自带的暗色纹理和背景色不一致，会露出一圈明显的方形接缝。

---

## License

本项目代码采用 [MIT](LICENSE)。

`assets/fonts/LXGWWenKai-Regular.ttf`（霞鹜文楷 / LXGW WenKai）是第三方字体作品，版权归原作者 LXGW 所有，依 **SIL Open Font License 1.1** 单独授权，**不在本仓库 MIT 许可范围内**。许可全文、版权声明与保留字体名条款随字体提供：[`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)。再分发或修改时请一并遵守这些条款——尤其不要用保留字体名发布修改版。

除上述字体外，本仓库的其余内容（含 `design/` 下的图标素材与 `tool/` 下的脚本）随代码以 MIT 发布。
