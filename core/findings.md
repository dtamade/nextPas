# Findings: HTTP headers allocation fast path

## Scope

本轮继续服务 `HttpServer 完成` 的性能路线。用户怀疑 Pascal llhttp 翻译本体可能有性能
问题；当前证据还不能直接证明状态机本体慢，上一轮子代理审计和本轮 microbenchmark 更
指向 `TH1Parser` adapter / `THttpHeaders` 的 managed allocation 成本。

因此本轮先做基础件优化：让 `THttpHeaders` 使用 `FCount + EnsureCapacity`，避免每次
`Add` 或删除都调整动态数组长度。

## Confirmed truths

### 1. llhttp vs adapter 判断

上一轮 `bench_h1parser` 已证明 fast path 快于当前 llhttp adapter：

| workload | llhttp ns/op | fast ns/op |
| --- | ---: | ---: |
| simple GET | 1111.4 | 691.3 |
| 10 headers | 4978.4 | 3753.0 |
| POST 1KB body | 2167.2 | 1442.8 |
| pipeline 10 requests | 9810.0 | 6973.5 |

Peirce 子代理只读审计结论仍成立：最高概率瓶颈不是 llhttp 状态机本体，而是 URL/header/body
span 进入 Pascal managed string / bytes 的 adapter 分配路径。

### 2. Headers baseline evidence

生产代码修改前，加入 `Add 15 headers` 场景后运行：

```sh
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

基线结果：

| workload | before ns/op |
| --- | ---: |
| Set+Get 5 headers | 1235.6 |
| Set+Get 15 headers | 3233.0 |
| Add 15 headers | 2424.4 |
| Get miss (3 headers) | 58.1 |
| Get hit (5 headers, last) | 64.7 |
| Has (3 headers) | 49.7 |
| Clone 10 headers | 725.9 |

### 3. Headers optimization evidence

`THttpHeaders` 现在保留动态数组容量，并用 `FCount` 标记有效条目。删除和 `Set_` 去重后
清理尾部 managed strings，避免 stale entries 外泄或长期持有已删除值。

同一 benchmark 修改后结果：

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 1235.6 | 924.2 |
| Set+Get 15 headers | 3233.0 | 2712.2 |
| Add 15 headers | 2424.4 | 1832.8 |
| Get miss (3 headers) | 58.1 | 53.9 |
| Get hit (5 headers, last) | 64.7 | 61.6 |
| Has (3 headers) | 49.7 | 46.0 |
| Clone 10 headers | 725.9 | 732.4 |

`Add 15 headers` 下降约 24%，直接覆盖 llhttp adapter 逐 header `Add` 路径。`Clone` 本轮不优化，
轻微波动不作为结论。

## Remaining gaps / risks

- 仍不能把性能问题归因到 llhttp Pascal 状态机本体；下一步应继续减少 adapter span copy /
  normalization / lookup，而不是先重写状态机。
- `Get/Has/GetAll` 仍会 Normalize 并线性扫描。后续可在 headers-complete 阶段缓存 Host、
  Expect、Content-Length、keep-alive 等 server ingress 常用判定，避免同一请求重复扫描。
- 正式追平 Go/Rust 仍需要全链 benchmark 轮次：更稳定的多轮采样、Hyper/Tokio comparator、
  body/chunked/router/middleware/TLS 负载，以及 threaded/epoll/backend 对照。
