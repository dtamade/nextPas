# Changelog

## 1.0.0 (2026-08-29) — nextpas.core.zip 1.0.0 领头羊 Final

基于 `1.0.0-rc.1` 零代码变更封版，`12门+bench 16项+hygiene` 全绿，`ci-matrix`（`linux-x86_64`/`win64` 交叉编译通过，`darwin` 源码级可移植）与 `SECURITY` 四模型就绪，`VERSION` 冻结为 `1.0.0`。

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
- **S50 安全审计**：`SECURITY.md` 四项威胁模型（`zip-slip/bomb/CPU bomb/AES oracle`），`INV-18/19` 入约，`VERSION` 冻结

### Security
- 见 `core/docs/zip/SECURITY.md` 四项 fail-closed 模型与 `CONTRACT INV-16/17/18/19`

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
