# PERFORMANCE：热路径契约与资源预算

> 每条主张对应 TESTING.md 的 bench 项；landing 后数据落 BENCHMARKS.md。
> 无数据不叙事——本文件是机制侧契约，不是营销页。

## 1. 热路径复杂度契约

| 路径 | 复杂度 | 禁止 |
|------|--------|------|
| sse.Feed(bytes) | O(bytes) 单遍 | 回扫、逐字符字符串拼接 |
| Decoder.DecodeEvent | O(frame) | 每帧重建解析器/JSON DOM 全量重挂 |
| fold.FoldDelta | O(1) 摊销/delta（参数片段 StringBuilder 倍增缓冲）| per-delta SetLength、`s := s + x` |
| EncodeXxxRequest | O(payload) | 中间拷贝超过 2×payload |
| loop transcript 追加 | O(1) 摊销 | 每轮全量深拷贝历史（code888 已知债，明确不继承）|
| 工具查找 | O(n) n=注册工具数（n 小）| — （不上哈希表，避免过早优化）|

## 2. 缓冲与尺寸默认值

| 项 | 默认 | 说明 |
|----|------|------|
| transport 读 chunk | 32 KiB | IReader.Read 步长；首块前不预分配响应体 |
| SSE 行缓冲 | 初始 4 KiB，倍增至上限 1 MiB | 上限即 SECURITY DoS 线 |
| ArgumentsJson 累积 | StringBuilder 初始 256 B | 工具参数片段典型 <2KiB |
| RawBodySnippet | 8 KiB 截断 | ERRORS §6 |

## 3. 字符串与编码策略

- wire 请求体组装：StringBuilder（text 语义，`{$H+}` UTF-8）单遍写出；
  不经 JSON DOM 再序列化（DOM 组装会引入 2-3× 分配）。结构化字段仍走
  core json 的**写出器**；只有 Extra 回注等未知结构才透传原始文本切片。
- 响应解码：按帧局部解析（decoder 内），禁止整流拼接成大字符串再 Parse
  ——这正是真增量与低分配的同一条路径。
- TJsonText 字段赋值是引用计数拷贝（COW），词表记录传递零深拷贝；
  需要独立可变副本时显式 UniqueString（消费方责任）。

## 4. 分配预算（bench 断言口径）

| 操作 | 预算 |
|------|------|
| 折叠 10k delta（含 50 工具槽）| 分配次数以 bench 框架的分配计数钩子为准（若框架未提供则降级为时长回归阈值，首版基线时定）；禁止 per-delta SetLength 回归 |
| Feed 16 MiB SSE 流 | 行缓冲外每 chunk 零额外常驻分配 |
| fake provider 10 轮纯文本 run | 总时长 µs~ms 级（抽象税基准），无 IO |

## 5. 与底座的性能协同

- http client keep-alive 复用：transport 不主动关连接，EOF 后归还池
  （连接生命周期归 client 池管）。
- async.cancellation 的 WaitForCancel 是唯一睡眠原语；retry 退避不引入
  第二种等待机制（保证取消打断语义单点实现）。
- bench 回归阈值冻结流程：W4 首次全量跑取 p50 为基线写入 BENCHMARKS.md，
  之后任何 wave 收口对比，劣化 >10% 必须解释或回退。

## 6. 缓存友好不变量（W3 实施约束）

厂商 prompt cache 按请求前缀命中。agent 循环每轮全量重发历史，前缀稳定性直接
决定缓存命中率（成本差可达数量级），故 loop 构造每轮请求时必须遵守：

1. **历史消息序列字节稳定**：已完成轮次的消息内容/顺序/格式化永不重写
   （不重新缩进 JSON、不重排 part、不改 id）。
2. **system/tools 前置且恒定**：两者在请求对象中的位置与序列化形式跨轮不变。
3. **只追加**：每轮仅在尾部追加 assistant/tool 消息，禁止中间插入或压缩重排
   （自动 compaction 若将来引入，必须显式失效缓存预期并告知消费方）。

该不变量是 W3 test_loop 的断言项之一（连续两轮请求的前缀字节相等）。
