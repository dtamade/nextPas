# C8-prep 自举差距清单

> 2026-06-26 全面探测结果（第二轮）
> 目标：用 nextPas 编译 `core/` 真实模块，记录所有差距

---

## 探测方法

```bash
# 工具：build/probe_self_compile_module.sh
# 编译器：build/stage0-bootstrap/nextpas（rebuild-compiler 产出）
# 目标：linux-x86_64
```

---

## 总结

| 类别 | 数量 | 说明 |
|------|------|------|
| ✅ 语法通过 | ~45 | parser + sema + codegen 全绿 |
| 🔴 Parser 语法错误 | ~14 | 需要 parser 增强 |
| 🟡 语义错误 | ~15 | 缺少 builtins/overload 解析 |
| ⚪ 缺少源文件 | ~8 | 文件名不存在（非编译器问题） |

---

## 已修复 Gaps（本轮）

### Gap #1：unit cycle ✅
- SysUtils stub 改为自定义 Exception，打破 cycle

### Gap #2：parser string keyword ✅
- `ParsePrimaryExpression` 添加 `tkStringKeyword`

### Gap #3：FPC Str() 格式说明符 ✅
- 格式说明符解析支持变量标识符（`tkIdentifier`）

### Gap #4：class body 'of object' ✅
- 类体解析器嵌套计数器 `I` 在 `procedure(...) of object` 处误增
- 修复：检查前一个 token 不是 `of` 才递增

---

## 🔴 Parser 语法错误（需增强）

### Gap P1：表达式链式调用
**症状：** `"statement" expected but "." found`
**位置：** `collections.arr` — `(Self as TCollection).TryLoadFrom(...)`
**根因：** 表达式解析器不支持括号表达式后的 `.` 方法调用

### Gap P2：函数指针调用
**症状：** `"statement" expected but "(" found`
**位置：** `collections.base`, `toml.parser` — `TEqualsFunc(aEquals^)(aLeft, aRight)`
**根因：** 类型转换后的函数调用 `TFunc(ptr)(args)` 不被识别

### Gap P3：statement expected but ";" found
**症状：** `"statement" expected but ";" found`
**位置：** `collections.hashmap`, `collections.skiplist`

### Gap P4：END expected but BEGIN found
**症状：** `"END" expected but "BEGIN" found`
**位置：** `collections.circularbuffer`, `collections.element_manager`, `collections.hashset`, `collections.list`, `collections.tree_set`
**可能根因：** `begin...end` 嵌套在类型声明或类体中的处理

### Gap P5：IMPLEMENTATION expected but END found
**症状：** `"IMPLEMENTATION" expected but "END" found`
**位置：** `bench.parallel`, `collections.smallvec`

### Gap P6：identifier expected but "." found
**症状：** `"identifier" expected but "." found`
**位置：** `fs.dir` — uses 子句或限定名

### Gap P7：非法字符
**症状：** `illegal character "�" (byte $A8) in source`
**位置：** `collections.vec` — 源文件含非 ASCII 字符

### Gap P8：statement expected but END found
**症状：** `"statement" expected but "END" found`
**位置：** `bench.runner`

---

## 🟡 语义错误（需 builtins/解析增强）

### Gap S1：unknown callable
- `SetString` — `config.env`
- `SiftDown` — `bench.base`（可能是泛型实例化问题）
- `InterlockedCompareExchange` — `bench.memtrack`
- `SizeUInt` — `bytes.base`（当作 callable）

### Gap S2：ambiguous overload
- `atomic_thread_fence` — `atomic.types`
- `FormatDateTime` — `bench`
- `Create` — `collections.forward_list`, `collections`
- `Max` — `collections.btree`

### Gap S3：wrong number of arguments
- `MkdirAll` — `fs`
- `Send` — `http.client`
- `Shutdown` — `http.server`
- `Truncate` — `collections.vecdeque`

### Gap S4：argument type mismatch
- `TextOfChar` — `bench.report`
- `StringsSplit` — `bench.xlang`

### Gap S5：interface not implemented
- `TBitSet does not implement IBitSet.AppendTo` — `collections.bitset`

### Gap S6：MIR lowering
- `TBitSet does not implement IBitSet.AppendTo` — `collections.bitset`

---

## ✅ 已通过模块（部分列表）

### L0 层
nextpas.core.base, nextpas.core.errors, nextpas.core.exception,
nextpas.core.mem, nextpas.core.log.intf, nextpas.core.base.utils

### L1 层
nextpas.core.text.conv, nextpas.core.text.utils, nextpas.core.text.format,
nextpas.core.sync, nextpas.core.sync.semaphore, nextpas.core.sync.event,
nextpas.core.sync.once, nextpas.core.sync.spinlock,
nextpas.core.collections.intf, nextpas.core.collections.arr.base,
nextpas.core.collections.arr.intf, nextpas.core.collections.arr.sort,
nextpas.core.collections.hashmap.base, nextpas.core.collections.hashmap.swiss,
nextpas.core.collections.hashmap.swiss.i32, nextpas.core.collections.hashmap.swiss.str,
nextpas.core.collections.linkedhashmap.intf,
nextpas.core.async, nextpas.core.async.base, nextpas.core.async.loop,
nextpas.core.async.task, nextpas.core.async.timer,
nextpas.core.bytes.pas(?), nextpas.core.atomic.pas(?)

### L2 层
nextpas.core.path, nextpas.core.fs.intf, nextpas.core.fs.util,
nextpas.core.fs.glob, nextpas.core.fs.path, nextpas.core.fs.stream,
nextpas.core.net.base, nextpas.core.net.intf, nextpas.core.net,
nextpas.core.net.resolve, nextpas.core.net.server.base,
nextpas.core.tls.base, nextpas.core.tls.asn1, nextpas.core.tls.base64,
nextpas.core.json, nextpas.core.json.builder, nextpas.core.json.parser,
nextpas.core.json.reader, nextpas.core.json.marshal,
nextpas.core.yaml, nextpas.core.toml, nextpas.core.toml.base,
nextpas.core.toml.value, nextpas.core.toml.builder, nextpas.core.toml.writer,
nextpas.core.config, nextpas.core.config.builder, nextpas.core.config.flatten,
nextpas.core.config.export, nextpas.core.math

### L3 层
nextpas.core.process, nextpas.core.process.base,
nextpas.core.tui.base, nextpas.core.http.base, nextpas.core.websocket

---

## 优先级建议

1. **P1-P2（表达式链式调用）** — 影响多个核心模块，表达式能力系统性不足
2. **P4（嵌套 begin/end）** — 影响 5 个 collections 模块
3. **S2（overload 歧义）** — 影响 5 个模块，可能是 overload 解析规则不完整
4. **S1（unknown callable）** — 需要注册更多 FPC builtins
5. 其余为边角问题
