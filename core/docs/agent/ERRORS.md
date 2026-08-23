# ERRORS：错误流转矩阵与语义细则

> 权威来源链：**API.md**（词表与签名权威）> **本文档**（错误行为细则）>
> 代码注释。DESIGN/SELECTION 是论证记录，不作实施依据。
> 所有层的错误行为必须能在本文档找到对应行；新增错误码/错误路径先改这里。

## 1. 错误产生点矩阵

| 层 | 可产生的错误码 | 说明 |
|----|--------------|------|
| transport.http | aecTransport, aecTimeout, aecServer, aecRateLimited, aecAuthentication, aecNotFound, aecInvalidRequest | 连接/读写失败与超时由传输直接产生；HTTP 状态码经公共分类器归约（非 2xx 一律在此转错误码，adapter 见不到裸状态码） |
| provider.openai / anthropic | aecProtocol, aecConfig, aecContextOverflow | 编解码违例；本地配置缺失（MaxTokens/key）；超窗措辞识别 |
| provider.fake | aecProtocol | 脚本耗尽后再调用 |
| WithRetry | （透传最后一次原始错误）| 重试耗尽不包装、不改码、不丢 RetryAfterMs |
| agent.sse | aecProtocol | 正常解析仅产帧不抛错；触发 DoS 上限（SECURITY §3）直接抛 aecProtocol 终止流 |
| loop | aecToolFailed, aecBudgetExhausted（收尾态）, aecCancelled, aecConfig | 工具异常兜底；预算走 RunOutcome 而非异常（见 §5）|
| 词表/fold | aecProtocol | delta 序列违反折叠规则 |

## 2. 重试判定权威表

| 错误码 | Retryable | 典型来源 | RetryAfterMs 适用 |
|--------|-----------|---------|------------------|
| aecInvalidRequest | 否 | 400（非超窗措辞） | 否 |
| aecAuthentication | 否 | 401/403 | 否 |
| aecNotFound | 否 | 404 | 否 |
| aecRateLimited | 是 | 429 | 是（头优先于退避曲线）|
| aecTransport | 是 | connect/reset/broken pipe | 否 |
| aecTimeout | 是 | connect/整体超时 | 否 |
| aecServer | 是 | 5xx, 529(overloaded) | 若带头则用 |
| aecContextOverflow | 否 | 400 + 超窗措辞 | 否（需消费方改 history）|
| aecProtocol | 否 | 帧违例/脚本耗尽 | 否 |
| aecCancelled | 否 | 令牌触发 | 否 |
| aecConfig | 否 | 本地装配 | 否 |
| aecToolFailed / aecBudgetExhausted | 否 | loop 层 | 否 |

铁律重申：上游 4xx 语义错误**原样透传**（token888 归因分离），WithRetry 白名单
默认 `[aecRateLimited, aecTransport, aecTimeout, aecServer]`。

## 3. 公共错误信封解析算法

```
function ClassifyUpstreamError(Status, Headers, Body):
  Snippet := Utf8SafeTruncate(Body, 8KB)          { 见 §6 }
  Msg     := ExtractJsonField(Body, "error.message")   { 两厂商同形，openai:
             error.{message,type,code}；anthropic: error.{type,message} }
  Code    := ErrorCodeForStatus(Status)
  if Code = aecInvalidRequest and MatchesOverflowPhrases(Msg):
    Code := aecContextOverflow                    { 覆盖 400 归因 }
  if Status = 429:
    RetryAfterMs := ParseRetryAfter(Headers)      { retry-after-ms > retry-after(秒);
                                                     HTTP-date 不解析 → CRetryAfterUnknown }
  raise EAgentError(Code, Msg, Retryable=IsRetryable(Code),
                    Provider=<name>, RequestId=ProbeRequestIdHeaders(Headers),
                    RawBodySnippet=Snippet)
```

## 4. 异常形态与消息规范

- 单一异常族：`EAgentError`（含全部上下文字段）+ `EAgentCancelled` 子类。
  不建深层继承树；不引入异常链（Pascal 无此惯例），上下文进字段不进 message。
- Message 格式：`[<provider>] <code-name>: <upstream-or-local message>`，
  例 `[anthropic] rate_limited: Number of requests too high (status=429)`。
  本地错误 Provider 为空串，前缀省略。
- EAgentCancelled.Message 固定 `"operation cancelled"`；判定取消永远看类型/码，
  不做字符串匹配。

## 5. 取消语义全表

| 场景 | 行为 |
|------|------|
| `IAgentCompletion.NextDelta` 进行中 Cancel | 当前阻塞读被打断，返回 False；GetCancelled=True；已产出 delta 有效 |
| `Complete()` 任意阶段取消 | 抛 `EAgentCancelled`——**取消优先于一切结果**（含退避中的最后一次原始错误）|
| `Loop.Run()` 轮界/工具界检测 | 终止轮询，RunOutcome=roCancelled；FinalMessage 为空记录（IsEmpty 判别，TryGetFinalMessage=False），Transcript 保留已完成部分 |
| 工具执行中取消 | 令牌已传入 IToolContext；工具自行响应；忽略令牌的工具无抢占式中断——超时后合成 timeout error result，工作线程弃置（LIFECYCLE §5 弃置策略），Run 不被无限拖住 |
| 退避睡眠中取消 | SleepMs 返回 False → 抛 `EAgentCancelled`（与 Complete 行同一规则的两面，不吞为成功、不还原为原始错误）|
| 取消后的资源 | 连接关闭/归还由 transport 完成（拥有线程内）；磁盘类副作用本模块无 |

## 6. 边界细则

- **Utf8SafeTruncate**：8KB 截断必须回退到 UTF-8 序列边界（最多回退 3 字节），
  绝不产出半字符——错误摘要会进日志，半字符会破坏下游 JSON 编码。
- **sdkError delta 之后必 EOF**：adapter 产出 sdkError 后不得再产出任何其他
  delta；错误由 IAgentCompletion 实现缓存（fold 跳过 sdkError，不进消息），
  EOF 后首次 GetMessage 抛出对应 `EAgentError`，重复调用重复抛同一缓存实例
  （pull 循环本身不被异常打断——错误延迟到取结果时刻）。
- **空输入**：Messages 空 + System 空 → `aecConfig`，在**适配器编码入口统一
  检查**（两厂商同规则；test_provider_* 各一条断言）；不发无效请求。
