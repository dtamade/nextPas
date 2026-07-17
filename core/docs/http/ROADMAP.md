# nextpas.core.http Roadmap

**Authority**: 本文件是 HTTP 模块**向前开发**的唯一执行入口。
**Companion**: 北极星与阶段定义见 `GOAL_TREE.md`；契约真相见 `CONTRACT.md`。
**Updated**: 2026-07-17（Wave I Proxy auth Basic-only freeze）

---

## 怎么工作（以后按这个走）

1. **先看本文件「当前该做」**，不要从零 inventory、不要用户催才开工。
2. 每一波只做表里 **最多 3 项**；做完 path-limited land，再回写本文件状态。
3. 改范围必须先改本文件（讨论 → 更新表 → 再写代码）。
4. 历史 cycle assessment / research / fix-plan 只作档案，**不再当主路线图**。
5. 跨模块依赖（QUIC、OpenSSL residual）标 **Blocked**，不在 http lane 硬堆 workaround。

**波次节奏**（固定）：

```text
ROADMAP 下一波 → 短 plan（若有歧义）→ 实现 + focused gate → path-limited land → 更新本文件
```

---

## 现在在哪

| 层 | 状态 |
|----|------|
| **G0–G5 模块骨架** | 完成（见 GOAL_TREE Map） |
| **non-H3 stage-complete** | 完成（P1–P5 关闭；H3 诚实 blocked） |
| **可用性 Wave A–F** | 完成并 landed main（dial/cancel、JSON、CONNECT、direct HTTPS、proxy Basic、HTTP-date Retry-After、WithTLSContext、*JsonDocument） |
| **Wave G Cookie site** | 完成（eTLD+1 SiteKey + multi-label PSL 子集；拒绝 Domain=public-suffix） |
| **Wave H Response metadata** | 完成（`IHttpResponse.FinalUrl` + `Version`；H1/H2 写入；client 盖章） |
| **Wave I Proxy auth** | 完成（评估后冻结 **Basic only**；407 诚实错误；Digest/NTLM Park） |
| **下一执行点** | **Phase P** 的 **Wave J**（Error Op hygiene） |

日常客户端主路径、cookie、响应元数据与代理鉴权边界已齐。
剩下是 **加深**（Op hygiene）和 **协议演进**（H2 边角、H3 等 QUIC）。

---

## 已完成（压缩，不展开史）

| 标记 | 内容 |
|------|------|
| Stage | INV-12 keep-alive；H2 facade live；API 审计；bench 诚实；H3 无假 facade |
| Wave A–B | WS budget/cancel；live dial/cancel；CONTRACT 真相 |
| Wave C | GetJson ensure+decode；429 + delta Retry-After |
| Wave D | HTTPS CONNECT via HTTP proxy |
| Wave E | H1 direct HTTPS；ProxyUrl Basic |
| Wave F | HTTP-date Retry-After；WithTLSContext；Post/Put/PatchJsonDocument |
| Wave G | Cookie eTLD+1 SiteKey；multi-label PSL 子集；拒绝 Domain=public-suffix；`HttpCookieSiteKey` |

详细证据在 [`archive/`](archive/README.md) 与 `API_COVERAGE.md` 矩阵。

---

## 向前路线（唯一有序列表）

### Phase P — Product depth（http 可独立做）

目标：把「能用」补成「多租户 / 运维 / 企业代理」也诚实可用。

| Wave | 主题 | 做 | 不做 | 预估 | 状态 |
|------|------|----|------|------|------|
| **G** | Cookie site model | 引入 **public suffix**（或可维护的 PSL 子集）修正 SiteKey；SameSite 跨站判定对齐；回归 jar 测试 | 不改 jar 存储 API 形状；不磁盘持久化 | M | **landed** |
| **H** | Response metadata | `IHttpResponse.FinalUrl` + `Version`；H1/H2 写入；client 盖章；CONTRACT + 测试 | TLS 摘要、transport 句柄泄漏 | M | **landed** |
| **I** | Proxy auth variants | **评估后冻结 Basic only**；CONNECT 407 诚实消息；`HTTP_STATUS_PROXY_AUTH_REQUIRED`；CONTRACT + source-contract | Digest 实现；NTLM；SOCKS | S | **landed** |
| **J** | Error Op hygiene | 热点路径 `CreateOp` 补齐（client Send / redirect / retry / H1 RoundTrip 边界）；source-contract 锁定数 | 全模块 Op-everywhere | S–M | **NEXT** |

**Wave J 为默认下一波。** 改序必须改本表，不能静默跳波。

### Phase Q — Surface cleanup（低风险还债）

| Wave | 主题 | 做 | 状态 |
|------|------|----|------|
| **K** | Deprecated factory 清退 | 批量迁移/删除多参 `NewRequest` 等已 deprecated 工厂；测试与 examples 只走 builder | queued |
| **L** | Docs/archive hygiene | 压缩 API_COVERAGE 顶部历史；GOAL_TREE Recent Fixes 归档到 `archive/` 索引；避免双入口 | **done**（本轮） |

### Phase R — Protocol edges（依赖设计，可延后）

| Wave | 主题 | 依赖 | 状态 |
|------|------|------|------|
| **M** | H2 CONNECT / WebSocket-over-H2 | H2 session 扩展；当前设计排除 | parked until demand |
| **N** | H3 client/server | **独立 QUIC 模块** | **Blocked** |
| **O** | h2c Upgrade / server push | 明确产品需求才开；默认永不做 push | parked / non-goal push |

### Phase X — Explicit non-goals & residuals（不排期除非改本文件）

| 项 | 立场 |
|----|------|
| server `Default` RW=0 | **Keep**（测试兼容）；生产用 `THttpServerOptions.Production` |
| cancel ~50 ms 切片 | **Residual-honest**（非 OS 硬中断） |
| OpenSSL factory unfreed | **跨模块 residual**；http 不单独清零宣称 |
| JSON dual raw vs ensure-string | **Keep** 三层模型（raw / ensure string / ensure+decode） |
| Digest / NTLM / Negotiate proxy auth | **Park**（Wave I 评估：Basic 已覆盖常见正向代理；无 consumer 不实现 challenge 重试） |
| 完整企业代理栈 | **Park** 除非有真实 consumer |
| SOCKS proxy | **Park**（更偏 net 层） |
| 为对标而扩 API | **禁止**（见 GOAL_TREE Do-Not-Drift） |

---

## 当前该做（给执行者）

```text
1. 打开本文件确认 Wave J 仍是 NEXT
2. 盘点 client Send / redirect / retry / H1 RoundTrip 的 CreateOp 缺口
3. 补齐热点 Op + source-contract 锁定数；path-limited land main
4. 本文件：Wave J → landed；下一波按表推进
```

**没有用户「马上下一波」指令时：默认执行 Wave J。**
只有 Blocked / 需跨模块决策时才停下来问。

---

## 与其他文档的关系

| 文档 | 角色 |
|------|------|
| **ROADMAP.md（本文件）** | 向前做什么、顺序、状态 |
| **GOAL_TREE.md** | 为什么做、阶段定义、不漂移规则 |
| **CONTRACT.md** | 对外行为契约 |
| **API_COVERAGE.md** | 证据矩阵（顶部短结论 + Public Surface Matrix） |
| **[`archive/`](archive/README.md)** | 已完成波次档案；禁止当作隐式路线图 |

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-07-17 | 初版：合并 stage + Wave A–F 完成态；定义 Phase P/Q/R/X；Wave G = NEXT |
| 2026-07-17 | Wave L：历史 docs → `archive/`；瘦身 API_COVERAGE / GOAL_TREE 当前段 |
| 2026-07-17 | Wave G landed：Cookie eTLD+1 + PSL 子集；Wave H = NEXT |
| 2026-07-17 | Wave H landed：`IHttpResponse.FinalUrl` + `Version`；Wave I = NEXT |
| 2026-07-17 | Wave I landed：Proxy auth 冻结 Basic only + CONNECT 407 诚实错误；Wave J = NEXT |
