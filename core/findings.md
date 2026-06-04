# Findings: HTTP header GetAll miss fast path

## Scope

本轮继续服务 `HttpServer 完成` 的性能路线，聚焦 `THttpHeaders.GetAll` missing path。server
和 parser 在常规请求上会查询 `Expect` / `Transfer-Encoding` 这类可重复 header；大多数普通
请求没有这些 header，因此 miss path 是热路径。

## Confirmed truths

### 1. Previous lookup optimization projects to parser

在本轮开始时运行：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

相对上一轮记录，llhttp rows 保持正向：

| workload | previous ns/op | current ns/op |
| --- | ---: | ---: |
| simple GET | 1208.7 | 1203.7 |
| 10 headers | 3952.9 | 4061.6 |
| POST 1KB body | 1926.7 | 1922.5 |
| pipeline 10 reqs | 10668.5 | 10602.0 |

微基准有噪声，但没有发现上一轮 header lookup fast path 带来 parser 层回退。

### 2. Existing `GetAll` miss allocated unnecessarily

旧 `GetAll` 会先：

```pascal
SetLength(Result, FCount);
```

即使没有任何匹配 header，也会分配 result array，再 `SetLength(Result, 0)`。normal no-Expect
request 会反复走到这种路径。

### 3. Header benchmark evidence

生产代码修改前：

```sh
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

修改前 rows：

| workload | before ns/op |
| --- | ---: |
| GetAll miss (5 headers) | 136.9 |

修改后 confirmation run：

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| GetAll miss (5 headers) | 136.9 | 60.6 |
| Get miss (3 headers) | 55.5 | 54.5 |
| Get hit (5 headers, last) | 47.0 | 45.5 |

`GetAll` missing path 下降约 56%。`Has` 单次 confirmation 有噪声，本轮不把它作为结论。

### 4. Parser projection evidence

修改后运行：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

相对本轮开始的 parser check：

| llhttp workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 1203.7 | 1094.1 |
| 10 headers | 4061.6 | 3905.8 |
| POST 1KB body | 1922.5 | 1867.3 |
| pipeline 10 reqs | 10602.0 | 10096.6 |

这说明 no-TE / no-Expect 的 missing `GetAll` 优化确实投射到 parser benchmark。

## Remaining gaps / risks

- `GetAll` hit path 现在是两遍扫描；这对 rare repeated headers 可以接受。若后续 `Expect`
  或 `Transfer-Encoding` hit-heavy workload 重要，再单独 benchmark。
- server ingress 仍会重复解析 `Expect` token；下一步可考虑 request metadata cache，但要先用
  focused tests 锁住 duplicate/unsupported `Expect` 语义。
- uppercase fallback 仍比 lowercase hot path 慢；这是上一轮已记录 tradeoff。
