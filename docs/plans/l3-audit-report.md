# L3 模块审计报告

> 日期: 2026-06-18
> 范围: `core/src/` 下所有 L3 层模块
> 工作线: L3 (codex/l3-modules)

## 模块概览

| 模块 | 文件数 | 代码行 | FPC 依赖文件数 | 测试数 | system 依赖 |
|------|--------|--------|----------------|--------|-------------|
| log | 2 | 1,121 | 0 | 3 | 0 |
| config | 6 | 3,916 | 0 | 11 | 0 |
| http | 36 | 37,005 | 9 | 32 | 0 |
| websocket | 2 | 419 | 0 | 1 | 0 |
| tui | 81 | 22,310 | 12 | 58 | 0 |
| app | 不存在 | - | - | - | - |
| **合计** | **127** | **64,771** | **21** | **105** | **0** |

## FPC RTL 依赖详情

### 完全干净的模块

- **log** (2 文件, 1121 行): 仅依赖 `text.conv`, `errors`, `fs.util`, `platform.files`, `time.base`
- **config** (6 文件, 3916 行): 依赖 `text`, `json`, `yaml`, `toml`, `ini`, `os.env`, `platform`, `sync`, `fs`, `hash`
- **websocket** (2 文件, 419 行): 仅依赖 `base`, `hash`, `encoding.base64`, `platform.random`

### http 模块 (9 文件依赖 FPC RTL)

所有引用均在 **implementation uses** 中，不传播到 interface：

| FPC 单元 | 文件数 | 涉及文件 |
|----------|--------|---------|
| SysUtils | 8 | headers, h1.parser, h2.client, h2.hpack, h2.session, h2.stream, h2.tls, impl.tls.stream |
| Classes | 1 | impl.tls.stream |

### tui 模块 (12 文件依赖 FPC RTL)

| FPC 单元 | 文件数 | 涉及文件 | 注意 |
|----------|--------|---------|------|
| SysUtils | 9 | image_cap(⚠️interface), image_mgr, keybind, sixel, widget.calendar, widget.command_palette, widget.markdown, widget.progress_group, widget.timeline |
| Classes | 1 | tui.task (TThread) |
| DateUtils | 1 | widget.calendar |
| BaseUnix+Unix | 1 | clipboard |

**关键风险**: `tui.image_cap.pas` 在 **interface uses** 中引入 SysUtils，会向上传播依赖。

## 迁移优先级

1. **websocket** (最易): 2 文件, 419 行, 零 FPC 依赖, 可立即就绪
2. **log** (极易): 2 文件, 1121 行, 仅 Math 依赖
3. **config** (容易): 6 文件, 3916 行, 零 FPC 依赖
4. **tui** (中等): 12 文件有依赖, 大多在 implementation, 先修 image_cap.pas interface 传播
5. **http** (最难): 9 文件, 深度依赖 net/io/tls, 最后处理

## 代码质量观察

1. FPC RTL 依赖封装良好，绝大多数在 implementation uses
2. websocket/log/config 完全无 FPC 依赖
3. app 模块不存在（tui.app 是 tui 子模块）
4. 测试覆盖充分（105 个测试文件）
