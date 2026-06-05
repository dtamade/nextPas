# Progress Log: C llhttp comparator proof track

## Session

- **Scope:** H1 parser C llhttp comparator and benchmark smoke coverage.
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser C parity proof`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP
  benchmark/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public API 变化，只有 benchmark harness
  与 smoke 覆盖。
- 本轮不跑全量测试；只跑 benchmark comparator 与 `test_http_benchmarks` focused gate。

## Completed work

- 新增 `bench_h1parser/compare_c` C llhttp comparator。
- 父级 `bench_h1parser` Makefile 增加 `run-c`，统一从 parser benchmark 入口代理。
- `test_http_benchmarks` 增加 missing `LLHTTP_ROOT` diagnostic smoke。
- `test_http_benchmarks` 增加 `NEXTPAS_LLHTTP_ROOT` opt-in C comparator smoke。
- 本机确认外部 llhttp source 是 `9.4.1`：
  `/home/dtamade/projects/fafafa.ccore/third_party/llhttp`。
- fresh 跑 Pascal translated llhttp / adapter benchmark。
- fresh 跑 C llhttp comparator benchmark。

## Verification so far

- llhttp source version:
  - `rg -n "LLHTTP_VERSION_(MAJOR|MINOR|PATCH)" /home/dtamade/projects/fafafa.ccore/third_party/llhttp/llhttp.h`
  - result: `9.4.1`
- Pascal benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - exit: `0`
  - representative rows:
    - Pascal raw simple GET: `222.0 ns/op`
    - Pascal raw 10 headers: `779.5 ns/op`
    - Pascal raw POST 1KB: `437.1 ns/op`
    - Pascal raw pipeline: `2203.0 ns/op`
    - adapter simple GET: `623.0 ns/op`
    - adapter 10 headers: `3341.4 ns/op`
    - adapter POST 1KB: `1429.1 ns/op`
    - adapter pipeline: `6273.4 ns/op`
- C comparator:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - exit: `0`
  - representative rows:
    - C raw simple GET: `279.4 ns/op`
    - C raw 10 headers: `561.5 ns/op`
    - C raw POST 1KB: `299.1 ns/op`
    - C raw pipeline: `1408.2 ns/op`
    - C no-op simple GET: `138.2 ns/op`
    - C no-op 10 headers: `544.7 ns/op`
    - C no-op POST 1KB: `283.4 ns/op`
    - C no-op pipeline: `1401.7 ns/op`
- Diff check:
  - `git diff --check -- benchmarks/nextpas.core.http/bench_h1parser tests/nextpas.core.http/test_http_benchmarks docs/http/BENCHMARKS.md task_plan.md findings.md progress.md`
  - exit: `0`
- Parent C comparator target:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser run-c LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - exit: `0`
  - output confirms llhttp `9.4.1` and matching payload sizes.
- Focused benchmark test gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `7 total, 7 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

方向没有走偏：本轮没有把性能怀疑直接变成大重构，而是先补同 payload C comparator。
证据显示 Pascal translated llhttp 在更有代表性的 10 headers、POST、pipeline/no-op rows
上确实慢于 C llhttp；但 nextPas adapter/materialization 仍是更大的成本池。

## Remaining work before commit

- path-limited commit。

## Next step

- 下一批不要再扩同型 benchmark 文档；应开始收敛性能路线：
  benchmark runner 统计质量、Pascal llhttp translation hotspot、adapter/materialization 三线择优。
