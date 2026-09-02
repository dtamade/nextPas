# nextpas.core 能力地图 × 编译器消费绑定矩阵

状态：compiler-flat-namespace.md v2 支柱二的支撑文档（Needs Review）
日期：2026-08-23
目标：把 core 家底盘透，让编译器在 **FPC 创世构建**与**未来 np 自举**
两个时代消费同一套代码——core 的每次优化迭代自动传导给两代构建，
无需任何二次移植。

## 1. 一套代码吃两代福利的机制（为什么绑 core 就是绑未来）

- `nextpas.core.*` 是唯一实现层；FPC 编译时 uses 落到真实搜索路径，
  np 自举时落到自家 rtl——**同名同语义，零 `{$IFDEF}` 分叉**（CLAUDE.md 冻结）；
- 编译器只依赖 core 的类型与契约，不复制实现。于是：
  - FPC 创世期：core 的 swiss 哈希/arena/vec 直接服务编译器自身构建速度；
  - np 自举期：同一批 core 单元由 np 编译，core 的代码生成优化
    （MIR pass、寄存器分配等）反过来加速编译器的自举构建——
    **core 越快，自举越快，飞轮成立**；
- 因此本矩阵的所有绑定都以「精确到单元与 API」为准，禁止绕过 core 手搓。

## 2. core 相关家族规模（2026-08-23 实测）

| 家族 | 单元数 | 对编译器的相关性 |
|------|--------|------------------|
| collections | 83 | ★★★ 主战场 |
| mem | 77 | ★★★ 主战场 |
| text | 34 | ★★ 高频 |
| sync / async / thread | 18 / 17 / 9 | ★★ 并行 sema 底座 |
| base / bytes / exception / errors / path / os / system / compiler | ~20 | ★★ 地基 |
| time / math / id / hash | 16 / 20 / 10 / 10 | ★ 辅助 |
| tls/http/tui/net/crypto/... 其余家族 | ~1400 | ✗ 禁止进入编译器依赖图 |

## 3. 绑定矩阵（编译器阶段 → 需求 → 精确 core 消费）

### 3.1 syntax（词法/语法）

| 需求 | core 单元 | 关键 API |
|------|-----------|----------|
| token 流容器 | collections.smallvec | TSmallVec（小容量栈上内联，溢出才堆） |
| 字符类判定表 | collections.bitset | TBitSet（标识符首字符集等） |
| 源码扫描基元 | text.scan | 扫描器原语 |
| 标识符驻留(interning) | collections.hashmap.swiss.str | Put/TryGetValue（名→id 唯一化，消重复字符串比较） |

### 3.2 sema（语义）

| 需求 | core 单元 | 关键 API |
|------|-----------|----------|
| 符号/类型/body 名索引 | collections.hashmap（现状已接，保留） | specialize THashMap<string,LongInt> |
| 整型 id→payload 热表 | **collections.hashmap.swiss.i32i32** | PutNew/TryGetValue（全 inline，替换热点泛型版） |
| 重载候选多值映射 | collections.multimap | 一名多候选 |
| 作用域标志集合 | collections.bitset | 可见性/修饰符位 |
| unit 作用域内存 | **compiler.mem.TCompilerUnitScope** | BeginScope/AllocZeroed/EndScope/PeakUsed——AST/符号/HIR 节点全部走它，unit 编完整体回收 |
| 查找键消除 LowerCase 分配 | （待 P0 定方案）冗余小写键字段或 fold 缓存 | — |

### 3.3 ir（HIR/MIR/emitter）

| 需求 | core 单元 | 关键 API |
|------|-----------|----------|
| 节点/指令容器 | collections.vec / smallvec | 按冷热分流 |
| pass 工作表 | collections.deque / vecdeque | worklist 算法标准件 |
| 活跃性/def-use 位集 | collections.bitset | — |
| IR 文本拼接 | text.builder | 替代手拼（emitter/printer，待 P0 数据） |
| 大对象 churn | mem.arena.virtual（经 compiler.mem） | mmap 增长、Reset 回收 |

### 3.4 frontend（会话/unit 图/调度）

| 需求 | core 单元 | 关键 API |
|------|-----------|----------|
| unit 依赖图邻接 | collections.hashmap / multimap | 名→边集 |
| symbol/query 缓存 | collections.lrucache | 容量受控热缓存 |
| 文件变更检测去重 | collections.hashset | — |
| 并行调度协调 | sync.waitgroup / mutex / async.taskgroup | P3 并行 sema 底座（不自旋自造） |
| 会话级长寿命内存 | compiler.mem.TCompilerSessionScope | 进程态分配器 |

### 3.5 诊断与工具链

| 需求 | core 单元 |
|------|-----------|
| 格式化输出 | text.format / text.builder |
| 计时统计 | time.stopwatch |
| 错误分类 | errors / exception |

## 4. 已核实的 API 面（读源确认，非推测）

- `THashMap<K,V>`（hashmap.intf）：TryGetValue/ContainsKey/Add/AddOrAssign/
  Put/Get/GetOrInsert/GetOrInsertWith/ModifyOrInsert/Retain/Reserve 全齐；
- `hashmap.swiss.i32i32`：AllocTable/TryGetValue/ContainsKey/Put/PutNew/
  Get/Remove/Clear，方法级 `inline`——适合符号 id 这类 Int32 键热路径；
- `compiler.mem`：`IArena/IAllocator/TVirtualArena/TGrowingAllocator` re-export
  + `TCompilerUnitScope`（BeginScope/EndScope/Reset/Alloc/AllocNoPointer/
  AllocZeroed/TryAlloc/TotalUsed/PeakUsed/FormatStats）
  + `TCompilerSessionScope`——注释原文即「stage0/compiler modules wire」。

## 5. 禁区

1. tls/http/tui/net/crypto/ui 等家族禁止出现在编译器 uses 图中
   （依赖面最小化，门禁脚本断言）；
2. 禁止绕过 R1–R6 手搓数据结构新实例（存量 417 处 SetLength 按 P 批消化，
   不新增）;
3. 禁止为编译器在 core 里加 `{$IFDEF}` 或编译器专属分支——缺口修 core 本体
   （R6），改动走 core lane 测试后编译器再消费；
4. 层位规则：compiler Ln 只依赖 core ≤Ln（见主方案 §支柱三）。

## 6. 与批次计划的衔接

- N1–N6（改名迁移）：不改任何数据结构，纯机械；
- P0 测量：产出各阶段耗时 + 热点清单，校准本矩阵各行的实施顺序；
- P1：swiss 接线（§3.2 两行）+ LowerCase 分配消除；
- P2：compiler.mem UnitScope/SessionScope 全面接线（§3.2/3.3/3.4 内存行）；
- P3：sync/async 底座接线（§3.4 调度行）。
