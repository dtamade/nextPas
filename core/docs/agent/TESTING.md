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
| `test_compile_skeleton`（W0）| 门面/base/errors 骨架 + 错误分类器 | 单元可编译；uses 方向符合 ARCHITECTURE §1 铁律；词表哨兵/builder/usage 值语义；ErrorCodeForStatus 全状态映射；IsRetryable 推导表；错误信封 upstream 格式与字段保真/local 默认；EAgentCancelled/EAgentMisuse 语义；facade 转发 |
| `test_protocol` | base 词表 + fold | FoldDeltas 全词表矩阵：text/thinking 交错、tool 多槽并行折叠（index 分桶）、usage/finish 三种到达顺序等价、违例序列抛 aecProtocol、Extra 无损往返 |
| `test_sse` | agent.sse 增量解析器 | 帧跨 chunk 断裂、多行 data、CRLF/LF、BOM、event+data 组合、半帧保持状态、**UTF-8 多字节序列跨 Feed 边界断裂**（WIRE-MAPPINGS §0）、EOF 收口、恶意超长行上限 |
| `test_transport_stream` | transport.http + 时序 | scripted chunk 流验证**真增量时序**：喂 chunk N 即产出对应事件（不等到 EOF）；Cancel 中途立即返回 False 且 GetCancelled=True；非流式 RoundTrip 超时/连接失败归因 aecTimeout/aecTransport；**回环硬取消**（裸 TCP 恒长 chunked SSE 源）：Cancel 后 NextEvent 在 IO 切片级返回 False 而非等满请求超时，弃置未读完的流 Destroy 快速收合 worker |
| `test_provider_common` | provider.common 分类器直测 | ParseRetryAfterMs 三形态全集：ms 头解析/去空白/头名大小写、秒级 ×1000、ms 优先且无效 ms 落秒级、HTTP-date/垃圾/缺失→unknown、负值一律不信任；MatchesOverflowPhrases 六短语全集（WIRE-MAPPINGS §0）+大小写不敏感+任意位置子串+无误报；BuildUpstreamError 契约：400+超窗措辞→aecContextOverflow 终态、401 归因、429 携带解析出的 Retry-After |
| `test_provider_openai` | openai 适配器 | 请求编码快照（含 sentinel 省略、Q-O1 改名、tools 编码）；响应解码快照（非流式+流式全事件序）；怪癖 Q-O2..Q-O6 各一条回归；W6：response_format json_schema strict 编码、schema 非 JSON object→aecConfig 不发网、tool_choice 四形态 wire 断言、tcmNamed 缺名→aecConfig |
| `test_provider_anthropic` | anthropic 适配器 | 编码快照（max_tokens 强制、thinking 预算校验、Q-A4 工具结果入 user 角色、is_error 哨兵仅失败上送、image mime 白名单、system 合并去重）；解码全字段（thinking+signature 透传 Q-A3、usage 含 cache read/write）；流帧 FSM 全轨迹（tool_use 即宣告、input_json_delta 分片重组、message_delta stash、message_stop 合成 finish+usage Q-A2）；ping/未知事件跳过；中途 error→sdkError+死态；Q-A8 截断 fail-closed；provider e2e（url/头/model 回退）+env nil 纪律；Q-A1 首信封、MaxTokens unset→aecConfig；W6：tool_choice auto/any/tool 编码、tcmNone 省略 tools 转译、ResponseSchemaJson fail-fast aecConfig、tcmNamed 缺名→aecConfig |
| `test_codecs` | 公开编解码器（D13） | 快照 wire → Decode → 词表 → Encode 语义等价往返（Extra 保真）；未映射枚举值→零值+`agent.unmapped.*`+warn；WireDecoder 跨断裂帧与 Finalize 双序（usage 先/后）等价、anthropic 无 message_stop 的 EOF 抛 aecProtocol（Q-A8）；协议违例输入抛 aecProtocol 带 RawBodySnippet；网关式双角色并行解码互不污染；W6：openai Encode 含 response_format+tool_choice 请求快照断言 |
| `test_clock` | IAgentClock 实现 | TFakeClock 零睡眠记录（LastSleepRequestMs）+ Advance 虚拟推进、已取消令牌 SleepMs=False 且仍记录请求、经接口引用驱动可用；SystemClock NowMs 单调、自然睡眠耗时匹配请求、预取消长睡立即返回 False 不真等 |
| `test_retry` | WithRetry + fake clock | 429 按 Retry-After 重试成功；指数退避曲线+抖动边界；MaxAttempts 耗尽抛原始错误；白名单外错误直通不睡；取消打断退避（fake clock 推进+令牌触发）；全程零真实睡眠 |
| `test_resilience` | 韧性纯函数三件 | StreamHasError 断流帧指纹判定；WaitCancelMs 取消感知等待（预取消 True、nil 源吸收、非正延迟跳过、ms→ns 超界守卫不挂死）；ClampHintMs 服务端提示与本地退避同帽收敛、负哨兵透传 |
| `test_tools` | 校验/截断/包装 | 名称/schema 注册校验 aecConfig；§1.5 参数校验全集（256KiB 预检、深度上限、required 存在性、string/number/boolean 类型核对）失败→error result；行/字节截断信封（UTF-8 安全切、双限兜底）；超时包装经 fake clock 驱动虚拟截止且迟到结果不回读；中途取消合成 cancelled error；工具异常兜底 'tool raised' 归因；ctx 令牌/序号贯通 |
| `test_loop` | TAgentLoop 全语义 | OnEvent 事件序快照（runStart..runEnd 全轨迹）；并行证明批（原子闸门桩：真并行时 B 放行 A，退化串行即饿死暴露）；80% 预算预警一次性+roBudgetExhausted 引导收尾（引导轮 Tools=nil 断言）；防打转阈值 roDoomLoop+引导文本逐字断言；MaxToolCalls 批裁剪至余量；roRoundsExhausted；pre-hook hvBlock 合成错误回喂/hvStop 即终点不回喂；post-hook 只见截断后载荷；未知工具合成错误回喂；provider 失败→roFailed+LastError 保真不冒泡；轮界取消 roCancelled 无 FinalMessage；回调异常直接冒出 Run |
| `test_fake_provider` | fake/scripted 自身 | 脚本回放顺序、耗尽再调抛错、echo 桩；W6：带 ResponseSchemaJson/ToolChoice 的请求回放不受影响（回放即所得，不校验 schema） |
| `test_assembly` | **真实装配链** | 经生产装配函数组装 provider（注入 scripted transport）跑通完整一轮——防"门测走 canned 绕过装配点"事故复发（code888 刀 56 教训） |
| `test_security` | SECURITY 验收项落 CI | 捕获型 ILogger（testkit）断言脱敏表：鉴权头/请求体/RawBodySnippet 全文不入日志；256KiB 参数预检；64 键 Extra 上限；FromEnv 缺 env 返回 nil；mime 白名单 aecConfig；Utf8SafeTruncate 边界；Active 期 GetMessage 抛 EAgentMisuse |
| `test_session` | W5 JSONL 转录存储 | 全词表无损往返（thinking+signature+tool_call+tool_result is_error+image+extra）；跨实例持久；torn tail 丢弃；损坏行/未知版本/未知 kind fail-closed 含行号；Delete 幂等；缺失线程空载；ThreadId 校验全集防路径穿越；Fork 干净快照且拒绝已存在目标/自 fork；双同步模式；Unicode 与转义往返；usage unknown 不伪造 0 |

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
| `bench_sse_feed` | 16MB SSE 流分 32KB 块 Feed | MB/s 绝对值基线 176（BENCHMARKS §2；http.sse 为文本行域引擎，无同口径对照）|
| `bench_loop_overhead` | fake provider 下 10 轮纯文本 run 总开销 | µs/run 级；证明抽象零税 |

纪律：-O2 运行；禁止自定义计时/内循环/手算统计（design-conventions §12）。

## 5. 出口检查（每 wave）

```bash
make focused FOCUS=core/tests/nextpas.core.agent/<该wave gates>
git diff --check
make hygiene
```

W4 追加全部 gates + benchmarks 数据写入 `docs/agent/BENCHMARKS.md`（landing 时建立）。
