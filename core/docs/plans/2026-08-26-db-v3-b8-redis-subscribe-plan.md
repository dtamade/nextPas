# nextpas.core.db V3-B8 计划提案：redis SUBSCRIBE/PSUBSCRIBE 订阅面

> 2026-08-26。**状态：提案（待总控立项确认后才动代码）**。
> 动机：V3-B7 已交付 pg LISTEN/NOTIFY 订阅会话（`nextpas.core.db.pg.listen`，
> CONTRACT §2.18），其骨架（专用连接独占 + 单工泵线程 + 有界投递队列 +
> Token 取消 + 断线重连按快照重放）可泛化到 redis——五后端中唯一具备
> 原生推送语义的其余后端。本文回答：差异在哪、复用什么、门禁怎么设。
> 不改变路线图 §4"维持不做"边界（本片不属于其中任何一项）。

---

## 1. 对标锚点

Go go-redis `PubSub`（`Receive/ReceiveTimeout/Channel()`）、Rust
redis-rs `PubSub`（`set_connection_time`/`on_message`）。共性契约：
订阅即独占连接、消息至多一次、断线由客户端负责重订。

## 2. 与 B7 的关键设计差异（诚实清单）

| # | 差异 | 设计取向 |
|---|---|---|
| D1 | RESP2 进入订阅态后，除 SUBSCRIBE/UNSUBSCRIBE/RESET/QUIT/PING 外的命令一律报错——比 pg 更严的独占约束 | 结构性保证直接成立：订阅器私有建连且不暴露查询面（§2.18 同款） |
| D2 | 推送帧三分支：`message` / `pmessage` / `subscribe`+`unsubscribe` 确认帧 | 确认帧**不入消费队列**，转为订阅快照簿记的应用回执（pg 侧无此概念）；消费队列只见 message/pmessage |
| D3 | `pmessage` 比 `message` 多一个 pattern 字段 | v1 决策点：方案 a 只做精确 SUBSCRIBE（TDbPgNotification 同构，Pattern 字段不加）；方案 b 加 `Pattern: string` 字段并支持 PSUBSCRIBE。**倾向 b**——字段加尾不破坏既有消费者，pattern 是 redis pub/sub 的主要价值 |
| D4 | redis 订阅同样是会话级：断线即全部失效，无服务端留存 | 重连后按快照重放 SUBSCRIBE/PSUBSCRIBE——与 pg 完全同款；GapCount/DroppedCount/at-most-once 语义逐字复用 §2.18 |
| D5 | 协议解析已存在：`db.redis.base` RESP 增量解析器有帧级门禁（test_db_redis_base） | 泵线程直接消费解析器输出，零新造协议代码 |
| D6 | 心跳：RESP2 订阅态长连接无流量时中间设备可能掐断 | 可选 PING 保活节拍（复用泵 tick）；v1 默认关、选项开，诚实登记 |

## 3. 形态与命名

- 新单元 `nextpas.core.db.redis.subscribe`（对齐 pg.listen 命名惯例）：
  `TRedisSubscriber`，API 与 `TPgListener` 同形——`Listen/Unlisten/
  UnlistenAll/Receive(Token 属性/Connected/GapCount/DroppedCount/
  SubscribedChannels)`，消费方学习成本零增量。
- **不进统一接口**（决策点）：v1 保持 per-backend 类。理由同
  IDbLargeObjectControl（pg）vs IDbRowBlobControl（sqlite）的分面先例
  ——两种订阅语义差异大（频道确认帧/pattern/独占强度），等第二后端
  实证后再考虑抽象 `IDbNotifySession`，防过早抽象。
- 不经 db 门面、独立单元显式 uses（§2.17/§2.18 依赖隔离纪律同款）。

## 4. 门禁

- `test_db_redis_subscribe`：
  - 离线段：`IRedisTransport` 脚本回放（A5 先例，传输可注入）覆盖
    订阅确认簿记、message/pmessage 分派、断线重连重放、溢出保旧弃新、
    Token 取消停泵；
  - live 段：`NEXTPAS_REDIS_TEST_CONN` 门控真机自发自收
    （PUBLISH→Receive 往返）；
  - heaptrc 0 unfreed 硬门。
- 基准：`bench_db_redis_subscribe` 吞吐段入册 benchmarks.md（延迟段
  视 live 环境可用性，缺席如实登记）。

## 5. 复用度与风险

- 复用 ≈70%：泵循环骨架、环形队列、取消桥、重连状态机、门禁模板
  自 pg.listen 直接泛化（提取共享基类与否留实现时裁量——先复制后
  抽象，避免为两个实例过早造父类）。
- 新增 ≈30%：RESP 推送帧分支解析、订阅确认簿记、PSUBSCRIBE pattern
  面。
- 风险：①RESP2 订阅态 PING 行为跨 redis/valkey 版本差异——离线回放
  钉死行为再上真机；②脚本回放传输的时序保真度不足以暴露真实竞态
  ——以 live 段兜底；③redis 无证书体系下的 TLS 由 A5.1b TLSDial 承担
  （live TLS 段维持 NEXTPAS_REDIS_TEST_TLS_CONN 门控，与本片解耦）。

## 6. 验收判据

每门全绿 heaptrc 0 + 家族回归抽查（unified/conformance/redis_base/
redis_adapter/pg_listen 对照）+ CONTRACT 新节 + README 地图行 +
benchmarks.md 口径扩充——与 B7 收口纪律完全同款。
