# Findings: H1 fast parser lazy headers

## Scope

本轮是 `nextpas.core.http` H1 fast parser / server fast snapshot 的窄性能优化。
不改公开 HTTP facade API，不改 wire contract，不写 inbox。

## Evidence on Pascal llhttp

本地复跑结果继续支持用户的疑虑：Pascal translated llhttp 本体相比 C llhttp 有 raw
gap。

- Pascal raw / C raw:
  - simple GET: `214.7 ns/op` vs `143.8 ns/op`
  - 10 headers: `754.8 ns/op` vs `535.6 ns/op`
  - POST 1KB: `436.6 ns/op` vs `285.7 ns/op`
  - pipeline 10 reqs: `2107.3 ns/op` vs `1346.5 ns/op`

子代理只读审查也给出同一结论：Pascal translated llhttp 有优化空间，但不建议现在手改大
状态机；当前 full parser / server 更大的确定成本仍是 adapter/materialization。

## RED evidence

新增 `test_http_h1fast` invalid header name/value fallback 后先跑：

```sh
make -C tests/nextpas.core.http/test_http_h1fast clean test
```

失败点：

```text
FAIL: Invalid header name fallback - invalid header name character
FAIL: Invalid header value fallback - invalid header value: contains CR/LF/NUL
```

这证明 fast parser 成功路径当前依赖 eager `THttpHeaders.Add` 做校验，异常输入不能干净
fallback。

## Implemented change

- 新增内部 `TFastLazyHeaders`，实现 `IHttpHeaders`，保存 raw header block。
- `FastParseRequest` 在扫描阶段显式校验 header name/value、设置 policy flags 和解析
  `Content-Length`，成功后才返回 lazy header interface。
- lazy headers 只在 `Get` / `GetAll` / `ForEach` / mutation / `Clone` 等接口调用时物化成
  `THttpHeaders`。
- `TH1ServerConnectionState` 在 fast snapshot 路径复用已知 policy facts，避免
  `HeaderPolicyErrorStatus`、keep-alive、Host 检查触发 materialization。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - 2 个新增 case 按预期失败。
- Focused fast parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `22 total, 22 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Benchmark sanity

Parser benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Fast rows:

| workload | ns/op |
| --- | ---: |
| simple GET | 349.9 |
| 10 headers | 1351.5 |
| POST 1KB | 628.9 |
| pipeline 10 reqs | 3526.5 |

Server benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_server clean run
```

- `87356 req/s`

Conclusion: parser microbench 明确受益；server benchmark 仍在此前噪声带内，不能声明稳定
full-chain throughput 提升。

## Remaining gaps / risks

- `TBenchRunner` / C comparator 当前 `MAX_ITERS = 1000`，短路径 benchmark 可信度不足；
  下一批应先提高/参数化迭代上限。
- Pascal translated llhttp 的大状态机、record-return matcher、cdecl helper 仍是长期优化轨道，
  但不适合当前手工改。
- lazy headers 目前复制 raw header block；相比 eager 多 string/header entries，仍是明显更轻，
  后续可继续评估 span-backed lifetime 模型，但要谨慎处理 buffer ownership。
