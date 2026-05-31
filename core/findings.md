# Findings: INI 修复与 XML/INI/CSV Benchmark

## 2026-06-01 Context

- 当前 worktree: `/home/dtamade/projects/nextPas/.worktrees/rtl-phase3/core`，branch `feat/rtl-phase3`。
- 初始状态已有未跟踪文件 `src/nextpas.core.template.pas` 与 `src/nextpas.core.validation.pas`，本轮视为既有/用户改动，不纳入清理或提交。
- `TIniFile.ParseLine` 当前解析 key/value 后直接追加 entry；`TIniFile.WriteString` 已有覆盖语义，可复用 `FindKey` 的一致行为。
- `TIniFile.LoadFromFile` 当前 `LContent := LContent + LLine + #10` 循环拼接；`TIniFile.ToString` 当前同样用 `Result := Result + ...` 逐片段拼接。
- XML facade 提供 `XmlTokenize` 和 `XmlParse`; DOM 类型为 `TXmlDocument`/`TXmlNode`。
- CSV facade 提供 `TCsvReader.Create(...).ReadAll`。
- 既有 benchmark 风格多为单 `.lpr`，但本轮用户要求统一输出 `操作名 迭代次数 总耗时 ns/op`，且计时必须使用 `platform_monotonic_ns`。

## 2026-06-01 Implementation Findings

- INI 重复 key 的红测失败在 `ReadString('app', 'name', '')` 返回旧值 `first`；根因是 `ParseLine` 解析 key 时绕过了 `WriteString` 已具备的覆盖语义。
- `LoadFromFile` 在 `TextFile`/`ReadLn` 约束下无法可靠预知全部行分隔符细节，本轮采用 growable string buffer，保留原行为：每个 `ReadLn` 后追加 `#10` 再交给 `LoadFromString`。
- `ToString` 可以完全预估输出长度，因为 section、entry、分隔符和换行都是已知固定片段；本轮改为两趟写入。
- INI `ReadString` benchmark 用 500 key 的末尾 key 查询，验证的是当前线性查找的 worst-ish path；100000 次足够稳定且不会让日常完整 benchmark 过慢。
