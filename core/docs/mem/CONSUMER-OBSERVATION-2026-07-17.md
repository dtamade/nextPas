# mem Consumer 只读观测（unsized free / 插件面）

**日期**: 2026-07-17 · **G7 重扫**: 2026-07-20
**范围**: `core/src/*.pas`，**排除** `nextpas.core.mem*`
**动作**: **只读 findings**；不改 consumer 生产代码（G4 样板除外，见 §6.2）
**非目标**: 全仓机械 `FreeMem` 替换（ROADMAP D3 / 明确不做）
**前序**: [CONSUMER-AUDIT-SUMMARY-2026-07-17.md](CONSUMER-AUDIT-SUMMARY-2026-07-17.md)（FIX CLOSED）

方法摘要：

- **过程式 unsized**: 正则 `(?<![\w.])FreeMem(arg)`（无第二 size 实参）；排除过程/函数声明行
- **过程式 sized**: `FreeMem(ptr, size)`
- **插件 free**: `FAllocator.FreeMem` / `AAllocator.FreeMem` 等（IAllocator **仅有**单参 free）
- **助手采用**: `FreeMemOf` / `TryBlockSize` / `ReallocMemOf`

---

## 1. 一句话

Consumer-audit **FIX 后**，关键路径（swiss / 部分 lockfree / text.builder）已用 `FreeMemOf` 或 sized free。
剩余问题主要是：**(a)** L0/System 故意旁路；**(b)** 过程式 `FreeMem(ptr)` 仍约 40+ 真实站点；**(c)** 插件面 `FAllocator.GetMem/FreeMem` 是 **设计内税**（SC9），不是误用 `IAllocator` 塞回门面。

---

## 2. 数量快照（本机）

| 模式 | 约计 | 解读 |
|------|------|------|
| 过程式 **sized** `FreeMem(p,n)` | **~72** | 健康方向；platform.io/pty、lockfree、mbedtls 等 |
| 过程式 **unsized** `FreeMem(p)` | **~40–45**（含注释命中噪声） | 见 §3 |
| `FreeMemOf` | **21**（5 文件） | swiss\* + text.builder；仍少 |
| `FAllocator.FreeMem` | **~56** | json/toml/yaml/collections 注入 free |
| `FAllocator.GetMem` | **~35** | 同上 alloc |

Scorecard 税（RELEASE 2026-07-17）：unsized ~**8.9×** sized；plugin IA ~**8.8×** hot heap。

---

## 3. 过程式 unsized `FreeMem(ptr)` — 分桶

### 3.1 WAIVED / 故意（不要改）

| 位置 | 理由 |
|------|------|
| `platform.fs` / `platform.io` / `platform.pty`（及注释） | **L0**：禁止 `uses mem`；System 堆旁路（CA-011 纪律） |
| `bench.run` / `test.runner`（部分） | 工具/测试 harness；非产品热路径 |

### 3.2 真实 L1+ 候选（owner 顺手时升级）— P2

已知 size 或可 `TryBlockSize` 时优先 `FreeMem(p,n)` / `FreeMemOf`：

| 模块 | 约站点 | 备注 |
|------|--------|------|
| `simd.avx2` / `simd.sse2` | 4+4 | **CLOSED 2026-07-19**：`FreeMem(buf, capacity*SizeOf(Single))` |
| `simd.alloc` / `image` / `imageproc` / `memutils` | 1 each | **CLOSED 2026-07-19**：raw size / row size / DataSize / TryBlockSize |
| `tls.winssl.certificate` / `winssl.utils` | — | **CLOSED E4**：utils + certificate 已 sized（alloc-size 快照） |
| `tls.openssl.api.*` / `certificate` / `wolfssl.context` | 若干 | C API 缓冲；**本批不做** |
| `tls.buffer.pool` | 2 | **CLOSED E4 2026-07-19**：`FreeMem(FData, FCapacity)` |
| `io.reactor.iocp` | 3 | **CLOSED E4 2026-07-19**：Accept 缓冲 `WSABuf.len` / `ADDR_BUF_SIZE` |
| `io.async.fileio` | 2+ | **CLOSED E4 2026-07-19**：写路径 `ASize` + 线程 finally 释放拷贝 |
| `tui.task` | 混合 | 已有 sized 形态；勿误伤 |

**纪律**: 谁改谁顺手（D3）；**禁止** mem lane 跨模块机械扫。

### 3.3 注释噪声

`platform.fs` 等文件头注释含 `GetMem/FreeMem` 字样，计数器可能 +1；以真实可执行语句为准。

---

## 4. 插件面 `IAllocator` — 不是「热路径用错」清单

### 4.1 正确 inject（保留）

下列默认 `DefaultAllocator` / 字段 `FAllocator` 是 **S5 插件轨**：

- collections：`vec` / `arr` / `hashmap` / `node` / `deque` / …
- 文本/结构化：`json.parser`、`toml.parser`、`yaml.*`、`xml.*`、`ini`、`csv`、`bytes.builder`、`text.builder`
- 产品桥：`http.mem` / `compiler.mem` 暴露 process 与 request/unit 面

这是 **双轨设计**：可注入、可 DEBUG wrap；付 SC9 税是预期。
**不要**为「接口统一」把过程式热路径改成 `DefaultAllocator.GetMem` 循环。

### 4.2 已对齐助手的样板

| 文件 | 模式 |
|------|------|
| `hashmap.swiss*.pas` | `DefaultAllocator` + **`FreeMemOf`**（consumer-audit 修复） |
| `text.builder.pas` | `FreeMemOf` |

其它 inject 模块 free 仍走 `FAllocator.FreeMem(ptr)`（IAllocator 五方法冻结下的唯一 free）。
**可选升级**（非阻塞）：在 **已知 size 且走默认堆** 时改 `FreeMemOf(alloc, ptr, size)`，使 DEBUG tracking 与 sized 路径一致；见门面 `FreeMemOf` 文档。

### 4.3 高频插件 free 文件（供 owner 参考）

| 文件 | `FAllocator.FreeMem` 约计 |
|------|---------------------------|
| `json.parser` | 15 |
| `toml.parser` | 13 |
| `collections.node` | 11 |
| `collections.hashmap` | 4 |
| `yaml.parser` | 3 |

这些是 **解析/容器** 路径；若 profiling 显示 alloc 占主导，优先 **Arena/一次性 Reset** 或 sized `FreeMemOf`，而不是换另一个实验 allocator。

---

## 5. 与 FIX CLOSED 审计的关系

| 项 | 状态 |
|----|------|
| CA-001 swiss 错误 API | **FIXED**（回归在 guardrails） |
| L1+ 接入 mem | **FIXED**（多数） |
| L0 不 uses mem | **保持** |
| 全仓 unsized 清零 | **明确不做** |
| 本观测 | **增量证据**，不 reopen P0 |

---

## 6. Findings 表（只读）

| ID | 严重度 | 主题 | 建议 owner | 动作 |
|----|--------|------|------------|------|
| CO-001 | — | L0 System FreeMem | platform | **保持** |
| CO-002 | P2 | simd 表/缓冲 unsized free | simd | **CLOSED 2026-07-19**（mem lane D3）：avx2/sse2 tan scratch、image FlipVertical、imageproc FreeImage、simd.alloc raw free、memutils AlignedFree TryBlockSize |
| CO-003 | P2 | tls 缓冲 unsized free | tls | **CLOSED E4-c 2026-07-19**（产品 GetMem 路径；见 §6.1 WAIVE） |
| CO-004 | P2 | iocp / async fileio unsized | io | **CLOSED E4 2026-07-19** |
| CO-005 | info | FreeMemOf 采用面 | collections / 文本 | **扩展中**：swiss + text/bytes.builder + **G4 json/toml** |
| CO-006 | P2 | async buffer/channel unsized | async | **CLOSED E4-b 2026-07-19** |
| CO-007 | info | json/toml/node 插件 free | 各模块 | json/toml **已知 size → FreeMemOf（G4）**；owned 字符串 / node 仍按触达 |
| CO-008 | — | DefaultAllocator 默认 inject | — | **正确**；勿改热循环为虚调用 |

### 6.1 残余矩阵（E4 关闭时，2026-07-19 重扫）

| 桶 | 处置 | 说明 |
|----|------|------|
| platform.* FreeMem | **WAIVE** | L0 禁止 uses mem |
| bench.run / test.runner | **WAIVE** | harness |
| simd.memutils AlignedFree | **FIXED F6** | header 存 totalSize；sized `FreeMem`；无 unsized 回落 |
| openssl 本模块 GetMem 串/DER/param 数组 | **FIXED E4-c** | 见 [OPENSSL-HEAP-DISCIPLINE.md](OPENSSL-HEAP-DISCIPLINE.md) |
| OpenSSL CRYPTO 对象 | **禁止 FreeMem** | 只用 `*_free` FFI |
| IAllocator.FreeMem | **设计内** | 五方法冻结；SC9 |

过程式产品主路径 unsized：**无开放 P0/P1**。

### 6.2 FreeMemOf 样板与残余 inject（G7 · 2026-07-20）

**已落地样板（禁止全仓扫，只作模式参考）**:

| 模块 | 路径 |
|------|------|
| text.builder | `FreeMemOf` / sized process free |
| bytes.builder | F4：`FreeMemOf` / `ReallocMemOf` |
| json.parser | G4：nodes / arena / indices / slots / overflow 表 |
| toml.parser | G4：nodes / hash / owned 指针表 |
| collections.node | **G4.x**：TNodeManager 块/registry/tree node |
| collections.hashmap | **G4.x+**：buckets/bitmap FreeMemOf |
| yaml / xml / ini / csv | **G4 residual**：表/slot 容量 FreeMemOf |
| toml LBuf | **G4 residual**：free 点旁有 LBufLen |
| collections swiss\* | 既有 FreeMemOf |

**`FAllocator.FreeMem` 残余（2026-07-20 residual 后）**:

| 模块 | 备注 |
|------|------|
| toml `FOwnedBufs[i]` | 无 per-buf size — **故意 unsized** |
| tui buffer/overlay inject | **WAIVE FreeMemOf**：须 `IAllocator.FreeMem` 以保留 tracking 可观测 |
| element_manager / treemap 等 | 按触达 |

**结论**: 无新 P0/P1。下一刀仅 **命名模块** + 已知 size；默认 Steady。

---

## 7. 给其它 lane 的 review 清单（D3）

触达堆路径时自问：

1. 是否 L0？→ 保持 System，勿 uses mem。
2. 是否请求/帧生命周期？→ Arena / RequestArena，勿逐块 FreeMem。
3. 是否已知 size？→ `FreeMem(p,n)` 或 `FreeMemOf`。
4. 是否需要 inject/DEBUG？→ `IAllocator` / `DefaultAllocator`；接受 SC9。
5. 是否热循环？→ 过程式 `GetMem`/`DefaultHeap`，**不要** `DefaultAllocator.GetMem`。

---

## 8. 结论

- **无新 P0**。E4-a/b/c 后产品过程式 free 主路径已 sized 或显式 WAIVE。
- 「热路径 IAllocator」在 consumer 侧主要是 **合法 inject**；勿把过程式热路径改回虚调用。
- 性能下一刀在 **consumer 触达时** 采用 sized free / Arena，不在 mem 再加分配器。
- OpenSSL 双堆纪律：[OPENSSL-HEAP-DISCIPLINE.md](OPENSSL-HEAP-DISCIPLINE.md)。

相关：[SCORECARD.md](SCORECARD.md) SC8/SC9 · [USABILITY-SCORE.md](USABILITY-SCORE.md) · [ROADMAP.md](ROADMAP.md) D3/D9 · [API-GUIDE.md](API-GUIDE.md)
