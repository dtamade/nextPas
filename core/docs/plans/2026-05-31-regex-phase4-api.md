# nextpas.core.regex Phase 4 — API 完善与正确性

> **Goal:** 将 regex 模块 API 提升到 Go regexp / Rust regex 同等水平，确保接口设计合理、测试覆盖 100%、零泄漏。

## Codex 审查结论（session 019e7aba）

| 建议 | 决策 |
|------|------|
| FindAt(AInput, AStartPos) | ✅ 添加 |
| IsFullMatch(AInput) | ✅ 添加 |
| RegexQuoteMeta(s) | ✅ 模块级函数 |
| Split 支持 limit | ✅ `Split(AInput, AMaxSplits: SizeInt = -1)` |
| ReplaceAllFunc/ReplaceFirstFunc | ✅ 签名: `function(const AInput: string; const AMatch: TMatch): string` |
| 替换模板 $1/${name} | ✅ 新增 `ReplaceAllExpand` 支持 `$0 $1 ${name}` |
| TMatch 设计 | 保持 offset-based，不存值 |
| SubMatch | 不加，改为统一 Group(0)=full match 语义 |

## 任务分解

### T1: API 扩展（facade + NFA 对接）
- [ ] `FindAt(const AInput: string; AStartPos: SizeUInt): TMatch`
- [ ] `IsFullMatch(const AInput: string): Boolean`
- [ ] `RegexQuoteMeta(const AStr: string): string`（模块级）
- [ ] `Split(const AInput: string; AMaxSplits: SizeInt = -1): TStringArray`
- [ ] `FindAll(const AInput: string; AMaxMatches: SizeInt = -1): TMatchArray`

### T2: 回调替换
- [ ] `TReplaceFunc = function(const AInput: string; const AMatch: TMatch): string`
- [ ] `ReplaceFirstFunc(const AInput: string; AFunc: TReplaceFunc): string`
- [ ] `ReplaceAllFunc(const AInput: string; AFunc: TReplaceFunc): string`

### T3: 模板替换（$1, ${name}）
- [ ] `ReplaceAllExpand(const AInput, ATemplate: string): string`
- [ ] 支持 `$0`（全匹配）、`$1`..`$9`（按索引）、`${name}`（按名字）、`$$`（转义$）

### T4: 缺失语法支持
- [ ] `\D`（非数字）、`\W`（非单词）、`\S`（非空白）
- [ ] `\B`（非单词边界）— 已有，验证测试
- [ ] `(?i)` 内联 flag（case-insensitive）— 延后到 Phase 5

### T5: 测试覆盖（目标 40+ tests）
- [ ] FindAt 测试（起始位置、边界）
- [ ] IsFullMatch 测试（完全匹配 vs 部分匹配）
- [ ] QuoteMeta 测试（所有元字符）
- [ ] Split limit 测试
- [ ] ReplaceFunc 测试
- [ ] ReplaceAllExpand 测试（$0/$1/${name}/$$）
- [ ] \D \W \S 测试
- [ ] 边界条件：空模式、空输入、超长输入

### T6: heaptrc 验证 + 提交
- [ ] 全部测试通过
- [ ] 零内存泄漏
- [ ] git commit

## 执行顺序

T4（语法补全）→ T1（API 扩展）→ T2（回调替换）→ T3（模板替换）→ T5（测试）→ T6（验证提交）

## 质量门禁

- 所有新增 API 必须有对应测试
- heaptrc 0 unfreed blocks
- 不引入性能回退（benchmark 最后一轮验证）
