# Task Plan: INI 修复与 XML/INI/CSV Benchmark

## Goal
完成 `nextpas.core.ini` 的重复 key 语义修复和字符串构建优化，并新增 XML/INI/CSV benchmark 对照，确保指定测试与 benchmark 全部可编译运行。

## Current Phase
Phase 4: Verification + Closeout complete

## Design

- INI 行解析保持现有公开 API 和大小写不敏感语义：`ParseLine` 遇到同 section 的重复 key 时更新已有 entry 的 value，而不是追加新 entry。
- `ToString` 改为两趟构建：先预估总长度，再 `SetLength` 分配目标字符串，最后用 `Move` 写入片段，避免 O(n²) 拼接。
- `LoadFromFile` 也避免循环拼接：使用 growable buffer 收集文件内容，读完整内容后交给 `LoadFromString`。
- Benchmark 采用现有仓库单文件 `.lpr` 风格，计时使用 `nextpas.core.platform.time.platform_monotonic_ns`，输出列为 `操作名 / 迭代次数 / 总耗时 / ns/op`。
- XML benchmark 覆盖 tokenizer-only 与 DOM parse+query；INI benchmark 覆盖 1KB/10KB parse 与 ReadString 查找；CSV benchmark 覆盖 10KB/100KB parse。

## Phases

### Phase 1: Context + RED
- [x] 检查 worktree 状态和现有规划文件
- [x] 梳理 INI 实现、INI 测试、XML/CSV facade 与 benchmark 风格
- [x] 添加 INI 重复 key 红测并确认失败
- **Status:** complete

### Phase 2: INI Fix
- [x] 修复 `src/nextpas.core.ini.pas` 重复 key 更新语义
- [x] 优化 `LoadFromFile` 和 `ToString` 字符串构建
- [x] 运行指定 INI 测试并确认通过
- **Status:** complete

### Phase 3: Benchmarks
- [x] 新增 `benchmarks/nextpas.core.xml/bench_xml/bench_xml.lpr`
- [x] 新增 `benchmarks/nextpas.core.xml/bench_xml/compare_go/main.go`
- [x] 新增 `benchmarks/nextpas.core.ini/bench_ini/bench_ini.lpr`
- [x] 新增 `benchmarks/nextpas.core.csv/bench_csv/bench_csv.lpr`
- **Status:** complete

### Phase 4: Verification + Closeout
- [x] 编译运行指定 INI 测试
- [x] 编译运行 XML/INI/CSV benchmark
- [x] Go 可用时运行 XML Go 对照
- [x] 检查 git status，清理本轮意外产物，提交本轮逻辑改动
- **Status:** complete

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|

## Verification Notes
- RED: 指定 INI 测试命令新增重复 key 用例后失败，断言为 `expected "second", got "first"`。
- GREEN: INI 修复后同一命令通过 `25 total, 25 passed, 0 failed`。
- First benchmark smoke: XML/INI/CSV Pascal benchmark 均已编译并输出结果；Go 可用且 `go run main.go` 已输出 encoding/xml 对照。
- Final requested command sequence exit 0，XML/INI/CSV benchmark 与 Go encoding/xml 对照均输出 `ns/op`。
- Heaptrc focused INI check: `25 total, 25 passed, 0 failed` and `0 unfreed memory blocks`.
