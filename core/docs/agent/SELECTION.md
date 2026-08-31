# SELECTION：选型分析

> 本文是 DESIGN.md 决策记录（D1-D14）背后的完整论证：每个选型点列候选方案、
> 业界/仓库内先例、决定性维度、结论与翻案条件。
> 结论与 DESIGN/API 冲突时，以本文档最新修订为准并回写前者。

## 0. 评审维度

| # | 维度 | 含义 |
|---|------|------|
| V1 | 可测性 | 能否离线、零睡眠、确定性断言 |
| V2 | 性能 | 热路径分配与复杂度（口径见 PERFORMANCE）|
| V3 | FPC 约束 | FPC 3.3.1 语言现实（匿名函数捕获限制、无 nullable、COW 等）|
| V4 | 底座契合 | 只用 nextpas.core 已有原语，不自造第二套设施 |
| V5 | 迁移成本 | token888 / code888 作为首发客户的接入摩擦 |
| V6 | 维护面 | 长期代码量与怪癖修正的单点性 |

---

## C1 流原语形态：pull 接口 vs push 回调 vs 协程通道

| 方案 | 先例 | 要点 |
|------|------|------|
| **pull `NextDelta(out Δ)`** ✅ | codex/opencode reader 形态、code888 已验证、Vercel async iterator 同构 | mock=喂数组；消费循环直线；异常不打断拉取 |
| push 回调三件套 | 多数 HTTP SDK（onMessage/onError/onDone） | 回调里抛异常的传播路径复杂；FPC 匿名函数不能捕获局部变量（token888 实测教训），上下文必须经 Pointer 显式传——push 的实现成本和出错面都被放大 |
| 协程通道 | Go chan 风格 | 依赖 coroutine 设施；同步消费者反而绕远 |

**结论**：pull。**翻案条件**：出现大量"多消费者扇出同一流"需求（当前明确不支持，
见 LIFECYCLE §7），届时在 completion 之上加 broadcast 装饰器而非改原语。

## C2 词表载体：record 值语义 vs interface 对象图

record ✅（TPart/TMessage/TStreamDelta 全部 record）：值传递零深拷贝（COW 引用计数）、
快照/比较/序列化直接、测试断言天然确定。interface 对象图（Anthropic SDK 风格
content_block 对象）会引入生命周期管理噪音，违背"纯数据无生命周期"框架准则。
**代价与对策**：动态数组字段只整体重建禁原地改（ARCHITECTURE §6）；大 transcript
逐轮复制风险由 PERFORMANCE §6 只追加不变量规避（历史数组引用共享而非重建）。

## C3 wire 请求体载体：string vs TBytes

string ✅：`{$H+}` 下即 UTF-8 文本；http client 有 PostString 直发；
组装单遍 StringBuilder/TJsonWriter 写出。TBytes 的收益仅在二进制 payload（图像
data URI 已是 base64 文本，无二进制收益）。响应侧 transport 从 IReader 读入
TBytes 后一次转 string（帧局部处理，见 C5，无整流拼接）。
**翻案条件**：未来接入二进制模态（audio）再为该字段单独用 TBytes。

## C4 JSON 编码策略：TJsonWriter 单遍 vs builder DOM vs 手拼字符串

| 方案 | 先例 | 要点 |
|------|------|------|
| **TJsonWriter（core.json.writer，流式写出 record）** ✅ | 底座自有 | 单遍 O(payload)，转义正确性由底座保证 |
| builder/DOM 组装后 Stringify | 常见做法 | 2-3× 分配（PERFORMANCE 明令避免）|
| 手拼字符串 | token888 JsonBuilder 痛点自述（其 M3 技术债） | 转义 bug 温床 |

**结论**：请求编码一律 TJsonWriter；Extra 无损回注处透传原始文本切片。
**翻案条件**：writer 若被证实不支持嵌套便利写法，允许 provider.common 封装薄 helper，
但不得绕开其转义。

## C5 JSON 解码策略：帧局部解析 vs 整流解析

帧局部 ✅：decoder 收到单个 SSE event 的 data 字符串后即刻 parser/scanner 解析——
真增量与低分配是同一条路径（整流解析正是 code888 全缓冲债的根因）。
底座事实（已核实）：`json.parser/scanner` 是**整输入** token 化（TStringView 进），
满足帧局部需求；**feed 式增量解析不存在**——工具参数边流校验（inbox 组 B）因此
保持"先反哺 json 域再立项"的前置条件。

## C6 错误形态：单一异常族+字段 vs 子类树

单族 ✅（EAgentError + EAgentCancelled 一个子类）。仓库先例 fs.errors/crypto.errors
是多子类风格，但本模块错误码位多（14 个）且诊断字段（Provider/RequestId/
RetryAfterMs/RawBodySnippet）必须随行——字段化承载优于 14 个空壳子类；
catch 边界也只需两类。**翻案条件**：出现"某类错误需要专属行为方法"的真实需求。

## C7 重试位置：装饰器 vs provider 内嵌 vs runtime 散落

装饰器 ✅（详见 DESIGN D6）。补充论证：Vercel AI SDK 的 middleware 包装、
Go net/http RoundTripper 装饰是同一形态；provider 内嵌使策略不可组合且测试需
真实时钟；token888 证明零重试不可用，code888 证明 runtime 内散落不可测。
装饰器还免费解锁 inbox 组 A 全部候选（Fallback/Hedge/Throttle 同构）。

## C8 时钟注入：IAgentClock vs 直接 Sleep

IAgentClock ✅：退避测试零睡眠（code888 TFakeLLMClock.Advance 先例）；真实实现
底层 WaitForCancel 保取消打断语义单点（PERFORMANCE §5）。生产默认 NewSystemClock
一行装配，不强迫用户感知时钟存在。

## C9 并行工具执行原语：thread 池 vs async taskgroup vs 自研 ⚠️ 修订 D14

底座核实结果（本档新增）：

- `CreateTaskGroup(ALoop: TAsyncLoop)` —— **绑定事件循环**，面向 async reactor
  场景；同步阻塞的工具批次用它需要凭空造 Loop，错配。
- `IThreadPool`（L1 thread）：`SubmitBatch(tasks)` 单锁广播提交 +
  `WaitAllTimeout(ns)` 汇合——与同步轮线程完美契合，且有 work-steal 变体备选。

**修订结论（覆盖 LIFECYCLE §5 原 taskgroup 表述）**：并行工具批 =
`IThreadPool.SubmitBatch` 提交 + 原子完成计数 + 轮线程带超时汇合；
池实例由 loop 持有（构造可注入，默认共享进程池）。批内失败隔离仍走子令牌
（async.cancellation.CreateChildToken）。**翻案条件**：loop 若将来异步化，
重评 taskgroup。

## C10 取消词表：async.cancellation vs thread.cancel（双词表现状）

底座现状存在两套：`IAsyncCancellationToken`（含 WaitForCancel/CreateChildToken）
与 `thread.intf.ICancellationSource/Token`。本模块**统一选 async.cancellation**：
能力更全（子令牌树+等待打断），且 retry 退避睡眠依赖 WaitForCancel。
工具实现收到的也是同一接口，IsCancelled 轮询即可。
**翻案条件**：core 未来统一取消接缝时跟随迁移（词表层只动类型别名）。

## C11 会话持久化时机：接口先行 vs 全做 vs 不做

接口先行 ✅（DESIGN D10）。LangGraph checkpoint 与 code888 event-sourcing 各证明
了持久化的价值与体量——后者 fork/crash 恢复/fsync 节奏是独立工程，塞进 v1 必然
挤压协议层质量。内存实现 W4 交付最小可用；JSONL 版 W5 按需。
（2026-08-25 审计注：内存实现未随 W4 落地——当前仅 intf 词表接口先行，
无任何 store 实现；补齐与否随 W5 session 立项一并定。）

## C12 编解码器公开度：公开 vs 私有

公开 ✅（DESIGN D13）。补充先例：LiteLLM 以"翻译层"立库、Vercel 把 provider spec
独立成包供网关类项目复用——协议翻译单独成面是被验证过的产品形态。
对纯客户端用户成本为零（工厂内部同一实现）。

## C13 模块家族划分：单 family `agent` vs 双 family `llm`+`agent`

单 family ✅。registry 先例：`http` 一个 family 容 server/client/sse/middleware。
provider+loop 分家会迫使 loop 引用跨 family（合法但增加注册表面），而两者共享
词表单元，分家只会制造"词表归属"争论。子域边界由单元命名承担。

## C14 本地消息 ID 策略：留空 vs 本地生成（ULID/v7）

**留空串 ✅**（house 规则"无值用 nil/空表达"）：Id 字段语义 = 厂商消息 id，
厂商未给即为空，不伪造唯一性。loop transcript 排序依赖数组位置而非 id；
session 存储键是 ThreadId。**翻案条件**：W5 JSONL store 若需要稳定消息主键，
届时引入"store 层本地 id"，仍不污染词表语义（id 模块 ulid/v7 备好即用）。

## C15 日志接缝：log.intf 可选注入 vs 无日志

可选注入 ✅：`TProviderOptions.Logger / TAgentLoopOptions.Logger : ILogger`
（log.intf 的 NullLogger 保证零开销默认）；脱敏内容以 SECURITY §2 等级表为准。
不做模块级全局 logger（D4 同理：无可变全局态）。

## C16 测试替身形态：三层各管一段

| 替身 | 截止层 | 用途 |
|------|--------|------|
| FakeProvider（脚本 delta 数组） | provider 接口之上 | loop/tools/上层业务测试 |
| ScriptedTransport（wire 快照回放/投喂） | transport 接缝 | adapter 怪癖回归、真增量时序断言 |
| FakeClock | 时钟接缝 | retry 曲线、超时路径 |

三层正交，任何一层都不许越界 mock 更低层（防 code888 刀56 式"门测绕过装配链"）：
test_assembly gate 强制走一次真实装配函数。

## C17 超时模型：connect+total vs idle-based

v1 采用 connect+total 双旋钮 ✅（两厂商长尾推理请求 total 默认 300s）。
idle-based（codex 风格空闲 408）作为 Inbox 组 A 的 IdleGuard 装饰器候选——
它是传输行为策略，不该焊死在词表里；等真实长尾数据再定默认。

---

## 附：选型总览表

| 点 | 结论 | 一句理由 |
|----|------|---------|
| C1 | pull 接口 | 可测+直线消费+FPC 捕获限制不利于 push |
| C2 | record 词表 | 值语义/COW 零拷贝，符合框架纯数据准则 |
| C3 | string wire | UTF-8 文本直发直收，无二进制收益场景 |
| C4 | TJsonWriter 单遍 | 底座流式写出器，杜绝手拼转义 bug |
| C5 | 帧局部解码 | 真增量与低分配同路径；增量校验待 json 反哺 |
| C6 | 单异常族+字段 | 诊断字段随行，catch 边界最窄 |
| C7 | WithRetry 装饰器 | 可组合、可离线测、解锁后续全部弹性装饰器 |
| C8 | 注入时钟 | 零睡眠测试；取消打断单点 |
| C9 | IThreadPool.SubmitBatch | taskgroup 绑 AsyncLoop 属错配（已核实）|
| C10 | async.cancellation 词表 | 子令牌+等待打断更全；统一迁移留别名位 |
| C11 | 会话接口先行 | 持久化工程量独立立项，勿挤占协议质量 |
| C12 | codec 公开 | 网关型客户的存在前提 |
| C13 | 单 family | http 先例；共享词表不宜分家 |
| C14 | 消息 Id 留空 | 不伪造唯一性；store 层将来自带主键 |
| C15 | log.intf 可选注入 | NullLogger 零开销默认，无全局态 |
| C16 | 三层替身正交 | 各截止一层，装配链必经 test_assembly |
| C17 | connect+total | idle 策略留给装饰器按数据定默认 |
