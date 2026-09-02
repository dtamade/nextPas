# Changelog — codex/agent-sse-restore

> 本分支承载 main 历史重组期间丢失/回退的 agent 修复与测试，目标合入时机：main 稳定后。

## 2026-08-31 — sse 边界测试恢复 + inline Move 缺陷修复 (2 commits)

### Commits

| Hash | Type | Summary |
|------|------|---------|
| `04f3253f3` | test | 恢复 sse 边界测试 — line limit exact boundary + event data limit（main 历史重组丢失，从 landing 线补回；main 的 sse.pas AnsiString 实现兼容，13/13 全绿） |
| `f36049401` | fix | FPC inline+Move 缺陷 — StringToBytes/GitStringToBytes 改 PAnsiChar 解引用（实证：-O2 下 inline 展开 `Move(AText[1],...)` 仅复制 1 字节；bytes 域 35+5+10 与 test_sse 13/13 无回归） |

### Gates

- `test_sse` 13/13 HEAPTRC OK（含恢复的 2 个边界测试）
- `test_bytes` 35 / `test_cursor` 5 / `test_stream` 10 全绿
- 实证探针：修复前 `StringToBytes('hello'#10)` = `68 00 00 00 00 00`（1 字节），修复后 = `68 65 6C 6C 6F 0A`（完整）

### 关联

- landing 线：`landing/agent-final-20260831`（49 单元 agent perfection，本地 + origin 备份）
- main 状态：2026-08-31 17:xx 处于历史重组震荡（reset 反复），landing 冻结等待稳定
