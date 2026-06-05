# Findings: H1 server URL-path benchmark correlation

## Scope

本轮是 benchmark/correlation 强化，不改变 public HTTP API，不改变 wire
contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

三方 server comparator 现在支持同一个 workload selector：

```text
--workload no_url
--workload url_path
```

`url_path` 语义：

- nextPas client 发送 `GET /api/v1/users`，handler 读取 `AReq.Url.Path` 并校验。
- Go comparator 发送同一路径，handler 读取 `request.URL.Path` 并校验。
- Rust std-only comparator 发送同一路径，并在同一个 buffered request frame 内校验
  `GET /api/v1/users ` 前缀后再响应。
- `run_server_comparison.sh` 负责校验并下传 workload，输出也包含
  `workload=<value>`。

## Bug caught during GREEN

Rust comparator 的初版 `url_path` 分支先用 `read_one_request` 消费掉当前
request，又在一个新 buffer 上调用 `read_one_request_with_path`。这会导致 server
等待第二个 request 才响应，benchmark 语义错误。

修正后只保留一个 `read_one_request_matches_workload`，一次读取、一次判定、一次
响应。

## Performance evidence

Fresh local row:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload url_path

nextPas url_path: 79527 req/s, 12574 ns/op
Go net/http url_path: 19019 req/s, 52576 ns/op
Rust std-only url_path: 113158 req/s, 8837 ns/op
```

对比上一批 `no_url` 50k/4 row：

```text
nextPas no_url: 77958 req/s, 12827 ns/op
Go net/http no_url: 18871 req/s, 52990 ns/op
Rust std-only no_url: 98422 req/s, 10160 ns/op
```

结论：`url_path` 没有把 nextPas 拉出既有噪声带，也没有显示 URL projection 是主要
瓶颈。nextPas 仍快于 Go comparator，仍慢于 Rust std-only comparator。

## Verification evidence

Focused gate:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

17 total, 17 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Earlier RED / intermediate failure:

```text
17 total, 13 passed, 4 failed
heaptrc: 0 unfreed memory blocks
```

失败点用于证明新增 `url_path` contract 有效：实现或测试 helper 仍停留在
`workload=no_url` 时会失败。

## Direction review

方向没有走偏：本轮没有在没有证据的情况下直接手改 Pascal 翻译版 llhttp。已有 raw
parser 证据说明 Pascal translated llhttp 相对 C llhttp 有代表性差距，但本轮
full-chain `url_path` workload 仍走 H1 fast path，不能把 server 吞吐差距直接归咎到
llhttp。

## Remaining gaps / risks

- 还缺 forced-adapter workload，用来让 server full-chain 明确走 llhttp adapter path。
- Rust comparator 仍是 std-only microbaseline，不代表 Hyper/Tokio 生态性能。
- 本机 benchmark 仍有调度噪声；正式性能结论需要多轮 snapshot 或更稳定 runner。
- 如果要优化 translated llhttp，下一步应先拿 C/Pascal narrowed benchmark 与硬件计数器，
  再决定是否改 generator/codegen 或转换表结构。
