# C8-prep 自举差距清单

> 2026-06-26 首次探测结果
> 目标：用 nextPas 编译 `core/` 真实模块，记录所有差距

---

## 探测方法

```bash
# 工具：build/probe_self_compile_module.sh
# 编译器：build/stage0-bootstrap/nextpas（rebuild-compiler 产出）
# 目标：linux-x86_64
```

---

## Gap #1：unit cycle（阻塞所有 core 模块）

**症状：**
```
unit cycle detected: nextpas.core.exception -> sysutils -> nextpas.core.exception
```

**根因：**
- `nextpas.core.exception.pas` 第 14 行 `uses SysUtils`，继承 `SysUtils.Exception`
- `units/linux-x86_64/SysUtils.pas` 第 6 行 `uses nextpas.core.exception`，re-export Exception 类型
- 当 nextPas 编译时，两个 stub 互相引用形成 cycle

**历史：**
- Phase A（cfe9e1061）：Exception 改为 `class(TObject)`，自给自足
- Phase A 回退（7b0787506）：FPC 的 `raise` 要求 `SysUtils.Exception` 后代
- Phase C（bcd9a2f4e）：SysUtils stub re-export Exception → 引入 cycle

**影响范围：**
- `nextpas.core.base` → `nextpas.core.exception` → SysUtils → cycle
- 所有 core 模块最终都依赖 `nextpas.core.base`，因此全部受影响
- compiler-pass 测试中 6/16 失败（unit-resolution-failed）

**修复选项：**

| 选项 | 方案 | 代价 |
|------|------|------|
| A | Phase A 重做：Exception 不继承 SysUtils.Exception | FPC 编译的代码 `raise` 失败 |
| B | SysUtils stub 不导入 nextpas.core.exception | Exception 类型分裂（两个独立层次） |
| C | SysUtils stub 内联定义 Exception（不引用 core） | 类型分裂 + 维护双份定义 |
| D | nextpas.core.exception 消除 SysUtils 依赖 + FPC 侧用 wrapper | 最干净但工作量大 |

**推荐：选项 D**
1. nextpas.core.exception 重新自给自足（Phase A 方案）
2. FPC 编译路径：`{$IFDEF FPC}` 在 exception.pas 顶层加 `uses SysUtils`？
   — 但 CLAUDE.md 禁止 `{$IFDEF}` 分叉
3. **替代方案**：FPC 编译路径不经过 stub，直接用 FPC 的 SysUtils。
   问题：FPC 的搜索路径和 nextPas 的搜索路径不同。
   FPC 编译时 `uses SysUtils` → FPC 自带 SysUtils（无 cycle）
   nextPas 编译时 `uses SysUtils` → stub SysUtils（有 cycle）
   所以只需要在 stub 路径上打破 cycle。

**实际推荐：选项 B+C 混合**
- SysUtils stub 定义自己的 Exception 类（不导入 nextpas.core.exception）
- nextpas.core.exception 保持 `uses SysUtils`（FPC 兼容）
- 类型分裂是已知限制，可在 C8 阶段处理

---

## Gap #2：parser syntax error（text.conv）

**症状：**
```
Syntax error, "statement" expected but "," found
```

**位置：** `core/src/nextpas.core.text.conv.pas` byte offset 3579, 3938

**可能原因：** 默认参数值语法 `AAll: Boolean = False`（FPC 扩展语法）

**影响范围：** 未知，需进一步分析

**验证方法：**
```bash
# 找到语法错误位置对应的行
python3 -c "
with open('core/src/nextpas.core.text.conv.pas','rb') as f:
    f.seek(3579)
    ctx = f.read(200)
    print(ctx[:200])
"
```

---

## Gap #3：search path 配置

**症状：** core 模块编译时 `searchPathCount=0`

**原因：** `probe_self_compile_module.sh` 使用 `--workspace` 指定根目录，
但 search path 可能未正确配置 core/ 的源码路径。

**影响：** 即使打破 cycle，依赖解析也可能失败。

---

## 下一步

1. **最高优先级**：修复 Gap #1（unit cycle）
   - 修改 `units/linux-x86_64/SysUtils.pas`：移除 `uses nextpas.core.exception`
   - 在 SysUtils stub 中内联定义 Exception 类层次
   - 验证：nextPas 可编译 nextpas.core.base
2. **次高优先级**：修复 Gap #2（parser syntax）
   - 分析具体语法错误位置
   - 可能需要扩展 parser 支持默认参数值
3. **低优先级**：修复 Gap #3（search path）
   - 分析 workspace/package 配置
   - 确保 core/ 源码路径正确配置

---

## 状态

| Gap | 状态 | 优先级 |
|-----|------|--------|
| #1 unit cycle | 🔴 未修复 | 最高 |
| #2 parser syntax | 🔴 未分析 | 次高 |
| #3 search path | 🔴 未分析 | 低 |
