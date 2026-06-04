# Progress Log: HTTP parser body buffer reuse

## Session

- **Scope:** `TH1Parser` body capacity reuse + Reset/body snapshot guard。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser adapter allocation reduction`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP parser/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- `API_COVERAGE.md` 本轮不改：没有公开 API 扩展。
- `gpt-5.5 xhigh` 只读子代理已复核 llhttp 性能归因：当前主瓶颈证据仍指向 adapter materialization；
  若要严格判断 Pascal 翻译本体，需要补 C llhttp comparator。

## Completed work

- `TestResetAndReparse` 增强为 body-focused guard：Reset 后更短 body 不串旧字节，旧 body reader 仍是快照。
- `TH1Parser` 新增 `FBodySize`，`FBody` 从 effective-size array 改为 reusable capacity buffer。
- `CbOnBody` 改为 capacity append，避免 repeated parse/body path 每次按有效长度重分配。
- `GetBody` / `GetBodySize` 只读取有效长度。
- `NewBodyReader` 复制有效区间，保留 Reset/reparse 后的 reader snapshot 语义。

## Verification

- Focused tests:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - `make -C benchmarks/nextpas.core.http/bench_h1parser run`
  - confirmation llhttp adapter:
    - `simple GET`: `644.2 ns/op`
    - `10 headers`: `3333.1 ns/op`
    - `POST 1KB body`: `1404.6 ns/op`
    - `pipeline 10 reqs`: `6206.8 ns/op`

## Current conclusion

本轮方向没有走偏：继续沿 adapter materialization 降本，而不是先大改 runtime。收益边界也必须说清楚：
body buffer reuse 对 POST body workload 有小幅正向投射；对 no-body/pipeline 不应期待明显收益。

## Next step

- 等待并吸收 `gpt-5.5 xhigh` 子代理关于 Pascal translated llhttp comparator 的只读审视。
- 下一批优先做 header/value materialization 或 server ingress metadata cache。
- 若要回答“llhttp Pascal 翻译是否性能有问题”，必须补 C llhttp comparator；当前只能根据 raw no-callback rows
  判断它不是 nextPas 当前 H1 parser stack 内的主瓶颈。
