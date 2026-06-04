# Findings: HTTP parser span append fast path

## Scope

本轮继续服务 `HttpServer 完成` 的性能路线，聚焦 `TH1Parser` 的 llhttp callback adapter。
上一轮已经降低 `THttpHeaders.Add` 的数组分配抖动；本轮继续处理 URL/header field/header
value span 进入 Pascal string 的成本。

## Confirmed truths

### 1. Existing callback pattern did extra allocation

旧回调模式：

```pascal
SetString(LChunk, p1, p2);
FCurrentField := FCurrentField + LChunk;
```

常见单段 header field/value 会先创建临时 `LChunk`，再通过字符串拼接写入目标字段。跨 buffer
分片时也会同时承担临时 string 和最终 string 的两次搬运。

### 2. Split callback behavior is now locked

`test_http_h1parser` 新增 `Split header callbacks accumulate`，把 request line、`Host`
field/value、`X-Custom` field/value 分成多个 `Execute` 调用喂给 parser，并验证：

- request 最终完成。
- URL 合并为 `/split/path?x=1`。
- `Host` 合并为 `example.com`。
- `X-Custom` 合并为 `value`。

### 3. Parser benchmark evidence

生产代码修改前：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

修改前 llhttp rows：

| workload | before ns/op |
| --- | ---: |
| simple GET | 1298.0 |
| 10 headers | 4704.7 |
| POST 1KB body | 2136.6 |
| pipeline 10 reqs | 11400.4 |

修改后使用同一 benchmark 复测，并再跑一次确认。确认 run 的 llhttp rows：

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 1298.0 | 1208.7 |
| 10 headers | 4704.7 | 3952.9 |
| POST 1KB body | 2136.6 | 1926.7 |
| pipeline 10 reqs | 11400.4 | 10668.5 |

微基准存在抖动，但 10-header、POST、pipeline 三个与 adapter span/body/header 相关负载均显示
正向变化。simple GET 改善较小，下一步不应继续在这条小 helper 上榨，而应转向重复 lookup /
normalization 和 server ingress 判定缓存。

## Remaining gaps / risks

- 本轮只优化 URL/header field/value span append；body callback 仍按每个 body span `SetLength`
  扩展 `TBytes`，后续 body-heavy workload 可单独处理。
- `ValidateRequestTransferEncoding` 仍会 `GetAll + LowerCase + TextSplit`。transfer-coding 错误路径
  correctness 更重要，性能优化要谨慎，不应影响 security proof。
- 下一个高收益点仍是 headers-complete/server ingress 常用判定：Host、Expect、Content-Length、
  Transfer-Encoding、Connection 的重复 `Normalize + linear scan`。
