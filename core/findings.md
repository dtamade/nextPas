# Findings: HTTP header lookup exact fast path

## Scope

本轮继续服务 `HttpServer 完成` 的性能路线，聚焦 `THttpHeaders.Get/Has`。server ingress 和
parser adapter 常用 lookup key 已经是小写形式，例如 `host`、`content-length`、`connection`。
旧实现每次 `Get/Has` 都先 normalize 查询名，再扫描 entries。

## Confirmed truths

### 1. Lowercase lookup is the hot path

HTTP server 侧典型调用包括：

- `AParser.GetHeaders.Get('content-length')`
- `AParser.GetHeaders.Get('transfer-encoding')`
- `AParser.GetHeaders.GetAll('expect')`
- `FParser.GetHeaders.Get('host')`
- fast path gating 里的 `host`、`connection`、`expect`、`transfer-encoding`

这些 key 都是小写。public API 仍要求大小写不敏感，因此 uppercase fallback 不能移除。

### 2. Behavior guard

`test_http_headers` 的 `Has returns true/false` 现在额外覆盖 `LH.Has('X-PRESENT')`，继续锁住
uppercase public lookup 语义。

### 3. Header benchmark evidence

生产代码修改前：

```sh
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

修改前 rows：

| workload | before ns/op |
| --- | ---: |
| Set+Get 5 headers | 1404.5 |
| Set+Get 15 headers | 3420.0 |
| Add 15 headers | 2064.0 |
| Get miss (3 headers) | 58.8 |
| Get hit (5 headers, last) | 68.6 |
| Get hit uppercase (5 headers, last) | 122.8 |
| Has (3 headers) | 53.3 |
| Clone 10 headers | 752.3 |

修改后 confirmation run：

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 1404.5 | 928.0 |
| Set+Get 15 headers | 3420.0 | 2665.6 |
| Add 15 headers | 2064.0 | 1775.8 |
| Get miss (3 headers) | 58.8 | 55.6 |
| Get hit (5 headers, last) | 68.6 | 46.6 |
| Get hit uppercase (5 headers, last) | 122.8 | 149.7 |
| Has (3 headers) | 53.3 | 25.1 |
| Clone 10 headers | 752.3 | 723.9 |

小写 lookup hot path 改善明显；uppercase public lookup 变慢，这是本轮有意接受的 tradeoff，因为
server/adapter 内部热路径走小写 key。若后续发现外部 uppercase-heavy workload 是真实瓶颈，可再
用单独策略优化 fallback。

## Remaining gaps / risks

- `GetAll` 仍总是 normalize 并分配 result array；`Expect` 和 `Transfer-Encoding` 相关路径仍有
  `GetAll + split/lowercase` 成本。
- server ingress 仍在多个阶段重复查询同一批 headers；下一步更高收益可能是 request metadata
  cache，而不是继续微调 `FindFirst`。
- uppercase fallback 性能下降已记录；这不是 correctness 风险，但需要在后续公开 API benchmark
  中持续观察。
