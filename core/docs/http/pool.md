# nextpas.core.http.pool — Client 连接池域契约

**模块**：`nextpas.core.http.pool.{base,intf,pas}` 聚合 `impl.h1.pool` + `impl.h2.client.pool`  
**层级**：L3 http（若需跨 http 复用再评估下沉 `nextpas.core.net.pool`，当前 L3）  
**四件套**：`pool.base` ← `pool.intf` ← `pool` 门面 ← `impl.*.pool` 实现  
**依赖**：L0–L2 only（`bytes.ops` 单源、`net.intf`、`sync`）  
**对应主契约**：`CONTRACT.md` §1.1 连接池行 + §5 pool 表 + §2.1 MaxPoolSize/IdleTTL

## 职责

- 按 authority（H1: host+port + scheme/prefix / H2: host+port+secure）管理空闲连接
- MaxPoolSize per-authority（默认 64，非全局）、IdleTTL 墙钟淘汰（默认 90000ms，0=关闭淘汰）
- CloseIdleConnections / destroy 全清（锁外 Close，不持锁做 IO）
- 健康探测：H1 TryRead WouldBlock=活 / H2 PING（PingTimeout 5000ms，0=仅状态位）

## 性能

- Host key 归一化 `CanonicalPoolHostKey` inline 薄转发，单源 `bytes.ops` / `text.conv` 不重复实现
- 借出/归还 `IdleAtMs` 墙钟检查在锁外/锁内最小临界区，不阻塞
- 零拷贝：key 视图不分配多余 string；tail 不拷贝

## 稳定性

- Destroy / CloseIdle 路径必 `PoolClear`，heaptrc 0 unfreed
- 锁外 Close/Free 避免 dead hang（IdleTTL suite 已验证）

## Owner 边界

- 缺能力先反哺 `bytes.ops`（key 编码）、`net`（stream runtime）、`sync`（mutex），不绕边界
