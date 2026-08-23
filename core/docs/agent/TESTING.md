# TESTING：测试 gate、离线纪律与基准计划

> 铁律：**仓库内任何 test / example / benchmark 禁止触公网 LLM API。**
> "接近真实"用 scripted transport + 快照 wire 体实现；需要新快照时由开发者
> 本地采集后脱敏提交（去 key、去 requestId），gate 只回放。

## 1. 测试框架与布局

- 框架：`nextpas.core.test`（TTestSuite + Check*/Expect，禁手写 runner）。
- 布局：`core/tests/nextpas.core.agent/<gate>/<gate>.lpr`，每 gate 独立项目。
- 运行：`make focused FOCUS=core/tests/nextpas.core.agent/<gate>`。

## 2. Gate 清单

| Gate | 覆盖 | 关键断言 |
|------|------|---------|
| `test_compile_skeleton`（W0）| 空 facade + base + errors 骨架 | 单元可编译；uses 方向符合 ARCHITECTURE §1 铁律 |
| `test_protocol` | base 词表 + fold | FoldDeltas 全词表矩阵：text/thinking 交错、tool 多槽并行折叠（index 分桶）、usage/finish 三种到达顺序等价、违例序列抛 aecProtocol、Extra 无损往返 |
| `test_errors` | 错误分类器 | ErrorCodeForStatus 全状态映射；Retryable 推导表；RetryAfterMs 解析（ms 头/秒头/date 拒绝→unknown）；超窗措辞全集识别 |
| `test_sse` | agent.sse 增量解析器 | 帧跨 chunk 断裂、多行 data、CRLF/LF、BOM、event+data 组合、半帧保持状态、**UTF-8 多字节序列跨 Feed 边界断裂**（WIRE-MAPPINGS §0）、EOF 收口、恶意超长行上限 |
| `test_transport_stream` | transport.http + 时序 | scripted chunk 流验证**真增量时序**：喂 chunk N 即产出对应事件（不等到 EOF）；Cancel 中途立即返回 False 且 GetCancelled=True；非流式 RoundTrip 超时/连接失败归因 aecTimeout/aecTransport；**回环硬取消**（裸 TCP 恒长 chunked SSE 源）：Cancel 后 NextEvent 在 IO 切片级返回 False 而非等满请求超时，弃置未读完的流 Destroy 快速收合 worker |
| `test_provider_openai` | openai 适配器 | 请求编码快照（含 sentinel 省略、Q-O1 改名、tools 编码）；响应解码快照（非流式+流式全事件序）；怪癖 Q-O2..Q-O6 各一条回归 |
| `test_provider_anthropic` | anthropic 适配器 | 编码快照（max_tokens 强制、thinking 预算校验、Q-A4 工具结果入 user 角色、is_error 哨兵仅失败上送、image mime 白名单、system 合并去重）；解码全字段（thinking+signature 透传 Q-A3、usage 含 cache read/write）；流帧 FSM 全轨迹（tool_use 即宣告、input_json_delta 分片重组、message_delta stash、message_stop 合成 finish+usage Q-A2）；ping/未知事件跳过；中途 error→sdkError+死态；Q-A8 截断 fail-closed；provider e2e（url/头/model 回退）+env nil 纪律 |
| `test_provider_anthropic` | anthropic 适配器 | 同上对称集；Q-A1 首信封、Q-A2 usage 双源合成、Q-A3 signature 透传、Q-A4 tool_result 分组、MaxTokens unset→aecConfig |
| `test_codecs` | 公开编解码器（D13） | 快照 wire → Decode → 词表 → Encode 语义等价往返（Extra 保真）；未映射枚举值→零值+`agent.unmapped.*`+warn；WireDecoder 跨断裂帧与 Finalize 双序（usage 先/后）等价、anthropic 无 message_stop 的 EOF 抛 aecProtocol（Q-A8）；协议违例输入抛 aecProtocol 带 RawBodySnippet；网关式双角色并行解码互不污染 |
| `test_retry` | WithRetry + fake clock | 429 按 Retry-After 重试成功；指数退避曲线+抖动边界；MaxAttempts 耗尽抛原始错误；白名单外错误直通不睡；取消打断退避（fake clock 推进+令牌触发）；全程零真实睡眠 |
| `test_tools` | 校验/截断/包装 | 名称合法性、schema 结构校验失败→error result；2000 行/64KB 截断标记 Truncated；executor 超时包装经 fake clock 生效 |
| `test_loop` | TAgentLoop 全语义 | 单轮直答；工具单轮/并行批（全 tcParallel 才并行——用记录执行顺序的桩断言串并行）；hook block/stop 三值；预算耗尽走"引导总结"收尾 roBudgetExhausted；防打转阈值触发 roDoomLoop；取消在轮界/工具界生效 roCancelled；OnEvent 事件序快照 |
| `test_fake_provider` | fake/scripted 自身 | 脚本回放顺序、耗尽再调抛错、echo 桩 |
| `test_assembly` | **真实装配链** | 经生产装配函数组装 provider（注入 scripted transport）跑通完整一轮——防"门测走 canned 绕过装配点"事故复发（code888 刀 56 教训） |
| `test_security` | SECURITY 验收项落 CI | 捕获型 ILogger（testkit）断言脱敏表：鉴权头/请求体/RawBodySnippet 全文不入日志；256KiB 参数预检；64 键 Extra 上限；FromEnv 缺 env 返回 nil；mime 白名单 aecConfig；Utf8SafeTruncate 边界；Active 期 GetMessage 抛 EAgentMisuse |

## 3. 测试基建

| 件 | 形态 |
|----|------|
| FakeClock | 实现 IAgentClock：NowMs 手动推进；SleepMs 记录请睡时长并按脚本立即返回（模拟取消）|
| ScriptedTransport | 实现 IAgentTransport：按脚本返回 TWireResponse 或逐块投喂 OpenStream；可编排"延迟 3 块后 Cancel" |
| Wire 快照 | `tests/nextpas.core.agent/snapshots/{openai,anthropic}/*.json`；采集脚本脱敏规则见上 |

替身落位：ScriptedTransport/FakeClock 接线与 wire 快照装载位于
`tests/nextpas.core.agent/testkit/agent.testkit.pas`（测试树，不进 src/）；
例外是 `TFakeClock` 本体——它在产品单元 `nextpas.core.agent.clock` 公开
（API.md §3），因消费方自建离线测试同样需要它。

## 4. 基准计划（nextpas.core.bench 强制）

| Bench | 度量 | 回归阈值（首版基线落地后冻结）|
|-------|------|------|
| `bench_fold` | 10k delta（含 50 工具槽参数片段）FoldDeltas 总耗时 | ns/op；无 per-delta SetLength 回归（分配次数随行数线性封顶）|
| `bench_sse_feed` | 16MB SSE 流分 32KB 块 Feed | MB/s ≥ http.sse 整包解析器的同等数量级 |
| `bench_loop_overhead` | fake provider 下 10 轮纯文本 run 总开销 | µs/run 级；证明抽象零税 |

纪律：-O2 运行；禁止自定义计时/内循环/手算统计（design-conventions §12）。

## 5. 出口检查（每 wave）

```bash
make focused FOCUS=core/tests/nextpas.core.agent/<该wave gates>
git diff --check
make hygiene
```

W4 追加全部 gates + benchmarks 数据写入 `docs/agent/BENCHMARKS.md`（landing 时建立）。
