# Findings: H1 parser adapter materialization breakdown

## Scope

本轮只改 H1 parser benchmark 与 benchmark smoke，不改 HTTP public facade API，不改 wire
contract。目标是拆分 full `IH1Parser` adapter 相比 raw/no-op llhttp 的额外成本。

## Subagent / local conclusion

- Pascal translated llhttp raw 本体相比 C llhttp 有真实差距，代表性 raw/no-op rows 约
  `1.4x-1.6x`。
- 但 full adapter 明显更慢，当前更大的可控成本在 URL/header/body materialization。
- 巨型 llhttp 翻译状态机不适合手工直接改；如果 raw gap 后续仍稳定，应走 profile/codegen
  A/B，而不是手写 patch。

## RED evidence

新增 focused smoke 后先跑：

```sh
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
```

失败点：

- `adapter cost: span append 10 headers`
- `adapter cost: header add 10 headers`
- `adapter cost: body copy 1KB`

实际输出仍只有 raw/no-op/full adapter/fast rows，证明 benchmark 还不能拆分 adapter 成本。

## Implemented change

- `bench_h1parser` 新增 `adapter materialization costs` 分组。
- 新增 synthetic rows：
  - `adapter cost: span append 10 headers`
  - `adapter cost: header add 10 headers`
  - `adapter cost: body copy 1KB`
- `test_http_benchmarks` 的 H1 parser smoke 现在检查这些 rows，防止后续误删。

## Verification

- Focused benchmark gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

中间错误：

- 第一次 GREEN build 失败：`Identifier not found "TBytes"`。
- 修复：benchmark 程序引入 `nextpas.core.base`。

## Benchmark sanity

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Evidence:

- `bench_max_iters=100000`
- raw translated llhttp 10 headers: `753.6 ns/op`
- no-op callback 10 headers: `786.6 ns/op`
- adapter span append 10 headers: `801.1 ns/op`
- adapter header add 10 headers: `1220.9 ns/op`
- adapter body copy 1KB: `33.1 ns/op`
- full llhttp adapter 10 headers: `3378.2 ns/op`
- fast 10 headers: `1381.5 ns/op`

## Current conclusion

方向没有走偏：本轮是 performance 阶段的证据拆分，不改变接口或 wire contract。它服务于后续
把 nextPas HTTP 追到 Go/Rust 标准的真实优化，不再扩大同型 correctness 测试。

breakdown 结论很明确：body copy 不是当前主要问题；10 headers 的 full adapter 成本主要由
header string append 和 `THttpHeaders.Add` 叠加形成。下一批生产优化应优先减少普通路径的
header materialization，而不是优先动 body copy 或手改 llhttp 状态机。

## Remaining gaps / risks

- breakdown rows 是 synthetic microbench，不代表完整 server throughput。
- 如果后续做 zero-copy/lazy span，必须处理 llhttp callback span 指向输入 buffer 的生命周期。
- 本轮不声明生产吞吐提升。
