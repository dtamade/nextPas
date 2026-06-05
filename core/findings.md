# Findings: C llhttp comparator proof track

## Scope

本轮是 `nextpas.core.http` 的 H1 parser performance proof slice，不改公开 API，不改
生产 HTTP wire contract。目标是回答用户指出的核心疑点：Pascal translated llhttp
是否比 C llhttp 慢，以及当前优化路线是否应继续优先处理 adapter/materialization。

## RED evidence

上一阶段进入本批时，C comparator 入口不存在：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c run
```

结果是目录/目标缺失。这证明当前仓库还不能直接做 Pascal translated llhttp 与 C
llhttp 的 same-payload 对照。

## Comparator design

新增 `benchmarks/nextpas.core.http/bench_h1parser/compare_c`：

- 不 vendor llhttp 源码。
- 使用 `LLHTTP_ROOT` 指向外部 llhttp `9.4.1` source tree。
- 支持 flat source layout、`include/src` layout、以及 generated build layout。
- 镜像 Pascal `bench_h1parser` 的 payload：
  - simple GET：35 bytes
  - 10 headers：286 bytes
  - POST 1KB：1130 bytes
  - pipeline：350 bytes，10 requests
- 镜像 raw/no-op/pipeline rows：
  - raw no callbacks：simple GET、10 headers、POST 1KB
  - raw pipeline pause-only
  - no-op callbacks：simple GET、10 headers、POST 1KB、pipeline

`test_http_benchmarks` 现在直接锁住两条 benchmark contract：

- missing `LLHTTP_ROOT` 必须给出清晰 diagnostic。
- 设置 `NEXTPAS_LLHTTP_ROOT` 时会 opt-in 跑真实 C comparator smoke，并校验标题、
  llhttp version 与代表性 rows。

## Fresh local evidence

本机 llhttp source：

```text
LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
version=9.4.1
```

Pascal translated llhttp / adapter：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| workload | Pascal translated raw ns/op | Pascal no-op ns/op | nextPas adapter ns/op |
| --- | ---: | ---: | ---: |
| simple GET | 222.0 | 221.5 | 623.0 |
| 10 headers | 779.5 | 785.7 | 3341.4 |
| POST 1KB | 437.1 | 454.5 | 1429.1 |
| pipeline 10 reqs | 2203.0 | 2159.2 | 6273.4 |

C llhttp `9.4.1`:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c \
  clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
```

| workload | C raw ns/op | C no-op ns/op |
| --- | ---: | ---: |
| simple GET | 279.4 | 138.2 |
| 10 headers | 561.5 | 544.7 |
| POST 1KB | 299.1 | 283.4 |
| pipeline 10 reqs | 1408.2 | 1401.7 |

## Interpretation

- raw simple GET 是极短输入，当前 `MAX_ITERS=1000` 下噪声敏感；这次 fresh run 里
  Pascal raw simple GET 反而快于 C raw simple GET，不能拿这一行单独下 parity 结论。
- 10 headers、POST 1KB、pipeline 与 no-op callback rows 更能代表实际 parser 工作；
  这些行显示 Pascal translated llhttp 相比 C llhttp 通常慢约 `1.4x-1.6x`。
- nextPas 完整 `IH1Parser` adapter 仍是更大的栈内成本：
  - 10 headers adapter/C raw 约 `5.95x`
  - POST 1KB adapter/C raw 约 `4.78x`
  - pipeline adapter/C raw 约 `4.46x`
  - simple GET adapter/C raw 约 `2.23x`
- 因此用户的怀疑是有依据的：Pascal llhttp translation 需要进入性能路线。
  但最高收益不应只盯 state machine；adapter/header/body materialization 与 server
  hot path 仍然是更大的优化池。

## Remaining gaps / risks

- 当前 C comparator 是本机 directional benchmark，不是跨平台永久排名。
- comparator 依赖外部 `LLHTTP_ROOT`，测试中的真实 C run 是 opt-in，避免仓库 vendor
  或强制依赖外部源码。
- `MAX_ITERS=1000` 对短输入噪声仍偏高，后续正式 benchmark 轮次应提升 runner 统计质量。
- 如果要继续追平 Go/Rust，应把优化路线分为：
  1. C/Pascal state machine parity。
  2. adapter materialization / header storage / body buffer / callback span cost。
  3. server full-chain worker handoff、drain、keep-alive 与 future evented backend。

## Next optimization targets

1. 先把 benchmark runner 的统计质量提高：更高 cap、可配置 iterations、报告环境和 commit。
2. 深挖 Pascal translated llhttp 热点：record layout、callback cdecl 成本、branch/cache locality、
   bounds/string conversion、可能的 generated-table/inline 策略。
3. 并行继续削 adapter/materialization：header insert/lookup、body reader snapshot、
   URL/header span zero-copy、request object reuse。
