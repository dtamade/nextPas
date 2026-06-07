# Historical Findings: HTTP H1 Performance Work

## 2026-06-06 comparator scale validation slice

- 本轮继续收紧 benchmark truth 的输入契约：
  runner 已经拒绝非正 `--requests` / `--threads`，但四个单体 comparator 仍会把
  `0` 静默夹到 `1` 或回落默认值，并继续输出正常 benchmark row。
- 选择依据：
  - 这和 earlier invalid workload fallback 属于同类 evidence 污染：调用方输入错了，
    却得到一条看似成功的 row。
  - 手工 smoke、局部 profile、或保存单体 comparator 输出时，并不总会经过 runner。
  - 只收紧 CLI fail-fast，不改变 valid scale 的 benchmark 行为。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `49 total, 45 passed, 4 failed`
    - failed at `bench_server rejects invalid scale`
    - failed at `go server comparator rejects invalid scale`
    - failed at `rust server comparator rejects invalid scale`
    - failed at `hyper/tokio server comparator rejects invalid scale`
    - failures all emitted successful benchmark rows despite `--requests 0` or
      `--threads 0`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - nextPas `bench_server` now rejects invalid positive options in `ParseOptions`.
  - Go comparator exits with `invalid --requests` / `invalid --threads`.
  - Rust std-only and Hyper/Tokio comparators exit with the same diagnostics.
  - focused gate also locks that invalid scale runs do not emit
    `operation=http.server.keepalive`.
- 复盘结论：
  single-implementation comparator binaries 现在不会把 invalid scale 输入伪装成成功
  benchmark row。后续 benchmark truth 仍应优先补输入契约、metadata 和 artifact
  boundary，而不是直接追加数字。

## 2026-06-06 h1 parser operation marker slice

- 本轮继续收紧 parser benchmark metadata contract：
  `bench_h1parser` 和外部 C llhttp comparator 已经有 title、`bench_max_iters`、
  `bench_filter` 等文本信息，但 focused smoke 还没有锁住稳定 `operation=` marker。
- 选择依据：
  - parser benchmark 现在不仅被人直接运行，也会被 filter、flag matrix、保存 raw
    output、后续 snapshot/parser 工具消费。
  - 只靠 `=== ... ===` 标题区分工具不够稳；machine-readable marker 更适合 runner
    和证据收集链路。
  - 这是 benchmark truth slice，不改变 row schema、性能数字、HTTP runtime 或
    public API。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `49 total, 47 passed, 2 failed`
    - failed at `H1 parser benchmark max iterations env`
    - failed at `C llhttp comparator max iterations env when configured`
    - failures: missing `operation=http.h1parser` and
      `operation=http.h1parser.c_llhttp`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `bench_h1parser` now emits `operation=http.h1parser`.
  - `bench_h1parser/compare_c` now emits `operation=http.h1parser.c_llhttp`.
  - focused gate locks both markers alongside the existing `bench_max_iters`
    smoke.
- 复盘结论：
  parser benchmark 与 C comparator 现在和 server/header/writer/outbound/fullchain
  benchmark 一样有稳定 operation marker。后续若再加 snapshot/runner 机器消费逻辑，
  应优先复用这些 marker，而不是重新解析标题文本。

## 2026-06-06 benchmark inventory cleanup slice

- 本轮不是新增 benchmark，而是清理 HTTP benchmark lane 内一个遗留孤岛资产：
  `benchmarks/nextpas.core.http/bench_http/bench_http.lpr`。
- 选择依据：
  - 它是 HTTP benchmark 目录下唯一没有 project `Makefile` 的顶层 Pascal benchmark
    project。
  - 它输出的是旧式自由文本，没有 `operation=` / `bench_filter=` / `iterations`
    等稳定 metadata contract。
  - 它把 router / URL / header 三类 microbenchmark 混在一个聚合程序里，而这些面
    现在都已有更窄、更可比较、带 focused gate 的专门 benchmark 资产。
  - 在当前 benchmark truth 主线下，继续维护这个聚合 bench 只会制造第二套不受约束
    的数字入口。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - 新增 inventory contract 后，唯一新失败是
      `HTTP top-level Pascal benchmark projects have Makefiles`
    - failure: `top-level HTTP Pascal benchmark projects missing Makefile: expected "", got "bench_http"`
- GREEN / behavior 证据：
  - 删除 `bench_http` 遗留聚合 benchmark。
  - `test_http_benchmarks` 改为锁定：HTTP 顶层 Pascal benchmark project 不再存在
    无 `Makefile` 的孤岛资产。
- 复盘结论：
  benchmark truth 不只是“更多 benchmark”；也包括主动移除不再受维护契约约束的旧入口。
  当前 HTTP benchmark 公开资产以 focused projects + comparator runners 为准。

## 2026-06-06 header benchmark smoke marker slice

- 本轮收紧 header microbenchmark evidence：
  `bench_headers` 已有多个 header container rows，并且历史优化记录多次引用它，
  但 `test_http_benchmarks` 没有 smoke 该 benchmark，且 benchmark 输出缺少
  stable `operation=` marker。
- 选择依据：
  - Header lookup 是 H1 parser metadata、server policy、client/server header handling
    的基础热路径。
  - 这个 slice 把已有 benchmark 资产纳入 focused gate，比继续追加同型 correctness
    case 更符合 performance evidence 主线。
  - 只补 marker 和 smoke，不改变 `THttpHeaders` 实现或 public contract。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `45 total, 44 passed, 1 failed`
    - failed at `bench_headers lookup smoke`
    - failure: missing `operation=http.headers`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `bench_headers` now emits `operation=http.headers`.
  - focused smoke locks `NEXTPAS_BENCH_FILTER=Get hit`, lowercase `Get hit`
    row, uppercase `Get hit uppercase` row, `bench_filter`, `ns/op`, and `ops/s`.
- 复盘结论：
  header benchmark 现在和 router/writer/outbound microbenchmarks 一样有 stable
  operation marker 和 focused gate coverage。后续 header 性能 slice 可以依赖这个
  gate，但不能把单次 row 当成持久性能排名。

## 2026-06-06 snapshot raw cleanup slice

- 本轮收紧 benchmark snapshot helper 的 artifact hygiene：
  `capture_server_comparison_snapshot.sh` 会把 runner 输出先写入
  `${OUTPUT_PATH}.raw`，再嵌入 Markdown snapshot。旧实现成功后保留该 raw 文件，
  容易让 build tree 留下不该提交的临时 benchmark 输出。
- 选择依据：
  - benchmark truth 不只依赖 row schema，也依赖 evidence capture 的可维护性和
    artifact boundary。
  - `.md` snapshot 已包含 raw comparison output；相邻 `.raw` 文件只是实现临时文件，
    不应成为第二个需要人工清理的产物。
  - 这是 harness cleanup，不触碰 HTTP runtime、public API、comparator workload 或
    Hyper/Tokio dependency set。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `44 total, 43 passed, 1 failed`
    - failed at `server comparison snapshot small smoke`
    - failure: `server comparison snapshot raw temp file should be removed`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - snapshot helper 现在用 `trap cleanup EXIT` 删除 `${OUTPUT_PATH}.raw`。
  - Markdown snapshot 仍保留 `## Raw Comparison Output`，runner stdout/report schema
    不变。
- 复盘结论：
  snapshot helper 现在只留下 durable Markdown snapshot，不再在成功路径残留临时 raw
  capture。后续 benchmark evidence slice 应继续优先收紧可复现参数和 artifact
  boundary，而不是追加裸数字。

## 2026-06-06 http response body release helper slice

- 本轮转向 client response body ownership：
  redirect/download 内部已经有 close/drain 语义，但普通调用方拿到
  `IHttpResponse` 后，如果选择不读取 `Body`，没有稳定 public helper 可释放 body。
  直接要求调用方探测 `IReadCloser` / `ICloser` / `IStream` 会把 transport/body
  implementation detail 暴露到应用代码。
- 选择依据：
  - Go/Rust 生态都强调 response body 未消费时也要显式 release / discard，避免资源泄漏
    或阻碍连接复用。
  - 公开 `HttpReleaseResponseBody` 是小 surface：只复用已有内部 release 语义，不新增
    request builder、streaming response API 或 H1 transport contract。
  - 不把 close 行为隐式加入 `HttpReadResponseBodyString` /
    `HttpReadResponseBodyBytes`，避免改变已落地的 read-all helper contract。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - compile failed at four missing call sites:
      `Identifier not found "HttpReleaseResponseBody"`
- GREEN / behavior 证据：
  - `HttpReleaseResponseBody(nil)` 抛 `EArgumentError`。
  - nil body no-op。
  - close-capable body 走 close。
  - plain `IReader` body drain 到 EOF。
  - facade `nextpas.core.http.HttpReleaseResponseBody` 转发同一 helper。
- 复盘结论：
  client response body ownership 现在有三个清晰路径：调用方读取 bytes/string、download
  helper 代为消费并释放、或者调用 `HttpReleaseResponseBody` 显式丢弃/释放。后续若继续
  response body 方向，应设计 streaming lifetime 或 close-on-read policy，不要偷偷改变
  既有 read-all helper。

## 2026-06-06 runner include-hyper marker slice

- 本轮继续收紧 comparison report header：
  runner raw output 已有 `comparison`、`requests`、`threads`、`workload`、`runs`，
  但缺 `include_hyper`。保存 report 后，调用方只能从后续是否出现
  `section=rust_hyper` / `summary_impl=rust_hyper` 推断当时是否请求了 Hyper/Tokio
  comparator。
- 选择依据：
  - 这是 benchmark evidence metadata，不改变任何 comparator row 或 summary
    解析。
  - snapshot helper 已经记录 `include_hyper=`，runner raw report 也应有同一
    参数 truth。
  - marker 位于 header，便于 grep/脚本消费。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `44 total, 43 passed, 1 failed`
    - failed at `server comparison runner include hyper smoke`
    - failure: missing `include_hyper=1`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `run_server_comparison.sh` header 现在输出 `include_hyper=0|1`。
  - include-hyper smoke 锁住 stdout 和 saved report 都包含 `include_hyper=1`。
- 复盘结论：
  server comparison report 现在能直接说明是否请求 Hyper/Tokio comparator。后续
  benchmark truth 可继续补 runner/snapshot 的 parameter metadata，但不应改变已经
  稳定的 row schema。

## 2026-06-06 hyper snapshot cargo metadata slice

- 本轮继续收紧 Hyper/Tokio comparator 的环境证据：
  snapshot 已记录 `rustc_version`，但 include-hyper 路径实际还依赖 Cargo 和
  `compare_hyper/Cargo.lock` 锁定的 dependency set。没有这些 marker，后续
  Hyper/Tokio row 的复现信息弱于 Go / Rust std-only row。
- 选择依据：
  - Hyper comparator 是 Cargo-based；Cargo 版本和 lockfile hash 是比裸
    `rustc_version` 更接近真实环境的最小补充。
  - 这是 snapshot evidence，不改变 comparator 代码、依赖版本或 runner 输出格式。
  - hash 只记录已追踪 `Cargo.lock`，不提交任何 build/cargo target 产物。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `44 total, 43 passed, 1 failed`
    - failed at `server comparison snapshot include hyper smoke`
    - failure: missing `cargo_version=`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - snapshot helper 现在记录 `cargo_version=<cargo --version|unknown>`。
  - snapshot helper 现在记录
    `hyper_cargo_lock_sha256=<sha256(compare_hyper/Cargo.lock)|unknown>`。
  - include-hyper snapshot smoke 锁住这两个 marker 与 `rust_hyper` row 同时出现。
- 复盘结论：
  Hyper/Tokio benchmark snapshot 的环境块现在包含 Cargo toolchain 与 locked
  dependency set 指纹。后续若继续 Rust comparator truth，应考虑记录 Cargo package
  versions 或确保 snapshot 可同时覆盖 `--include-hyper + --workload response_1k`。

## 2026-06-06 snapshot workload propagation slice

- 本轮继续收紧 benchmark evidence capture：
  `run_server_comparison.sh` 已能选择 `no_url` / `url_path` /
  `adapter_no_url` / `response_1k`，但 snapshot helper 只能捕获默认
  `no_url`。这使得 docs 里的 non-default workload 证据难以通过带环境元数据的
  Markdown snapshot 复现。
- 选择依据：
  - snapshot 是长期性能证据入口，应该能记录同一个 runner 支持的 workload。
  - 这是 benchmark harness truth，不触碰 HTTP public API、server runtime 或
    comparator 输出格式。
  - 默认 snapshot 行为保持兼容；只有显式 `--workload` 时才在 command block 中展示。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `44 total, 43 passed, 1 failed`
    - failed at `server comparison snapshot url_path smoke`
    - failure: `unknown argument: --workload`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - snapshot helper 新增 `--workload no_url|url_path|adapter_no_url|response_1k`。
  - 非法 workload 走与 runner 相同的 allow-list validation。
  - 显式 workload 会透传到 runner，并写入 snapshot environment `workload=...`
    和 command block。
- 复盘结论：
  现在可以用 snapshot helper 捕获 non-default workload 的环境化证据。下一步若继续
  benchmark truth，应优先让 snapshot 覆盖 `--include-hyper + --workload` 的组合或
  记录 Cargo/Hyper dependency versions，而不是只追加裸 benchmark 数字。

## 2026-06-06 comparator workload validation slice

- 本轮转向 benchmark truth 的输入契约：
  `run_server_comparison.sh` 已经拒绝非法 `--workload`，但四个单体 comparator
  仍会把拼错的 workload 静默 fallback 到 `no_url`。这会让手工 smoke 或后续报告
  捕获出一条真实完成的 `workload=no_url` row，从而掩盖调用方原本想测的 workload
  并污染性能证据。
- 选择依据：
  - 这是 benchmark harness correctness，不是新增 public HTTP API。
  - Go/Rust/Hyper comparator 的价值在于提供可信对照；显式输入错误必须 fail-fast，
    否则 Rust std-only / Hyper rows 再清晰也可能被错误 workload 污染。
  - runner 已经有 allow-list，本轮只让单体 comparator 与 runner 契约一致。
- RED 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `43 total, 39 passed, 4 failed`
    - failed at `bench_server rejects invalid workload`
    - failed at `go server comparator rejects invalid workload`
    - failed at `rust server comparator rejects invalid workload`
    - failed at `hyper/tokio server comparator rejects invalid workload`
    - 四条失败输出都包含成功的 `workload=no_url` benchmark row
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - nextPas `bench_server` 对非法 workload `Halt(2)`。
  - Go comparator 对非法 workload `os.Exit(2)`。
  - Rust std-only / Hyper comparator 对非法 workload `std::process::exit(2)`。
  - 四者都输出 `invalid --workload` 和相同 workload allow-list。
- 复盘结论：
  benchmark comparator 现在不会因 workload 拼写错误生成误导性 `no_url` 行。后续
  benchmark truth 更高价值方向是继续加强 snapshot/runner 的参数透传和环境元数据，
  或补更完整的 Hyper/Tokio workload，而不是新增未验证的性能排名。

## 2026-06-06 http download body release slice

- 本轮收紧 client download helper 的 response body ownership：
  `HttpGetToWriter` / `HttpGetToFile` 旧实现会消费成功响应体、丢弃非 2xx 响应体，
  但没有在 helper 边界释放 close-capable body。调用方拿不到 response，因此也无法
  自己 close。
- 选择依据：
  - Go/Rust 生态里代替调用方消费 response body 的 helper 应同时负责释放资源。
  - 这属于 client helper 错误/资源语义，不是新增 builder、transport vtable 或 H1
    runtime 改造。
  - redirect 路径已经有 close/drain release 语义，可以复用同一内部 contract。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `55 total, 52 passed, 3 failed`
    - failed at `HttpGetToWriter closes body after successful copy`
    - failed at `HttpGetToWriter closes body when copy fails`
    - failed at `HttpGetToWriter closes non-2xx body before raising`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `ReleaseRedirectResponseBody` 泛化为 `ReleaseResponseBody`。
  - redirect 路径继续复用同一 release helper。
  - `HttpGetToWriter` / `HttpGetToFile` 现在在 successful copy、copy failure、
    non-2xx rejection、temp-file failure 等路径通过 `finally` 释放 response body。
- 复盘结论：
  download helper 现在承担它隐藏掉的 response body ownership。后续如果继续
  response body 方向，应先设计 streaming/read helper 是否也应 close，而不是把 close
  行为隐式扩散到所有 reader helper。

## 2026-06-06 http shortcut body bytes-buffer slice

- 本轮收紧 client shortcut body materialization：
  `IHttpClient.Post` / `Put` / `Patch` 旧实现各自重复读取 `IReader`，并把 bytes
  先追加到 Pascal string，再用 `StrToBytes` 转回 `TBytes` 创建 body stream。
- 选择依据：
  - 这不是新增 public API，而是让已有 shortcut 的内部载体与刚落地的
    `NewRequest(..., BodyBytes)` helper 对齐。
  - Go/Rust 的 body helper 语义应把 bytes 当 bytes 处理；string 中转既重复，也让
    binary payload ownership 更难审计。
  - 本 slice 不改变 shortcut 仍需 buffer body 以生成 `Content-Length` 的当前
    public contract，也不引入 streaming/chunked request body。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `52 total, 51 passed, 1 failed`
    - failed at `Client shortcut bodies use bytes buffer`
    - failure: `client shortcut body path uses one bytes-buffer request helper`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - 新增内部 `BufferedBodyRequest`。
  - `Post` / `Put` / `Patch` 共享该 helper；helper 用
    `nextpas.core.io.ReadAll` 读取 body，再调用 bytes body `NewRequest` helper。
  - source-contract 证明不再存在 `LBodyBuf: string;` 与
    `CreateBytesStreamFrom(StrToBytes(LBodyBuf))` 中转。
- 复盘结论：
  client shortcut body path 现在和 public bytes request helper 用同一个载体语义。
  后续若继续 body ownership，应先设计 streaming/chunked request contract，而不是在
  shortcut 内继续堆 ad hoc buffer 逻辑。

## 2026-06-06 http request bytes body helper slice

- 本轮补齐 client request body ergonomics：
  `NewRequest(..., BodyText)` 已覆盖文本请求体，但 binary request body 仍需要调用方
  自己创建 `IReader` 和显式 length。`TBytes` helper 是 Go/Rust 常见 binary body
  使用面的低风险补齐。
- 选择依据：
  - 这是 public message/facade helper，不新增 builder、不扩大 transport vtable。
  - helper 复制 bytes 到 in-memory reader，ownership 与 string body helper 对齐。
  - `Content-Type` 仍由调用方设置，避免 helper 根据 bytes 做不稳定推断。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - compile failed at missing overload:
      `Error: Incompatible type for arg no. 4: Got "TBytes", expected "AnsiString"`
- GREEN / behavior 证据：
  - 新增 `NewRequest(Method, Url, Headers, BodyBytes)` overload，`Url` 支持
    `TUrl` 与 URL string。
  - 新增内部 `BytesBodyReader`；`StringBodyReader` 复用同一 bytes reader 路径。
  - facade `nextpas.core.http.NewRequest(..., BodyBytes)` 转发同一 helper。
- 复盘结论：
  request body helper 现在覆盖 reader + explicit length、string、bytes 三个低风险
  使用面。后续若继续 client ergonomics，应审计 per-request policy 或 streaming
  body ownership contract，而不是直接引入完整 builder。

## 2026-06-06 http response body bytes helper slice

- 本轮补齐 client response body ergonomics：
  `HttpReadResponseBodyString(Resp)` 已覆盖文本 body 便利读取，但二进制响应仍需要
  调用方直接消费 `IHttpResponse.Body` 或走 download helper。`TBytes` helper 是
  Go `io.ReadAll(resp.Body)` / Rust bytes-style 取用的低风险基础面。
- 选择依据：
  - 这是 public client helper ergonomics，不新增 builder、不扩大 transport vtable。
  - helper 明确消费 response body reader，因此 ownership 语义与 string helper 对齐。
  - nil body 返回 empty bytes，nil response 抛 `EArgumentError`，延续 string helper
    已落地的错误边界。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - compile failed at missing `HttpReadResponseBodyBytes`
    - `test_http_client.lpr(1096,39) Error: Identifier not found "HttpReadResponseBodyBytes"`
    - 同一 RED 还覆盖 nil body / nil response helper call site。
- GREEN / behavior 证据：
  - 新增 `nextpas.core.http.client.HttpReadResponseBodyBytes(Resp): TBytes`。
  - facade `nextpas.core.http.HttpReadResponseBodyBytes` 转发同一 helper。
  - `HttpReadResponseBodyString` 现在复用 bytes helper，再转换成 Pascal string，
    避免 duplicate body read loop。
- 复盘结论：
  response body 现在有 string 与 bytes 两条常用消费 helper。后续若继续 client
  ergonomics，应审计 per-request policy、charset decoding 或 streaming ownership
  contract；不要在没有明确 contract 前继续堆格式化 body helper。

## 2026-06-06 http server options validation slice

- 本轮收紧 server options error semantics：
  `THttpServerOptions` 是 server facade 的 public carrier。旧实现只校验 nil
  handler，negative `ReadTimeout` / `WriteTimeout` / `IdleTimeout` 会继续下沉到
  H1 runtime，negative `MaxHeaderSize` / `MaxBodySize` 也会下沉到 request parser /
  limit handling。
- 选择依据：
  - Go/Rust 侧 timeout 和 size limit 都是明确策略输入，负数不是稳定 public
    contract。
  - construction-time `EArgumentError` 比把非法 options 延迟到 runtime 更可测试，
    也避免 HTTP facade 把坏 carrier 推给 foundation。
  - 本 slice 不改变 `0` timeout / limit 的现有语义，不修改
    `nextpas.core.net.server`，也不扩大 H1 runtime。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - `33 total, 32 passed, 1 failed`
    - failed at `HttpServer options reject negative values`
    - failure: `negative server read timeout raises EArgumentError`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - 新增内部 `ValidateServerOptions`。
  - `THttpServer.Create(Handler, Options)` 与
    `THttpServer.Create(Handler, Transport, Options)` 共享同一校验路径，因此
    default transport 与 injected transport overload 都会拒绝 negative timeout /
    size-limit fields。
- 复盘结论：
  server options 现在与 client options 一样具备明确 non-negative invariant。后续若
  继续 options 方向，应先审计 zero-value limit 是否需要 contract，而不是顺手改变。

## 2026-06-06 http client options validation slice

- 本轮继续收紧 client options error semantics：
  `THttpClientOptions.Timeout` 与 `MaxRedirects` 是 public client policy carrier。
  旧实现把 negative timeout 传给 H1 transport，实际表现为“不设置 deadline”；
  negative max redirects 则只会在遇到 redirect 时通过 `too many redirects` side
  effect 暴露，而不是在 construction 边界失败。
- 选择依据：
  - Go/Rust 侧 timeout/redirect limit 都是明确策略输入，负数不是稳定语义。
  - construction-time `EArgumentError` 比把非法选项延迟到 transport 或 redirect
    runtime 更可测试，也更接近 nextPas 公共 API 的防御性输入校验风格。
  - 本 slice 不新增 per-request timeout、redirect callback、cookie jar 或 transport
    vtable，只收紧现有 options carrier。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `47 total, 46 passed, 1 failed`
    - failed at `Client options reject negative values`
    - failure: `negative client timeout raises EArgumentError`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - 新增内部 `ValidateClientOptions`。
  - `THttpClient.Create(Options)` 与 `THttpClient.Create(Transport, Options)` 共享
    同一校验路径，因此默认 transport 与 injected transport overload 都会拒绝
    negative `Timeout` / `MaxRedirects`。
- 复盘结论：
  client options 现在有明确 non-negative invariant。后续若继续 client ergonomics，
  更高价值方向是 per-request policy seam 或 response/body ownership helper，而不是
  扩大一次性 validation 列表。

## 2026-06-06 http request constructor nil headers slice

- 本轮继续收紧 message carrier ergonomics：
  helper 层 `NewRequest(..., nil headers, ...)` 已创建空 header set，但 direct
  `THttpRequest.Create` / `CreateFromRequestTarget` 仍会保存 nil headers。高级调用方
  或内部路径若直接构造 request，再交给 client/H1，后续 `Req.Headers.Has/Get/ForEach`
  仍可能 access violation。
- 选择依据：
  - `THttpRequest` 是 `http.message` 单元公开的 concrete implementation；虽然 helper
    是推荐入口，constructor 不应保留更弱的 header carrier invariant。
  - 这与上一轮 `THttpResponse.Create` nil headers normalization 是同一类
    ownership/ergonomics 修正。
  - 本 slice 不改变 public helper signatures、不新增 builder，也不触碰 H1 transport。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - `27 total, 26 passed, 1 failed`
    - failed at `Request constructors create headers when headers argument is nil`
    - failure: `direct request constructor creates headers when nil`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - 新增内部 `HeadersOrNew` helper。
  - `THttpRequest.Create`、`CreateFromRequestTarget` 与 `THttpResponse.Create`
    共享同一 nil headers normalization。
- 复盘结论：
  request/response message carrier 现在都有稳定 non-nil headers invariant。后续如果
  继续同线，应审计 options validation 或 client redirect policy，而不是继续扩大
  constructor surface。

## 2026-06-06 http response nil headers slice

- 本轮转向 message helper ergonomics：
  `NewRequest(..., nil headers, ...)` 已经会创建空 header set，但
  `NewResponse(Status, nil, Body)` 旧行为保留 nil headers。调用方随后读
  `Resp.Headers.Get(...)` 或追加 headers 会触发 access violation。
- 选择依据：
  - Go/Rust 的 response header carrier 通常给调用方稳定空集合语义；nil header
    map/collection 不应成为普通 response helper 的陷阱。
  - 这是 public message/facade API 质量，不是 H1 malformed case。
  - 实现可以落在 `THttpResponse.Create`，让 public helper 与内部 direct
    response construction 共享同一语义。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - `26 total, 25 passed, 1 failed`
    - failed at `NewResponse with nil headers creates headers`
    - failure: `response helper creates headers when nil`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据:
  - `THttpResponse.Create` 现在把 nil headers 规范化成 `NewHttpHeaders`。
  - `test_http_message` 锁住 helper contract；`test_http_contract` 锁住 facade
    可见性。
- 复盘结论：
  response helper 的 nil headers 语义已与 request helper 对齐。后续可继续审计
  direct request constructor nil headers 或 client option validation，但应单独切片。

## 2026-06-06 http client nil transport response slice

- 本轮转向 client transport seam 错误语义：
  `IHttpTransport.RoundTrip` 是 default H1、future H2/H3 与 injected test/custom
  transport 的共同边界。若 transport 返回 nil response，旧 `THttpClient.DoRequest`
  会直接读取 `LResp.StatusCode`，把 contract violation 暴露成 access violation。
- 选择依据：
  - Go/Rust HTTP client 都把“没有 response”表达为 error，而不是让调用方碰到
    nil response runtime fault。
  - 这是 public client facade 的错误语义，不是 redirect URL spelling 变体。
  - 本 slice 不需要新增 public API 或修改 transport vtable。
- RED 证据：
  - injected `TNilResponseTransport.RoundTrip` 返回 nil。
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `46 total, 45 passed, 1 failed`
    - failed at `Client Do rejects nil transport response`
    - failure: `Access violation`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `THttpClient.DoRequest` 在 `RoundTrip` 后立即检查 nil response，并抛
    `EHttpError`。
  - focused gate 证明该错误不会再穿透成 access violation。
- 复盘结论：
  client facade 现在对 transport 返回 nil response 有稳定错误边界。后续同线可继续
  审计 nil headers、options validation 或 per-request policy，但不要混成一个大
  API 变更。

## 2026-06-06 http redirect response body error-path proof

- 本轮补齐上一 slice 的 error-path proof：
  redirect follow-up 前的 body release 已落地，但 `too many redirects`、
  missing `Location`、unsupported absolute scheme 这些会丢弃当前 3xx response
  并抛出 `EHttpError` 的路径也需要明确 body ownership 证据。
- 选择依据：
  - 这些路径都不会把中间 redirect response 返回给调用方；如果不释放 body，
    close/drain 责任会丢失。
  - 这是 client error semantics / resource ownership，不是继续铺 URL spelling
    variant。
  - 当前实现已具备 release 顺序，本轮只补 source-contract proof，不新增 public
    API。
- RED 证据：
  - 临时移除 `too many redirects` / missing `Location` 分支的 release，并把正常
    release 移到 `ResolveRedirectUrl` 之后。
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `45 total, 42 passed, 3 failed`
    - failed at
      `Client closes redirect response body on too many redirects`
    - failed at
      `Client closes redirect response body on missing Location`
    - failed at
      `Client closes redirect response body on unsupported scheme`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - 恢复正式 release 顺序后，`test_http_client` 锁住三条错误路径都会在抛出前
    close discarded redirect body，且不会执行 follow-up `RoundTrip`。
- 复盘结论：
  error-path body release 已有直接 focused proof。后续同线更高价值方向是
  per-request redirect policy 或 timeout/body ownership API，而不是继续枚举
  redirect resolver 拼写。

## 2026-06-06 http redirect response body release slice

- 本轮转向 client redirect response body ownership：
  `THttpClient.DoRequest` 在收到 redirect response 后直接构造 follow-up request，
  没有释放上一跳 response body。默认 H1 transport 当前会在返回前把
  fixed/chunked/close-delimited body 收到内存 reader，所以 live H1 connection
  reuse 不会立刻被未消费 body 污染；但 injected/future streaming transport seam
  仍会看到被丢弃的 response body 没有 close/drain。
- 选择依据：
  - Go `net/http` redirect 路径不会把中间 redirect response body 交给最终调用方；
    resource ownership 必须由 client 处理。
  - nextPas 已有 `IReadCloser` / `ICloser` / `IStream.Close` 语义；不需要为了本
    slice 新增 public redirect policy 或 streaming response API。
  - plain `IReader` 没有 close 能力时，唯一可表达的释放方式是 drain 到 EOF。
- 实现决策：
  - 新增内部 `ReleaseRedirectResponseBody`。
  - 优先 close `IReadCloser`、`ICloser`、`IStream`。
  - non-closeable `IReader` fallback 读取到 EOF。
  - `too many redirects` 和 `redirect with no Location header` 错误路径也会释放
    当前 redirect body。
- RED 证据：
  - close-capable body RED：
    - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `41 total, 40 passed, 1 failed`
    - failed at `Client closes redirect response body before follow-up`
    - failure: `redirect response body is closed before follow-up round trip`
    - heaptrc: `0 unfreed memory blocks`
  - non-closeable drain RED：
    - 临时移除 fallback drain 循环后，同一 focused gate 失败在
      `Client drains redirect response body before follow-up`
    - failure:
      `non-closeable redirect response body is drained before follow-up round trip`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `42/42 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 redirect 中间响应 body ownership 的窄修正。它没有声明新增 response
  streaming API、per-request redirect callback、cookie jar 或 H1 parser 重构。
  后续 client 方向可以继续审计 redirect error-path body release、timeout
  ergonomics 或 per-request redirect policy，但应先有具体 contract。

## 2026-06-06 http redirect default-port authority slice

- 本轮继续收紧 client redirect Host ownership：
  上一轮 same-authority 判断直接比较 raw `Port` 字段。`TUrl.Parse` 对省略端口
  使用 `Port=0`，因此 `http://example.test` redirect 到
  `http://example.test:80` 会被误判为 authority 变化，进而删除 caller
  `Host` override。
- 选择依据：
  - 对 HTTP redirect 来说，omitted port 与 scheme 默认端口应视为同一
    effective authority；这符合 Go/Rust 常见 URL/client 使用面。
  - 本缺口只影响 redirect Host ownership，不要求修改全局 `TUrl.Parse`
    表达方式，也不要求 H1 transport 改端口选择逻辑。
  - 继续保持 cross-authority 时删除旧 Host 的安全边界。
- 实现决策：
  - 新增内部 `DefaultPortForScheme` 与 `EffectiveAuthorityPort`。
  - `IsRedirectSameAuthority` 现在比较 lower-case host 与 effective port。
  - 未知 scheme 仍落到 effective port `0`；本轮不扩大到非 HTTP scheme 设计。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `40 total, 39 passed, 1 failed`
    - failed at `Client redirect preserves custom host header on default-port authority`
    - failure: `default-port redirect preserves caller host override: expected "override.test", got ""`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `40/40 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 redirect Host ownership 的 effective-authority 修正。后续若继续同线，
  更高价值方向应转向 redirect response body drain / connection reuse 或
  per-request redirect policy，而不是继续枚举 URL spelling variants。

## 2026-06-06 http redirect absolute scheme slice

- 本轮继续收紧 client redirect URL resolution：
  `ResolveRedirectUrl` 只直接识别小写 `http://` / `https://`。大写 scheme
  例如 `HTTP://redirect.test/new` 会进入 relative 分支，导致 follow-up request
  保留 base host；unsupported absolute scheme 例如 `ftp://...` 也会被误当成
  relative target，而不是 fail-fast。
- 选择依据：
  - URL scheme 语义是 case-insensitive；Go/Rust 常见 client 都不会把
    `HTTP://...` 当成相对路径。
  - redirect client 层应该决定是否支持一个 absolute scheme，transport 不应收到
    被错误合并到 base authority 的 request object。
  - 本 slice 仍限于 redirect resolver，不改全局 `TUrl.Parse`、不新增 TLS/H2/H3
    或 redirect policy。
- 实现决策：
  - 新增内部 `RedirectAbsoluteScheme`，用 `://` 检测 absolute redirect scheme
    并转小写。
  - `http` / `https` scheme 走 `TUrl.Parse`，然后把 follow-up `Scheme`
    规范成小写。
  - 其他 `://` absolute scheme 抛 `EHttpError`，并且不会执行第二次
    `RoundTrip`。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `39 total, 37 passed, 2 failed`
    - failed at `Client redirect transport resolves uppercase absolute Location`
    - failure: `uppercase absolute redirect updates host: expected "redirect.test", got "example.test"`
    - failed at `Client redirect rejects unsupported absolute scheme`
    - failure: `absolute redirect with unsupported scheme raises EHttpError`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `39/39 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 redirect request-object URL scheme contract 的真实收紧。后续如果继续
  URL resolution，可以单独审计 default-port authority normalization；不要把
  TLS implementation 或 H2/H3 support 混入此 resolver slice。

## 2026-06-06 http redirect Host ownership slice

- 本轮继续收紧 client redirect header ownership：
  上一个 header carry-over slice 为了避免跨 authority 旧 Host 污染新目标，
  在 follow-up request 中无条件删除 `host`。这会破坏调用方显式设置的
  Host override：relative redirect 没有改变 URL authority，却丢掉了 caller
  `Host: override.test`。
- 选择依据：
  - Go/Rust 常见 client 语义都把 redirect follow-up 当作同一个调用方请求意图的
    延续；relative / same-authority redirect 不应丢失 caller 指定的 authority
    override。
  - `Host` 与 auth/cookie 不同，不能用 trusted-subdomain 规则。它只在 URL
    authority 变化时删除，否则 same-authority redirect 中 caller override
    应继续可见。
  - 这仍是 redirect request-object contract，不改 `IHttpClient` vtable、
    cookie jar、per-request redirect policy、H1 writer 或底层 net runtime。
- 实现决策：
  - 新增内部 `IsRedirectSameAuthority`，只比较 host（case-insensitive）和 port。
  - `RedirectHeadersFor` 在 authority 不同时删除 `host`；relative redirect
    经 `ResolveRedirectUrl` 继承 base authority，因此保留 caller Host override。
  - sensitive header stripping 仍使用 `IsRedirectTrustedHost`，保持 previous
    same-host/subdomain auth-cookie 语义不变。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `37 total, 36 passed, 1 failed`
    - failed at `Client redirect preserves custom host header on relative Location`
    - failure: `relative redirect preserves caller host override: expected "override.test", got ""`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `37/37 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 follow-up Host ownership 的窄修正。后续如果继续 redirect header
  semantics，可单独补 cross-authority Host removal proof 或 default-port
  authority 规范化，但不要混进 cookie jar / redirect callback 扩展。

## 2026-06-06 http redirect header ownership slice

- 本轮转向 client redirect header ownership：
  当前 redirect follow-up request 每次都用 `NewHttpHeaders`，导致 caller headers
  在 same-authority redirect 中也全部丢失；这与 Go `net/http` 常见语义不符，
  也让 future H2/H3 transport seam 看不到稳定的 follow-up request headers。
- 选择依据：
  - Go `net/http` 会把初始请求 headers 带到 redirect follow-up，但跨到非同域 /
    非子域目标时剥离 `Authorization`、`WWW-Authenticate`、`Cookie`、`Cookie2`
    这类敏感 header。
  - 这是真实安全/API 语义，不是继续铺 malformed H1 case，也不需要改
    `IHttpClient` vtable、cookie jar 或 per-request redirect policy。
  - nextPas 的 `content-length` 是普通 header；`301` / `302` / `303` 改成
    bodyless `GET` 时必须额外删除 `content-length` / `transfer-encoding`，
    否则会生成声明 body 但无 body 的 H1 request。
- 实现决策：
  - 新增内部 `RedirectHeadersFor`，从当前 request clone headers。
  - redirect follow-up 永远删除 `host`，让 H1 transport 根据新 URL 重新设置。
  - bodyless redirect 删除 `content-length` / `transfer-encoding`。
  - cross-authority redirect 删除 `authorization`、`www-authenticate`、`cookie`、
    `cookie2`；same host 或 subdomain 保留敏感 headers。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `36 total, 34 passed, 2 failed`
    - failed at `Client redirect preserves headers on same authority`
    - failure: `same-authority redirect preserves ordinary header: expected "trace-1", got ""`
    - failed at `Client redirect strips sensitive headers across authority`
    - failure: `cross-authority redirect preserves ordinary header: expected "trace-2", got ""`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `36/36 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 redirect follow-up request header contract 的真实收紧。后续如果继续
  client redirect，应单独设计 per-request redirect policy / callback 或 cookie
  jar，而不是把这些扩展混入 header carry-over slice。

## 2026-06-06 http 307 seekable body replay slice

- 本轮转向 client redirect body ownership：
  旧文档说 `307` / `308` preserve method/body reader，但真实行为只是复用同一
  `IReader`。一旦第一跳 transport 已经读完 body，第二跳就会拿到 EOF。
- 选择依据：
  - Go/Rust HTTP client 都不会把 body replay 语义伪装成“复用 reader 就够了”；
    可 replay body 应该能 replay，不能 replay 的非空 body 应该 fail-fast。
  - 这比继续铺 relative URL 变体更有 API 质量价值，且仍可限制在 client
    redirect layer，不需要改 H1 writer 或底层 net runtime。
  - 当前 `IStream` 已经是 nextPas 的 seekable body carrier，足够覆盖
    `NewRequest(..., BodyText)` 和 in-memory request helpers。
- 实现决策：
  - 在第一跳 `RoundTrip` 前记录 body stream 起始 position。
  - `307` / `308` follow-up 构造前，如果 body 支持 `IStream`，把 position
    rewind 回起点。
  - 非空 body 不支持 `IStream` 时抛 `EHttpError`，避免第二跳静默发送空 body。
- RED 证据：
  - seekable replay RED：
    - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `33 total, 32 passed, 1 failed`
    - failed at `Client replays seekable body on 307 redirect`
    - failure: `temporary redirect replays seekable body on follow-up: expected "payload", got ""`
    - heaptrc: `0 unfreed memory blocks`
  - non-replayable fail-fast RED：
    - 临时移除 raise 分支后，同一 focused gate 失败在
      `Client rejects non-replayable body on 307 redirect`
    - failure: `temporary redirect rejects non-replayable request body`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `34/34 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  这是 body ownership contract 的真实收紧，不是 helper 糖。后续如果继续 client
  ergonomics，应单独设计 streaming body replay / `GetBody` callback 或
  per-request redirect policy，不应把这些混进本 slice。

## 2026-06-06 http fragment-only redirect slice

- 本轮继续收紧 client redirect URL resolution：
  dot-segment path merging 已收口，但 fragment-only `Location` 例如
  `#section` 会把 base query 清空，follow-up request object 只剩 fragment。
- 选择依据：
  - Go/Rust HTTP client 都按 RFC-style relative reference resolution 处理
    fragment-only redirects；它们不应该改变 path/query。
  - 这仍是 internal resolver contract，不改 `IHttpClient` vtable、
    public helper、timeout 或 body replay ownership。
  - H1 writer 已经只写 path/query，不把 fragment 发到 request-target；本 slice
    只保证 request object 的 URL parts 正确，避免 future transport 复制错误语义。
- 实现决策：
  - 新增内部 `HasRedirectQueryDelimiter`，只扫描 fragment delimiter 前的 `?`。
  - relative redirect 分支中，非空 path 继续替换/清空 query；
    query-only reference 继续替换 query；fragment-only reference 保留 base query。
  - absolute URL 与 network-path redirect 分支保持不变。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `32 total, 31 passed, 1 failed`
    - failed at
      `Client redirect transport preserves query on fragment-only Location`
    - failure: `fragment-only redirect preserves original raw query: expected "from=base", got ""`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `32/32 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向仍然是 redirect follow-up request object URL-resolution contract，不是
  H1 malformed parity。后续若继续 client ergonomics，应优先审计 redirect
  body replay ownership、per-request redirect policy 或 timeout ergonomics，而不是
  继续铺同型 relative URL case。

## 2026-06-06 http dot-segment redirect slice

- 本轮继续收紧 client redirect URL resolution：
  path-relative redirect 已按 base directory 合并，但 merged path 中的 `..`
  segment 仍原样暴露给 follow-up request。
- 选择依据：
  - Go/Rust HTTP client 都按 RFC-style relative reference resolution 移除
    dot segments；transport 不应收到 `/dir/sub/../next` 再自行解释。
  - 这仍是 internal resolver contract，不改 `IHttpClient` vtable、
    public helper、timeout 或 body replay ownership。
  - 对 future H2/H3 transport seam 有直接价值：protocol implementation 应收到
    已解析的 path，而不是把 URL resolution 逻辑复制到每个 transport。
- 实现决策：
  - 新增内部 `NormalizeRedirectPath`，在 relative `Location` 分支完成
    base-directory merge 后移除 `.` / `..` segments。
  - normalizer 使用 segment-moving algorithm，避免把逻辑下沉到 H1 writer。
  - 本 slice 不改变 absolute URL 和 network-path redirect 的既有分支。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `31 total, 30 passed, 1 failed`
    - failed at `Client redirect transport normalizes dot-segment Location`
    - failure: `dot-segment redirect normalizes merged path: expected "/dir/next", got "/dir/sub/../next"`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `31/31 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 redirect follow-up request object path normalization
  contract，不是 H1 malformed parity。后续若继续 URL resolution，应单独审计
  query-only / fragment-only 语义或 absolute/network-path dot-segment normalization。

## 2026-06-06 http path-relative redirect slice

- 本轮继续收紧 client redirect URL resolution：
  network-path redirect 已能替换 authority，但 path-relative `Location`
  例如 `next?from=relative-path` 仍被直接写入 follow-up `Url.Path`，
  变成裸 `next`。
- 选择依据：
  - Go/Rust HTTP client 都按 base URL 目录解析 path-relative redirects；
    transport 不应收到没有 leading slash 的 request path。
  - 这仍是 internal resolver contract，不改 `IHttpClient` vtable、
    public helper、timeout 或 body replay ownership。
  - 对 H1 wire 和 future H2/H3 transport seam 都有价值：follow-up request
    object 应暴露合并后的 path，而不是要求 transport 再做 URL resolution。
- 实现决策：
  - 新增内部 `MergeRedirectPath(BasePath, TargetPath)`。
  - absolute-path target 仍直接替换 path。
  - path-relative target 使用 base path 的最后一个 `/` 作为目录边界；
    base path 没有目录时落到 root-relative `/<target>`。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `30 total, 29 passed, 1 failed`
    - failed at `Client redirect transport resolves path-relative Location`
    - failure: `path-relative redirect merges with base directory: expected "/dir/next", got "next"`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `30/30 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 redirect follow-up request object path contract，不是 H1
  malformed parity。后续可单独审计 dot-segment normalization、query-only 和
  fragment-only redirects，但不应混入本 slice。

## 2026-06-06 http network-path redirect slice

- 本轮继续收紧 client redirect URL resolution：
  relative redirect query 已能拆分 path/query，但 network-path `Location`
  例如 `//redirect.test/new?from=network` 仍被当成普通 relative target，
  follow-up request 继续保留 base host。
- 选择依据：
  - Go/Rust HTTP client 都在 client redirect 层完成 URL resolution；
    network-path redirect 必须继承 base scheme 并替换 authority，transport
    不应再猜 `//host/path` 的含义。
  - 这仍是 internal resolver contract，不改 `IHttpClient` vtable、
    public helper、timeout 或 body replay ownership。
  - 对 future H2/H3 transport seam 有直接价值：follow-up request object
    必须暴露权威 `Scheme` / `Host` / `Path` / `RawQuery`。
- 实现决策：
  - `ResolveRedirectUrl(BaseUrl, Location)` 对 `//...` 先要求 base scheme 非空。
  - network-path Location 使用 `BaseUrl.Scheme + ':' + Location` 转成 absolute URL，
    再复用 `TUrl.Parse`。
  - base scheme 为空时抛 `EHttpError`，避免 silent 生成无效 authority。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `29 total, 28 passed, 1 failed`
    - failed at `Client redirect transport resolves network-path Location`
    - failure: `network-path redirect updates host: expected "redirect.test", got "example.test"`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `29/29 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 redirect follow-up request object authority contract，
  不是继续铺 H1 malformed case。后续若继续 redirect URL resolution，应单独审计
  query-only / fragment-only / dot-segment merge，而不是混入本 slice。

## 2026-06-06 http relative redirect query slice

- 本轮继续收紧 client redirect transport seam：
  live H1 request-target 会在 server 侧重新解析，所以 `/new?from=redirect`
  端到端已能工作；但显式注入 `IHttpTransport` 时，redirect follow-up request
  对象本身仍把 query 留在 `Url.Path`，`RawQuery` 为空。
- 选择依据：
  - Go/Rust HTTP client 都把 redirect 解析视为 client 层职责；transport 应收到
    已拆分的 URL parts，而不是被迫自己从 path 字符串里二次解析 query。
  - 这直接影响 future H2/H3 transport seam：H2/H3 不会发送 HTTP/1.1
    request-target 文本再让 server 解析，follow-up request object 必须是权威。
  - 这是内部 redirect resolver 收敛，不改 public API、vtable、timeout 或
    body replay ownership。
- 实现决策：
  - `ResolveRedirectUrl(BaseUrl, Location)` 作为 client 内部 helper。
  - absolute `http://` / `https://` 继续走 `TUrl.Parse`。
  - relative Location 走 `TUrl.ParseRequestTarget` 拆分 path/query/fragment，再合并
    scheme/host/port 等 base URL authority。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `28 total, 27 passed, 1 failed`
    - failed at `Client redirect transport sees parsed relative query`
    - failure: `redirect follow-up request path excludes query: expected "/new", got "/new?from=redirect"`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `28/28 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 redirect follow-up request object contract，不是再铺一个
  H1 live malformed case。后续可继续审计 query-only / network-path Location 或
  per-request redirect policy，但应单独 RED，不和本 slice 混合。

## 2026-06-06 http see-other redirect slice

- 本轮继续收紧 client redirect/error semantics：
  HTTP status surface 里缺少 `303 See Other`，client redirect set 也只覆盖
  `301/302/307/308`。
- 选择依据：
  - Go `net/http` 与 Rust 常见 client surface 都把 `303 See Other` 视作常见
    redirect 语义，POST 后跳转到 GET 结果页是核心使用面，不是边角 malformed case。
  - 这是 redirect/status contract tightening，不改 `IHttpClient` vtable、
    transport、timeout、连接池或 request helper。
  - `303` 明确应丢弃原 body；`307/308` 继续保持既有 method/body preservation
    语义，本轮不扩大到 body replay ownership 设计。
- 实现决策：
  - `HTTP_STATUS_SEE_OTHER = 303` 进入 `http.base` 与 facade。
  - `HttpStatusText(303)` 返回 `See Other`。
  - `THttpClient.DoRequest` 将 `303` 纳入 redirect set，并与 `301/302`
    一样构造无 body 的 `GET` follow-up request。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_base clean test`
    - 编译失败：`Identifier not found "HTTP_STATUS_SEE_OTHER"`。
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - 编译失败：`Identifier not found "HTTP_STATUS_SEE_OTHER"`。
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - 编译失败：`Identifier not found "HTTP_STATUS_SEE_OTHER"`。
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_base clean test`
    - `22/22 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - `32/32 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `26/26 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 client redirect 语义真实缺口，不是扩大 builder 或继续铺
  malformed wire case。后续若继续 client 侧，应优先单独审计 redirect override、
  per-request timeout 与 body replay ownership，而不是把这些塞进 `303` slice。

## 2026-06-06 http request string body helper slice

- 本轮继续收紧 client request construction ergonomics：
  request helper 已支持 custom `IReader + ContentLength`，但简单 string body
  仍要求调用方手写 bytes stream 和长度。
- 选择依据：
  - Go `net/http` 的 `NewRequest` 和 Rust 常见 client builder surface 都让简单
    string/body 构造保持直接；nextPas 只接受 `IReader` 时，对普通 POST/PUT
    过于啰嗦。
  - 这是 helper overload，不改 `IHttpClient` vtable，不改 transport，不引入完整
    fluent builder。
  - helper 不猜 `Content-Type`，避免把 JSON/form/text policy 写死在 HTTP core。
- 实现决策：
  - `NewRequest(Method, Url, Headers, BodyText)` 同时支持 `TUrl` 和 URL string。
  - helper 复制 Pascal string 到 `CreateBytesStreamFrom` 生成的 in-memory reader。
  - helper 复用既有 custom request contract：nil headers 创建空 header set，
    并发布 `Content-Length`。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - 编译失败：`Wrong number of parameters specified for call to "NewRequest"`。
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - 编译失败于 facade `NewRequest(..., string body)` 缺失。
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - 编译失败于 live `IHttpClient.Do_` helper path 的 string body overload 缺失。
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - `25/25 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - `32/32 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `25/25 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是低风险 body ergonomics helper，不是扩大成 request builder。
  后续如果继续 client API，应单独设计 per-request timeout / redirect override /
  streaming body ownership，而不是让 string helper 承担这些语义。

## 2026-06-06 http client nil request error slice

- 本轮继续收紧 client public error semantics：
  `IHttpClient.Do_(nil)` 之前会进入 `DoRequest`，读取 `AReq.Url` 时触发
  access violation。
- 选择依据：
  - Go / Rust 的 HTTP client 使用面都会把 request 对象视为调用边界的必需参数；
    nil request 属于调用方参数错误，应该在 public API 入口给出明确错误。
  - 这是错误语义 guard，不改 `IHttpClient` vtable，不改 transport registry，
    不改变 redirect 或 body ownership。
- 实现决策：
  - `THttpClient.Do_` 在调用 `DoRequest` 前检查 `AReq = nil`。
  - nil request 抛 `EArgumentError.Create('HTTP request is nil')`。
  - redirect recursion 仍走内部 `DoRequest`，不额外扩大 internal guard。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `25 total, 24 passed, 1 failed`
    - failure: `Client Do rejects nil request - Access violation`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `25/25 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 client API 边界的真实错误语义缺口，不是继续铺
  malformed wire case。后续 client 侧仍应优先审计 timeout / redirect /
  body ownership 等 public contract，而不是扩大 builder。

## 2026-06-06 http response body string helper slice

- 本轮继续收紧 client response ergonomics：
  request construction helper 已落地，但常见 response body 读取仍散落在测试和
  example 的 reader loop / `ReadAll` + bytes conversion 中。
- 选择依据：
  - Go `net/http` 和 Rust reqwest/hyper 生态都让调用方很直接地表达“消费 body
    并读完整内容”；nextPas 目前只有底层 `IReader`，对简单 client/example 场景
    过于啰嗦。
  - 这是 helper，不改 `IHttpClient` vtable，不改 transport，不改变 body
    ownership；helper 明确消费当前 response body reader。
  - 不把它扩大成 charset-aware decoder、streaming builder 或 response owner 类型；
    这些 contract 需要后续单独设计。
- 实现决策：
  - `nextpas.core.http.client.HttpReadResponseBodyString(Resp)` 读取 `Resp.Body`
    到 Pascal string。
  - nil response 抛 `EArgumentError`；nil body 返回 `''`。
  - facade `nextpas.core.http.HttpReadResponseBodyString` 只做 inline 转发。
  - `http_get_client` example 改用新 helper，删除本地 bytes-to-string helper。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - 编译失败于 3 处 `Identifier not found "HttpReadResponseBodyString"`。
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - 编译失败于 facade helper 缺失：
      `Identifier not found "HttpReadResponseBodyString"`。
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `24/24 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - `32/32 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_examples clean test`
    - `5/5 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是低风险 public helper ergonomics，不是继续复制 correctness
  malformed case，也不是 premature request/response builder。后续 client API 仍应
  评估 per-request timeout / redirect override / charset decoding 是否需要独立
  contract。

## 2026-06-06 http hyper comparator smoke slice

- 本轮继续收紧 benchmark truth：
  `rust_std` 已经明确不是 Rust 生态代表，但 runner 仍缺少真实 Rust HTTP
  stack 的可执行 seam。
- 选择依据：
  - Hyper/Tokio 是 Rust HTTP 生态常见基础栈，比 std-only microbaseline 更接近
    真实 async server stack。
  - 直接把 Hyper 纳入默认 runner 会让普通 smoke 依赖 Cargo dependency fetch，
    不适合所有快速验证；因此本轮做 opt-in `--include-hyper`。
- 实现决策：
  - 新增 `benchmarks/nextpas.core.http/compare_hyper` Cargo project。
  - Hyper/Tokio comparator 只负责 HTTP/1.1 server；client 仍使用 raw
    keep-alive workload shape，保持与 std-only comparator 的 request/response
    读取口径一致。
  - 输出统一为 `impl=rust_hyper` 与 `rust_profile=hyper_tokio`。
  - `run_server_comparison.sh --include-hyper` 才 cargo build / run Hyper
    comparator；默认仍只跑 nextPas、Go、Rust std-only。
  - `capture_server_comparison_snapshot.sh --include-hyper` 透传同一 flag，并在
    Markdown 中记录 `include_hyper=1` 和完整 command。
- RED 证据：
  - `test_http_benchmarks` 首次 RED：
    - `38 total, 36 passed, 2 failed`
    - Hyper comparator 失败于无法 resolve `compare_hyper` core root。
    - runner 失败于 `unknown argument: --include-hyper`。
    - heaptrc: `0 unfreed memory blocks`
  - snapshot pass-through RED：
    - `39 total, 38 passed, 1 failed`
    - `capture_server_comparison_snapshot.sh` 失败于
      `unknown argument: --include-hyper`。
    - heaptrc: `0 unfreed memory blocks`
- 调试证据：
  - 直接 smoke 初版 Hyper comparator 暴露 runtime-context bug：
    `TokioTcpListener::from_std` 在 runtime 外调用会 panic。
  - 根因是 Tokio listener 需要在 runtime context 内注册 IO driver；修复为在
    server thread 的 `runtime.block_on(async move { ... })` 内执行 `from_std`。
- GREEN / behavior 证据：
  - direct comparator smoke：
    - `bench_http_server_hyper --requests 32 --threads 2`
    - 输出 `impl=rust_hyper`、`rust_profile=hyper_tokio`、`completed=32`
  - optional runner smoke：
    - `run_server_comparison.sh --requests 8 --threads 1 --include-hyper`
    - 输出 `section=rust_hyper` 与 `summary_impl=rust_hyper`
  - focused gate：
    - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
    - `39/39 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 benchmark truth seam，不是把一次本机数字包装成排名。
  后续正式 benchmark 应继续把 `rust_std` 与 `rust_hyper` 分开报告，必要时再补
  TLS、router/middleware 或 async-client workload。

## 2026-06-06 http request string URL overload slice

- 本轮继续收紧 client request construction ergonomics：
  上一轮 `NewRequest(Method, Url, Headers, Body, ContentLength)` 已让调用方摆脱
  concrete `THttpRequest`，但仍要求先手写 `TUrl.Parse`。
- 选择依据：
  - Go `net/http.NewRequest` 和 Rust 常见 client builder surface 都允许调用方直接给
    URL 字符串，手动 URL record 解析不应成为构造 `IHttpClient.Do_` request 的默认负担。
  - 这是 helper overload，不改 `IHttpClient` vtable，不引入 fluent builder，
    也不改变 H1 transport/body ownership。
- 实现决策：
  - `nextpas.core.http.message.NewRequest` 新增两个 string URL overload：
    简单 request 和 headers/body/content-length request。
  - facade `nextpas.core.http.NewRequest` 同步转发两个 overload。
  - 实现只调用 `TUrl.Parse(AUrl)` 后复用既有 `TUrl` overload，因此 nil headers、
    `content-length`、negative length 和 URL parse error contract 不分叉。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - 编译失败，`Incompatible type for arg no. 2: Got "Constant String", expected "TUrl"`
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - 编译失败，facade overload 同样缺失。
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - 编译失败，live `IHttpClient.Do_` helper 用例不能直接传 URL string。
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_message clean test`
    - `24/24 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_contract clean test`
    - `31/31 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C core/tests/nextpas.core.http/test_http_client clean test`
    - `21/21 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是低风险 public helper ergonomics，不是 premature builder。
  后续 client API 仍应优先评估 per-request timeout / redirect override /
  body ownership，而不是扩大 shortcut 方法数量。

## 2026-06-06 http get client example env URL slice

- 本轮针对 goal 中“examples / smoke 不依赖固定端口”的剩余小缺口：
  server examples 的 smoke 已用保留端口启动，但 `http_get_client` 尚未纳入
  runnable smoke，且无参数时只能连固定 `8080`。
- 选择依据：
  - client example 本身已支持命令行 URL，但 Makefile / smoke 场景更适合用环境变量
    注入动态 URL，避免要求额外参数拼接。
  - 这是 example ergonomics / runnable smoke 改良，不改变 HTTP runtime 或 public API。
- 实现决策：
  - `http_get_client` 的 URL 优先级为：命令行第一个参数 >
    `NEXTPAS_HTTP_GET_URL` > 原默认 `http://127.0.0.1:8080/hello/world?page=1`。
  - `test_http_examples` 新增 `http_get_client` build/run smoke：先启动
    `hello_http_server` 的保留 loopback port，再通过 env URL 运行 client，
    验证 `url=...`、`status-code=200`、`hello=world`、`page=3`。
- RED 证据：
  - `make -C core/tests/nextpas.core.http/test_http_examples clean test`
    - `5 total, 4 passed, 1 failed`
    - failed at `get client example uses env URL without fixed port`
    - client 仍连接默认 `8080`，报 `ENetworkError: tcp connect failed (111)`
    - heaptrc: `0 unfreed memory blocks`
- GREEN / behavior 证据：
  - `make -C core/tests/nextpas.core.http/test_http_examples clean test`
    - `5/5 passed`
    - heaptrc: `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 runnable example smoke 的实际缺口，不是扩大 HTTP API。
  后续如继续 example work，优先考虑 Makefile 参数传递或 server examples 的更清晰
  dynamic-port story；不应为此改 HTTP server runtime。

## 2026-06-06 http rust std comparator label slice

- 本轮不是新增 Hyper/Tokio comparator，而是先修正现有 benchmark harness 的
  输出 contract：std-only Rust comparator 不能继续以 `impl=rust` 出现在 raw rows、
  summary rows 和 snapshots 里。
- 选择依据：
  - 文档已经明确该 comparator 是 std-only microbaseline，但机器可读输出仍是
    `impl=rust` / `summary_impl=rust`，后续报告容易被误读成 Rust 生态代表。
  - 引入真实 Hyper/Tokio 需要 Cargo dependency、async runtime 和 server/client
    harness 设计；当前更小、更可回滚的 truth slice 是先把已有 baseline 标准化为
    `rust_std`。
- 实现决策：
  - `compare_rust/main.rs` 输出 `impl=rust_std` 与 `rust_profile=std_only`。
  - `run_server_comparison.sh` 的 runner section、expected impl 和 median summary
    统一使用 `rust_std`。
  - `test_http_benchmarks` 同时锁住 comparator smoke、runner report、multi-run
    summary 和 snapshot 中的新 marker。
- RED 证据：
  - `test_http_benchmarks` 先失败 9 个 case，典型失败为
    `implementation marker missing from output: impl=rust_std`，实际输出仍是
    `impl=rust` / `summary_impl=rust`。
  - 失败 run 仍显示 heaptrc `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C core/tests/nextpas.core.http/test_http_benchmarks clean test`
  - `36/36 passed`，heaptrc `0 unfreed memory blocks`。
- 复盘结论：
  方向没有走偏：这是 benchmark truth 的 contract tightening，不是性能数字包装。
  后续仍不能声明 Rust 生态对标完成；下一步若继续 benchmark truth，应新增真实
  Hyper/Tokio 或等价 async Rust comparator。

## 2026-06-06 http API parity request helper slice

- 对标结论：
  - Go `net/http` 的稳定使用面是同步 `Server` lifecycle、handler/middleware
    composition、`Request`/`Header`/`Body` ownership 与 `Client.Do`。
  - Rust 生态不能只看 std-only comparator；hyper/tower 更强调 service/connection
    seam，reqwest 更强调 request-builder ergonomics。
  - nextPas 当前 server lifecycle、router/middleware、transport injection、
    static helper 与 WebSocket helper surface 已经够稳；H2/H3 仍只能保留 registry
    seam 和 future plan，不能伪实现。
- 真实缺口：
  - client shortcut 已有 `Get/Post/Put/Delete/Patch/Head`，download helpers 也已落地；
    缺的是一个不用 concrete `THttpRequest` 的 request construction helper。
  - 完整 fluent `IHttpRequestBuilder` 还不是当前最佳切片，因为 per-request timeout、
    redirect override、form/json convenience、streaming/chunked request body ownership
    都需要额外 contract。
- 实现决策：
  - 新增 `NewRequest(Method, Url, Headers, Body, ContentLength)` overload。
  - nil headers 创建空 `IHttpHeaders`，body/positive length 会设置
    `content-length`，negative length 抛 `EArgumentError`。
  - 不改 `IHttpClient` vtable，不改 transport registry，不改 H1 request writer
    streaming model。
- RED 证据：
  - `test_http_message` 先失败于 `Wrong number of parameters specified for call to "NewRequest"`。
  - `test_http_contract` 先失败于 facade `NewRequest` overload 缺失。
  - negative content-length 用例先失败：`22 total, 21 passed, 1 failed`，heaptrc
    `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_message`：`22/22 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_contract`：`30/30 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_client`：`21/21 passed`，heaptrc `0 unfreed memory blocks`
- 复盘结论：
  方向没有走偏：这是 API ergonomics 的小 public surface，不是继续堆 correctness
  case，也不是 premature builder。后续若继续 API 设计，对 client 侧优先评估
  per-request options / body ownership；若转 benchmark truth，优先补 Hyper/Tokio
  comparator 或至少明确 runner smoke。

## 2026-06-06 http h1 parser metadata span fast path slice

- 本轮把 H1 parser watched request metadata 从“parse-time cache 但仍为部分
  watched value 物化 string”继续推进到单 span callback 下的 direct span scan。
- 选择依据：
  - `AddParsedSpans` 与 request metadata cache 已经落地；重复做 parsed-header
    insertion 会浪费，直接 staging/materialize public headers 又是更大架构 slice。
  - 当前更窄、更安全的真实成本是 `UpdateRequestMetadataFromHeader` 对
    `Host` / `Connection` / `Content-Length` / `Expect` 仍调用
    `CapturedHeaderValueToString`，随后 public header store 又会为同一 value
    物化一次。
  - `Transfer-Encoding` 的 malformed-vs-unsupported 分类敏感，本轮不改它的
    combined-string validation。
- 实现决策：
  - 新增 captured value helpers：non-empty、exact equals、trimmed Int64 parse、
    trimmed/case-insensitive `Expect` token scan。
  - `Host` / `Connection` / `Content-Length` / `Expect` metadata 在 value 未分片时
    直接扫描 captured span；分片或已 materialized 情况保留 string fallback。
  - 不改 public `IHttpHeaders`，不改 `THttpHeaders` 存储，不改 generated llhttp。
- RED 证据：
  - `test_http_benchmarks` 先失败在
    `H1 parser request metadata span fast path source contract`：
    `36 total, 35 passed, 1 failed`，heaptrc `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_h1parser`：`95/95 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`36/36 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server`：`275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `adapter no-url: metadata 3 headers = 322.2 ns/op`
  - `adapter no-url: llhttp direct only = 1172.1 ns/op`
- 子代理只读复盘：
  - Euclid 确认 direct `AddParsedSpans` 已经存在，主要风险是 buffer lifetime 和
    token/trim 语义漂移；本轮保留 `Execute` 后 pending-span materialization。
  - Cicero 建议 parsed-header staging 是下一批更大候选；本轮按收敛期要求没有扩大。
- 复盘结论：
  方向没有走偏：这是 adapter metadata 热路径降本，不是碎片化 inline，也没有引入新
  worktree 或大功能。下一步进入收敛：只处理已验证 HTTP 改动的提交与 merge readiness，
  暂停新增大 slice；如果后续恢复性能批次，优先评估 parsed-header staging 的收益/风险。

## 2026-06-06 http h1 writer known status-line slice

- 本轮把 `TH1ResponseWriter.WriteStatusLine` 从“只有 `200 OK` 固定行”推进到
  常见 status 固定行 fast path。
- 选择依据：
  - 上一批 compact header block 已减少 header section write 调用数；下一处真实固定成本是
    非 200 status-line 仍走 `WriteStr('HTTP/1.1 ')`、`IntToStr`、`HttpStatusText`、
    `WriteStr(reason)`、`WriteCRLF` 多段路径。
  - Server malformed/error 路径大量使用 `400/413/417/431/500/501`，router 常见 miss 使用
    `404`；这些 fixed status-line 比继续扩大 header block 优化更贴近 HttpServer 热路径。
  - 子代理只读审查确认应保持 unknown status fallback，不在整个 writer 禁用
    `IntToStr` / `HttpStatusText`，benchmark 只锁 row/marker 不锁数值。
- 实现决策：
  - 新增 `TryWriteKnownStatusLine`，覆盖
    `100/101/103/200/201/204/301/302/304/400/401/403/404/405/413/417/431/500/501/502/503`。
  - `WriteStatusLine` 先尝试 known fast path，失败再走原来的 generic fallback。
  - fixed line 仍通过 `WriteAllOrRaise` 写出，保留 short-writer retry / zero-progress raise。
  - 不改 public API，不改 `HttpStatusText`，不改 no-body / informational / hijack 语义。
- RED 证据：
  - `test_http_h1writer` 先失败在 common status write-call count：
    `32 total, 31 passed, 1 failed`，expected `2` got `6`，heaptrc `0 unfreed memory blocks`。
  - `test_http_benchmarks` 先失败在缺少 `status lines common errors` row
    与 known status-line source-contract：`35 total, 33 passed, 2 failed`，
    heaptrc `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_h1writer`：`34/34 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`35/35 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server`：`275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `status lines common errors = 1204.8 ns/op`
- 子代理只读复盘：
  - 第一梯队 status 是 `400/413/417/431/500/501`，第二梯队是 `404`；
    `101/204/304/100/103` 可以低成本同表覆盖。
  - 本轮 tests 直接覆盖 common status exact wire、unknown fallback 和 fixed `431`
    short-writer retry；server gate 覆盖响应路径集成语义。
- 复盘结论：
  方向没有走偏：这是 response writer 固定 status-line 成本削减，目标仍是提高
  HttpServer error/response 热路径性能。下一步应转向 llhttp adapter parsed-header
  insertion/materialization，或继续审计 writer/body path 中仍存在的 generic string allocation。

## 2026-06-06 http h1 writer compact header block slice

- 本轮把 `TH1ResponseWriter` 的 response header serialization 从“小 header line
  单行 coalescing”推进到“小 header section 整块 coalescing”。
- 选择依据：
  - 上一批 fast lazy header lookup 后，HTTP roadmap 仍处于 `6/6 Benchmark 与优化`
    的热路径降本阶段。
  - `WriteHeader` 当前仍是 status line、每条 header line、final CRLF 分开写；
    对常见小响应来说，header block write 调用数是可消除的固定成本。
  - 子代理只读审查确认本切片要保持 status line 独立、short-writer 全进度、
    informational response 不提交 final、large header fallback 写出前决策。
- 实现决策：
  - 新增 `WriteHeaderBlock` dispatcher；先调用 `TryWriteSmallHeaderBlock`，失败再回退
    `WriteAllHeaders` + `WriteCRLF`。
  - compact path 用 2048-byte stack buffer 聚合所有 header lines 与最终空行，并仍通过
    `WriteAllOrRaise` 写出，保留 short-write retry / zero-progress raise 语义。
  - large header block 在写出前回退旧逐行路径，避免 partial compact bytes 污染 wire。
  - `WriteInformationalHeader` 与 final `WriteHeader` 共用 header-block dispatcher，但
    informational 仍不设置 `FHeadersSent`。
- RED 证据：
  - `test_http_h1writer` 先失败在 small header block write-call count：
    `30 total, 29 passed, 1 failed`，heaptrc `0 unfreed memory blocks`。
  - `test_http_benchmarks` 先失败在缺少 `headers block 200 6 headers` benchmark row
    与 compact helper source-contract：`34 total, 32 passed, 2 failed`，
    heaptrc `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_h1writer`：`31/31 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`34/34 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server`：`275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `headers only 200 = 1280.4 ns/op`
  - `headers block 200 6 headers = 1890.9 ns/op`
- 子代理只读复盘：
  - 主要风险是 CRLF 边界、重复 header 顺序、short-writer 截断、non-101
    informational response 提交状态、101/204/304/HEAD no-body 语义。
  - 本轮 tests 覆盖 small-block exact wire/write count、large-block fallback exact wire，
    既有 h1writer/server gates 覆盖 informational/no-body/HEAD/chunked 语义。
- 复盘结论：
  方向没有走偏：这是 response writer 固定 write 调用成本削减，不是碎片化 inline。
  下一步应继续评估 H1 writer 非-200 status-line / generic string materialization 成本，
  或回到 llhttp adapter parsed-header insertion/materialization；跨语言正式 benchmark 仍后置。

## 2026-06-06 http h1 fast lazy header lookup slice

- 本轮把 `TFastLazyHeaders.Get` / `Has` 从“单次 lookup 也强制
  `EnsureMaterialized`”改为 raw header block first-value scan；`GetAll` /
  `ForEach` / `Count` / `Clone` / mutation 仍保留完整 materialization。
- 选择依据：
  - 上一批 request metadata cache 已去掉 parser metadata 二次扫 header 的固定成本；
    下一处高价值成本是 fast path request object 暴露 headers 时的单 header lookup。
  - 常见 handler/server policy 只读 `Host` 或少量 header，不应与全量 iteration
    支付同等 materialization 成本。
  - 子代理只读审查确认本切片应优先保持 case-insensitive name、`Get` 首值、
    empty-value `Has=True`、duplicate order、raw block 不变和 trailer 隔离。
- 实现决策：
  - 新增 `FindRawFirstValue`，按 raw header block 顺序查找首个匹配 header name。
  - `FastHeaderNameMatches` 仅做 ASCII case-fold，保持 fast parser 当前 header-name
    acceptance policy，不扩大到 Unicode 或复杂 normalization。
  - `Get` / `Has` 未 materialized 时不调用 `EnsureMaterialized`；materialized 后仍委托
    `THttpHeaders`。
  - `IsValidHeaderValueFast(ALen=0)` 必须直接返回 true，避免 `SizeUInt` 下 `ALen - 1`
    underflow 导致空 header value 误判非法。
- RED / debugging 证据：
  - `test_http_benchmarks` 先失败在 `TFastLazyHeaders raw first-value lookup helper`
    source-contract 缺失，heaptrc 为 `0 unfreed memory blocks`。
  - 新增 h1fast focused test 后先失败在 `lazy header semantic request should parse`；
    sentinel 诊断定位到空 value validation 分支，根因为 `ALen=0` unsigned loop-bound
    underflow。
- GREEN / behavior 证据：
  - `test_http_h1fast`：`23/23 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`33/33 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server`：`275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `adapter cost: fast headers get host only = 1466.4 ns/op`
  - `adapter cost: fast headers foreach all = 4678.8 ns/op`
- 子代理只读复盘：
  - fast parser 接受条件不应为普通重复 header 回退；真正回退仍限于
    transfer-coding、重复/非法 `Content-Length`、obs-fold、非法 header/name/value、
    incomplete body 等既有策略。
  - raw lookup 语义风险集中在 empty value、case-insensitive lookup、first-value
    order 和 materialization 后 duplicate order；本轮 focused test 已覆盖这些点。
- 复盘结论：
  方向没有走偏：本轮不是碎片化 inline，而是减少 H1 fast-path header access
  的实际 materialization 成本，并顺手修复一个空 header value correctness bug。
  下一步应继续处理 H1 writer/header serialization 或 llhttp adapter parsed-header
  insertion 成本；跨语言正式 benchmark 仍后置。

## 2026-06-06 http h1 parser request metadata cache slice

- 本轮把 H1 request metadata 从 headers-complete 后回扫 `IHttpHeaders`
  改为 header parse 阶段 pending cache，并在 headers-complete 校验通过后发布。
- 选择依据：
  - 上一批路径投影后，HTTP roadmap 已进入 `6/6 Benchmark 与优化` 的 adapter
    固定成本削减阶段。
  - 子代理审计确认 parser 当前 `BuildRequestMetadata` 会对 `Host`、`Connection`、
    `Content-Length`、`Expect`、`Transfer-Encoding` 做 `Get/GetAll` 二次扫描。
  - narrowed benchmark 中 legacy request metadata synthetic row 仍约 `1321.3 ns/op`，
    cached synthetic row 为 `6.1 ns/op`，说明这类固定成本值得先压。
- 实现决策：
  - `FPendingRequestMetadata` 作为 parser-owned cache，`FRequestMetadata` 仍只在
    headers-complete 校验通过后对外发布。
  - 新增 `Host` / `Connection` / `Content-Length` 首值 seen flags，保留 `Get`
    首值语义，避免空首值被后续重复 header 覆盖。
  - `Expect` 按重复 header 顺序增量归约；`Transfer-Encoding` 保存 combined string，
    仍在 headers-complete 统一执行 malformed / unsupported 校验，避免错误时机漂移。
  - trailer 阶段完全不更新 metadata cache，继续只统计 trailer bytes。
  - 不改 public `IHttpHeaders` store，不改 generated llhttp state machine，不改公开 API。
- RED 证据：
  - `test_http_benchmarks` 先失败在
    `H1 parser parse-time request metadata helper missing`。
  - 结果为 `32 total, 31 passed, 1 failed`，heaptrc 为
    `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_h1parser`：`94/94 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`32/32 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server`：`275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `adapter cost: request metadata legacy expect+cl = 1321.3 ns/op`
  - `adapter cost: request metadata cached expect+cl = 6.1 ns/op`
- 子代理只读复盘：
  - metadata cache 必须保护 `Get` 首值、`GetAll` 顺序、TE 错误分类和 trailer 隔离。
  - 下一批性能优先级建议为 fast-path header block 更细粒度 lazy access，其次是
    response writer/header serialization；router dispatch 暂缓。
- 复盘结论：
  方向没有走偏：本轮是 adapter 热路径固定成本削减，不是碎片化 inline。实现标准达到
  当前切片目标：source-contract 锁住不回扫，行为测试锁住高风险语义，server gate 锁住
  对外 wire contract。下一步应进入 fast lazy headers 按需命中，而不是继续扩大本 slice。

## 2026-06-06 http request path-only projection slice

- 本轮把上一批新增的 `Req.Path` / `Req.RawQuery` direct accessor 从“少复制
  `TUrl` record”推进成真正的 request-target path-only projection。
- 选择依据：
  - 上一轮 micro row 显示 direct `Path` 仍约 `710 ns/op`，说明仍在支付完整
    `TUrl.ParseRequestTarget` 成本。
  - `url_path` workload、router/static/middleware/H1 client writer 多数只需要
    path/query，不需要 scheme/host/port。
  - 这是比继续扩大 inline 更直接的 adapter/materialization 固定成本削减。
- 实现决策：
  - `THttpRequest` 新增内部 `EnsureRequestTargetParts`，只拆 `#` 与 `?` 后填
    `FUrl.Path` / `RawQuery` / `Fragment`。
  - absolute-form 仍回退 `EnsureUrlParsed`，所以 host/port validation 和
    `Req.Url` 完整语义不变。
  - `Req.Url` 继续完整 materialize；`QueryParam` 现在可基于轻量 RawQuery 解析，
    外部行为不变。
- RED 证据：
  - `test_http_benchmarks` 先失败在
    `THttpRequest request-target projection helper declaration missing`。
  - 结果为 `31 total, 30 passed, 1 failed`，heaptrc 仍是
    `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_message`：`19/19 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`31/31 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_router`：`21/21 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `request lazy Url.Path access = 779.9 ns/op`
  - `request direct Path access = 496.5 ns/op`
  - `request direct RawQuery access = 494.2 ns/op`
  - `request direct Path+RawQuery access = 542.6 ns/op`
  - `bench_server --requests 512 --threads 1 --workload url_path` 完成 `512/512`，
    `43622 ns/op`、`22923 req/s`
- 子代理只读复盘：
  - `Boyle` 认为方案方向正确，并建议补足 origin/absolute/asterisk/authority/relative
    target 边界；本轮已按建议补 compact matrix。
  - `Parfit` 认为本轮是当前最高优先级性能切片；下一批应转向 llhttp adapter
    request metadata parse-time cache，第三候选是 fast-path header block 按需物化。
- 复盘结论：
  方向没有走偏：这轮不是碎片化 inline，而是把 `url_path` 代表的公开 handler
  热路径从完整 URL materialization 中解耦。下一批不应继续扩同类 accessor，
  应处理 parser adapter metadata 二次扫 header 的固定成本。

## 2026-06-06 http direct outbound response path slice

- 本轮去掉 H1 server response path 中的额外 generic buffered writer：
  `TH1ResponseWriter` 现在直接写入 `IH1OutboundBuffer`，再由 server drain 到 socket
  或 poll runtime。
- 选择依据：
  - server 响应已经有协议专用 `IH1OutboundBuffer` 承担排队、backpressure、poll drain。
  - 再包一层 `TBufferedWriter` 会为每个请求增加一个对象和一层内存缓冲/flush，
    对 full-chain response path 没有必要。
  - 这个切片比继续盲目 inline 小 helper 更贴近 `HttpServer` full-chain 成本，
    同时不改变公开 API。
- 明确不改：
  - 不改 H1 client request writer；client 仍直接写 transport stream，generic buffered writer
    在那里仍是合理边界。
  - 不改 `TH1ResponseWriter` wire contract，不改 chunked/HEAD/no-body/hijack 语义。
  - 不触碰 dirty 的 `test_http_client.lpr` 和其他无关文件。
- RED 证据：
  - `test_http_benchmarks` 新增 source-contract 后先失败在
    `H1 server response path should write directly into IH1OutboundBuffer`。
  - 结果为 `30 total, 29 passed, 1 failed`，heaptrc 仍是
    `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_benchmarks` 后续为 `30/30 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server` 后续为 `275/275 passed`，heaptrc `0 unfreed memory blocks`
- 小 benchmark row：
  - `bench_fullchain plaintext`：`completed=5000`，`38134.9 ns/op`，`26223 req/s`
  - `bench_server response_1k`：`completed=512`，`35310 ns/op`，`28319 req/s`
  - 这两条是本机 smoke，不声明永久跨运行性能提升。
- 子代理只读审计结论：
  - 后续高价值候选优先级是 request-target path-only 投影、llhttp header materialization、
    fast lazy headers lookup、response writer 固定头部快路径。
  - 本轮 direct outbound response path 属于 response writer/drain 候选的底层降本，
    方向合理，但下一批应回到更显著的 request-target / header materialization 差距。
- 复盘结论：
  方向没有走偏：本轮是生产 hot-path 去冗余，不是碎片化治理；验证覆盖了 source-contract、
  threaded/epoll server behavior 和小 benchmark smoke。下一步应做 `Req.Path` origin-form
  path-only 快捷投影，或 llhttp parsed header insertion/materialization 降本。

## 2026-06-06 http request path direct-accessor slice

- 本轮把 `IHttpRequest` 从“只能通过 `Url` record 取 path/query”扩展为直接
  `Path` / `RawQuery` 访问器。
- 选择依据：
  - `url_path` server workload、router dispatch、static serving、middleware logging
    都只需要 path，不需要完整 `TUrl` record。
  - 直接 getter 保留旧 `Req.Url` 语义，但避免常见路径读取复制整个 `TUrl` record。
  - 这是公开接口完整性提升，也更接近 Go/Rust handler 里直接读 path/query 的使用范式。
- 接口决策：
  - `IHttpRequest` IID 从 `...000000000002` 更新到 `...000000010002`，因为 vtable
    增加了新成员。
  - 不删除 `Req.Url`，不改变 `QueryParam`，不引入第二套复杂 request-target cache。
- 本轮切换到 direct accessor 的内部调用点：
  router dispatch、static serving、logger/timeout middleware、H1 client request writer、
  `bench_server url_path` handler。
- RED 证据：
  `test_http_message` 先失败在 `Identifier idents no member "Path"` /
  `"RawQuery"`。
- GREEN / behavior / leak 证据：
  - `test_http_message`：`16/16 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_contract`：`29/29 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_router`：`21/21 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_middleware`：`11/11 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_middlewares`：`13/13 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_static`：`10/10 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_benchmarks`：`29/29 passed`，heaptrc `0 unfreed memory blocks`
  - `http_hello_server` example build passed
- 小 benchmark row：
  - `request lazy Url.Path access = 780.6 ns/op`
  - `request direct Path access = 710.0 ns/op`
  - `bench_server --requests 128 --threads 1 --workload url_path` 完成 `128/128`，
    `42179 ns/op`、`23708 req/s`
- 已知非本批阻塞：
  - `test_http_client` 当前在 shared dirty test file 中失败于
    `HttpGetToWriter` / `HttpGetToFile` 未实现，这是既有 HTTP client helper RED，
    不属于本轮 `Path` / `RawQuery` accessor 变更。
- 复盘结论：
  方向正确：这不是继续堆碎片 inline，而是把高频 handler/router path 访问提升成
  公共 API，并用 focused tests + microbenchmark 证明。下一步应继续找能影响 full-chain
  server row 的剩余 adapter/runtime 成本，而不是扩大同类 accessor。

## 2026-06-06 http header lookup hot-helper inline slice

- 本轮只处理 `THttpHeaders` lookup/normalize 热路径中的三个短 helper：
  `FindFirst`、`NeedsNormalize`、`NormalizeIfNeeded`。
- 选择依据：
  - `FindFirst` 是 `Get` / `Has` 的内部 concrete-call 热路径；server policy、
    writer header checks、handler 常用 header lookup 都会经过它。
  - `NeedsNormalize` 是 lowercase exact lookup fast path 的分支判断，函数体只是
    扫描是否存在大写 ASCII。
  - `NormalizeIfNeeded` 是 `Del` 等路径的短 wrapper，lowercase 输入直接返回原字符串。
- 本轮明确不改：
  - 不改 `IHttpHeaders` public API。
  - 不改 header 存储结构、大小写语义、validation 语义。
  - 不 inline `Normalize` / `NormalizeParsedNameSpan` 这类循环物化函数。
- RED 证据：
  `test_http_benchmarks` 新增 source-contract 后先失败在
  `THttpHeaders FindFirst inline declaration missing`；
  结果为 `29 total, 28 passed, 1 failed`，heaptrc 仍是 `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_benchmarks` 后续为 `29/29 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_headers` 后续为 `17/17 passed`，heaptrc `0 unfreed memory blocks`
  - `bench_headers` filtered `Get hit` 小 row：
    `Get hit (5 headers, last) = 48.9 ns/op`，
    `Get hit uppercase (5 headers, last) = 155.4 ns/op`
- 该 benchmark row 是小 smoke，不声明跨运行永久提升；本轮更重要的是锁住
  header lookup hot helper source shape，防止未来回退。
- 复盘结论：
  方向仍在 HttpServer 性能主线上；这轮比继续堆大 server benchmark 更有效，
  因为它用一个小 source-contract 固定了 server 内部高频 header lookup 形状。

## 2026-06-05 http h1 server policy-helper inline slice

- 本轮只处理 H1 server policy 决策路径中的三个短 helper：
  `ShouldKeepAlive`、`ParserErrorStatus`、`ShouldSendContinueResponse`。
- 选择依据：
  - `ShouldKeepAlive` 位于 threaded / poll keep-alive 决策路径，函数体只是 metadata
    读取加 HTTP/1.0/1.1 分支。
  - `ParserErrorStatus` 位于 parser-error 直接响应路径，函数体只是 error-kind 到
    status 的小 case。
  - `ShouldSendContinueResponse` 位于 headers-complete 后的 `Expect: 100-continue`
    决策路径，函数体是 metadata 快照加布尔判断。
- 本轮明确不 inline：
  - `HeaderPolicyErrorStatus`：包含 size policy、Host、Expect、MaxBodySize 等多分支，
    应保持普通 helper，避免代码膨胀。
  - `TH1ServerConnectionState.*` 大型状态机方法：继续保持非 inline。
  - `h1.scan` SIMD 扫描函数：函数体较大，盲目 inline 可能增加 icache 压力。
- RED 证据：
  `test_http_benchmarks` 新增 source-contract 后先失败在
  `H1 server ShouldKeepAlive inline implementation missing`；
  结果为 `28 total, 27 passed, 1 failed`，heaptrc 仍是 `0 unfreed memory blocks`。
- GREEN / behavior 证据：
  - `test_http_benchmarks` 后续为 `28/28 passed`，heaptrc `0 unfreed memory blocks`
  - `test_http_server` 后续为 `275/275 passed`，heaptrc `0 unfreed memory blocks`
  - `bench_server --requests 128 --threads 1 --workload adapter_no_url`
    完成 `128/128`，row 为 `42022 ns/op`、`23797 req/s`
- 该 benchmark row 是小 smoke，只证明 fast-path server benchmark 仍可完成；
  不能声明跨语言或跨运行性能提升。
- 复盘结论：
  这轮是窄性能卫生切片，方向正确：用 source-contract 锁住高频短 helper，
  同时避免把大 policy evaluator / state-machine / SIMD scanner 硬 inline。

## 2026-06-05 http h1 outbound hot-helper inline slice

- 本轮只处理 H1 outbound response-drain 热路径的一个窄切片：
  `TH1OutboundBuffer.PendingBytes`、`IsEmpty`、`Advance`。
- sidecar 复核结论：
  - `PendingBytes` 适合 inline：只是 `FWritePos - FReadPos`，且在
    `Compact`、`EnsureCapacity`、`DrainAllTo`、`TryDrainTo` 中频繁调用。
  - `Advance` 适合 inline：每次 drain 成功写出后都会走，快路径是
    `Inc` 加少量分支；`Reset` / `Compact` 是冷分支。
  - `IsEmpty` 可 inline：主要是 public convenience 与 server poll 状态机判空，
    收益低于前两者，但函数体极短。
  - `Compact` 不 inline：包含 `Move` 与状态重排，属于冷路径，inline 会增加代码膨胀。
  - `EnsureCapacity` 不 inline：包含扩容策略、循环、`SetLength` 与 `Compact`，
    后续若优化应拆 slow path，而不是整段 inline。
- 初次只加 `inline` 后，`bench_h1outbound` clean build 暴露 FPC note：
  `PendingBytes` 在实现体声明前被调用时出现 “marked as inline is not inlined”。
  本轮因此把 `PendingBytes` / `IsEmpty` 实现提前到 `Compact` / `EnsureCapacity`
  之前，focused build 不再出现该 note。
- 这轮不把 `-Si` / `{$INLINE ON}` 上升为全局策略；项目中已有大量 inline 标注，
  全局编译选项是否需要强化应单独建 batch，用 source-contract、focused benchmark
  和 warning/note gate 一起验证。
- RED 证据：
  新增 `H1 outbound hot helpers inline source contract` 后，
  `test_http_benchmarks` 先失败在缺少
  `procedure Advance(const ACount: SizeUInt); inline;`，同时 heaptrc 仍为 0 unfreed blocks。
- GREEN / benchmark 证据：
  `test_http_benchmarks` 后续为 `27/27 passed`，`heaptrc: 0 unfreed memory blocks`；
  `bench_h1outbound buffer write+drain 1KB` 本机单次 row 为 `283.1 ns/op`、
  `3532176 ops/s`。该 row 只作为方向性观测，不声明永久性能排名。
- 下一批性能候选应优先从 sidecar 筛出的 H1 fast parser helpers、header lookup、
  writer status/header path、URL materialization、body reader/copy focused rows 中选一个，
  不手改生成 llhttp 状态机，不动大型 server state-machine 函数。

## 2026-06-05 http benchmark completion-marker contract

- server comparison 之前虽然输出 `iterations`、`ns/op`、`req/s`，但 summary
  层没有强制证明 comparator 实际完成了目标请求数；这会让部分请求失败或短读时的
  速度数字失去解释力。
- 本轮把 harness contract 收紧为：
  - 每个 raw row 必须含 `iterations=<requests>` 与 `completed=<requests>`
  - runner 会拒绝 `iterations` 或 `completed` 不等于目标请求数的 row
  - summary/report 输出 `median_completed=<requests>`
  - nextPas raw row 额外输出 `nextpas_h1_path=fast`，当前 no-body HTTP/1.1
    workload 的 fast-path 解释不再只靠 workload 名称推断
- 实现上没有改生产 HTTP server；只改 benchmark binary / runner / focused benchmark tests。
- 一个修复点是 `run_server_comparison.sh` 的 awk `printf` 参数顺序：
  `median_completed` 必须取 completed 列，而不是误取 `ns/op` median。
- focused gate 结果：
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26/26 passed`，`heaptrc: 0 unfreed memory blocks`。
- live smoke 结果：
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 8 --threads 1 --workload adapter_no_url --runs 2 --output build/projects/nextpas.core.http/server_comparison/adapter_no_url_completed_smoke.txt`
  -> nextPas/Go/Rust std-only raw rows 均有 `completed=8`，nextPas rows 有
  `nextpas_h1_path=fast`，summary rows 均有 `median_completed=8`。
- 复盘结论：这轮仍属于 benchmark harness correctness，不是生产性能优化；下一轮性能优化应基于更可信的 harness，优先审计 H1 热路径小函数 `inline`、URL materialization、response writer/drain、以及 Pascal llhttp adapter raw gap。

## 2026-06-04 http max-header 431 backpressure security proof

- `test_http_security` 之前已经有 generic `MaxHeaderSize` 两条正向 raw-wire
  `431` 证据：普通 header field over limit 与 request-target over limit
  都会返回显式 `431`；`test_http_server` 也已锁住更窄的 server-layer
  “不进入 handler” 语义。
- 但 security 层此前仍缺这两条 direct-error 在 real-socket backpressure
  尝试下的 safe-close 直接证据，也就是：
  - 连接仍会在观察窗口内安全关闭
  - wire 上至多暴露单一原始 `431` status-line 前缀
  - 不会追加 synthetic `500`
- 本轮在 `test_http_security` 新增 threaded / Linux `epoll` 四条 live proof，
  直接锁定：
  - `header field over MaxHeaderSize -> 431` 的 backpressure safe-close
  - `request-target over MaxHeaderSize -> 431` 的 backpressure safe-close
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test`
  结果为 `198/198 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：generic `MaxHeaderSize`
  的两条 `431` direct-error runtime contract 与当前实现 truth 一致。

## 2026-06-04 http write-timeout follow-up suppression trio

- `HttpServer` 的 real-socket write-timeout/backpressure live proof
  之前只直接锁了 follow-up malformed `400` 与 follow-up unsupported
  transfer-coding `501` 不会误漏到 wire；同一运行时风险面的
  follow-up `413 Payload Too Large`、`431 Request Header Fields Too Large`
  与 `417 Expectation Failed` 还缺 live 证据。
- 本轮在 `test_http_server` 新增 threaded / Linux `epoll` 六条 live proof，
  直接锁定：
  - 当首个大响应已开始排出、连接因 backpressure 命中 `WriteTimeout`
    而关闭时，后续 follow-up `413/431/417` 不会误漏到 wire
  - wire 上仍只保留首个 `200` status line，不会追加第二条状态行
  - 首个请求仍只会处理一次
- focused gate `make -C tests/nextpas.core.http/test_http_server clean test`
  结果为 `228/228 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：这组三条
  write-timeout/backpressure runtime contract 与当前实现 truth 一致。

## 2026-06-04 http truncated trailer field-line backpressure proof

- `truncated trailer field line EOF` 之前在 `test_http_h1parser` 已有 parser error
  focused proof，在 `test_http_server` 也已有 explicit `400` / poll-driven writable-drain
  证据，但 `test_http_security` 还缺 real-socket direct raw-wire/backpressure 直接证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - chunked trailer field line 在 EOF 截断时会直接返回 final `400 Bad Request`
  - 在 backpressure 尝试下，连接仍会安全关闭
  - wire 上至多暴露一条原始 `400` status-line 前缀，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test`
  结果为 `194/194 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：这条 malformed trailer EOF
  路径在 security 层也已有 direct raw-wire/backpressure proof。

## 2026-06-04 http standalone 413 direct-error backpressure proof

- `payload-too-large direct 413` 之前在 `test_http_server` 已有 poll-driven
  direct-error timed drain proof，也已有 queued follow-up `413` 的
  real-socket wire-order proof，但 `test_http_security` 还缺 standalone direct
  raw-wire/backpressure 直接证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - fixed-length body 超过 `MaxBodySize` 时会直接返回 final
    `413 Payload Too Large`
  - 在 backpressure 尝试下，连接仍会安全关闭
  - wire 上至多暴露一条原始 `413` status-line 前缀，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test`
  结果为 `192/192 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：standalone direct `413`
  路径在 security 层也已有 direct raw-wire/backpressure proof。

## 2026-06-04 http partial chunked body idle-timeout proof

- request-side `IdleTimeout` 之前已经覆盖了 slowloris、partial fixed-length body、
  partial chunk-size line、partial chunked trailer，但还缺 `chunked body`
  数据段本身半包 stall 的 live truth。
- 本轮新增 security + server 两层 focused proof，直接锁定：
  - `chunked body` 在 chunk-size 已完成、chunk-data 尚未收齐时发生 stall，
    最终也会沿用同一 request-side deadline 安全关闭
  - 连接关闭前不会误进入成功 handler，也不会返回成功响应
  - poll-driven seam 同样保持 `WakeDeadline` 收口与 timeout-close 语义一致
- focused gates 结果为：
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    -> `190/190 passed`, `heaptrc: 0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    -> `222/222 passed`, `heaptrc: 0 unfreed memory blocks`
- 结论仍然是 coverage-expansion，不是生产修复：`partial chunked body stall`
  的 request-side timeout contract 与现有 runtime truth 一致。

## 2026-06-04 http malformed chunked direct-error backpressure trio

- `invalid chunk-size`、`missing chunk-data CRLF`、`malformed trailer field`
  之前都已有 parser focused proof、server focused live proof、以及 poll-driven writable-drain truth，
  但 `test_http_security` 还缺 threaded / Linux `epoll` real-socket direct-error/backpressure
  直接证据。
- 本轮新增 threaded / Linux `epoll` 六条 security proof，直接锁定：
  - 这三个 malformed chunked case 都会直接返回 final `400 Bad Request`
  - 在 backpressure 尝试下，连接仍会安全关闭
  - wire 上至多暴露一条原始 `400` status-line 前缀，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `188/188 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：这组三个 malformed chunked
  direct-error 路径在 security 层也已有 direct raw-wire/backpressure proof。

## 2026-06-04 http chunked-not-final backpressure security proof

- `Transfer-Encoding: chunked, gzip` 这条 malformed chunked framing 之前已有
  parser focused proof、server focused live proof、以及 poll-driven writable-drain proof，
  但 `test_http_security` 还缺 threaded / Linux `epoll` real-socket direct-error/backpressure
  直接证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - `Transfer-Encoding: chunked, gzip` 会直接返回 final `400 Bad Request`
  - 在 backpressure 尝试下，连接仍会安全关闭
  - wire 上至多暴露一条原始 `400` status-line 前缀，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `182/182 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：`chunked`-must-be-final malformed framing
  在 security 层也已有 direct raw-wire/backpressure proof。

## 2026-06-04 http expect bodyless and duplicate-member security proof

- `Expect: 100-continue` 的 duplicate-member 正向 interim 行为，以及 bodyless / no-length
  变体的 no-interim 合同，之前在 `test_http_server` 已有 focused live 证明，但
  `test_http_security` 还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两组 security proof，直接锁定：
  - `Expect: 100-continue, 100-continue` 仍会先返回单条 interim `100 Continue`，
    且 body 到达前不会误进 handler
  - `Content-Length: 0 + Expect: 100-continue`、普通 no-length `POST + Expect: 100-continue`、
    以及 no-length `HEAD + Expect: 100-continue` 都不会误发 interim `100 Continue`
  - no-length `HEAD` 变体仍保持 bodyless wire contract
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `180/180 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：这组 `Expect` request-side public contract
  在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http queued follow-up 400 security proof

- `malformed follow-up 400 preserves wire order` 之前在
  `test_http_server` 已有 real-socket/backpressure live 证明，但 `test_http_security`
  还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 首个 `200 OK` 响应会先开始排出
  - follow-up `400 Bad Request` 会保持在首个响应 body 之后
  - wire 上只暴露两条 status line，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `172/172 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：queued follow-up `400`
  的 wire-order contract 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http queued follow-up 413 security proof

- `payload-too-large follow-up 413 preserves wire order` 之前在
  `test_http_server` 已有 real-socket/backpressure live 证明，但 `test_http_security`
  还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 首个 `200 OK` 响应会先开始排出
  - follow-up `413 Payload Too Large` 会保持在首个响应 body 之后
  - wire 上只暴露两条 status line，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `170/170 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：queued follow-up `413`
  的 wire-order contract 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http queued follow-up 431 security proof

- `header-too-large follow-up 431 preserves wire order` 之前在
  `test_http_server` 已有 real-socket/backpressure live 证明，但 `test_http_security`
  还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 首个 `200 OK` 响应会先开始排出
  - follow-up `431 Request Header Fields Too Large` 会保持在首个响应 body 之后
  - wire 上只暴露两条 status line，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `168/168 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：queued follow-up `431`
  的 wire-order contract 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http queued follow-up 417 security proof

- `unsupported Expect follow-up 417 preserves wire order` 之前在
  `test_http_server` 已有 real-socket/backpressure live 证明，但 `test_http_security`
  还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 首个 `200 OK` 响应会先开始排出
  - follow-up `417 Expectation Failed` 会保持在首个响应 body 之后
  - wire 上只暴露两条 status line，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `166/166 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：queued follow-up `417`
  的 wire-order contract 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http queued follow-up 501 security proof

- `unsupported transfer-coding follow-up 501 preserves wire order` 之前在
  `test_http_server` 已有 real-socket/backpressure live 证明，但 `test_http_security`
  还缺 direct raw-wire 证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 首个 `200 OK` 响应会先开始排出
  - follow-up `501 Not Implemented` 会保持在首个响应 body 之后
  - wire 上只暴露两条 status line，不会追加 synthetic `500`
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `164/164 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：queued follow-up `501`
  的 wire-order contract 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http expect chunked security proof

- `Expect + Transfer-Encoding: chunked` 的正向与 after-interim size-limit live contract 之前在
  `test_http_server` 已有 focused 证明，但 `test_http_security` 还缺 raw-wire 直接证据。
- 本轮新增 threaded / Linux `epoll` 两组 security proof，直接锁定：
  - `Expect + chunked` 会先返回单条 interim `HTTP/1.1 100 Continue`
  - chunked body 到达前不会误进入 handler，也不会提前返回 final `200`
  - 完整 chunked body 送达后才返回 final `200`，且 handler 看到的是解码后的 body
  - 如果在收到 interim `100` 后 chunked ingress 跨 chunk 超过 `MaxBodySize`，最终会返回 final
    `413 Payload Too Large`，且不会进入 handler
- 初次 RED 来自新测试自身的 header 写入长度硬编码，不是生产实现缺陷；修正测试 helper 后，focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `162/162 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：当前 runtime truth 与 server 套件一致，
  `Expect + chunked` 正向/after-interim `413` 在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http expect positive-flow security proof

- `Expect: 100-continue` 的正向 live contract 之前在 `test_http_server` 已有 focused 证明，
  但 `test_http_security` 还缺 raw-wire 直接证据。
- 本轮新增 threaded / Linux `epoll` 两条 security proof，直接锁定：
  - 先返回单条 interim `HTTP/1.1 100 Continue`
  - 在 body 送达前不会误进入 handler，也不会提前返回 final `200`
  - body 送达后再返回 final `200`，且 handler 能看到完整 request body
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `158/158 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：当前 runtime truth 与 server 套件一致，
  `Expect` 正向路径在 security 层也已有 direct raw-wire proof。

## 2026-06-04 http expect early-reject security proof

- `Expect` 相关 early-reject contract 在 server 层已有 focused live proof，但 security 层此前还缺两条高价值 raw-wire 直接证据：
  - `Expect: 100-continue + declared oversize Content-Length -> final 413 without interim 100`
  - `repeated Expect headers + unsupported member -> final 417 without interim 100`
- 本轮把 threaded / Linux `epoll` 两条 live 路径都补进 `test_http_security` 后，focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `156/156 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：这两条 `Expect` early-reject 路径都会直接返回单一 final status-line，
  不会误发 interim `100 Continue`，也不会误落到 `200` 成功响应。

## 2026-06-04 http unsupported-expect backpressure proof

- `unsupported Expect -> 417` 属于 request-side early-reject / direct-error contract，server 层已有 focused proof，
  但 security 层此前还缺 raw-wire/backpressure 直接证据。
- 本轮把 threaded / Linux `epoll` 两条 live 路径都补进 `test_http_security` 后，focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `152/152 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：在 backpressure 尝试下，
  `unsupported Expect` 的 direct-error 路径会保持原始 `417 Expectation Failed` status-line 前缀，
  不会误进 `200`、不会追加 synthetic `500`，并会安全关闭连接。

## 2026-06-04 http fixed-length eof truncation epoll parity

- `Truncated Content-Length request body at EOF` 是 fixed-length request-body framing 的高价值边界，
  不能只停留在默认 backend raw-wire proof；Linux `epoll` 也需要直接证据。
- 本轮补上 `epoll` case 后，focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `150/150 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：threaded / Linux `epoll` 两条 raw-wire ingress
  路径都会把 fixed-length request body EOF truncation 直接收口成 explicit `400`。

## 2026-06-04 http request validation epoll parity

- 这批 case 属于 request-side validation / malformed raw-wire ingress 边界，不能只停留在默认
  backend live proof；Linux `epoll` 也需要直接证据。
- 本轮补上的 `epoll` proof 包括：generic malformed request、`HTTP/1.1 missing Host`、
  `HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`null-byte header`、
  very long method、以及 `Content-Length + Connection: close + extra bytes after body`。
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `149/149 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：threaded / Linux `epoll` 两条 raw-wire ingress
  路径都会把这组 request validation / malformed input 直接收口成 explicit `400`。

## 2026-06-04 http eof truncation epoll parity

- request-line EOF truncation 与 headers EOF truncation 是 request parser 边界，不应只停留在默认
  backend live proof；Linux `epoll` raw-wire ingress 也需要直接证据。
- 这轮新增两条 `epoll` proof 后，`make -C tests/nextpas.core.http/test_http_security clean test`
  结果为 `142/142 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍是 coverage-expansion，不是生产修复：threaded / Linux `epoll` 两条 ingress 路径都会把
  request-line/header EOF truncation 判成 explicit `400`。

## 2026-06-04 http content-length validation epoll parity

- `duplicate Content-Length` 与 `negative Content-Length` 属于 request header validation /
  request smuggling 邻接安全边界，不应只停留在默认 backend live proof。
- 这轮把两条 `epoll` raw-wire proof 补进 `test_http_security` 后，
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `140/140 passed`，`heaptrc: 0 unfreed memory blocks`。
- 结论仍然是 coverage-expansion，不是生产修复：threaded / Linux `epoll` 两条 ingress 路径
  都会把 duplicate/negative `Content-Length` 直接判成 explicit `400`。

## 2026-06-04 http cl-te epoll smuggling proof

- `Content-Length + Transfer-Encoding: chunked` 是 request smuggling 边界，不能只停留在默认 backend
  live proof；Linux `epoll` 也需要 raw-wire 直接证据。
- 本轮新增 `CL+TE` 与 `TE+CL` 两种 header 顺序的 `epoll` proof 后，
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `138/138 passed`，`heaptrc: 0 unfreed memory blocks`。
- 这仍是 coverage-expansion，不是生产修复；当前 truth 是 threaded / Linux `epoll` 两条
  raw-wire ingress 路径都会把 CL/TE conflict 判为 explicit `400`。

## 2026-06-04 http chunked max-body epoll parity

- `Chunked MaxBodySize rejects before terminal chunk` 原先在 `test_http_security` 只有默认 backend
  raw-wire proof；Linux `epoll` 这条更接近公开 limit contract 的 live parity 仍缺。
- 这轮补上 `epoll` case 后，focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `136/136 passed`，`heaptrc: 0 unfreed memory blocks`。
- 因此这条同样是 coverage-expansion，不是生产修复。当前 truth 可以更明确地写成：
  chunked ingress 跨 chunk 越过 `MaxBodySize` 时，threaded / Linux `epoll` raw-wire 路径都会在
  terminal chunk 到达前直接返回 explicit `413`，且不会泄漏 handler 成功响应。

## 2026-06-04 http malformed chunk extension epoll parity

- `Malformed chunk extension -> 400` 原先在 parser focused coverage 与 threaded live coverage 都有证据，
  但 `test_http_security` 少了一条 Linux `epoll` raw-wire parity proof。
- 这条缺口补上后，没有暴露新的实现问题：focused gate
  `make -C tests/nextpas.core.http/test_http_security clean test` 为 `135/135 passed`，
  `heaptrc: 0 unfreed memory blocks`。
- 因此本轮仍然是 coverage-expansion，不是生产修复；当前 truth 可明确为：
  malformed chunk extension 在 threaded / Linux `epoll` raw-wire ingress 上都返回 explicit `400`。

## 2026-06-04 http fixed-length 413 proof tightening

- 这轮 fixed-length `MaxBodySize` 更像 public runtime contract 收口，而不是生产修复：
  上一刀 `test_http_server` 已经把 server 侧 truth 收紧为 explicit `413`，这轮补跑
  `test_http_security` 后也证明 raw-wire / security 侧 current truth 一致。
- fixed-length oversize body 现在有两层 focused 证据：
  - `test_http_server`
    - threaded 路径直接断言 `HTTP/1.1 413`
    - 新增 handler-not-called 断言
    - Linux `epoll` backend 同步锁定同一契约
  - `test_http_security`
    - raw-wire request 直接断言 `HTTP/1.1 413`
    - 明确排除 `HTTP/1.1 200`
    - Linux `epoll` backend 同步锁定同一契约
- focused gate `make -C tests/nextpas.core.http/test_http_security clean test` 结果为
  `134/134 passed`，`heaptrc: 0 unfreed memory blocks`；因此这刀没有暴露需要落生产修复的新缺口。
- 这轮之后，`MaxBodySize` 对外契约可以更明确地表述为：
  - fixed-length body：超限时 explicit `413`，且不进入 handler
  - chunked body：跨 chunk 累加一旦越限，立即 final `413`
- 下一刀应回到 malformed chunked request security 的剩余 raw-wire 边角，而不是继续复制
  fixed-length / chunked 的同型 parity case。

## 2026-06-04 compiler worktree/branch cleanup classification

- 当前 6 条目标里没有“已合并可删”的分支：全部都不是 `tip ∈ main`，`git cherry -v main <branch>`
  也没有显示为全部 patch-equivalent。
- 当前主升级线应收敛到 `codex/compiler-c8-np-allocator-20260604`，因为它包含
  `codex/compiler-truth-integration-20260604-main0915` 的 4 个已提交 C6-A/C8 控制提交，并且
  worktree 内路线已推进到 `C6-A / C8-F`。
- 但 `codex/compiler-c8-np-allocator-20260604` 现在不是可直接合并状态：
  - `main...branch = 54:12`
  - worktree 有未提交 compiler/sema/parser/toolchain/test/control-doc 改动
  - 还有 `compiler/tests/test_dynlibs_contract.pas`、`test_typinfo_contract.pas`、
    `test_variants_contract.pas`、target `Dynlibs/TypInfo/Variants` facade 等 untracked 文件
  - 已有计划记录显示 latest live gate 是 `vecdeque` 从 `357` diagnostics 收敛到 `24` diagnostics，
    但这些结论还没有作为干净 commit 进入 `main`
- `codex/compiler-truth-audit-main-20260603` 仍是有价值的 committed truth lane：
  - `main...branch = 172:18`
  - worktree clean
  - 其内容集中在 `build/verify_local.sh`、stage0/toolchain route truth、GNU/LLVM comparison 与 docs
  - 它不是可删 side lane；后续应把其有效 committed commits 吸收到单一升级线，而不是整条盲 merge
- `codex/compiler-truth-integration-20260604-main0915` 是有价值但混乱的中间集成草稿：
  - `main...branch = 54:4`
  - committed HEAD 已被 C8 allocator 分支包含
  - worktree 仍有 staged audit/toolchain absorption 与 unstaged `build/verify_local.sh` /
    `compiler/ir/np_hir_builder.pas`
  - 后续不能直接删除，必须先确认 staged 草稿是否已进入 C8 或应转成干净提交
- `fix/sema-include-resolver` 暂列“不确定”：
  - `main...branch = 1540:1`
  - 单提交很旧，但 patch 没被 C8 patch-equivalent 吸收
  - 它硬编码 include search paths，并把 imported source 截到 interface section；这可能与当前 C8 的
    imported-unit body / implicit-self 语义 truth 冲突，也可能仍有 include resolver 价值
  - 正确动作是针对当前 C8 imported-source path 做 focused review，不整支 merge
- `backup/accidental-mixed-commit-20260603` 应 archive：
  - 单提交同时包含 compiler structured ordinary member calls 与 core HTTP/net server 代码
  - compiler ordinary/dispatched call work 在当前路线图已有 C5-N/O/P 记录；core HTTP/net server 不属于本轮 compiler cleanup
  - 不应拆都不拆就进入 main
- `backup/sema-no-matching-overload-before-rebase` 应 archive：
  - 该线是旧 rebase 前 semantic backup
  - 当前 `main` 与 C8 worktree 已有大量 `no matching overload` / `wrong-argument-count` /
    `ambiguous-overload` coverage 与 diagnostics code
  - 保留 archive 价值即可，不建议合并旧分支

## 2026-06-04 local branch cleanup

- VSCode 当前让人感觉“分支还很多”，主要原因不是 worktree 没清掉，而是本地 branch ref 还保留了很多。worktree cleanup 和 branch cleanup 是两件事。
- 本轮开始前的真实状态是：
  - live worktree `4` 个
  - 本地分支 `96` 个
- 这里再次暴露出一个实时状态变化点：earlier notes 里记录的是 3 个 live worktree，但重新执行 `git worktree list --porcelain` 后发现
  `codex/window-sdl2-backend-20260602` 当前也在 live worktree 上，因此后续任何清理都必须以 fresh Git state 为准。
- 安全删除本地分支的第一条规则是：只删 `tip` 已在 `main` 里的 branch ref。按这个标准，本轮一次性删掉了 `43` 个 merged local branches。
- 删除这些 merged branches 不会丢代码；删掉的只是本地引用名，提交已经被 `main` 保住。
- 第二条安全压缩规则是：虽然 branch 还没进 `main`，但如果它已被另一个保留分支完整包含，也可以删除 branch ref 而不丢代码。
- 本轮唯一满足“被别的保留分支完整包含”的是 `feat/platform-pty`：
  - `git merge-base --is-ancestor feat/platform-pty codex/platform-pty-integration` 为真
  - 反向不成立
  - 因此 `feat/platform-pty` 只是 PTY integration 线的冗余基线 ref，可安全删除
- `git branch -d feat/platform-pty` 被 Git 拒绝不是因为不安全，而是因为 `-d` 只认“是否已并入当前 HEAD/main”；对这种“已被另一条未合并分支完整包含”的情况，需要在祖先关系取证后用 `-D` 删除 ref。
- `git cherry -v main <branch>` 进一步筛出了第二类安全删除对象：输出全为 `-` 的 branch 虽然不满足“ancestor merged into main”，但其提交补丁已被 `main` 等价吸收。
- 按这个标准，本轮又删除了 `28` 个 patch-equivalent branches，包括：
  - `fix/resolver-diagnostic-isolation`
  - 一整批 `worktree-*` 临时分支
  - `worktree-sysutils-*` 三条阶段分支
- 对这种 patch-equivalent 分支，`git branch -d` 同样可能误报“not fully merged”；因为 Git 看的仍是祖先关系，不是 patch-id 等价。这里删除 ref 的安全证据来自 `git cherry`，不是 `git branch --merged`。
- `docs/cross-module-workflow` 后续也已删除：
  - 相对 `main` 只有一个 docs commit
  - earlier audit 已确认这条文档包含危险的 `git reset --hard` 回退建议，不是应保留资产
- `codex/io-cursor-csv-streaming` 后续也已删除：
  - 相对 `codex/data-format-streaming-ini` 只剩一条 docs commit `docs(http): plan phase 2 runtime hardening`
  - 其余实质代码已被 `codex/data-format-streaming-ini` 吸收，因此保留两个 branch ref 只会制造列表噪音
- 本轮 branch cleanup 后，本地分支数从 `96` 降到 `22`。
- 剩余 `22` 个分支里：
  - `main` 是唯一已 merged branch
  - 其余 `21` 个都还没并进 `main`
  - 这意味着 easy/safe bulk delete 已基本做尽，接下来必须回到逐条价值判断
- 当前仍保留的非主线分支里，至少这几条因为 live worktree 或用户约束而不能碰：
  - `codex/compiler-truth-audit-main-20260603`
  - `codex/window-sdl2-backend-20260602`
  - `fix/sema-include-resolver`

## 2026-06-04 worktree merge audit batch 1

- 本轮目标不是看 worktree 是否 `clean`，而是确认相对 `main` 是否还有独有提交值得合并。
- `clean` 只表示 worktree 没有未提交改动；它不说明分支是否已并入 `main`，也不说明提交是否已被别的 lane 吸收。
- root checkout 的 `git status` 受到 repo 内 `.claude/worktrees/`、`.worktrees/` 和 `core-tui-migration/` 目录影响；审查时必须按 worktree 路径逐个取证，不能直接把 root 脏状态当成某个待合并 lane 的证据。
- `perf/chacha20poly1305-fused-scout` 的 planning files 已明确把该线定义成 scout/probe：internal streaming scout 可保留，但 benchmark 没显示正收益，因此 production 继续 default-off。它属于“已验证的研究脚手架”，不是“主线缺失的功能”。
- `codex/collections-refactor` 只有 2 个独有提交，主体是 facade re-export 与 focused test；但第二个提交把 iterator aliases 也公开到 facade，这扩大了 public surface，价值高于体量，因此不能不审就整支 merge。
- `codex/compiler-truth-audit-main-20260603` 自证为 canonical compiler truth lane：它不是旧 side lane 的重复物，而是吸收 side lane 后继续推进的主线，仍有 17 个未进 `main` 的独有提交，涉及 `build/verify_local.sh`、`tools/stage0`、HIR/tests 与 route truth docs。
- `codex/config-branch-triage-20260604` 在本轮审查中发现 live state 已变化：最初 worktree 清单里有它，但复查时 worktree 和 branch ref 都已消失，只剩一个 dangling docs-only commit。这说明整理 worktree 时必须以“重新查询当前 Git 状态”为准，不能只靠上一次列表截图。
- `codex/core-strict-review-20260601` 不是单一功能分支，而是 125 commit 的长期 strict-review 汇流线；最新 tip 虽然是 Process final proof closeout，但整线仍覆盖 log/async/io/process/platform/fs 等多个主题。整体 merge 风险远高于逐批摘取。

## 2026-06-04 full worktree triage

- 用户在本轮后续明确收紧范围：编译器 worktree 交给同事处理，因此后续 triage 只继续覆盖非编译器线。
- 用户当前目标不是“把 worktree 删干净”，而是“先把值得保留的代码审过并安全合回主线，再清理 worktree”。因此清理动作必须从属于代码审计结论，而不是反过来为了目录干净牺牲代码判断。
- 这轮的安全标准不是 branch 名字或提交新旧，而是：
  - 改动范围是否清晰
  - branch 自身是否有 focused verification 证据
  - public surface 是否被无意扩大
  - 是否只是默认关闭的实验/scout 代码
  - 是否已经被别的 canonical lane 吸收
- `codex/data-format-streaming-ini` 基本吸收了 `codex/io-cursor-csv-streaming` 的实质代码：反向 `git cherry` 只剩 `docs(http): plan phase 2 runtime hardening` 这一条 `io-cursor` 独有提交。后续应把它们当“升级线 + 残余 docs commit”处理，而不是两条并列功能线。
- 基于上面的关系，`codex/io-cursor-csv-streaming` 没必要继续占一个 live worktree；保留 branch ref 供后续决定那条 docs commit 的去留就够了。
- PTY 现在至少有三条线：
  - `feat/platform-pty`：干净的基础功能线；
  - `codex/platform-pty-main-merge`：对 `feat/platform-pty` patch-equivalent 的重复线；
  - `codex/platform-pty-integration`：在基础 PTY 之上继续叠加 main refresh 和额外改动的 dirty 线。
    因此后续清理时不应同时保留前两条 clean 线。
- TLS 组并不是简单的“final 完全覆盖 base/refresh”。反向 `git cherry` 证明 base/refresh 还各自带着 5 个 final 没有的 TLS/time/helper 命名相关提交，所以不能只因为有 `final` 就把另外两条直接删掉。
- `docs/cross-module-workflow` 虽然只是文档，但它引导了危险的临时回退方式（`git reset --hard`），不适合未经修订直接进主线。
- `crypto-polish` 的工作树脏状态不是新源码，而是 planning files 和测试产物；这类 worktree 清理优先级高，因为继续保留只会污染根 checkout 观察结果。
- `crypto-polish` 的 live 复核再次确认了上面的判断：dirty files 只有 planning markdown 与一串已编译测试二进制，没有任何 `.pas` 源码差异，因此可以 force remove worktree checkout 而不必担心漏掉代码。
- `fpdev-core-copydir` 的第三个提交 `90306fd6 feat(hash): add file hex helpers` 不是“冲突没处理完”，而是当前主线早已通过等价提交 `1fbef90c feat(hash): add file hex helpers` 吸收了相同源码/测试；因此在 integration branch 上 cherry-pick 变空是正确结果。
- `codex/collections-refactor` 剩余真正有价值的部分不是再导出一遍 facade public types，而是补一个 focused facade test，证明 `TCollectionClass` / `TPtrIter` 这些当前已在 `main` 的导出确实可从 facade 解析。
- `codex/datetime-now` 的 committed 实现线已经过时：
  - current `main` 已同时提供 `DateTimeNow` 和 `DateTimeUtcNow`
  - `x509verify` 当前使用 `nextpas.core.time.DateTimeUtcNow`
  - dirty worktree 中那句 “DateTimeNow - UTC-shaped wall clock time” 注释与 current main 语义不符，因为 current `DateTimeNow` 已带本地 UTC offset
    因此这条线只能摘测试，不能再回收它的实现/注释口径。
- `codex/datetime-now` 的 dirty worktree 里确实藏着值得保留的未提交代码：`x509verify` 的
  expired / not-yet-valid behavior tests。它们已经在 integration branch 上改写为基于
  `TCertificateUtils.GenerateSelfSigned` 的版本，避免把 openssl 固定窗口参数细节带回主线。
- `codex/compiler-truth-audit-20260603` 可以删的前提不是“看起来旧”，而是 Git 祖先关系已证明确实被
  `codex/compiler-truth-audit-main-20260603` 吸收；剩余 dirty state 只是 lane-local planning files，
  不是未提交源码。
- `codex/core-tls-rtl-main-20260603-final` 当前是 clean，且自身相对 `main` 有 18 个 TLS/time/text 收敛提交，适合作为 TLS review anchor。
- 但 `codex/core-tls-rtl-main-20260603-final` 不是 TLS 组的完整 superset。`git cherry -v codex/core-tls-rtl-main-20260603-final codex/core-tls-rtl-main-20260603` 与对 `refresh` 的同样检查都给出同一组 5 个 `final` 未吸收的已提交 TLS commits：
  - `4c812194 refactor(tls.winssl): route session time checks through nextpas time`
  - `060498e6 fix(tls): use UTC for backend days-until-expiry helpers`
  - `2e6362a6 refactor(tls): route operational timestamps through nextpas time`
  - `8fc77c8d fix(tls): avoid premature expiry rotation events`
  - `6882e821 refactor(tls): route capability helpers through nextpas text`
- 这 5 个缺口里，有些是“代码 + 覆盖都缺”，有些是“核心代码大体已被 final 后续提交吸收，但 focused coverage 仍缺”：
  - `060498e6` 的 UTC days-until-expiry 代码在 current `final` 上已基本存在：各 backend 当前都用 `DateTimeUtcNow`；但 `test_backend_certificate_days_until_expiry_utc_contract.pas` 与 `winssl/test_winssl_certificate_days_until_expiry_utc.pas` 这两条 coverage 还不在 `final`。
  - `2e6362a6` 与 `8fc77c8d` 没有被 `final` 的 `64d94f95` 同主题提交完全覆盖；`cert.rotation` / `ct.log` 这一面仍需单独看。
  - `6882e821` 对 `capability.serializer/diff` 的 text routing 与 `test_capability_rtl_escape_contract` 仍不在 `final`。
  - `4c812194` 的 `winssl.connection` session time wrapper adoption test 也还不在 `final`。
- `base/refresh` 的 live dirty state 当前没有呈现额外的新 merge 价值：
  - `base` 未提交的是 `verify.custom` + `test_verify_custom_rtl_escape_contract`
  - `refresh` 未提交的是 `http2.alpn` / `verify.custom` + 相关 tests
  - 这些都对应 `final` 已有的早期提交 `387b38fb` / `fdc28d0e`，更像未提交 replay，不应误判成 `final` 之外的新代码。
- 对 `final` 这条线做的两条 focused verification 在本轮为绿：
  - `make -C core/tests/nextpas.core.tls/test_certificate_validity_utc_contract clean test`
  - `make -C core/tests/nextpas.core.tls/test_mbedtls_certificate_text_conv_contract clean test`
    两条都通过，且 heaptrc 为 `0 unfreed memory blocks`。
- 后续按 commit-by-commit 吸收后，`final` 已不再缺那 5 个 follow-up：
  - `86afb4a9` / `959b1bee` / `98a475d0` / `162d920d` / `493a9b43`
    分别以当前 `final` 代码为准解冲突，保留更强实现并补齐缺失测试覆盖。
- `test_capability_rtl_escape_contract` 的首次编译还揭出一个真实回归，不是测试噪音：
  `nextpas.core.tls.logging.pas` 被重复引入 `nextpas.core.time`。这说明 TLS 收口不能只看
  source diff，必须让更宽依赖图至少编译一次。该问题已用 `3f940bea` 修正。
- `base` / `refresh` 剩余的 dirty state 没有留下任何 `final` 没有的代码价值：
  - `verify.custom` replay 与 `final` 当前源码一致，且 `final` 上的 contract test 更强或等价
  - `refresh` 的 `http2.alpn` replay 还停留在 `DateUtils.SecondsBetween`，弱于 `final`
    当前的 `DateTimeSecondsBetween`
  - `final` 上再次跑过 `test_http2_alpn_time_contract` 与 `test_verify_custom_rtl_escape_contract`，均通过
- 因此 TLS 组三棵 worktree 的安全结论已经变化：
  - `codex/core-tls-rtl-main-20260603-final` 保留，作为唯一 consolidated TLS lane
  - `codex/core-tls-rtl-main-20260603` 与 `codex/core-tls-rtl-main-20260603-refresh`
    已可安全删除，且已删除
- 当前真正阻塞把 TLS consolidated lane 落到 `main` 的不是代码质量，而是 live root `main`
  checkout 带着 out-of-scope 编译器/planning 脏改动；在这种状态下移动 `main` 会碰到用户明确隔离的工作面。
- `feat/platform-pty` 这条 clean 基础线没有必要继续占 live checkout：
  - `git merge-base --is-ancestor feat/platform-pty codex/platform-pty-integration` 为真
  - 反向不成立，说明 integration 线完整包含基础 PTY 线
  - 因此保留 branch ref 即可，live worktree 已移除
- `codex/platform-host-ffi-wave15-helper-names` 原本属于“branch tip 已进 main，但 worktree 里还挂着真实未提交源码”的危险状态；
  这轮先跑通它自己改到的 5 组 platform host ABI contract tests，再把改动提交为
  `b7df674f platform: host-own remaining ffi helper names`，然后移除 live worktree。
- 经过上面两步，再加上 earlier archive/parking，本轮现在只剩 4 个 live worktree：
  - `main`
  - `codex/compiler-truth-audit-main-20260603`（用户明确不让我碰）
  - `fix/sema-include-resolver`（用户明确不让我碰）
  - `codex/platform-pty-integration`（仍有真实未提交源码，不能擅自删）
- `codex/platform-pty-integration` 的最终 dedicated audit 证明它不是“还有一批漏合主线的 PTY 价值代码”，而是混着三类东西：
  - 5 个 tracked dirty files 只是把 worktree 局部追平到 current `main`，没有独有价值
  - 11 个 tracked dirty files 相对 current `main` 是明显退化：
    - `constant_time/hash/pkcs8/tls12prf` 等重新引入 `SysUtils` / `TEncoding`
    - `x509verify` 把 UTC validity 路径退回 `Now`
    - `test_http_h1writer` / `test_http_integration` 删掉了大量现有覆盖或减弱断言
  - 3 个 untracked Makefile 是真实可保留的小进度
- 因此这条线的安全结论是：
  - 只保留 Makefile，小批量提交为 `231ad0a6 test(core): add missing Makefiles for marshal/template/validation`
  - focused verification 只围绕这 3 个 Makefile 对应测试重跑：
    `test_marshal`、`test_template`、`test_validation` 全部通过，heaptrc 为 `0 unfreed memory blocks`
  - 其余 dirty diff 作为“已被 main 覆盖的重复”或“回退 main 质量的差异”明确丢弃
  - live checkout 已移除，branch ref `codex/platform-pty-integration` 保留供后续 branch-level review
- `codex/window-sdl2-backend-20260602` 这条线不能用 naive `git diff main..branch` 代表“本 lane 的有效改动”；
  它的祖先链会把更早的 unrelated history 一起带出来。对这种 stacked lane，正确边界是先锁定 graph tip 上那
  5 个图形栈 commits，再按这些 commits 触达的路径逐文件取证。
- 这 5 个图形栈 commits 的真实代码面是清晰的：`40` 个新增/修改的 code/test 路径，外加
  `docs/inbox.md` 这一份 lane-local 看板文档。
- 把这 5 个 commits 转存到 `codex/worktree-triage-integration-20260604` 时，所有冲突都只发生在
  `docs/inbox.md`。integration 保留的是 repo 当前共享工作看板；window branch 那份是 SDL2/OpenGL/atlas/cell
  路线板，不属于必须跟着代码进入主线的共享事实源。
- focused verification 已完整覆盖这条图形栈 lane：
  `test_window_surface`、
  `test_window_sdl2_loader`、
  `test_window_sdl2_smoke`、
  `test_gpu_gl_smoke`、
  `test_gpu_atlas_surface`、
  `test_gpu_gl_atlas_smoke`、
  `test_text_font_bitmap`、
  `test_text_shaper_fixed`、
  `test_text_glyph_atlas_surface`、
  `test_gpu_cell_surface`、
  `test_gpu_gl_cell_smoke`
  全部通过，且 heaptrc 均为 `0 unfreed memory blocks`。
- 对 original window branch tip 与 integration tip 的逐文件比对证明：这 5 个 commits 触达的 `40` 个
  code/test 路径内容完全一致；唯一故意不保留的是 `docs/inbox.md` 的 lane-local 看板文本。
- 这轮 `window-sdl2` dedicated audit 还再次暴露出一个会话内实时状态点：为安全转存它，新建了临时 integration
  worktree，因此 live worktree 数在同一轮里会从 `3` 短暂回到 `5`。最终在删除 original
  `codex/window-sdl2-backend-20260602` worktree/branch 与临时 integration worktree 后，verified live
  worktree 状态又回到 `3`。
- 经过这一步后，本轮我负责范围内已没有剩余 non-compiler live worktree；当前 live worktree 只剩 3 个：
  - `main`
  - `codex/compiler-truth-audit-main-20260603`
  - `fix/sema-include-resolver`

## 2026-06-03 C5-N structured direct-call lowering

- 继续按 `WalkHaltCalls` 的 raw assign 分支补 call 特判，收益已经开始变差；更值钱的切片是把第一条真正的 structured call expr 收起来，让 builder 能直接 lower call，而不是再把表达式压回 blob。
- 这轮最小正确合同是：`shekCall` 只描述 direct free-function call，`LiteralStr` 放 callee，`Op` 放 legacy ABI 参数种类，`Children` 放参数 expr；`TypeId` 和 `ValueClass` 只表达结果，不夹带 builder 产物。
- builder 不能按“类型 ID 完全相等”判断 legacy int call，因为 semantic `Integer` 走的是 width-based `i64` type，而 runtime function body 走的是 legacy `GetIntType`。正确边界是按 ABI 形态判断，再在 lowering 时归一到 legacy `i64` / `ptr`。
- pointer/class-return helper assignment 之前虽然能发旧 `assign-runtime` blob，但它绕开了统一 attach helper，因此 class target 一直拿不到 `ExprId`。这不是 call lowering 本身的问题，而是 producer 路由问题。
- 这轮故意不把 scope 扩到 overload、member call、virtual/interface call、string/record/var-param call。它们都可以继续回落旧 blob；先把第一条 direct call 通路打通，比再堆一层局部特判更稳。

## 2026-06-03 C5-M object-backed field-array value loads

- `Result := FItems[i]` 和 `Result := Self.FItems[i].A.B` 的新探针已经证明：它们不是下一个红点；current-class return-side 在 C5-L 后已经是通的。
- 真正的下一处缺口是 object-backed field-array value load：`Result := Other.FItems[i]`。
  RED `exit=83` 直接证明 producer 没有发出 `assign-runtime`，问题仍在 sema 旧 blob gate，而不是 builder。
- 根因是四个地方都只认 implicit/self field-array：
  `TryCurrentClassFieldArrayAccess`、`BuildClassFieldArrayElementTargetExpr`、
  `ResolveArrayAccessElementTypeId`、`EncodeRuntimeIntExprFold`。因此
  `Other.FItems[i]` 同时失去 legacy blob 和 structured address-backed `ExprId`。
- 最小正确修复不是再堆 one-off 分支，而是引入共享 `TryClassFieldArrayAccess(base,class,field)`：
  它统一识别 implicit self、explicit self 和 object variable receiver，然后让
  self-only helper 退化成 wrapper。
- 这样 direct/nested + local/result 四条 object-backed field-array value load
  都复用了同一条结构：`shekArrayElem -> shekField -> shekDeref -> shekSymbolValue`；
  legacy fallback 也同步变成 `field <receiver> <index> p` + `arr_load`。
- builder 这轮不需要动；只要 sema 把对象接收者的 address-backed value expr 和 blob 都讲清楚，
  现有 lowering 就能工作。

## 2026-06-03 C5-L array-backed value loads

- `TestNestedFieldArrayValueExprProducer` 的 shell exit `255` 不是崩溃；用调试器断在
  `SYSTEM_$$_HALT$LONGINT` 后确认实参是 `261`，只是 FPC 把 `Halt(261)` 截断成 `255`。
- 真正的红点不是 builder，也不是结构化 `ExprId` 构造失败，而是 producer 根本没发出
  value-side `assign-runtime` 节点。失败模型只有 `assign-arr-elem-runtime` store，
  没有 `y := Self.FItems[i].A.B` 对应的 runtime assign。
- 因果链很直接：`WalkHaltCalls` 的 scalar assign 分支只有在
  `EncodeRuntimeIntExprFold(Arg, Operand)` 成功时才会调用 `AddScalarAssignRuntimeNode`；
  current-class field-array value load 缺少旧 blob 编码，所以 node emission 被 gate 掉了。
- builder 这时已经是“准备好的”：`BuildRuntimeScalarHirExpr` 能把 array-backed value
  视为 address-backed structured expr；这轮不该再碰 builder，而该让 producer 的 legacy blob
  与 structured path 重新对齐。
- 最小正确修复是在 `EncodeRuntimeIntExprFold` 补齐两条旧路径：
  `Self/FItems[i]` 与 `Self/FItems[i].Field`。这样 direct field-array value load
  和 nested `Self.FItems[i].A.B` 都能重新发出 `assign-runtime`，同时继续挂上结构化 `ExprId`。

## 2026-06-03 C5-K nested array-backed field chains

- `arr[i].A.B := rhs` 没有 runtime node 的根因不只是 `TargetExprId` 缺失；`WalkHaltCalls`
  里 assignment routing 本身只认一层 shape，所以 deeper chain 需要同时收口“node 分流”和
  “target address 构造”两层逻辑。
- `shekField` 不需要新 kind；更深 field chain 的正确结构仍然是 repeated
  `shekField` over an address-producing base。
- 对 array-backed nested field store，legacy fallback 仍可保留而不必作废：
  只要把 field path offset 展平成 `index * elem_slots + field_offset`，现有
  `assign-arr-elem-runtime` fallback 就还能表达 deeper chain 的槽位寻址。
- builder 当前真正的阻塞点是 `shekField` 把 `ExprHirTypeId(AExpr) <> 0`
  当成 address lowering 前提；这会错误拒绝像 `.A` 这样的 aggregate intermediate field。
  放开 address lowering 后，value load 仍必须继续要求 concrete scalar HIR type，
  这样不会把 aggregate address 偷偷当标量值读走。
- `BuildTargetAddressExpr` 适合作为 C5 期间的共享 sema seam：同一条递归路径可以覆盖
  direct array、field-array、record/class base、implicit self field 和 deeper dot chain，
  比继续堆叠 one-off producer helper 更稳。

## 2026-06-03 C5-J field array target

- Current HEAD is `7a62f257 feat(compiler): C5I lower array record field targets`.
- The working tree has unrelated dirty work in `.claude/`, `.worktrees/`, and `core/`; C5-J must use path-limited edits/staging only.
- C5-J should choose field arrays `self.Items[i]` over deeper `arr[i].A.B` for this slice because it attacks the existing field-array string magic and forces a more general address/value contract.
- Proposed shape: keep `shekArrayElem` as the element-address kind. Symbol-backed arrays continue to use `SymbolId > 0` with one index child. Field-array slots should use `SymbolId = 0`, child 0 as the array-slot address expression, and child 1 as the index expression.
- This keeps the old blob fallback intact while allowing builder lowering to load the dynamic array pointer from the field slot, then perform the usual element GEP.
- Class field metadata currently records `TFieldMeta.TypeId`, but `array of Integer` class fields enter as `gnkArrayType`, so they do not naturally get a scalar type id. C5-J should record array-field element metadata and treat the field slot itself as `Pointer` for address lowering.
- `__field_arr__` producer currently creates `assign-arr-elem-runtime` directly and does not call the shared attach helpers; GREEN should add a field-array target helper rather than overloading `ExprId`.
- Parser class-field handling previously skipped non-identifier field types. `FItems: array of Integer` therefore had no child type node, so sema could not record field-array element metadata until the parser preserved that type node.
- Builder `ProcessAssignArrElem` must not parse field-array `IdxBlob` / `ValBlob` before checking `TargetExprId`; otherwise structured lowering can succeed while legacy `const:99` artifacts have already been emitted.
- /codex review found two blocking gaps before commit: explicit `Self.FItems[i]` is not the same CST shape as implicit `FItems[i]`, and comma class field lists still drop type nodes. It also flagged inherited class array field metadata as a medium residual risk.

## 2026-06-03 C5-I array record field target

- Existing legacy `arr[i].Field := rhs` support encodes the address as an offset blob: array index multiplied by record slot count plus field index. This keeps working as fallback but hides the lvalue chain from typed HIR.
- `shekField` already composes over any address-producing child, so `arr[i].Field` does not need a new expression kind. The right structure is `shekField -> shekArrayElem -> index`.
- The current blocker was `shekArrayElem` hard-coding `Integer` as element type and builder requiring a concrete scalar HIR type for every array element address. Record elements are addressable aggregates, not scalar values.
- C5-I first slice lets aggregate array elements lower as addresses with no concrete HIR scalar type. Loading such an aggregate as a value still fails, preserving fallback behavior.
- This slice intentionally does not cover field arrays (`self.Items[i]`) or deeper chains (`arr[i].A.B`); those need separate producer patterns.

## 2026-06-03 C5-H static array target/address

- C5-H0 already made builder-side static array address lowering viable: `shekArrayElem` can use `arr_low` metadata for lower-bound normalization and static backing storage is connected to `arr$ptr` / `arr$len`.
- Direct static `@arr[i]` can reuse the existing `BuildRuntimeArrayElementAddressHirExpr` path because static arrays are registered as runtime array vars.
- The real producer gap found by RED was direct array element store RHS: `assign-arr-elem-runtime` had a `TargetExprId` for LHS, but no structured RHS `ExprId`, so builder still had to parse the RHS blob even when the scalar expression was migratable.
- The minimal fix is to make `AddArrayElementStoreRuntimeNode` mirror field-store behavior: attach scalar RHS `ExprId` when possible, then attach LHS `TargetExprId`, while keeping the old operand blob intact.
- This intentionally also improves direct dynamic array stores, because the helper is shared. Field arrays, array-of-record-field, class/object RHS special branches, and nested lvalue chains remain out of scope.

## 2026-06-03 C5-H0 static array foundation

- C5-G is complete and current `docs/inbox.md` still points to static array target/address as the next step.
- Direct C5-H target/address migration is premature: static arrays are currently parsed and registered like dynamic arrays, so the builder can end up storing/loading through `arr$ptr = null`.
- Parser investigation target: `compiler/syntax/np_green_tree.pas` `ParseTypeReference` and `ParseTypeSection` create `gnkArrayType`, but static bounds must be preserved as structured children instead of being skipped.
- Sema investigation target: `compiler/sema/np_semantic_analyzer.pas` `WalkRuntimeVarDecls` registers direct `gnkArrayType` declarations through the dynamic array path.
- Builder investigation target: `compiler/ir/np_hir_builder.pas` `ProcessVarDecl` treats `var-decl-arr-runtime` as `arr$ptr` + `arr$len`; C5-H0 should keep this channel but point static arrays at real backing storage and store compile-time length.
- Parser already has `gnkRangeExpression` and `tkDotDot` support for set constructors and case labels. Static array bounds should reuse that node kind instead of inventing a string-only range marker.
- HIR emitter already supports `hikAlloca` with `IntrinsicName='record:N'`, emitting `[N x i64]` stack storage. Builder can use that for integer static-array backing storage while preserving `arr$ptr`.
- Existing array element address paths that need lower-bound normalization are `LowerArrayElemExpr`, `BlobArrElemRef`, `BlobArrLoadVar`, and `ProcessAssignArrElem` legacy fallback.
- The requested Claude memory file `stale-ppu-discovery.md` is referenced by Claude `MEMORY.md` but is not present in the directory. The same discipline is still present in `compiler/docs/compiler-goal-tree.md`: full rebuild is mandatory because stale PPU can make compiler edits look active when they are not.
- Design decision: split C5-H into C5-H0 foundation first, then C5-H proper for structured static-array target/address after metadata and storage are correct.

## 2026-05-31 Crypto/TLS Security Audit Findings

- Deep audit scope covered `nextpas.core.crypto.field25519*`, `x25519`,
  `ed25519`, `aesgcm`, `constant_time`, `ct.bigint`, `ecdsa`, `bigint`,
  `rsa`, and the TLS 1.3 `chacha20poly1305`, `keyschedule`, `recordcrypto`,
  `clienthello`, `serverhello`, and `aead` units.
- High-risk findings identified in the current source:
  - Pure-Pascal AES uses secret-dependent `SBox[...]` lookups, so the AES-GCM
    fallback is not constant-time on non-AESNI systems.
  - RSA/ECDSA big-int and scalar-multiplication paths are not constant-time;
    the current `ct.bigint` API also overstates its guarantees.
  - TLS 1.3 ChaCha20-Poly1305 has an x86_64 AVX2 path with no runtime feature
    gate, creating a SIGILL/DoS risk on unsupported CPUs.
  - The non-x86_64 streaming Poly1305 fallback is explicitly incomplete and is
    not cryptographically correct for production use.
  - Ed25519 verification accepts non-canonical signatures/encodings and the
    unit still exposes public test helpers that can trigger short-input reads.
  - The standalone `field25519.femul.x86_64.inc` variant is alias-unsafe if it
    is ever wired in, even though the current live `FeMul` implementation uses
    a safer temporary-buffer approach.
- Fresh report for the user should be grouped by category with concrete
  severity and `file:line` references, plus suggested fixes.

## 2026-05-28 Follow-up Findings 41

- Wave 6 branch verification is complete in the isolated worktree:
  `make -C core test`, `make -C core examples`, `make -C core benchmarks`,
  `sh -n build/verify_local.sh`, `git diff --check`, and fresh
  `bash build/verify_local.sh` all passed. The final official envelope includes
  `corePlatformHostAbiWave6ProcessCheck":"pass"` with `verify-local=pass`.
- The corrected verification boundary held: raw FPC process ABI definitions were
  not runtime-tested as OS API behavior. The checks only guarded nextPas
  integration discipline: owner placement, no feature-specific
  `platform.process.ffi`, no new POSIX host `platform_process_*` helpers,
  no production FPC RTL dependency, compile coherence, route truth, and
  documentation synchronization.
- Integration risk is now outside the feature branch: the main checkout has
  unrelated collections WIP, so merging must happen through a clean integration
  window or an isolated post-merge verification worktree. Do not mix collections
  WIP into the platform Wave 6 commit.

## 2026-05-28 Follow-up Findings 40

- Wave 6 的高价值切片是 process-control raw ABI inventory，不是 public
  `platform.process` contract。未来统一进程 API 要处理参数数组、环境块、编码、句柄生命周期、
  wait/kill semantics、exit code 与跨平台能力差异；这些不应在 raw ABI inventory wave 里偷渡。
- 用户明确修正搬运口径：FPC 已有的平台 API、常量、结构和 ABI alias 本身不需要 nextPas 再验证；
  只要 FPC 源码里有，就认定为正确定义。nextPas 只验证自己的集成纪律，不做“证明 FPC 正确”的
  source-surface/token 测试或 runtime raw OS API 单测。
- POSIX process-control 取证清楚：FPC `rtl/unix/oscdeclh.inc` 声明 `FpFork`、`FpExecve`、
  `FpWaitpid`、`FpExit` 和 `FpKill`，分别绑定 libc `fork`、`execve`、`waitpid`、`_exit` 与
  `kill`。Linux/BSD syscall wrapper families 是补充证据，但 nextPas production code 仍只写
  自有 FFI 声明。
- Windows process-control 取证清楚：FPC `rtl/win/wininc/ascfun.inc` /
  `unifun.inc` 声明 `CreateProcessA/W` 与 `GetStartupInfoA/W`；`func.inc` 声明
  `ExitProcess`、`TerminateProcess`、`GetExitCodeProcess` 与 `WaitForSingleObject`；
  `struct.inc` 记录 `PROCESS_INFORMATION`、`STARTUPINFOA/W` 与 `SECURITY_ATTRIBUTES`；
  `base.inc` 记录 `WINBOOL`、`LPVOID`、`LPBYTE` 等 ABI alias；`defines.inc` 记录
  process creation flags 与 priority class constants。
- 本轮 owner 规则纠偏：POSIX shared raw externals 归 `nextpas.core.platform.posix.ffi`；
  Linux、Android、Darwin、FreeBSD、generic Unix `.ffi` 本轮不暴露
  `platform_process_*` host owner helper。`platform_process_*` 看起来像统一 public contract，
  process-control 语义需要未来单独设计 `platform.process` 后再决定 public API；Windows
  record/constant/alias 归 `windows.base`，kernel32 raw declarations 归 `windows.ffi`，本轮不新增
  非 FPC 的 `windows_*process*` result wrapper。
- 用户审查指出 `linux.ffi` 中 `platform_pthread_*` / `platform_process_id` 这类命名把 host
  selector helper 和 unified public `platform.*` contract 混在一起。这个问题成立：host-specific
  `.ffi` 应避免继续导出 generic `platform_*` helper；shared POSIX owner 可以保留明确的
  `platform_posix_*`，Windows helper 已有 `windows_*` 前缀，POSIX host selector helper 应迁到
  `host_*` 或具体 host 前缀。
- 当前 Wave 6 先止住新增污染：删除新增 `platform_process_fork/execve/waitpid/exit/kill`，
  测试改为检查这些 unified-looking helper 不存在。既有 `platform_pthread_*` /
  `platform_process_id` 属于历史命名债，需要单独的 host FFI hygiene wave 做受控迁移，不能在
  process ABI wave 里无计划大面积改名。
- raw process-control ABI 不做 runtime unit test。本轮验证口径改为 nextPas integration only：
  文档事实、official route truth、ABI owner/命名边界、无 FPC RTL 生产依赖、Win64 compile-only
  与 simulated-host compile matrix；不再把 FPC raw 定义本身作为待证明对象。
- 当前跨平台证明边界要诚实：Linux runtime 只能证明当前 host compile/runtime surface；
  Windows 主要是 Win64 compile-only；Darwin/Android/FreeBSD/generic Unix 主要是 simulated-host
  compile matrix 与 source evidence。

## 2026-05-28 Follow-up Findings 39

- Wave 5 的高价值切片是 environment raw ABI inventory，不是 public `platform.env` 或
  `platform.process` contract。环境变量是 future process/env/workspace/doctor 能力的基础系统面，
  但统一语义、编码、枚举所有变量、线程安全和错误模型要另起 public contract 设计。
- POSIX 侧取证显示 FPC 已有 `getenv` 路径：`rtl/unix/oscdeclh.inc` 声明 `fpgetenv`
  绑定 libc `getenv`，`rtl/unix/baseunix.pp` 引入 `genfuncs.inc`，`rtl/unix/unix.pp` 提供
  `getenv` wrapper。`setenv` / `unsetenv` / `putenv` 属于 POSIX/libc environment mutation family；
  本轮可以把它们作为 raw ABI 记录到 shared POSIX `posix.ffi`，host `.ffi` 暴露 owner helper。
- Android 侧 FPC `rtl/android/sysandroid.inc` 记录了 libc `environ` 获取路径；本轮仍按 POSIX libc
  environment family 处理，不把 Android 独立拆成另一套 public API。
- Windows 侧取证清楚：FPC `rtl/win/wininc/ascfun.inc`、`unifun.inc`、`ascdef.inc`、`unidef.inc`
  提供 `GetEnvironmentStringsA/W`、`FreeEnvironmentStringsA/W`、`GetEnvironmentVariableA/W`、
  `SetEnvironmentVariableA/W` 与 `ExpandEnvironmentStringsA/W`；`rtl/win/sysos.inc` 也记录
  `SetEnvironmentVariableW`。这些 entrypoint 应归 `windows.ffi`，复用 `windows.base` 既有 string
  pointer aliases。
- raw environment ABI 不做 runtime unit test。本轮验证口径继续是 source-surface、文档事实、
  official route truth、ABI owner 边界、Win64 compile-only 与 simulated-host compile matrix。
- Wave 5 implementation 已落为 host-owned ABI inventory：shared POSIX externals 与
  `platform_posix_environment_*` helper 位于 `posix.ffi`；Linux、Android、Darwin、FreeBSD、
  generic Unix `.ffi` 暴露 `platform_environment_*` 并委托 POSIX；Windows A/W environment
  entrypoints 与 `windows_*environment*` helper 位于 `windows.ffi`。
- Pre-commit verification 证据完整：focused Wave 5 gate `5 total, 5 passed, 0 failed`；
  simulated host compile matrix 全部 `status=pass`；`make -C core test` / `examples` /
  `benchmarks` 通过；fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`，final envelope 包含
  `corePlatformHostAbiWave5EnvCheck":"pass"`。
- 本轮仍没有真实 Windows/macOS/Android runtime execution evidence；当前跨平台保证来自 FPC/source
  evidence、host-owned declarations、Win64 compile-only smoke、simulated-host compile matrix 与
  source-surface gates，不能把它包装成所有平台 runtime 已执行。
- Wave 5 已 fast-forward merge 到 `main@7c4db4a`，并完成 post-merge verification：
  focused Wave 5 gate `5 total, 5 passed, 0 failed`，`make -C core test` / `examples` /
  `benchmarks` 通过，fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`，final envelope 保留
  `corePlatformHostAbiWave5EnvCheck":"pass"`。
- 临时 worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave5-env` 与分支
  `codex/platform-host-abi-wave5-env` 已清理。剩余并行 worktree 仍是 collections 与 sema，本轮没有
  触碰它们。

## Requirements

- 用户要求继续按路线图推进，但不能再停在碎片化“继续”循环里。
- 用户要求设计和实现都必须建立在真实代码之上，不能空谈现代化。
- 外部审查报告要求优先关闭 `P0` 验证失真，再关闭 `P1` resolver correctness 问题。
- 当前阶段的表述必须诚实：
  已经落地的能力可以明确写，仍然 host-backed 或尚未实现的部分不能包装成已完成。
- Collections 迁移按用户要求以 `nextpas.core` 搬入代码为基础继续重构；不能用自写简化版替代原实现。

## Research Findings

- platform 是 L0 系统平台 API/ABI 适配层，负责 OS/CPU、thread、sync、time clock 等低层契约；
  `Stopwatch`、`Duration` 这类用户便利抽象属于 `nextpas.core.time` 或更高层模块，不能作为
  platform 模块成果混入。
- FPC 源码和平台单元是 `platform.<host>.base` / `platform.<host>.ffi` 的 ABI 取证依据，不是
  platform 生产代码依赖；raw 系统 API 不作为 nextPas runtime 单元测试目标，行为测试只覆盖
  `platform.time` / `platform.sync` / `platform.thread` 这类统一抽象子模块 public contract。
- `platform.time`、`platform.sync`、`platform.thread` 是基于 `platform.<host>.base` /
  `platform.<host>.ffi` 的跨平台统一 API contract，不是按 feature 切碎的 FFI owner。
  除非 feature 自身真的拥有独立 foreign ABI，否则不创建
  `platform.time.ffi`、`platform.sync.ffi`、`platform.thread.ffi`。
- `core/docs/platform-host-ffi-gap-matrix.md` 现在是 Linux / Android / Darwin / FreeBSD /
  generic Unix / Windows host ABI 覆盖面和已知缺口的文档事实源；配套
  `test_platform_host_gap_matrix` 与 `build/verify_local.sh` 的
  `corePlatformHostGapMatrixCheck` 只证明 source-surface 同步，不把 Win64/simulated host 编译证据
  包装成跨宿主 runtime proof。
- `core/docs/platform-ffi-source-evidence-index.md` 将作为 host ABI 声明的 evidence index：它记录
  每类声明参考的 FPC source family / unit names、nextPas host owner 与证据边界。该文档不替代
  host gap matrix；gap matrix 说明当前覆盖和缺口，evidence index 说明这些声明应回到哪里取证。
- 需要新增 `core/docs/platform-ffi-import-workflow.md` 作为工作流事实源：evidence index 说明“声明去哪里
  取证”，gap matrix 说明“当前拥有了什么和缺什么”，import workflow 说明“每一批 API 怎么安全搬进来、
  怎么验证、怎么恢复、怎么合并”。三者职责不同，后续不能只靠口头约定。
- `platform-ffi-import-workflow` 已把“本次做不完，下次继续”变成硬流程：每个 API import wave 必须记录
  worktree path、branch、起点 main、当前 phase、第一条未完成任务、RED/GREEN 输出、source evidence
  和 merge/cleanup 状态；恢复入口固定为读 `task_plan.md`、`progress.md`、`findings.md` 后从最新
  platform addendum 的第一条未完成任务继续。
- `corePlatformFfiImportWorkflowCheck` 已进入 `build/verify_local.sh` 的 official final envelope；
  这保证后续 session 不能只更新 workflow 文档而忘记 route truth，也不能绕过 workflow 直接开始
  bulk raw OS API import。
- Platform Host ABI Completeness Wave 1 的边界已定为 raw host ABI inventory，而不是统一 public
  contract：先从 FPC source evidence 补 host `base/ffi`，再由未来 `platform.file`、`platform.process`、
  `platform.memory`、`platform.dylib` 等统一子模块择机消费。raw ABI 本轮不做 runtime unit test。
- 本机 `/home/dtamade/projects/fpdev/sources/fpc/fpc-main` 是空目录壳，不能写进 evidence index 作为
  可验证依据；可用 FPC source checkout 位于 `/home/dtamade/projects/fpc`，但项目文档应记录
  `rtl/linux`、`rtl/unix`、`rtl/darwin`、`rtl/freebsd`、`rtl/win32`、`rtl/win64`、
  `packages/winunits-base` 这类 source family 和 unit names，而不是绑定用户机器绝对路径。
- `docs/design-conventions.md`、`docs/platform-host-ffi-gap-matrix.md` 与 `build/verify_local.sh`
  应形成 route-truth 闭环：设计规范是规则入口，gap matrix 是 host ABI 覆盖事实源，
  `core-platform-host-gap-matrix-check` / `corePlatformHostGapMatrixCheck` 是 official local
  verification route。后续不能只更新其中一个文件而让其他入口失真。
- `platform.thread` 的 public carrier types 也应遵循 base owner：`TPlatformThreadHandle`、
  `TPlatformThreadToken`、`TPlatformThreadProc`、`TPlatformTLSKey` 归
  `nextpas.core.platform.thread.base`，`nextpas.core.platform.thread` 只 re-export 并实现统一
  thread API。这个 base 单元不是 host ABI owner，不新增 `platform.thread.ffi` 或
  `platform.thread.intf`。
- `platform.sync` 的 public carrier types/constants 也应遵循 base owner：
  `TPlatformMutexAlign`、`TPlatformRwLockAlign`、`TPlatformCondVarAlign`、
  `TPlatformMutex`、`TPlatformRwLock`、`TPlatformCondVar`、opaque size token、public mutex
  kind 与 `PLATFORM_ERR_*` 归 `nextpas.core.platform.sync.base`。`platform.sync` 只 re-export
  并实现统一 sync API；这个 base 单元不是 host ABI owner，不新增 `platform.sync.ffi` 或
  `platform.sync.intf`。
- 顶层 `platform` 的 OS/CPU/endian inquiry 也需要按职责拆分：`platform.base` 只拥有
  `TOSKind`、`TCPUArch`、`TEndianness` 与 `CURRENT_*` compile-time truth；
  `nextpas.core.platform.info` 拥有 `CurrentOS`、`CurrentCPU`、`CurrentEndian`、`OSName`、
  `CPUName` 的纯 Pascal 实现；`nextpas.core.platform` 顶层 facade 只 re-export/inline forward。
  这个 `info` 单元不是 host ABI owner，不新增 `platform.info.ffi`、`platform.info.intf` 或
  `platform.info.base`。
- `test_platform_facade_surface` 与 `build/verify_local.sh` 现在把顶层 platform facade/info 边界
  变成 official gate：`platform.info` 必须存在并拥有 info logic，`platform.pas` 必须保持 thin
  forwarding，final verify envelope 必须包含 `corePlatformFacadeSurfaceCheck`。
- Windows `WaitOnAddress` 的 raw success/timeout/last-error truth 属于 `windows.ffi`，但
  `platform_wait_address32` 的 nil/mismatch/timeout/wake public result contract 属于
  `platform.sync`。因此 Windows wait path 必须像 Linux futex 与 POSIX fallback 一样，在调用
  host wait helper 前完成 nil/mismatch precheck；mismatch -> `PLATFORM_ERR_AGAIN` 不能下沉成
  `windows.ffi` 的硬编码 public policy。
- `*.intf.pas` 只给真实 Pascal `interface` contract。`platform.time` 当前只有过程/函数 API，
  不应保留 `nextpas.core.platform.time.intf.pas` 或 `IPlatformTimeSource`。
- `ICollection` 与 `IGenericCollection<T>` 的真实 interface definition 已迁入
  `nextpas.core.collections.intf`；`collections.base` 不再拥有这些接口定义。
- 当前不能直接把 `TCollection` / `TGenericCollection<T>` 强搬到 `collections.abstract`：现有
  interface contracts 大量引用 `TCollection` class，如果 `intf` 为此引用 `abstract`，会和
  `abstract` 引用 `intf` 形成循环。下一步需要先设计 class API 与 interface API 的过渡边界。
- `platform_posix_clock_deadline_after_ns` 与
  `platform_posix_clock_deadline_remaining_ns_u64` 现在是 shared `posix.ffi` 的单一事实源；
  `platform.sync` 应继续只消费 host-owned
  `platform_pthread_timeout_deadline_after_ns` /
  `platform_pthread_timeout_remaining_ns_u64`，不再直接组装 POSIX timeout deadline arithmetic。
- 错误的 `codex/platform-time-extras-preview` 分支只存在于隔离 worktree，尚未合入 main；已删除
  该 worktree/branch，避免 stopwatch 示例污染 platform 收口。
- `platform.time` 的 helper/no-FPC focused tests 原先位于 `core/tests/nextpas.core.time/`，
  这会弱化 L0 platform contract 与 L1 time API 的边界；本批迁入
  `core/tests/nextpas.core.platform.time/`，`nextpas.core.time/test_time` 继续覆盖 L1 public API。
- `*.ffi.pas` 与“同 host family 的纯 helper unit”不能混为一谈：如果单元不拥有 `external` ABI
  declaration，就不该继续命名成 `*.ffi.pas`，否则会和 `test_platform_ffi_owner_boundary`
  以及 `docs/design-conventions.md` 的规则自相矛盾。
- `core/docs/design-conventions.md` 中 Windows FFI 示例文件名仍写作 `win32.ffi`，与当前真实
  `nextpas.core.platform.windows.ffi.pas` 不一致；同时目标平台描述需要显式包含通用 Unix/BSD
  与 Android。
- `platform.time` 现在通过 nextPas-owned FFI 单元访问平台 ABI：POSIX clock API 位于
  `nextpas.core.platform.posix.ffi`，macOS mach timebase 位于
  `nextpas.core.platform.darwin.ffi`，Windows QPC/FILETIME 位于
  `nextpas.core.platform.windows.ffi`。
- Windows `FILETIME` 的 Unix epoch offset 与 tick size 也不该继续埋在 `platform.time` 实现里；
  现在这两个宿主时钟 truth 已进入 `nextpas.core.platform.windows.ffi`，`platform.time` 只消费
  `WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS` 与
  `WINDOWS_FILETIME_NANOSECONDS_PER_TICK`。
- Windows 的 `Sleep` / `WaitOnAddress` / `SleepConditionVariableSRW` timeout 换算 policy 也不该
  分别散落在 `platform.thread` 与 `platform.sync` 里；现在 `windows.ffi` 继续拥有
  `windows_sleep_ns_to_ms` 与 `windows_timeout_ns_to_ms`，consumer 不再各自复制向上取整和
  `INFINITE - 1` 截断语义。
- Windows `SRWLOCK` / `CONDITION_VARIABLE` 的“无需显式 destroy”也是宿主语义，不该继续留在
  `platform.sync` consumer 里写三处 `Result := 0`。现在 `windows.ffi` 显式拥有
  `windows_mutex_destroy`、`windows_rwlock_destroy`、`windows_condvar_destroy`，Windows sync helper
  family 在 ffi owner 侧更完整了。
- Windows `TryAcquireSRWLock*` 的 false=>busy classifier 也不该继续留在 `platform.sync` consumer 里写
  `if ... then 0 else PLATFORM_ERR_BUSY`。现在 `windows.ffi` 显式拥有
  `windows_mutex_trylock_busy_result`、
  `windows_rwlock_tryrdlock_busy_result`、
  `windows_rwlock_trywrlock_busy_result`，同时继续采用 caller-supplied busy result，避免把
  `PLATFORM_ERR_BUSY` 硬编码进 ffi owner。
- 新增 `core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface/`，把
  `platform.time` 对 `posix.ffi` / `darwin.ffi` / `windows.ffi` 的 clock ABI 消费关系冻结成
  source-surface gate；fresh `bash build/verify_local.sh` 已把
  `core-platform-time-host-ffi-surface-check=pass` /
  `corePlatformTimeHostFfiSurfaceCheck":"pass"` 纳入 official envelope。
- `platform.time` 现在连 public façade body 的重复都收掉了：`platform_monotonic_ns`、
  `platform_realtime_ns`、`platform_monotonic_resolution_ns` 各只保留一个实现体，并由统一
  `NEXTPAS_PLATFORM_TIME_HOST_FFI` gate 覆盖 `NEXTPAS_UNIX` / `NEXTPAS_WINDOWS` 两类受支持宿主。
- `platform.time` 现在进一步收成 `facade + base + host`：facade 只 re-export
  `platform.time.base` 的 public carrier types 并转发到 `platform.time.host`；不存在真实接口契约，
  因此不再有 `platform.time.intf`。
- `test_platform_time_host_ffi_surface` 现在还会额外禁止 `platform.time` 回归裸
  `116444736000000000` 这类 Windows `FILETIME` epoch 魔数；owner boundary 不再只检查符号存在，
  也检查实现层不把宿主 clock truth 再偷拿回来。
- `test_platform_sync_host_ffi_surface` 与 `test_platform_thread_host_ffi_surface` 现在也会冻结
  Windows timeout/sleep conversion helper 的 owner boundary：`windows.ffi` 必须继续拥有 helper，
  `platform.sync` / `platform.thread` 必须继续消费它们，不能回归 local helper 或 raw
  `$FFFFFFFF` saturation literal。
- `test_platform_time_helpers` 现在 direct 覆盖 `platform_realtime_ns` 与
  `platform_monotonic_resolution_ns`，platform 自己的 focused test 对 public clock API 的接口覆盖更完整，
  不再主要依赖 example 与 L1 `time` test 间接证明。
- `test_platform_ffi_owner_boundary` 现在还冻结了 platform runtime behavior test 的边界：
  `platform.time` / `platform.sync` / `platform.thread` 行为测试不得 import host FFI，也不得用
  raw `pthread_create` / `pthread_join` / `gettid` 作为系统 API oracle；`platform.sync` 的并发场景
  已改为使用 `platform.thread` 创建和 join worker。
- `nextpas.core.platform.posix.ffi` 现在应只拥有 shared POSIX ABI：`timespec`、
  `clock_gettime/getres`、`nanosleep`、`sched_yield`、`sysconf` 与 pthread
  type/function declarations；host-owned `CLOCK_*`、`_SC_NPROCESSORS_ONLN`、errno 常量和 errno
  symbol binding 已经不应继续留在这里。
- shared `posix.ffi` 不必被收窄成“只能放 raw external 声明”；只要语义在 POSIX 宿主间完全共享，
  它也应该拥有单一事实源级别的 helper。当前已经明确收口的包括
  `platform_posix_timespec_to_ns_u64`、`platform_posix_timespec_add_ns`、
  `platform_posix_timespec_remaining_ns_u64`、`platform_posix_thread_self_token_u64`、
  `platform_posix_sysconf_positive_i32`、
  `platform_posix_pthread_create/join/detach_handle`、
  `platform_posix_pthread_state_create/join/detach`、
  `platform_posix_pthread_yield`、
  `platform_posix_pthread_sleep_ns` 与
  `platform_posix_pthread_tls_create/destroy/set/get`。
- `platform.thread` 的 POSIX state carrier、allocation、zero-init、join/detach release 和 pthread token
  storage offset 不应留在 unified consumer。现在 `linux/android/darwin/freebsd/unix.base` 拥有
  `PPlatformPThreadState` / `TPlatformPThreadState`，各 host `.ffi` 拥有
  `platform_pthread_state_create/join/detach`，consumer 只把返回的 pointer 当作
  `TPlatformThreadHandle` public handle。
- 这也修正了旧记录里“`platform.thread` 继续保留 state record”的说法：当前规则是 public
  handle contract 仍在 `platform.thread`，但 host-shaped thread state carrier 和释放时机由 host
  base/ffi owner 封装。
- 这轮之后，shared `posix.ffi` 还进一步统一承载了两层不携带宿主 truth 的 projection skeleton：
  `platform_posix_errno_value_from_location` 与
  `platform_posix_pthread_mutex_init_public_kind`。前者只做 `errno-location -> value` 的通用 load，
  后者只做 public mutex kind 到 caller-supplied host kind token 的通用投影，再复用
  `platform_posix_pthread_mutex_init_kind`。
- 对应地，`linux/android/darwin/freebsd/unix.ffi` 现在不再各自复制
  `Result := platform_errno_location^` 与 public mutex kind 的 `case AKind of` skeleton；host ffi
  继续只保留 `platform_errno_location` symbol binding 与 `PLATFORM_PTHREAD_MUTEX_*_KIND` 这类宿主 truth。
- `platform.sync` 的 POSIX errno classifier 已按 host-owner 模型收口：public `PLATFORM_ERR_*`
  仍是 nextPas sync contract，留在 `platform.sync`；但
  `PLATFORM_POSIX_EAGAIN/EBUSY/EINVAL/ENOTSUP/ETIMEDOUT` 到 public result 的分类现在由
  `linux/android/darwin/freebsd/unix.ffi` 的 `platform_pthread_sync_result` 承载，并委托 shared
  `platform_posix_sync_result_from_error` skeleton。consumer 不再直接依赖 host errno token，host ffi
  也不硬编码 nextPas public error 值。
- 这条边界已用 `test_platform_sync_host_ffi_surface` 固化：host `.ffi` 必须暴露
  `platform_pthread_sync_result` 并委托 shared `platform_posix_sync_result_from_error`，而
  `platform.sync` 必须消费 host helper 且不得直接引用 `PLATFORM_POSIX_E*`。完整收口验证已包含
  focused gates、`make -C core test` / `examples` / `benchmarks` 与
  `bash build/verify_local.sh` 的 `verify-local=pass`。
- `platform.sync` 不应继续自己保存 public mutex kind 到宿主 pthread 编号的映射；现在
  `linux/android/darwin/freebsd/unix.ffi` 统一暴露
  `platform_pthread_mutex_init_platform_kind`，consumer 只传 public `AKind`。
- Windows condvar timedwait / address-wait 的 timeout classifier 分支也不该继续散落在
  `platform.sync` consumer；现在 `windows.ffi` 继续拥有
  `windows_condvar_timedwait_timeout_result` 与
  `windows_wait_address_i32_timeout_result`，consumer 只传 caller-chosen
  `PLATFORM_ERR_TIMEOUT` result。
- 现在新增了 platform-level `test_platform_ffi_owner_boundary`：它会扫描整组
  `nextpas.core.platform*.pas`，固定“非 `*.ffi.pas` 不得声明 `external`、`*.ffi.pas`
  必须继续拥有 `external`、`platform.sync.windows.ffi` 不得回归”这三条 owner boundary。
- `core/src/nextpas.core.platform.android.ffi.pas`、
  `core/src/nextpas.core.platform.freebsd.ffi.pas`、
  `core/src/nextpas.core.platform.unix.ffi.pas` 已新增；`linux.ffi` 与 `darwin.ffi` 也扩成 host-owned
  clock/sysconf/errno owner，让 generic Unix fallback 不再偷偷继承 Linux 近似 token。
- `platform.time`、`platform.thread`、`platform.sync` 现在都会按 target 选择 host-owned FFI unit；
  generic Unix 分支显式走 `nextpas.core.platform.unix.ffi`，不再从 shared `posix.ffi`
  读取伪通用的 host token。
- 新增 `core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix/`，在 Linux 主机上用
  `NEXTPAS_FORCE_HOST_DARWIN`、`NEXTPAS_FORCE_HOST_ANDROID`、
  `NEXTPAS_FORCE_HOST_FREEBSD`、`NEXTPAS_FORCE_HOST_UNIX` 做 compile-only matrix proof；这条证据验证
  host branch selection 与 `platform.time/thread/sync + host ffi` compile coherence，但不是 runtime
  truth。
- `nextpas.core.settings.inc` 现在显式支持 test-only `NEXTPAS_FORCE_HOST_*` 覆盖层；这层 override 只能用于
  独立测试项目和 compile proof，不能在文档或结论里包装成真实 cross toolchain/runtime 支持。
- 这条 matrix proof 直接暴露并修掉了三个真实缺陷：
  - `platform.thread` 的 non-Linux Unix `uses` 条件块原先有前导逗号语法错误
  - `platform.posix.ffi` 原先有三处非法 `{$ELSEIFDEF ...}`，会把 FreeBSD 分支解析坏成重复声明
  - generic Unix 原先没有定义 `NEXTPAS_POSIX_CLOCK`，使 `platform.time` 与 `unix.ffi` 的 POSIX
    clock helper contract 自相矛盾
- generic Unix fallback 现在明确启用 `NEXTPAS_POSIX_CLOCK`；既然 `nextpas.core.platform.unix.ffi`
  已经承载 `clock_gettime` / `clock_getres` / pthread timeout clock truth，就不能再让
  `platform.time` 把 generic Unix 视为 unsupported。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与
  fresh `bash build/verify_local.sh` 都已通过；official envelope 现在包含
  `corePlatformSimulatedHostCompileMatrixCheck":"pass"`。
- 当前 `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-time-integration`
  仍未合入 `main`；`main...codex/platform-time-integration = 81:1`，说明它已经明显落后主线。它那 1 个独有
  提交混有 `demo_stopwatch`、L1 time benchmark 与过期的 platform.time 收口方式，不能整条合并；如果还要
  参考，只能按模块边界择优吸收。
- `platform_thread_self` 与 `platform_thread_id` 不是同一个契约：前者是 unowned current-thread
  token，后者应该尽可能返回宿主 native integer thread id。继续在所有 Unix 平台上把
  `pthread_self` 强转成 `UInt64` 会把 Darwin / FreeBSD 这类非整数 `pthread_t` 的语义糊成一层。
- 这批已把 host-native thread id ABI 继续沉进各自 FFI：
  Linux/Android 走 `gettid`，macOS 走 `pthread_threadid_np`，FreeBSD 走
  `pthread_getthreadid_np`，generic Unix 才保留 `pthread_self` fallback。
- `platform.thread` 的 POSIX sleep retry 现在不再对 `nanosleep` 的所有失败一律重试；各宿主 FFI 统一拥有
  `PLATFORM_POSIX_EINTR`，实现层只在 `platform_errno_location^ = PLATFORM_POSIX_EINTR` 时重试。
- 这也意味着 `nanosleep` 的 retry/error 语义现在和 mutex kind、condattr clock capability 一样，
  进入了 host-owned FFI truth，而不是继续躲在实现层 while-loop 假设里。
- 新增 `core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface/`，把
  host-native thread id declarations 与 `platform.thread` 的消费关系冻结成 source-surface gate；
  Linux behavior test 也已从“self token == thread id”改成 “`platform_thread_id` 对齐宿主 `gettid`”。
- fresh `bash build/verify_local.sh` 已再次通过，并把
  `core-platform-thread-host-ffi-surface-check=pass` /
  `corePlatformThreadHostFfiSurfaceCheck":"pass"` 纳入 official verification envelope；因此这批
  不只是局部测试过，而是已经进入仓库级回归面。
- `linux/android/darwin/freebsd/unix.ffi` 现在不再各自复制 `pthread_self` token 投影、
  `pthread_create/join/detach`、`sched_yield`、TLS key 读写、`sysconf` 正数投影与 `nanosleep`
  retry loop；这些 truly shared POSIX thread glue 已统一委托给 `nextpas.core.platform.posix.ffi`，
  host ffi 继续只保留 errno binding、`PLATFORM_POSIX_EINTR`、`_SC_NPROCESSORS_ONLN` 与
  native thread id ABI。
- `platform.sync` 的 Windows ABI 现在也并入统一 `nextpas.core.platform.windows.ffi`：
  `SRWLOCK`、`CONDITION_VARIABLE`、`WaitOnAddress` 与 `GetLastError` 不再留在
  `nextpas.core.platform.sync.windows.ffi` 这种按模块切碎的 FFI 单元里。
- `platform.sync` 现已补齐和 `platform.time` / `platform.thread` 同等级的 focused gate：
  behavior、no-FPC、L0 boundary、sizes、Win64 compile-only、example、benchmark 都进入
  official local verification surface。
- 新增 `core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface/`，把
  `platform.sync` 对 Linux futex ABI、Windows wait-address ABI 与 host-owned errno/clock token 的
  消费关系冻结成 source-surface gate；fresh `bash build/verify_local.sh` 已把
  `core-platform-sync-host-ffi-surface-check=pass` /
  `corePlatformSyncHostFfiSurfaceCheck":"pass"` 纳入 official envelope。
- `codex/platform-time-integration` 当前不是可直接 merge 的活跃平台分支：`main` 相对它 ahead `81`，
  它自己只 ahead `1`，且那个唯一提交混有 `demo_stopwatch`、L1 `bench_platform_time` 与广泛
  Makefile/doc 改动；它更适合作为历史参考，而不是整条合入主线。
- `platform.sync` 现在还有 generic `NEXTPAS_UNIX` pthread runtime 路径：
  non-Linux Unix 的 `platform_wait_address32` / wake 走 bucketed condvar fallback，Linux 继续默认
  走 futex，但可以通过 `NEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK` 在 Linux 主机上强制验证
  fallback surface。
- `nextpas.core.platform.posix.ffi` 现在不再拥有 per-host pthread capability truth：`PTHREAD_MUTEX_*`
  kind 编号与 `pthread_condattr_setclock` 已继续下沉到 `linux/darwin/android/freebsd/unix` 各自的 FFI
  owner 单元。
- `linux/darwin/android/freebsd/unix` FFI 现在统一暴露
  `PLATFORM_PTHREAD_MUTEX_*_KIND`、
  `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED`、
  `PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` 与
  `platform_pthread_condattr_setclock`，让 `platform.sync` 不再在实现层自己保存 pthread capability
  例外知识。
- `darwin.ffi` 现在显式承载 “`pthread_condattr_setclock` 不支持” 这条宿主事实；shared `posix.ffi`
  不再假装所有 POSIX 宿主都共享这条 capability。
- `nextpas.core.platform.posix.ffi` 现在开始按 target matrix 诚实建模 pthread ABI，而不是继续用
  Linux 近似值覆盖所有 POSIX：
  FreeBSD 的 mutex/rwlock/condvar/attr 都回到 pointer-backed handle；
  macOS 的 opaque size 固定为 `64/16/200/24/48/16`；
  Android 固定为 `40/PtrInt/56/PtrInt/48/PtrInt`；
  Linux 固定为 `40/Int32/56/Int64/48/Int32`；
  同时补齐 `pthread_rwlockattr_t` 与 FreeBSD mutex type 常量编号。
- `platform.sync` 的 public opaque storage 现在也按 Linux/Android/macOS/FreeBSD/Windows/generic
  Unix 分支，至少在 public size/align surface 上不再把 FreeBSD pointer handle 或 macOS rwlock
  继续装进“通用 Unix 大数组”里。
- `platform.sync` 的 POSIX wait-bucket fallback 是 nextPas 的跨平台 wait/wake policy，而不是
  raw OS ABI；因此 `POSIX_WAIT_BUCKET_COUNT`、`TPosixWaitBucket`、waiter/generation 计数和
  release predicate 应继续留在 `platform.sync`。host `.ffi` 继续只拥有 Linux futex、pthread condvar、
  Windows WaitOnAddress 等宿主 helper 及 caller-supplied result projection，不能反向拥有
  wait-bucket policy。
- `platform_wait_address32` / `platform_wake_address_one` / `platform_wake_address_all` 的 nil
  address 处理属于 `platform.sync` public contract。Linux futex 和 POSIX fallback 已有 guard；Windows
  wrapper 也需要在调用 `windows_wait_address_i32_timeout_result` /
  `windows_wake_address_*` 前统一返回 `PLATFORM_ERR_INVALID`，不能把 nil 直接交给 raw WinAPI helper。
- `platform.sync` 的 size ownership 现在进一步收回到 FFI 类型本身：
  POSIX 分支直接取 `SizeOf(pthread_mutex_t)` / `SizeOf(pthread_rwlock_t)` /
  `SizeOf(pthread_cond_t)`，Windows 分支直接取 `SizeOf(SRWLOCK)` /
  `SizeOf(CONDITION_VARIABLE)`，不再在 wrapper 里复制一套平台 size 数字。
- `nextpas.core.platform.windows.ffi` 现在显式声明 `SRWLOCK` 与
  `CONDITION_VARIABLE` 类型，让 Windows sync ABI 在类型层也能成为单一事实源，
  而不是只剩过程声明。
- 新增 `core/tests/nextpas.core.platform/test_platform_posix_ffi_surface/`，并扩充
  `test_platform_sync_posix_surface`，把 target-specific pthread ABI token 与 public opaque size
  branch 都冻结成 source-surface gate。
- 新增 `core/tests/nextpas.core.platform/test_platform_ffi_partition_surface/`，把
  `posix.ffi` shared-vs-host ownership、Linux/macOS/Android/FreeBSD/generic Unix 的 host-owned
  FFI surface 全部冻结成 source-surface gate；同时测试必须支持“从测试目录运行”和“从 repo root 的
  official verify 入口运行”两种路径解析。
- `build/verify_local.sh` 现在不仅运行 sync focused gates，也会把
  `corePlatformFfiOwnerBoundaryCheck`、
  `corePlatformFfiPartitionSurfaceCheck`、
  `corePlatformPosixFfiSurfaceCheck`、`corePlatformSyncCheck`、
  `corePlatformSyncNoFpcCheck`、`corePlatformSyncL0BoundaryCheck`、
  `corePlatformSyncPosixSurfaceCheck`、`corePlatformSyncSizeCheck`、
  `corePlatformSyncWin64Check`、`corePlatformSyncExampleCheck`、
  `corePlatformSyncBenchCheck`、`corePlatformSyncPosixFallbackCheck`、
  `coreSyncPosixFallbackCheck` 正式写进最终 `verify-local` envelope。
- `nextpas.core.platform.posix.ffi` 现在拥有跨 Linux/Android、macOS/FreeBSD 的 errno surface：
  `POSIX_EAGAIN` / `POSIX_EBUSY` / `POSIX_EINVAL` / `POSIX_ENOTSUP` / `POSIX_ETIMEDOUT`
  与 `posix_errno_location` 已沉到 nextPas-owned FFI，而不是让实现层去猜宿主符号。
- POSIX fallback timeout 现在围绕绝对 deadline 等待，而不是每次把“剩余相对时间”重新转成新的
  absolute timeout；这样 repeated wait/signal/recheck 不会把 timeout 一轮轮往后漂。
- wait-bucket 初始化现在会在失败时回收已初始化 mutex/condvar，避免进程里残留半初始化的
  fallback runtime 状态。
- `test_platform_sync` 在 FPC 宿主上需要显式 `cthreads` 才能稳定覆盖 pthread-backed fallback；
  否则 forced-fallback test 可能在所有断言通过后仍于 runtime teardown 崩溃。
- 这批仍保留一个明确 residual risk：macOS / FreeBSD / Android 的 opaque size 选择、pthread
  library 绑定方式与 condvar clock 行为，还需要真实 compile/runtime matrix 证据，不能只靠 Linux
  forced-fallback 绿灯当成完全闭环。
- `platform.sync` benchmark 不再直接取用裸 `posix.ffi` 时钟 ABI，而是改走
  `nextpas.core.platform.time` 的 L0 平台时钟源；这样基准仍留在 platform 命名空间内，但不再绕开
  platform 自己的 FFI/contract 边界。
- `platform.time` 不再直接 `uses Linux`、`UnixType` 或 `Windows`，也不在实现单元中声明
  `external` ABI；`test_platform_time_no_fpc_units` 固定这个硬规则。
- time conversion helper 现在对不可表示的 UInt64 结果做饱和，对负的 timespec 输入归零，并用
  ceil 计算 frequency resolution，避免对 Windows QPC/macOS timebase 精度做过度承诺。
- QPC / mach timebase 的 fractional multiply/divide 边界已补强：当 divisor 很大导致
  `remainder * multiplier` 会溢出但最终商仍可表示时，走逐位 fallback 而不是直接饱和。
- `build/verify_local.sh` 已提升 platform time focused gates：time helpers、no-FPC 静态检查和 Win64
  compile-only 都会进入 official local verification。
- Batch 104 把 `sema.type-mismatch` evidence 从变量/参数推进到 root-owned 零参 function result：
  `function Flag: Boolean; Pick(Flag);` 调 `Pick(Integer)` 现在会失败且不注册失败 call binding。
- function-result evidence 只接受 root-owned、零参、builtin scalar/string return type；imported、
  带参、member function result、function pointer、class/record/alias/Pointer/Text/Variant 继续 deferred。
- Batch 104 新增 `type-mismatch-function-result-call-check`，用 dedicated fixture 固定 stage0
  `sema.type-mismatch` projection 与 final envelope。
- Batch 104 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `type-mismatch-function-result-call-check=pass`、`typeMismatchFunctionResultCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 102 已把 platform.time focused tests 迁入 `core/tests/nextpas.core.platform.time/`，
  并让 official gates 指向 platform 命名空间；`nextpas.core.time/test_time` 继续只覆盖 L1
  `time` public API。
- Batch 102 fresh verification 已闭环：focused platform.time tests、`make -C core test`、
  `make -C core examples`、`make -C core benchmarks` 均通过，fresh `bash build/verify_local.sh`
  输出 `corePlatformTimeHelpersCheck=pass`、`corePlatformTimeNoFpcCheck=pass`、
  `corePlatformTimeWin64Check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- platform.time 批次的 fresh verification 已闭环：`make -C core test`、`make -C core examples`、
  `make -C core benchmarks` 通过，`bash build/verify_local.sh` 输出
  `verify-local=pass` 与 `human-summary=local verification passed`。
- `platform.time` 示例/基准必须贴着 L0 clock source 语义：本批新增
  `nextpas.core.platform.time/platform_time_clock` 与
  `nextpas.core.platform.time/bench_platform_time_clock`，只调用 platform clock API，不引入
  `Stopwatch`、`Duration` 或 L1 time convenience API。
- 新增 `nextpas.core.platform.time/test_platform_time_l0_boundary`，把这个边界变成 gate：
  platform.time 源码、platform 门面、platform 示例和 platform 基准不能引用
  `nextpas.core.time`、`TStopwatch`、`TDuration`、`TInstant` 或 Timer。
- 旧 `codex/platform-time-integration` 仍有可参考内容，但其中 `demo_stopwatch`、L1 time 基准、
  通用 Makefile 批量改动和已过期 platform.time 代码不能整条合入；后续只能按模块边界择优搬迁。
- `build/verify_local.sh` 已增加 platform.time boundary/example/benchmark focused gates，并在 final
  envelope 暴露 `corePlatformTimeL0BoundaryCheck`、`corePlatformTimeExampleCheck` 与
  `corePlatformTimeBenchCheck`。
- platform.time L0 surface coverage 的 fresh verification 已闭环：`make test`、`make examples`、
  `make benchmarks` 通过，fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeL0BoundaryCheck=pass`、`corePlatformTimeExampleCheck=pass`、
  `corePlatformTimeBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- `platform.thread` 的 public surface 不应把 current-thread identity 与 create/join/detach lifecycle
  handle 混成同一个类型：`TPlatformThreadHandle` 现在只表示 `platform_thread_create` 返回的 owned
  handle，`platform_thread_self` 返回新的 `TPlatformThreadToken` unowned identity token。
- `platform_thread_self` 的 focused RED 先失败在 `Identifier not found "TPlatformThreadToken"`；
  修正后 `test_platform_thread` 输出 `8 total, 8 passed, 0 failed`，补齐这个 public API 的接口覆盖。
- `platform.thread` 示例和基准必须贴着 L0 thread surface：本批新增
  `platform_thread_lifecycle` 与 `bench_platform_thread_lifecycle`，只覆盖 create/join、TLS、
  self/id、yield/sleep 与 CPU count，不引入 `nextpas.core.thread`。
- 新增 `test_platform_thread_l0_boundary`，把 L0/L1 并发边界变成 gate：platform.thread 源码、
  示例和基准不能引用 `nextpas.core.thread`、ThreadPool、Channel、Future、Scheduler 或 Task。
- `build/verify_local.sh` 已增加 platform.thread behavior/no-FPC/L0-boundary/Win64/example/benchmark
  focused gates，并在 final envelope 暴露 `corePlatformThreadCheck`、
  `corePlatformThreadNoFpcCheck`、`corePlatformThreadL0BoundaryCheck`、
  `corePlatformThreadWin64Check`、`corePlatformThreadExampleCheck` 与
  `corePlatformThreadBenchCheck`。
- Windows FFI 已移除不再消费的 `GetCurrentThread` 声明；self token 使用 `GetCurrentThreadId`，
  避免 Win32 pseudo handle 被误投影成可 join/detach 的 platform handle。
- platform.thread L0 surface coverage 的 fresh verification 已闭环：`make -C core test`、
  `make -C core examples`、`make -C core benchmarks` 均通过；fresh
  `bash build/verify_local.sh` 输出 `corePlatformThreadCheck=pass`、
  `corePlatformThreadNoFpcCheck=pass`、`corePlatformThreadL0BoundaryCheck=pass`、
  `corePlatformThreadWin64Check=pass`、`corePlatformThreadExampleCheck=pass`、
  `corePlatformThreadBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- Batch 103 把 `@np_object_release_invalid` 从 no-op boundary 推进成最小 fatal failure policy：
  invalid helper 会调用 `@llvm.trap()`，随后发出 `unreachable`。
- Batch 103 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 102 的 invalid helper 仍 `ret void`，因此
  object-free focused test 失败在 `missing-object-free-release-invalid-trap-call`。
- 修正后 magic mismatch / double free 已有最小 fatal runtime 行为，但这还不是结构化 diagnostics、
  Pascal exception、core allocator 接管或完整 validation runtime。
- Batch 102 把 `@np_object_free_release` 的 magic mismatch 路径推进成 compiler-owned
  invalid-release boundary：非法 header 会进入 `invalid:`，调用
  `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后再汇合到 `done:`。
- Batch 102 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 101 后的 mismatch path 仍直接跳 `done:`，因此
  object-free focused test 失败在 `missing-object-free-release-header-magic-branch`。
- 修正后 invalid-release helper 当前仍是 no-op；它只是 diagnostics/trap/future runtime policy 的
  唯一挂载点，不是 allocator free、异常抛出、core allocator 接管或完整 validation runtime。
- Batch 101 把 `@np_object_release_valid` 从 no-op boundary 推进成 valid release 后的 magic poison：
  helper 会定位 header offset 8 并写入 `0`，让重复释放同一 payload pointer 在下一次进入
  `@np_object_free_release` 时走 magic mismatch skip 路径。
- Batch 101 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 100 的 valid-release helper 只 `ret void`，因此
  object-free focused test 失败在 `missing-object-free-release-poison-magic-slot`。
- 修正后 release poison 已是实际运行期状态变化，但仍不是 allocator free、diagnostics/trap failure
  path、core allocator 接管或完整 dynamic dispatch runtime。
- Batch 100 把 magic-valid `release:` 占位块推进成 compiler-owned
  `@np_object_release_valid(ptr %raw, i64 %size)` boundary；只有 header magic 校验通过后才会调用，
  参数固定为 header raw pointer 与 payload size。
- 新 focused RED 固定旧行为缺口：Batch 99 的 `release:` 仍只是 `br label %done`，因此
  object-free focused test 失败在 `missing-object-free-release-valid-boundary-call`。
- 修正后 valid-release helper 当前仍是 no-op，只是未来 allocator free / poison / statistics 的唯一
  挂载点；这还不是 allocator free、diagnostics/trap failure path、core allocator 接管或完整 dynamic
  dispatch runtime。
- Batch 99 把 `@np_object_free_release` 从 header read contract 推进到 header magic validation
  branch：读取 `%magic` 后会比较 `1313882451`，合法 header 进入 `release:` 占位块，非法 header
  直接汇合到 `done:`。
- 新 focused RED 固定旧行为缺口：Batch 97 的 release helper 读出 magic 后直接
  `br label %done`，因此 object-free focused test 失败在
  `missing-object-free-release-header-magic-check`。
- 修正后 release helper 已有可观察的合法/非法 header 分支，但 `release:` 当前仍是空占位；这还不是
  真实 allocator free、diagnostics/trap failure path、core allocator 接管或完整 dynamic dispatch
  runtime。
- Batch 97 把 object allocation/release helper boundary 推进成最小 header ownership contract：
  `@np_object_alloc` 现在申请 `payload size + 16`，在 header offset 0 写 payload size，在
  offset 8 写 magic `1313882451`，再返回 payload pointer。
- 新 focused RED 固定旧行为缺口：Batch 96 的 allocation helper 只委托 `@np_alloc(size)`，release
  helper 仍为空，因此 class alloc test 失败在 `missing-hir-class-alloc-header-size`，object-free
  test 失败在 `missing-object-free-release-header-base`。
- 修正后 `@np_object_free_release` 会防御性处理 null，并从 payload pointer 回退 16 bytes 读取
  payload size 与 magic header；这只是 ownership contract 和后续 allocator free 的入口证据，
  还不是验证失败路径或真实 free。
- Batch 96 把 class allocation 的 LLVM lowering 从直接 `@np_alloc` 推进到 compiler-owned
  `@np_object_alloc` helper boundary。
- 新 focused RED 固定旧行为缺口：HIR 已有 `class_alloc` intrinsic，但 LLVM emitter 直接生成
  `call ptr @np_alloc(...)`，因此失败在 `missing-hir-class-alloc-object-helper-call`。
- 修正后 class allocation site 会生成 `call ptr @np_object_alloc(i64 ...)`，内部
  `@np_object_alloc(i64 %size)` helper 再委托 `@np_alloc(i64 %size)`；这只是 object
  allocation/release ABI boundary，不是 object header、ownership metadata 或真实 allocator
  free 已完成的证据。
- Batch 95 把 `object-free-runtime` 中的 `heap-release true` 推进到 HIR/LLVM 后端可见边界：
  matching owned `Destroy` 之后现在会追加 `np.system.object_free.release` HIR marker。
- 新 focused RED 固定旧行为缺口：Batch 94 已有 nil branch 和 guarded `Destroy`，但 builder
  没有 release marker，LLVM 也没有 `@np_object_free_release` hook，因此失败在
  `missing-object-free-release-intrinsic`。
- 修正后 LLVM HIR emitter 会在 `objectfree.destroy.*` 非空分支内按顺序发出
  `@TObject.Destroy` call 与 `call void @np_object_free_release(ptr ...)`，然后汇合到
  `objectfree.end.*`；nil receiver 仍直接跳过二者。
- 当前 `@np_object_free_release` 是内部空 helper，只是稳定 backend/runtime 接入口；真实
  allocator free、object header ownership、完整 dynamic dispatch runtime 和 implicit
  `System.pas` backend/link 接管仍未完成。
- `platform.thread` 现在可以在不直接 `uses` FPC 平台单元的前提下覆盖 thread lifecycle、TLS、
  yield/sleep 和 CPU count；禁止规则由 `test_platform_thread_no_fpc_units` 固定。
- Windows `CreateThread` 不能接收 Pascal cdecl user proc，也不能靠 32-bit thread exit code 携带
  64-bit pointer return value；本批改为 stdcall trampoline state，由 join 读取 state 中保存的
  return pointer。
- `platform.thread` 和 `platform.sync` 共同使用 `posix.ffi`，因此 FFI 文件必须取并集；clean
  preview 基于 `main@ad236a2` 保留 sync 的 mutex/rwlock/condvar 声明，并追加 thread 的
  detach/self/TLS/nanosleep/sched_yield/sysconf 声明。
- 本批刻意不混入独立 `platform.time` hardening commit；`windows.ffi` 只保留 thread/TLS/yield/sleep/
  cpu-count 所需 ABI，后续 time 合并时再追加 QueryPerformance/FileTime 等 time-only FFI。
- Batch 94 把 object-free lifecycle contract 推进到 LLVM HIR emitter：`np.system.object_free`
  现在会生成 receiver pointer 的 `icmp eq ptr ..., null` 与 conditional branch；匹配的
  `np.system.object_free.destroy` call 位于 `objectfree.destroy.*` 非空分支，并在调用后汇合到
  `objectfree.end.*`。
- 新 focused RED 固定旧行为缺口：Batch 92 的 LLVM emitter 只保留 owned destroy ordinary call，
  因此失败在 `missing-object-free-llvm-null-check`。
- 初次 guarded emitter 实现暴露 builder 侧 receiver reload 缺口：owned destroy 前的额外 load 会让
  guard 提前关闭；修正后 `THIRBuilder` 会复用 object-free marker 已解析出的 receiver pointer。
- 修正后 focused test 输出 `hir-object-free-contract-status=pass`；fresh full verify 已输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 这个切片已经有真实 LLVM nil branch，但仍不是完整对象释放：allocator free、完整 dynamic dispatch
  runtime、implicit `System.pas` 自动 assemble/link 与完整 `System` 平替仍未完成。
- Batch 92 把 `np.system.object_free` 与紧随的 effective `Destroy` 连接成 HIR lifecycle group：
  匹配 receiver/destroy target 的后续 `call-runtime` 现在会成为 `hikIntrinsic` /
  `np.system.object_free.destroy`，而不是裸 `hikCall @TObject.Destroy`。
- 新 focused HIR RED 固定旧行为缺口：在 `object-free-runtime` 后追加匹配
  `call-runtime TObject.Destroy` 时，旧实现失败在 `plain-object-free-destroy-call`。
- 修正后 focused test 输出 `hir-object-free-contract-status=pass`；fresh full verify 已输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- LLVM HIR emitter 现在让 `np.system.object_free.destroy` 复用 ordinary call emission，
  所以本批保留当前可执行析构 call 行为，但仍不声称 nil guard、allocator free 或完整动态
  dispatch runtime 已完成。
- Batch 91 把 `object-free-runtime` 从 semantic typed HIR 接到 HIR builder：`THIRBuilder` 现在会
  生成 `hikIntrinsic` / `np.system.object_free` marker，receiver 以 pointer operand 保留，
  effective `Destroy` 名称保存在 `CallTarget`。
- 新 focused HIR RED/GREEN 固定这个边界：旧实现失败在
  `missing-object-free-hir-intrinsic`，修正后输出
  `hir-object-free-contract-status=pass`；`build/verify_local.sh` 也新增
  `hir-object-free-contract` gate，fresh full verify 已输出 `hir-object-free-contract=pass` 与
  `verify-local=pass`。
- 这个 HIR bridge 仍不是真实对象释放：当前 LLVM HIR emitter 不展开 nil guard、不调用 allocator
  free，也不声明完整 dynamic dispatch runtime 已完成。
- Merge-preview closeout 已证明 platform.sync 分支可以和最新 `main` 的 source-backed
  `System/TObject`、`ICondVar`、Vec/interface allocator 等变更共存；冲突只落在设计约定和
  跟踪文档，源码自动合并后通过全量验证。
- `nextpas.core.platform.sync` 当前只依赖 `nextpas.core.platform.posix.ffi`、
  `nextpas.core.platform.linux.ffi`、`nextpas.core.platform.windows.ffi`，不再 `uses`
  FPC 的 `Linux`、`PThreads`、`UnixType`、`BaseUnix`、`Syscall`、`Windows` 平台单元。
- `nextpas.core.platform.linux.ffi` 已保持为纯 ABI 声明文件；`__errno_location` 只作为
  external declaration 暴露，读取 errno 的逻辑位于 `platform.sync` 实现层。
- 主线新增的 `atomic`、`hashmap`、`arena`、`pool`、`thread` 测试项目暴露了 per-project
  Makefile 规则的合并缺口；补齐后 `make -C core test` 已能覆盖全部 core 测试项目。
- `platform.time` 脱离 FPC 平台单元这条硬规则债务已经在主线关闭；当前更真实的后续债务是
  Darwin / FreeBSD / Android 的 compile/runtime 证据矩阵，以及旧 platform worktree 的清理与归档边界。
- Platform sync closeout 证明 `build/verify_local.sh` 之前不是 stage0 行为失败，而是 verification
  contract 自身把 explicit workspace 固定成 `.*/nextPas`，导致 linked worktree 下误报
  `missing-stage0-workspace-root`。
- `verify_local` 现在通过 `escape_ere()` 派生当前 `REPO_ROOT`、workspace artifact/output、
  distribution/runtime root 的正则 pattern；line output 用 literal 断言，JSON envelope 用
  escaped regex 断言，保留精确性但不再绑定主 checkout 目录名。
- `core-text-smoke-check` 不再写死 `/home/dtamade/projects/nextPas/rtl/core/...`，而是使用当前
  `REPO_ROOT/rtl/core/...`，让 smoke 在 worktree 内自洽。
- `core-platform-sync-check` 顶层 summary 已同步到当前 14 项接口覆盖；fresh
  `bash build/verify_local.sh` 已通过并输出 `verify-local=pass` / `human-summary=local verification passed`。
- Batch 89 把 source-backed implicit `System` 的对象生命周期从 `TObject.Free` binding 推进到
  no-fold typed HIR 的 effective `Destroy` runtime call：普通 class 没有显式父类时，会继承
  `System.TObject` 的 VMT slot/function metadata。
- `compiler/sema/np_semantic_analyzer.pas` 现在让隐式 `ParentTypeId` 也参与 class layout 复制，
  并让 `Free` lowering 通过 `TClass$vmt_slot_Destroy` / `TClass$vmt_func_<slot>` 选择当前有效
  destructor；继承路径可落到 `TObject.Destroy`，不再硬写不存在的 `TWorker.Destroy`。
- 新 focused semantic RED/GREEN 固定这个边界：旧实现失败在
  `missing-implicit-system-free-inherited-destroy-lowering`，修正后
  `semantic-call-bindings-status=pass`。这仍不是完整 heap free、nil guard、动态 virtual dispatch
  runtime 或 backend/link 接管。
- Batch 88 把 implicit runtime `System` 从无来源 placeholder 推进到 source-backed semantic truth：
  program 即使没有显式 `uses System`，semantic analyzer 也能从
  `units/linux-x86_64/System.pas` 读取 `TObject` / `TObject.Free`。
- 这次升级只发生在 semantic model：implicit runtime unit 的 `OriginClass` 仍是
  `implicit-runtime`，所以 backend extra assemble 继续跳过它，不会让所有 program 自动编译/链接
  nextPas 自定义 `System.pas`。
- 显式 `uses System` 仍不会被 implicit runtime source path 短路；resolver 会继续 normal search，
  并允许 `TUnitGraph.AddResolvedUnit(...)` 把 source-backed implicit runtime 节点升级成显式
  `installed-source` provenance。
- 新增 `tests/fixtures/system_object_free/system_object_free_implicit_binding.pas` 与
  `stage0-query-system-object-free-implicit-check`，固定无显式 uses 下 `Worker.Free` 到
  `TObject.Free` 的 binding 和 definition source path。
- Batch 87 落地第一条 nextPas-owned source-backed `System` truth：`rtl/core/system/System.pas`
  与 `units/linux-x86_64/System.pas` 现在先提供 `TObject.Create`、`TObject.Destroy` 和
  `TObject.Free`。
- 当显式 `uses System` 让 target-installed `System.pas` 进入 `TUnitGraph` / `TSemanticModel`
  后，普通 `class` 会默认继承 owner=`system` 的 `TObject`；`Worker.Free` 通过现有
  `ParentTypeId` 继承 member lookup 绑定到真实 `TObject.Free`，不是新增字符串兜底。
- 新增 `tests/fixtures/system_object_free/system_object_free_binding.pas` 与
  `stage0-query-system-object-free-check`，固定 `querySymbols` 中的 `TObject.Free` method symbol、
  `queryBindings` 中的 `Free` member-call，以及 `queryDefinitions.targetSourcePath` 指向
  `units/linux-x86_64/System.pas`。
- implicit runtime edge 仍保持 placeholder，本批没有让所有 program 自动编译/链接
  `System.pas`；没有 source-backed System truth 的路径仍让 `Free` deferred，避免把最低 runtime
  baseline 缺口误报为普通 unknown member。
- Batch 86 把 receiver type 已知的 direct class member-call name miss 接进 structured diagnostics：
  `Worker.Missing(1)` 这类 class/parent chain 没有同名 method 的调用会发出
  `sema.unknown-member`，model status 进入 `failure`，且不会注册 `member-call` binding。
- `ClassTypeHasKnownNonMethodMember(...)` 让已知 field / property 名称保持 deferred，不把
  `Worker.Value(1)` 这类后续应由 non-callable / field-property access 处理的边界误报成 unknown member。
- 新增 `tests/fixtures/unknown_member/unknown_member_fail.pas` 与 `unknown-member-check`，固定
  stage0 failure projection、`diagnosticsSummary=sema.unknown-member` 和 final envelope
  `unknownMemberCheck=pass`。
- Full verify 首轮暴露 `examples/smoke/llvm_destructor.pas` 的 `C.Free` 被误报为
  `sema.unknown-member`；这不是普通 member miss，而是当前尚未有 source-backed nextPas
  `System` / `TObject` truth 的结果。本批先把 `Free` 保持 deferred，后续要用真实
  `System.pas` / `TObject` 符号替代临时边界。
- Full verify 后段又暴露 `tests/parser/generics_pass.pas` 的 `TIntStack.Push` 被误报为
  `sema.unknown-member`；`TIntStack = specialize TStack<Integer>` 当前还没有 generic instantiation
  member truth。本批把 unknown-member 限定到已有 class layout truth 的 receiver，alias /
  generic specialization / record-like receiver 继续 deferred。
- nextPas-owned `System` 是自举代码和 `core` 框架的最低依赖层：它负责平替宿主 FPC
  `System` 中必须先稳定的基础类型、对象生命周期、启动/退出和 runtime helper 事实；
  `core` 框架应建立在这层之上，而不是反向承担编译器最低语义前提。
- Batch 85 重新验证最新 baseline：detached clean worktree 基于 `287d13d` 已输出
  `unknown-callable-check=pass`、`unit-root-precedence-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- `unit_root_precedence` 曾暴露 host FPC backend cache 污染：前序 build 留下的
  `Stage0Greeter` 中间产物可能让后续显式 `--unit-root` 构建运行到旧 installed-source 行为；
  当前 runner 会在 host compiler step 前清理旧 `.ppu/.o/.s/*_link.res/*_ppas.sh`。
- 当前最高价值后续路线仍是非 `core/` 的 G1.5/G1.6：优先补 source-owned、证据稳定、
  误报风险可控的 unknown member 或 no-matching-overload diagnostic。
- Batch 84 把 source-owned bare callable name miss 接进 structured diagnostics：当 bare call
  的名字既不是 root/imported procedure/function、也不是已知 symbol/type/builtin callable 时，
  semantic analyzer 发出 `sema.unknown-callable`，model status 进入 `failure`，且不会注册 call binding。
- 本批刻意不把已知非 callable symbol、typecast 形态、function pointer、imported helper no-match 或
  unknown member 一起归类；这些仍留给后续 G1.5/G1.6 切片。
- 新增 `unknown-callable-check`，用 `tests/fixtures/unknown_callable/unknown_callable_fail.pas`
  固定 stage0 failure projection 与 final envelope `unknownCallableCheck=pass`。
- Batch 83 新增 `docs/architecture/nextpas-goal-tree.md`，把 nextPas 的北极星目标、G0-G8
  能力树、当前完成度、近期优先级和每轮报告格式收成总控地图。
- 目标树明确后续每轮批次必须绑定目标节点；近期最高价值非 core 路线是继续推进
  G1.4/G1.5/G1.6：semantic model、call/member/overload resolution 与 diagnostics。
- 目标树明确当前协作边界：`core/` 由 core 负责人推进；本工作流不直接修改 `core/` 代码，
  只提出 compiler/tooling 侧 integration requirement 或 review/suggestion。
- `build/verify_local.sh` docs-check 现在要求 `docs/architecture/nextpas-goal-tree.md` 存在，
  防止总控目标树脱离 verification surface。
- Batch 82 把 `nextpas.core.time` 纳入顶层官方验证面：`build/verify_local.sh` 新增
  `core-time-check`，编译并运行 `core/tests/nextpas.core.time/test_time/test_time.lpr`，并在
  final envelope 中暴露 `coreTimeCheck=pass`。
- `core.platform.time` 现在是 `TInstant.Now` 的 platform-owned monotonic clock 来源，同时由
  `nextpas.core.platform` facade re-export `PlatformMonotonicNs` / `PlatformRealtimeNs` /
  `PlatformMonotonicResolutionNs`。
- `core.platform.time` 的 Unix 路径使用 `clock_gettime` / `clock_getres`，并检查返回值；Windows
  路径保留 `QueryPerformanceCounter` / `GetSystemTimeAsFileTime` 结构，未知平台 fallback 只保证可编译。
- `nextpas.core.time` focused test 现在覆盖 13 项，包括 direct platform time facade：
  monotonic 不倒退、Linux realtime 可用、resolution 至少 1ns。
- 本批不声明 DateTime、timezone、Timer、scheduler、async runtime 或完整跨平台时间库已经完成。
- Batch 81 把 `sema.type-mismatch` evidence 从变量扩展到当前 callable scope 中已声明为内建
  标量/字符串类型的参数：`procedure Run(Flag: Boolean); begin Pick(Flag); end;` 调
  `Pick(Integer)` 现在会失败并且不注册该失败 call binding。
- `TProcedureBodyEntry` 现在记录 callable scope id，call binding walker 进入 procedure/function
  declaration body 时会切到对应 scope，让参数 lookup 不再退化到 root scope。
- parameter symbol 现在记录声明 type id；stable scalar evidence 明确限制为 `variable` /
  `parameter` symbol，`function Flag: Boolean` 这类函数返回值 symbol 继续不作为 diagnostic evidence。
- bare single-target call 若 argument signature 已知但缺少 stable evidence 且 signature 不匹配，会保持
  no diagnostic / no binding 的 deferred 边界，避免把函数返回值 mismatch 误注册为有效 call binding。
- Batch 81 新增 `type-mismatch-parameter-call-check` 与
  `member-type-mismatch-parameter-call-check`，用 dedicated fixtures 固定 bare/member 参数
  `sema.type-mismatch` projection 与 final envelope。
- Batch 80 把 `sema.type-mismatch` evidence 从 literal/纯表达式扩展到当前 scope 中已声明为内建
  标量/字符串类型的变量参数：`Flag: Boolean; Pick(Flag);` 调 `Pick(Integer)` 现在会失败并且不注册
  binding。
- 新增 `TypeIdHasStableScalarFact(...)`，只认可 `Boolean`、整数/浮点、`Char` 与内建字符串族变量；
  `Pointer`、`Text`、`Variant`、declared class/record/alias、成员访问、函数结果仍不作为 diagnostic
  evidence。
- Batch 80 新增 `type-mismatch-variable-call-check` 与 `member-type-mismatch-variable-call-check`，
  用 dedicated fixtures 固定 bare/member 变量参数 `sema.type-mismatch` projection 与 final envelope。
- Batch 79 把第一条可证明 type no-match 接进 call diagnostics：bare procedure/function call 与
  direct member-call 在只有 root-owned 单一 target、arity 已匹配、argument signature 来自稳定事实且与
  param signature 明确不兼容时，会发 `sema.type-mismatch`，model status 进入 `failure`，且不会注册
  `call` / `member-call` binding。
- `sema.type-mismatch` 还要求 argument signature 来自 literal/纯表达式等稳定事实；变量、成员或函数结果
  相关 no-match 继续 deferred。
- `True` / `False` 现在由 `InferExpressionType(...)` 识别为 `Boolean`，避免 boolean literal
  在 call argument signature 中退化为 unknown identifier。
- `LookupCallBindingDeclaration(...)` 不再因为 bare call target 唯一就绕过 signature check；
  单一 target 的 signature mismatch 会透传 `type-mismatch` failure kind。
- `MethodSymbolIdForExactClassTypeMember(...)` 同样会在 direct member-call 单一 target signature
  mismatch 时透传 `type-mismatch` failure kind。
- Batch 79 仍保持 imported target 与多 overload signature no-match deferred；implicit conversion、完整
  ranking、unknown callable/member、record/property/array/deref receiver 与完整 member resolver 继续 deferred。
- fresh verify 首轮证明 imported RTL/helper surface 不能纳入本批 type-mismatch 诊断：`ExpandFileName` /
  `FileExists` 曾被过宽规则误报，原因是 compact signature 还不足以完整表达 imported declaration
  与 caller-side alias/string facts。
- fresh verify 二轮证明变量 type facts 也不能纳入本批 diagnostic evidence：`SetNext(TNode)` 被变量参数
  `B` / `C` 误报后，type mismatch 诊断边界收紧为 literal/纯表达式稳定事实。
- 新增 `type-mismatch-call-check` 与 `member-type-mismatch-call-check`，用 dedicated stage0 failure
  fixtures 固定 `sema.type-mismatch` projection 与 final envelope。
- Batch 78 把 `sema.wrong-argument-count` 从 bare call 扩到 direct member-call：当前已支持的
  class/type receiver path 中，同名 method 已知但没有任何同 arity target 时，semantic analyzer
  会发 diagnostic，model status 进入 `failure`，且不会注册 `member-call` binding。
- `MethodSymbolIdForExactClassTypeMember(...)` 现在通过 `AResolutionFailureKind` 区分普通
  deferred、`ambiguous-overload` 与 `wrong-argument-count`；exact receiver type 明确 wrong arity
  时不会继续穿透 parent class 代偿。
- Batch 78 仍保持 receiver/type/signature 保守边界：未知 member、receiver 未覆盖、body mismatch、
  signature no-match、implicit conversion、default parameter lowering/ranking、visibility 与完整
  member resolver 继续 deferred。
- `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 里的历史 `Worker.SetValue;`
  负例在 Batch 78 后不再属于 success query fixture；它现在应由 dedicated
  `member_wrong_argument_count_fail.pas` 固定 semantic failure projection。
- 新增 `member-wrong-argument-count-check`，用 `tests/fixtures/member_wrong_argument_count` 固定
  stage0 failure projection 与 final envelope `memberWrongArgumentCountCheck=pass`。
- Batch 77 把 bare callable 的第一条 arity no-match 接进 structured diagnostics：
  root/imported 同优先级内已存在同名 callable，但没有任何候选参数个数匹配调用时，发出
  `sema.wrong-argument-count`，model status 进入 `failure`，且不会注册 call binding。
- `LookupCallBindingDeclaration(...)` 现在区分 name miss、arity miss、ambiguous overload 与
  signature no-match：name miss 仍 deferred，arity miss 报 `wrong-argument-count`，signature
  match count 为 0 仍 deferred。
- 默认参数不能被 arity diagnostics 误伤：bare call 的 arity match 现在按
  `requiredParamCount..ParamCount` 判断，并用已提供参数的 compact signature 前缀消歧；默认参数
  lowering、完整 overload ranking 与 implicit conversion 仍不是本批目标。
- root callable name 继续优先；root 有同名 callable 但 arity 不匹配时不会回落 imported 代偿。
- 新增 `wrong-argument-count-check`，用 `tests/fixtures/wrong_argument_count` 固定 stage0 failure
  projection 与 final envelope `wrongArgumentCountCheck=pass`。
- Batch 76 把 `sema.ambiguous-overload` 从 bare call 扩展到 direct member-call：当同 owner /
  同 qualified method name / 同 arity 的 method candidates 不能被 compact `ParamSignature`
  唯一选择时，semantic analyzer 会发 diagnostic，model status 进入 `failure`，且不会注册
  `member-call` binding。
- member lookup 现在通过 `AResolutionFailureKind` 把 exact class lookup、parent-chain lookup 与
  `TryRegisterMemberCallBinding(...)` 串起来；exact receiver type 明确 ambiguous 时不会继续穿透
  parent class 代偿。
- Batch 76 仍保持 no-match deferred：signature match count 为 0、receiver form 未覆盖或未来
  type-based resolver 才能判断的路径，不会被提前归类成 ambiguity。
- 新增 `ambiguous-member-overload-check`，用 `tests/fixtures/ambiguous_member_overload` 固定 stage0
  failure projection 与 final envelope `ambiguousMemberOverloadCheck=pass`。
- Batch 75 把 bare overload binding 的第一条可证明失败边界接进 structured diagnostics：
  imported bare callable 同名同 arity 多候选且无法唯一选择时，`SeedCallBindingsInNode(...)`
  会发出 `sema.ambiguous-overload`，model status 进入 `failure`，且不会注册 call binding。
- `LookupCallBindingDeclaration(...)` 现在通过 `AResolutionFailureKind` 区分“普通未解析/暂不绑定”
  和“ambiguous-overload”；root callable 仍优先，root 明确 ambiguous 时不会回落 imported。
- 为避免过早把 future resolver 能力误判成错误，Batch 75 只在无 argument signature 或 signature
  匹配数超过 1 的同名同 arity 多候选上报 ambiguity；signature match count 为 0 仍保持 deferred。
- 新增 `ambiguous-overload-check`，用 `tests/fixtures/ambiguous_overload` 固定 stage0 failure
  projection：`failure-kind=semantic-analysis-failed`、`diagnostic-code=sema.ambiguous-overload`、
  `diagnostic-phase=sema` 与 final envelope `ambiguousOverloadCheck=pass`。
- Batch 74 把 Batch 73 的 compact typed argument relation 复用到 bare procedure/function call
  binding：`Pick(1)` 会绑定到 `Pick(Integer)` 的 `i` signature，`Pick(1 = 1)` 会绑定到
  `Pick(Boolean)` 的 `b` signature。
- bare procedure/function symbol 现在会记录 `ParamSignature`；root/imported callable seeding 与
  lazy callable symbol creation 都会同步写入。
- `LookupCallBindingDeclaration(...)` 仍保留 root callable 优先；root 里存在同名同 arity 多候选时，
  只有当前 argument signature 能唯一匹配才会绑定，不会因为 root ambiguous 而回落 imported。
- 新增 `stage0-query-call-bindings-check`，固定 `querySymbols` / `queryDefinitions` 中 bare typed
  overload 的 `paramSignature` / `targetParamSignature` truth。
- Batch 74 仍不声明完整 overload ranking、implicit conversion、default parameter、
  var/out compatibility、visibility checking 或完整 Pascal callable resolver。
- Batch 73 把 member-call overload binding 从 arity identity 推进到最小 typed argument relation：
  `Worker.Pick(1)` 会绑定到 `TWorker.Pick` 的 `i` signature，`Worker.Pick(1 = 1)` 会绑定到
  `b` signature。
- `TSemanticSymbol` 现在有 `ParamSignature`；class method declaration 通过
  `GetParamSignature(...)` 写入 compact signature，当前编码为 `i` / `b` / `s` / `r` / `p`。
- member-call target lookup 在同 owner / 同 qualified name / 同 `ParamCount` 有多个 candidate
  时，会用 call argument signature 做唯一匹配，并继续用 method body declaration signature
  做二次确认；无法推断 argument type 或同签名不唯一时仍保守不绑定。
- `querySymbols` / `queryDefinitions` 现在分别投影 `paramSignature` / `targetParamSignature`；
  stage0 member-call gate 已固定 integer/boolean 同 arity overload 的 target signature。
- Batch 73 仍不声明 implicit conversion ranking、default parameter、var/out compatibility、
  visibility checking、virtual/override dispatch、record/property receiver 或完整 Pascal member resolver。
- Batch 72 把 class method overload 的 member-call target identity 从“同名 method + body 参数数”
  补强为“同名同 owner 同 `ParamCount` method symbol”：`Worker.Pick;` 与 `Worker.Pick(1);`
  现在会分别绑定到 0 参与 1 参的 `TWorker.Pick` method symbol。
- parser 不再跳过 class method declaration 的 parameter list；`gnkClassMethod` 现在携带已有
  `gnkParameterList` / `gnkParameterDecl` 结构，`ProcessClassFields(...)` 可为 method symbol 设置
  `ParamCount`。
- `queryDefinitions` 现在投影 `targetParamCount`，stage0 member-call gate 已固定 overloaded
  `Pick` 的 0 参/1 参 target；这让 automation / future IDE adapter 不必回扫 `querySymbols`
  才能确认 target arity。
- Batch 72 仍不声明 type-based overload resolution、default parameter matching、implicit
  conversion、visibility checking、virtual/override dispatch、record/property receiver 或
  runtime constructor lowering。
- Batch 71 把 `member-call` target lookup 从 receiver exact class type 推进到最小 inherited
  method lookup：`TChild` receiver 在本类没有 `Touch` 时，会沿 `ParentTypeId` 找到
  `TBase.Touch`，并注册 target 为 parent method symbol 的 `member-call` binding。
- inherited lookup 仍走 owner-aware/type-id-aware 路径：每一层 parent 都先通过 `TypeId` 找回
  type symbol，再用该 type symbol 的 owner unit 限定 `TClass.Method`，不会退回裸字符串 lookup。
- 若 exact receiver type 已声明同名 method 但 body/arity 不匹配或不唯一，lookup 会保守停止，
  不穿透 parent 代偿；这仍不是完整 visibility checking、virtual/override dispatch、
  record/property receiver、runtime constructor lowering 或 type-based overload resolution。
- `stage0-query-member-call-bindings-check` 现在固定 `Child.Touch` 的 `queryBindings` /
  `queryDefinitions` truth，target 为 `TBaseWorker.Touch`，继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- Batch 70 把 Batch 69 的 member-call identity 风险收窄到 owner-aware/type-id-aware 路径：
  root/imported unit 同时声明同名 class（例如 `TWorker`）时，root variable receiver 的
  `Worker.Add(...)` 现在必须先消费变量 symbol 上的稳定 `TypeId`，再通过该 type symbol 的
  owner unit 限定 `TClass.Method` target。
- type resolution 现在在可获得 owner unit 的声明期优先匹配同 owner 的 `type` symbol；若当前
  owner 没有匹配，只接受全模型唯一同名 type candidate，跨 owner 同名冲突时保守返回 0，
  避免继续依赖 `FindTypeByName(...)` 的第一个同名 type。
- member target lookup 同时要求 method symbol 与 procedure body declaration 的 owner unit
  与 receiver type symbol 对齐；这仍不是 inherited lookup、visibility checking、record/property
  receiver、runtime constructor lowering、virtual dispatch 或 type-based overload resolution。
- Batch 69 继续把 `member-call` 正向边界推进到 class method body 内的 `Self` receiver：
  `Self.SetValue(9)` 现在会把 `SetValue` 注册为 `member-call`，并指向当前 method context
  提供的 `TWorker.SetValue` method symbol。
- `Self` receiver 的类型不从 source text 猜测：`SeedCallBindingsInNode(...)` 只在进入
  qualified method declaration（例如 `TWorker.Run`）后携带当前 class context，
  `TypeNameForMemberReceiver(...)` 才会把 `Self` 解析成该 class。
- Batch 69 也补上 imported class variable receiver 的 focused semantic 边界：
  root source 中 `uses Worker; var Worker: TWorker;` 后的 `Worker.Add(1, 2)` 可以绑定到
  imported unit `Worker` 的 `TWorker.Add` method symbol。
- 这个 imported 边界要求 imported type section / class method symbols 先进入
  `TSemanticModel`，再处理 root declarations；否则 root variable 的 `TWorker` type id 会是 0，
  后续 receiver type lookup 仍无法进入 `TClass.Method` matching。
- `stage0-query-member-call-bindings-check` 现在还固定 `Self.SetValue(9)` 的
  `queryBindings` / `queryDefinitions` truth，并继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- Batch 69 仍不声明完整 inherited member lookup、visibility checking、runtime constructor
  lowering、record/property/array/deref receiver、virtual dispatch 或 type-based overload。
- Batch 68 关闭 constructor / class type-name receiver 的第一条正向边界：
  `TWorker.Create(42)` 现在会把 `Create` 注册为 `member-call`，并指向 `TWorker.Create`
  method symbol。
- 真实缺口不在 method symbol 生成，而在 receiver type lookup：旧实现只接受变量 receiver，
  `TWorker` 作为已声明 type symbol 时不会进入后续 `TClass.Method` arity matching。
- 新策略是先保留 variable receiver 类型优先级，再保守回落到同一份 `TSemanticModel` 中的
  declared `type` symbol；这样 `Worker.Run` / `Worker.SetValue` 等变量 receiver 行为不变，
  同时让 `TWorker.Create(42)` 进入同一份 compiler-owned binding truth。
- `stage0-query-member-call-bindings-check` 现在同时固定 `Create` / `Run` / `SetValue` / `Add`
  的 `member-call` 与 `queryDefinitions` truth，并继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- 收口复查曾发现残留 `./tests/run_all_tests.sh --filter smoke` 进程；本轮接手后未保留
  semantic fixture failure 复现条件，最新 fresh `bash build/verify_local.sh` 已确认
  `semantic` smoke 使用当前 14 个 fixture 且全部通过。旧
  `.sisyphus/tmp/harness/semantic-type_mismatch_fail` 目录只是历史 artifact，不参与当前 fixture
  收集。
- Batch 68 仍不声明 runtime constructor allocation / lowering、完整 static class method
  semantics、full overload/type dispatch、virtual dispatch、record/property 或 array/deref receiver。
- Batch 67 关闭 expression-position member function call 的第一条正向边界：
  `Halt(Worker.Add(1, 2));` 现在会把参数表达式里的 `Worker.Add(...)` 注册为 `member-call`，
  并指向 `TWorker.Add` method symbol。
- 真实缺口不在 method lookup，而在 binding walker 的 wrapper skip：为避免
  `gnkProcedureCallStatement` 包住同 offset `gnkFunctionCall` 时重复注册，旧实现整棵跳过 wrapped
  child，连参数里的嵌套 call 也一起跳过。
- 新策略是只跳过 wrapper callee 自身，继续递归 wrapped function-call 的参数表达式；这保留 Batch 60
  以来的 duplicate binding guard，同时让 expression-position direct member function call 进入
  compiler-owned binding truth。
- Batch 66 把 `member-call` 从零参数 direct class receiver 推进到参数个数匹配：`Worker.SetValue(7);`
  现在会绑定到 `TWorker.SetValue` method symbol，缺参 `Worker.SetValue;` 不会再因为 method name
  match 被误注册。
- member-call 参数个数匹配仍不等于完整 overload/type dispatch：当前只在存在同名 `TClass.Method`
  body declaration 时要求 `CountDeclParams(...)` 与 call argument count 恰好唯一匹配；同名同参数个数
  的多个 body declaration 仍保持不绑定。
- `stage0-query-member-call-bindings-check` 现在用
  `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 固定 `query-bindings` /
  `queryDefinitions` 中的 `member-call` truth，并确认 query surface 仍保持 MIR/backend/toolchain
  deferred。
- 更复杂的 expression-position member binding 仍保持 deferred：当前只承诺 direct class variable
  receiver 的 `Halt(Worker.Add(1, 2))` 形态；constructor、record/property、array/deref receiver、
  virtual dispatch 与 type-based overload 还需要后续 AST/member expression binding 设计。
- Batch 65 把 selector/member binding 从“只排除误绑定”推进到第一条正向 truth：root source
  中 direct class variable receiver 的零参数 class method call（`Worker.Run;` 与
  `Worker.Run();`）现在会注册 `member-call` binding，并指向 `TWorker.Run` 的 `method`
  semantic symbol。
- member-call binding 不复用 `RegisterClassVar(...)` 这类后端 runtime lowering 副表；receiver
  类型来自已 seed 的 `variable` symbol 的 `TypeId`，target 来自同一份 `TSemanticModel` 中的
  `TClass.Method` / `method` symbol。
- Batch 65 仍不声明完整 selector/member lookup：非零参 class method、overload/type-based
  dispatch、virtual/override dispatch、record method、property accessor、array/deref receiver 与
  constructor binding 都继续保持 deferred。
- Selector/member statement call 的真实风险点已经被 Batch 64 RED 抓住：`Holder.Help();`
  会被 parser 表达成 procedure-call statement 包住 qualified `gnkFunctionCall`，旧
  `SeedCallBindingsInNode(...)` 会继续按 name-only `Help` + 0 参数查找，进而误绑定到 imported
  unit 的 bare `Help` procedure。
- `Holder.Help;` 过去没有误绑只是因为当前 parser wrapper 让 `CallArgumentCount(...)` 返回 1，
  与 imported 0 参数 `Help` 偶然错开；这个行为不能作为长期 contract。
- `TSemanticAnalyzer.IsQualifiedCallNode(...)` 现在显式排除 dot/array/deref selector callee，
  让 name-only binding 只覆盖 bare procedure/function call。完整 selector/member access binding
  仍然留给后续 member lookup 与 type-based dispatch，不由 imported callable lookup 代偿。
- `build/verify_local.sh` 的 stage0 bootstrap 与 lexer/parser/sema bench build dirs 现在使用
  run-private `.sisyphus/tmp/verify-local.<run>/...`，避免并发 verify 或失败重跑互相删除固定目录。
- lexer/parser/sema bench 现在统一通过 `tools/bench/np_bench_timing.pas` 读取 process CPU time，
  并由 verify gate 断言 `*-bench-timing-source=process-cpu`；这让 smoke perf floor 更接近代码自身
  成本，而不是宿主调度等待。
- `nextpas query symbols` 现在会把 binding target definition metadata 作为
  `query-definitions=<json-array>` 与 envelope `queryDefinitions` 投影出来；该 JSON 由
  `TCompilationSession.DefinitionsJson` 从同一份 `TSemanticModel` 的 binding table 与 symbol graph
  派生。
- RED gate 已证明旧 query surface 缺少 definition target projection：fresh verification 失败在
  `missing-stage0-query-definitions-detail`；focused GREEN probe 已确认
  `hello_with_units.pas` 的 `SayHello` call definition target 投影为
  `targetName=SayHello`、`targetKind=procedure`、`targetOwnerUnitName=Stage0Greeter`、
  `targetSourcePath=.../units/linux-x86_64/Stage0Greeter.pas` 与 `targetByteOffset=32`。
- query definition projection 仍是 compilation-session-backed 只读 semantic query；它不新增
  `LanguageServiceSession`，不执行 MIR/backend/toolchain，也不扩展 selector/member access、
  bare function-reference binding、references、rename 或 completion。
- `nextpas query symbols` 现在正在接入 `TSemanticModel` 的 binding side table：计划公开
  `query-bindings=<json-array>` 与 envelope `queryBindings`，条目字段直接来自
  `TSemanticBinding` 的 `bindingId/kind/name/ownerUnitId/byteOffset/targetSymbolId`。
- RED gate 已证明旧 query surface 缺少 binding projection：fresh verification 失败在
  `missing-stage0-query-bindings-detail`；focused GREEN probe 已确认
  `hello_with_units.pas` 的 `SayHello` call occurrence 投影为
  `targetSymbolId=1` 的 call binding。
- query binding projection 仍是 compilation-session-backed 只读 semantic query；它不新增
  `LanguageServiceSession`，不执行 MIR/backend/toolchain，也不扩展 selector/member access 或
  type-based overload resolution。
- Root source call binding 现在已经覆盖 imported unit callable 的最小边界：`SeedImportedUnitBodies`
  会解析 resolved imported units，并为 imported procedure/function declarations seed owner-aware
  callable symbols；`RegisterProcedureBody` 同步保存 owner unit id。
- `LookupCallBindingDeclaration` 当前采用保守绑定规则：root callable 优先；如果 root 没有唯一匹配，
  imported callable 也必须只有一个同名同参数数目的匹配才会成为 binding target。
- `tests/semantic/test_semantic_call_bindings.pas` 现在覆盖 `Help;` 调用绑定到 `Helper` unit 的 callable
  symbol，同时用 `Holder.Help := 1`、`Holder.Help;` 与 `Holder.Help();` 固定 selector/member
  access 不应误注册为 imported call binding。
- owner-aware imported callable symbols 让 `examples/smoke/hello_with_units.pas` 的 semantic smoke
  `symbol-count` 从 4 变成 6；这是 imported callable truth 进入 semantic model 的结果，不是
  verifier 假绿。
- `pkg plan` 现在会在 lockfile valid、manifest-lock identity match 之后继续检查 target snapshot：
  如果 lockfile 已有 `[[snapshot]]` 集合但没有 requested target，install plan 会 blocked 为
  `package-lock-target-snapshot-missing`。
- `tests/fixtures/package_lock_target_snapshot_missing` 固定了 lock entry 与 manifest identity 匹配、
  lock status ready、但 snapshot target 只有 `linux-aarch64` 的边界；fresh verification 已确认
  `linux-x86_64` 请求会停在 target snapshot missing blocker。
- target snapshot missing 仍是 read-only preflight：它不让 lockfile invalid，也不触发 resolver、
  version solving、fetch/install、lockfile rewrite 或 migration。没有 snapshot 的既有最小 v1
  lockfile 继续兼容 ready path。
- `TSemanticModel` 现在新增 `TSemanticBinding` side table，用于表达 source-addressable binding
  truth：当前最小字段为 binding id、kind、name、owner unit id、source byte offset 与 target
  semantic symbol id。
- `TSemanticAnalyzer` 现在会在 `AssignScopesToSymbols` 后生成 root procedure/function call
  bindings；这条路径复用已有 callable body registry 和 semantic symbols，不让 downstream adapter
  自行猜 symbol。
- overloaded procedure call binding 现在使用 call argument count 选择 target declaration；focused
  test 已覆盖 `Pick;` 与 `Pick(1);` 分别绑定到 0 参数与 1 参数 overload。
- parser 目前会把某些 `Pick(1);` 表达成 wrapper `gnkProcedureCallStatement` 内含同 offset
  `gnkFunctionCall`；semantic binding walker 会跳过这种 wrapper child，避免同一个 source
  occurrence 产生重复 binding。
- `tests/semantic/test_semantic_call_bindings.pas` 已覆盖 procedure call、function call 与 overloaded
  procedure call；`build/verify_local.sh` 已新增 `semantic-call-bindings-check=pass`，最终
  verify-local envelope 也投影 `semanticCallBindingsCheck":"pass"`。
- 当前 binding contract 已承诺 root source 中普通 procedure/function call、overload arg-count
  消歧与 imported unit callable binding；selector/member access、bare identifier function-reference
  binding 与完整 type-based overload resolution 仍是后续
  language-service contract 工作，不能被 downstream 包装成已完成。
- Batch 60 给 `nextpas.lock` snapshot skeleton 增加了最小一致性校验：snapshot `selection`
  必须匹配某个 lock entry 的 `name@version`，否则投影
  `package.lock.snapshot-selection-unmatched`。
- `compiler/frontend/np_package_lock.pas` 现在还会把非 `sha256:` digest shape 与重复 snapshot
  target 标成 lock issues；这些仍然只是 parser-side read-only validation，不触发 resolver、
  fetch/install 或 lockfile write。
- `tests/fixtures/package_lock_snapshot_invalid` 固定了 lock entry `0.1.0` 但 snapshot selection
  指向 `0.2.0` 的边界；fresh verification 已确认该路径进入
  `package-lock-status=invalid` 与 `package-lock-invalid` blocker。
- `build/verify_local.sh` 已新增 `stage0PkgPlanLockSnapshotInvalidCheck=pass`，用于冻结 snapshot
  consistency invalid path。
- Batch 59 把 `nextpas.lock` 的最小 v1 只读 parser 从 `[[package]] name/version` 扩展到
  `[[snapshot]] target/provenance/digest/selection` skeleton。
- `TPackageLockTruth` 现在会携带 snapshot count 与 snapshots，stage0 line output 公开
  `package-lock-snapshot-count` 与 `package-lock-snapshots`，command envelope 公开
  `packageLockSnapshotCount` 与 `packageLockSnapshots`。
- `tests/fixtures/package_lock_detail` 现在固定一个 `target=linux-x86_64` 的 snapshot happy path；
  focused probe 已确认 `pkg inspect` 同时输出 snapshot detail，且 `package-install-plan-status`
  仍保持 `ready`。
- `tests/fixtures/package_lock_invalid` 现在固定 `[[snapshot]]` 缺 `digest` 的 invalid path；
  focused probe 已确认该路径投影 `package.lock.snapshot-digest-missing`，并让 `pkg plan`
  停在 `package-lock-invalid` blocker。
- Batch 59 仍然不做 resolver、version solving、fetch/install、lockfile write 或 lockfile migration；
  snapshot skeleton 只是 machine-owned replay shape 的只读投影。
- `package-lock-out-of-sync` blocker 现在有独立 mismatch detail：line output 公开
  `package-install-plan-blocker-expected-package` 与
  `package-install-plan-blocker-lock-entries`，command envelope 公开对应 camelCase 字段。
- mismatch detail 只在 out-of-sync blocker 上输出；focused probe 已确认 ready path 不输出空的
  blocker detail，避免 automation 把空数组误解成阻塞证据。
- Batch 58 仍然不做 resolver、version solving、fetch/install 或 lockfile write；它只把已有
  manifest-lock consistency preflight 的解释力补齐。
- `pkg plan` 现在会在 lockfile valid 之后做最小 manifest-lock identity check：manifest 的
  package name/version 必须出现在 canonical `nextpas.lock` entries 里，否则 install preflight
  会阻塞为 `package-lock-out-of-sync`。
- `TPackageManifestInfo` 现在保存 `[package].version`，并经由 `WorkspaceModel` 进入
  `TPackageWorkflowTruth`；这只是 read-only preflight 输入，不是 resolver 或 lock writer。
- `tests/fixtures/package_lock_out_of_sync` 固定了 manifest `0.1.0` 与 lock `0.2.0`
  不一致的边界；focused probe 已确认实现前会误报 ready，实现后会投影
  `package-install-plan-blocker-code=package-lock-out-of-sync`。
- `build/verify_local.sh` 已新增 `stage0PkgPlanLockOutOfSyncCheck=pass`，用于冻结
  manifest-lock out-of-sync blocked plan path。
- `nextpas.lock` 现在有最小 v1 只读 parser：当前实现读取 `[lockfile] format-version = 1` 与
  `[[package]] name/version`，并通过 `TPackageLockTruth` 投影 format version、entries 与 issues。
- `package-lock-status` 已从存在性 truth 扩展为 `missing|ready|invalid`；invalid lockfile 不再被误报为
  ready，也不会继续落入 `package-lock-missing`。
- invalid lock fixture 会稳定投影 `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-lock-invalid` 与
  `package-install-plan-blocker-message=canonical package lockfile is invalid`。
- `build/verify_local.sh` 已新增 `stage0PkgLockDetailCheck=pass` 与
  `stage0PkgPlanLockInvalidCheck=pass`，分别冻结 lock detail ready path 与 invalid-lock blocked plan path。
- Batch 56 仍然不做 dependency resolution、fetch/install、publish 或 lockfile write；它只把 canonical
  lockfile 的最小可解释读模型纳入 package workflow truth。
- `pkg plan` 的 preflight blocker matrix 现在被完整 gate 到当前 truth 已拥有的四个终止原因：
  `package-manifest-missing`、`package-dependencies-invalid`、
  `package-source-roots-missing` 与 `package-lock-missing`。
- malformed dependency fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-dependencies-invalid` 与
  `package-install-plan-blocker-message=package dependency validation is invalid`。
- `tests/fixtures/package_manifest_no_source_roots` 固定了 manifest/lock ready 但 source roots 为空的
  package truth；该 fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-blocker-code=package-source-roots-missing` 与
  `package-install-plan-blocker-message=package source roots are missing`。
- 这个 Batch 55 仍然不做 dependency resolution、fetch/install、publish 或 lockfile write；
  它只把已经存在的 `TPackageWorkflowTruth` preflight truth 纳入 `pkg plan` 专用 promotion gate。
- `pkg plan` 现在不再只靠 ready path 证明自己可用：`build/verify_local.sh` 已新增
  `stage0PkgPlanBlockedCheck=pass` 与 `stage0PkgPlanMissingCheck=pass`，分别冻结
  lockfile 缺失导致的 blocked preflight 和 package truth 缺失导致的 missing preflight。
- workspace member fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-status=blocked`、`package-install-plan-blocker-code=package-lock-missing`
  与 `package-install-plan-blocker-message=canonical package lockfile is missing`。
- package-free 临时 workspace 下的 `nextpas pkg plan` 会稳定投影
  `package-workflow-status=missing`、`package-install-plan-status=missing`、
  `package-install-plan-blocker-code=package-manifest-missing` 与
  `package-install-plan-blocker-message=package manifest is missing`。
- `pkg inspect / pkg plan / pkg graph` 现在共享同一份
  `WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`；其中 `pkg plan` 是真实的
  install plan preflight surface，只读，不碰 resolver、fetch、install 或 lockfile write。
- `nextpas pkg plan --target linux-x86_64` 的负向参数 gate 现在会诚实投影
  `failure-kind=missing-required-option` 与 `human-summary=missing-required-option: --workspace`，
  并在 usage 里公开 `nextpas pkg plan --workspace <root> --target linux-x86_64`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `stage0PkgPlanCheck=pass`、
  `stage0PkgPlanInvalidArgumentsCheck=pass` 与最终 `verify-local=pass` 已进入正式 promotion path。
- `pkg graph` 现在是一个真正的只读 package workflow projection：它直接复用
  `WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`，把同一份 truth 展开成
  package root node、declared-dependency nodes 与 `declared-dependency` edges，不碰 resolver、
  fetch、install 或 lockfile write。
- `tests/fixtures/workspace_declared_dependencies/app` 现在会稳定投影
  `packageGraphStatus=ready`、`packageGraphNodeCount=3` 与 `packageGraphEdgeCount=2`，并且
  envelope 会同步携带 `packageGraphNodes` / `packageGraphEdges`。
- `tests/fixtures/workspace_malformed_dependencies/app` 现在会稳定投影
  `packageGraphStatus=invalid`，但仍然把同一份 declared dependencies truth 展开为 root / dependency
  nodes 与 edges，和 package dependency validation 共享同一套只读边界。
- `nextpas pkg graph --target linux-x86_64` 的负向参数 gate 现在会诚实投影
  `failure-kind=missing-required-option` 与 `human-summary=missing-required-option: --workspace`，
  并在 usage 里公开 `nextpas pkg graph --workspace <root> --target linux-x86_64`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `stage0PkgGraphCheck=pass`、
  `stage0PkgGraphInvalidArgumentsCheck=pass` 与最终 `verify-local=pass` 已进入正式 promotion path。
- `env clean` 现在是一个真正的 workspace-local maintenance surface：它只删除
  `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并通过
  `env-clean-status`、`env-clean-change`、`env-clean-selection-path`、
  `env-clean-resolution-path` 与 `env-clean-removed-count` 投影结果。
- `env clean` 的 repeat 行为已经被收口为 `unchanged` / `0`，不会因为文件已经不存在而重复报
  `removed`；同时 `--toolchain-binding` 也被确认为 invalid-option 边界。
- fresh `bash build/verify_local.sh` 已通过，说明 Batch 51 的 cleanup contract、repeat contract
  与 invalid-arguments contract 都已经进入正式 promotion path。
- `env use` 现在已经是真实 mutation surface：它把 workspace-local preferred binding 写进
  `<workspace>/.nextpas/env/selections/<target>.toml`，并把 selection 结果投影到 line-based
  output 与 `command-envelope=<json>`。
- `env status --workspace <root>` 现在会在没有显式 `--toolchain-binding` 时读取同一份
  selection sidecar，并把 `env-selection-status=ready` 与 selected binding 继续投影出来；
  显式 `--toolchain-binding` 仍然覆盖 workspace-local selection。
- `env sync` 现在会把 workspace-local resolution cache 写进
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并在 line output / envelope 中公开
  `env-resolution-path`、`env-resolution-status=ready` 与 `env-sync-change=materialized|updated|unchanged`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `env sync` gate 的 workspace-local
  resolution cache contract 和验证脚本变量边界都已收口。
- 这条 selection sidecar 只属于 ArtifactRootSet 管辖的 machine-local state，不回写
  `nextpas.workspace.toml`、`nextpas.package.toml` 或 `nextpas.lock`。
- fresh `bash build/verify_local.sh` 已经把 `stage0EnvUseCheck=pass` 纳入 promotion path，
  所以 `env use` / `env status --workspace` 已进入正式 gate。
- `package-lock-status` 现在已经不再是“path 已知但状态固定 deferred”的空壳字段；
  它会根据 canonical `nextpas.lock` 的存在性投影 `ready|missing`，并由同一份
  `TPackageWorkflowTruth` 贯穿 `doctor` / `pkg inspect`。
- `tests/fixtures/package_manifest_source_root/nextpas.lock` 让 package manifest fixture 形成
  真实 ready path；workspace member / declared dependencies / repo root 仍然缺锁，因此会稳定
  投影 `missing`。
- `package-install-plan-status` 现在改成只读 preflight truth，投影
  `ready|blocked|missing`；有 blocker 时还会同步投影
  `package-install-plan-blocker-code` / `package-install-plan-blocker-message`。
- `tests/fixtures/package_manifest_source_root` 现在会稳定投影 `package-install-plan-status=ready`；
  workspace member / declared dependencies fixture 会因为缺锁稳定投影 `blocked`，而
  `workspace_malformed_dependencies` 会因为 dependency validation invalid 稳定投影 `blocked`。
- Batch 48 已经被 fresh `bash build/verify_local.sh` 验证为 pass，并以 git commit
  `616110c` 收口。
- 当前 `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 顶部已经同步到 `Batch 48`
  install plan preflight truth，不会再误导下一轮“继续”的恢复点。
- 当前 `docs/architecture/architecture-principles-specification.md` 已把用户提出的长期质量目标
  固化为可执行门槛：每个切片都要明确 owner、truth object、projection、promotion gate、
  non-goal 与回退信号；这条规范应作为 `master-roadmap.md`、compiler 自举路线和后续 package /
  language-service / GUI / IDE 工作的共同约束。
- 当前 `query symbols` 的实现已经走 `ResolveWorkspaceModel(...)` 与 `TCompilationSession`，
  并且 public projection 现在同时投影 `querySymbols`、`queryScopes` 与 `queryTypes`；
  这让 CLI/IDE/automation 能直接消费 normalized semantic truth，而不是只知道 query 有结果。
- Batch 37 之后的 focused probe 继续暴露下一层真实缺口：`querySymbols[]` 已经有
  `ownerUnitId`、`scopeId` 与 `typeId`，但如果不投影 `ownerUnitName`、`scopeKind` /
  `scopeName` 与 `typeName` / `typeKind`，CLI、automation 和 future IDE adapter 仍然需要
  自己回查或重扫 semantic truth；因此 Batch 38 选择在 `TCompilationSession.SymbolsJson`
  内从同一份 `TUnitGraph` / `TSemanticModel` 补 semantic metadata，而 Batch 39 则继续把
  `TSemanticScope` / `TSemanticType` graph 作为 normalized `queryScopes` / `queryTypes`
  side tables 投影出来，避免调用方再维护一套 lookup。
- 当前 `compiler/ir/np_hir_builder.pas` 里 `FEntryBlockId` 基础设施已经足够支持 late alloca hoist；
  真正缺的是 `EnsureAlloca(...)` 仍把 `hikAlloca` 发到 current block。
- 当前 `compiler/ir/np_hir_llvm_emitter.pas` 之前依赖 raw `%1/%2/...` 匿名数值 SSA 名，
  并用“按 block 首个 `ResultId` 排序”的方式迁就 LLVM 文本 IR 的顺序编号约束。
- 把 emitter 切到 `%vN` named SSA values 之后，entry-block hoist 可以安全落地，且 block 输出顺序
  可以回到 HIR 原始顺序，不再需要 `ResultId` 排序 hack。
- `tests/hir/test_hir_late_alloca_hoist.pas` + `build/verify_local.sh` 里的 `opt -disable-output`
  probe 已经把这条 contract 冻结下来：late slot 的 `alloca` 必须位于 entry block，生成 IR 也必须可解析。
- 外部审查报告对 `harness` 假绿风险的判断是成立的：
  旧路径确实更接近 fixture/snapshot inventory，而不是完整真实执行。
- 当前 `tests/harness/runner.pas` 已经补成真实执行模型：
  `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
  都会真实执行，并显式投影 fixture-level 与 smoke-level 结果。
- 当前 `compiler/frontend/np_unit_resolver.pas` 已经补上三个关键 correctness 修正：
  根单元 implementation uses、requested-name mismatch、显式 `System` source upgrade。
- 当前 `compiler/frontend/np_unit_graph.pas` 的 `AddResolvedUnit(...)` 已支持用真实 source-backed
  unit 升级 placeholder 节点，这是显式 `System` 行为变正确的关键。
- 当前 `compiler/syntax/np_green_tree.pas` 已明确接受 `array of const` 这一形态；
  `compiler/sema/np_semantic_analyzer.pas` 的 `GetParamSignature(...)` 也已补上
  `TypeChild` nil guard，避免 `np_diagnostics_sink` 在参数签名抽取阶段 AV。
- `tests/parser/array_of_const_pass.pas` 已新增并纳入 parser smoke，`./tests/run_all_tests.sh --filter parser`
  与 fresh `bash build/verify_local.sh` 都已通过。
- `build/verify_local.sh` 当前已经把新 gate 纳入 promotion path：
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `harness-compiler-pass-check`、`smoke-check`。
- 当前 search path 模型已经不只剩 root source 和 target-installed：
  session 现在还会把 nearest `nextpas.package.toml` 的 source roots、workspace member
  package source roots 与 CLI explicit unit roots 纳入同一条 precedence path。
- 当前 precedence 已经固定为：
  `root-source -> package-source-root -> explicit-unit-root -> target-installed`。
- 当前 `tools/stage0/nextpas.pas` 已经把现有 workspace/package/artifact discovery 结果
  正式提升为 command truth：line-based output 会投影
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 也会同步带上 camelCase 版本字段。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小 `test` family：
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]` 都会走 stage0 CLI，
  但真正的 group execution 仍由 `tests/run_all_tests.sh` /
  `tests/harness/runner.pas` 持有。
- 当前 `nextpas test` 的 thin wrapper 会显式把 `NEXTPAS_STAGE0`、
  `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT` 传给 harness；
  driver-side test parse failure 则会继续诚实投影成
  `command=test`、`selector=test` 与 `failure-kind=invalid-arguments`。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `env` surface：
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]` 会复用现有
  target/toolchain/distribution/runtime truth，显式投影
  `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
  `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`。
- 当前 `tools/stage0/nextpas.pas` 也已拥有最小 workspace-local `env sync` surface：
  `nextpas env sync --target linux-x86_64 [--toolchain-binding <id>] --workspace <root>` 会写
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并把 selection 输入、resolved binding、
  distribution/runtime readiness 与 sync delta 公开给 CLI、IDE 与 automation。
- 当前 `env status` 已明确和 `doctor` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，命令也继续保持
  `status=success` / `result=success`，把 `environment-readiness=incomplete`、
  `runtime-sdk-status=missing` 与 `runtime-libc-present=false` 当成 state truth，而不是
  command failure。
- 当前 `env status` 已继续补齐 readiness evidence：line-based output 与 envelope 都会投影
  `environment-status` / `environmentStatus`、`toolchain-binding-status` /
  `toolchainBindingStatus` 与 `distribution-status` / `distributionStatus`。
- 当前 `environment-readiness` 保留为兼容字段，并与 `environment-status` 使用同一 derived
  readiness vocabulary；`doctor` 的 binding readiness 也复用同一份 environment projection。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `doctor` surface：
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 `env status` 已经使用的 target/toolchain/distribution/runtime truth，并额外投影
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`。
- 当前 `doctor` 已明确和 `env sync` / `env use` / `env bootstrap` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，inspection 也继续保持
  `status=success` / `result=success`，把健康问题写进
  `doctor-status=warning` 与 `doctor-finding-count=1`，而不是修改环境或把 runtime 缺失误报成
  command execution failure。
- 当前 `doctor` 的 result contract 已从 aggregate summary 继续加固：
  line-based output 会投影 `doctor-workspace-status=ready`、
  `doctor-toolchain-binding-status=ready`、`doctor-finding-code=doctor.runtime-sdk-missing`
  与 `doctor-finding-severity=warning`。
- 当前 `doctor` 的只读 inspection 现在也会把 package/workspace truth 纳入：
  当 `--workspace` 指向没有 package truth 的目录时，会同步投影
  `package-workflow-status=missing`、`package-manifest-status=missing`、
  `package-lock-status=deferred`、`package-install-plan-status=deferred`、
  `package-source-root-count=0`，并给出 `doctor.package-workspace-missing`；这条 finding 仍然不
  改变 `doctor` 的只读边界。
- 当前 `doctor` 的 package/workspace coherence 已经有正反两侧 gate：
  `tests/fixtures/package_manifest_source_root` 会稳定表现为 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1`，并且不会出现
  `doctor.package-workspace-missing`；这防止合法 package workspace 被误报成缺失 package truth。
- 当前 `doctor` 的 workspace descriptor + member package ready 路径也已经进入 gate：
  `tests/fixtures/workspace_member_source_root` 会把显式 workspace descriptor root 稳定解析到
  `app/nextpas.package.toml`，投影 `workspace-descriptor-path`、member
  `package-manifest-path`、`package-root-path`、`package-name`、`package-lockfile-path` 与
  `package-source-root-count=1`，并且不会出现 `doctor.package-workspace-missing`；这防止
  future workspace package tooling 把 workspace root 与 package root 混为一谈。
- 当前 `command-envelope=<json>.result.doctorFindings[]` 会保留同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`；这属于
  health inspection result，不替代 compiler diagnostics sink。
- 当前 `build/verify_local.sh` 的 toolchain contract probe 已经不再把
  `tests/toolchain/toolchain_contract_smoke` 与 `.o` 写回源码树：它现在会编译到临时
  `mktemp -d` build dir，并在执行后显式断言源码树里不存在这两个生成物。
- 当前 `build/verify_local.sh` 也已经把 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass` 与 `smoke`
  五条 contract 纳入 promotion path，因此 developer tooling 的最小 test 入口不再只靠
  手工运行留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas env status` 的 success path 与 bare
  `nextpas env` 的 invalid-arguments contract 纳入 promotion path，因此最小 `env`
  公开面不再只靠手工 probe 留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas doctor` 的 success path 与 bare
  `nextpas doctor` 的 invalid-arguments contract 纳入 promotion path，因此最小 `doctor`
  健康检查入口不再只靠手工 probe 留证。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `query symbols` surface：
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 shared workspace model、target facts 与 `TCompilationSession`，只执行 syntax、
  unit resolution 与 semantic analysis。
- 当前 `query symbols` 已明确和完整 language service 分层：它输出
  `analysis-source=compilation-session`，不宣称拥有 `LanguageServiceSession`、open document
  overlay、incremental invalidation、references、rename preflight 或 completion。
- 当前 `query symbols` 成功路径会投影 `query-kind=symbols`、`query-status=success`、
  `query-result-count=<count>`、`query-symbols=<json-array>`、`query-scopes=<json-array>` 与
  `query-types=<json-array>`，并让 `command-envelope=<json>.result` 同步保留 `queryKind`、
  `queryStatus`、`analysisSource`、`queryResultCount`、`querySymbols`、`queryScopes` 与
  `queryTypes`。
- 当前 `queryScopes` 与 `queryTypes` 不是新的 language service 协议，而是同一份
  `TSemanticModel` 的 normalized side tables；它们保留 `scopeId` / `typeId` 的稳定 identity，
  让调用方可以不再在 CLI 外部自行补 lookup。
- 当前 `build/verify_local.sh` 也已经把 `nextpas query symbols` 的 success path 与 bare
  `nextpas query` 的 invalid-arguments contract 纳入 promotion path，因此最小 `query`
  公开面不再只靠手工 probe 留证。
- 当前 `compiler/frontend/np_package_workflow.pas` 已经存在，并把 package workflow 的第一批
  compiler-owned truth 收成 `TPackageManifestTruth`、`TPackageLockTruth`、
  `TPackageInstallPlanTruth` 与 `TPackageWorkflowTruth`。
- 当前这批 package workflow truth 仍然严格 non-executing：manifest truth 只消费
  `TPackageManifestInfo` 的 manifest/package/source-root 事实，lock/install truth 只冻结
  canonical path/provenance 与 `deferred` 状态，不执行 registry lookup、fetch、solver、
  install placement 或 lockfile write。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已经把最小 package workflow contract 纳入真实 gate：
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`；
  这让 package workflow skeleton 不再只靠文档留证。
- 当前 `pkg inspect` 的 detail contract 也已进入 promotion path：line-based output 与
  `command-envelope=<json>.result` 会同时投影 workflow-owned manifest path、package root、
  package name、lock status 与 canonical lockfile path；这仍然是只读 truth projection，
  不执行 fetch、install、dependency resolution、lockfile write 或 publish workflow。
- 当前 `pkg inspect` 的 workspace descriptor + member package ready 路径也已经进入 gate：
  `tests/fixtures/workspace_member_source_root` 会把显式 workspace descriptor root 稳定解析到
  `app/nextpas.package.toml`，投影 `workspace-descriptor-path`、member
  `package-manifest-path`、`package-root-path`、`package-name`、`package-lockfile-path` 与
  `package-source-root-count=1`；这让 `pkg inspect` 与 `doctor` 共享同一条 package workflow
  truth，而不是各自解释 workspace membership。
- 当前 package workflow truth 已经持有完整 `SourceRoots`，不应只公开 count：
  `package-source-roots=<json-array>` 与 envelope `packageSourceRoots` 现在也来自同一份
  `ManifestTruth.SourceRoots`。缺少 package truth 时它稳定为 `[]`，ready package workspace
  则投影 resolved source root 路径，避免 IDE/CI/automation 为了拿 roots 明细再重读 manifest。
- 当前 package workflow truth 已继续持有 declared dependency intent：
  `nextpas.package.toml` 的 `[dependencies]` keyed inline table 会被收成 dependency name /
  requirement，并通过 `package-dependency-count`、`package-dependencies=<json-array>`、
  `packageDependencyCount` 与 `packageDependencies` 只读投影；这仍然不是 dependency
  resolution、fetch/install 或 lockfile write。
- Batch 46 的最新未收口 blocker 是 dependency requirement validation：
  `compiler/frontend/np_package_manifest.pas` 当前 `ParsePackageDependencyInfo(...)` 只抽取
  inline table 里的 `version` / `requirement` 字符串，遇到无法解析的 dependency line 会
  `Continue`，因此 malformed requirement 存在静默消失风险。下一批应把已冻结的最小 grammar
  (`=`、`>`、`>=`、`<`、`<=`，逗号 intersection) 收成 manifest/workflow 层共享 truth，
  并让 `doctor` / `pkg inspect` 公开投影 invalid dependency detail。
- Batch 46 已收口 dependency requirement validation：
  `TPackageManifestInfo` 继续保留所有 declared dependency intent，同时新增 dependency issue
  truth；`TWorkspaceModel.PackageRef` 与 `TPackageWorkflowTruth` 负责把 validation status /
  issue count / issue details 传给 stage0 projection。`doctor` 与 `pkg inspect` 现在都会投影
  `package-dependency-validation-status=valid|invalid|missing`、
  `package-dependency-issue-count=<count>`、`package-dependency-issues=<json-array>`，envelope
  同步投影 camelCase 字段。`tests/fixtures/workspace_malformed_dependencies` 覆盖 `^0.1.0`、
  `~>0.1`、`>=`、`>=0.1.0 || <0.2.0` 与 empty requirement；fresh
  `bash build/verify_local.sh` 已通过。
- 当前 `tests/run_all_tests.sh` 的 stage0 bootstrap failure 已不再把关键回放线索吞掉：
  失败输出会继续带上 `bootstrap-step`、`bootstrap-command`、
  `bootstrap-stderr-file`，并在 stderr 文件非空时直接回显原始 stderr evidence。
- 当前 build/workspace/artifact 相关 truth 已经开始从平铺字段收口：
  `tools/stage0/nextpas.pas` 使用 `TBuildCommandContext` 持有 command-level build context，
  `compiler/frontend/np_compilation_session.pas` 则用 `TBuildContext` 持有
  session-owned build context。
- 当前 `tools/stage0/nextpas.pas` 的 diagnostics/toolchain/build-trace projection
  也已继续从平铺字段收口：
  `TDiagnosticProjectionContext` / `TToolchainProjectionContext` 现在不仅负责
  clear/capture/envelope，也已经覆盖 `PrintSessionProjection(...)` 的
  stdout/stderr mirror；旧 `ActiveDiagnostic*` / `ActiveToolchain*` 残留引用已清除。
- 当前 `compiler/frontend/np_workspace_model.pas` 已经存在，并把 workspace root、
  discovery kind、package refs、project unit root infos、artifact root、output dir、
  host-fpc cache root 与 target selection 收成 compiler-owned `TWorkspaceModel`。
- 当前 `compiler/frontend/np_package_manifest.pas` 现在会为 shared workspace model 提供 typed
  `TPackageManifestInfoArray`、workspace member package info 与 project unit root info；
  parser 职责仍保留在 manifest layer，不再承担最终 workspace ownership。
- 当前 `compiler/frontend/np_compilation_session.pas` 现在会正式拥有并释放
  `WorkspaceModel`；resolver 与 toolchain planner 改为从 model 读取
  `ProjectUnitRootInfos` / `ProjectUnitRoots`。
- 当前 `tools/stage0/nextpas.pas` 现在会先调用 `ResolveWorkspaceModel(...)`，
  从 model 捕获 pre-session build context，并在创建 `TCompilationSession` 后把 ownership
  交给 session；旧 driver-side workspace discovery / artifact placement helper 已被收缩掉。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已经把 explicit workspace、nearest package manifest 与 workspace member 的
  workspace model contract 纳入真实 gate；fresh `bash build/verify_local.sh`
  继续得到 `toolchainContractCheck=pass` 与 `verify-local=pass`。
- 当前 `compiler/toolchain/np_toolchain_runner.pas` 已存在，并能顺序执行 ready
  `TToolchainPlan` 的 steps：它会准备 working/output/sidecar 目录、解析 executable path、
  物化 `response-file` / `resource-list-script` / `archive-command-script`，真实调用外部进程，
  再按 `delete-on-success` 回收 sidecar，并留下 per-step status / exit code。
- 当前 `compiler/frontend/np_compilation_session.pas` 也已把 generic runner 正式接回
  当前 `bootstrap-native-assemble-link` production path：`ExecuteToolchain(...)` 现在直接复用
  `ExecuteToolchainPlan(...)`，并让 session 正式拥有 `tool-run-status`、
  `tool-run-step-count` 与 `primary-tool-run-status`。
- 当前 `tools/stage0/nextpas.pas` 已不再手写 `ResolveCompilerExecutable + TProcess`
  执行宿主 FPC；`stage0 build` 现在通过
  `Session.ExecuteToolchain(GetEnvironmentVariable('PATH'))` 走统一 runner，并把真实
  execution result 同步投影到 line-based output 与 `command-envelope=<json>.result`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  已把 fake `as` + `ld` 的 `native-assemble-link` execution contract 纳入 promotion path：
  `native-run-status`、assemble/link step status、object/output existence、
  response sidecar cleanup、captured response 与 object-path presence 都已被真实 gate。
- 当前 `compiler/toolchain/np_toolchain_plan.pas` 已让 `PlanFromBackend`
  直接选择 `bootstrap-native-assemble-link` production path：
  `host-fpc-emit-asm -> native-assemble -> native-link` 已经进入真实执行面，而不是继续停留在
  single-step host compile。
- 当前主 smoke success path 已被 verify 冻结为
  `toolchain-plan-family=bootstrap-native-assemble-link`、
  `tool-invocation-count=3`、`tool-run-step-count=3`、
  `primary-tool-step-id=host-fpc-emit-asm`、
  `tool-status-event-count=10` 与
  `build-trace-ref=...-toolchain-plan`；显式 source-backed unit 场景还会继续追加
  `native-assemble-<unit>` step，并让 step/event 数量继续增长。
- 当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
  已经收口：如果 failure 发生在 `native-assemble` / `native-link`，
  `compiler/frontend/np_compilation_session.pas` 现在会把
  `diagnostic-step-id`、`diagnostic-profile-id`、`diagnostic-logical-executable`、
  `build-trace-ref=trace-<session-id>-toolchain-plan` 与 `tool-status-events` 的
  step metadata 对齐到真实失败 step；
  `build/verify_local.sh` 也已用 fake `as` / `ld` 负路径冻结
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed` contract。
- 当前 success/failure observability 已整体收口：
  `compiler/frontend/np_compilation_session.pas` 现在会把 `buildTrace.steps[*]` 与
  `tool-status-events` 都扩成完整 multi-step transcript，只让真实失败 step 携带
  `diagnosticRefs`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已把 runner sidecar truth 收进正式 gate：`native-run-transcript` 会冻结
  `materialized=true|false` 与 `cleanupStatus=deleted|retained|not-requested`。
- 当前 `tools/stage0/nextpas.pas` 的 build/session projection writer 也已从
  双分支镜像收敛到统一 helper：
  `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
  不再各自维护 stdout/stderr 两套 `WriteLn(...)` 实现，而是复用同一组
  text/integer/boolean projection writer。
- 当前 `tools/stage0/nextpas.pas` 的剩余 session/syntax/resolution/semantic/mir/backend
  projection state 也已继续从平铺 `Active*` 收口到分组 record：
  `TSessionProjectionContext`、`TSyntaxProjectionContext`、
  `TResolutionProjectionContext`、`TSemanticProjectionContext`、
  `TMirProjectionContext`、`TBackendProjectionContext` 现在已经覆盖
  `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)` 与 `PrintSessionProjection(...)`；
  旧 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
  `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 残留引用已清除。
- 当前 `tools/stage0/nextpas.pas` 也已把剩余的分组 projection 序列化 / 输出细节继续收敛到
  helper：
  `BuildCommandEnvelopeJson(...)` 现在通过一组
  `Append*ProjectionJsonFields(...)` helper 拼接 result 字段，
  `PrintSessionProjection(...)` 现在通过一组
  `Print*Projection...(...)` helper 输出 line-based projection；
  fresh `bash build/verify_local.sh` 已确认字段顺序、启停条件和
  pre-session/session-owned 边界没有漂移。
- 当前 `tools/stage0/nextpas.pas` 的 clear/capture 路径也已继续收敛到按 record 分组的
  helper：
  `ClearBuildCommandContext(...)`、`ClearSessionContext(...)`、
  `CaptureBuildCommandContext(...)`、`CaptureSessionContext(...)`
  不再各自内联维护大段字段搬运，而是统一调 build/session/diagnostics/syntax/
  resolution/semantic/mir/backend/toolchain 分组 helper；fresh
  `bash build/verify_local.sh` 已确认行为无漂移。
- 当前 `invalid-unit-root` 这类在 session 创建前就失败的路径，也已经不再退回成只有
  `failureKind` 的贫血结果：已知的 `workspace-root` / `artifact-root` / `output-dir`
  等 build context 会继续出现在 line-based output，而
  `command-envelope=<json>.result` 仍保留 `source`、`target` 与 camelCase 对应字段。
- focused probe 已确认同一条 pre-session projection 也真实覆盖
  `invalid-out-dir` 与 `invalid-artifact-root`；这一批不需要继续改
  `tools/stage0/nextpas.pas`，只需要把 verify gate 补齐。
- focused probe 也确认：当 source 周围不存在 `nextpas.workspace.toml` /
  `nextpas.package.toml`，且 CLI 不传 `--workspace` 时，当前真实行为已经是
  `workspace-discovery-kind=source-directory-fallback`，workspace root 退回 source 所在目录，
  默认 artifact 则进入 `<source-dir>/.nextpas/out/linux-x86_64/`。
- 对 `build/verify_local.sh` 做 focused audit 后确认：虽然
  `package-manifest-source-root-check`、`workspace-member-source-root-check`、
  `package-manifest-source-precedence-check` 都已经在真实 promotion path 里跑通，但
  `verify-local` 最终 success envelope 之前还没有同步它们的 camelCase result field。
- focused probe 也确认：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 这些成功路径，当前真实的 `command-envelope=<json>.result`
  已经带有 `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`；缺口只是
  verify 之前还没有把这批 machine-readable truth 冻结下来。
- focused probe 还确认：`workspaceDescriptorPath` / `packageManifestPath`
  当前不是“总是带字段，有时为空”，而是按 discovery truth 按需出现：
  `stage0-smoke`、`source-directory-fallback`、`invalid-unit-root`、
  `invalid-out-dir`、`invalid-artifact-root` 都不会投影这两个字段；
  `package-manifest-source-root` 与 `package-manifest-source-precedence`
  会只带 `packageManifestPath`，不带 `workspaceDescriptorPath`；
  `workspace-member-source-root` 则会同时带上两者。
- focused probe 进一步确认：剩余 explicit-workspace 主路径
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 sessionful failure 的
  `toolchain-failure` 也都稳定省略 `workspaceDescriptorPath` /
  `packageManifestPath`；之前缺的只是更广覆盖的 verify 断言。
- 恢复会话后 fresh rerun `bash build/verify_local.sh` 继续得到
  `verify-local=pass`，说明这批 explicit-workspace omission 断言已经与当前实现一致，
  不需要再改 `tools/stage0/nextpas.pas`。
- focused probe 还确认：当前 `tools/stage0/nextpas.pas` 已经把
  `diagnostics-summary` / `human-summary` 当成共享 summary surface 稳定发出：
  success path 会给出 `diagnostics-summary=none` / `human-summary=build succeeded`，
  syntax / resolution / sema / toolchain failure 会给出对应的 diagnostic summary 与阶段级
  human summary，而显式 workspace 的 pre-session failure 也会继续镜像 envelope 顶层
  `humanSummary`；缺口只是 verify 之前没有把这层 contract 明确冻结。
- 当前 `compiler/frontend/np_unit_resolver.pas` 的 missing/ambiguous diagnostics
  已经不再只输出裸路径：`SearchRootsSummary` 与 `CandidateSummary` 现在会消费
  `TSearchPathEntry`，把 `scope` / `provenance` / `root`（以及 candidate `path`）
  一起投影进 diagnostic message。
- 新一轮 focused verification 已确认：`session-id`、`tool-invocation-plan-ref`、
  `build-trace-ref` 现在都已改成每次 build 唯一；`verify_local.sh` 已从“固定字面量断言”
  切到“同轮一致、跨轮不复用”的真实 contract。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在已拥有最小 warning contract：
  `EmitWarning` 会产出 severity=`warning` 的 structured diagnostic，
  `SetWarningAsError(true)` 会把同类 warning 提升为 severity=`error`。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在也已把 split accounting 固定下来：
  promoted warning 会进入 `ErrorCount`，而不会继续留在 `WarningCount`。
- `compiler/frontend/np_compilation_session.pas` 现在已把 diagnostics split 继续投影到
  session / stage0 result：
  line-based output 有 `diagnostics-error-count`、`diagnostics-warning-count`，
  `command-envelope=<json>.result` 也有 `diagnosticErrorCount`、
  `diagnosticWarningCount`。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已把上述 warning / warning-as-error 行为，以及 resolver search index 的
  `deferred -> ready` 状态、indexed root count 与 scan count 收进 promotion path。
- `compiler/frontend/np_unit_resolver.pas` 现在已引入最小 per-root search index，
  同一 root 的 candidate lookup 不再每次调用都重新全量扫描目录。
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  现在已把 resolver search index 公开成 session-owned projection：
  `search-index-status`、`indexed-search-root-count`、`search-index-scan-count`
  会跟随真实 lookup 行为变化，而不是总被伪装成 `ready`。
- fresh rerun `./build/verify_local.sh` 已确认：
  `examples/smoke/hello.pas` 继续如实表现为
  `search-index-status=deferred` / `0` / `0`，
  `examples/smoke/hello_with_units.pas` 则如实表现为
  `search-index-status=ready` / `2` / `2`。
- 新一轮 focused probe 也确认：
  `explicit_unit_root`、`package_manifest_source_precedence`、
  `root_source_precedence` 与 `unit_root_precedence` 这些 precedence 成功路径
  都会稳定投影 `search-index-status=partial`，而且 indexed root / scan count
  会随着命中 tier 变化：
  - root-source precedence：`1 / 1`
  - explicit/package precedence 代表路径：`2 / 2`
- `build/verify_local.sh` 现在已把这批 `partial` 行为纳入 promotion path，
  不再只靠手工 probe 留证。
- 当前“编译成功”仍然有明确 bootstrap-host 边界：
  resolution/graph/diagnostics 与 native assemble/link 已进入 nextPas 控制面，但第一步
  `host-fpc-emit-asm` 仍依赖宿主 `fpc` 发射汇编。
- 当前 Stage2 compiler-module self-compile 的首个真实 parser blocker 不是 `FreeAndNil`、
  `Format` 或 `SysUtils` 尾部缺 `implementation`，而是
  `class(Exception);` 这种 shorthand 派生类声明；nextPas parser 对
  `class(Exception) ... end;` 稳定，但对 shorthand 仍会把失败拖到 EOF 才报
  `"IMPLEMENTATION" expected`。
- 当前 `compiler/backend/np_backend_plan.pas` / `compiler/toolchain/np_toolchain_plan.pas`
  原先无条件把 root source 当成 `executable`，这对 compiler units 是错误模型；
  把 `unit` roots 明确降成 `object-file`，并让 toolchain 只走
  `bootstrap-native-assemble`，才能让 self-hosting 成功边界和真实产物形状对齐。
- `build/verify_local.sh` 现在已经把 compiler-module self-compile 纳入 promotion path：
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 必须在
  `backend-output-kind=object-file`、
  `toolchain-plan-family=bootstrap-native-assemble`、
  `logical-link-request-status=deferred` 下稳定成功，而且不得偷偷退回 `native-link`。
- `np_workspace_model` 这条 self-compile contract 还额外冻结
  `tool-invocation-count=2` / `tool-run-step-count=2`，防止 unit root 被误扩成 transitive
  extra assemble 或 native link。

## Technical Decisions

| Decision                                                                                                                               | Rationale                                                                                                                         |
| -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------------------------------------------------------------------------- |
| 先把 `smoke` 和 CI 变成真实 gate，再继续扩功能                                                                                         | 没有可信验证，后续所有阶段都会被假进展污染                                                                                        |
| harness 只按 group 契约收集 `.pas` fixture                                                                                             | 让测试输入和源码树生成物彻底解耦                                                                                                  |
| snapshot-bearing groups 统一对比 canonical actual text                                                                                 | 降低输出噪声，提高 baseline 的稳定性和可回放性                                                                                    |
| `resolver.unit-name-mismatch` 进入正式 failure model                                                                                   | 防止“文件名像是对的”却静默绑定错误 unit                                                                                           |
| implicit `System` 保留 graph 语义，但显式 `uses System` 必须继续解析真实源码                                                           | 同时保留 runtime edge 显式性和 source provenance correctness                                                                      |
| 文档只写当前已验证事实，并明确标注 search path / host-backed 限制                                                                      | 避免把设计目标误写成当前能力                                                                                                      |
| `stage0 test` 继续做 thin wrapper，而不是重写 harness                                                                                  | harness 已经是 execution owner；driver 只该负责 CLI parse、workspace root 选择与 env bridge                                       |
| planning files 与架构文档必须同步最小 package/workspace source root 现状                                                               | 避免下一轮恢复时被过时的“project roots 未落地”表述误导                                                                            |
| 长期质量目标必须先落成 `architecture-principles-specification.md`，再继续扩局部能力                                                    | 防止“现代、高性能、优雅、一流框架”只停留在口号；后续切片要围绕 owner、truth object、projection、promotion gate 和 non-goal 做取舍 |
| 当前 rolling plan 必须进入 docs-check                                                                                                  | 它是后续“继续”恢复当前生产路径的活动入口，不能只靠人工记忆避免 Batch 状态漂移                                                     |
| `query symbols` detail 必须由 `TCompilationSession` 投影，而不是由 CLI 重扫源码或 scrape build output                                  | 这样 future IDE/automation 可以复用同一份 semantic symbol graph，同时保持 `stage0` 只是 thin entrypoint                           |
| `.sisyphus/`、FPC 中间产物、runner/bootstrap 产物、snapshot diff evidence 和已知 smoke/example 产物统一进入 ignore                     | 降低源码树污染，避免历史生成物继续影响测试与工作区判断                                                                            |
| resolution diagnostics 继续沿用现有 message 通路，只在 formatter 层接入 typed search-path provenance                                   | 保持改动面最小，同时把 consulted root / candidate origin 变成 verify-able output                                                  |
| workspace discovery 这一批只做“已有 truth 的稳定投影”，不提前引入完整 workspace model                                                  | 保持变更 grounded 在当前实现上，同时让 CLI / envelope 更诚实                                                                      |
| early failure 继续复用 `Active...` command context，而不是再发明 session-less pseudo model                                             | 保持 ownership 边界不变，同时避免 pre-session failure 丢掉已知 build truth                                                        |
| 如果 focused probe 已证明行为存在，下一步先补 verify gate 而不是先改实现                                                               | 让增量更小，也让 promotion path 尽快覆盖真实已落地行为                                                                            |
| verify-local 的 success envelope 也要同步新增 gate 名称                                                                                | 避免结构化 verify 结果落后于 shell gate 现状                                                                                      |
| `diagnostics-summary` / `human-summary` 既然已被规范列为最小结果表面，就应一起进入 verify gate                                         | 避免共享 summary surface 继续只靠实现自觉，而没有 promotion-path 保护                                                             |
| session / plan / trace locator 的契约应是“唯一且一致”，不是固定字面量                                                                  | 避免 verify 和文档把实现细节误冻结成错误的公开协议                                                                                |
| 继续扩 toolchain projection 前，先补 semantic diagnostics 和 workspace/source-root truth                                               | 当前最需要的是 ownership 变真实，而不是再增加更多外层投影字段                                                                     |
| resolver search index 继续保持 lazy，并把 `deferred                                                                                    | partial                                                                                                                           | ready` 当成有效结果 | 这比强行 eager 扫描更诚实，也更符合 session 当前真实消费过的 search-root 状态 |
| `partial` 必须被当成 precedence 命中的正常成功状态，而不是模糊中间态                                                                   | 只有把它正式 gate 住，后续才能防止高优先级命中后又退化回低价值的全量扫描                                                          |
| toolchain contract smoke 必须在临时 build dir 里编译，并显式证明源码树没有被生成物污染                                                 | 否则 verify 自己会继续制造 source-adjacent output，削弱 hygiene contract                                                          |
| harness bootstrap failure 必须保留 step/command/stderr locator 和原始 stderr evidence                                                  | 否则 CI 或本地回放仍只看到模糊 failure kind，无法快速定位 bootstrap 失败点                                                        |
| internal compaction 必须保持在 owned-shape 层完成，而不是一半 record 一半平铺全局                                                      | 否则后续维护仍要同时理解两套 state surface，增加实现漂移风险                                                                      |
| projection writer 也必须收敛到单一路径，而不是 stdout/stderr 各维护一套镜像 `WriteLn(...)`                                             | 否则任何字段调整都容易只改到一边，重新制造 surface drift                                                                          |
| 剩余 session/syntax/resolution/semantic/mir/backend projection 也应按阶段 record 化，而不是继续让四条主路径直接消费散落 `Active*` 字段 | 这样才能让 owner shape 一致，同时保持 envelope / CLI surface 不变                                                                 |
| 分组 projection 的 JSON 拼接与 line-based 输出细节也应继续收敛到 helper，而不是长期留在两个大函数里                                    | 这样后续再做 compaction 时更容易守住字段顺序、启停条件和 ownership 边界                                                           |
| clear/capture 路径也应按 record helper 收敛，而不是继续把字段清理和复制集中在两个超长入口里                                            | 这样 owner shape 才能在 capture、clear、envelope、print 四条主路径上同时一致                                                      |
| 在 backend 还没有 assembly/object intermediate truth 之前，不把 `stage0 build` 伪装成 multi-step native assembler/linker               | 否则会把 typed plan、backend artifact truth 与真实 production path 说错；先落通用 runner 和 contract gate 更诚实                  |
| `TToolchainPlan` runner 继续只消费 typed `steps/inputs/outputs/sidecars`，不接受退化回 shell string 的执行模型                         | 这样 future assembler/linker/resource/archiver 复用同一份 plan ownership，而不是重新逃回临时脚本拼接                              |
| 当前 host-compiler production path 也必须复用同一套 runner，而不是继续保留 driver 私有 `TProcess` 路径                                 | 这样 `stage0 build` 的 selection/start/success/failure bookkeeping、CLI projection 与 execution contract 才不会长期分叉           |

## Issues Encountered

| Issue                                                                                                                                                                                              | Resolution                                                                                                                                                                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------- |
| 历史 runner、fixture 二进制和 `.o/.ppu` 直接留在源码树里                                                                                                                                           | 补齐 `.gitignore`，并清理已确认的历史生成物、过期 diff 与 fresh verify 产物                                                                                                                                                                    |
| 旧文档仍在描述 inventory-style harness                                                                                                                                                             | 全面回写 `tests/` README 与架构规范，改成真实执行语义                                                                                                                                                                                          |
| `unit-resolution` / `stage0` 文档与 planning files 落回了旧 search path 说法                                                                                                                       | 改回“当前已支持最小 package/workspace source roots，并继续诚实标注非完整 workspace truth”                                                                                                                                                      |
| 容易把当前绿灯误解成“nextPas 已经独立编译全部路径”                                                                                                                                                 | 在 README、架构规范和 planning files 里明确标注 host-backed 边界                                                                                                                                                                               |
| missing / ambiguous unit diagnostics 仍只显示裸路径，无法说明候选来源                                                                                                                              | 在 resolver formatter 层复用 `TSearchPathEntry`，补齐 `scope` / `provenance` / `root` / `path`                                                                                                                                                 |
| workspace / artifact discovery 真实存在，但 CLI / envelope 之前没有把它们当正式 command truth 投影出来                                                                                             | 在 `TCompilationOptions` / `TCompilationSession` 补最小 metadata，并让 stage0 输出/结构化结果同步带上这些字段                                                                                                                                  |
| `invalid-unit-root` 会在 session 创建前失败，导致 failure envelope 一度丢掉已知的 workspace/artifact/output truth                                                                                  | 继续沿用 `Active...` command context，并让 `PrintSessionProjection(...)` 先投影 build context，再按 `session-id` 决定是否打印 session-owned fields                                                                                             |
| `invalid-out-dir` / `invalid-artifact-root` 已经有正确行为，但 promotion path 之前没有 gate 覆盖                                                                                                   | 先用 focused probe 确认现状，再把两条 early-failure baseline 收进 `build/verify_local.sh`                                                                                                                                                      |
| `source-directory-fallback` 行为已在位，但 verify 之前没有冻结这条成功路径的 workspace/artifact contract                                                                                           | 用临时 source-dir probe 确认现状后，补齐 `source-directory-fallback-check` 与 verify-local success envelope 字段                                                                                                                               |
| 三条 package/workspace source-root gate 已经存在，但 verify-local success envelope 仍漏掉对应 machine-readable 字段                                                                                | 先做 gate/result 对照，再把 `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、`packageManifestSourcePrecedenceCheck` 补进最终 `command-envelope=<json>.result`                                                               |
| 多条 success path 虽然已在 envelope 里投影 `outputDir` / `artifact` / `searchPaths`，但 verify 仍主要只看 line-based output                                                                        | 先做 focused probe 确认 truth 已在位，再为 `explicit-unit-root`、`out-dir-override` 与几条 precedence gate 补齐 envelope 断言                                                                                                                  |
| descriptor / manifest projection 的“缺失边界”之前主要靠实现自觉，verify 只冻结了部分 presence case                                                                                                 | 先做 focused probe 确认按需省略已在位，再把代表性 success / failure 路径的 line/envelope absence contract 补进 `build/verify_local.sh`                                                                                                         |
| remaining explicit-workspace 主路径虽然也稳定省略 descriptor / manifest 字段，但 verify 之前只做了代表性 absence 覆盖                                                                              | 继续对 `semantic-smoke`、`explicit-unit-root`、几条 precedence / override 成功路径与 `toolchain-failure` 做 focused probe，并补齐 absence 断言                                                                                                 |
| `diagnostics-summary` / `human-summary` 虽然已由共享输出路径稳定发出，但 verify 之前只零散覆盖少数 failure 文本                                                                                    | 先对 success、sessionful failure 与 pre-session failure 做 focused probe，再把 representative summary line/envelope contract 补进 `build/verify_local.sh`                                                                                      |
| 旧文档把 `plan-build-linux-x86_64-file-1-*` / `trace-build-linux-x86_64-file-1-*` 写成固定示例，已经和实现不符                                                                                     | 全面改成 `plan-<session-id>-...` / `trace-<session-id>-...`，并在规范里明确“唯一且一致”才是正式契约                                                                                                                                            |
| 路线图近期建议一度偏向 richer toolchain projection，容易掩盖 semantic/workspace truth 仍待补强的现实                                                                                               | 在 master roadmap 和 master roadmap plan 里把近期优先级改回 warning contract、resolver/workspace truth，再谈更丰富的 toolchain 外层投影                                                                                                        |
| parser 当前对 shorthand `class(Exception);` 不稳定，而 compiler RTL / frontend/toolchain source 恰好大量使用这种写法                                                                               | 把 shorthand 统一降格为显式 `class(Exception) ... end;`，先把语法形态收敛到已验证路径，避免 Stage2 自编译继续卡在 parser 假象上                                                                                                                |
| compiler unit roots 没有 entry point，但 backend/toolchain 之前仍无条件产出 `executable` 并计划 `native-link`                                                                                      | 把 root kind 接入 backend/toolchain；`unit -> object-file`、`program                                                                                                                                                                           | library | package -> executable`，让产物模型与真实 Pascal root semantics 对齐 |
| `compiler/diagnostics` / `compiler` / `unit-resolution` 规范与 planning files 还没有写出 split diagnostics accounting 和 lazy search-index projection                                              | 依据已通过的 toolchain contract 与 smoke verification，把这两条 contract 回写到架构说明和持续记录里                                                                                                                                            |
| precedence 成功路径上的 `partial` search-index 行为之前只在手工 probe 里可见，promotion path 没有正式保护                                                                                          | 在 `build/verify_local.sh` 为 representative precedence 路径补齐 line/envelope 两层 partial-state 断言，并同步 README/架构规范                                                                                                                 |
| `build/verify_local.sh` 的 toolchain contract probe 之前会把 `tests/toolchain/toolchain_contract_smoke` 与 `.o` 留在源码树                                                                         | 改成临时 build dir，并在 verify 里显式断言源码树中不存在这两个生成物                                                                                                                                                                           |
| `tests/run_all_tests.sh` 的 stage0 bootstrap failure 之前只暴露模糊的 `stage0-build-failed`                                                                                                        | 在 bootstrap failure 输出里补齐 `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并回显原始 stderr evidence                                                                                                                     |
| `tools/stage0/nextpas.pas` 在引入 projection record 之后，`PrintSessionProjection(...)` 仍残留旧平铺全局字段访问                                                                                   | 把 stdout/stderr session projection 统一切到 `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`，并用 fresh `bash build/verify_local.sh` 确认行为不变                                                                                 |
| `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)` 之前仍各自维护 stdout/stderr 双分支，任何字段调整都要同步改两遍                                                                 | 引入统一 projection writer helper，把 build/session projection 收敛到单一路径，并用 fresh `bash build/verify_local.sh` 确认输出契约未变                                                                                                        |
| `tools/stage0/nextpas.pas` 里剩余的 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` / `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 仍是散落平铺状态，导致 owner shape 半收口半悬空 | 引入六个 projection context record，并让 envelope、clear/capture 与 session projection 全部改走分组 context，再用 fresh `bash build/verify_local.sh` 确认无行为漂移                                                                            |
| `BuildCommandEnvelopeJson(...)` / `PrintSessionProjection(...)` 虽然已经吃分组 context，但分组字段的具体 JSON 拼接与 line-based 输出仍集中在两个大函数里，后续容易把顺序或启停条件改偏             | 抽出 `Append*ProjectionJsonFields(...)` 与 `Print*Projection...(...)` helper，并用 fresh `bash build/verify_local.sh` 确认 contract 继续稳定                                                                                                   |
| `ClearSessionContext(...)` / `CaptureSessionContext(...)` 以及 build-context 对应入口仍直接维护跨多个 record 的大段字段清理/复制，后续继续 compaction 时容易漏改某一组 projection                  | 抽出按 record 分组的 clear/capture helper，并用 fresh `bash build/verify_local.sh` 确认公开行为继续稳定                                                                                                                                        |
| workspace/package/artifact truth 仍散落在 driver helper、session 字段与 manifest parser 之间，owner boundary 不够诚实                                                                              | 新增 `compiler/frontend/np_workspace_model.pas`，让 `TCompilationSession` 正式拥有 model，并让 `stage0` 改成 shared model consumer                                                                                                             |
| success-path build trace/status-event 之前仍是单步摘要，later-step failure trace ref 也还是 step-anchored                                                                                          | 扩 `compiler/frontend/np_compilation_session.pas` 与 runner transcript，让 success/failure 全部对齐 plan-level `build-trace-ref=trace-<session-id>-toolchain-plan`，并用 fresh `bash build/verify_local.sh` 冻结 full-step transcript contract |
| 当前多步 production path 已经真实执行 root/native steps，但显式 source-backed unit 还需要额外 assemble step 才能保持 smoke 全绿                                                                    | 在 `TCompilationSession` 收集 source-backed unit 的额外 assembly base name，并让 planner 追加 `native-assemble-<unit>` steps，再用 `build/verify_local.sh` 冻结这条 contract                                                                   |

## 2026-05-23 Follow-up Findings

- `compiler/diagnostics/np_diagnostics_sink.pas` 当前必须显式带 `{$UNITPATH .}`，否则同目录
  `nextpas_json_helpers` 不会稳定进入 compiler-module self-compile 的解析面。
- `units/linux-x86_64/SysUtils.pas` 当前还缺一条真实 compiler dependency；
  `IntToHex(Value: Int64; Digits: Integer)` 补齐后，Stage2 / diagnostics path 才重新闭合。
- `compiler/frontend/np_compilation_session.pas` 的 extra-assemble 边界现在已经明确：
  `unit` root 不追加 transitive deps；linked root 会收集 source-backed units，包括
  `installed-source`，但继续跳过 `implicit-runtime`。
- `examples/smoke/hello_with_units.pas` 在 `run_stage0_build_capture` 的 `--fold` 语境下，
  当前真实 contract 已冻结为 `typed-hir-node-count=8`、
  `tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`；先前看到的 `20` 是 verify 脚本期望漂移，不是实现回归。
- fresh `bash build/verify_local.sh` 已再次拿到 `verify-local=pass`，说明这轮修复没有引入
  新的 toolchain / semantic / self-host contract 漂移。
- 后续接手时不要再把 `np_workspace_model` 当作“只在 notes 里成功”的灰色项：它现在已经和
  `np_diagnostics_sink`、`np_source_database` 一起进入 `compiler-module-self-compile-check`。

## Resources

- [runner.pas](/home/dtamade/projects/nextPas/tests/harness/runner.pas)
- [snapshot_support.pas](/home/dtamade/projects/nextPas/tests/harness/snapshot_support.pas)
- [run_all_tests.sh](/home/dtamade/projects/nextPas/tests/run_all_tests.sh)
- [np_unit_resolver.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_resolver.pas)
- [np_unit_graph.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_graph.pas)
- [np_compilation_session.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_compilation_session.pas)
- [np_workspace_model.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_workspace_model.pas)
- [np_diagnostics_sink.pas](/home/dtamade/projects/nextPas/compiler/diagnostics/np_diagnostics_sink.pas)
- [np_ast_facade.pas](/home/dtamade/projects/nextPas/compiler/syntax/np_ast_facade.pas)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [nextpas.pas](/home/dtamade/projects/nextPas/tools/stage0/nextpas.pas)
- [np_toolchain_plan.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_plan.pas)
- [np_toolchain_runner.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_runner.pas)
- [toolchain_contract_smoke.pas](/home/dtamade/projects/nextPas/tests/toolchain/toolchain_contract_smoke.pas)
- [tests/harness/README.md](/home/dtamade/projects/nextPas/tests/harness/README.md)
- [tests/README.md](/home/dtamade/projects/nextPas/tests/README.md)
- [test-harness-specification.md](/home/dtamade/projects/nextPas/docs/architecture/test-harness-specification.md)
- [unit-resolution-specification.md](/home/dtamade/projects/nextPas/docs/architecture/unit-resolution-specification.md)
- [stage0-driver-specification.md](/home/dtamade/projects/nextPas/docs/architecture/stage0-driver-specification.md)
- [compiler-specification.md](/home/dtamade/projects/nextPas/docs/architecture/compiler-specification.md)
- [diagnostics-specification.md](/home/dtamade/projects/nextPas/docs/architecture/diagnostics-specification.md)
- [toolchain-specification.md](/home/dtamade/projects/nextPas/docs/architecture/toolchain-specification.md)
- [stage0 README](/home/dtamade/projects/nextPas/tools/stage0/README.md)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [pre-session-build-context-projection-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-03-26-pre-session-build-context-projection-plan.md)
- [workspace-model-shared-truth-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-04-05-workspace-model-shared-truth-plan.md)

## Visual/Browser Findings

- 本轮未使用图片或浏览器结果

## 2026-05-27 Follow-up Findings

- 当前仓库 live truth 是：本批 platform Windows wait/error ownerization 改动直接发生在
  `main` 的 dirty worktree 上，尚未提交；历史
  `codex/platform-time-integration @ 02be065` 仍未合入 `main@b255298`，不能把它误记为已合并。
- `nextpas.core.platform.windows.ffi` 现在不应只拥有 ABI declaration 和 timeout conversion；
  Windows last-error 投影、timeout classification、wait-result success semantics 也应该继续归它 owner。
- `platform.thread` 的 Windows consumer 现在应该只消费
  `windows_last_error_i32` 与 `windows_wait_for_single_object_is_signaled`；
  raw `GetLastError` 与 `WAIT_OBJECT_0` 不应继续散落在实现里。
- `platform.sync` 的 Windows consumer 现在应该只消费
  `windows_last_error_i32`、`windows_last_error_is_timeout` 与
  `windows_timeout_ns_to_ms`；raw `GetLastError` / `ERROR_TIMEOUT`
  不应继续散落在 condvar / `WaitOnAddress` 路径里。
- 这批 focused gate 已把上面的 owner boundary 冻结成 source-surface contract：
  `test_platform_thread_host_ffi_surface` 与
  `test_platform_sync_host_ffi_surface` 现在同时防回归 raw consumer 语义。
- fresh `bash build/verify_local.sh` 已再次得到 `verify-local=pass` 与
  `human-summary=local verification passed`，说明这批 owner boundary 收紧没有引入
  thread/sync/platform 的回归。
- 下一轮最自然的 platform 方向，不是再回头碰 stopwatch 一类 L1 time API，而是继续审计
  `platform.time` / `platform.sync` 剩余的 host capability / wait semantics owner truth，
  尤其是 Windows 与 Darwin 的 residual policy token。

## 2026-05-27 Follow-up Findings 2

- `platform_errno_location` 的 external binding 虽然早已沉到 `linux/darwin/android/freebsd/unix`
  各自 ffi owner，但这还不等于 errno read ownership 已完全收口；如果 consumer 还在自己写
  `platform_errno_location^`，那“当前 errno 值怎么读”的 ABI 细节仍在实现层泄漏。
- `platform.thread` 与 `platform.sync` 现在都改为消费 host-owned
  `platform_posix_errno_value`，不再自己解引用 errno storage。
- `linux/darwin/android/freebsd/unix` ffi 单元现在统一拥有 errno location binding 与 errno value
  helper 两层 truth；consumer 只继续拥有 retry / timeout / error mapping policy。
- 这批 focused gate 现在不只冻结 `EINTR` token 或 errno symbol binding 的存在，还额外防回归
  consumer 直接写 `platform_errno_location^`。
- 这一步让 POSIX errno truth 的 owner boundary 比之前更完整：shared `posix.ffi` 仍只保留
  shared ABI，per-host errno binding 与 errno read helper 都继续留在各 host ffi owner。

## 2026-05-27 Follow-up Findings 3

- `platform.time` 之前虽然已经不直接依赖 FPC 平台单元，也已经通过 nextPas-owned ffi
  声明 raw externals，但 Darwin `mach_timebase_info` cache / sanitize 与 Windows QPC /
  FILETIME 读取细节仍停留在 consumer。
- 这轮之后，`darwin.ffi` 继续拥有 `darwin_mach_monotonic_ns` 与
  `darwin_mach_monotonic_resolution_ns`，`windows.ffi` 继续拥有
  `windows_qpc_frequency_u64`、`windows_qpc_counter_u64` 与
  `windows_filetime_now_unix_ns`；`platform.time` 不再直接写 raw
  `mach_absolute_time` / `mach_timebase_info` / `QueryPerformance*` /
  `GetSystemTimeAsFileTime` 调用。
- 现在 `platform.time` 的 Darwin / Windows 分支更接近“platform contract consumer”
  而不是“宿主时钟初始化脚本”：host-specific stateful helper 继续留在各自 ffi owner，
  consumer 只保留跨平台 public contract 与通用安全换算。
- `test_platform_time_host_ffi_surface` 现在不仅要求 host ffi 暴露 Darwin / Windows
  时钟 helper，还额外防回归 consumer 直接回到 raw `mach_*` / QPC / FILETIME 调用。
- 当前证据边界仍然要诚实：Win64 compile-only 已补跑通过，但 Darwin compile-only 在当前
  Linux 宿主因为缺少 target `System` 单元而拿不到有效编译证据，因此这批没有新增 Darwin
  runtime / compile proof，只新增了 source-surface owner boundary 与 Linux 主门全绿证据。

## 2026-05-27 Follow-up Findings 4

- `platform.thread` 之前已经把 Windows wait/error、sleep timeout、POSIX errno truth 收进了
  host ffi owner，但 current-thread id、yield、TLS 和 CPU count helper 仍停留在 consumer。
- 这轮之后，`windows.ffi` 继续拥有 `windows_current_thread_id_u64`、
  `windows_thread_yield`、`windows_tls_alloc_key`、`windows_tls_free_key`、
  `windows_tls_set_value`、`windows_tls_get_value` 与 `windows_cpu_count_i32`；
  `platform.thread` 不再直接写 raw `GetCurrentThreadId` / `SwitchToThread` / `Tls*` /
  `GetSystemInfo`。
- Linux/Android/Darwin/FreeBSD/generic Unix 现在也各自拥有
  `platform_thread_self_token_u64`、`platform_native_thread_id_u64` 与
  `platform_cpu_count_i32`，所以 consumer 不再直接写 `pthread_self`、`gettid`、
  `pthread_threadid_np`、`pthread_getthreadid_np` 或 `sysconf(...)`。
- 现在 `platform.thread` 的 Unix / Windows 分支更像“platform thread contract consumer”
  而不是零散的宿主 helper 集合；raw helper 的 ABI / fallback / token truth 都继续留在宿主 ffi owner。
- 这批 focused gate 也同步冻结了新的 owner boundary：`test_platform_thread_host_ffi_surface`
  现在不仅检查 helper 是否存在，还显式防回归 consumer 重新直接调用上述 raw helper。

## 2026-05-27 Follow-up Findings 5

- `platform.sync` 之前虽然已经把 Windows sync ABI declaration 并入统一
  `nextpas.core.platform.windows.ffi`，但 consumer 仍直接调用
  `InitializeSRWLock`、`AcquireSRWLock*`、`SleepConditionVariableSRW`、
  `WaitOnAddress` 与 `WakeByAddress*`；ABI owner 和 helper owner 还没有完全收口到同一层。
- 这轮之后，`windows.ffi` 不只拥有 raw declaration，还继续拥有
  `windows_mutex_*`、`windows_rwlock_*`、`windows_condvar_*`、
  `windows_wait_address_i32` 与 `windows_wake_address_*`；`platform.sync` 不再直接写 raw
  Windows sync API。
- `platform.sync` 的 Windows consumer 现在更接近“public contract + policy consumer”：
  它继续保留 `PLATFORM_ERR_BUSY` / `PLATFORM_ERR_TIMEOUT` 映射、`windows_timeout_ns_to_ms`
  以及 `windows_last_error_is_timeout` 的策略消费，但把 raw SRWLOCK / condvar /
  address-wait 调用细节收回 host ffi owner。
- 这轮 focused gate 也更诚实了：`test_platform_sync_host_ffi_surface` 不再保留
  “要求出现 raw WaitOnAddress token、同时又禁止直接调用它” 这种自相矛盾断言，而是明确冻结
  consumer 只消费 helper 名称。
- Win64 compile-only 与 fresh `bash build/verify_local.sh` 都已通过，说明这次 helper
  ownerization 没把 `platform.sync` 的行为、尺寸契约或仓库级主门打坏。

## 2026-05-27 Follow-up Findings 6

- `platform.sync` 的 Linux futex path 之前虽然已经依赖 `linux.ffi` 拥有 syscall binding、
  futex constants 与 errno helper，但 consumer 仍自己拼 `linux_syscall + FUTEX_* + timespec`，
  所以 helper ownership 还没像 Windows 那样完全收口。
- 这轮之后，`linux.ffi` 不只拥有 raw futex ABI truth，还继续拥有
  `linux_futex_wait_i32`、`linux_futex_wake_one_i32`、`linux_futex_wake_all_i32`；Linux
  futex opcode 组合、timeout `timespec` 组装与 errno 读取不再散落在 consumer。
- `platform.sync` 的 Linux consumer 现在更接近“public contract + error mapping consumer”：
  它继续保留 nil/value mismatch 检查和 `platform_posix_map_error`，但不再直接触碰 raw
  `linux_syscall` / `LINUX_SYSCALL_FUTEX` / `FUTEX_*` 细节。
- `test_platform_sync_host_ffi_surface` 现在同时冻结 Windows helper owner boundary 和 Linux
  futex helper owner boundary，source-surface gate 比之前更接近真正的“host helper ownerization”
  目标，而不只是“ABI declaration 在 ffi 里”。
- focused tests、Win64 compile-only 与 fresh `bash build/verify_local.sh` 都已通过，说明这批
  Linux futex helper 下沉没有引入 `platform.sync` 行为回归，也没有破坏仓库级验证面。

## 2026-05-27 Follow-up Findings 7

- 当前 live truth 仍然要说清楚：`main` 已经承载多轮 platform ownerization 提交，但
  `codex/platform-time-integration @ 02be065` 这个旧 worktree 还没有合入 `main`；当前收口的
  是 `main` 上未提交的 `platform.thread` Windows lifecycle helper batch。
- `platform.thread` 虽然已经把 wait/error、TLS、CPU count 等 helper 收进 host ffi owner，
  但如果 consumer 还直接写 `CreateThread`、`WaitForSingleObject`、`CloseHandle`、`Sleep`、
  `InterlockedDecrement`，那 Windows handle lifecycle / sleep / atomic refcount truth 仍未真正收口。
- 这轮之后，`nextpas.core.platform.windows.ffi` 继续拥有
  `windows_thread_create_handle`、`windows_thread_wait_terminated`、
  `windows_thread_close_handle`、`windows_thread_sleep_ns`、
  `windows_atomic_decrement_i32`；`platform.thread` 不再直接调用上述 raw WinAPI。
- `platform.thread` 的 Windows consumer 现在更接近“public contract + lifecycle state
  consumer”：它继续保留 thread state、join/detach 收口时机和返回值语义，但把 raw Windows
  handle create/wait/close、sleep rounding 与 atomic refcount 细节都收回 host ffi owner。
- `test_platform_thread_host_ffi_surface` 现在也把这条 owner boundary 冻成 source-surface
  contract：既要求 helper 名称存在，也防回归 consumer 重新直接调用 raw
  `CreateThread` / `WaitForSingleObject` / `CloseHandle` / `Sleep` /
  `InterlockedDecrement`。
- focused tests、Win64 compile-only 与 fresh `bash build/verify_local.sh` 都已通过，说明这批
  Windows lifecycle helper 下沉没有破坏 `platform.thread` 行为或仓库级主门。

## 2026-05-27 Follow-up Findings 8

- `platform.thread` 的 Unix 分支之前虽然已经把 self token、native thread id、CPU count、
  errno read 等 truth 收进 host ffi owner，但 consumer 仍直接碰
  `pthread_create`、`pthread_join`、`pthread_detach`、`pthread_key_*`、
  `sched_yield` 与 `nanosleep`，所以 pthread lifecycle / TLS / sleep retry 这层 owner boundary
  还是半收口状态。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 统一继续拥有
  `platform_pthread_create_handle`、`platform_pthread_join_handle`、
  `platform_pthread_detach_handle`、`platform_pthread_yield`、
  `platform_pthread_sleep_ns` 与 `platform_pthread_tls_*`；`platform.thread`
  不再直接调用 raw `pthread_*` / `sched_yield` / `nanosleep`。
- 现在 `platform.thread` 的 Unix consumer 更接近“public contract + state consumer”：
  它继续保留 `TPosixThreadState`、join/detach 收口时机和返回值语义，但把 pthread lifecycle、
  TLS key 操作和 sleep retry 细节继续收回当前宿主 ffi owner。
- `test_platform_thread_host_ffi_surface` 现在也把这条 POSIX owner boundary 冻成 source-surface
  contract：不仅要求各宿主 ffi 文件继续暴露 helper 名称，也防回归 consumer 重新直接调用 raw
  `pthread_*` / `sched_yield` / `nanosleep`。
- 当前证据边界要继续诚实：这批新增了 Linux focused runtime proof 与 Win64 compile-only，
  但没有新增 Darwin / FreeBSD / Android runtime 或 cross compile 证据，所以这些宿主目前仍主要由
  source-surface contract 覆盖。

## 2026-05-27 Follow-up Findings 9

- `platform.sync` 的 Unix 分支之前虽然已经把 pthread capability token、Linux futex helper、
  Windows sync helper 和 errno read truth 收进 host ffi owner，但 consumer 仍直接碰
  `clock_gettime`、`pthread_mutexattr_*`、`pthread_mutex_*`、`pthread_rwlock_*`、
  `pthread_condattr_*`、`pthread_cond_*` 与 `sched_yield`，所以 POSIX sync helper ownership
  还是半收口状态。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 统一继续拥有
  `platform_pthread_timeout_clock_now`、`platform_pthread_mutex_*`、
  `platform_pthread_rwlock_*` 与 `platform_pthread_condvar_*`；`platform.sync`
  不再直接调用 raw `clock_gettime` / `pthread_*` / `sched_yield`。
- 现在 `platform.sync` 的 Unix consumer 更接近“public contract + policy consumer”：
  它继续保留 public opaque storage contract、`PLATFORM_ERR_*` 映射、deadline 计算与
  wait-bucket fallback 策略，但把 timeout clock 读取、mutex/cond attr 初始化和 raw pthread
  调用细节继续收回当前宿主 ffi owner。
- `test_platform_sync_host_ffi_surface` 现在也把这条 POSIX owner boundary 冻成 source-surface
  contract：不仅要求各宿主 ffi 文件继续暴露 helper 名称，也防回归 consumer 重新直接调用 raw
  `clock_gettime` / `pthread_*` / `sched_yield`。
- 当前证据边界仍然要诚实：这批新增了 Linux focused runtime proof 与 Win64 compile-only，
  但没有新增 Darwin / FreeBSD / Android runtime 或 cross compile 证据，所以这些宿主目前仍主要由
  source-surface contract 覆盖。

## 2026-05-27 Follow-up Findings 10

- `platform.time` 的 Unix / Darwin consumer 之前虽然已经把 Windows QPC / FILETIME helper、
  Darwin `mach_*` helper 和 host clock id token 收进 `*.ffi` owner，但 POSIX 路径仍直接碰
  raw `clock_gettime` / `clock_getres`，所以 host clock helper ownership 还没像
  `platform.thread` / `platform.sync` 一样收紧到底。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 统一继续拥有
  `platform_clock_monotonic_now`、`platform_clock_realtime_now`、
  `platform_clock_monotonic_getres`；`platform.time` 不再直接调用 raw
  `clock_gettime` / `clock_getres`，也不再直接消费 raw host clock id token。
- 现在 `platform.time` 更接近“public contract + cross-platform conversion consumer”：
  它继续保留 `platform_timespec_to_ns`、QPC/frequency 安全换算和 public clock contract，但把
  POSIX raw clock 调用细节继续收回当前宿主 ffi owner。
- `test_platform_time_host_ffi_surface` 现在也把这条 POSIX/Darwin owner boundary 冻成
  source-surface contract：不仅要求各宿主 ffi 文件继续暴露 clock helper 名称，也防回归
  consumer 重新直接写 raw `clock_gettime` / `clock_getres` 或 host clock id。
- 当前证据边界仍然要诚实：这批新增了 Linux focused runtime proof、Win64 compile-only 与
  fresh `verify_local` 主门通过，但没有新增 Darwin / FreeBSD / Android runtime 或 cross
  compile 证据，所以这些宿主目前仍主要由 source-surface contract 覆盖。

## 2026-05-27 Follow-up Findings 11

- `platform.thread` / `platform.sync` 前几轮虽然已经把 raw pthread / futex / WinAPI helper 收进
  host ffi owner，但 ABI size truth 仍没有完全收口：`platform.thread` 还直接保存
  `pthread_t`，`platform.sync` 还在 consumer interface 里直接写
  `SizeOf(pthread_*_t)` / `SizeOf(SRWLOCK)` / `SizeOf(CONDITION_VARIABLE)`。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 统一继续拥有
  `PLATFORM_PTHREAD_TOKEN_SIZE`、`PLATFORM_PTHREAD_MUTEX_SIZE`、
  `PLATFORM_PTHREAD_RWLOCK_SIZE`、`PLATFORM_PTHREAD_CONDVAR_SIZE`；`windows.ffi`
  继续拥有 `PLATFORM_WINDOWS_MUTEX_SIZE`、`PLATFORM_WINDOWS_RWLOCK_SIZE`、
  `PLATFORM_WINDOWS_CONDVAR_SIZE`。
- POSIX host ffi 的 interface 现在显式 `uses nextpas.core.platform.posix.ffi`，让 shared ABI
  shape 只在 ffi owner 层参与 size 派生；consumer 不再需要重新知道 raw type 名字。
- `platform.thread` 的 Unix consumer 现在用 nextPas 自己的 opaque byte storage 承载 pthread
  token，并通过 `PLATFORM_PTHREAD_TOKEN_SIZE` 定义尺寸；这比继续把 raw `pthread_t` 放进
  consumer state record 更符合 L0 boundary。
- `platform.sync` 的 public opaque storage size 现在只消费 host-owned size token；旧的
  `test_platform_sync_posix_surface` 初次在 fresh `verify_local` 里失败，正好暴露出它还冻结旧设计。
  修正后，这条 gate 也开始和新的 owner boundary 对齐。
- focused tests、Win64 compile-only 与第二轮 fresh `bash build/verify_local.sh` 都已通过，
  说明这批 ABI size-token ownerization 没把行为测试、跨平台 compile-only 或仓库级主门打坏。

## 2026-05-27 Follow-up Findings 12

- ABI size truth 收回 host ffi owner 之后，`platform.thread` / `platform.sync` 里其实还留着一层更隐蔽
  的 consumer-side 假设：`FAlign: PtrUInt` 和 `FAlign: UInt64`。它们在 Linux x86_64 上碰巧能过，
  但不该继续代表 Darwin / FreeBSD / Android pthread token，或 Windows `SRWLOCK` /
  `CONDITION_VARIABLE` 的真实对齐契约。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 统一继续拥有
  `TPlatformPThreadTokenAlign`、`TPlatformPThreadMutexAlign`、
  `TPlatformPThreadRwLockAlign`、`TPlatformPThreadCondVarAlign`；`windows.ffi` 继续拥有
  `TPlatformWindowsMutexAlign`、`TPlatformWindowsRwLockAlign`、
  `TPlatformWindowsCondVarAlign`。
- `platform.thread` 的 Unix consumer 现在通过 host-owned `TPlatformPThreadTokenAlign` 继承 pthread
  token 的宿主对齐，而不是继续用 `PtrUInt` 做“差不多”的占位；这让 pthread token 的 size 和
  alignment truth 都回到了同一个 ffi owner 边界。
- `platform.sync` 现在通过 `TPlatformMutexAlign` / `TPlatformRwLockAlign` /
  `TPlatformCondVarAlign` alias 消费 host-owned align carrier type，不再在 public opaque storage
  contract 里保留 `UInt64` 级别的 consumer 猜测。
- `test_platform_sync_sizes` 现在不只检查 opaque storage 足够大，还会在 Linux 主机上把 nextPas
  record 的嵌入偏移量和 native `pthread_mutex_t` / `pthread_rwlock_t` / `pthread_cond_t`
  做对照；这给了我们一条 runtime proof，证明新的 ownerization 至少没有把 Linux native ABI
  embedding 对齐打坏。
- 首轮 full verify 的真实失败不是行为回归，而是 `build/verify_local.sh` 还在要求旧的
  `4 total, 4 passed` summary；修正为 `5 total, 5 passed` 后，fresh `verify-local` 已再次通过。
- 当前证据边界仍要诚实：这批新增了 Linux runtime alignment proof 和 Win64 compile-only，但还没新增
  Darwin / FreeBSD / Android runtime 或 cross-compile 对齐证据，所以这些宿主目前仍主要由
  source-surface contract 覆盖。

## 2026-05-27 Follow-up Findings 13

- Windows helper ownerization 再往前走一层之后，`platform.thread` / `platform.sync` 里还剩的不是 raw
  WinAPI 调用，而是更隐蔽的 ABI leakage：本地 `HANDLE` 字段、`DWORD` TLS key / timeout 临时量、
  `DWORD(AError)` classifier，以及 `stdcall` thread entry thunk。
- 这轮之后，`windows.ffi` 不只拥有 raw declaration 和 lifecycle/sync helper 名称，还继续拥有
  `TPlatformWindowsThreadProc`、`PPlatformWindowsThreadState` /
  `TPlatformWindowsThreadState`、`windows_thread_state_create/join/detach`，
  以及 `windows_tls_create/destroy/set/get_platform_key`；`platform.thread` 不再在 consumer
  里重写 Windows state carrier / TLS ABI 投影。
- `platform.sync` 现在也不再自己保留 Windows `DWORD` timeout/error 中间层，而是直接消费
  `windows_error_i32_is_timeout`、`windows_condvar_timedwait_ns` 与
  `windows_wait_address_i32_timeout_ns`。这让 consumer 继续只保留 nextPas 的 timeout 映射和
  public contract，而不是继续承担 `DWORD` 细节。
- source-surface 上最直接的变化是：`platform.thread` / `platform.sync` 现在都不再出现 raw
  `HANDLE`、`DWORD`、`stdcall`、`windows_timeout_ns_to_ms` 或
  `windows_last_error_is_timeout` 这些 Windows ABI leakage token；focused gate 已把这条 contract
  冻住。
- 当前证据边界仍要诚实：这批新增了 Linux runtime proof 和 Win64 compile-only，但没有新增真实
  Windows runtime 执行证据，所以 Windows 语义目前仍主要由 source-surface contract 与 compile-only
  proof 覆盖。

## 2026-05-27 Follow-up Findings 14

- `platform.time` 前几轮虽然已经把 raw `clock_gettime` / `clock_getres`、Darwin `mach_*`、Windows
  QPC / FILETIME declaration 都收回到了 nextPas-owned ffi，但 consumer 里还残留一层更高阶的宿主拼装：
  POSIX 分支自己拿 `timespec` 再转纳秒，Darwin 分支直接点 `darwin_mach_monotonic_*`，Windows 分支直接
  点 `windows_qpc_*` / `windows_filetime_now_unix_ns`。
- 这轮之后，`linux/android/darwin/freebsd/unix.ffi` 与 `windows.ffi` 都继续拥有统一命名的高层时钟
  helper：`platform_clock_monotonic_ns_u64`、`platform_clock_realtime_ns_u64`、
  `platform_clock_monotonic_resolution_ns_u64`。`platform.time` consumer 现在只做薄 delegation，
  不再直接消费 raw timespec helper、Darwin mach monotonic helper，或 Windows QPC/FILETIME helper。
- shared `posix.ffi` 这轮新增 `platform_posix_timespec_to_ns_u64`，让所有 POSIX host ffi owner 复用同一条
  饱和 `timespec -> ns` 语义，而不是各自再复制一份秒/纳秒拼接与溢出保护逻辑。
- `test_platform_time_host_ffi_surface` 这轮也一起升级：它现在不仅要求 host ffi owner 暴露
  `platform_clock_*_ns_u64`，还禁止 `platform.time` 回退去直接消费
  `platform_clock_monotonic_now` / `platform_clock_realtime_now` /
  `platform_clock_monotonic_getres`、`darwin_mach_monotonic_*`，或 `windows_qpc_*` /
  `windows_filetime_now_unix_ns`。
- fresh focused proof 已拿到：
  `test_platform_time_host_ffi_surface`、`test_platform_time_helpers`、`test_platform_simulated_host_compile_matrix`
  通过。这说明新的 owner boundary 至少在 Linux runtime 与 Darwin/Android/FreeBSD/generic Unix
  compile-only proof 上没有被打坏。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与 fresh
  `bash build/verify_local.sh` 也都已通过；official envelope 继续保持
  `corePlatformTimeHostFfiSurfaceCheck":"pass"` 与
  `corePlatformSimulatedHostCompileMatrixCheck":"pass"`。
- 当前证据边界仍要诚实：这轮没有新增 Darwin / FreeBSD / Android / Windows runtime 证据，所以这些宿主
  仍主要由 source-surface contract 与 compile-only proof 覆盖。

## 2026-05-27 Follow-up Findings 15

- `platform.time` 这轮真正暴露出的不是 clock 算法错误，而是链接边界错误：consumer 为了复用纯
  `windows_qpc_to_ns` / `windows_qpc_resolution_ns` 换算，把 `nextpas.core.platform.windows.ffi`
  无条件拉进了 Linux 链接路径，直接导致
  `/usr/bin/ld.bfd: cannot find -lkernel32`。
- 正确分解不是把纯数学 helper 再复制回 `platform.time`，也不是继续让 Linux 链接路径碰
  `kernel32`，而是新增同 host family 的普通 helper unit
  `nextpas.core.platform.windows.math`，承载纯 QPC 数学换算。
- `windows.ffi` 继续拥有真实 Windows ABI 与 public helper 名，但把纯 QPC 数学委托给
  `windows.math`；`platform.time` 在非 Windows 目标只复用 `windows.math`，从而保持换算语义一致且不
  污染非 Windows 链接。
- 第一次把这个单元命名成 `nextpas.core.platform.windows.math.ffi` 是错误的；`test_platform_ffi_owner_boundary`
  很快就证明了这一点。修正后的规则应该是：只有拥有 `external` declaration 的 owner 单元才叫
  `*.ffi.pas`，纯 helper 保持普通 unit 命名。
- `verify_local` 的 `core-platform-time-win64-check` 这轮还额外抓到了一个条件编译语法缺口：
  `platform.time` 的 `implementation uses` 在 Windows 分支后缺少统一结尾分号。这个问题在 Linux runtime
  proof 下不会露出来，但 Win64 compile-only 会立即失败，所以这条 gate 的价值是实打实的。

## 2026-05-27 Follow-up Findings 16

- 这轮继续往下挖之后，POSIX host ffi 里剩下的显著重复已经不在 public API，而在一层很薄的
  glue：`clock_gettime` / `clock_getres` 的参数化 wrapper，以及
  `pthread_mutex_*` / `pthread_rwlock_*` / `pthread_cond_*` 的 host-independent forwarder。
- 这些 helper 虽然会触碰 raw POSIX external，但它们本身不携带宿主 capability truth；真正变化的只有
  clock id、timeout clock id、errno binding、mutex kind、condattr capability 与 Darwin mach monotonic
  truth。把这层 glue 收回 shared `nextpas.core.platform.posix.ffi`，比继续在 5 个 host ffi 内复制更符合
  “FFI owner 只保留宿主 truth，shared owner 保留 truly shared helper” 这条方向。
- 这轮之后，`nextpas.core.platform.posix.ffi` 新增了
  `platform_posix_clock_now/getres/ns_u64/resolution_ns_u64` 和
  `platform_posix_pthread_mutex_*` / `platform_posix_pthread_rwlock_*` /
  `platform_posix_pthread_condvar_*`。`linux/android/darwin/freebsd/unix.ffi` 继续暴露既有 public
  helper 名，但实现改成对 shared helper 的薄委托。
- 这也让 Darwin 的边界更清楚了：`platform_clock_realtime_ns_u64` 现在可以回到 shared POSIX helper，
  但 `darwin_mach_monotonic_ns` / `darwin_mach_monotonic_resolution_ns` 仍然留在 host owner，不会因为
  “名字看起来像 clock helper” 就被误收进 shared owner。
- `test_platform_posix_ffi_surface`、`test_platform_time_host_ffi_surface`、
  `test_platform_sync_host_ffi_surface` 这轮都升级成更强的 source-surface gate：不仅要求 symbol 存在，
  也明确要求 POSIX host ffi source 出现对 shared `platform_posix_*` helper 的委托 token。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与 fresh
  `bash build/verify_local.sh` 都已通过；official envelope 继续保持
  `corePlatformPosixFfiSurfaceCheck":"pass"`、
  `corePlatformTimeHostFfiSurfaceCheck":"pass"`、
  `corePlatformSyncHostFfiSurfaceCheck":"pass"` 与
  `corePlatformSimulatedHostCompileMatrixCheck":"pass"`。
- 当前证据边界仍要诚实：这轮新增的是 owner boundary / compile coherence / Linux runtime 行为的进一步收紧，
  不是新的 Darwin / Android / FreeBSD runtime 证据；这些宿主仍主要由 source-surface contract 与
  compile-only proof 覆盖。

## 2026-05-27 Follow-up Findings 17

- 在 clock thin wrapper、sync forwarder 和 thread glue 都下沉之后，POSIX host ffi 里剩下最显著的重复
  已经缩到 pthread attr-init skeleton：`pthread_mutexattr_init/settype/destroy + pthread_mutex_init`
  和 `pthread_condattr_init/destroy + pthread_cond_init`。
- 这层样板本身不携带宿主 truth。真正因宿主而变的仍只是 public kind 对应的宿主 mutex kind、timeout
  clock id，以及 `pthread_condattr_setclock` binding / capability。把样板收回 shared
  `nextpas.core.platform.posix.ffi`，比继续在 5 个 host ffi owner 内复制更符合当前边界模型。
- 这轮之后，`nextpas.core.platform.posix.ffi` 新增了
  `TPThreadCondAttrSetClockProc`、
  `platform_posix_pthread_mutex_init_kind` 与
  `platform_posix_pthread_condvar_init_with_clock`。`linux/android/darwin/freebsd/unix.ffi`
  继续暴露既有 public helper 名，但实现改成对这些 shared helper 的薄委托。
- 这也让 host truth 的落点更稳定了：`platform_pthread_mutex_init_platform_kind` 仍留在 host ffi owner
  承载 kind numbering truth；`platform_pthread_condattr_setclock` binding 和
  `PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` /
  `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED` 也仍然留在 host owner，不会被 shared helper 反向吞掉。
- `test_platform_posix_ffi_surface` 与 `test_platform_sync_host_ffi_surface` 这轮一起升级成更硬的
  source-surface gate：不仅要求新 shared helper 存在，也明确禁止 POSIX host ffi 继续保留 raw
  `pthread_mutexattr_*` / `pthread_condattr_*` / `pthread_cond_init` glue。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与 fresh
  `bash build/verify_local.sh` 都已通过；official envelope 继续保持
  `corePlatformPosixFfiSurfaceCheck":"pass"`、
  `corePlatformSyncHostFfiSurfaceCheck":"pass"`、
  `corePlatformSimulatedHostCompileMatrixCheck":"pass"`、
  `corePlatformSyncCheck":"pass"` 与
  `verify-local=pass`。
- 当前证据边界仍要诚实：这轮新增的是 owner boundary / compile coherence / Linux runtime 行为的继续收紧，
  不是新的 Darwin / Android / FreeBSD / Windows runtime proof；这些宿主仍主要由 source-surface
  contract 与 compile-only 证据覆盖。

## 2026-05-27 Follow-up Findings 18

- `platform.<host>.ffi` 继续同时承载常量、record、opaque carrier、size/align token 与 external
  declaration，会让四件套范式在 platform 模块里失效；正确收口是新增
  `platform.<host>.base`，把宿主定义和 ABI 载体迁出去。
- `platform.time`、`platform.sync`、`platform.thread` 不是各自拥有 foreign ABI 的 feature owner，而是
  对 Linux、Windows、macOS、Android、FreeBSD、generic Unix 的统一 platform API contract。它们应消费
  `platform.<host>.base` / `platform.<host>.ffi`，默认不再创建
  `platform.time.ffi` / `platform.sync.ffi` / `platform.thread.ffi`。
- `platform.sync` 的 public interface 尤其要保持轻：公开 opaque storage 常量和类型时只引用 host
  `.base`，implementation 再引用 `.ffi`，避免 raw external owner 被 public surface 顺手拉进来。
- `posix.base` 应只放真正跨 POSIX 宿主共享的 ABI 形状，例如 `timespec`、pthread opaque carrier、
  callback signature 与 shared align carrier；mutex kind、timeout clock id、condattr capability 这类
  host truth 必须留在各自 `linux/darwin/android/freebsd/unix.base`。
- 这轮 source-surface gate 已经升级到检查 7 个 base 文件存在性、`.ffi` 对 `.base` 的消费关系、
  FFI owner boundary，以及 simulated host compile matrix；fresh `make -C core test`、
  `make -C core examples`、`make -C core benchmarks` 与 fresh `bash build/verify_local.sh` 均通过，
  `verify-local=pass` 已拿到。
- 当前证据边界仍要诚实：这轮主要证明 owner boundary、Linux runtime 行为、Win64 compile-only 与
  multi-host simulated compile coherence；没有新增 macOS / Android / FreeBSD / Windows runtime proof。

## 2026-05-27 Follow-up Findings 19

- `platform.time.host` 无条件 `uses posix.ffi` 的问题和之前无条件拉 `windows.ffi` 类似：consumer 只是需要
  纯 `timespec -> ns` 数学，却把 POSIX external owner 带进了所有宿主编译/链接路径。
- 正确边界是新增 helper-only `nextpas.core.platform.posix.math`。它承载
  `platform_posix_timespec_to_ns_u64`、`platform_posix_timespec_add_ns` 与
  `platform_posix_timespec_remaining_ns_u64`；这些 helper 跨 POSIX 宿主共享，但本身不需要
  `clock_gettime`、`pthread`、`nanosleep` 等 external binding。
- `posix.ffi` 仍然可以消费 `posix.math`，用于 clock/deadline helper；但它不再是纯 timespec math 的
  owner。这样 `platform.time.host` 的 public timespec helper 可以只拉 `posix.math`，而 Unix host clock
  分支再拉 `posix.ffi`。
- 这条规则已经进入 source-surface gate：time host surface、posix ffi surface 和 ffi owner boundary 都会
  检查 `posix.math`，并防止 `posix.ffi` 回头定义纯 timespec math。
- 当前证据边界仍要诚实：这轮重点是 source boundary、Linux runtime focused tests 和 multi-host simulated
  compile matrix；真实 Windows runtime link evidence 仍未新增。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与 fresh
  `bash build/verify_local.sh` 都已通过；official envelope 继续给出 `verify-local=pass` 与
  `human-summary=local verification passed`。
- 新的长期落地规则：FPC 源码和平台单元可以作为系统 ABI 声明依据，把系统 API、常量、record layout、
  调用约定、外部库名和符号名核对后搬进 nextPas 自己的 `platform.<host>.base/ffi`；必要时可做
  test-only/reference-only 对照工具。但 platform 生产代码不能依赖或 `uses` FPC 平台单元。后续扩充
  platform ffi 时应按 host owner 扩，不按 feature 随手分裂。
- 扩平台 API 的顺序也明确了：host `base/ffi` 先尽量完整承载系统 ABI，再由通用 platform 子模块做统一
  抽象。也就是说，ffi 层可以做厚，但 public contract 仍应由 `platform.time/sync/thread/...`
  这类子模块整理成 nextPas 稳定语义。
- Platform Host ABI Wave 1 已落为低风险 raw host ABI inventory：process id、`timeval`、mmap、
  dynamic loader，以及 Windows process id / dynamic library / virtual memory basics。它不新增
  `platform.process`、`platform.memory` 或 dynamic-library public contract。
- `stat/open/fcntl deferred` 是本轮明确延期边界：file/stat 的 record layout、flag family、large-file
  suffix 与 32/64-bit 差异风险高，应作为下一波单独取证和 gate。
- POSIX `MAP_FAILED` 保留 signed ABI token `PLATFORM_POSIX_MAP_FAILED = PtrInt(-1)`，指针比较使用
  unsigned token `PLATFORM_POSIX_MAP_FAILED_PTR = High(PtrUInt)`，避免 FPC 的 signed pointer
  comparison warning。
- `build/verify_local.sh` 已纳入 Wave 1 official route：required path、focused check、cleanup 和 final
  envelope token `corePlatformHostAbiWave1Check` 必须同步维护。
- Wave 1 已在 feature commit `865ae8f` 上 rebase 到 `main@52c2e2d`，无冲突；合并前重新跑过 focused
  gate、`make -C core test`、`make -C core examples`、`make -C core benchmarks`、`git diff --check`
  与 `bash build/verify_local.sh`，final envelope 继续包含
  `corePlatformHostAbiWave1Check":"pass"`。
- Wave 1 最终以 fast-forward 方式合入 `main@54b19bd`；post-merge focused gate 通过 3/3，
  `git diff --check` 通过，`bash build/verify_local.sh` 输出 `verify-local=pass` /
  `human-summary=local verification passed`，final envelope 继续包含
  `corePlatformHostAbiWave1Check":"pass"`。
- 收口后已删除临时 worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave1` 与分支
  `codex/platform-host-abi-wave1`；后续 platform host ABI wave 应从 latest `main` 重新开隔离 worktree。
- Platform Host ABI Wave 2 已从 latest `main@4643daa` 开始，worktree 为
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave2-files`，
  branch 为 `codex/platform-host-abi-wave2-files`。本轮目标是 file ABI raw inventory，
  不创建 `platform.file` public contract。
- Wave 2 的风险边界先定为 `open` / `close` / `fcntl` 与基础 flag/token；`stat` record layout、
  large-file suffix、32/64-bit policy 和 Windows file handle 语义需要先取证，不能为了“完整”强行混入。
- runtime 单元测试的判断口径也已固定：只测 `platform.time`、`platform.sync`、`platform.thread`
  等通用抽象子模块的 public contract；raw `clock_gettime`、`pthread_*`、`futex`、`gettid` 等系统
  API 本身不作为 nextPas 单元测试目标。
- `platform-ffi-source-evidence-index` 已进入 official verification surface：fresh focused gate
  `test_platform_ffi_source_evidence_index` 通过 2/2，fresh `make -C core test`、`make -C core examples`、
  `make -C core benchmarks` 与 fresh `bash build/verify_local.sh` 均通过；final envelope 包含
  `corePlatformFfiSourceEvidenceIndexCheck":"pass"`，并输出 `verify-local=pass` /
  `human-summary=local verification passed`。

## 2026-05-27 Follow-up Findings 20

- FPC Linux 与 FreeBSD `pthread.inc` 明确声明 `pthread_mutex_timedlock`；Linux 这份声明也覆盖
  Android 条件分支，因此 Linux / Android / FreeBSD 可以把该 ABI 搬入 nextPas-owned
  `platform.posix.ffi` raw declaration 与 shared thin helper。
- FPC Darwin `pthread.inc` 没有 `pthread_mutex_timedlock` 声明，generic Unix 也没有足够宿主证据；
  这类 host owner 应显式暴露 unsupported / unknown capability，而不是让 consumer 直接调用一个可能
  不存在的 pthread symbol。
- `pthread_rwlock_timedrdlock` / `pthread_rwlock_timedwrlock` 这轮不应被强行搬入通用 POSIX surface：
  当前 FPC 搜索只在 `netwlibc` 找到它们，不足以作为 Linux/FreeBSD/Darwin/Android host pthread
  owner 的依据。
- 因此新增的 owner 模型是：
  `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED` 放在各 host `.base`；
  `posix.ffi` 只在 Linux / Android / FreeBSD target path 声明 raw `pthread_mutex_timedlock` 与
  `platform_posix_pthread_mutex_timedlock_abs`；
  host `.ffi` 对支持宿主委托 shared helper，对 Darwin / generic Unix 返回
  `PLATFORM_POSIX_ENOTSUP`。
- 这批没有新增 `platform.sync` public API，也不新增 raw pthread runtime 单测；证据面是
  source-surface gate、FPC 源码取证和 simulated host compile matrix。
- fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 与 fresh
  `bash build/verify_local.sh` 均已通过；official envelope 给出 `verify-local=pass` 与
  `human-summary=local verification passed`。当前结论仍是 ABI reference surface 已收口，不等价于
  新增 raw pthread runtime behavior contract。

## 2026-05-27 Follow-up Findings 21

- `codex/platform-time-integration @ 02be065` 已不是可合并的活跃平台分支；相对当前主线它只剩
  1 个独有旧提交，但整条 diff 会删除/回滚大量已成熟的 platform host-owner base/ffi、source-surface
  gate、example 和 benchmark。
- 旧分支里的 platform time hardening、per-project Makefile、platform time example/benchmark、
  no-FPC 边界和 verification 记录，都已经被当前主线以更好分层吸收。
- 旧分支中仍值得保留的小颗粒是 `nextpas.core.text` public contract 边界：empty split field、
  empty delimiter，以及 empty substring index。移植这些测试后，`TextIndexOf('hello', '')`
  暴露出真实缺口，修复为返回 0。
- `demo_stopwatch` 和旧 L1 `bench_platform_time` 不应作为 platform closeout 合入；platform L0 示例/
  基准继续使用 `core/examples/nextpas.core.platform.time/platform_time_clock` 与
  `core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock`。

## 2026-05-27 Follow-up Findings 22

- platform 下一轮不能继续凭“感觉”扩 `time` 或 `sync`，必须先以 `task_plan.md` 的 Phase 19 为入口：
  建立 ABI owner audit 与 gap matrix，再选择实现切片。
- 当前架构主线已经明确：host `base/ffi` 承载系统 ABI truth，`platform.time/sync/thread` 承载
  nextPas 的跨宿主稳定 contract；feature-specific `platform.thread.ffi` 仍不是默认方案。
- 下一轮优先 `platform.thread`，因为它横跨 POSIX thread、TLS、sleep/yield、native thread id、CPU
  count、Windows thread state 和 Windows TLS key，最能暴露 raw ABI type / scalar / calling convention
  是否还泄漏到 consumer。
- 证据口径必须继续诚实：Linux runtime、Win64 compile-only、simulated Darwin/Android/FreeBSD/Unix
  compile-only 是三类不同证据；不能把 compile-only 或 simulated host selection 包装成真实 runtime 支持。
- runtime 单元测试仍只覆盖 `platform.thread` / `platform.sync` / `platform.time` public contract；raw
  OS API 的正确性依赖 FPC 源码取证、host-owned declarations、source-surface guard 与 compile gate。

## 2026-05-27 Follow-up Findings 23

- `platform.thread` 的 POSIX state carrier、allocation、zero-init、join/detach release 和 pthread token
  storage offset 已从 unified consumer 收回 host owner：
  `linux/android/darwin/freebsd/unix.base` 暴露 `PPlatformPThreadState` / `TPlatformPThreadState`，
  对应 `.ffi` 暴露 `platform_pthread_state_create/join/detach`。
- shared `posix.ffi` 只新增不携带宿主 truth 的 pthread token storage glue：
  `platform_posix_pthread_state_create/join/detach`。真正的 state 生命周期和 nil guard 仍由各 host
  `.ffi` 包装。
- `platform.thread` 现在只把 host state pointer 当作 `TPlatformThreadHandle` public handle，不再声明
  `PPosixThreadState` / `TPosixThreadState`，也不再执行 `New` / `Dispose` 或
  `@State^.Thread[0]` 这类 ABI storage offset 操作。
- fresh focused gates、`make -C core test`、`make -C core examples`、`make -C core benchmarks`
  与 `bash build/verify_local.sh` 均已通过；official envelope 给出 `verify-local=pass` 与
  `human-summary=local verification passed`。
- 证据边界保持不变：Linux thread behavior 是真实 runtime proof；Win64、Darwin、Android、FreeBSD
  和 generic Unix 仍主要是 source-surface / compile-only proof，不能宣称新增真实 runtime 覆盖。

## 2026-05-27 Follow-up Findings 24

- 当前 platform host base/ffi 已经比较丰富，但缺少一份“覆盖面与已知缺口”的正式矩阵；没有这份矩阵，
  后续继续从 FPC 源码搬 ABI 时容易重复争论哪些 token 属于 host base、哪些 helper 属于 host ffi，
  以及哪些 unsupported 是刻意决策。
- 这轮正确切片不是继续扩 `platform.time` / `platform.sync` / `platform.thread` public API，而是新增
  `platform-host-ffi-gap-matrix` 文档和 source-surface guard，把 Linux / Android / Darwin /
  FreeBSD / generic Unix / Windows 的 host rows、domain coverage 与 known gaps 冻结下来。
- 当前需要明确记录的已知差异包括：
  Darwin `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0`、Darwin
  `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0`、generic Unix native thread id fallback 到
  `platform_posix_thread_self_token_u64`、generic Unix `_SC_NPROCESSORS_ONLN = -1`、generic Unix
  mutex timedlock unsupported，以及 Windows 完全走 kernel32 / SRW / CONDITION_VARIABLE /
  QPC / FILETIME / WaitOnAddress 路径而不是 POSIX。
- 这个 guard 的证据边界必须诚实：它证明 source ownership、文档同步和 compile-surface 可回归，
  不等价于真实 macOS / Android / FreeBSD / Windows runtime proof；raw 系统 API 本身仍不进入
  nextPas runtime 单元测试。

## 2026-05-27 Follow-up Findings 25

- Wave 2 的正确落点是 host-owned file ABI raw inventory，而不是新建 `platform.file` public
  contract 或 `platform.file.ffi`。`platform.time`、`platform.sync`、`platform.thread` 仍是统一
  public contract 的范式；file 抽象要等 semantic contract 单独设计。
- POSIX shared owner 只承载跨 Linux、Android、Darwin、FreeBSD、generic Unix 一致的薄层：
  `TPlatformFileDescriptor`、`TPlatformFileModeArg`、`PLATFORM_FILE_MODE_DEFAULT`、
  `open`、`close`、`fcntl` 与 `platform_posix_*` helpers。host-specific open/fcntl tokens 仍放在各
  host `.base`。
- Linux/Android 的 `O_CLOEXEC` 值可作为 host capability token 落入各自 `.base`；Darwin、FreeBSD
  和 generic Unix 本轮只落已经纳入 source-surface gate 的基础 flags，避免把未完成取证的 capability
  token 混进通用面。
- Windows file entrypoints 使用既有 `HANDLE` / `CloseHandle` ownership：`CreateFileA/W`、
  `ReadFile`、`WriteFile` 属于 `windows.ffi`，`windows_file_close_handle` 委托
  `windows_thread_close_handle`，避免重复声明 `CloseHandle` owner。
- `stat/fstat/lstat` 继续延期是架构选择，不是遗漏：record layout、large-file suffix、
  32/64-bit policy 和 Windows `GetFileInformationByHandle`/POSIX `stat` 的语义差异需要下一波单独
  evidence 和 gate。
- 本轮验证口径保持 raw ABI 边界：source-surface test、文档事实、compile-only gates 和
  `verify_local` route truth；不为 `open`、`fcntl`、`CreateFile*` 等 raw OS API 添加 runtime unit
  tests。

## 2026-05-27 Follow-up Findings 26

- Wave 2 rebase 到 `main@5c0f03d` 时无冲突；并行 collections 文档提交没有覆盖 platform host
  `base/ffi` owner，也没有改变 Wave 2 file ABI 分层。
- Rebase 后 fresh verification 继续通过，说明 `build/verify_local.sh` 的
  `corePlatformHostAbiWave2FilesCheck` 与既有 `corePlatformHostAbiWave1Check`、host gap matrix、
  source evidence index 和 simulated-host compile matrix 可以共存。
- 当前剩余集成风险主要在主 checkout 合并窗口，而不是实现本身：合并前仍要确认主 checkout
  干净，避免把其他 worktree 或同事 WIP 混进 platform 收口。

## 2026-05-27 Follow-up Findings 27

- Wave 3 的正确切片是 file status raw ABI evidence，不是 `platform.file` public contract。
  POSIX `stat` / `fstat` / `lstat` 与 Windows `GetFileAttributesEx*` /
  `GetFileInformationByHandle` 都属于 host-owned L0 ABI inventory，未来是否抽象成统一文件 API
  要单独设计。
- `stat` 的风险高于 Wave 2 的 `open` / `fcntl`：record layout、large-file suffix、time field
  形态、device/inode width 和 32/64-bit policy 都可能跨 Linux / Android / Darwin / FreeBSD /
  generic Unix 分裂。因此本轮必须先做 FPC source evidence，再决定只落函数 family、落 host-specific
  record，还是继续延期部分 host。
- Windows 不能被伪装成 POSIX `stat`。如果本轮落 Windows 文件状态 ABI，应使用 Windows
  base/ffi owner 承载 `WIN32_FILE_ATTRIBUTE_DATA`、`BY_HANDLE_FILE_INFORMATION`、
  `GetFileAttributesExA/W`、`GetFileInformationByHandle` 这类 kernel32 family。
- raw 文件状态 ABI 不进入 runtime 单元测试。验证口径仍是 source-surface gate、文档事实、
  simulated host compile matrix、Win64 compile-only gate 与 `verify_local` route truth。

## 2026-05-27 Follow-up Findings 28

- FPC `rtl/unix/oscdeclh.inc` 证明 `stat` family 的外部符号名不是简单全平台一致：
  generic Unix 用 `stat` / `lstat` / `fstat` 加 `suffix64bit`，Darwin x86/x86_64 new iostructs 用
  `stat$INODE64` / `lstat$INODE64` / `fstat$INODE64`。
- FPC Linux libc 路径在 `rtl/linux/osmacro.inc` 证明 `FpStat` / `FpLstat` / `FpFstat` 走
  `__xstat` / `__lxstat` / `__fxstat` 并传 `_STAT_VER`，而 `_STAT_VER` 在
  `rtl/linux/ostypes.inc` 按 CPU family 分裂：x86_64 是 1，aarch64/riscv64 是 0，非这些 CPU 还有
  old/kernel/SVR4/Linux 版本常量。不能把 Linux `stat` family 当作一个普通 `stat` external。
- FPC Linux `stat.inc` 证明 record layout 按架构分裂：x86_64、aarch64、riscv64 等字段顺序和类型
  都不完全一样；BSD `rtl/bsd/ostypes.inc` 还按 Darwin/FreeBSD/OpenBSD/NetBSD 等分支改变字段顺序、
  birthtime 和 padding。
- 因此本轮 POSIX 侧不能新增 shared `stat` record 到 `posix.base`，也不能在
  `posix.ffi` 里声明一个无条件 `stat/lstat/fstat`。安全落点应是 host-specific evidence、host
  capability token、或把 record/import 留在 gap matrix，直到每个 target 的 ABI shape 被逐一证明。
- Windows file status ABI 证据更稳定：FPC `rtl/win/wininc/struct.inc` 提供
  `BY_HANDLE_FILE_INFORMATION` 与 `WIN32_FILE_ATTRIBUTE_DATA` record；`ascfun.inc` /
  `unifun.inc` / `func.inc` 提供 `GetFileAttributesExA/W` 和
  `GetFileInformationByHandle`；`defines.inc` 提供 `FILE_ATTRIBUTE_*` 常量。Wave 3 可以优先把这组
  Windows base/ffi owner 补全。

## 2026-05-27 Follow-up Findings 29

- Wave 3 source-surface gate 不能只搜字符串；本轮增加了 ABI size guard，直接编译检查
  `TPlatformLinuxStatxTimestamp = 16`、`TPlatformLinuxStatx = 256`、
  `GET_FILEEX_INFO_LEVELS = 4`、`WIN32_FILE_ATTRIBUTE_DATA = 36`、
  `BY_HANDLE_FILE_INFORMATION = 52`。这不调用 raw OS API，但能守住 nextPas-owned record layout。
- `PLATFORM_LINUX_AT_SYMLINK_NOFOLLOW` 应贴近 FPC/kernel token `AT_SYMLINK_NOFOLLOW`，不要自行拆成
  `NO_FOLLOW`。platform host base/ffi 里的 raw ABI token 命名应优先保持 source evidence
  可追溯性。
- `platform.time` / `platform.sync` / `platform.thread` 不应消费 Wave 3 file-status raw ABI；本轮
  focused gate 已显式检查这些统一抽象子模块中不存在 `linux_statx`、`GetFileAttributesEx*`、
  `GetFileInformationByHandle` 消费痕迹。

## 2026-05-27 Follow-up Findings 30

- Wave 3 的 full verification 已完成：`make -C core test`、`make -C core examples`、
  `make -C core benchmarks` 均通过，fresh `bash build/verify_local.sh` 输出
  `verify-local=pass` 与 `human-summary=local verification passed`，final envelope 包含
  `corePlatformHostAbiWave3StatCheck":"pass"`。
- 本轮验证边界仍保持 L0 raw ABI 口径：Linux `statx` 与 Windows file status declaration 通过
  FPC source evidence、source-surface guard、ABI size gate、compile-only gate 和 official route
  truth 固定；没有把 raw 系统 API 当成 nextPas runtime unit test 目标。
- 收口前剩余风险在集成窗口：需要 rebase 最新 `main` 并确认主 checkout 没有会被覆盖的同事/用户
  WIP，再 fast-forward 或 merge。合并后必须重跑 focused Wave 3 gate、`git diff --check` 和
  official verify，确认 route truth 在主线仍成立。

## 2026-05-27 Follow-up Findings 31

- Rebase 后 full `make -C core test` 暴露了一个与 Wave 3 无直接关系但会污染收口可信度的并发缺陷：
  `tests/nextpas.core.thread/test_thread` 偶发卡在 `TestPoolSubmitAll` 的 `TThreadPool.Shutdown`。
  LLDB 证据显示主线程在 `platform_thread_join`，一个 worker 仍在 `TCondVar.Wait` /
  `pthread_cond_wait`。
- 根因是高层 `nextpas.core.sync.condvar.TCondVar` 使用内部 mutex 桥接外部 `IMutex`：`Wait` 先锁内部
  mutex，再释放 caller mutex，再进入 `pthread_cond_wait`。signal/broadcast 如果落在释放 caller mutex
  与实际等待之间，会被 POSIX condvar 丢掉，进而让 thread pool worker 永久睡眠。
- 修复方向应保持在 nextPas 抽象层：`TCondVar` 改成 monotonic sequence + `platform_wait_address32` /
  `platform_wake_address_*`，不直接依赖 FPC platform units，也不把 raw pthread ABI 泄漏到 `nextpas.core.sync`。
- 新增的确定性回归比重跑 flaky 更有价值：测试 mutex 在 `Release` 中调用 `Signal`，旧实现稳定失败，
  新实现把 already-changed sequence 映射为成功 wake 后通过。这条测试同时覆盖 Linux futex 与 forced
  POSIX fallback route。

## 2026-05-27 Follow-up Findings 32

- Condvar 修复后首轮 fresh `bash build/verify_local.sh` 的失败不是实现回归，而是 official route 的
  summary 断言漂移：`core-sync-posix-fallback-check` 已真实运行
  `--- nextpas.core.sync: 11 total, 11 passed, 0 failed ---`，但脚本仍要求旧的
  `10 total, 10 passed, 0 failed`。
- `build/verify_local.sh` 应跟随 public sync test contract 更新为 11 项；这个 gate 的价值是防止
  forced POSIX fallback 被悄悄跳过或测试数量回退，而不是冻结过期的测试总数。
- 更新 summary 后的 official verification 已通过，final envelope 同时保留
  `corePlatformHostAbiWave3StatCheck":"pass"` 与 `coreSyncPosixFallbackCheck":"pass"`。这说明本轮
  Wave 3 raw ABI route truth 和 condvar fallback route truth 都已经回到同一个官方收口面。

## 2026-05-27 Follow-up Findings 33

- Branch `codex/platform-host-abi-wave3-stat` 已 rebase 到最新本地 `main@c09bc58`，没有冲突，主
  checkout 当前干净，`main` 是 feature branch 的祖先。
- Rebase 后 fresh focused checks 通过：`git diff --check`、`test_sync`
  `11 total, 11 passed, 0 failed`、`test_platform_host_abi_wave3_stat`
  `5 total, 5 passed, 0 failed`。
- Rebase 后 fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`，final envelope 同时包含
  `corePlatformHostAbiWave3StatCheck":"pass"` 与 `coreSyncPosixFallbackCheck":"pass"`。当前可进入
  fast-forward merge、post-merge verification 与 worktree cleanup。

## 2026-05-27 Follow-up Findings 34

- Platform Host ABI Wave 3 已 fast-forward merge 到 `main@ed25455`，随后主线又被 unrelated
  collections docs 推进到 `main@d2e5b52`；Wave 3 三笔提交仍是当前 `main` 的祖先。
- Post-merge focused gates 通过：`git diff --check`、`test_platform_host_abi_wave3_stat`
  `5 total, 5 passed, 0 failed`、`test_sync` `11 total, 11 passed, 0 failed`。
- Post-merge official verification 通过：fresh `bash build/verify_local.sh` 输出
  `verify-local=pass` 与 `human-summary=local verification passed`，final envelope 继续包含
  `corePlatformHostAbiWave3StatCheck":"pass"` 与 `coreSyncPosixFallbackCheck":"pass"`。
- 临时 worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave3-stat` 已删除，分支
  `codex/platform-host-abi-wave3-stat` 已删除，`git worktree prune` 已执行；当前剩余并行 worktree 是
  `collections-refactor` 与 `sema-no-matching-overload`。

## 2026-05-28 Follow-up Findings 35

- Platform Host ABI Wave 4 的正确切片是 directory/path raw ABI inventory，不是 `platform.file`
  或 `platform.path` public contract。后续统一文件/路径 API 需要另起设计，不应在本轮 raw ABI
  import 中偷渡。
- POSIX 侧取证落点清楚：FPC `rtl/unix/oscdeclh.inc` 以 libc external 方式声明
  `chdir`、`mkdir`、`unlink`、`rmdir`、`rename`、`access`；`rtl/linux/ossysc.inc` 与
  `rtl/bsd/ossysc.inc` 还提供 `Fpgetcwd` 等 syscall wrapper evidence。因此 shared POSIX
  `posix.ffi` 可以承载这些 external binding 和 `platform_posix_*` thin helpers，host `.ffi`
  再暴露 `platform_path_*` / `platform_directory_*` helper。
- POSIX access mode token `F_OK` / `X_OK` / `W_OK` / `R_OK` 属于 host base fact。当前 Linux、
  Android、Darwin、FreeBSD 与 generic Unix 的基础值均可按 FPC/POSIX evidence 收进各自 `.base`；
  不能把它们塞进 feature-specific `platform.file.ffi`。
- Windows 侧取证来自 kernel32 family：FPC `rtl/win/wininc/ascfun.inc`、`unifun.inc`、
  `ascdef.inc`、`unidef.inc` 与 `rtl/win/sysos.inc` 覆盖 `CreateDirectoryA/W`、
  `RemoveDirectoryA/W`、`DeleteFileA/W`、`MoveFileA/W`、`GetCurrentDirectoryA/W`、
  `SetCurrentDirectoryA/W`、`GetFullPathNameA/W`。这些 entrypoint 与 helper 应归
  `windows.base` / `windows.ffi`。
- raw directory/path ABI 仍不做 runtime unit test。本轮测试目标是 source-surface、文档事实、
  official route truth、ABI owner 边界和 compile-only coherence。

## 2026-05-28 Follow-up Findings 36

- Wave 4 implementation 已把 directory/path ABI 放进 host-owned shape：POSIX externals 与
  `platform_posix_*` helper 位于 `posix.ffi`；Linux、Android、Darwin、FreeBSD、generic Unix
  `.ffi` 只暴露 host owner helper 并委托 POSIX；Windows A/W entrypoints 和 helper 位于
  `windows.ffi`，string pointer aliases 位于 `windows.base`。
- `build/verify_local.sh` 的 Wave 4 接入应保持小而可审查：required path、focused source-surface
  check、final envelope token 足够。一次机械插入曾把脚本扩大成异常大 diff，已修复为
  `27 1` 的最小 diff 并通过 `sh -n build/verify_local.sh`。
- Pre-merge verification 证据完整：Wave 4 focused gate `5 total, 5 passed, 0 failed`；
  simulated host compile matrix 全部 `status=pass`；`make -C core test` / `examples` /
  `benchmarks` 通过；fresh `bash build/verify_local.sh` 输出 `verify-local=pass`、
  `human-summary=local verification passed`，final envelope 包含
  `corePlatformHostAbiWave4PathsCheck":"pass"`。
- 本轮仍未新增真实 Windows/macOS runtime execution evidence；这是当前硬件/环境边界，不应被误报为
  已有跨平台 runtime 证明。当前跨平台保证来自 source evidence、Win64 compile-only smoke 与
  simulated host compile matrix。

## 2026-05-28 Follow-up Findings 37

- Wave 4 feature branch 初始 commit 为 `e852718`；集成窗口内本地 `main` 前进到
  `ff141a2`，本分支已再次 rebase 到最新 main 且无冲突。
- 最新 rebase 后 fresh checks 通过：`git diff --check main..HEAD`、focused Wave 4 gate
  `5 total, 5 passed, 0 failed`、fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`，final envelope 继续包含
  `corePlatformHostAbiWave4PathsCheck":"pass"`。
- 合并应 fast-forward 进行；合并后要重新跑 focused gate 与 official verification，确保主线上的
  route truth 仍成立。

## 2026-05-28 Follow-up Findings 38

- Wave 4 已 fast-forward merge 到主线，commit 为
  `71c7a62 platform: add host path ABI wave 4`。合并后又有 unrelated collections commit 推进
  main 到 `0768e2b`，但 `71c7a62` 仍是当前 main 祖先。
- Post-merge verification 在干净 detached worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave4-postmerge-verify`
  上执行，避免主 checkout 中 collections 工作影响证据。`git diff --check` 通过，focused Wave 4
  gate 仍为 `5 total, 5 passed, 0 failed`，fresh `bash build/verify_local.sh` 输出
  `verify-local=pass` 与 `human-summary=local verification passed`，final envelope 继续包含
  `corePlatformHostAbiWave4PathsCheck":"pass"`。
- 临时 worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave4-paths` 与
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave4-postmerge-verify`
  已删除，分支 `codex/platform-host-abi-wave4-paths` 已删除，`git worktree prune` 已执行。

## 2026-06-03 C5-K0 Findings 1

- 当前 `main@32a555d1` 的 compiler 路径没有 dirty 变更；dirty 范围集中在 `.claude/`、`.worktrees/`、`core/` 与 `core-tui-migration`，本轮必须 path-limited。
- 目标树显示 C5 正在推进 address/value 模型；本轮不是新功能扩张，而是修 C5 主线后的 LLVM verifier 红点。
- 用户报告的稳定现象：`test_obj_compose.ll` 中 `TRect.Create` 期望 `(ptr, i64, i64)`，但 `P.GetX/P.GetY` 的 `i64` 结果被按 `ptr` argument 传入。`test_nested_method` 仍正常，因此优先调查 constructor call lowering / arg classification。

## 2026-06-03 C5-K0 Findings 2

- 复现命令：stage0 `nextpas build examples/smoke/test_obj_compose.pas --target linux-x86_64 --toolchain-binding linux-x86_64-to-linux-x86_64-llvm`。
- 失败位置稳定在 `examples/smoke/.nextpas/cache/backend/linux-x86_64/test_obj_compose.ll:24`：
  `call i64 @TRect.Create(ptr %v11, ptr %v15, ptr %v17)`，其中 `%v15/%v17` 是
  `call i64 @TPoint.GetX/GetY(...)` 的结果。
- `TRect.Create` 定义是 `define i64 @TRect.Create(ptr %self, i64 %AW, i64 %AH)`；
  同类工作样例 `test_nested_method` 的 `A.AddTo(B.Get)` 正确发出
  `call i64 @TCalc.AddTo(ptr %self, i64 %nestedResult)`。

## 2026-06-03 C5-K0 Findings 3

- RED 已加入 `compiler/tests/test_semantic_hir_expr_producer.pas`：
  `TestConstructorNestedMethodIntegerArgs` 从源码生成 LLVM 文本，定位
  `call i64 @TRect.Create(...)`，要求非 self 参数不出现 `, ptr `，并至少出现
  `, i64 `。
- RED 运行证据：focused test 编译成功后退出 `148`，对应 constructor call 行仍含
  `, ptr ` argument。
- 代码坐标：`np_hir_builder.pas:4672` 的 `ProcessClassNew` 用整个 nested arg blob
  判定 pointer，其中 `var P` 这类 receiver 行会污染后续 `call/vcall` 结果；这是字符串暗号导致的过宽匹配点。

## 2026-06-03 C5-K0 Findings 4

- GREEN 修复：builder 新增 `ParseIntBlobTyped(const ABlob; out ATypeId)`，
  `ProcessClassNew` 不再对 constructor argument blob 做全文/首行 pointer 判定，
  而是直接消费 blob lowering 的最终 `TypeId`。
- 这样避免 `var P` receiver 出现在 nested method-call blob 前部时污染最终参数类型；
  integer nested method-call 会保持 integer，pointer-return ordinary member call
  也继续保留 `ptr`。
- GREEN focused：`test_semantic_hir_expr_producer` 重新编译运行后退出 `0`，并新增
  pointer-return constructor arg regression 覆盖。

## 2026-06-04 branch cleanup tranche 2

- `codex/platform-host-ffi-wave15-helper-names` 不能按“它有 focused tests 就该合”处理，因为
  current `main` 的平台 FFI 边界已经前进了：
  - `core/docs/platform-host-ffi-gap-matrix.md` 明写 “Wave 15 corrects the FFI boundary”
    且 “earlier Wave 13/14 helper-name direction is superseded”
  - 当前 host/shared `.ffi` 的规则是 raw `external` declaration only，不再承载 helper /
    wrapper / projection 逻辑
  - 该 branch 的 `b7df674f` 反而会把 host helper 名字重新塞回 `.ffi` units，因此现在属于
    过时实现，不是漏合资产
- `worktree-json-yaml-coverage` 的 commit message 写着“full API coverage”，但用 current
  `main` 重新比对后不能直接相信旧结论：
  - `test_json_builder.lpr` 与 `test_yaml_block.lpr` 的大部分覆盖当前主线已经具备
  - 相对 current `main` 的唯一净差异反而是 branch 少了
    `TestBuildOwnsQuotedSpecialStrings` 这一条 YAML builder 覆盖
  - 因此这条 branch 现在不是“主线缺覆盖”，而是“旧分支已经落后主线”
- `codex/platform-pty-integration` 剩余的两个独有提交必须拆开看：
  - `1cf558e2` 只是把 `TestSplitEdgeCases2` 改名成 `TestSplitEdgeCasesP4`，行为和覆盖都没增加；
    current `main` 已通过 `2` 后缀解决命名冲突，不值得再摘
  - `231ad0a6` 给 `test_marshal` / `test_template` / `test_validation` 补了标准 `Makefile`，
    这三处 current `main` 仍然缺失，且符合用户一贯偏好的 `Makefile` 入口
- 对 integration queue 的正确处理不是重建新分支，而是 refresh 现有
  `codex/worktree-triage-integration-20260604`：
  - merge current `main` 进入 queue 后，`main...queue` 变成 `0 7`
  - 这说明 queue 现在是“包含 current `main` 的主线保全分支”，后续如果 root `main`
    变干净，可以从这个锚点继续安全落地主线
- 删除 branch ref 的最终理由必须区分清楚：
  - `codex/platform-host-ffi-wave15-helper-names`：架构方向已过时，主动丢弃
  - `worktree-json-yaml-coverage`：已被 current `main` 吸收并部分超越，删除噪音 ref
  - `codex/platform-pty-integration`：真实保留值 `231ad0a6` 已转存到 integration queue，
    其余独有提交无净价值

## 2026-06-04 C5 var-param validation findings 1

- 当前 `llvm_var_param` 的表面红点必须区分“源码行为”与“bootstrap 编译器年龄”。
- fresh focused tests 与 synthetic builder probe 同时为绿时，直接继续修生产代码是错误方向；先排除 stale stage0 才是最低成本、最高确定性的下一步。
- 本轮一开始的 `EXIT:102` 不是当前源码的直接证据，因为执行它的是 rebuild 之前的
  `.sisyphus/tmp/stage0-bootstrap/nextpas`。

## 2026-06-04 C5 var-param validation findings 2

- producer 侧没有缺 contract：
  - `debug_var_param_call_expr_producer` 已明确证明
    `Helper.ClearNode(Node)` statement call 挂上了 `ExprId`
  - root expr 是 `shekCall`
  - `LiteralStr='TNodeHelper.ClearNode'`
  - `Op='pr'`
  - receiver child 是 address-backed class receiver
  - arg child 是 `shekSymbolAddress` for `Node`
- 因此普通成员 `var` 参数 statement call 并不是“sema 没迁移到 structured call”。

## 2026-06-04 C5 var-param validation findings 3

- builder 侧当前源码也没有缺普通成员 `var` 参数 lowering：
  - `LowerCallExpr` 已支持 `'r'` 参数，直接走 `LowerExprAddress`
  - `ProcessCallRuntime` 在 `ANode.ExprId > 0` 时会优先 `LowerExprValue(ANode.ExprId, ...)`
    并整条提前退出，不再落回 blob path
  - synthetic probe `debug_builder_member_var_param` 证明 ordinary member call 的 by-ref arg
    来源是 `hikAlloca`，不是 `hikLoad`
- 因此“当前源码仍会把 ordinary member `var` 参数按值传入”这个判断已被当前工作树证伪。

## 2026-06-04 C5 var-param validation findings 4

- 旧 bootstrap 二进制确实会把 `llvm_var_param` 编坏：
  - old IR 仍有
    `call i64 @TNodeHelper.ClearNode(ptr %v58, ptr %v59)`
  - `%v59` 来源是 `load ptr, ptr %v2`
  - 所以 old executable 触发 `Halt(102)`
- fresh rebuild 之后同一 smoke 变绿：
  - `bash scripts/rebuild-compiler.sh` 输出 `45315 lines compiled`
  - fresh `llvm_var_param` executable 退出 `7`
  - fresh IR 改成
    `call i64 @TNodeHelper.ClearNode(ptr %v58, ptr %v2)`
- 结论：这轮最重要的真实发现不是新的编译器修复点，而是“旧 `EXIT:102` 已经过期，属于 stale stage0 假红点”。

## 2026-06-04 C5 var-param validation findings 5

- 这也说明当前 `C5` closeout 不能只看源码 diff 或 focused tests；必须至少做一次 fresh compiler rebuild，才能把 structured-call 变更真正带入 stage0 运行面。
- 对接下来通往 `C6/C8` 的工作，最优策略不是继续围绕 `llvm_var_param` 做额外补丁，而是：
  - 清理这轮临时 debug harness
  - 固化 `llvm_var_param` 已绿的验证事实
  - 用 fresh gate 去找下一个真实 blocker

## 2026-06-04 compiler truth absorb live verification and recategorization

- `codex/compiler-truth-integration-20260604-main0915` 的 live 状态已经确认不是待处理 worktree，而是已完成安全归档的历史锚点：
  - local tag：`archive/compiler-truth-integration-20260604-main0915`
  - branch 与 worktree 都已删除
- `codex/compiler-truth-absorb-20260604` 当前是唯一带 fresh 编译器 gate 证据的升级候选线：
  - fresh `make rebuild-compiler` 输出 `48332 lines compiled`
  - fresh `bash build/verify_local.sh` 已越过 compiler/HIR/stage0/platform/sync 等 gate
  - 当前 full gate 真失败点是：
    - `failure-kind=rtl-sysutils-run-failed`
    - 文件：`rtl/core/sysutils/np_sysutils_test.pas`
    - 7 条失败：
      - `ExtractFileDir trailing slash`
      - `Include delimiter empty`
      - `FileExists existing file`
      - `ExpandFileName starts with /`
      - `Now returns reasonable date after 2009`
      - `ExtractFileDir single-level path`
      - `ExtractFileDir root`
- 因而 absorb 线当前没有暴露新的 compiler/stage0/toolchain regression；full gate 卡点已经收敛成独立 `rtl/sysutils` 旧红。
- absorb 候选线 worktree 仍有 1 个未提交改动：
  - `build/verify_local.sh`
  - 内容是把 `llvm_var_param` expected exit 从旧值改回 fresh truth `7`
  - 在这 1 行没有形成干净 follow-up commit 前，不能把 absorb 线当成可落地主线的完成品
- `codex/compiler-c8-np-allocator-20260604` 仍然是实际升级主线，但现在不能直接移动 branch ref：
  - live worktree 仍有 compiler/sema/syntax/toolchain/tests/target facade 的 dirty WIP
  - 在没先保护这批 dirty 内容前，不能把 absorb 候选 fast-forward 回真实 C8 分支
- `codex/compiler-truth-audit-main-20260603` 也还不能降级成“已吸收可删”：
  - `git cherry` 证明很多 committed truth 已被 absorb 以新 commit 形式重放
  - 但仍有 audit-only 提交没有形成 patch-equivalent，必须逐提交判定是吸收、丢弃还是保留
- `fix/sema-include-resolver` 继续处于“不确定”：
  - 这条线还没有对照当前 `C8` imported/include truth 做 live focused review
  - 在没确认它与当前 imported-unit body / resolver / sema 路线是否冲突前，不应 archive，更不应直接 merge
- 这一轮 fresh 复盘后的分类应更新为：
  - 有价值但需要整理后合并：
    - `codex/compiler-truth-absorb-20260604`
    - `codex/compiler-c8-np-allocator-20260604`
  - 实验 / 不建议合并但要 archive：
    - `backup/accidental-mixed-commit-20260603`
    - `backup/sema-no-matching-overload-before-rebase`
    - `codex/compiler-truth-integration-20260604-main0915`（已 archive 并清理）
  - 不确定，需要继续审查：
    - `codex/compiler-truth-audit-main-20260603`
    - `fix/sema-include-resolver`

## 2026-06-07 full-chain direct-root isolation findings

- `bench_fullchain` 之前最小的 `plaintext` row 仍然经过 router，所以它并不能单独
  表示“runtime/socket + fixed handler response”成本；router dispatch 一直混在里边。
- 给 full-chain harness 增加 direct path 时，最先暴露出的不是 runtime bug，而是
  benchmark truth bug：
  - 如果 workload 叫 `direct_plaintext`，substring filter 会让
    `NEXTPAS_BENCH_FILTER=plaintext` 同时命中两条 row。
  - 这会污染 filter 语义，比“有没有新数字”更值得先修。
- 最终方案选择：
  - 不改 substring filter 机制本身；
  - 新 workload 命名为 `direct_root`，避免和 `plaintext` 重叠；
  - 让 routed row 使用 `Host: router`，direct row 使用 `Host: direct`，
    两者都保持 `GET /` + fixed-length plaintext response，差异主要落在是否经过 router。
- focused gate 现在直接锁住两件事：
  - `direct_root` row 确实存在；
  - `NEXTPAS_BENCH_FILTER=plaintext` 不会再误发 `workload=direct_root`。
- 这轮最重要的产出不是单次 `ns/op` 高低，而是：
  - full-chain benchmark 首次具备 router-free 对照 row；
  - filter 语义没有因为新增 workload 退化成模糊匹配假证据。

## 2026-06-07 router direct-call isolation findings

- 仅靠 `bench_fullchain direct_root/plaintext` 还不足以精确描述 router 成本：
  那两条 row 仍混有 real socket、server runtime、response serialization 和
  outer-handler gating。
- `bench_router` 原先只有 `handler dispatch (match + no-op handler)`，没有一个
  “同一 request、同一 handler、完全不经过 router”的纯基线，所以即使知道 routed
  row 的数字，也不能把纯 router dispatch 和 handler 调用本身拆开。
- 本轮选择的最小补充不是再加一个 full-chain workload，而是在现有 router
  microbenchmark 里补 `direct call (same request, no router)`：
  - 它复用同一个 `NewGetRequest('/health')` 和同一个 no-op handler 形状；
  - 唯一去掉的是 `THttpRouter.ServeHTTP` / route lookup / dispatch。
- focused gate 现在锁住三件事：
  - direct baseline row 确实存在；
  - `NEXTPAS_BENCH_FILTER=handler dispatch` 不会误命中 direct row；
  - `NEXTPAS_BENCH_FILTER=direct call` 不会误命中 routed row。
- 本地方向性数字：
  - `direct call (same request, no router)` 约 `3.8 ns/op`
  - `handler dispatch (match + no-op handler)` 约 `264.5 ns/op`
- 这说明：
  - router dispatch 现在已经有一条足够窄的纯进程基线；
  - 纯 handler 调用本身几乎可以忽略；
  - short-GET full-chain 的主要剩余成本仍应继续在 runtime/socket、
    response writer/drain、以及其他 server-path 成本上找，而不是回头扩大
    router parity 清单。

## 2026-06-07 bench_server backend marker and epoll smoke findings

- 目前 cross-language server comparison runner 明确写着“不覆盖 epoll”，但
  nextPas 自己的 `bench_server` raw row 之前也没有任何 `backend=` metadata。
  这会导致保存下来的 nextPas benchmark row 无法直接说明它到底测的是哪条
  runtime path。
- 本轮优先收紧的是 benchmark truth，不是立刻把 runner 扩成 threaded/epoll
  双模式比较：
  - 先给 nextPas `bench_server` 自己补 `--backend threaded|epoll`；
  - 再把 `backend=<...>` 写进 raw row / runner / snapshot 会继承到的 nextPas
    输出里；
  - 并让 invalid backend fail-fast，而不是静默回到默认 threaded。
- 这样做的好处是：
  - nextPas-only runtime characterization 可以立即开始；
  - 现有 Go/Rust comparison runner 不需要同步长出“只对 nextPas 有意义”的参数面；
  - 保存下来的报告不会再把 threaded 默认值隐含在背景知识里。
- focused gate 现在锁住三件事：
  - nextPas `bench_server` row 默认带 `backend=threaded`
  - invalid `--backend` 不会再产出伪成功 benchmark row
  - Linux epoll smoke row 确实能跑并带 `backend=epoll`
- 本地方向性 smoke：
  - `threaded no_url 128x1` 约 `41890 ns/op`
  - `epoll no_url 128x1` 约 `91425 ns/op`
- 这组数字不是 threaded-vs-epoll 的最终结论；它只是说明：
  - backend seam 现在已经进入 benchmark artifact truth；
  - 下一轮若继续追 runtime/socket overhead，可以在 nextPas-only bench 上直接
    对 threaded/epoll 做更窄、更受控的重复测量，而不是先改比较 runner。

## 2026-06-07 bench_fullchain backend marker and epoll smoke findings

- `bench_server --backend` 解决的是多线程吞吐维度，但 `bench_fullchain` 之前仍把
  backend 选择隐藏在默认 threaded 背景里。这样保存下来的 single-connection
  `direct_root/plaintext` row 仍无法直接说明自己跑的是哪条 runtime path。
- 这轮继续沿同一 benchmark-truth 方向走，但不去改 cross-language runner：
  - 只给 nextPas-only `bench_fullchain` 补 `NEXTPAS_BENCH_BACKEND`
  - 只让 full-chain header / row 公开 `backend=<...>` truth
  - 只让 invalid backend fail-fast
- 这样做的价值在于：
  - `direct_root` 本来就是当前最窄的 “single-connection runtime/socket +
    fixed handler response” row；
  - 有了 backend seam，它终于可以在 threaded / epoll 之间做受控切换；
  - 而 Go/Rust comparison runner 仍保持原来的 apples-to-apples 边界。
- focused gate 现在锁住三件事：
  - 默认 full-chain row 带 `backend=threaded`
  - invalid `NEXTPAS_BENCH_BACKEND` 不会再产出伪成功 benchmark row
  - Linux `epoll + direct_root` smoke 确实能跑并带 `backend=epoll`
- 本地方向性 smoke：
  - `threaded direct_root 128` 约 `32058.8 ns/op`
  - `epoll direct_root 128` 约 `92845.4 ns/op`
- 这组数字仍不是 threaded-vs-epoll 的稳定排名；它只是把 single-connection
  runtime characterization 从“默认 threaded 的隐含状态”推进到了“backend truth
  明示且可切换”的状态。下一轮如果继续追 runtime/socket overhead，就可以把
  `bench_server` 与 `bench_fullchain direct_root` 两条 backend-aware row 结合起来看。

## 2026-06-07 server comparison nextPas backend truth findings

- 只给 `bench_server` / `bench_fullchain` 增 `backend=` 还不够：
  人真正保存和转发的常常是 comparison runner report 或 snapshot，而不是单体 row。
  如果 report/snapshot 自己不写明 nextPas backend，那么 `backend=epoll` 只会埋在
  nextPas section 里，调用方很容易把整份 artifact 误读成默认 threaded。
- 这轮选择的是最小 truth 收口，而不是把 cross-language runner 扩成“所有实现都能切 backend”：
  - runner 增 `--nextpas-backend threaded|epoll`
  - raw comparison header 直接写 `nextpas_backend=<...>`
  - snapshot environment block 与 embedded command 同步保留这条 truth
  - 只有 nextPas row 吃这个参数，Go / Rust comparator row 完全不变
- 默认值仍保持 `threaded`，这点很关键：
  - 旧的 cross-language smoke / saved command 形状仍然成立
  - 调用方只有在明确做 nextPas-only runtime characterization 时，才需要显式传
    `--nextpas-backend epoll`
  - 这样不会把“nextPas epoll vs Go/Rust default implementation”伪装成新的
    apples-to-apples 公平比较
- focused gate 现在锁住：
  - runner 默认 header 带 `nextpas_backend=threaded`
  - invalid `--nextpas-backend` fail-fast，不会再打印伪 benchmark header
  - Linux `epoll` runner/snapshot smoke 都能把 `nextpas_backend=epoll` 透传到
    raw report / Markdown snapshot
- 本地手工 smoke 也确认 artifact truth 已贯通：
  - `run_server_comparison.sh --requests 8 --threads 1 --nextpas-backend epoll`
    输出 `nextpas_backend=epoll`，且 nextPas row 带 `backend=epoll`
  - `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --nextpas-backend epoll`
    snapshot environment block 带 `nextpas_backend=epoll`，command block 保留
    `--nextpas-backend epoll`
- 一个额外观察是：runner 和 snapshot 共用同一 build output root，若并行触发可能在
  Rust comparator build 阶段互相踩到目标文件。这是 benchmark harness 并发安全问题，
  不属于本轮 contract 最小收口，但值得作为下一轮 benchmark-truth 候选切片。

## 2026-06-07 server comparison concurrent build lock findings

- 在给 runner/snapshot 补完 `nextpas_backend` truth 后，手工并行触发两者时直接撞出了
  另一类 benchmark truth 污染：
  - 两个进程都会往同一个
    `build/projects/nextpas.core.http/server_comparison/` output root 重建 Go/Rust
    comparator 二进制；
  - 实际失败表现是 Rust link 阶段找不到刚被另一个进程覆盖/清理的目标文件。
- 这不是 “parallel shell misuse 才会出现的假问题”：
  - comparison runner 与 snapshot helper 本来就共用 build root；
  - 只要 CI/脚本/人工并行抓 report + snapshot，就可能命中同一类竞争；
  - 失败时得到的不是明确 “busy/locked” 诊断，而是一条看似 toolchain 自身损坏的
    linker error，会污染 benchmark evidence。
- 本轮选择的最小收口不是给每个 comparator 发明独立 cache key，也不是改 row/summary
  contract，而是：
  - 只在 `run_server_comparison.sh` 增一个 shared comparison lock；
  - snapshot 继续复用 runner，因此自动吃到同一条并发保护；
  - 锁住的是整个 comparison invocation，而不只是 build step，避免
    “A 刚 build 完、B 立刻原地重写二进制、A 再去执行半写入产物” 这类更隐蔽的竞争。
- 实现边界里还暴露出一个 shell 细节：
  - 旧的 `run_comparison | tee ...` 会把 `run_comparison` 推进 pipeline subshell；
  - 锁如果在 subshell 里拿到，就可能因为 parent trap 看不到持锁状态而残留 stale lock。
  - 因此输出路径分支也必须改成 process substitution，让 runner 继续在当前 shell 持锁并释放锁。
- focused gate 现在锁住 `run_server_comparison.sh` 拥有显式 comparison lock seam。
- 手工并发 smoke 也已转绿：
  - `run_server_comparison.sh --requests 8 --threads 1 --workload url_path --output ...`
    与
    `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --nextpas-backend epoll --output ...`
    并发启动后均返回 `exit=0`
  - runner report 仍保留 `nextpas_backend=threaded`
  - snapshot environment block 仍保留 `nextpas_backend=epoll`

## 2026-06-07 full-chain direct-1k isolation findings

- 现有 1 KiB 证据链仍有一个空档：
  - `bench_h1writer` / `bench_h1outbound` 只证明内存内 writer/drain 成本；
  - `bench_server response_1k` 证明的是多连接 server throughput；
  - 但还没有一条 “real socket + single keep-alive connection + no router +
    fixed 1 KiB response” 的 nextPas-only row。
- 本轮选择的最小补充不是扩 comparison runner，也不是改 `bench_server` workload，
  而是在 `bench_fullchain` 现有 outer-handler seam 上补 `direct_1k`：
  - 复用 `Host: direct` 的 no-router path；
  - 只新增 `GET /1k` + fixed 1 KiB body；
  - 继续沿用同一个 real socket / keep-alive client read contract。
- focused gate 锁住两件关键 truth：
  - `direct_1k` row 确实存在；
  - `NEXTPAS_BENCH_FILTER=direct_root` 不会误发 `workload=direct_1k`。
- 本地方向性 smoke：
  - `threaded direct_1k 128` 约 `36978.2 ns/op`
  - `epoll direct_1k 128` 约 `75342.2 ns/op`
- 这组数字不是新的 cross-language 排名；它们的意义更窄但更重要：
  - full-chain 现在终于有了 1 KiB fixed response 的 single-connection
    no-router seam；
  - 后续如果继续追 runtime/socket overhead，可以把
    `direct_root`、`direct_1k`、`bench_server response_1k` 和
    writer/outbound 1 KiB rows 串起来看，而不是继续把这些成本混成一条笼统
    的 “response_1k 很快/很慢” 结论。

## 2026-06-07 full-chain response-body-bytes marker findings

- `bench_server`、Go comparator、Rust std-only comparator 与 Hyper/Tokio comparator
  都已经公开 `response_body_bytes=...`，但 `bench_fullchain` 之前只有
  `client_read_mode=buffered`，没有 row-level response size marker。
- 这会让 `direct_root`、`direct_1k`、`plaintext` 等 full-chain row 的“完成条件”
  只能靠 workload 名称间接推断，不利于后续 grep、脚本消费和 saved artifact 对照。
- 本轮选择的最小收口不是改 full-chain client read mode，也不是扩 runner：
  - 只让 `bench_fullchain` 每条 row 追加 `response_body_bytes=...`
  - `direct_root` / `plaintext` 锁成 `13`
  - `direct_1k` 锁成 `1024`
- focused gate RED 直接暴露了 contract 缺口：
  `bench_fullchain plaintext` / `direct_root` / `direct_1k` / `epoll direct_root`
  smoke 全都因为缺失 `response_body_bytes=` marker 而失败。
- 这个 slice 没有新增任何性能数字；它补的是 full-chain artifact truth。
  现在 `bench_fullchain` 和 `bench_server`/comparators 一样，都会把 response
  size 当作 machine-readable metadata 输出，后续分析 `direct_root` vs `direct_1k`
  时不必再靠 workload 名字猜测 body 规模。

## 2026-06-07 full-chain H1 path marker findings

- `bench_server` 早就输出了 `nextpas_h1_path=...`，但 `bench_fullchain` 之前没有。
  这会让 full-chain saved row 难以直接说明自己是在当前 conservative fast path，
  还是已经落回 llhttp adapter path。
- 这轮选择的最小收口不是扩 comparison runner，也不是去改 H1 fast path 本身：
  - 只让 `bench_fullchain` 每条 nextPas row 输出 `nextpas_h1_path=...`
  - 当前 no-body GET rows 锁成 `fast`
  - body-bearing `echo_1k` / `sink_16k` rows 锁成 `llhttp`
- focused gate 这次不仅锁 metadata，还顺手补上了一个之前缺失的 full-chain
  body-bearing smoke：
  - `plaintext` / `direct_root` / `direct_1k` / `epoll direct_root`
    都因为缺 `nextpas_h1_path=fast` marker 而 RED
  - 新增 `echo_1k` smoke 进一步证明 llhttp path row 真实存在，并要求
    `nextpas_h1_path=llhttp`
- 本地手工 smoke 也给出了最窄的 llhttp full-chain row：
  - `echo_1k` threaded 128 次约 `39532.8 ns/op`
  - row 同时带 `response_body_bytes=1024` 与 `nextpas_h1_path=llhttp`
- 这轮的价值不在于又多了一条 benchmark 数字，而在于：
  - full-chain row 终于能直接说明自己测的是 fast ingress 还是 llhttp ingress
  - 后续把 `direct_root/direct_1k` 和 `echo_1k/sink_16k` 放在一起看时，不必再从
    request shape 间接推断 parser path

## 2026-06-07 full-chain request-body-bytes marker findings

- `bench_fullchain` 现在已经有 `response_body_bytes=...` 和
  `nextpas_h1_path=...`，但请求侧 body 大小之前仍只能靠 workload 名称猜。
- 这在 body-bearing full-chain rows 上会留下真实 artifact gap：
  - `echo_1k` 看名字还能勉强推断 request size；
  - `sink_16k` 这种 “大请求、空响应” row 如果没有 request-size marker，保存后的
    raw output 很难直接说明自己到底测了多少 ingress body。
- 本轮选择的最小收口仍然只落在 `bench_fullchain` metadata contract：
  - 每条 row 追加 `request_body_bytes=...`
  - focused rows 锁住 no-body GET workloads -> `0`
  - `echo_1k` 锁住 `request_body_bytes=1024`
- focused gate RED 直接说明这是 contract 缺口，不是性能数字问题：
  `bench_fullchain plaintext` / `direct_root` / `direct_1k` / `echo_1k` /
  `epoll direct_root` 全都因为缺失 `request_body_bytes=` marker 而失败。
- 本地手工 smoke 进一步把最容易误读的 request-heavy row 公开出来：
  - `sink_16k` threaded 128 次输出 `request_body_bytes=16384`
  - 同一 row 也保留 `response_body_bytes=0` 与 `nextpas_h1_path=llhttp`
- 这轮的价值仍是 benchmark truth，而不是新排名：
  full-chain saved artifacts 现在终于能同时自描述请求大小、响应大小和 ingress
  parser path，后续拆 request-body parse cost / response drain cost 时不必再从
  workload 名称做二次推断。

## 2026-06-07 full-chain sink-16k focused smoke findings

- `request_body_bytes` slice 之后，`sink_16k` 已经作为 docs/manual smoke 证据存在，
  但 focused gate 仍只锁住了 `echo_1k` 这一条 body-bearing llhttp row。
- 这会留下一个真实 coverage 空洞：
  - `echo_1k` 证明的是 “有请求体 + 有响应体”；
  - 但 `sink_16k` 代表的是 “大请求体 + 空响应体”，它更接近 ingress-heavy seam，
    也正是 request-size marker 文档里最容易误读的一条 row。
- 本轮选择的最小收口不是再加新 workload，也不是扩 epoll/backend matrix：
  - 只把既有 `sink_16k` row 提升进 `test_http_benchmarks` focused gate
  - 锁住 `request_body_bytes=16384`
  - 同时锁住 `response_body_bytes=0` 与 `nextpas_h1_path=llhttp`
- 这轮没有改 benchmark runtime，也没有新增 benchmark 输出字段；价值在于：
  request-heavy llhttp row 不再只是文档里的手工 smoke，而是进入了可回归的
  focused benchmark truth。

## 2026-06-07 full-chain epoll-echo focused smoke findings

- 到上一轮为止，`bench_fullchain` 的 epoll focused proof 仍只有
  `epoll + direct_root`。
- 这意味着 epoll backend 在 focused gate 里只被证明过 fast-path/no-body row，
  body-bearing llhttp path 还停留在手工 smoke，而不是持续回归证据。
- 本轮继续按最小矩阵补洞，不扩到 request-heavy epoll row，也不改 runtime：
  - 只把 `epoll + echo_1k` 提升进 focused gate
  - 锁住 `backend=epoll`
  - 同时锁住 `request_body_bytes=1024`、
    `response_body_bytes=1024`、`nextpas_h1_path=llhttp`
- 本地手工 smoke 也说明这条 row 真实存在：
  - `epoll echo_1k 64` 约 `107034.3 ns/op`
  - `req/s` 约 `9343`
- 这轮的价值仍是 benchmark truth：
  epoll 后端现在不再只靠 `direct_root` fast-path row 代表自己，focused gate 已经
  覆盖到至少一条 body-bearing llhttp full-chain row。

## 2026-06-07 full-chain param-route focused smoke findings

- `bench_fullchain` 里已有 `param_route` row，但此前 focused gate 仍没有锁住它。
- 这不是“再补一个普通 GET row”：
  - `plaintext` 只证明静态 route 的 routed path；
  - `param_route` 代表的是 URL path + router param extraction 这一条更具体的
    full-chain seam。
- 本轮继续遵守窄刀纪律：
  - 不改 runtime，不扩 backend matrix，不引入新 marker
  - 只把既有 `param_route` row 提升进 focused gate
  - 锁住 `request_body_bytes=0`、`response_body_bytes=10`、
    `backend=threaded`、`nextpas_h1_path=fast`
- 本地手工 smoke 也说明了这条 row 的现实形状：
  - `param_route 64` 约 `34646.2 ns/op`
  - `req/s` 约 `28863`
- 价值在于：
  full-chain saved artifacts 现在不只锁 “router/no-router/body/no-body”，还把
  path-params 这一条独立路由成本面纳入了持续回归证据。

## 2026-06-07 full-chain epoll-sink focused smoke findings

- 在 `epoll + echo_1k` slice 之后，epoll backend 已经覆盖到一条 body-bearing
  llhttp row，但它仍然没有覆盖 request-heavy / empty-response 这一格。
- `sink_16k` 在这里不是重复 `echo_1k`：
  - `echo_1k` 是对称的 request/response body row；
  - `sink_16k` 代表的是“重 ingress、空 egress”的 full-chain seam。
- 这轮继续保持窄刀，不扩 runtime、不加新 marker：
  - 只把 `epoll + sink_16k` 提升进 focused gate
  - 锁住 `backend=epoll`
  - 同时锁住 `request_body_bytes=16384`、`response_body_bytes=0`、
    `nextpas_h1_path=llhttp`
- 这轮的价值仍是 benchmark truth：
  epoll backend 的 durable full-chain proof 现在同时覆盖
  fast-path row、对称 body-bearing llhttp row，以及 request-heavy llhttp row。

## 2026-06-07 snapshot include-hyper response-1k focused smoke findings

- support 文档里之前已经明确提过一个更窄的后续缺口：
  snapshot helper 虽然支持 `--include-hyper` 和 `--workload`，但 focused gate
  还没有锁住这两个参数同时出现的组合。
- 在所有 workload 里，`response_1k` 比默认 no-body workload 更有信息量：
  - 它要求 raw output 继续保留 `response_body_bytes=1024`；
  - 同时它还能证明 Hyper/Tokio snapshot 不只是在默认 hello-world shape 上可用。
- 本轮保持窄刀，没有去扩 runner/schema/runtime：
  - 只把 `capture_server_comparison_snapshot.sh --include-hyper --workload response_1k`
    提升进 focused gate
  - 锁住 `workload=response_1k`
  - 锁住命令块同时包含 `--workload response_1k --include-hyper`
  - 锁住 `rust_hyper` row、`rust_profile=hyper_tokio`、`response_body_bytes=1024`
- 这轮的价值仍是 benchmark truth：
  Hyper/Tokio snapshot evidence 现在不再只靠默认 workload，saved artifact 对
  body-bearing response workload 也有 durable regression proof。

## 2026-06-07 hyper url_path direct comparator focused smoke findings

- 之前的 focused gate 里，Hyper/Tokio direct comparator 只有默认 `no_url`
  smoke；虽然 shared runner / snapshot 已覆盖 `url_path`，但 Cargo-based
  comparator 自己还没有一个独立、非默认 request-target workload contract。
- 这一轮不需要扩 runner/schema，也不需要改 comparator 实现：
  `compare_hyper` 源码本来就支持 `--workload url_path`，真实缺口只是 focused gate
  没有把这个 seam 锁住。
- 本轮继续保持窄刀：
  - 只把 `bench_http_server_hyper --requests 32 --threads 2 --workload url_path`
    提升进 focused gate
  - 锁住 `workload=url_path`
  - 锁住 `impl=rust_hyper`、`rust_profile=hyper_tokio`、`completed=32`
- 这轮的价值仍是 benchmark truth：
  Hyper/Tokio direct comparator 现在也有 durable non-default request-target
  proof，Go / Rust std-only / Hyper direct comparator 三条 direct smoke 的
  `url_path` parity 更完整，但没有借机扩到 `adapter_no_url` 或新的 runner
  组合。

## 2026-06-07 runner include-hyper url_path focused smoke findings

- 当前 matrix 里，runner 对 `url_path` 的证明原先只覆盖 nextPas / Go /
  Rust std-only 三行；Hyper/Tokio 只在默认 `no_url` include-hyper smoke 和
  `response_1k` snapshot 组合里出现。
- 这意味着一个真实而独特的 parity gap 仍存在：
  `run_server_comparison.sh --workload url_path --include-hyper` 虽然逻辑上应当
  可用，但 focused gate 还没有锁住 raw report 里 Hyper row 的非默认
  request-target seam。
- 本轮继续保持窄刀，没有扩到 snapshot 或 comparator 实现：
  - 只把 `run_server_comparison.sh --requests 8 --threads 1 --workload url_path --include-hyper`
    提升进 focused gate
  - 锁住 `include_hyper=1`
  - 锁住 `workload=url_path`
  - 锁住 `rust_hyper` row、`rust_profile=hyper_tokio`、`summary_impl=rust_hyper`
- 这轮的价值仍是 benchmark truth：
  Hyper/Tokio 现在不仅有 direct `url_path` smoke，也有 raw runner 级别的
  `url_path` durable proof；但没有借机扩大到新的 snapshot 组合或内部
  `adapter_no_url` 变体。

## 2026-06-07 full-chain epoll direct-1k focused smoke findings

- `direct_1k` 这个 1 KiB full-chain isolation row 之前已经有 threaded focused
  smoke，也在文档里记过本地 `epoll` 数字，但 regression gate 还没有把
  `epoll + direct_1k` 这条 nextPas-only egress-heavy seam 锁住。
- 这会留下一个真实 evidence gap：
  后续如果继续用 `direct_root` / `direct_1k` 对比 threaded 与 epoll 的
  runtime/socket开销，`direct_1k` 的 epoll 侧只能依赖文档里的手工 smoke，
  不够 durable。
- 本轮继续保持窄刀，没有扩 `bench_fullchain` 生产逻辑，也没有去碰 runner /
  comparator：
  - 只把 `NEXTPAS_BENCH_FILTER=direct_1k NEXTPAS_BENCH_BACKEND=epoll`
    提升进 focused gate
  - 锁住 `backend=epoll`
  - 锁住 `workload=direct_1k`
  - 锁住 `request_body_bytes=0`、`response_body_bytes=1024`、
    `nextpas_h1_path=fast`
- 这轮的价值仍是 benchmark truth：
  `direct_1k` 的 backend split 现在两侧都有 durable regression proof，更适合后续
  继续拆 runtime/socket overhead；但没有借机包装成 threaded-vs-epoll 排名。

## 2026-06-07 snapshot include-hyper url_path focused smoke findings

- 经过前两轮收口后，Hyper/Tokio 的 `url_path` 证据链已经有：
  - direct comparator smoke；
  - raw runner `--include-hyper + --workload url_path`；
  - 但 durable snapshot artifact 还没有锁住同一个组合。
- 这会留下一个很具体的 artifact gap：
  saved Markdown 里虽然已有默认 `include-hyper` 和 `response_1k` 组合 proof，
  但 request-target workload 的 Hyper row 仍只能从 raw runner 或 direct smoke
  间接推断。
- 本轮继续保持窄刀，没有扩 runner/schema，也没有碰 comparator 实现：
  - 只把
    `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --workload url_path --include-hyper`
    提升进 focused gate
  - 锁住 `workload=url_path`
  - 锁住命令块同时包含 `--workload url_path --include-hyper`
  - 锁住 `cargo_version=`、`hyper_cargo_lock_sha256=`
  - 锁住 `rust_hyper` row、`rust_profile=hyper_tokio`、`summary_impl=rust_hyper`
- 这轮的价值仍是 benchmark truth：
  Hyper/Tokio 的 `url_path` 现在在 direct comparator、raw runner 和 durable snapshot
  三层都有回归证据，但没有借机扩到 `adapter_no_url` 或新的 API/runtime 改动。

## 2026-06-07 runner include-hyper response-1k focused smoke findings

- `response_1k` 这条 body-bearing workload 之前已经有：
  - shared direct comparator 的 response-read contract；
  - include-hyper snapshot artifact；
  - 但 raw runner report 还没有把 Hyper/Tokio 自己的 body/read markers 锁住。
- 这会留下一个真实 gap：
  `run_server_comparison.sh --workload response_1k --include-hyper` 虽然逻辑上可用，
  但 saved text report 上的 `rust_hyper` body-bearing row 还没有 durable focused proof。
- 本轮继续保持窄刀，没有扩 runner/schema，也没有碰 comparator 实现：
  - 只把
    `run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --include-hyper`
    提升进 focused gate
  - 锁住 `include_hyper=1`
  - 锁住 `workload=response_1k`
  - 锁住 `rust_hyper` row、`rust_profile=hyper_tokio`
  - 锁住 `client_read_mode=header_plus_content_length`、
    `response_body_bytes=1024`、`summary_impl=rust_hyper`
- 这轮的价值仍是 benchmark truth：
  Hyper/Tokio 的 body-bearing raw runner row 现在也有 durable regression proof，
  request-target 和 body-bearing 两条高信息量 workload 都不再只靠 snapshot
  或 indirect contract 覆盖。

## 2026-06-07 runner epoll url_path focused smoke findings

- 当前 `--nextpas-backend epoll` 的 comparison proof 还停在默认 `no_url` workload。
  这意味着 nextPas epoll 虽然已经能进入 cross-language runner，但 public
  request-target seam 还没有 durable raw report。
- 这不是机械补一条同型 row：
  - `no_url` 更像 fast-path baseline；
  - `url_path` 代表的是 nextPas 在公开 request-target 访问面上的 backend 证据。
- 本轮继续保持窄刀，没有扩 snapshot，也没有碰 runner/HTTP 生产逻辑：
  - 只把
    `run_server_comparison.sh --requests 8 --threads 1 --workload url_path --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=url_path`
  - 锁住 nextPas row 的 `backend=epoll`
  - 同时保留 Go / Rust std-only 的同 workload 对照行
- 这轮的价值仍是 benchmark truth：
  epoll backend 现在不再只在默认 no-URL comparison 上有 durable proof，而是进入了
  public request-target cross-language report。

## 2026-06-07 snapshot epoll url_path focused smoke findings

- raw runner 的 `--nextpas-backend epoll + --workload url_path` 这轮已经有了 focused
  proof，但 durable snapshot artifact 还停在默认 epoll row。
- 这会留下一个 artifact gap：
  后续如果只看 Markdown snapshot，仍然无法直接看到 epoll backend 在 public
  request-target comparison seam 上的保存结果。
- 本轮继续保持窄刀，没有扩 snapshot schema，也没有碰 runner/HTTP 生产逻辑：
  - 只把
    `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --workload url_path --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=url_path`
  - 锁住命令块同时包含 `--workload url_path --nextpas-backend epoll`
  - 锁住 nextPas row 的 `backend=epoll`
  - 同时保留 Go / Rust std-only 的同 workload 对照行
- 这轮的价值仍是 benchmark truth：
  epoll backend 现在在 raw runner 和 durable snapshot 两层都覆盖到了 public
  request-target seam，而不再只停在默认 no-URL artifact。

## 2026-06-07 runner epoll response-1k focused smoke findings

- 目前 `--nextpas-backend epoll` 的 public comparison evidence 已覆盖默认
  `no_url` 和 request-target `url_path`，但 body-bearing `response_1k` raw report
  还没有 durable focused proof。
- 这会留下一个真实 gap：
  后续如果只看 saved text report，epoll backend 仍然缺少公开 response-body seam
  的 regression evidence。
- 本轮继续保持窄刀，没有扩 snapshot，也没有碰 runner/HTTP 生产逻辑：
  - 只把
    `run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=response_1k`
  - 锁住 nextPas row 的 `backend=epoll`
  - 锁住 `client_read_mode=header_plus_content_length`、
    `response_body_bytes=1024`
  - 同时保留 Go row 的 `client_read_mode=http_client_body_drain`
- 这轮的价值仍是 benchmark truth：
  epoll backend 现在也进入了 public body-bearing raw comparison seam，不再只停在
  no-URL 和 request-target 两条无请求体 workload。

## 2026-06-07 snapshot epoll response-1k focused smoke findings

- raw runner 的 `--nextpas-backend epoll + --workload response_1k` 现在已有 focused
  proof，但 durable snapshot artifact 还没有锁住同一个 body-bearing backend 组合。
- 这会留下一个 artifact gap：
  后续如果只看 Markdown snapshot，仍然看不到 epoll backend 在 public
  response-body seam 上的保存结果。
- 本轮继续保持窄刀，没有扩 snapshot schema，也没有碰 runner/HTTP 生产逻辑：
  - 只把
    `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --workload response_1k --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=response_1k`
  - 锁住命令块同时包含 `--workload response_1k --nextpas-backend epoll`
  - 锁住 nextPas row 的 `backend=epoll`
  - 锁住 `client_read_mode=header_plus_content_length`、
    `response_body_bytes=1024`
  - 同时保留 Go row 的 `client_read_mode=http_client_body_drain`
- 这轮的价值仍是 benchmark truth：
  epoll backend 现在在 raw runner 和 durable snapshot 两层都覆盖到了 public
  body-bearing comparison seam。

## 2026-06-07 runner include-hyper epoll response-1k focused smoke findings

- 之前的 focused coverage 已分别证明：
  - `--include-hyper + --workload response_1k`
  - `--nextpas-backend epoll + --workload response_1k`
  但还没有一条测试证明这两个 opt-in knob 能在同一个 public raw report 里稳定共存。
- 这不是机械补笛卡尔积：
  它锁的是“真实用户会一起打开的两条非默认 comparison 维度是否能组合”，也就是
  Rust Hyper/Tokio comparator 与 nextPas epoll backend 能否同时进入同一条
  body-bearing cross-language report。
- 本轮继续保持窄刀，没有改 runner 或 comparator 实现：
  - 只把
    `run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --include-hyper --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `include_hyper=1`
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=response_1k`
  - 锁住 nextPas row 的 `backend=epoll`
  - 锁住 `rust_hyper` row 的 `rust_profile=hyper_tokio`
  - 锁住 `response_body_bytes=1024` 与 `summary_impl=rust_hyper`
- 这轮的价值仍是 benchmark truth：
  它证明 dual opt-in body-bearing public comparison 能稳定组合，而不是只在两个分离的
  focused seam 里各自成立。

## 2026-06-07 snapshot include-hyper epoll response-1k focused smoke findings

- raw runner 的 dual opt-in body-bearing seam 这轮已经有了 focused proof，但 durable
  snapshot artifact 还没有锁住同一个组合。
- 这会留下一个 artifact gap：
  如果调用方只消费保存下来的 Markdown snapshot，仍然无法直接证明 Hyper/Tokio comparator
  与 nextPas epoll backend 在同一条 public body-bearing report 上稳定共存。
- 本轮继续保持窄刀，没有扩 snapshot schema，也没有碰 runner/HTTP 生产逻辑：
  - 只把
    `capture_server_comparison_snapshot.sh --requests 8 --threads 1 --workload response_1k --include-hyper --nextpas-backend epoll`
    提升进 focused gate
  - 锁住 `include_hyper=1`
  - 锁住 `nextpas_backend=epoll`
  - 锁住 `workload=response_1k`
  - 锁住命令块同时包含
    `--workload response_1k --include-hyper --nextpas-backend epoll`
  - 锁住 `cargo_version=`、`hyper_cargo_lock_sha256=`
  - 锁住 nextPas row 的 `backend=epoll`
  - 锁住 `rust_hyper` row 的 `rust_profile=hyper_tokio`
  - 锁住 `client_read_mode=header_plus_content_length`、
    `response_body_bytes=1024`、`summary_impl=rust_hyper`
- 这轮的价值仍是 benchmark truth：
  dual opt-in body-bearing public comparison 现在在 raw runner 和 durable snapshot
  两层都能稳定取证。

## 2026-06-07 h1 metadata-cache filter focused smoke findings

- `request metadata` 这组 bench_h1parser row 之前只在较宽的过滤器下一起出现：
  legacy row 与 cached row 会同时输出。
- 这会留下一个微基准 truth gap：
  后续如果只想盯住 parse-time metadata cache 本身，focused gate 还不能证明
  `request metadata cached` 这条 row 能单独稳定存在，也不能证明过滤器不会顺手带出
  legacy row 或无关 fast-headers row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=request metadata cached` 提升进 focused gate
  - 锁住 `bench_filter=request metadata cached`
  - 锁住 `adapter cost: request metadata cached expect+cl`
  - 锁住 filtered output 不包含
    `adapter cost: request metadata legacy expect+cl`
  - 也不包含无关的 `fast headers get host only`
- 这轮的价值仍是 benchmark truth：
  request metadata cache 现在有了更窄、更适合后续性能 isolation 的 standalone
  microbenchmark proof，而不是只附着在更宽的 filter 组合里。

## 2026-06-07 h1 fast-headers filter focused smoke findings

- `fast headers` 这组 bench_h1parser row 之前也只在较宽的过滤器下一起出现：
  `get host only`、`count all`、`has accept`、`get all accept`、`foreach all`
  会同时输出。
- 这会留下另一个微基准 truth gap：
  后续如果只想盯住 fast lazy headers 的单-header raw lookup，本来的 focused gate
  还不能证明 `fast headers get host only` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 materialization 更重的 `count all` / `foreach all` 或无关的
  metadata-cache row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=fast headers get host only` 提升进 focused gate
  - 锁住 `bench_filter=fast headers get host only`
  - 锁住 `adapter cost: fast headers get host only`
  - 锁住 filtered output 不包含
    `adapter cost: fast headers count all`
  - 也不包含 `adapter cost: fast headers foreach all`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  fast lazy headers 的单-header raw lookup 现在有了更窄、更适合后续性能 isolation
  的 standalone microbenchmark proof，而不是只附着在更宽的 `fast headers`
  filter 组合里。

## 2026-06-07 h1 fast-headers get-all filter focused smoke findings

- `fast headers get all accept` 之前虽然有独立 row，但 focused gate 仍只证明整组
  `fast headers` filter 会一起输出。
- 这会留下同名多值 lookup 的 truth gap：
  后续如果只想盯住 `GetAllRawValues` 这一层的 raw multi-value lookup，本来的
  focused gate 还不能证明 `fast headers get all accept` 这条 row 能单独稳定存在，
  也不能证明过滤器不会顺手带出单值 `get host only`、materialization 更重的
  `foreach all` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=fast headers get all accept` 提升进 focused gate
  - 锁住 `bench_filter=fast headers get all accept`
  - 锁住 `adapter cost: fast headers get all accept`
  - 锁住 filtered output 不包含
    `adapter cost: fast headers get host only`
  - 也不包含 `adapter cost: fast headers foreach all`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  fast lazy headers 的 same-name multi-value raw lookup 现在有了更窄、更适合后续
  性能 isolation 的 standalone microbenchmark proof，而不是只附着在更宽的
  `fast headers` filter 组合里。

## 2026-06-07 h1 fast-headers has filter focused smoke findings

- `fast headers has accept` 之前虽然有独立 row，但 focused gate 仍只证明整组
  `fast headers` filter 会一起输出。
- 这会留下 presence-only lookup 的 truth gap：
  后续如果只想盯住 `HasRawHeader` 这一层的 raw presence lookup，本来的 focused
  gate 还不能证明 `fast headers has accept` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 `get host only`、`get all accept` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=fast headers has accept` 提升进 focused gate
  - 锁住 `bench_filter=fast headers has accept`
  - 锁住 `adapter cost: fast headers has accept`
  - 锁住 filtered output 不包含
    `adapter cost: fast headers get host only`
  - 也不包含 `adapter cost: fast headers get all accept`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  fast lazy headers 的 presence-only raw lookup 现在有了更窄、更适合后续性能
  isolation 的 standalone microbenchmark proof，而不是只附着在更宽的
  `fast headers` filter 组合里。

## 2026-06-07 h1 fast-headers count filter focused smoke findings

- `fast headers count all` 之前虽然有独立 row，但 focused gate 仍只证明整组
  `fast headers` filter 会一起输出。
- 这会留下 raw header-count 的 truth gap：
  后续如果只想盯住 `TFastLazyHeaders.Count` 这一层的 raw count path，本来的 focused
  gate 还不能证明 `fast headers count all` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 `get host only`、`foreach all` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=fast headers count all` 提升进 focused gate
  - 锁住 `bench_filter=fast headers count all`
  - 锁住 `adapter cost: fast headers count all`
  - 锁住 filtered output 不包含
    `adapter cost: fast headers get host only`
  - 也不包含 `adapter cost: fast headers foreach all`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  fast lazy headers 的 raw count path 现在有了更窄、更适合后续性能 isolation 的
  standalone microbenchmark proof，而不是只附着在更宽的 `fast headers`
  filter 组合里。

## 2026-06-07 h1 fast-headers foreach filter focused smoke findings

- `fast headers foreach all` 之前虽然有独立 row，但 focused gate 仍只证明整组
  `fast headers` filter 会一起输出。
- 这会留下 full materialization path 的 truth gap：
  后续如果只想盯住 `EnsureMaterialized + ForEach` 这一层的重路径，本来的 focused
  gate 还不能证明 `fast headers foreach all` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 `get host only`、`get all accept` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 parser 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=fast headers foreach all` 提升进 focused gate
  - 锁住 `bench_filter=fast headers foreach all`
  - 锁住 `adapter cost: fast headers foreach all`
  - 锁住 filtered output 不包含
    `adapter cost: fast headers get host only`
  - 也不包含 `adapter cost: fast headers get all accept`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  fast lazy headers 的 full materialization path 现在有了更窄、更适合后续性能
  isolation 的 standalone microbenchmark proof，而不是只附着在更宽的
  `fast headers` filter 组合里。

## 2026-06-07 h1 request-path filter focused smoke findings

- `request direct Path access` 之前虽然已有独立 row，但 focused gate 仍只证明宽
  `request ` filter 会一起输出 `lazy Url.Path`、`direct Path`、`direct RawQuery`、
  `direct Path+RawQuery`。
- 这会留下 request-target projection 的 truth gap：
  后续如果只想盯住 `Req.Path` 这条 direct path projection，本来的 focused gate
  还不能证明 `request direct Path access` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 `lazy Url.Path`、`direct RawQuery` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 request/URL 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=request direct Path access` 提升进 focused gate
  - 锁住 `bench_filter=request direct Path access`
  - 锁住 `adapter cost: request direct Path access`
  - 锁住 filtered output 不包含
    `adapter cost: request lazy Url.Path access`
  - 也不包含 `adapter cost: request direct RawQuery access`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  direct request-path projection 现在有了更窄、更适合后续 URL/request-target
  成本隔离的 standalone microbenchmark proof，而不是只附着在更宽的
  `request ` filter 组合里。

## 2026-06-07 h1 request-rawquery filter focused smoke findings

- `request direct RawQuery access` 之前虽然已有独立 row，但 focused gate 仍只证明宽
  `request ` filter 会一起输出 `lazy Url.Path`、`direct Path`、`direct RawQuery`、
  `direct Path+RawQuery`。
- 这会留下 request-target query projection 的 truth gap：
  后续如果只想盯住 `Req.RawQuery` 这条 direct query projection，本来的 focused gate
  还不能证明 `request direct RawQuery access` 这条 row 能单独稳定存在，也不能证明
  过滤器不会顺手带出 `lazy Url.Path`、`direct Path` 或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 request/URL 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=request direct RawQuery access` 提升进 focused gate
  - 锁住 `bench_filter=request direct RawQuery access`
  - 锁住 `adapter cost: request direct RawQuery access`
  - 锁住 filtered output 不包含
    `adapter cost: request lazy Url.Path access`
  - 也不包含 `adapter cost: request direct Path access`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  direct request-query projection 现在有了更窄、更适合后续 URL/request-target
  成本隔离的 standalone microbenchmark proof，而不是只附着在更宽的
  `request ` filter 组合里。

## 2026-06-07 h1 request-path+rawquery filter focused smoke findings

- `request direct Path+RawQuery access` 之前虽然已有独立 row，但 focused gate 仍只证明宽
  `request ` filter 会一起输出 `lazy Url.Path`、`direct Path`、`direct RawQuery`、
  `direct Path+RawQuery`。
- 这会留下 combined request-target projection 的 truth gap：
  后续如果只想盯住 `Req.Path` + `Req.RawQuery` 的组合 direct projection，本来的
  focused gate 还不能证明 `request direct Path+RawQuery access` 这条 row 能单独
  稳定存在，也不能证明过滤器不会顺手带出 `direct Path`、`direct RawQuery` 或
  无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 request/URL 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=request direct Path+RawQuery access` 提升进 focused gate
  - 锁住 `bench_filter=request direct Path+RawQuery access`
  - 锁住 `adapter cost: request direct Path+RawQuery access`
  - 锁住 filtered output 不包含
    `adapter cost: request direct Path access`
  - 也不包含 `adapter cost: request direct RawQuery access`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  combined direct request path/query projection 现在有了更窄、更适合后续
  URL/request-target 成本隔离的 standalone microbenchmark proof，而不是只附着在
  更宽的 `request ` filter 组合里。

## 2026-06-07 h1 url-parse request-target filter focused smoke findings

- `url parse request-target origin-form` 之前虽然已有独立 row，但 focused gate 仍只证明
  宽 `url parse` filter 会一起输出 `generic origin-form` 与
  `request-target origin-form`。
- 这会留下 parse-only 成本中心的 truth gap：
  后续如果只想盯住 request-target-specialized parse path，本来的 focused gate
  还不能证明 `url parse request-target origin-form` 这条 row 能单独稳定存在，也不能
  证明过滤器不会顺手带出 `url parse generic origin-form`、request projection row
  或无关的 metadata-cache row。
- 本轮继续保持窄刀，没有碰 URL/request 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=url parse request-target origin-form` 提升进 focused gate
  - 锁住 `bench_filter=url parse request-target origin-form`
  - 锁住 `adapter cost: url parse request-target origin-form`
  - 锁住 filtered output 不包含
    `adapter cost: url parse generic origin-form`
  - 也不包含 `adapter cost: request direct Path access`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  request-target-specialized URL parse path 现在有了更窄、更适合后续 parse-only
  成本隔离的 standalone microbenchmark proof，而不是只附着在更宽的 `url parse`
  filter 组合里。

## 2026-06-07 h1 url-parse generic filter focused smoke findings

- `url parse generic origin-form` 之前虽然已有独立 row，但 focused gate 仍只证明宽
  `url parse` filter 会一起输出 `generic origin-form` 与
  `request-target origin-form`。
- 这会留下 parse-only 对照组的 truth gap：
  后续如果只想盯住 generic origin-form parse path，本来的 focused gate 还不能证明
  `url parse generic origin-form` 这条 row 能单独稳定存在，也不能证明过滤器不会
  顺手带出 `url parse request-target origin-form`、request projection row 或无关的
  metadata-cache row。
- 本轮继续保持窄刀，没有碰 URL/request 生产逻辑：
  - 只把 `NEXTPAS_BENCH_FILTER=url parse generic origin-form` 提升进 focused gate
  - 锁住 `bench_filter=url parse generic origin-form`
  - 锁住 `adapter cost: url parse generic origin-form`
  - 锁住 filtered output 不包含
    `adapter cost: url parse request-target origin-form`
  - 也不包含 `adapter cost: request direct Path access`
  - 也不包含无关的 `request metadata cached expect+cl`
- 这轮的价值仍是 benchmark truth：
  generic origin-form URL parse path 现在有了更窄、更适合后续 parse-only 成本隔离的
  standalone microbenchmark proof，也给 request-target-specialized parse row 留下
  对照组。
