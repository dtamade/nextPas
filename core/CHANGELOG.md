# Changelog

## 1.0.2 (2026-09-02) — nextpas.core.audio 1.5.3 (PR评审闭环)

`78→85` 文件收敛（`29+56`, unique `83+2` bus facade），`11→23` GUID（B前缀 bus异形 `B1A2B3C4-D5E6-7890-ABCD-C00000000001/02`），`14→24` 门 `195→268` tests，`wav` 四件套 L2化 + `opus` 占位 + `bus` 本地 pin/实时零分配/8MB 守卫 + `bench` 扩 `Graph/1K/4K Timeline/1K Loop Device.Drive/1K`，`24` 门 + `85` 文件 + `23` GUID + `test_bus/test_wav` + `Probe≤4KB` + `hygiene` 全绿，`VERSION 1.0.1→1.0.2`。

### Highlights (audio 1.5—1.5.3)

- **audio 1.5 (69→78)**：`codec.flac/mp3/vorbis` 各 `base/intf/impl` 9文件补齐，四件套 `base(L0 only)←intf(仅 IAudioDecoder别名,复用0001)←impl(Probe≤4KB/DecodeWhole/STUB)←facade(type别名+inline转发)` 完整，`registry` 薄封装不硬 `uses` 各 `impl`，实盘 78=`26+52` (unique 76+2)，23 GUID不变
- **audio 1.5.1 (78→81)**：`wav` 四件套 L2化 — 新增 `codec.wav.base(L0 only CWavProbeLimit=4096)/wav.intf(IWavDecoder别名)/wav.impl(Probe≤4KB DecodeWhole/Encode)`，`wav.pas` 精简为 `type`别名+`inline`转发零逻辑，`graph/mix/sinc` 切 `SimdAddF32/SimdMulF32` 与 `bytes.ops` 单源零拷贝，实盘 81=`29+52` (unique 79+2)
- **audio 1.5.2 (81→84)**：`codec.opus` 四件套占位 — `opus.base(L0 only COpusProbeLimit=4096)/opus.intf(IOpusDecoder别名)/opus.impl(OpusProbe≤4KB prOggOpus + DecodeWhole 1024帧静音桩 + STUB: OpenStreaming白名单)/opus.pas(inline+AudioRegisterDecoder自注册)`，守 `bytes.ops` 单源+Probe≤4KB零分配，`bus.impl MixRealtime` 本地 pin `LBus:=FSnapshotBuses[I]` 单次 fetch+Assigned/IsValid守卫，实盘 84=`29+55` (unique 82+2)
- **audio 1.5.3 (84→85)**：PR评审闭环 — `P0` 84→85实盘对齐（`ls 85, for-loop 85, unique 83+2`），`bus MixRealtime` INV-6实时零分配收敛（`FScratch/FSnapshotBuses` 实时不分配，违例 `InterlockedExchangeAdd64(FViolations)` 计数，异构 `Format` 按 per-bus `BlockAlign` 单独计字节，snapshot几何扩容仅控制面），`opus DecodeWhole` 补 `COpusMaxDecodeBytes=8MB(8*1024*1024)` + `COpusOggMinHeader=27` 显式守卫与 `wav MAX_WAV_PAYLOAD` 对称，`bench_pcm_wav` 8项 `Graph/1K/4K Timeline/1K Loop Device.Drive/1K` 已扩，实盘 85=`29+56` (unique 83+2)

### Testing (audio)

- 24门 268 tests `[HEAPTRC] OK`：`test_base 21/test_pcm_wav 12/test_wav 16/test_aiff 11/test_meta 11/test_registry 9/test_resample 14/test_mix 14/test_dsp 14/test_device 15/test_graph 16/test_sfx 15/test_game 15/test_timeline 16/test_flac 8/test_mp3 6/test_vorbis 6/test_spatial 6/test_bus 8/test_bank 15/test_resource 13/test_playlist 8/test_event 10/test_studio 16/test_automation 8`，`85` 文件无 `ffi/vendor` + `23` GUID + `Probe≤4KB` + `实时纪律` + `test_automation` gate 存活，`make hygiene && git diff --check` 绿
- `bench_pcm_wav` 8项 `ns/op + MB/s -O2, HEAPTRC 关`：`Parse/64KB 13µs / Parse/1MB 1.7ms / Write/1MB 997µs CV9% / Graph/1K 19µs / Graph/4K 77µs / Timeline/1K 8µs / TimelineLoop/1K 12µs / Device.Drive/1K 13µs`（`GWrite*` 预分配，`Graph/Timeline` 零分配快照）

## 1.0.1 (2026-09-02) — nextpas.core.zip 1.0.1 巡检

`1.0.0` 后 23 期巡检收敛（S64—S87），`12 门` 扩至 `10→12`（原子选项透传），`zip_roundtrip` 增原子三演示，`CRC 5×`、`TOCTOU`、`原子`、`几何`、`复用`、`bench`、`单源` 多维打磨，`12 门+bench+hygiene` 全绿。

### Highlights (S80—S87)
- **S80 最佳实践合入**：`landing/zip-1.0.1 → main 626cadf7e` path-limited replay，保护未提交脏区，12门全绿
- **S81 六维打磨**：`NormalizeZipReadOptions` 单源（reader/sequential 去重）、`BASELINE.json` 2026-09-02 刷新固化 slice-by-8
- **S82 治理收口**：`bench.baseline` 补 `json.value` 适配 `IsReal/AsFloat` 新门面，16项可编译通过
- **S83 复用收口**：`TryZipMethodFromCode` 单源化 `zmStore/zmDeflate` 映射，`CONTRACT`/`README`/`ROADMAP` 文档同步
- **S84 文档与零堆栈验证**：`CONTRACT §1.2` 补 `TryMethod` 入约、`README S0—S83` 同步，`writer` AES extra `Encode 栈上 7B` + `FScratch 64B` 零堆栈确认，12 门回归
- **S85 AES 单源**：`aes.ResolveZipMethodWithAes` 单源化 `reader/sequential` 的 AES 方法分发重复，`EParseError/ENotSupportedError` 语义守恒
- **S86 Local 单源**：`common.ParseLocalHeader` 单源化 `reader` 双 `LocatePayload` 本地头走查，`bad local header signature` 语义守恒
- **S87 Password 单源**：`common.GuardEntryPassword` 单源化 `reader/sequential` 的缺口令守卫，`EInvalidOperationError` 语义守恒

## 1.0.1 (2026-09-02) — nextpas.core.zip 1.0.1 巡检（S64—S75 基线）

`1.0.0` 后 12 期巡检收敛（S64—S75），`12 门` 扩至 `10→12`（原子选项透传），`zip_roundtrip` 增原子三演示，`CRC 5×`、`TOCTOU`、`原子`、`几何`、`复用` 多维打磨，`12 门+bench+hygiene` 全绿。

### Highlights (S64—S76)
- **S64 复用收敛 II**：`TryDescriptor` 单点 `VerifyParsedValues` 与 `GuardRange` 单点 `GuardCursorRange/GuardRange` 收口
- **S65 性能攻坚**：`checksum.crc32` slice-by-8（8 表并行，`1MiB` 5× 提升）
- **S66 TOCTOU 双校验**：`ADestDir/LParent/MkdirAll/WriteFile` 前后双 `EnsureNoSymlinkInPath` + `IsSymlink` 后验
- **S67 原子落盘**：`ZipExtractToDirAtomic*` 同文件系统 `TempDir+Rename` 原子提交，`Exists` 拒绝覆盖，`RemoveAll` 清理
- **S68 文档一致性**：`CONTRACT 1.38→1.39`/`README`/`SECURITY` 四文档同步原子与双校验，门面透出 `Atomic*` 三 API
- **S69 原子硬化**：`Rename EXDEV` 回退 `CopyTree+RemoveAll`，`test_zip_fs` 10 门
- **S70 性能收敛**：`LDirs` 几何预留 `O(n²)→O(n)`，`LDirsCount` 分离容量与计数
- **S71 示例完整性**：`README` Cookbook 第7式原子，`zip_roundtrip` 增 `ok/refuse/bomb clean` 三演示
- **S72 复用收敛**：`CalcGrowCapacity` 单源，双 `Ensure*Capacity` 薄委托
- **S73 稳定性纵深**：原子落盘后 `IsSymlink+EnsureNoSymlinkInPath` 二次校验
- **S74 完整性**：`test_zip_fs` 10→12 门，`Atomic permission/symlink` 透传验证
- **S75 复用收敛**：`ParentDirOf` 单源，双路径复用，`LSep` 清零
- **S76 版本封版**：`VERSION 1.0.0→1.0.1`，`ROADMAP` 当前状态同步 `1.0.1`

## 1.0.0 (2026-08-29) — nextpas.core.zip 1.0.0 领头羊 Final

基于 `1.0.0-rc.1` 零代码变更封版，`12门+bench 16项+hygiene` 全绿，`ci-matrix`（`linux-x86_64`/`win64` 交叉编译通过，`darwin` 源码级可移植）与 `SECURITY` 五模型就绪，`VERSION` 冻结为 `1.0.0`。

## 1.0.0-rc.1 (2026-08-29) — nextpas.core.zip 领头羊封版 RC

Pascal AI 时代 ZIP 容器领头羊实现，以 `nextpas.core.bench` 为唯一口径，12门+bench+hygiene 全绿，`ci-matrix` 四靶标通过。

### Highlights (S43—S50)
- **S43 PByte 零拷贝**：`IZipReader.ExtractToBuffer*` 与 `DecompressEntryToBuffer` 共享内核，store `Move` 直写、deflate `RawDeflateDecompressToBuffer` 泵送，无 `TBytes` 物化，`1MiB ≤8 allocs`，`bench 16项`
- **S44 AES 描述符对偶**：顺序读 `AES+descriptor` 打通，`CollectDescriptorPayload` 先集密文再 `Unseal` 校验，`MaxOutput` 对明文预筛
- **S45 阈值可配**：`TZipReadOptions.MaxDescriptorBuffer` 默认 512MiB 可配，与 `MaxOutput/MaxTotal` 正交
- **S46 中央零分配**：`IByteCursor.ReadSpan` + `DecodeCentralExtraBuf` 直通，`open/parse-CD 4004→2004 allocs`
- **S47 100+ fuzz与no-sig**：`test_zip_fuzz 450组` 与 `Go 7门` 含 `12/16/20/24` 四形态与 unicode 双锚点一致
- **S48 Cookbook定版**：`README` 6式与 `Migration` 表，`zip_roundtrip` 增 `PByte/AES-desc` 两小节 `all demos ok`
- **S49 方差治理**：`TBenchSuite 300ms/7/25` 使 `aes-*` CV `<5%`，回归无 `WARN`
- **S50 安全审计**：`SECURITY.md` 五项威胁模型（`zip-slip/bomb/CPU bomb/AES oracle/symlink traversal`），`INV-18/19` 入约，`VERSION` 冻结

### Security
- 见 `core/docs/zip/SECURITY.md` 五项 fail-closed 模型与 `CONTRACT INV-16/17/18/19`

### Testing
- 12门 `nextpas.core.zip.*` 全绿 `[HEAPTRC] OK`（27/27/22/7/5/6/9/3/13/7/5/4），`bench regression allocs+2/bytes` 硬门，`zip_roundtrip all demos ok`，`make hygiene/diff --check` 通过，`ci-matrix` 四靶标复跑通过

## 0.9.0 (2026-06-01) — Migration Complete

Full migration from fafafa.tui to nextpas.core.tui.

### Architecture
- Immediate-mode rendering with double-buffered diff (ratatui model)
- 77 source units, layered: base → buffer → layout → widgets → terminal → app
- All 40 widgets implement IWidget interface (class + COM reference counting)
- Platform integration via nextpas.core.platform (console/signal/time/io)

### Widgets (40 total)
- Core: Block, Paragraph, List, Table, Gauge, Tabs, Scrollbar, Clear, Input, Sparkline, BarChart, Canvas
- Extended: Tree, Dialog, Menu, Panel, SplitPane, Modal, Popover, Tooltip, Select, ScrollView, Calendar, Breadcrumb, StatusBar, Timeline, ProgressGroup, LineChart, InputEditor, DiffView, FileTree, Kanban, Markdown, VirtualList, CommandPalette, NotificationCenter, ToastManager, Checkbox, RadioGroup

### Performance Optimizations
- AVX2+SSE2 SIMD for StringDisplayWidth (3.4-5x faster on ASCII)
- Dirty-row bitmap in TBuffer (skips ~80% of CompareByte in real apps)
- Zero-allocation hot path (packed records, array-based cells)

### Unicode
- UAX#11 East Asian Width (63 ranges, 45 zero-width ranges)
- UAX#29 Grapheme Cluster segmentation (Extend, ZWJ, Regional Indicator, SpacingMark)
- Full UTF-8 decode/encode with SIMD validation

### Input
- CSI sequences (arrows, function keys, modifiers)
- Kitty keyboard protocol (CSI u)
- SGR mouse protocol (1006h) with motion tracking (1003h)
- Bracketed paste (CSI 200~/201~)

### Testing
- 32 TUI test projects, 240 TUI test cases, 0 memory leaks in heaptrc-covered runs
- 4K terminal stress tests (300x80, 10000-item lists)
- Input parser fuzz harness with 12-file corpus
- 4 benchmarks (diff, render, input, layout)
- TUI benchmark smoke entrypoint for CI compile/run coverage
- StringDisplayWidth 中文实战用例组（tui888 设计器验证集反哺：混合问候/全角/谚文/标点/数字串）

### Documentation
- ARCHITECTURE.md, WIDGET_CATALOG.md, BENCHMARK.md
- Goal tree with full phase tracking
