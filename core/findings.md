# Findings: H1 server forced-adapter benchmark correlation

## Scope

本轮是 benchmark/correlation 强化，不改变 public HTTP API，不改变 wire
contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

三方 server comparator 现在支持同一个 workload selector：

```text
--workload no_url
--workload url_path
--workload adapter_no_url
```

`adapter_no_url` 语义：

- nextPas client 发送 `GET /`，并带 `Connection: keep-alive` 与
  `Content-Length: 0`。
- nextPas H1 server 因 `HasConnection` 拒绝 fast path，转入 llhttp adapter path。
- Go comparator 仍用 `net/http`，在该 workload 下通过 request header 设置
  `Connection: keep-alive`。
- Rust std-only comparator 发送同一类 raw request，handler 不做 URL path 检查。
- `run_server_comparison.sh` 负责校验并下传 workload，输出也包含
  `workload=<value>`。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

18 total, 17 passed, 1 failed
server comparison runner adapter_no_url small smoke failed:
--workload must be no_url or url_path
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

18 total, 18 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local row:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload adapter_no_url

nextPas adapter_no_url: 78828 req/s, 12685 ns/op
Go net/http adapter_no_url: 17294 req/s, 57822 ns/op
Rust std-only adapter_no_url: 95806 req/s, 10437 ns/op
```

对比最近两条 full-chain rows：

```text
nextPas no_url: 77958 req/s, 12827 ns/op
nextPas url_path: 79527 req/s, 12574 ns/op
nextPas adapter_no_url: 78828 req/s, 12685 ns/op
```

结论：forced-adapter no-URL row 没有把 nextPas 拉出既有本机噪声带，也没有显示
fast path 是 full-chain throughput 的唯一关键因素。nextPas 仍快于 Go comparator，
仍慢于 Rust std-only comparator。

## Direction review

方向没有走偏：本轮按证据把 full-chain workload 拆到 forced-adapter，而不是直接手改
Pascal translated llhttp。已有 raw parser 证据说明 Pascal translated llhttp 相对 C
llhttp 有代表性差距，但 full-chain forced-adapter row 指向更复杂的成本构成：
adapter materialization、response writer/drain、runtime/socket handoff、request
dispatch 都需要继续拆。

## Remaining gaps / risks

- `adapter_no_url` 只证明带 `Connection` header 的 no-body path 进入 adapter；
  还没有拆分 adapter 内 header materialization、request construction、response drain
  的占比。
- Rust comparator 仍是 std-only microbaseline，不代表 Hyper/Tokio 生态性能。
- 本机 benchmark 仍有调度噪声；正式性能结论需要多轮 snapshot 或更稳定 runner。
- 如果要优化 translated llhttp，下一步应先拿 C/Pascal narrowed benchmark 与硬件计数器，
  再决定是否改 generator/codegen 或转换表结构。
