# 项目规范合规审计报告

日期: 2026-05-31

## 审计结论

| 检查项 | 状态 | 详情 |
|--------|------|------|
| 单元命名 (§1) | ✅ 合规 | 全小写 dotted namespace |
| platform 硬规则 (§18) | ✅ 合规 | 0 违规，不依赖 FPC 平台单元 |
| 分层依赖 (§3) | ✅ 合规 | L0 不引用 L1+ 模块 |
| SysUtils 依赖 | ⚠️ 已知 | 138 files（自举阶段临时，规范已标注） |
| Classes 依赖 | ❌ 23 files | 应逐步消除 |
| src/ 构建产物 | ✅ 已清理 | 176 个 .o/.ppu 已删除 |
| 测试 Makefile | ❌ 8 缺失 | 部分测试无法 `make test` |
| 单元体积 >800行 | ⚠️ 10+ 个 | 软性指引，内聚性强可例外 |
| 门面含逻辑 | ⚠️ json/toml | Stringify 逻辑在门面中（性能优化） |
| 模块 README | ❌ 11 缺失 | 仅 id/toml/hash 有文档 |

## Classes 依赖清单（23 files）

需要消除 `Classes` 单元依赖的文件：

### collections (13 files)
- nextpas.core.collections.base.pas
- nextpas.core.collections.bitset.pas
- nextpas.core.collections.forward_list.pas
- nextpas.core.collections.hashmap.pas
- nextpas.core.collections.intf.pas
- nextpas.core.collections.linkedhashmap.pas
- nextpas.core.collections.list.pas
- nextpas.core.collections.lrucache.pas
- nextpas.core.collections.node.pas
- nextpas.core.collections.pas
- nextpas.core.collections.treemap.pas
- nextpas.core.collections.vecdeque.pas
- nextpas.core.collections.vec.pas

### mem (6 files)
- nextpas.core.mem.blockpool.sharded.pas
- nextpas.core.mem.mapped_ring_buffer.pas
- nextpas.core.mem.mapped_ring_buffer.sharded.pas
- nextpas.core.mem.mapped_slab_pool.pas
- nextpas.core.mem.memory_map.pas
- nextpas.core.mem.pool.slab.sharded.pas
- nextpas.core.mem.stack_pool.pas

### 其他 (3 files)
- nextpas.core.simd.cpuinfo.arm.pas
- nextpas.core.simd.cpuinfo.diagnostic.pas
- nextpas.core.thread.pool.pas

## 缺失 Makefile 的测试目录

- tests/nextpas.core.args/test_args/
- tests/nextpas.core.atomic/test_atomic/
- tests/nextpas.core.base/test_base/
- tests/nextpas.core.bytes/test_bytes/
- tests/nextpas.core.collections/test_base/
- tests/nextpas.core.collections/test_bitset/
- tests/nextpas.core.collections/test_btreemap/
- tests/nextpas.core.collections/test_btreeset/

## 缺失 README 的模块

collections, text, encoding, bytes, sync, thread, io, time, compress, fs, yaml

## 修复优先级

| 优先级 | 任务 | 工作量 |
|--------|------|--------|
| P0 | 清理 src/*.o/*.ppu | ✅ 已完成 |
| P1 | 补充 8 个 Makefile | 小（模板化） |
| P2 | 消除 Classes 依赖 | 中（需分析每个 uses 的实际用途） |
| P3 | 补充 11 个 README | 中 |
| P4 | 逐步替换 SysUtils | 大（长期） |

## 门面含逻辑说明

json.pas 和 toml.pas 的门面包含 Stringify 逻辑（而非纯 re-export），这是性能优化的设计决策：
- StringifyNode 需要访问 TJsonDocument 的内部结构
- 将其放在门面中避免了额外的单元间调用开销
- 这是规范 §2 "门面职责" 的合理例外
