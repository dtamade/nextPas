# Historical Task Plan: HTTP H1 Performance Work

## Active Session: 2026-06-06 http relative redirect query slice

### Goal

收紧 client redirect transport seam：relative `Location` 里带 query 时，
follow-up request 对象必须把 path/query 拆开，而不是把整串留在 `Url.Path`。
这保证显式注入的 `IHttpTransport` 以及 future H2/H3 transport 都能看到正确
`Path` / `RawQuery` contract。

### Checklist

- [x] 审计发现 live H1 wire path 已能正确到达 `/new?from=redirect`，因为 server
  会重新解析 request-target；但 injected transport seam 仍能暴露 follow-up
  request 对象的 URL parts 缺口。
- [x] RED：`test_http_client` 新增 fake transport，第一轮返回
  `302 Location: /new?from=redirect`，第二轮检查 request `Path` / `RawQuery`；
  当前失败为 `expected "/new", got "/new?from=redirect"`。
- [x] GREEN：在 `nextpas.core.http.client` 增加内部 `ResolveRedirectUrl`，absolute
  URL 继续走 `TUrl.Parse`，relative Location 走 `TUrl.ParseRequestTarget` 后
  合并到 base URL。
- [x] 保留 live H1 proof：relative redirect with query 能命中最终 route，并且
  handler 可见 `Path`、`RawQuery` 与 `QueryParam`。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gate：`test_http_client`。

## Active Session: 2026-06-06 http see-other redirect slice

### Goal

收紧 client redirect/error semantics：补齐 `303 See Other` status constant /
facade visibility，并让 `IHttpClient` 跟随 `303` 时按 Go/Rust 常见 client
语义把原请求改为 `GET` 且丢弃 body。该 slice 不改 `IHttpClient` vtable、
transport、timeout 或 per-request redirect option。

### Checklist

- [x] RED：`test_http_base` 先要求 `HTTP_STATUS_SEE_OTHER` 与
  `HttpStatusText(303) = 'See Other'`，当前编译失败于 status constant 缺失。
- [x] RED：`test_http_contract` 先通过 facade 读取
  `nextpas.core.http.HTTP_STATUS_SEE_OTHER`，当前编译失败，证明 facade 未暴露。
- [x] RED：`test_http_client` 先启动 live server，POST `/submit` 返回 `303`
  到 `/complete`，期望最终请求为 `GET` 且 body 为空；当前编译失败于 status
  constant 缺失。
- [x] GREEN：在 `http.base` / facade 增加 `HTTP_STATUS_SEE_OTHER` 与
  status text，在 client redirect set 中加入 `303`，并沿用 `301/302` 的
  replay-as-GET/drop-body 分支。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gates：`test_http_base`、`test_http_contract`、`test_http_client`。

## Active Session: 2026-06-06 http request string body helper slice

### Goal

继续收紧 client request ergonomics：新增
`NewRequest(Method, Url, Headers, BodyText)` public helper，让调用方可以用
Pascal string 构造 request body，而不必手写 bytes stream 和 content length。
该 helper 复制 string 到 in-memory reader，发布 `Content-Length`，但不自动设置
`Content-Type`。

### Checklist

- [x] RED：`test_http_message` 先调用 string body helper，当前编译失败于
  `NewRequest` 参数数量不匹配。
- [x] RED：`test_http_contract` 先通过 `nextpas.core.http` facade 调用 string body
  helper，当前编译失败，证明 facade 还没有暴露该 public surface。
- [x] RED：`test_http_client` 把 live `IHttpClient.Do_` helper path 改用 string
  body overload，当前编译失败，证明缺口会影响真实 client path。
- [x] GREEN：在 `nextpas.core.http.message` 与 facade 增加 `TUrl` / URL string
  两个 string body overload；实现只复制 body、复用既有 headers/content-length
  helper contract。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gates：`test_http_message`、`test_http_contract`、`test_http_client`。

## Active Session: 2026-06-06 http client nil request error slice

### Goal

收紧 `IHttpClient.Do_` 的 public error semantics：nil request 是调用方
参数错误，必须在 client 入口抛 `EArgumentError`，不能穿透到 transport /
redirect path 形成 access violation。

### Checklist

- [x] RED：`test_http_client` 新增 `Client Do rejects nil request`，
  当前失败为 `Access violation`，证明 public 入口缺少 guard。
- [x] GREEN：只在 `THttpClient.Do_` 增加 nil request guard，不改
  `IHttpClient` vtable、transport、redirect 或 request helper 语义。
- [x] 更新 `core/docs/http/API_COVERAGE.md` 与本 support evidence。
- [x] 跑 focused gate：`test_http_client`。

## Active Session: 2026-06-06 http response body string helper slice

### Goal

继续收紧 client response ergonomics：新增
`HttpReadResponseBodyString(Resp)` public helper，让常见 client/example
调用方能把完整 response body 读成 Pascal string，而不再在每个调用点手写
reader loop 或 `ReadAll` + bytes conversion。该 helper 明确会消费
`IHttpResponse.Body`；nil body 返回空串，nil response 作为调用错误抛
`EArgumentError`。

### Checklist

- [x] RED：`test_http_client` 先用 helper 读取 live response body，并锁住
  nil body / nil response 边界；当前编译失败于 helper 缺失。
- [x] RED：`test_http_contract` 先通过 `nextpas.core.http` facade 调用 helper；
  当前编译失败，证明 facade 还没有暴露该 public surface。
- [x] GREEN：在 `nextpas.core.http.client` 添加 helper，在
  `nextpas.core.http` facade 添加 inline forwarding helper；不改
  `IHttpClient` vtable、不改 transport、不引入 response builder。
- [x] 更新 `http_get_client` example，改用新 helper。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gates：`test_http_client`、`test_http_contract`、
  `test_http_examples`。

## Active Session: 2026-06-06 http hyper comparator smoke slice

### Goal

继续收紧 benchmark truth：在保留 `rust_std` std-only microbaseline 的同时，
新增一个可选 Cargo-based Hyper/Tokio HTTP/1.1 server comparator smoke。
runner 默认仍不强制跑外部依赖；显式 `--include-hyper` 时才纳入
`impl=rust_hyper` / `rust_profile=hyper_tokio` 行和 median summary。

### Checklist

- [x] RED：`test_http_benchmarks` 先要求 `compare_hyper` Cargo comparator
  和 runner `--include-hyper`，当前分别失败于目录缺失和 unknown argument。
- [x] GREEN：新增 `compare_hyper` Cargo project，Hyper/Tokio 负责 server，
  raw keep-alive client 保持与 std-only comparator 相同 workload shape。
- [x] GREEN：`run_server_comparison.sh --include-hyper` 可选构建/运行
  Hyper/Tokio comparator，并把 `summary_impl=rust_hyper` 纳入 summary。
- [x] RED/GREEN：snapshot helper 先失败于 unknown `--include-hyper`，随后
  透传该 flag，并在 Markdown environment / command / raw output 中记录。
- [x] 更新 HTTP benchmark/API docs 与本 support evidence。
- [x] 跑 focused gate：`test_http_benchmarks`。

## Active Session: 2026-06-06 http request string URL overload slice

### Goal

继续收紧 client ergonomics：`NewRequest(Method, Url)` 与
`NewRequest(Method, Url, Headers, Body, ContentLength)` 除了接受 `TUrl`，
也接受 URL string。调用方可以直接构造 `IHttpClient.Do_` 请求，不必先手写
`TUrl.Parse`；解析和 body/header contract 仍复用现有 helper。

### Checklist

- [x] RED：`test_http_message` 先用 string URL overload 构造简单 request
  与 headers/body request，当前编译失败，错误为 string 参数仍要求 `TUrl`。
- [x] RED：`test_http_contract` 先通过 facade 调用 string URL overload，
  当前编译失败，证明门面还没有暴露该 public surface。
- [x] RED：`test_http_client` 把 live `IHttpClient.Do_` request helper 用例改成
  string URL overload，当前编译失败，证明 ergonomics 缺口会影响真实 client path。
- [x] GREEN：在 `nextpas.core.http.message` 与 `nextpas.core.http` facade
  增加 string URL overload；实现只调用 `TUrl.Parse` 并复用既有 helper contract。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gates：`test_http_message`、`test_http_contract`、`test_http_client`。

## Active Session: 2026-06-06 http get client example env URL slice

### Goal

让 `http_get_client` example 可在 example smoke 中跟随动态保留端口运行：
无命令行 URL 时先读取 `NEXTPAS_HTTP_GET_URL`，没有环境变量时才回到原
`127.0.0.1:8080` 示例默认值。

### Checklist

- [x] RED：`test_http_examples` 新增 client smoke，先启动 `http_hello_server`
  的保留 loopback 端口，再只通过 `NEXTPAS_HTTP_GET_URL` 运行 client；当前
  client 忽略 env，仍连接 `8080` 并失败。
- [x] GREEN：只修改 `http_get_client` example，命令行参数优先，其次读取
  `NEXTPAS_HTTP_GET_URL`，最后才使用旧默认 URL。
- [x] 更新 HTTP README/API coverage/control evidence。
- [x] 跑 focused gate：`test_http_examples`。

## Active Session: 2026-06-06 http rust std comparator label slice

### Goal

收紧 benchmark truth：把当前 Rust std-only server comparator 从泛化
`impl=rust` 改成机器可读的 `impl=rust_std` / `rust_profile=std_only`，
让 runner、snapshot 和 focused tests 都明确它不是 Hyper/Tokio 或 Rust 生态代表。

### Checklist

- [x] RED：`test_http_benchmarks` 先要求 Rust comparator / runner / snapshot
  输出 `impl=rust_std` 与 `rust_profile=std_only`，当前 `impl=rust` 触发失败。
- [x] GREEN：只修改 `compare_rust/main.rs` 与 `run_server_comparison.sh`，
  comparator 输出新 marker，runner 的 section / expected impl / summary 统一使用
  `rust_std`。
- [x] 更新 HTTP benchmark/API/control 文档，记录 std-only label contract 和
  Hyper/Tokio 仍是后续缺口。
- [x] 跑 focused gate：`test_http_benchmarks`。

## Active Session: 2026-06-06 http API parity request helper slice

### Goal

完成一轮 HTTP public API 对标审计，并落一个低风险 client ergonomics
切片：新增 `NewRequest(Method, Url, Headers, Body, ContentLength)` helper，
让调用方不必直接依赖 concrete `THttpRequest` 就能构造带自定义 headers/body
的 `IHttpClient.Do_` 请求。

### Checklist

- [x] 只读审计当前 HTTP docs、coverage、benchmark truth 与 public API。
- [x] 对标 Go `net/http` 与 Rust hyper/tower/reqwest 核心使用面，记录短结论：
  server lifecycle/router/middleware/static/websocket/H2-H3 boundary 已够稳；
  client request construction 是真实缺口；Hyper/Tokio comparator 仍是 benchmark truth 缺口。
- [x] RED：`test_http_message` / `test_http_contract` 先因缺少
  `NewRequest(..., Headers, Body, ContentLength)` overload 编译失败。
- [x] RED：负 `ContentLength` 用例先失败，证明 helper 缺少输入校验。
- [x] GREEN：在 `nextpas.core.http.message` 与 facade 增加 overload；
  nil headers 创建空 header set，body/positive length 写入 `content-length`，
  negative length 抛 `EArgumentError`。
- [x] 在 `test_http_client` 补 live proof：新 helper 构造的 request 经
  `IHttpClient.Do_` 正确发送 custom header、content-length 与 body。
- [x] 跑 focused gates：`test_http_message`、`test_http_contract`、`test_http_client`。
- [x] 跑 `git diff --check` 与 `make hygiene`，并先提交 feature。
- [x] 更新 `core/docs/http/README.md`、`API_COVERAGE.md` 与本 support evidence，
  单独提交 docs。

## Active Session: 2026-06-06 http h1 parser metadata span fast path slice

### Goal

推进 `nextpas.core.http` 的 llhttp adapter request metadata 热路径：
在 parser watched headers 已由 llhttp 以单 span callback 交付时，让
`Host` / `Connection` / `Content-Length` / `Expect` metadata 直接扫描 captured
span，避免为了 metadata 再物化一份 header value string；`Transfer-Encoding`
继续保留 combined-string validation，避免 malformed / unsupported 分类漂移。

### Checklist

- [x] RED：`test_http_benchmarks` 先失败，证明 parser metadata 缺少 span
  fast-path helper source-contract。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1.parser`，新增 captured value
  non-empty / equals / trimmed-int64 / expect-token span helper，并让 watched
  metadata 分支使用它们。
- [x] 在 `test_http_h1parser` 补 span fast path 下 trim / case-insensitive
  `Expect` token / trimmed `Content-Length` behavior proof。
- [x] 跑 focused gates：`test_http_h1parser`、`test_http_benchmarks`、
  `test_http_server`。
- [x] 跑小 benchmark smoke：`bench_h1parser` 的 `adapter no-url` filter。
- [x] 更新 HTTP benchmark/API/control 文档，不写 inbox，并 path-limited commit。

## Active Session: 2026-06-06 http h1 writer known status-line slice

### Goal

推进 `nextpas.core.http` 的 H1 response status-line serialization 热路径：
让 `TH1ResponseWriter.WriteStatusLine` 对常见状态码使用固定 status-line
fast path，尤其覆盖 server 错误响应常见的 `400/404/413/417/431/500/501`，
避免每次经过 `IntToStr`、`HttpStatusText` 和多段 `WriteStr`；未知状态仍保留
原 fallback 语义。

### Checklist

- [x] RED：`test_http_h1writer` 先失败，证明 common status line 当前仍是
  多段写，`expected 2, got 6`。
- [x] RED：`test_http_benchmarks` 先失败，证明缺少
  `status lines common errors` row 与 known status-line source-contract。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1.writer`，新增
  `TryWriteKnownStatusLine`，常见状态走固定 status-line 常量写出，未知状态保留
  `IntToStr` / `HttpStatusText` fallback。
- [x] 在 `test_http_h1writer` 补 common status exact-wire/write-call proof、
  unknown `599 Unknown` fallback proof、fixed `431` short-writer proof。
- [x] 在 `bench_h1writer` 增加 `status lines common errors` row，并用
  `test_http_benchmarks` 锁住 row 与 source-contract。
- [x] 跑 focused gates：`test_http_h1writer`、`test_http_benchmarks`、
  `test_http_server`。
- [x] 跑小 benchmark smoke：`bench_h1writer` 的
  `status lines common errors` filter。
- [x] 更新 HTTP benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-06 http h1 writer compact header block slice

### Goal

推进 `nextpas.core.http` 的 H1 response header serialization 热路径：
让 `TH1ResponseWriter` 在小 header section 下把所有 header lines 与最终空行
聚合成一次 write-all invocation，减少 response header block 的 write 调用数；
大 header block 在写出前回退旧逐行路径，保持 wire bytes 与 short-writer 契约不变。

### Checklist

- [x] RED：`test_http_h1writer` 先失败，证明当前小 header block 仍是
  status line + 每条 header line + final CRLF 分开写。
- [x] RED：`test_http_benchmarks` 先失败，证明 `bench_h1writer` 缺少
  `headers block 200 6 headers` row，writer 也缺少 compact helper source-contract。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1.writer`，新增
  `WriteHeaderBlock` / `TryWriteSmallHeaderBlock`，小 header block 走栈缓冲聚合写，
  大块回退旧 `WriteAllHeaders` + `WriteCRLF`。
- [x] 在 `test_http_h1writer` 补 small-block 2 write-call proof 与 large-block
  fallback exact-wire proof。
- [x] 在 `bench_h1writer` 增加 `headers block 200 6 headers` row，并用
  `test_http_benchmarks` 锁住 row 与 source-contract。
- [x] 跑 focused gates：`test_http_h1writer`、`test_http_benchmarks`、
  `test_http_server`。
- [x] 跑小 benchmark smoke：`bench_h1writer` 的 `headers` filter。
- [x] 更新 HTTP benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-06 http h1 fast lazy header lookup slice

### Goal

推进 `nextpas.core.http` 的 H1 fast-path header block 细粒度 lazy access：
让 `TFastLazyHeaders.Get` / `Has` 在单 header lookup 时直接扫描 raw header
block，避免强制 materialize 完整 `THttpHeaders` store，同时保持 `GetAll` /
`ForEach` / `Count` / mutation 的完整 materialization 语义。

### Checklist

- [x] RED：`test_http_benchmarks` source-contract 先失败，证明
  `TFastLazyHeaders.FindRawFirstValue` / raw `Get` / raw `Has` 尚不存在。
- [x] GREEN：新增 raw first-value lookup helper，`Get` / `Has` 改为未 materialized
  时直接扫描 raw header block。
- [x] GREEN：修复 `IsValidHeaderValueFast(ALen=0)` 的 `SizeUInt` loop-bound
  underflow，空 header value 不再误触发 fast parser fallback。
- [x] 在 `test_http_h1fast` 补空 header value、case-insensitive lookup、`Get`
  首值、missing header、raw lookup 后 `Count` / `GetAll` materialization 的 focused proof。
- [x] 在 `bench_h1parser` 增加 `fast headers get host only` 与
  `fast headers foreach all` materialization-cost rows，并用 `test_http_benchmarks`
  锁住 row。
- [x] 跑 focused gates：
  `test_http_h1fast`、`test_http_benchmarks`、`test_http_server`。
- [x] 跑小 benchmark smoke：
  `bench_h1parser` 的 `fast headers` filter。
- [x] 更新 HTTP benchmark/API/control 文档并 path-limited commit。


## Active Session: 2026-06-06 http h1 parser request metadata cache slice

### Goal

推进 `nextpas.core.http` 的 llhttp adapter request metadata 热路径：
让 `TH1Parser` 在 header parse 完成时增量维护 `TH1RequestMetadata`，不再在
`BuildRequestMetadata` 中通过 `IHttpHeaders.Get/GetAll` 二次回扫 header store，
同时保持 public header store、重复 header 顺序、trailer 隔离和异常 framing 语义不变。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 source-contract，证明
  `BuildRequestMetadata` 不应再访问 `FHeaders.Get/GetAll`。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1.parser`，新增 parse-time
  pending metadata cache、首值 seen flags、headers-complete 发布边界和
  `Transfer-Encoding` combined value 校验。
- [x] 在 `test_http_h1parser` 补 split/duplicate watched headers 与 chunked trailer
  不污染 metadata 的 focused tests。
- [x] 跑 focused gates：
  `test_http_h1parser`、`test_http_benchmarks`、`test_http_server`。
- [x] 跑小 benchmark smoke：
  `bench_h1parser` 的 `request metadata` filter。
- [x] 更新 HTTP benchmark/API/control 文档并 path-limited commit。


## Active Session: 2026-06-06 http request path-only projection slice

### Goal

推进 `nextpas.core.http` 的 request-target materialization 热路径：
让 `THttpRequest.Path` / `RawQuery` / `QueryParam` 在常见 origin-form
request-target 下只做轻量 path/query projection，不再强制完整
`TUrl.ParseRequestTarget`，同时保持 `Req.Url` 的完整 URL record 语义。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 source-contract，证明 direct
  `Path` / `RawQuery` 不应直接调用 `EnsureUrlParsed`。
- [x] GREEN：只修改 `nextpas.core.http.message`，新增
  `EnsureRequestTargetParts`，absolute-form 仍回退完整 parser。
- [x] 在 `test_http_message` 补 origin-form、query/fragment、asterisk、
  authority-like、relative target、absolute target 和 invalid absolute port
  focused 回归。
- [x] 在 `bench_h1parser` 增加 `direct RawQuery` 与 `direct Path+RawQuery`
  rows，并用 `test_http_benchmarks` 锁住 row。
- [x] 跑 focused gates：
  `test_http_message`、`test_http_benchmarks`、`test_http_router`。
- [x] 跑小 benchmark smoke：
  `bench_h1parser` request filter 与 `bench_server --workload url_path`。
- [x] 更新 benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-06 http direct outbound response path slice

### Goal

推进 `nextpas.core.http` 的 HttpServer response-drain 热路径：
让 H1 server 的 threaded / poll response writer 直接写入 `IH1OutboundBuffer`，
去掉每个请求额外包一层 generic `TBufferedWriter` 的对象和内存缓冲成本。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 source-contract，要求 H1 server
  response path 不再出现 `CreateBufferedWriter(LOutbound as IWriter, 4096)`。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1` 的 server response path，
  threaded / poll 两条路径都把 `TH1ResponseWriter` 直接接到 `IH1OutboundBuffer`。
- [x] 保留 H1 client request writer 的 generic buffered writer，因为 client 路径是直接写 socket。
- [x] 跑 focused benchmark/source-contract gate：
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`。
- [x] 跑 server behavior/leak gate：
  `make -C tests/nextpas.core.http/test_http_server clean test`。
- [x] 跑小 benchmark smoke：
  `NEXTPAS_BENCH_MAX_ITERS=5000 NEXTPAS_BENCH_FILTER=plaintext make -C benchmarks/nextpas.core.http/bench_fullchain clean run`
  与 `bench_http_server --requests 512 --threads 1 --workload response_1k`。
- [x] 更新 benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-06 http request path direct-accessor slice

### Goal

推进 `nextpas.core.http` 的 HttpServer handler/router path 热路径：
给 `IHttpRequest` 增加直接 `Path` / `RawQuery` 访问器，让只需要路径/查询的
router、static、middleware、H1 client request writer 与 benchmark workload
不再通过整条 `Url` record projection 取字段。

### Checklist

- [x] RED：在 `test_http_message` 直接要求 `IHttpRequest.Path` / `RawQuery`。
- [x] GREEN：扩展 `IHttpRequest`、更新 IID、补 `THttpRequest` 实现和 mock 实现。
- [x] 将 router/static/middleware/logger/timeout/H1 client writer/`bench_server url_path`
  切到直接 `Path` / `RawQuery`。
- [x] 在 `bench_h1parser` 增加 `request lazy Url.Path access` 与
  `request direct Path access` 对比 row，并用 `test_http_benchmarks` 锁住 row。
- [x] 跑 focused API/behavior/benchmark gates 与小 benchmark row。
- [x] 更新 HTTP benchmark/API/control 文档并 path-limited commit。


## Active Session: 2026-06-06 http header lookup hot-helper inline slice

### Goal

推进 `nextpas.core.http` 的 header lookup 热路径性能切片，
把 `THttpHeaders.FindFirst`、`NeedsNormalize`、`NormalizeIfNeeded`
锁成 inline source contract，保持 public `IHttpHeaders` API 与 header
存储结构不变。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 header lookup hot helper inline source-contract。
- [x] GREEN：只修改 `nextpas.core.http.headers` 的三个短 helper 声明/实现。
- [x] 跑 focused benchmark/source-contract gate：
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`。
- [x] 跑 header behavior/leak gate：
  `make -C tests/nextpas.core.http/test_http_headers clean test`。
- [x] 跑小 header benchmark row：
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='Get hit' make -C benchmarks/nextpas.core.http/bench_headers clean run`。
- [x] 更新 benchmark/API/control 文档并 path-limited commit。


## Active Session: 2026-06-05 http h1 server policy-helper inline slice

### Goal

推进 `nextpas.core.http` 的 H1 server request-policy 热路径性能切片，
把 keep-alive、parser-error status、`Expect: 100-continue` 三个短 helper
锁成 inline source contract，不扩大到大型 header-policy evaluator 或 server
state-machine 函数。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 H1 server policy helper inline source-contract。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1` 的
  `ShouldKeepAlive`、`ParserErrorStatus`、`ShouldSendContinueResponse` 三个短 helper。
- [x] 跑 focused benchmark/source-contract gate：
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`。
- [x] 跑 server behavior/leak gate：
  `make -C tests/nextpas.core.http/test_http_server clean test`。
- [x] 跑 nextPas-only 小 server smoke：
  `build/projects/nextpas.core.http/bench_server/bench_http_server --requests 128 --threads 1 --workload adapter_no_url`。
- [x] 更新 benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-05 http h1 outbound hot-helper inline slice

### Goal

推进 `nextpas.core.http` 的 H1 response-drain 热路径性能切片，
先把 `TH1OutboundBuffer` 中极短且高频的
`PendingBytes` / `IsEmpty` / `Advance` 锁成 inline source contract，
不扩大到全局编译策略或大型 server state-machine 重构。

### Checklist

- [x] RED：在 `test_http_benchmarks` 新增 source-contract smoke，要求 H1 outbound hot helpers 带 `inline`。
- [x] GREEN：只修改 `nextpas.core.http.impl.h1.outbound` 的三个短 helper 声明/实现，并调整实现顺序避免 FPC inline note。
- [x] 跑 focused benchmark gate：`NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`。
- [x] 跑 focused behavior/leak gate：`make -C tests/nextpas.core.http/test_http_h1writer clean test`。
- [x] 跑小 benchmark row：`NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' make -C benchmarks/nextpas.core.http/bench_h1outbound run`。
- [x] 更新 benchmark/API/control 文档并 path-limited commit。

## Active Session: 2026-06-05 http benchmark completion-marker contract

### Goal

收束 `nextpas.core.http` benchmark harness 校准批次，让 server comparison
runner 不只报告速度，还证明每个 comparator 实际完成了目标请求数，并把
nextPas 当前 H1 fast-path 解释显式写入 raw output。

### Checklist

- [x] 复核当前 HTTP benchmark diff 与 shared checkout 脏文件边界，避免覆盖无关 async/client/compiler 改动。
- [x] 基于已有 RED，要求 server comparison 输出 `completed=<requests>`、nextPas row 输出 `nextpas_h1_path=...`，multi-run summary/report 输出 `median_completed=<requests>`。
- [x] 修正 `run_server_comparison.sh` summary 字段顺序，让 `median_completed` 来自 completed 列而不是 `ns/op` 列。
- [x] 跑 focused gate：`NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`。
- [x] 跑小规模 live runner smoke：`benchmarks/nextpas.core.http/run_server_comparison.sh --requests 8 --threads 1 --workload adapter_no_url --runs 2 --output build/projects/nextpas.core.http/server_comparison/adapter_no_url_completed_smoke.txt`。
- [x] 更新 benchmark/API coverage 文档；不写 `docs/nextpas.core.http.inbox.md`。

## Active Session: 2026-06-04 http max-header 431 backpressure security proof

### Goal

继续补 `nextpas.core.http` 的 direct-error raw-wire security proof，
把 `header field over MaxHeaderSize -> 431` 与
`request-target over MaxHeaderSize -> 431`
在 backpressure 尝试下的 safe-close 语义补进 `test_http_security`，
覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_security`、`test_http_server` 与 `API_COVERAGE`，确认
  generic `MaxHeaderSize` 两条 `431` 路径仍缺 security 层 direct raw-wire/backpressure 证据。
- [x] 新增 threaded / `epoll` 四条
  `header field` / `request-target over MaxHeaderSize`
  direct-error backpressure proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http write-timeout follow-up suppression trio

### Goal

继续补 `nextpas.core.http` 的 `HttpServer` write-timeout/backpressure
runtime contract，把 follow-up `413` / `431` / `417`
在首个大响应被背压卡住时“不应误漏到 wire” 的 live proof
补进 `test_http_server`，覆盖 threaded / Linux `epoll` 两条路径。

### Checklist

- [x] 对比 `test_http_server` 与 `API_COVERAGE`，确认
  `write-timeout backpressure does not emit follow-up` 目前只锁了
  `400` / `501`，而 `413` / `431` / `417` 仍缺 live 证据。
- [x] 新增 threaded / `epoll` 六条
  `follow-up 413/431/417 does not emit under write-timeout backpressure` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_server clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http truncated trailer field-line backpressure proof

### Goal

继续补 `nextpas.core.http` 的 malformed trailer raw-wire security proof，
把 `truncated trailer field line EOF direct-error backpressure safe-close`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server`、`test_http_security` 与 `API_COVERAGE`，确认
  该类 trailer EOF truncation 仍缺 security 层 direct raw-wire/backpressure 证据。
- [x] 新增 threaded / `epoll` 两条
  `truncated trailer field line EOF direct error backpressure safe handling` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http standalone 413 direct-error backpressure proof

### Goal

继续补 `nextpas.core.http` 的 direct-error raw-wire security proof，
把 `payload-too-large direct 413 backpressure safe-close`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server`、`test_http_security` 与 `API_COVERAGE`，确认
  security 层仍缺 standalone direct `413` 的 raw-wire/backpressure 证据，
  且不是重复已有 queued follow-up `413`。
- [x] 新增 threaded / `epoll` 两条
  `payload-too-large direct error backpressure safe handling` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http partial chunked body idle-timeout proof

### Goal

继续补 `nextpas.core.http` request-side `IdleTimeout` 的 runtime contract，
把 `chunked body` 数据段半包 stall 的 live close truth 补进
`test_http_security` 与 `test_http_server`，覆盖 threaded / Linux `epoll`
real-socket 与 poll-driven 两层证据。

### Checklist

- [x] 对比 `test_http_security`、`test_http_server` 与 `API_COVERAGE`，确认
  `partial chunked body stall` 仍缺 live / poll-driven focused 证据。
- [x] 新增 `test_http_security` threaded / `epoll`
  `partial chunked body idle-timeout closes connection` proof。
- [x] 新增 `test_http_server`
  `H1 poll-driven session times out partial chunked body read wait` proof。
- [x] 跑 focused gates：
  `make -C tests/nextpas.core.http/test_http_security clean test`
  与
  `make -C tests/nextpas.core.http/test_http_server clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http malformed chunked direct-error backpressure trio

### Goal

继续补 `nextpas.core.http` malformed chunked request 的 raw-wire security proof，
把 `invalid chunk-size`、`missing chunk-data CRLF`、`malformed trailer field`
这组三个 direct-error / backpressure safe-close 合同补进 `test_http_security`，
覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server`、`test_http_security` 与 `test_http_h1parser`，确认这组三个 malformed chunked case 仍缺 security 层 direct raw-wire/backpressure 证据。
- [x] 新增 threaded / `epoll` 六条
  `invalid chunk-size` / `missing chunk-data CRLF` / `malformed trailer field`
  direct-error backpressure proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http chunked-not-final backpressure security proof

### Goal

继续补 `nextpas.core.http` malformed chunked request 的 raw-wire security proof，
把 `Transfer-Encoding: chunked, gzip -> 400` 的 direct-error / backpressure safe-close
语义补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server`、`test_http_security` 与 `test_http_h1parser`，确认
  `chunked-not-final transfer-coding -> 400` 仍缺 security 层 direct raw-wire/backpressure 证据。
- [x] 新增 threaded / `epoll` 两条
  `chunked-not-final transfer-coding direct error backpressure safe handling` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http expect bodyless and duplicate-member security proof

### Goal

继续补 `nextpas.core.http` 的 `Expect: 100-continue` request-side raw-wire security proof，
把 duplicate-member 正向 interim 行为，以及 bodyless / no-length 变体的 no-interim
合同补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 duplicate-member 与 bodyless `Expect` 变体仍缺 security 层 direct raw-wire 证据。
- [x] 新增 duplicate `100-continue` interim proof，以及 `Content-Length: 0` / no-length `POST` / no-length `HEAD` 的 no-interim proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http queued follow-up 400 security proof

### Goal

继续补 `nextpas.core.http` 的 queued follow-up raw-wire security proof，
把 `malformed follow-up 400 preserves wire order`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 queued follow-up `400` 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `queued follow-up 400 preserves wire order` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http queued follow-up 413 security proof

### Goal

继续补 `nextpas.core.http` 的 queued follow-up raw-wire security proof，
把 `payload-too-large follow-up 413 preserves wire order`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 queued follow-up `413` 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `queued follow-up 413 preserves wire order` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http queued follow-up 431 security proof

### Goal

继续补 `nextpas.core.http` 的 queued follow-up raw-wire security proof，
把 `header-too-large follow-up 431 preserves wire order`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 queued follow-up `431` 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `queued follow-up 431 preserves wire order` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http queued follow-up 417 security proof

### Goal

继续补 `nextpas.core.http` 的 queued follow-up raw-wire security proof，
把 `unsupported Expect follow-up 417 preserves wire order`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 queued follow-up `417` 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `queued follow-up 417 preserves wire order` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http queued follow-up 501 security proof

### Goal

继续补 `nextpas.core.http` 的 queued follow-up raw-wire security proof，
把 `unsupported transfer-coding follow-up 501 preserves wire order`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 queued follow-up `501` 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `queued follow-up 501 preserves wire order` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http expect chunked security proof

### Goal

继续补 `nextpas.core.http` 的 `Expect + Transfer-Encoding: chunked` request-side raw-wire security proof，
把正向 `interim 100 -> final 200` 与 `interim 100 -> chunked MaxBodySize final 413`
两组 threaded / Linux `epoll` live 路径补进 `test_http_security`。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 `Expect + chunked` 正向/超限路径仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两组 `Expect chunked positive flow` 与 `Expect chunked MaxBodySize rejects after interim 100` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http expect positive-flow security proof

### Goal

继续补 `nextpas.core.http` 的 `Expect: 100-continue` request-side 正向 raw-wire security proof，
把 `interim 100 -> final 200`、`handler 只在 body 到达后进入`、以及 threaded / Linux `epoll`
两条 live 路径补进 `test_http_security`。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认正向 `Expect` flow 仍缺 security 层 direct raw-wire 证据。
- [x] 新增 threaded / `epoll` 两条 `Expect positive flow sends interim 100 before final 200` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http expect early-reject security proof

### Goal

继续补 `nextpas.core.http` 的 `Expect` request-side early-reject raw-wire security proof，
把 `declared oversize -> final 413 without interim 100` 与
`repeated Expect headers + unsupported member -> final 417 without interim 100`
补进 `test_http_security`，覆盖 threaded / Linux `epoll` 两条 live 路径。

### Checklist

- [x] 对比 `test_http_server` 与 `test_http_security`，确认 `Expect` 早拒绝 contract 在 security 层仍缺 direct raw-wire 证据。
- [x] 新增 declared oversize 与 repeated-Expect unsupported-member 两组 threaded / `epoll` security proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http unsupported-expect backpressure proof

### Goal

继续补 `nextpas.core.http` direct-error / early-reject 的 raw-wire security proof，
把 `unsupported Expect -> 417` 的 backpressure safe-close 语义补进 `test_http_security`，
覆盖 threaded / Linux `epoll` 两条 live 路径，只跑 focused gate，不改生产代码，除非先打出真实 RED。

### Checklist

- [x] 复核 server/security 对 `unsupported Expect -> 417` 的现有证据，确认 security 层仍缺 direct raw-wire/backpressure proof。
- [x] 新增 threaded / `epoll` 两条 `unsupported Expect direct error backpressure safe handling` 用例。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http fixed-length eof truncation epoll parity

### Goal

继续补 `nextpas.core.http` request-body framing 的 raw-wire security proof，
把 `Truncated Content-Length request body at EOF -> 400` 收到 Linux `epoll` live parity，
仍然只跑 `test_http_security` focused gate，不改生产代码，除非测试先打出真实 RED。

### Checklist

- [x] 复核 `test_http_security` / `API_COVERAGE`，确认 fixed-length body EOF truncation 仍缺 `epoll` raw-wire proof。
- [x] 新增 `Truncated Content-Length request body at EOF -> 400 with epoll backend`。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http request validation epoll parity

### Goal

继续补 `nextpas.core.http` request-side raw-wire security proof，
把 generic malformed / host/version/path/method/content-length 边界补到 Linux `epoll`
live parity，仍然只跑 `test_http_security` focused gate，不改生产代码，除非先打出真实 RED。

### Checklist

- [x] 复核 shared checkout 脏状态与当前 HEAD，确认 EOF truncation 批次已提交，不重复收口。
- [x] 对比 `test_http_security` 默认 backend / `epoll` 注册项，筛出仍缺的 request validation gap。
- [x] 新增 `generic malformed`、`null-byte header`、`HTTP/0.9`、`CRLF injection`、
  `missing Host`、`very long method`、`body larger than Content-Length` 的 `epoll` proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若仍是 coverage-expansion，则只更新记录并 path-limited commit。

## Active Session: 2026-06-04 http eof truncation epoll parity

### Goal

继续补 `nextpas.core.http` request-line/header parse boundary 的 Linux `epoll` raw-wire proof，
本轮只收 request-line EOF truncation 与 headers EOF truncation 两条 explicit `400` 契约。

### Checklist

- [x] 过滤 security parity gap，确认这两条 parser-boundary case 仍缺 `epoll` live proof。
- [x] 新增 request-line EOF 与 headers EOF 的 `epoll` 用例。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 只记录 current truth，并做 path-limited commit。

## Active Session: 2026-06-04 http content-length validation epoll parity

### Goal

继续补 `nextpas.core.http` request-side header validation 的 Linux `epoll` raw-wire proof，
本轮只收 `duplicate Content-Length` 与 `negative Content-Length` 这两个高价值验证契约。

### Checklist

- [x] 过滤 security parity 假 gap，确认这两条仍缺 `epoll` live proof。
- [x] 新增 `Duplicate Content-Length` 与 `Negative Content-Length` 的 `epoll` 用例。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 只记录 current truth，并做 path-limited commit。

## Active Session: 2026-06-04 http cl-te epoll smuggling proof

### Goal

继续收口 `nextpas.core.http` raw-wire security proof，把 request smuggling 核心防线
`Content-Length + Transfer-Encoding` conflict 两种 header 顺序补到 Linux `epoll` live parity。

### Checklist

- [x] 机器比对 `test_http_security` default / `epoll` 注册项，筛出高价值 parity gap。
- [x] 新增 `CL+TE` 与 `TE+CL` 两个 `epoll` raw-wire proof。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 不改生产代码，只记录 current truth 并 path-limited commit。

## Active Session: 2026-06-04 http chunked max-body epoll parity

### Goal

继续补 `nextpas.core.http` 的 malformed/limit raw-wire security proof，
把 `Chunked MaxBodySize rejects before terminal chunk` 的 Linux `epoll` live parity 锁进
`test_http_security`，不改生产代码，除非测试先打出真实 runtime RED。

### Checklist

- [x] 对比 `test_http_security` 默认 backend / `epoll` case 清单，定位 still-missing 的 raw-wire gap。
- [x] 复用现有 chunked `MaxBodySize` case，补 `epoll` parity 用例。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 若只是 coverage gap，则只更新记录并 path-limited 提交。

## Active Session: 2026-06-04 http malformed chunk extension epoll parity

### Goal

继续收口 `nextpas.core.http` 的 malformed chunked raw-wire security proof，
只补 `Malformed chunk extension -> 400` 的 Linux `epoll` live parity，不扩散到无关模块。

### Checklist

- [x] 对比 parser / server / security 三侧 case 清单，确认这条是还没被 `test_http_security` 锁住的 raw-wire gap。
- [x] 补 `test_http_security` 的 `epoll` case。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 记录这条 proof 已补齐；若 runtime 已经正确，则不改生产代码。

## Active Session: 2026-06-04 http fixed-length 413 proof tightening

### Goal

在 `nextpas.core.http` 继续做 correctness / coverage 收口，不改生产代码，先把
fixed-length request body 的 `MaxBodySize` runtime contract 从“`413` 或安全关闭”收紧成
explicit `413 Payload Too Large`，并补齐 threaded / Linux `epoll` 两条路径的 focused proof。

### Checklist

- [x] 重读 HTTP 规范/覆盖矩阵与 shared checkout 脏状态，确认只碰 `nextpas.core.http` 相关文件。
- [x] 复核上一刀未提交的 `test_http_server` / `test_http_security` diff。
- [x] 跑 focused gate：`make -C tests/nextpas.core.http/test_http_security clean test`。
- [x] 在覆盖矩阵与控制文件中记录 fixed-length `MaxBodySize -> explicit 413` 的 current truth。
- [x] path-limited stage / commit，不带入无关 dirty 文件。

### Exit Criteria

- `test_http_server` 与 `test_http_security` 都保留 focused 证明：
  - fixed-length oversize body 返回 explicit `HTTP/1.1 413`
  - handler 不会被误调用
  - Linux `epoll` backend 语义与 threaded 一致
- 本轮不跑全量；只要 focused gate 绿且 `heaptrc = 0 unfreed memory blocks`，就按 current truth 收口。

## Active Session: 2026-06-04 compiler worktree/branch cleanup classification

### Goal

按用户要求接手编译器相关 branch/worktree 清理，但先只做安全分类，不合并、不删除、不改源码：

- 一个分支一个分支审查相对 `main` 的提交、diff、涉及文件和 worktree dirty 状态
- 识别哪些已经被 `main` 吸收、哪些有价值但需要整理后合并、哪些应 archive、哪些还不确定
- 保护当前 `main` 工作区已有脏改动，后续合并必须走隔离候选路径和编译器验证

### Checklist

- [x] 读取现有 `/plan`、`findings.md`、`progress.md` 与 compiler goal tree，确认当前路线图语境。
- [x] 复核 `main` 工作区 dirty 状态和目标 worktree 是否仍存在。
- [x] 逐分支采集 `main...branch`、提交列表、diff 文件范围和 worktree status。
- [x] 输出四类分类表：已合并可删 / 有价值需整理 / 实验需 archive / 不确定需继续审查。
- [x] 将本轮分类依据、风险和下一步写回 `findings.md` / `progress.md`。

### Initial classification

- 已合并可删：当前 6 条里暂无。没有任何目标 branch 的 tip 已进入 `main`，也没有任何一条对 `main`
  全部 patch-equivalent。
- 有价值但需要整理后合并：
  - `codex/compiler-c8-np-allocator-20260604`
  - `codex/compiler-truth-audit-main-20260603`
  - `codex/compiler-truth-integration-20260604-main0915`
- 实验/不建议合并但要 archive：
  - `backup/accidental-mixed-commit-20260603`
  - `backup/sema-no-matching-overload-before-rebase`
- 不确定，需要继续审查：
  - `fix/sema-include-resolver`

### Evidence summary

- `codex/compiler-c8-np-allocator-20260604`
  - `main...branch = 54:12`
  - worktree dirty，另有 target unit facade 与 compiler tests untracked
  - 包含 `compiler-truth-integration` 的 4 个 committed commits，并继续推进到 `C6-A / C8-F`
- `codex/compiler-truth-audit-main-20260603`
  - `main...branch = 172:18`
  - worktree clean
  - 计划记录证明它是 stage0/toolchain truth audit 的 canonical lane，但尚未被 `main` 或 C8 吸收
- `codex/compiler-truth-integration-20260604-main0915`
  - `main...branch = 54:4`
  - committed HEAD 是 `compiler-c8-np-allocator` 的祖先
  - worktree dirty/staged，包含 audit absorption 草稿与 `compiler/ir/np_hir_builder.pas` WIP
- `fix/sema-include-resolver`
  - `main...branch = 1540:1`
  - worktree clean
  - 单提交很旧，包含 include resolver 与 imported-source interface-only parsing；需要确认是否仍适合当前 imported-unit body/sema truth
- `backup/accidental-mixed-commit-20260603`
  - `main...branch = 148:1`
  - 无 worktree
  - 单提交跨 compiler 与 core HTTP/net server，属于 accidental mixed commit，不应整合
- `backup/sema-no-matching-overload-before-rebase`
  - `main...branch = 2249:2`
  - 无 worktree
  - 当前 `main`/C8 已有大量 no-matching/ambiguous/wrong-argument semantic coverage；保留作历史备份，不建议合并

### Errors encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| branch relationship script passed a pair string as one Git revision | first relationship matrix run | discarded output and rewrote the check with explicit branch variables |
| zsh rejected Bash array index syntax | second relationship matrix run | reran the read-only relationship check under Bash |

### Constraints

- 本阶段不移动 `main`，不合并、不删除 worktree/branch，不创建 archive tag。
- 后续任何真正合并都必须先在隔离候选 worktree 整理干净提交，再跑 focused compiler tests、`scripts/rebuild-compiler.sh`、相关 smoke；语义/LLVM 路径变化需完整 LLVM smoke。
- 当前 `main` 工作区已有无关 dirty 改动，本轮只读审查不得覆盖或 stage 这些改动。

## Active Session: 2026-06-04 local branch cleanup

### Goal

清理 VSCode 分支选择面板里的本地 branch 噪音，但只做不会丢代码的安全删除：

- 先删除已经并入 `main` 的本地分支
- 再删除虽未进 `main`、但已被别的保留分支完整包含的冗余分支
- 不触碰仍需代码审查的未合并分支

### Checklist

- [x] 重新盘点 live worktree 与本地 branch 数量，避免沿用过期判断。
- [x] 删除 `tip ∈ main` 且不被 live worktree 占用的本地分支。
- [x] 检查未并入 `main` 的分支里，哪些已被别的保留分支完整包含。
- [x] 删除确认冗余的非主线分支，并复核剩余 branch/worktree 状态。

### Current Verdict

- 本轮 branch cleanup 前：
  - 本地分支 `96`
  - live worktree `4`
- 已安全删除的第一批 merged local branches：`43`
  - 条件：`tip` 已被 `main` 吸收、不是 `main`、不在任何 live worktree 上
- 已安全删除的第二批 contained branch：`1`
  - `feat/platform-pty`
  - 取证：`feat/platform-pty` 是 `codex/platform-pty-integration` 的祖先，反向不成立
- 已安全删除的第三批 patch-equivalent branches：`28`
  - 条件：`git cherry -v main <branch>` 结果全为 `-`
  - 含义：这些分支虽未以祖先关系并入 `main`，但提交内容已被 `main` 等价吸收，只剩 branch ref 噪音
- 已安全删除的第四批 docs/redundant refs：`2`
  - `docs/cross-module-workflow`
    - 只有 1 个 docs commit，且 earlier audit 已确认内容带危险 git 建议
  - `codex/io-cursor-csv-streaming`
    - 代码面已基本被 `codex/data-format-streaming-ini` 吸收
    - 相对 `codex/data-format-streaming-ini` 只剩 `docs(http): plan phase 2 runtime hardening` 这一条 docs commit
- 本轮 branch cleanup 后：
  - 本地分支 `22`
  - `main` 之外剩余 `21` 个分支全部尚未并入 `main`
- 当前 live worktree 需按实时 Git 状态认定为 `4` 个，而不是 earlier notes 里的 `3` 个：
  - `main`
  - `codex/compiler-truth-audit-main-20260603`
  - `codex/window-sdl2-backend-20260602`
  - `fix/sema-include-resolver`
- 当前剩余的 21 条非主线分支已基本收敛到“真实保留线 / live lane / 需人工价值判断的 archive 线”。
- 下一轮如果继续清理分支，应只做 branch-by-branch review，不再有大批量无脑安全删除空间。

## Active Session: 2026-06-04 worktree merge audit batch 1

### Goal

审查第一批 5 个 `clean` worktree 是否需要合并回 `main`，避免因为会话中断或同事
切换后遗漏已完成代码。本轮只做证据化审查和整理建议，不直接删除 worktree，不做
源码修改。

### Checklist

- [x] 复核当前 root checkout 与 worktree 边界，确认本轮只读审查，不碰脏 lane。
- [x] 采集首批 5 个 worktree 相对 `main` 的独有提交、改动文件和提交主题。
- [x] 检查这些提交是否已被 `main` 或其他活跃分支吸收，筛出遗漏风险。
- [x] 对每个 worktree 给出结论：应合并 / 不应合并 / 需人工确认。
- [x] 产出建议的处理顺序，便于后续安全合并或归档。

### Batch 1 conclusion

- `perf/chacha20poly1305-fused-scout`
  - 2 个独有提交，已验证，但分支自身结论是 benchmark 无正收益，production 继续 default-off。
  - 结论：不作为主线必合代码；保留为 perf/archive scout。
- `codex/collections-refactor`
  - 2 个独有提交，范围小，focused collections tests 通过。
  - 但第二个提交把 `PPtrIter/TPtrIter` 暴露为 facade public surface，需再确认这是否真是想公开的 contract。
  - 结论：适合摘小批次；优先考虑 cherry-pick `TCollection/TCollectionClass`，iterator export 需再确认。
- `codex/compiler-truth-audit-main-20260603`
  - 17 个独有提交，branch 自身记录它是 compiler truth 的 canonical lane，不是已被 `main` 吸收的 side lane。
  - 结论：不能删；需要独立 integration batch 合回 `main`。
- `codex/config-branch-triage-20260604`
  - worktree 与 branch ref 当前都已不存在，只剩 dangling commit `c6669009`。
  - commit 内容只是 config 清理计划文档，不含源码。
  - 结论：无代码 merge 需求；仅在想保留清理文档时再摘。
- `codex/core-strict-review-20260601`
  - 125 个独有提交，跨度覆盖 log/async/io/process/platform/fs/tests/examples/benchmarks。
  - 最新记录显示它仍是长期 strict-review 汇流线，不是单一可整体合并的小分支。
  - 结论：不能整体 merge；后续按模块/验证闭环拆批摘取，Process closeout 可作为优先候选。

### Constraints

- 这轮不改源码，不删除 worktree，不重写历史。
- 只用 `git log` / `git diff` / `git cherry` / `git branch --contains` 一类只读证据做判断。
- 根 checkout 当前有 unrelated dirty 状态；不得把 repo 内 worktree 目录噪音误判成待合并代码。

## Active Session: 2026-06-04 full worktree triage and selective merge

### Goal

把当前 `nextPas` 全部活跃 worktree / branch 做一轮完整合并审计：

- 好的、值得保留的差异才进入 `main`
- 不值得保留、无收益或已被吸收的差异直接放弃/归档
- 合并后逐个移除已完成 worktree，降低后续维护噪音

### Checklist

- [x] 重新盘点当前全部 worktree 的实时状态，防止沿用过期清单。
- [x] 为每个活跃分支建立结论：`merge` / `archive` / `discard` / `investigate-more`。
- [x] 对 `merge` 候选采用最小可审计路径：优先摘提交，不做无脑整支 merge。
- [x] 在隔离 integration 工作区落主线代码，并逐批做 focused verification。
- [x] 每吸收一批就清理对应 worktree / branch，并复核 Git 状态与剩余 backlog。

### Current Status

- 已创建隔离 integration worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/worktree-triage-integration-20260604`
  on `codex/worktree-triage-integration-20260604`。
- 已吸收并验证的主线候选：
  - `9c96305b refactor(core): export collections skeleton types from facade`
    - 保留的真实价值是 facade test，不重复导出当前 `main` 已有的 public types。
    - focused verification:
      `make -C core/tests/nextpas.core.collections/test_facade clean test`
  - `83c6a83b feat(fs): add recursive CopyDir`
    - focused verification:
      `make -C core/tests/nextpas.core.fs/test_fs clean test`
  - `1e2bea56 feat(os): add GetHomeDir`
    - focused verification:
      `make -C core/tests/nextpas.core.os.env/test_os_env clean test`
  - `89b9944f test(crypto): guard x509verify UTC time source`
    - focused verification:
      `make -C core/tests/nextpas.core.crypto/test_x509verify_source_guard clean test`
  - `bc046e86 test(crypto): cover x509 validity windows`
    - focused verification:
      `make -C core/tests/nextpas.core.crypto/test_x509verify clean test`
- `fpdev-core-copydir` 的第三个提交 `90306fd6 feat(hash): add file hex helpers`
  在 integration worktree 里 cherry-pick 为空；取证确认 current main 已有等价提交
  `1fbef90c feat(hash): add file hex helpers`，因此该提交按“已吸收”处理而不是重复落地。
- 已完成第一批安全清理：
  - 删除 worktree + branch:
    `fpdev-core-copydir`,
    `codex/collections-refactor`,
    `codex/datetime-now`,
    `feat/crypto-migrate`,
    `feat/fix-remaining`,
    `codex/platform-pty-main-merge`,
    `codex/compiler-truth-audit-20260603`
  - 其中 `codex/datetime-now` 删除前已人工审过 dirty state：
    真实有价值的未提交差异是 `x509verify` validity-window tests，已用更稳的
    `TCertificateUtils` 路径吸收到 integration branch；剩余删除 inbox / planning 漂移 /
    误导性的 `DateTimeNow` UTC 注释被明确丢弃。
- 已完成第二批减噪但保留 branch 历史的清理：
  - 仅移除 worktree checkout，保留 branch ref:
    `perf/chacha20poly1305-fused-scout`,
    `perf/aesgcm-fused-debug`,
    `docs/cross-module-workflow`,
    `feat/crypto-polish`,
    `codex/io-cursor-csv-streaming`
  - 其中 `feat/crypto-polish` 复核确认没有源码 diff，只有 planning 文件和测试二进制产物。
- `codex/window-sdl2-backend-20260602` 已完成 dedicated audit：
  - 在临时 worktree
    `/home/dtamade/.config/superpowers/worktrees/nextPas/worktree-triage-integration-window-20260604`
    上，把 5 个图形栈提交转存到 `codex/worktree-triage-integration-20260604`
  - 转存后的 integration commits:
    `904c7b8b`,
    `3aa1d952`,
    `4c0a155b`,
    `34dfaade`,
    `7ce965bf`
  - 所有 cherry-pick 冲突都只发生在 `docs/inbox.md`；保留 integration 侧版本，因为
    原 branch 那份是 lane-local 图形栈看板，不是代码或共享主线文档
  - focused verification 已覆盖：
    `test_window_surface`,
    `test_window_sdl2_loader`,
    `test_window_sdl2_smoke`,
    `test_gpu_gl_smoke`,
    `test_gpu_atlas_surface`,
    `test_gpu_gl_atlas_smoke`,
    `test_text_font_bitmap`,
    `test_text_shaper_fixed`,
    `test_text_glyph_atlas_surface`,
    `test_gpu_cell_surface`,
    `test_gpu_gl_cell_smoke`
    全部通过，heaptrc 为 `0 unfreed memory blocks`
  - 以这 5 个 commits 触达的 `40` 个 code/test 路径逐文件比对，original branch tip 与
    integration tip 完全一致；唯一故意不带过去的是 `docs/inbox.md`
  - 已删除原 worktree/branch `codex/window-sdl2-backend-20260602`，并删除临时 integration worktree
- 当前 live worktree 数量已从早期清理前的 `26` 收敛到 `3`：
  - `main`
  - `codex/compiler-truth-audit-main-20260603`
  - `fix/sema-include-resolver`

## Current Single-Worktree Audit: codex/core-tls-rtl-main-20260603-final

### Goal

只审 `codex/core-tls-rtl-main-20260603-final` 这一条 TLS lane，判断它能否单独作为
merge 锚点，或者是否仍缺 `base/refresh` 中的有效提交。

### Checklist

- [x] 检查 `final` / `base` / `refresh` 三条 TLS worktree 的 clean/dirty 状态。
- [x] 列出 `final` 相对 `main` 的独有提交和改动面。
- [x] 复核 `base/refresh` 相对 `final` 是否还有未吸收的已提交 TLS commits。
- [x] 区分 `base/refresh` 的“已提交缺口”和“未提交本地草稿”。
- [x] 把 5 个缺失的已提交 TLS follow-up 逐个 cherry-pick 到 `final`，按文件价值解冲突。
- [x] 跑 focused verification，确认收口后的 `final` 主题是绿的。
- [x] 复核并吸收/丢弃 `base` / `refresh` 的 replay dirt，避免误删有用代码。
- [x] 在确认无独有价值后，删除冗余 `base` / `refresh` worktree 与 branch。
- [ ] 在不碰同事编译器 WIP 的前提下，为 consolidated TLS lane 找到安全落 `main` 的入口。

### Current Verdict

- `codex/core-tls-rtl-main-20260603-final` 已不再只是 review anchor，而是当前唯一保留下来的 TLS consolidation lane。
- 原先 `base/refresh` 比 `final` 多出的 5 个已提交 TLS follow-up 已全部吸收到 `final`：
  - `86afb4a9` 吸收 `4c812194 refactor(tls.winssl): route session time checks through nextpas time`
  - `959b1bee` 吸收 `060498e6 fix(tls): use UTC for backend days-until-expiry helpers`
  - `98a475d0` 吸收 `2e6362a6 refactor(tls): route operational timestamps through nextpas time`
  - `162d920d` 吸收 `8fc77c8d fix(tls): avoid premature expiry rotation events`
  - `493a9b43` 吸收 `6882e821 refactor(tls): route capability helpers through nextpas text`
- 在 focused build 里额外暴露了一个真实收口遗漏：
  - `nextpas.core.tls.logging.pas` 重复 `uses nextpas.core.time`
  - 已用 follow-up commit `3f940bea fix(tls): drop duplicate time import from logging` 修正
- focused verification 已覆盖这批吸收后的关键面：
  - `test_certificate_validity_utc_contract`
  - `test_mbedtls_certificate_text_conv_contract`
  - `test_session_time_wrapper_adoption_contract.sh`
  - `test_backend_certificate_days_until_expiry_utc_contract`
  - `test_winssl_session_time_wrapper_contract`
  - `test_operational_time_wrapper_adoption_contract`
  - `test_capability_rtl_escape_contract`
  - `test_http2_alpn_time_contract`
  - `test_verify_custom_rtl_escape_contract`
  - `winssl/test_winssl_certificate_days_until_expiry_utc` 在 Linux 仅 compile + runtime skip，符合平台条件
  - 所有实际运行项均通过，heaptrc 为 `0 unfreed memory blocks`
- `base` / `refresh` 的未提交 dirt 已证实没有独有价值：
  - `verify.custom` replay 与 `final` 已吸收版本一致，测试副本相同或更弱
  - `http2.alpn` replay 反而停留在 `DateUtils.SecondsBetween`，弱于 `final` 的 `DateTimeSecondsBetween`
- 基于上面的证据，`codex/core-tls-rtl-main-20260603` 与 `codex/core-tls-rtl-main-20260603-refresh`
  worktree/branch 已删除；TLS 组只保留 `codex/core-tls-rtl-main-20260603-final`
- 当前没有直接把它 fast-forward 到 `main`，原因不是代码还不稳，而是 root `main` checkout 正带着同事的
  编译器与 planning 脏改动；此时移动 `main` 会碰到用户明确要求不要动的范围

### Constraints

- 不允许把“clean worktree”误当成“值得合并”。
- 不允许为了省事把长线分支整支合入 `main`。
- 优先保留有 focused verification、范围清晰、public surface 可解释的提交。
- 对 benchmark 无正收益、默认关闭、纯 scout/probe 的线，默认归档而不是合主线。
- 用户最新明确约束：编译器相关 worktree 不在本轮负责范围内，由同事单独处理。
- 我这里后续不再触碰：
  - `codex/compiler-truth-audit-main-20260603`
  - `fix/sema-include-resolver`
- 后续只继续审非编译器线；编译器 lane 不再 merge、cleanup、也不再给处理建议。

### First-pass classification

- `discard/remove when safe`
  - `feat/crypto-migrate`: clean, fully merged into `main`.
  - `feat/fix-remaining`: clean, fully merged into `main`.
  - `codex/compiler-truth-audit-20260603`: side lane absorbed by `codex/compiler-truth-audit-main-20260603`; local dirt is planning-only.
  - `codex/platform-pty-main-merge`: PTY patchset is patch-equivalent to `feat/platform-pty`; keep one PTY line only.
  - `crypto-polish` worktree dirt is planning files + built test binaries, not new source.
- `archive/keep out of main`
  - `perf/chacha20poly1305-fused-scout`: branch itself concludes benchmark gain was not positive; keep as perf scout only.
  - `perf/aesgcm-fused-debug`: current phase explicitly says Windows production enablement is intentionally deferred; not a near-term mainline merge candidate.
  - `docs/cross-module-workflow`: docs-only and includes risky git advice (`reset --hard` to revert temporary cherry-picks); do not merge as-is.
- `merge candidates`
  - `codex/collections-refactor`: prefer cherry-picking `63d9880f` first; `87dc5d5c` iterator alias export needs separate API judgment.
  - `codex/datetime-now`: committed slice is coherent and verified; branch also has local dirt, so only the committed change should be considered first.
  - `fpdev-core-copydir`: 3 focused, verified slices (`CopyDir`, `GetHomeDir`, file hash helpers) are good cherry-pick candidates.
  - `worktree-db-clients`: large but internally verified line; keep for later dedicated integration, not first batch.
- `investigate-more`
  - `feat/platform-pty`: clean base PTY feature line; prefer as the surviving PTY base, but verify before landing.
  - `codex/platform-pty-integration`: dirty upgrade line on top of PTY base; keep only if it contains reviewed value beyond `feat/platform-pty`.
  - `codex/data-format-streaming-ini`: likely the upgraded data-format line; review after using it to subsume `codex/io-cursor-csv-streaming`.
  - `codex/io-cursor-csv-streaming`: mostly patch-equivalent to `codex/data-format-streaming-ini`; only unique commit is `docs(http): plan phase 2 runtime hardening`.
  - `codex/math-simd-harmonize-20260601`: candidate foundation line for math/fafafa migration; needs separate scope judgment.
  - `codex/core-strict-review-20260601`: multi-theme long line; extract small verified slices only.
  - TLS cluster:
    - `codex/core-tls-rtl-main-20260603-final` is the cleanest review anchor.
    - `codex/core-tls-rtl-main-20260603` / `refresh` still carry 5 unabsorbed TLS-related commits plus local dirt; do not delete before reconciling those deltas.
  - `codex/platform-host-ffi-wave15-helper-names`: branch tip is merged, but local uncommitted Wave 15 renaming work is real source/test content and needs a keep/discard decision before removal.
  - update after current cleanup pass:
    - `codex/platform-host-ffi-wave15-helper-names` 已转成已提交 branch `b7df674f`，live worktree 已移除
    - `feat/platform-pty` clean base 已停车，保留 branch ref，避免和 `codex/platform-pty-integration` 双占 checkout
    - `codex/platform-pty-integration` 已完成 dedicated audit：
      只保留 `231ad0a6 test(core): add missing Makefiles for marshal/template/validation`
    - 该 worktree 其余 dirty diff 已明确判定为“重复追平 main”或“回退 main 现有质量”的退化改动，已丢弃
    - `codex/window-sdl2-backend-20260602` 已完成 dedicated audit：
      5 个图形栈 commits 已转存到 `codex/worktree-triage-integration-20260604`，
      code/test 路径逐文件一致性已证明，原 worktree/branch 已删除
    - 当前桌面上只剩 3 个 live worktree：
      `main`、`codex/compiler-truth-audit-main-20260603`、`fix/sema-include-resolver`

## Active Session: 2026-06-03 C5-P structured dispatched-call stabilization

### Goal

把 `shekVirtualCall` / `shekInterfaceCall` 接通之后出现的唯一 live red 一次收掉：
`llvm_full_oop` 里的 `Result := Sum div Count;` 不能再被 implicit-self bare-call
误判吞成单个 `Sum`。这轮不扩 scope，不加新 lowering kind，只修 call-shape 合同并保住
dual-track。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或并行 toolchain/targets/stage0 lane。
- [x] 写 RED：给 `Result := Sum div Count;` 增加 producer 用例，并用隔离入口确认不是别的历史测试干扰。
- [x] 定位根因：证明不是 builder/ABI 宽度，而是 implicit-self bare-call 误吞 `gnkBinaryExpression`。
- [x] 实现 GREEN：收紧 implicit-self call shape，并同时作用于 ordinary/dispatched member-call contract。
- [x] 跑 focused tests、完整重编译、`llvm_full_oop`、137 LLVM smoke。
- [x] 更新 `docs/inbox.md`、`compiler/docs/compiler-goal-tree.md`、`progress.md`，并准备 path-limited commit。

### Constraints

- 只改本轮需要的 `compiler/sema`、`compiler/tests` 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- 结构化表达式和旧 blob fallback 双轨必须保留；不能用局部特判掩盖 call-shape 根因。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

## Active Session: 2026-06-03 C5-N structured direct-call lowering

### Goal

把第一条真正 end-to-end 的结构化 call expr 接起来，停止继续按 RHS 特判堆分支。
这轮只做 direct free-function call，范围限定在 legacy ABI 兼容子集：
`i` / `p` 参数，`i64` / `ptr` 返回；旧 blob fallback 必须完整保留。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或并行 toolchain/targets/stage0 lane。
- [x] 收口 `shekCall` 合同：callee、paramKinds、arg children、return type、value class。
- [x] 在 sema 让 direct free-function call 产出 `ExprId`，同时保留旧 blob。
- [x] 让 pointer/class-return helper assignment 不再绕过 `ExprId` 挂接。
- [x] 在 builder 增加 `shekCall` lowering，只接受 legacy ABI 兼容子集；不兼容时回落 blob。
- [x] 跑 changed tests、完整重编译、137 LLVM smoke。
- [x] 更新目标树、`docs/inbox.md`、计划/进度文件，并准备 path-limited commit。

### Constraints

- 只改本轮需要的 `compiler/sema`、`compiler/ir`、`compiler/tests` 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- 这轮不进入 overload、member call、virtual/interface call、string/record/var-param call lowering。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address，不混用。
- 结构化表达式和旧 blob fallback 双轨必须保留；不能把“不支持”偷偷变成“没有 fallback”。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-M object-backed field-array value loads

## Active Session: 2026-06-03 C5-M object-backed field-array value loads

### Goal

在 C5-L 已经把 `FItems[i]` / `Self.FItems[i].A.B` 这类 current-class value-side
接上之后，把 object-backed 对称面补齐：`Other.FItems[i]`、
`Other.FItems[i].A.B`，并同时覆盖 local assign 与 `Result` assign。
这轮仍然不改 builder，只让 sema 对 object receiver 的 field-array 识别
同时服务 legacy blob 与 structured `ExprId`。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或并行 toolchain/targets/stage0 lane。
- [x] 重读 `compiler/docs/compiler-goal-tree.md`、`core/docs/design-conventions.md`、`docs/inbox.md`、memory 与根计划文件。
- [x] 写 RED：`Result := Other.FItems[i]`，确认 producer 因缺 `assign-runtime` 节点而失败（`exit=83`）。
- [x] 扩 focused coverage：补 direct/nested + local/result 四条 object-backed field-array value load producer 用例。
- [x] 在 sema 引入共享的 object-backed field-array 识别，并让 `BuildClassFieldArrayElementTargetExpr`、`ResolveArrayAccessElementTypeId`、`EncodeRuntimeIntExprFold` 复用。
- [x] 保持 builder 不改，只验证 address/value lowering 现有合同没有被带偏。
- [x] 跑 changed tests、完整重编译、137 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md`、`docs/inbox.md`、计划/进度文件，并准备 path-limited commit。

### Constraints

- 只改本轮需要的 `compiler/sema`、`compiler/tests` 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address，不混用。
- 结构化表达式和旧 blob 双轨必须保留；不能靠“只有 structured path”偷过当前 slice。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-L array-backed value loads

## Active Session: 2026-06-03 C5-L array-backed value loads

### Goal

在 C5-K 已经打通 `arr[i].A.B := rhs` 与 `Self.FItems[i].A.B := rhs`
结构化 target 之后，把对称的 value-side 收进来：`x := arr[i]`、
`x := arr[i].A.B`、`y := FItems[i]`、`y := Self.FItems[i].A.B`。目标不是改 builder，
而是修 producer 的发射门：即使结构化 `ExprId` 已经能建，也必须保留旧 blob fallback，
不能让 `assign-runtime` 因 blob 编码缺口而直接消失。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或并行 toolchain/targets/stage0 lane。
- [x] 重读 `compiler/docs/compiler-goal-tree.md`、`core/docs/design-conventions.md`、`docs/inbox.md`、memory 与根计划文件。
- [x] 稳定复现 `TestNestedFieldArrayValueExprProducer` 失败，确认不是 builder 红点，而是 producer 缺 `assign-runtime`。
- [x] 用调试证据确认 `Halt(261)` 被 FPC 截断为 exit `255`；根因是 `EncodeRuntimeIntExprFold` 对 current-class field-array value load 缺 blob。
- [x] 在 sema 补齐 `Self/FItems[i]` 与 `Self/FItems[i].Field` 的旧 blob 编码路径，保持 `AddScalarAssignRuntimeNode` 与结构化 `ExprId` 双轨。
- [x] 清理临时调试痕迹，恢复完整 `test_semantic_hir_expr_producer` main block。
- [x] 跑 changed tests、完整重编译、137 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md`、`docs/inbox.md`、计划/进度文件，并准备 path-limited commit。

### Constraints

- 只改本轮需要的 `compiler/sema`、`compiler/tests` 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address，不混用。
- 结构化表达式和旧 blob 双轨必须保留；不能靠“只有 structured path”偷过当前 slice。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-K nested array-backed field chains

## Previous Session: 2026-06-03 C5-K nested array-backed field chains

### Goal

在 C5-I/C5-J 已分别打通 `arr[i].Field := rhs` 与 `self.FItems[i] := rhs`
之后，把更深一层的 array-backed field chain 一次收口：
`arr[i].A.B := rhs` 与 `Self.FItems[i].A.B := rhs`。目标是统一 sema target
递归构造与 builder aggregate intermediate field address lowering，同时保留旧 blob
fallback，不碰同事的 toolchain/targets/stage0/verify truth lane。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或并行 toolchain/targets/stage0 lane。
- [x] 重读 `compiler/docs/compiler-goal-tree.md`、`core/docs/design-conventions.md`、`docs/inbox.md`、memory 与根计划文件。
- [x] 写 RED：producer 覆盖 `arr[i].A.B := y + 1` 与 `Self.FItems[i].A.B := y + 1`。
- [x] 写 RED：builder 覆盖 aggregate intermediate `shekField` address，不允许掉回 legacy `const:99/123`。
- [x] 在 sema 增加共享 `BuildTargetAddressExpr`，统一 nested array/field-array/record/class address tree。
- [x] 把 array-backed field store producer 收口成统一分流，fallback index 展平成 `index * elem_slots + field_offset`。
- [x] 在 builder 放行 aggregate intermediate `shekField` 的 address lowering，同时保留 value-load guard。
- [x] 跑 changed tests、9 个 focused compiler tests、完整重编译、137 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md`、`docs/inbox.md`、计划/进度文件，并准备 path-limited commit。

### Constraints

- 只改本轮需要的 `compiler/sema`、`compiler/ir`、`compiler/tests` 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address，不混用。
- 结构化表达式和旧 blob 双轨必须保留；失败时 builder 仍回落旧 operand/blob。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-K0 constructor arg classification redpoint

## Previous Session: 2026-06-03 C5-K0 constructor arg classification redpoint

### Goal

修复当前 LLVM verify 唯一稳定红点：`examples/smoke/test_obj_compose.pas`
中 `TRect.Create(P.GetX, P.GetY)` 把 `TPoint.GetX/GetY` 的 integer return value
按 `ptr` 传给 constructor。目标是收紧 constructor call argument classification：
参数类型应来自 callee signature / lowered expression result，而不是把 nested method-call
结果误判为 address/pointer。保持 `test_nested_method` 正常，保持旧 blob fallback。

### Checklist

- [x] 确认当前 `main` 与 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或同事的 toolchain/targets/stage0 lane。
- [x] 重读 `compiler/docs/compiler-goal-tree.md`、`core/docs/design-conventions.md`、`docs/inbox.md`、根计划文件。
- [x] 稳定复现 `test_obj_compose` LLVM verifier 失败，记录 `.ll` 错误位置与实际 call shape。
- [x] 对比 `test_nested_method` 的正常 lowering，限定问题在 constructor call argument classification。
- [x] 写 RED：focused compiler test 覆盖 constructor nested method-call integer args 不应按 `ptr` 发射。
- [x] 实现 GREEN：最小修复 constructor arg classification，保留 blob fallback，不扩大到无关 lowering。
- [x] 跑 focused tests、完整重编译、全量 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md`、`docs/inbox.md` 与必要计划文档。
- [x] path-limited stage/commit 本轮文件，并报告复盘和下一步。

### Constraints

- 只改本轮需要的 compiler/ir、compiler/sema、compiler/tests 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address，不混用。
- 结构化表达式和旧 blob 双轨必须保留；失败时 builder 仍回落旧 operand/blob。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-J field array target

### Goal

在 C5-I 已完成 `arr[i].Field := rhs` 之后，打通字段数组 `self.Items[i] := rhs`
这条更有价值的 lvalue chain。目标是让 legacy `__field_arr__` / `$ptr` 字符串暗号
开始收口到结构化 target：`shekArrayElem -> shekField(self.Items) -> index`。
旧 operand/blob fallback 必须保留。本轮不做更深 `arr[i].A.B`，不碰同事
toolchain/targets/stage0/verify truth lane。

### Checklist

- [x] 确认当前 `main` 与并行 dirty 边界：本轮不碰 `.claude/`、`.worktrees/`、`core/` 或 toolchain/targets/stage0 lane。
- [x] 重读 `compiler/docs/compiler-goal-tree.md`、`core/docs/design-conventions.md`、`docs/inbox.md`、根计划文件。
- [x] 复核 legacy field-array store：确认 `self.Items[i] := rhs` 当前如何编码 `__field_arr__` 与 builder fallback。
- [x] 写 RED：producer/builder 测试证明 field-array 缺结构化 `TargetExprId`。
- [x] 实现 GREEN：让 `shekArrayElem` 支持 base-address child，同时保留 symbol-backed array 路径。
- [x] 跑 changed/focused tests、完整重编译、全量 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md`、`docs/inbox.md` 与 C5-J plan 文档。
- [ ] path-limited stage/commit 本轮文件，并报告复盘和下一步。（/codex re-review: no blocking findings）

### Constraints

- 只改 C5-J 需要的 compiler/ir、compiler/sema、compiler/tests 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- `ExprId` 只表示 RHS value；`TargetExprId` 表示 LHS address，不混用。
- 结构化表达式和旧 blob 双轨必须保留；失败时 builder 仍回落旧 operand/blob。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-I array record field target

### Goal

在 C5-H 已完成 direct array element target/address 后，打通第一条嵌套 lvalue chain：
`arr[i].Field := rhs`。结构化形态应为 `shekField -> shekArrayElem -> index`，
旧 operand/blob fallback 保留。本轮不做 `self.Items[i]` 字段数组、不做
`arr[i].A.B` 更深链，也不碰同事 toolchain/targets/stage0/verify truth lane。

### Checklist

- [x] 确认当前 `main` 与并行 lane：本轮不碰 toolchain/targets/stage0/verify truth。
- [x] 复核 legacy array-of-record-field store：当前用 offset blob 表达 `index * elem_size + field_index`。
- [x] 写 RED：`arr[i].Y := y + 1` 缺结构化 `TargetExprId`，`test_semantic_hir_expr_producer` 退出 `173`。
- [x] 实现 GREEN：`shekArrayElem` 携带真实元素类型，`shekField` 可组合到 array element address。
- [x] 增加 builder 覆盖：nested target 成功时不解析 legacy `int 99` index blob。
- [x] 跑 focused tests、完整重编译、全量 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md` 和 `docs/inbox.md`。
- [x] path-limited stage/commit 本轮文件，并报告复盘和下一步。

### Constraints

- 只改 C5-I 需要的 compiler/ir、compiler/sema、compiler/tests 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- 结构化表达式和旧 blob 双轨必须保留；失败时 builder 仍回落旧 operand/blob。
- aggregate array element 只作为 address base 放行；value load 仍要求 concrete scalar HIR type。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-H static array target/address

### Goal

在 C5-H0 已经提供 static array bounds/backing storage 的基础上，把 direct static
array 的 `arr[i] := rhs` 与 `@arr[i]` 接到结构化 address/value 双轨。保持旧 blob
fallback；不进入字段数组、array-of-record-field、嵌套 lvalue chain，也不碰同事的
toolchain/targets/stage0/verify truth lane。

### Checklist

- [x] 确认当前 `main` 与并行 lane：本轮不碰 `compiler/toolchain/*`、`compiler/targets/*`、`tools/stage0/*`、`tests/toolchain/*`、`build/verify_local.sh` 等。
- [x] 复核 C5-G/C5-H0：builder 已能 lower static `shekArrayElem`，缺口集中在 producer。
- [x] 写 RED：static array store 缺 RHS `ExprId`，`test_semantic_hir_expr_producer` 退出 `246`。
- [x] 实现 GREEN：direct array element store producer 同时挂 RHS `ExprId` 与 LHS `TargetExprId`。
- [x] 补 static `@arr[i]` address producer 覆盖。
- [x] 跑 focused tests、完整重编译、全量 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md` 和 `docs/inbox.md`。
- [x] path-limited stage/commit 本轮文件，并报告复盘和下一步。

### Constraints

- 只改 C5-H proper 需要的 compiler/sema、compiler/tests 与状态文档。
- 不碰同事并行 lane：toolchain、targets、stage0、build/toolchain/target/profile、`build/verify_local.sh`。
- 结构化表达式和旧 blob 双轨必须保留；失败时 builder 仍回落旧 operand/blob。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Previous Session: 2026-06-03 C5-H0 static array foundation

### Goal

先修静态数组基础语义，再做静态数组结构化 target/address。当前 C5-G 已把动态数组
`arr[i] := rhs` 接入 `TargetExprId`，但静态数组仍缺 bounds 元数据和真实 backing storage；
直接迁移 target/address 会把错误语义结构化。

### Checklist

- [x] 确认 Git 状态：`compiler/` 当前无未提交改动；脏文件集中在 `.claude/`、`.worktrees/`、`core/`。
- [x] 重读 `core/docs/design-conventions.md`、`compiler/docs/compiler-goal-tree.md`、Claude memory、`docs/inbox.md`。
- [x] 建立本轮计划文档：`compiler/docs/plans/2026-06-03-c5h0-static-array-foundation.md`。
- [x] 写 RED 测试，证明静态数组 bounds/metadata/backing/index normalization 缺口。
- [x] 实现 C5-H0：parser bounds、sema static metadata、builder backing storage 和 low-bound normalization。
- [x] 跑 focused tests、完整重编译、全量 LLVM smoke。
- [x] 更新 `compiler/docs/compiler-goal-tree.md` 和 `docs/inbox.md`。
- [x] path-limited stage/commit 本轮文件，并报告复盘和下一步。

### Constraints

- 本轮只改 `compiler/`、`docs/inbox.md`、根目录计划文件；不碰 `core/` 并行工作。
- 结构化表达式和旧 blob 双轨必须保留；未迁移 producer 必须能回退。
- 改编译器后必须跑 `scripts/rebuild-compiler.sh`，确认 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以现有 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

### Prior Historical Plan

The following historical plan content is retained for recovery context.

# Task Plan: P0/P1 verification fidelity + unit resolution correctness

## Goal

按外部审查报告的优先级收口当前批次，把“看起来完整”推进到“结果可信、边界诚实、核心路径更正确”。

这轮收口标准不是再扩一批新架构名词，而是先把当前仓库最危险的两类问题关掉：

- `harness` / CI 不能再给出容易误导的假绿结果
- unit resolver 不能再漏掉根单元 implementation uses、错绑 unit 名，或让 synthetic
  `System` 遮蔽真实源码

同时，这轮还要把文档、规划文件和仓库卫生同步到真实实现状态。

说明：下面的 addendum 按时间保留当时的批次范围；当前 reality 以最新 addendum 与
fresh `bash build/verify_local.sh` 为准。

## Master Addendum: FPC Platform ABI Full Inventory

### Goal

最终目标是把 FPC 各平台可取证的系统 API、常量、结构体、opaque carrier、调用约定和 ABI
差异，系统性搬运到 nextPas-owned `platform.<host>.base/ffi` inventory 中，作为未来 nextPas
标准库、编译器和跨平台 runtime 的底座。

### Non-negotiable Rules

- `*.base` 只放 ABI 常量、结构体、record layout、opaque size/alignment、type alias 和 capability token。
- `*.ffi` 只放 raw external declaration、syscall declaration、FFI symbol binding，以及极薄的 ABI
  级错误/返回值投影；不得把跨平台 public contract、策略、业务语义或便利 API 放进 FFI。
- FPC source 是 reference authority，不是 production dependency；production platform code 不
  `uses Linux` / `UnixType` / `BaseUnix` / `PThreads` / `Windows` / `Syscall` 等 FPC RTL 单元。
- FPC 已有的平台 API、常量、结构和 ABI alias 视为正确来源；nextPas 不为这些 raw 定义额外写
  “证明 FPC 正确”的测试。验证只覆盖 nextPas 自己的集成边界：owner、命名、无 FPC RTL 依赖、
  编译连通、文档/路线可恢复。
- `platform.time` / `platform.sync` / `platform.thread` / future `platform.process` 是统一抽象层；
  它们消费 host `base/ffi`，但 raw ABI 不按 feature 建 `platform.<feature>.ffi`。
- 全量搬运必须按平台和 API family 分批落地：FPC source authority、owner decision、
  compile/coherence gate、docs/gap matrix、verify route 同步。不能把不属于 FPC 或未找到来源的 ABI
  伪装成已搬运。

### Work Breakdown

- Phase A: 固化 import workflow 和命名边界，先修正当前 Wave 6 中 raw FFI 与 helper/API 混淆。
- Phase B: 建平台清单：Linux / Android / Darwin / FreeBSD / generic Unix / Windows 分别列出 FPC
  source families、已搬运 API、未搬运 API、ABI 风险。
- Phase C: 按 API family 分波导入：process、file/path/stat、memory/mmap/virtual memory、
  dynamic loader、time/clock、thread/TLS、sync/wait、errno/last-error、socket/network、
  environment、filesystem metadata、terminal/console、signal/exception 等。
- Phase D: 对每个平台补 compile-only 或 simulated-host gate；真实 runtime 只测 nextPas unified
  public contract，不直接 runtime 单测 raw OS API。

当前最新本轮为 Platform Host ABI Completeness Wave 6；上一轮包括
Platform Host ABI Completeness Wave 5；
Platform Host ABI Completeness Wave 4；
Platform Host ABI Completeness Wave 3；
Platform Host ABI Completeness Wave 2；
Platform Host ABI Completeness Wave 1；
Platform FFI Import Workflow；
Platform FFI Source Evidence Index；
Platform Host Gap Route Guard；
Platform Host FFI Gap Matrix Guard；
Platform Facade Info Boundary；
Platform Sync Base Extraction；
Platform Thread Base Extraction、
Platform Sync Windows Wait-Address Public Result Boundary、
Platform Sync POSIX Wait-Bucket Policy Ownership、
Platform Sync POSIX Error Result Host Ownership、
Platform ABI Owner Audit And Gap Matrix、
Platform Behavior Tests Abstract API Boundary；
Platform Time Facade/Base/Host Shape Normalization；
Platform Sync Windows Busy-result Helper Ownership；
Platform Sync Windows Destroy Helper Ownership；
Platform Time Host-FFI Facade Collapse；
Platform POSIX Timeout Deadline Helper Ownership、
Collections Interface Ownership Normalization、
Platform POSIX Pthread Attr-init Shared Helper Ownership；
Platform POSIX Errno/Mutex Projection Shared Helper Ownership；
Platform POSIX Clock/Sync Shared Helper Ownership；
Platform Thread Shared POSIX Helper Ownership；
Platform Time Windows Math Helper Boundary；
Platform Sync Windows Timeout Result FFI Ownership、
Platform Sync POSIX Helper FFI Ownership、Platform Simulated Host Compile Matrix、Platform Windows ABI Type Leakage Ownership、Platform ABI Alignment Carrier Ownership、Platform Windows Timeout Conversion FFI Ownership、Platform Time Windows FILETIME Host FFI Ownership、Platform Thread Sleep EINTR FFI Ownership、Platform Sync Pthread Capability FFI Ownership、Platform Sync Host FFI Surface Guard、Platform Time Host FFI Surface Guard、Platform Thread Native Thread ID Host FFI Hardening、
Platform FFI Owner Boundary Guard、Platform Host-owned FFI Partitioning、Platform Sync FFI-owned Opaque Size Derivation、Platform POSIX FFI Target Matrix Hardening、Platform Sync POSIX Fallback Runtime Coverage、
Platform Sync FFI Surface Parity、Platform Thread L0 Surface Coverage、
Platform Time L0 Surface Coverage 与 Platform API Boundary Cleanup；Batch 103 Object Release
Invalid Trap Policy、Batch 102 Object Release Invalid Boundary、
Batch 101 Object Release Poison Contract、Batch 100 Object Release Valid Boundary、
Batch 99 Object Header Magic Validation、
Batch 98 Platform Time FFI Boundary、
Batch 97 Object Header Ownership Contract、
Batch 96 Object Allocation Helper Boundary 与 Batch 93 Platform Thread FFI Boundary 是并行
platform/core 工作流保留下来的已完成记录。

## Addendum: 2026-05-28 Platform Host ABI Completeness Wave 6

### Goal

目标节点：`G3: RTL、core 和 framework` / `G7: FreePascal compatibility 和生态迁移`。

继续按 `core/docs/platform-ffi-import-workflow.md` 扩充 host-owned raw ABI inventory。本轮聚焦
process control raw ABI：POSIX `fork` / `execve` / `waitpid` / `_exit` / `kill`，
以及 Windows `PROCESS_INFORMATION`、`STARTUPINFOA/W`、`SECURITY_ATTRIBUTES`、creation flags / priority class
tokens、`CreateProcessA/W`、`GetStartupInfoA/W`、`TerminateProcess`、
`GetExitCodeProcess` 与 `ExitProcess`。

本轮明确不创建 public `platform.process` contract，不新增 `platform.process.ffi`，
也不把 raw OS process-control API 作为 runtime unit test 目标。未来统一进程 API 应另起
public contract 设计，处理参数/环境编码、句柄生命周期、wait/kill 语义、错误模型和跨平台能力差异。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC
  platform/RTL units。
- 本轮不得再新增 host-specific `.ffi` 的 generic `platform_*` helper。`platform_*` 命名保留给统一
  public contract（如 `platform.time` / `platform.sync` / `platform.thread`）或明确的 shared
  POSIX owner（如 `platform_posix_*`）。Linux / Android / Darwin / FreeBSD / generic Unix
  既有 `platform_pthread_*` / `platform_process_id` 属于历史命名债；后续应单开 host FFI hygiene
  wave 迁到 `host_*` 或具体 host 前缀，不能在 Wave 6 里顺手大面积改名。
- Shared POSIX process-control raw externals 放在
  `nextpas.core.platform.posix.ffi`；Linux / Android / Darwin / FreeBSD / generic Unix
  `.ffi` 本轮不再暴露 `platform_process_*` selector helper，避免把 raw ABI inventory 伪装成
  unified public `platform.process` contract。
- Windows process-control record layout、flag/priority tokens、pointer aliases 归
  `nextpas.core.platform.windows.base`；kernel32 raw entrypoints 归
  `nextpas.core.platform.windows.ffi`。
- raw OS ABI 不做 runtime unit test，也不为 FPC 定义写正确性证明；本轮只做 FPC source authority
  记录、owner/命名边界、compile coherence 与 official verify route。

### Status

Pre-merge verified in isolated worktree; feature branch is ready to commit and
then needs integration into the latest safe `main` window.

- Worktree:
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave6-process`
- Branch: `codex/platform-host-abi-wave6-process`
- Base: `main@b14bd5a`
- Started: 2026-05-28 CST
- Parallel worktrees remain `collections-refactor` and `sema-no-matching-overload`; this
  wave must not touch them.

### Planned Steps

- [x] 从最新 `main@b14bd5a` 创建 `codex/platform-host-abi-wave6-process` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、Wave 5 test pattern 与现有 host
      base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 初步取证 POSIX / Windows process-control ABI
- [x] RED：新增 Wave 6 integration guard，要求 source-authority docs、owner/命名边界和 verify route
- [x] GREEN：更新 source-authority index、gap matrix、host ffi/base raw declarations
- [x] GREEN：修正 Wave 6 host-specific `.ffi` 中新增 generic `platform_process_*` helper 污染，新增/更新边界 gate
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [ ] commit feature branch and rebase latest `main`
- [ ] merge, post-merge verification, cleanup

### Audit Checklist

- [x] 不新增 `platform.process` public API，也不新增 feature-specific `platform.process.ffi`
- [x] `platform.time` / `platform.sync` / `platform.thread` 不消费本轮 raw process-control ABI
- [x] production platform units 不 `uses Linux` / `UnixType` / `BaseUnix` / `PThreads` /
      `Windows`
- [x] raw OS API 接受 FPC source authority，不写 runtime unit test；nextPas 只守 integration/compile gate
- [x] POSIX 与 Windows process-control family 分别归 host owner，不混成伪 POSIX
- [x] POSIX host `.ffi` 本轮不新增 `platform_process_*` unified-looking helper

### Baseline Evidence

- Worktree and `main` were clean before this wave resumed.
- `git worktree list --porcelain` confirmed only this worktree plus parallel
  `collections-refactor` and `sema-no-matching-overload`.
- Baseline focused gates passed before mutation:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
    `2 total, 2 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
    `4 total, 4 passed, 0 failed`.
- FPC source evidence found before implementation:
  - POSIX: `rtl/unix/oscdeclh.inc` declares `FpFork`, `FpExecve`, `FpWaitpid`,
    `FpExit`, and `FpKill` as libc `fork`, `execve`, `waitpid`, `_exit`, and
    `kill`; Linux/BSD syscall wrapper families also carry process-control
    wrappers.
  - Windows: `rtl/win/wininc/ascfun.inc` / `unifun.inc` declare
    `CreateProcessA/W` and `GetStartupInfoA/W`; `rtl/win/wininc/func.inc`
    declares `ExitProcess`, `TerminateProcess`, `GetExitCodeProcess`, and
    `WaitForSingleObject`; `rtl/win/wininc/struct.inc` carries
    `PROCESS_INFORMATION` and `STARTUPINFOA/W`; `rtl/win/wininc/defines.inc`
    carries process creation and priority constants.

### Verification

- Focused Wave 6 integration guard:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave6_process clean test`
  -> `5 total, 5 passed, 0 failed`.
- Adjacent platform integration guards:
  `test_platform_ffi_import_workflow` -> `2 total, 2 passed, 0 failed`;
  `test_platform_ffi_source_evidence_index` -> `2 total, 2 passed, 0 failed`;
  `test_platform_host_gap_matrix` -> `4 total, 4 passed, 0 failed`;
  simulated host compile matrix -> Darwin / Android / FreeBSD / generic Unix
  `status=pass`.
- Full branch verification:
  `make -C core test` -> `All tests passed.`;
  `make -C core examples` -> `All examples compiled.`;
  `make -C core benchmarks` -> `All benchmarks passed.`;
  `bash build/verify_local.sh` -> `verify-local=pass`,
  `human-summary=local verification passed`, final envelope includes
  `corePlatformHostAbiWave6ProcessCheck":"pass"`;
  `sh -n build/verify_local.sh` and `git diff --check` passed.

## Addendum: 2026-05-28 Platform Host ABI Completeness Wave 5

### Goal

目标节点：`G3: RTL、core 和 framework` / `G7: FreePascal compatibility 和生态迁移`。

继续按 `core/docs/platform-ffi-import-workflow.md` 扩充 host-owned raw ABI inventory。本轮聚焦
环境变量 ABI：POSIX `getenv` / `setenv` / `unsetenv` / `putenv`，以及 Windows
`GetEnvironmentVariableA/W`、`SetEnvironmentVariableA/W`、`GetEnvironmentStringsA/W`、
`FreeEnvironmentStringsA/W`、`ExpandEnvironmentStringsA/W`。

本轮明确不创建 public `platform.env` / `platform.process` contract，不新增
`platform.env.ffi` 或 `platform.process.ffi`，也不把 raw OS environment API 作为 runtime unit
test 目标。后续统一环境变量 API 应另起 public contract 设计。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC
  platform/RTL units。
- Shared POSIX environment external 与 thin helper 放在
  `nextpas.core.platform.posix.ffi`；Linux / Android / Darwin / FreeBSD / generic Unix
  `.ffi` 只暴露 host owner helper 并委托 shared POSIX helper。
- Windows environment entrypoints 归 `nextpas.core.platform.windows.ffi`；既有
  `LPSTR` / `LPWSTR` / `LPCSTR` / `LPCWSTR` / `BOOL` / `DWORD` ABI aliases 继续由
  `windows.base` 承载。
- raw OS ABI 不做 runtime unit test；本轮用 FPC source evidence、source-surface guard、
  simulated host compile matrix、Win64 compile-only gate 与 official verify route 证明。

### Status

Completed; merged to `main`, post-merge verified, and temporary worktree/branch cleaned up.

- Worktree:
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave5-env`
- Branch: `codex/platform-host-abi-wave5-env`
- Base: `main@46acefb`; rebased over latest `main@af4b8fb`; merged as
  `main@7c4db4a`
- Started: 2026-05-28 02:28:43 CST
- Parallel worktrees remain `collections-refactor` and `sema-no-matching-overload`; this
  wave does not touch them.

### Planned Steps

- [x] 从最新 `main@46acefb` 创建 `codex/platform-host-abi-wave5-env` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、Wave 4 test pattern 与现有 host
      base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 初步取证 POSIX / Windows environment ABI
- [x] RED：新增 Wave 5 source-surface gate，要求 evidence、host owner tokens 和 verify route
- [x] GREEN：更新 evidence index、gap matrix、host ffi declarations/helpers
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [x] commit feature branch and rebase latest `main`
- [x] merge, post-merge verification, cleanup

### Audit Checklist

- [x] 不新增 `platform.env` / `platform.process` public API，也不新增 feature-specific
      `platform.env.ffi` / `platform.process.ffi`
- [x] `platform.time` / `platform.sync` / `platform.thread` 不消费本轮 raw environment ABI
- [x] production platform units 不 `uses Linux` / `UnixType` / `BaseUnix` / `PThreads` /
      `Windows`
- [x] raw OS API 只通过 source-surface / compile gates 取证，不写 runtime unit test
- [x] POSIX 与 Windows environment family 分别归 host owner，不混成伪 POSIX

### Baseline Evidence

- `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`:
  `2 total, 2 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`:
  `4 total, 4 passed, 0 failed`.
- RED:
  `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave5_env clean test`
  compiled and failed as expected: `posix.ffi` lacks `getenv`, `windows.ffi`
  lacks `GetEnvironmentVariableA`, docs lack Wave 5 evidence, and
  `build/verify_local.sh` lacks the Wave 5 route.
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave5_env clean test`:
    `5 total, 5 passed, 0 failed`.
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    Darwin / Android / FreeBSD / generic Unix simulated host compile matrix all `status=pass`.
  - Adjacent gates passed: `test_platform_ffi_partition_surface`,
    `test_platform_posix_ffi_surface`, and `test_platform_ffi_source_evidence_index`.
  - Win64 compile-only smoke passed for `nextpas.core.time`, `platform.thread`, and
    `platform.sync`.
- Full verification:
  - `make -C core test`: `All tests passed`.
  - `make -C core examples`: `All examples compiled`.
  - `make -C core benchmarks`: `All benchmarks passed`.
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope contains
    `corePlatformHostAbiWave5EnvCheck":"pass"`.
  - `git diff --check` and `sh -n build/verify_local.sh`: no output.
- Post-merge main verification:
  - Fast-forward merged `codex/platform-host-abi-wave5-env` into `main@7c4db4a`.
  - `git diff --check`: no output.
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave5_env clean test`:
    `5 total, 5 passed, 0 failed`.
  - `make -C core build`: nothing to compile yet; units compile on demand.
  - `make -C core test`: `All tests passed`.
  - `make -C core examples`: `All examples compiled`.
  - `make -C core benchmarks`: `All benchmarks passed`.
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope contains
    `corePlatformHostAbiWave5EnvCheck":"pass"`.
  - Temporary worktree
    `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave5-env`
    and branch `codex/platform-host-abi-wave5-env` were removed; `git worktree prune`
    was run.

### Recovery Entry

This wave is closed. If work continues, resume from latest `main` and start the next host
ABI wave from the workflow and gap matrix:

```bash
cd /home/dtamade/projects/nextPas
git status --short --branch
sed -n '1,190p' task_plan.md
sed -n '1,170p' progress.md
sed -n '1,80p' findings.md
```

## Addendum: 2026-05-28 Platform Host ABI Completeness Wave 4

### Goal

继续按 `core/docs/platform-ffi-import-workflow.md` 扩充 host-owned raw ABI inventory。本轮聚焦
目录与路径基础 ABI：POSIX `mkdir` / `rmdir` / `unlink` / `rename` / `access` /
`getcwd` / `chdir`，以及 Windows `CreateDirectoryA/W`、`RemoveDirectoryA/W`、
`DeleteFileA/W`、`MoveFileA/W`、`GetCurrentDirectoryA/W`、`SetCurrentDirectoryA/W`、
`GetFullPathNameA/W`。

本轮明确不创建 `platform.file` public contract，不新增 `platform.file.ffi`，也不把 raw
OS API 作为 runtime unit test 目标。后续统一文件/路径 API 应另起 public contract 设计。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC
  platform/RTL units。
- 共享 POSIX external 与 thin helper 放在 `nextpas.core.platform.posix.ffi`；host `.ffi`
  只暴露 host owner helper 并委托 shared POSIX helper。
- POSIX access mode token `F_OK` / `X_OK` / `W_OK` / `R_OK` 是 host base 事实，放入各
  POSIX host `.base`，不藏在 feature 子模块。
- Windows path/directory entrypoints、string pointer aliases 与 helper 归
  `nextpas.core.platform.windows.base` / `nextpas.core.platform.windows.ffi`。
- raw OS ABI 不做 runtime unit test；本轮用 FPC source evidence、source-surface guard、
  simulated host compile matrix、Win64 compile-only gate 与 official verify route 证明。

### Status

Completed and merged.

- Worktree:
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave4-paths`
- Branch: `codex/platform-host-abi-wave4-paths`
- Base: `main@27d57f2`
- Parallel worktrees remain `collections-refactor` and `sema-no-matching-overload`; this
  wave does not touch them.

### Planned Steps

- [x] 从最新 `main@27d57f2` 创建 `codex/platform-host-abi-wave4-paths` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、Wave 2/3 tests 与现有 host
      base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 初步取证 POSIX / Windows 目录路径 ABI
- [x] RED：新增 Wave 4 source-surface gate，要求 evidence、host owner tokens 和 verify route
- [x] GREEN：更新 evidence index、gap matrix、host base/ffi declarations/helpers
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [x] commit feature branch and rebase latest `main`
- [x] merge, post-merge verification, cleanup

### Audit Checklist

- [x] 不新增 `platform.file` public API，也不新增 `platform.file.ffi`
- [x] `platform.time` / `platform.sync` / `platform.thread` 不消费本轮 raw path ABI
- [x] production platform units 不 `uses Linux` / `UnixType` / `BaseUnix` / `PThreads` /
      `Windows`
- [x] raw OS API 只通过 source-surface / compile gates 取证，不写 runtime unit test
- [x] POSIX 与 Windows path/directory family 分别归 host owner，不混成伪 POSIX

### Verification Evidence

- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave4_paths clean test`:
  `5 total, 5 passed, 0 failed`.
- `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
  Darwin / Android / FreeBSD / generic Unix simulated host compile matrix all `status=pass`.
- Regression surface checks passed:
  `test_platform_ffi_partition_surface`, `test_platform_posix_ffi_surface`,
  `test_platform_ffi_source_evidence_index`, `test_platform_host_gap_matrix`,
  `test_platform_ffi_owner_boundary`.
- Win64 compile-only smoke passed for platform thread, platform sync, and `nextpas.core.time`.
- Full checks passed: `make -C core test`, `make -C core examples`,
  `make -C core benchmarks`.
- Fresh `bash build/verify_local.sh` passed with `verify-local=pass`,
  `human-summary=local verification passed`, and final envelope token
  `corePlatformHostAbiWave4PathsCheck":"pass"`.
- After local `main` advanced through collections work to `main@ff141a2`, rebasing
  Wave 4 again completed without conflicts. Fresh `git diff --check main..HEAD`,
  focused Wave 4 gate, and `bash build/verify_local.sh` passed again; the official
  envelope still contains `corePlatformHostAbiWave4PathsCheck":"pass"`.
- Wave 4 fast-forward merged as `71c7a62 platform: add host path ABI wave 4`.
  Post-merge verification ran from a clean detached worktree at that commit:
  `git diff --check`, focused Wave 4 gate, and `bash build/verify_local.sh` all
  passed; final envelope still contains `corePlatformHostAbiWave4PathsCheck":"pass"`.
- After post-merge verification, main advanced further to `main@0768e2b` through an
  unrelated collections commit; `71c7a62` remains an ancestor of current `main`.

### Retrospective

本轮方向正确：raw directory/path API 已进入 host-owned `base/ffi`，没有偷渡成 public
`platform.file` / `platform.path` contract，也没有让 `platform.time` / `platform.sync` /
`platform.thread` 消费这组 ABI。一次风险点是 `build/verify_local.sh` 曾被机械插入扩大成大 diff；
已收敛回最小 route-truth diff，并用 `sh -n build/verify_local.sh` 与 fresh full verification 证明。
集成窗口内主线前进过 collections commits；本轮通过重复 rebase 保持在最新 main 之上，并最终
fast-forward 合并。为避免主 checkout 的并行 collections 工作污染验证，post-merge official
verification 在干净 detached worktree 上执行。Wave 4 临时 worktree 与 post-merge verify
worktree 均已删除，`codex/platform-host-abi-wave4-paths` 分支已删除。

### Recovery Entry

If this session is interrupted, resume here:

```bash
cd /home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave4-paths
git status --short --branch
sed -n '1,170p' task_plan.md
sed -n '1,120p' progress.md
tail -n 120 findings.md
```

## Addendum: 2026-05-27 Platform Host ABI Completeness Wave 3

### Goal

继续按 `core/docs/platform-ffi-import-workflow.md` 扩充 host-owned raw ABI inventory。本轮聚焦
文件状态 ABI 取证：POSIX `stat` / `fstat` / `lstat` family 与 Windows 文件属性/文件信息
family。目标是把能够可靠取证、能够被 host owner 承载的低层声明先落进
`platform.<host>.base` / `platform.<host>.ffi`，并把 layout、large-file suffix 或语义映射仍不稳的
部分诚实写进 gap matrix。

本轮明确不创建 `platform.file` public contract，不新增 `platform.file.ffi`，也不把 raw
`stat` / `GetFileAttributesEx*` / `GetFileInformationByHandle` 作为 runtime unit test 目标。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC platform/RTL units。
- POSIX shared scalar/record 只有在 Linux / Android / Darwin / FreeBSD / generic Unix ABI shape
  确认一致时才放入 `nextpas.core.platform.posix.base`；否则放入具体 host `.base` 或继续延期。
- `stat` record layout、`stat64` suffix、time fields 与 device/inode width 是本轮最高风险点；
  如果无法在当前证据内形成跨宿主安全形状，只导入函数 family 的 source evidence 和 gap matrix，
  不硬造不可信 record。
- Windows `WIN32_FILE_ATTRIBUTE_DATA`、`BY_HANDLE_FILE_INFORMATION`、文件属性常量和
  `GetFileAttributesExA/W` / `GetFileInformationByHandle` 归 Windows base/ffi owner。
- raw OS ABI 不做 runtime unit test；本轮用 FPC source evidence、source-surface guard、
  simulated host compile matrix、Win64 compile-only gate 与 official verify route 证明。

### Status

Implementation, focused verification, full verification, rebase over latest local
`main@c09bc58`, final pre-merge verification, fast-forward merge, post-merge
verification, and cleanup are complete. The accepted platform Wave 3 commits are
on `main` as `f43cfbd`, `2e6b181`, and `ed25455`; `main` later advanced to
`d2e5b52` with unrelated collections docs.

### Planned Steps

- [x] 从最新 `main@846b9d1` 创建 `codex/platform-host-abi-wave3-stat` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、Wave 1/2 tests 与现有 host base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 取证，确定 Wave 3 最小可审查 ABI 子集
- [x] RED：新增 source-surface gate，要求 Wave 3 evidence、host owner tokens 和 verify route
- [x] GREEN：更新 evidence index、gap matrix、host base/ffi declarations/helpers
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [x] commit feature branch and rebase latest `main`
- [x] investigate rebase full-test hang and fix high-level condvar lost-wake regression
- [x] rerun full verification after condvar fix
- [x] sync `build/verify_local.sh` forced POSIX fallback summary to the new
      11-test `nextpas.core.sync` contract
- [x] commit final feature branch and rebase over latest local `main@c09bc58`
- [x] merge, post-merge verification, cleanup

### Audit Checklist

- [x] 不新增 `platform.file` public API，也不新增 `platform.file.ffi`
- [x] `platform.time` / `platform.sync` / `platform.thread` 不消费本轮 raw file status ABI
- [x] production platform units 不 `uses Linux` / `UnixType` / `BaseUnix` / `PThreads` / `Windows`
- [x] raw OS API 只通过 source-surface / compile gates 取证，不写 runtime unit test
- [x] Windows 与 POSIX 文件状态 family 分别归 host owner，不混成伪 POSIX

### Focused Verification Snapshot

- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave3_stat clean test`:
  `5 total, 5 passed, 0 failed`.
- Adjacent source-surface gates passed:
  `test_platform_ffi_source_evidence_index`, `test_platform_host_gap_matrix`,
  and `test_platform_simulated_host_compile_matrix`.
- Forced Windows compile-only checks passed for `test_platform_thread` and
  `test_platform_sync` after creating their temporary output directories.
- Full verification passed:
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave3StatCheck":"pass"`.
- Rebase over `main@12f5640` completed without conflicts. During rebase
  verification, `make -C core test` exposed a real flaky hang in
  `tests/nextpas.core.thread/test_thread`: `TestPoolSubmitAll` blocked in
  `TThreadPool.Shutdown` because a worker missed the high-level condvar
  broadcast. This is not caused by Wave 3 file-status ABI, but it made full
  verification unreliable.
- The condvar root cause was fixed in `nextpas.core.sync.condvar`: the high-level
  `TCondVar` no longer bridges an external `IMutex` through an unrelated
  internal mutex, which could lose a signal between `AMutex.Release` and
  `pthread_cond_wait`. It now uses a monotonic sequence plus
  `platform_wait_address32` / wake helpers, keeping the wait on nextPas platform
  abstractions and avoiding direct FPC platform units.
- Regression added to `core/tests/nextpas.core.sync/test_sync`: a test mutex
  signals during `Release`, and `WaitTimeout` must observe that signal. The
  test failed against the old implementation and passes after the fix.
- First fresh `bash build/verify_local.sh` after the condvar regression failed
  at `missing-core-sync-posix-fallback-pass-summary`: the forced POSIX fallback
  route correctly ran 11 sync tests, but the official route still expected the
  old `10 total, 10 passed, 0 failed` summary. The route expectation is now
  updated to `11 total, 11 passed, 0 failed`.
- Final pre-merge verification in the isolated worktree passed before the latest
  local rebase:
  - `git diff --check`
  - `make -C core/tests/nextpas.core.sync/test_sync clean test`:
    `11 total, 11 passed, 0 failed`
  - `make -C core/tests/nextpas.core.sync/test_sync_posix_fallback clean test`:
    `11 total, 11 passed, 0 failed`
  - `make -C core/tests/nextpas.core.thread/test_thread clean test`:
    `6 total, 6 passed, 0 failed`
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave3_stat clean test`:
    `5 total, 5 passed, 0 failed`
  - `make -C core test`: `All tests passed.`
  - `make -C core examples`: `All examples compiled.`
  - `make -C core benchmarks`: `All benchmarks passed.`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave3StatCheck":"pass"` and
    `coreSyncPosixFallbackCheck":"pass"`.
- Rebase over latest local `main@c09bc58` completed without conflicts. Fresh
  focused checks after that rebase passed:
  - `git diff --check`
  - `make -C core/tests/nextpas.core.sync/test_sync clean test`:
    `11 total, 11 passed, 0 failed`
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave3_stat clean test`:
    `5 total, 5 passed, 0 failed`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave3StatCheck":"pass"` and
    `coreSyncPosixFallbackCheck":"pass"`.
- Fast-forward merge landed on `main` at `ed25455`. Post-merge verification
  passed:
  - `git diff --check`
  - `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave3_stat clean test`:
    `5 total, 5 passed, 0 failed`
  - `make -C core/tests/nextpas.core.sync/test_sync clean test`:
    `11 total, 11 passed, 0 failed`
  - `bash build/verify_local.sh`: `verify-local=pass`,
    `human-summary=local verification passed`, final envelope includes
    `corePlatformHostAbiWave3StatCheck":"pass"` and
    `coreSyncPosixFallbackCheck":"pass"`.
- Cleanup completed: removed worktree
  `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave3-stat`,
  deleted branch `codex/platform-host-abi-wave3-stat`, and ran
  `git worktree prune`. Remaining worktrees are `collections-refactor` and
  `sema-no-matching-overload`.

### Recovery Entry

If this session is interrupted, resume here:

```bash
cd /home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave3-stat
git status --short --branch
sed -n '1,190p' task_plan.md
sed -n '1,200p' progress.md
sed -n '1,170p' findings.md
```

This Wave 3 addendum is closed. Continue from latest `main` for the next
platform host ABI import wave. Do not add runtime tests for raw OS APIs and do
not introduce `platform.file` public API without a separate public contract
design.

## Addendum: 2026-05-27 Platform Host ABI Completeness Wave 2

### Goal

继续按 `core/docs/platform-ffi-import-workflow.md` 扩充 host-owned raw ABI inventory。本轮聚焦
文件相关的低层 ABI 取证和最小可审查声明，不创建 `platform.file` public contract，也不把 raw
OS API 加入 runtime unit tests。

本轮候选范围：

- POSIX/Linux/Android/Darwin/FreeBSD/generic Unix：`open`、`close`、`fcntl`、基础 file descriptor
  scalar alias、open/access mode flags、fcntl command tokens。
- `stat` / `fstat` / `lstat` 只在 record layout、large-file suffix 和 32/64-bit policy 取证清楚后
  落地；如果跨 host 风险过大，本轮继续显式延期并写入 gap matrix。
- Windows：kernel32 file handle entrypoints 与基础 file access/share/creation/attribute tokens 的
  source evidence inventory；是否落 `CreateFileA/CloseHandle` thin helper 取决于和已有 `HANDLE`
  owner 的冲突检查。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC platform/RTL units。
- constants、record layouts、scalar aliases、capability tokens 放入
  `nextpas.core.platform.<host>.base`。
- external declarations 与 thin host helpers 放入 `nextpas.core.platform.<host>.ffi`。
- shared POSIX declaration 只有在 ABI shape 真正跨 Linux/Android/Darwin/FreeBSD/generic Unix 一致时
  才放入 `nextpas.core.platform.posix.base/ffi`。
- raw file ABI 不做 runtime unit test；本轮用 source evidence、source-surface guard、
  simulated host compile matrix 和 official verify route 证明。

### Status

Implementation, rebase, and pre-merge verification completed on isolated worktree
`/home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave2-files`
from `main@4643daa`, then rebased to latest `main@5c0f03d`. Merge,
post-merge verification, and cleanup are still pending.

### Planned Steps

- [x] 从最新 `main@4643daa` 创建 `codex/platform-host-abi-wave2-files` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、Wave 1 收口记录与现有 host base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 取证，确定 Wave 2 最小可审查 ABI 子集
- [x] RED：新增 source-surface gate，要求 Wave 2 evidence、host owner tokens 和 verify route
- [x] GREEN：更新 evidence index、gap matrix、host base/ffi declarations/helpers
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [x] commit feature work and rebase to latest `main@5c0f03d`
- [x] rebase 后 focused verification、full verification
- [ ] merge、post-merge verification、cleanup

### Verification Snapshot

- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave2_files clean test`:
  `4 total, 4 passed, 0 failed`.
- Adjacent focused gates passed:
  `test_platform_ffi_source_evidence_index`, `test_platform_host_gap_matrix`,
  `test_platform_posix_ffi_surface`, `test_platform_ffi_partition_surface`,
  `test_platform_ffi_owner_boundary`, `test_platform_simulated_host_compile_matrix`,
  and `test_platform_host_abi_wave1`.
- Win64 compile checks passed for `test_platform_thread`, `test_platform_sync`, and
  `test_time`.
- `git diff --check`: pass.
- `make -C core test`: `All tests passed.`
- `make -C core examples`: `All examples compiled.`
- `make -C core benchmarks`: `All benchmarks passed.`
- `bash build/verify_local.sh`: `verify-local=pass`,
  `human-summary=local verification passed`, final envelope includes
  `corePlatformHostAbiWave2FilesCheck":"pass"`.

Rebase verification on `codex/platform-host-abi-wave2-files@1536335` over
`main@5c0f03d`:

- `git diff --check`: pass.
- `make -C core/tests/nextpas.core.platform/test_platform_host_abi_wave2_files clean test`:
  `4 total, 4 passed, 0 failed`.
- `make -C core test`: `All tests passed.`
- `make -C core examples`: `All examples compiled.`
- `make -C core benchmarks`: `All benchmarks passed.`
- `bash build/verify_local.sh`: `verify-local=pass`,
  `human-summary=local verification passed`, final envelope includes
  `corePlatformHostAbiWave2FilesCheck":"pass"`.

### Recovery Entry

If this session is interrupted, resume here:

```bash
cd /home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave2-files
git status --short --branch
sed -n '1,170p' task_plan.md
sed -n '1,180p' progress.md
sed -n '1,130p' findings.md
```

Then continue from the first unchecked item in this Wave 2 addendum. Do not add
runtime tests for raw OS APIs and do not introduce `platform.file` public API in this wave.

## Addendum: 2026-05-27 Platform Host ABI Completeness Wave 1

### Goal

按刚合入的 `docs/platform-ffi-import-workflow.md` 开始第一批 host ABI completeness 工作。目标不是扩
`platform.time` / `platform.sync` / `platform.thread` public contract，而是从 FPC source evidence
补齐低风险、后续会被多个 platform 子模块消费的 host-owned raw ABI inventory。

本轮候选范围先限定为 source-surface 可审查的一小波：

- POSIX/Linux/Android/Darwin/FreeBSD/generic Unix：process id、`timeval`、file/stat/open/fcntl、
  mmap、dynamic loader family。
- Windows：process/thread/file/memory/dynamic library 对应的 kernel32 基础 ABI token 与 entrypoint
  inventory。

如果取证显示范围过大，本轮只落第一个可审查子集，并把剩余内容明确写入下一波。

### Architecture Decision

- FPC source 是 reference authority；production platform code 继续禁止 `uses` FPC platform/RTL units。
- constants、record layouts、opaque carriers、scalar aliases、syscall/open/mmap/error tokens 放入
  `nextpas.core.platform.<host>.base`。
- external declarations 与 thin host helpers 放入 `nextpas.core.platform.<host>.ffi`。
- raw OS API 不做 runtime unit test；本轮用 source evidence、source-surface guard、compile-only gate
  和 review 证明。
- 不新增 `platform.time.ffi`、`platform.sync.ffi`、`platform.thread.ffi`，也不扩这些统一 public
  contract。

### Status

Fast-forward merged to `main@54b19bd`, post-merge verified, and the temporary
worktree/branch has been cleaned up.

### Planned Steps

- [x] 从最新 `main@8a12bf9` 创建 `codex/platform-host-abi-wave1` isolated worktree
- [x] 读取 workflow、host gap matrix、source evidence index、现有 host base/ffi owner
- [x] 从 `/home/dtamade/projects/fpc` 取证，确定 Wave 1 最小可审查 ABI 子集：
      process id、`timeval`、mmap、dynamic loader；`stat/open/fcntl` 延后
- [x] RED：新增 source-surface gate，要求 Wave 1 evidence、host owner tokens 和 verify route
- [x] GREEN：更新 evidence index、gap matrix、host base/ffi declarations/helpers
- [x] GREEN：接入 `build/verify_local.sh` focused gate 与 final envelope
- [x] focused verification、full verification
- [x] feature commit and rebase over latest `main@52c2e2d`
- [x] pre-merge focused/full verification after rebase
- [x] fast-forward merge to `main@54b19bd`
- [x] post-merge focused gate and `bash build/verify_local.sh`
- [x] cleanup temporary worktree / branch

### Recovery Entry

If this session is interrupted, resume here:

```bash
cd /home/dtamade/.config/superpowers/worktrees/nextPas/platform-host-abi-wave1
git status --short --branch
sed -n '1,180p' task_plan.md
sed -n '1,180p' progress.md
sed -n '1,130p' findings.md
```

This wave is closed. Continue with the next platform host ABI wave from latest
`main`, and do not add runtime tests for raw OS APIs.

## Addendum: 2026-05-27 Platform FFI Import Workflow

### Goal

把“尽可能完整地从 FPC 源码补充各平台 API 到 nextPas platform 模块”的方法固定成可恢复、可验证、
可分批执行的工程工作流：

- 新增 `core/docs/platform-ffi-import-workflow.md`，明确从 FPC source evidence 到
  nextPas host `base/ffi` owner、source-surface gate、compile/runtime evidence、commit/merge/cleanup
  的完整流水线。
- 新增 `test_platform_ffi_import_workflow` source-surface gate，检查 workflow 文档、design conventions、
  evidence index、gap matrix 与 `build/verify_local.sh` 的 route truth 保持同步。
- 接入 `build/verify_local.sh` required path、focused route 与 final envelope：
  `core-platform-ffi-import-workflow-check` /
  `corePlatformFfiImportWorkflowCheck`。
- 这轮只固定工作流，不批量新增 raw OS API 声明；后续每个 API wave 必须按这个流程执行。

### Architecture Decision

- FPC 源码是 ABI reference authority；nextPas 生产代码继续禁止依赖 FPC 平台/RTL 单元。
- API import 先建立证据和 owner，再写声明；host `base/ffi` 可以做厚，但 public contract 必须由
  `platform.time`、`platform.sync`、`platform.thread` 以及后续统一 platform 子模块整理。
- raw OS API 不做 nextPas runtime 单测；raw ABI 的正确性靠 source evidence、source-surface gate、
  compile-only gate 和人工 review。runtime tests 只覆盖统一 public contract。
- 每批 import 都必须可恢复：`task_plan.md` 记录当前状态、`progress.md` 记录 RED/GREEN/验证证据、
  `findings.md` 记录取证和决策，worktree 分支名和下一步命令必须明确。

### Status

Completed and fast-forward merged to `main@e71e5d4`; cleanup pending.
`/home/dtamade/.config/superpowers/worktrees/nextPas/platform-ffi-import-workflow`
from `main@02d42d5`, rebased over `main@e01d069`, and merged as `e71e5d4`.

### Planned Steps

- [x] 从最新 `main@02d42d5` 创建 `codex/platform-ffi-import-workflow` isolated worktree
- [x] 研究现有 platform owner rules、evidence index、gap matrix、source-surface gate 和 FPC source tree
- [x] 更新 `task_plan.md` / `progress.md` / `findings.md`，写清恢复入口和本轮目标
- [x] RED：新增 `test_platform_ffi_import_workflow`，要求 workflow doc 与 official route token
- [x] GREEN：新增 workflow 文档，更新 `design-conventions.md`、evidence index 与 gap matrix 交叉入口
- [x] GREEN：接入 `build/verify_local.sh` required path、focused gate、final envelope
- [x] focused verification：
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_import_workflow clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
- [x] full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit 并整合最新 main：
  - initial commit before rebase: `c1f3680`
  - final feature commit after rebase/amend on `main@e01d069`: `e71e5d4`
- [x] 择优合并回 main、post-merge verification
- [ ] 清理 worktree/branch

### Full Verification Evidence

- `make -C core test`: `All tests passed.`
- `make -C core examples`: `All examples compiled.`
- `make -C core benchmarks`: `All benchmarks passed.`
- `bash build/verify_local.sh`: `verify-local=pass` and
  `human-summary=local verification passed`; final envelope includes
  `corePlatformFfiImportWorkflowCheck":"pass"`.
- `git diff --check`: pass.
- Rebase focused verification on `e71e5d4`:
  - `test_platform_ffi_import_workflow`: `2 total, 2 passed, 0 failed`
  - `test_platform_ffi_source_evidence_index`: `2 total, 2 passed, 0 failed`
  - `test_platform_host_gap_matrix`: `4 total, 4 passed, 0 failed`
  - `test_platform_ffi_owner_boundary`: `2 total, 2 passed, 0 failed`
- Post-merge focused verification on main:
  - `test_platform_ffi_import_workflow`: `2 total, 2 passed, 0 failed`
  - `test_platform_ffi_source_evidence_index`: `2 total, 2 passed, 0 failed`
  - `test_platform_host_gap_matrix`: `4 total, 4 passed, 0 failed`

### Recovery Entry

If this session is interrupted, resume here:

```bash
cd /home/dtamade/.config/superpowers/worktrees/nextPas/platform-ffi-import-workflow
git status --short --branch
sed -n '1,140p' task_plan.md
sed -n '1,140p' progress.md
sed -n '1,110p' findings.md
```

Then continue from the first unchecked item in this addendum. Do not start API import waves until
`core/docs/platform-ffi-import-workflow.md` and `test_platform_ffi_import_workflow` are in the official
`verify_local` envelope.

### Audit Checklist

- [x] workflow 明确 FPC source 是参考依据而非 production dependency
- [x] workflow 明确 host `base/ffi` owner 与禁止 feature-specific ffi 的默认规则
- [x] workflow 明确 raw OS API 不做 runtime 单测，统一 public contract 才做 runtime test
- [x] workflow 明确 evidence index、gap matrix、source-surface gate、compile gate、full verification 的顺序
- [x] workflow 明确每批 worktree/commit/merge/cleanup 和可恢复记录要求

## Addendum: 2026-05-27 Platform FFI Source Evidence Index

### Goal

把 platform host `base/ffi` 声明的“依据来自哪里”做成可审计、可验证、可追溯的 evidence index：

- 新增 `core/docs/platform-ffi-source-evidence-index.md`，记录 Linux、Android、Darwin、FreeBSD、
  generic Unix 与 Windows 当前 ABI 声明的 FPC source evidence family 与证据边界。
- 新增 `test_platform_ffi_source_evidence_index` source-surface gate，检查 evidence index 覆盖
  clock/time、errno、pthread/thread/TLS、CPU count、Linux futex 与 Windows kernel32/SRW/QPC/FILETIME。
- 接入 `build/verify_local.sh` required path、focused route 与 final envelope：
  `core-platform-ffi-source-evidence-index-check` /
  `corePlatformFfiSourceEvidenceIndexCheck`。
- 不测试 raw OS API，不扩 `platform.time` / `platform.sync` / `platform.thread` public API。

### Architecture Decision

- FPC source/platform units 是 reference authority，不是 production dependency。nextPas-owned
  `platform.<host>.base` / `platform.<host>.ffi` 承载 ABI truth，production platform 代码继续禁止
  `uses Linux`、`UnixType`、`BaseUnix`、`PThreads`、`Syscall`、`Windows` 等 FPC 平台单元。
- Evidence index 是 host ABI 声明的审计入口；host gap matrix 是覆盖/缺口事实源；
  `design-conventions.md` 是规则入口；`build/verify_local.sh` 是 official local route。
- raw 系统 API 的 runtime 正确性不由 nextPas 单元测试证明；统一 public contract 的 runtime 测试继续
  只覆盖 `platform.time` / `platform.sync` / `platform.thread` 抽象层。

### Status

Completed, fast-forward merged to `main@def99d2`, and worktree/branch cleanup
done. The work started from `main@2217d7a`, was rebased over latest
`main@c6a6ed7`, and did not touch unrelated collections work.

### Planned Steps

- [x] 刷新 main/worktree 状态并确认 unrelated collections WIP 不纳入本轮
- [x] 从 `main@2217d7a` 创建 `codex/platform-ffi-source-evidence-index` isolated worktree
- [x] 查证本机 FPC source 位置与可引用 source family，不写死不可验证的空目录
- [x] RED：新增 `test_platform_ffi_source_evidence_index`，要求 evidence index doc 与 official route token
- [x] GREEN：新增 evidence index 文档，更新 `design-conventions.md` 与 `platform-host-ffi-gap-matrix.md` 交叉入口
- [x] GREEN：接入 `build/verify_local.sh` required path、focused gate、final envelope
- [x] focused verification：
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_source_evidence_index clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
- [x] full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit、整合最新 main、择优合并回 main、post-merge verification、清理 worktree/branch

### Audit Checklist

- [x] evidence index 明确 FPC source 是参考依据而非 production dependency
- [x] Linux / Android / Darwin / FreeBSD / generic Unix / Windows 都有 host evidence entries
- [x] clock/time、errno、pthread/thread/TLS、CPU count、Linux futex、Windows kernel32/SRW/QPC/FILETIME 都有覆盖
- [x] design conventions 索引 evidence index 与 official route token
- [x] verify_local final envelope 包含 `corePlatformFfiSourceEvidenceIndexCheck`
- [x] 不新增 `platform.time.ffi` / `platform.sync.ffi` / `platform.thread.ffi`

## Addendum: 2026-05-27 Platform Host Gap Route Guard

### Goal

把 host gap matrix 从“有文档、有 focused gate”继续收紧成“设计规范、文档事实源和 official
verification route 互相索引”的闭环：

- `core/docs/design-conventions.md` 必须明确指出 host gap matrix 由
  `corePlatformHostGapMatrixCheck` / `core-platform-host-gap-matrix-check` 进入
  `build/verify_local.sh` official envelope。
- `test_platform_host_gap_matrix` 必须检查 design conventions、gap matrix 文档和
  `build/verify_local.sh` 之间的 route truth 一致性。
- 修正上一轮记录中 “cleanup pending” 的过期状态，记录实际 worktree/branch 已清理。
- 不扩 `platform.time` / `platform.sync` / `platform.thread` public API，不测试 raw OS API。

### Architecture Decision

- `docs/design-conventions.md` 是平台分层规则入口；`docs/platform-host-ffi-gap-matrix.md` 是 host
  ABI 覆盖和缺口事实源；`build/verify_local.sh` 是 official local verification route。
- 三者必须互相可追踪：规则入口必须说明矩阵的 gate 名称，gate 必须检查规则入口仍指向矩阵，
  final envelope 必须保留 `corePlatformHostGapMatrixCheck`。
- 这轮只强化 route-truth，不改变 ABI 声明和 runtime behavior。

### Status

Completed, committed as `4fe1391`, fast-forward merged to `main@4fe1391`, and
worktree/branch cleanup done.

### Planned Steps

- [x] 刷新 main/worktree 状态：主 checkout 有 unrelated collections WIP，本轮在隔离 worktree 执行
- [x] focused baseline：
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
- [x] RED：扩 `test_platform_host_gap_matrix`，要求 design conventions 记录 official route token
- [x] GREEN：更新 `core/docs/design-conventions.md` 与 `build/verify_local.sh` summary expectation
- [x] 更新 `task_plan.md`、`progress.md`、`findings.md`
- [x] focused verification：
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
- [x] full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit、合并回 main、post-merge focused verification、清理 worktree/branch

### Audit Checklist

- [x] design conventions 明确索引 `docs/platform-host-ffi-gap-matrix.md`
- [x] design conventions 明确 official line token `core-platform-host-gap-matrix-check`
- [x] design conventions 明确 final envelope token `corePlatformHostGapMatrixCheck`
- [x] host gap matrix test 检查 `build/verify_local.sh` 的 required path、line token、summary 与 envelope
- [x] 上一轮 cleanup 记录不再误导后续会话

## Addendum: 2026-05-27 Platform Host FFI Gap Matrix Guard

### Goal

把 platform host ABI owner 的覆盖面、已知缺口与证据边界固化成一条可回归 gate：

- 新增 `core/docs/platform-host-ffi-gap-matrix.md`，按 Linux、Android、Darwin、FreeBSD、
  generic Unix、Windows 记录 host `base/ffi` 当前覆盖域和已知缺口。
- 新增 `test_platform_host_gap_matrix` source-surface gate，检查文档、host base/ffi token、
  known-gap token 与 feature-specific FFI 禁止规则保持一致。
- 接入 `build/verify_local.sh` required path、focused check 与 final command envelope。
- 不扩 `platform.time` / `platform.sync` / `platform.thread` public API，不把 raw OS API 加入
  runtime 单元测试。

### Architecture Decision

- platform 是 L0 系统 API/ABI 适配层；raw ABI truth 归
  `nextpas.core.platform.<host>.base` / `nextpas.core.platform.<host>.ffi`。
- `platform.time`、`platform.sync`、`platform.thread` 是跨宿主统一 API contract，消费 host
  base/ffi，默认不创建 `platform.<feature>.ffi`。
- host gap matrix 是 source-surface / docs gate，不等价于 macOS、Android、FreeBSD、Windows 的
  runtime proof；当前真实 runtime proof 仍以 Linux 为主，Win64 与 simulated hosts 是 compile-only。
- raw `clock_gettime`、`pthread_*`、`futex`、`WaitOnAddress`、QPC/FILETIME 等系统 API 不作为
  nextPas runtime 单测目标；raw ABI 正确性靠 FPC 源码取证、source-surface guard 与 compile gate。

### Status

Completed, committed, fast-forward merged to `main@253a3fa`, follow-up docs commit
`main@c9948d5` recorded the merge, and worktree/branch cleanup is done.

### Planned Steps

- [x] 恢复当前 worktree / main 状态；实时主 checkout 为 `main@d987e80` 且干净
- [x] 跑上一轮总结指定 focused baseline：
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] RED：新增 `test_platform_host_gap_matrix`，先要求不存在的
      `core/docs/platform-host-ffi-gap-matrix.md`，确认失败边界正确
- [x] GREEN：补 `core/docs/platform-host-ffi-gap-matrix.md`，记录 host/domain/gap matrix 与证据边界
- [x] GREEN：扩 source-surface 检查，校验 host rows、domain tokens、known gaps、no feature ffi
- [x] 接入 `build/verify_local.sh` 的 mktemp/build dir/cleanup/required path/focused gate/final envelope
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform/test_platform_host_gap_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit、整合最新 `main@d987e80`、择优合并回 main
- [x] post-merge focused verification
- [x] 清理 worktree / branch

### Audit Checklist

- [x] 文档明确 host base/ffi 是 raw ABI owner，feature modules 是统一 contract
- [x] Linux/Android/Darwin/FreeBSD/generic Unix/Windows 都有矩阵行
- [x] known gaps 写清楚：Darwin condattr setclock unsupported、Darwin mutex timedlock unsupported、
      generic Unix native thread id fallback、generic Unix `_SC_NPROCESSORS_ONLN = -1`、
      generic Unix mutex timedlock unsupported、Windows 是 kernel32/SRW/QPC/FILETIME 路径
- [x] gate 检查 host base/ffi 中对应 token 仍存在
- [x] gate 禁止 `platform.time.ffi`、`platform.sync.ffi`、`platform.thread.ffi` 回归
- [x] final envelope 出现 `corePlatformHostGapMatrixCheck`

### Implementation Notes

- Baseline focused gates from this worktree are green:
  `test_platform_ffi_partition_surface`、`test_platform_posix_ffi_surface`、
  `test_platform_ffi_owner_boundary` 与 `test_platform_simulated_host_compile_matrix` 均已通过。
- RED proof:
  - `test_platform_host_gap_matrix` 初始失败：
    `platform host ffi gap matrix doc must exist: ../../../docs/platform-host-ffi-gap-matrix.md`。
- GREEN focused:
  - `test_platform_host_gap_matrix`: `3 total, 3 passed, 0 failed`。
  - `test_platform_ffi_partition_surface`: `1 total, 1 passed, 0 failed`。
  - `test_platform_posix_ffi_surface`: `1 total, 1 passed, 0 failed`。
  - `test_platform_ffi_owner_boundary`: `2 total, 2 passed, 0 failed`。
  - `test_platform_simulated_host_compile_matrix`: `simulated-host-compile-matrix-status=pass`。
  - `bash -n build/verify_local.sh`: pass。
- Full verification:
  - `make -C core test`: `All tests passed.`。
  - `make -C core examples`: `All examples compiled.`。
  - `make -C core benchmarks`: `All benchmarks passed.`。
  - `bash build/verify_local.sh`: `verify-local=pass`、`human-summary=local verification passed`，
    final envelope 包含 `corePlatformHostGapMatrixCheck":"pass"`。
  - `git diff --check`: pass。
- `main` 当前已到 `d987e80`，本 worktree 起点是 `cda52dd`；合并前必须先整合最新 main 并重跑
  post-integration focused verification。
- Integration:
  - 本分支 rebase 到 `main@d987e80` 后无冲突，提交变为 `253a3fa`。
  - `codex/platform-host-gap-matrix` 已 fast-forward 合并到 `main@253a3fa`。
  - post-merge focused verification passed:
    `test_platform_host_gap_matrix` 3/3 pass，
    `test_platform_ffi_partition_surface` 1/1 pass，
    `test_platform_posix_ffi_surface` 1/1 pass，
    `test_platform_ffi_owner_boundary` 2/2 pass，
    `test_platform_simulated_host_compile_matrix` 输出 `simulated-host-compile-matrix-status=pass`。
  - 主 checkout 仍有 unrelated collections WIP：
    `core/src/nextpas.core.collections.hashset.base.pas`、
    `core/src/nextpas.core.collections.hashset.intf.pas`；本轮未提交这些文件。

## Addendum: 2026-05-27 Platform Sync Base Extraction

### Goal

把 `platform.sync` 的 public carrier type、opaque storage size、mutex kind 与 public error
constant 从行为实现单元中抽到 `platform.sync.base`，让 sync 子模块和 `platform.time` /
`platform.thread` 一样遵循 facade/base/implementation 结构：

- `nextpas.core.platform.sync.base` 拥有 `TPlatformMutexAlign`、`TPlatformRwLockAlign`、
  `TPlatformCondVarAlign`、`TPlatformMutex`、`TPlatformRwLock`、`TPlatformCondVar`。
- `nextpas.core.platform.sync.base` 拥有 `PLATFORM_MUTEX_SIZE`、`PLATFORM_RWLOCK_SIZE`、
  `PLATFORM_CONDVAR_SIZE`、`PLATFORM_MUTEX_*` 和 `PLATFORM_ERR_*`。
- `nextpas.core.platform.sync` 只 re-export public types/constants，并保留 mutex/rwlock/condvar/
  wait-address 统一 API 实现。
- 不新增 `platform.sync.ffi` 或 `platform.sync.intf`；host ABI truth 仍归
  `platform.<host>.base` / `platform.<host>.ffi`。

### Architecture Decision

- `platform.sync.base` 是 public contract carrier owner，不是 host ABI owner，也不包含逻辑或
  `external` declaration。
- `platform.sync` 的 public API 名称保持不变；调用方仍可只 `uses nextpas.core.platform.sync`。
- 这轮只做结构收口，不改变 Linux/Windows/POSIX 运行时语义，不测试 raw OS API。
- regression gate 通过 source-surface、owner-boundary、no-FPC 与 L0-boundary 四条线固定：
  base 必须存在、实现单元必须 re-export、base 也不得引用 FPC 平台单元或 L1 sync 抽象。

### Status

Completed, committed, merged to `main@9312764`, and worktree/branch cleanup done.

### Planned Steps

- [x] 从最新 `main@56b4729` 开 `codex/platform-sync-base` isolated worktree
- [x] 跑 focused baseline：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_l0_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 `platform.sync.base` 存在并拥有
      public carrier types/constants，且 `platform.sync` re-export 而不是直接声明 raw shapes
- [x] RED：扩 `test_platform_ffi_owner_boundary`，把 `nextpas.core.platform.sync.base.pas` 纳入
      platform source owner audit
- [x] RED：扩 `test_platform_sync_no_fpc_units` 与 `test_platform_sync_l0_boundary`，把
      `platform.sync.base` 纳入 hard boundary
- [x] GREEN：新增 `core/src/nextpas.core.platform.sync.base.pas`，并让
      `platform.sync` re-export base types/constants
- [x] 更新 `build/verify_local.sh` required path 与 focused gate summary expectation
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_l0_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_sizes clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit、择优合并回 `main`
- [x] 清理 worktree / 分支

### Audit Checklist

- [x] `platform.sync.base` 只承载 public carrier type/constants，不含逻辑和 FFI
- [x] `platform.sync` 保持调用方兼容的 public type/constant re-export
- [x] 不新增 `platform.sync.ffi` 或 `platform.sync.intf`
- [x] `platform.sync.base` 进入 no-FPC / L0-boundary / owner-boundary gate
- [x] simulated host compile matrix 覆盖新 base 单元在 Darwin/Android/FreeBSD/generic Unix 分支下可编译

### Implementation Notes

- Baseline:
  - `test_platform_sync_host_ffi_surface` 1/1 pass。
  - `test_platform_sync_no_fpc_units` 1/1 pass。
  - `test_platform_sync_l0_boundary` 3/3 pass。
  - `test_platform_ffi_owner_boundary` 2/2 pass。
- RED proof:
  - `test_platform_sync_host_ffi_surface` 初始失败：缺
    `core/src/nextpas.core.platform.sync.base.pas`。
  - `test_platform_ffi_owner_boundary` 初始失败：non-ffi owner count 不含 sync feature base。
  - `test_platform_sync_no_fpc_units` 初始失败：
    `platform.sync.base source must exist for no-FPC guard`。
  - `test_platform_sync_l0_boundary` 初始失败：
    `platform.sync.base source stays L0 - File not found`。
- Focused GREEN:
  - `test_platform_sync_host_ffi_surface`: `1 total, 1 passed, 0 failed`。
  - `test_platform_ffi_owner_boundary`: `2 total, 2 passed, 0 failed`。
  - `test_platform_sync_no_fpc_units`: `2 total, 2 passed, 0 failed`。
  - `test_platform_sync_l0_boundary`: `4 total, 4 passed, 0 failed`。
  - `test_platform_sync`: `14 total, 14 passed, 0 failed`。
  - `test_platform_sync_sizes`: `5 total, 5 passed, 0 failed`。
  - `test_platform_simulated_host_compile_matrix`: `simulated-host-compile-matrix-status=pass`。
  - `test_platform_sync_posix_surface`: `1 total, 1 passed, 0 failed`。
  - `test_platform_sync_posix_fallback`: `14 total, 14 passed, 0 failed`。
  - `test_platform_ffi_partition_surface`、`test_platform_posix_ffi_surface` pass。
  - `platform_sync_basics` example 输出 `platform-sync-basics-status=pass`。
  - `bench_platform_sync` benchmark 输出 `platform-sync-bench-status=pass`。
- Full verification:
  - `make -C core test`: `All tests passed.`。
  - `make -C core examples`: `All examples compiled.`。
  - `make -C core benchmarks`: `All benchmarks passed.`。
  - `bash build/verify_local.sh`: `verify-local=pass`、
    `human-summary=local verification passed`。
  - `git diff --check`: pass。
- Note:
  - 曾误跑不存在的
    `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_win64 clean test`；
    这不是代码失败，实际 Win64 compile-only coverage 由 `build/verify_local.sh` 的
    `corePlatformSyncWin64Check=pass` 覆盖。

## Addendum: 2026-05-27 Platform Facade Info Boundary

### Goal

把顶层 `nextpas.core.platform` 中的 OS/CPU/endian 查询与名字映射逻辑收口到
`nextpas.core.platform.info`，让顶层 platform facade 更接近模块结构范式：

- `nextpas.core.platform.base` 继续只拥有 `TOSKind`、`TCPUArch`、`TEndianness` 与
  `CURRENT_*` 常量。
- `nextpas.core.platform.info` 拥有 `CurrentOS`、`CurrentCPU`、`CurrentEndian`、
  `OSName`、`CPUName` 的纯 Pascal 实现。
- `nextpas.core.platform` 只 re-export public types，并 inline 转发到 `platform.info` 与
  `platform.time`。
- 不新增 `platform.info.base`、`platform.info.intf` 或 `platform.info.ffi`；`info` 不拥有
  foreign ABI，也没有 Pascal interface contract。

### Architecture Decision

- 顶层 OS/CPU/endian inquiry 是 platform L0 public contract，但不是 host raw ABI；它依赖
  `platform.base` 的 compile-time truth，不应散在 facade 中。
- `platform.info` 不依赖 FPC 平台/RTL 绑定单元，不含 `external` declaration，不引用
  `platform.<host>.ffi`。
- `platform.pas` 可以保留 inline 转发函数，因为 FPC 不支持自动 re-export；但不能保留
  `case CurrentOS` / `case CurrentCPU` 这类业务逻辑。
- 这轮不改变 public API 名称和返回值，不引入 stopwatch/duration 等 L1 抽象，不测试 raw OS API。

### Status

Completed, committed, merged to `main@2417233`, and worktree/branch cleanup done.

### Planned Steps

- [x] 从 `main@9312764` 开 isolated worktree：
      `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-facade-info`
- [x] 校准当前主 checkout：存在 unrelated collections WIP，本轮不触碰
- [x] 更新本文件中上一轮 sync-base 的 merged/cleanup 状态，消除滞后计划记录
- [x] RED：新增 `test_platform_facade_surface`，要求 `platform.info` 存在并拥有 info API 逻辑，
      `platform.pas` 只转发，不再包含 OS/CPU name `case` 逻辑
- [x] RED：扩 `test_platform_ffi_owner_boundary`，把 `nextpas.core.platform.info.pas` 纳入
      non-ffi owner audit
- [x] GREEN：新增 `core/src/nextpas.core.platform.info.pas`，并修改
      `core/src/nextpas.core.platform.pas` 只 re-export/forward
- [x] 扩 `test_platform_simulated_host_compile_matrix`，让顶层 platform facade/info 也进入
      simulated host compile proof
- [x] 更新 `build/verify_local.sh` required path、focused gate 与 final envelope
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform/test_platform_facade_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] rebase 到最新 `main@db454df` 并跑 post-rebase focused gates
- [x] commit、择优合并回 `main`
- [x] 清理 worktree / 分支

### Audit Checklist

- [x] `platform.info` 只依赖 `platform.base`
- [x] `platform.info` 不含 `external`、host FFI import 或 FPC 平台单元 import
- [x] `platform.pas` 不再包含 `case CurrentOS` / `case CurrentCPU` 逻辑
- [x] `platform.pas` 继续兼容 `CurrentOS`、`CurrentCPU`、`CurrentEndian`、`OSName`、`CPUName`
      与 time public API
- [x] 顶层 facade/info 进入 owner-boundary、facade-surface、simulated-host compile 与 official
      local verification

### Implementation Notes

- RED proof:
  - `test_platform_facade_surface` 初始失败：
    `platform.info source must exist` 与 `platform facade must re-export platform.info`。
  - `test_platform_ffi_owner_boundary` 初始失败：
    `platform source audit must see the core non-ffi units...`。
- GREEN focused:
  - `test_platform_facade_surface`: `3 total, 3 passed, 0 failed`。
  - `test_platform_ffi_owner_boundary`: `2 total, 2 passed, 0 failed`。
  - `test_platform`: output includes `PASS: all platform tests passed`。
  - `test_platform_simulated_host_compile_matrix`: `simulated-host-compile-matrix-status=pass`。
- Full verification:
  - `make -C core test`: `All tests passed.`。
  - `make -C core examples`: `All examples compiled.`。
  - `make -C core benchmarks`: `All benchmarks passed.`。
  - `bash build/verify_local.sh`: `verify-local=pass`、
    `human-summary=local verification passed`，final envelope includes
    `corePlatformFacadeSurfaceCheck":"pass"`。
  - `git diff --check`: pass。
- Pre-merge review:
  - 合并前重新检查 `platform.info`、顶层 facade、facade surface test、owner-boundary test、
    simulated-host compile matrix、`build/verify_local.sh` 与设计文档 diff；未发现需要阻断合并的问题。
  - 多代理 code-review 工具虽可发现，但当前工具规则要求只有用户明确授权代理/分派时才能 spawn；
    因此本轮采用本地合并前 review，不启动子代理。
- Post-rebase focused verification on `main@db454df`:
  - `make -C core/tests/nextpas.core.platform/test_platform_facade_surface clean test`:
    `3 total, 3 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`:
    `2 total, 2 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`:
    `simulated-host-compile-matrix-status=pass`。
  - `make -C core/tests/nextpas.core.platform/test_platform clean test`:
    output includes `PASS: all platform tests passed`。
  - `git diff --check`: pass。
- Merge / post-merge:
  - `codex/platform-facade-info` commit `2417233` 已 fast-forward 合并进 `main@2417233`。
  - post-merge focused verification on main passed:
    `test_platform_facade_surface` 3/3，
    `test_platform_ffi_owner_boundary` 2/2，
    `test_platform_simulated_host_compile_matrix` pass，
    `test_platform` 输出 `PASS: all platform tests passed`，
    `git diff --check` pass。
  - `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-facade-info` worktree 已删除，
    `codex/platform-facade-info` 分支已删除。
- Note:
  - 扩 matrix 时暴露 enum constructor 不会随 type alias 变成真正“开箱即用” re-export；本轮只把
    facade/info 纳入 compile proof，未改变 enum constructor public usage contract。

## Addendum: 2026-05-27 Platform Thread Base Extraction

### Goal

把 `platform.thread` 的 public carrier type 从行为实现单元中抽到 `platform.thread.base`，让
platform 子模块继续符合“facade/base/implementation”结构范式：

- `nextpas.core.platform.thread.base` 拥有 `TPlatformThreadHandle`、
  `TPlatformThreadToken`、`TPlatformThreadProc`、`TPlatformTLSKey`。
- `nextpas.core.platform.thread` 只 re-export public carrier types，并保留线程生命周期、TLS、
  sleep/yield、CPU count 等统一 API 实现。
- 不新增 `platform.thread.ffi`，不移动 host ABI truth；host raw API 仍归
  `platform.<host>.base` / `platform.<host>.ffi`。
- 不引入 `*.intf.pas`，因为 `platform.thread` 当前没有 Pascal interface contract。

### Architecture Decision

- `platform.thread.base` 是 public type/alias owner，不是 host ABI owner，也不包含逻辑。
- `platform.thread` 的 public API 名称保持不变；调用方仍可只 `uses nextpas.core.platform.thread`。
- 这轮是结构收口，不改变 Linux/Windows/POSIX 运行时语义，不测试 raw OS API。
- regression gate 通过 source-surface、owner-boundary、no-FPC 与 L0-boundary 四条线固定：
  base 必须存在、实现单元必须 re-export、base 也不得引用 FPC 平台单元或 L1 thread 抽象。

### Status

Completed; merged to `main@de7efaa`, cleanup done.

### Planned Steps

- [x] 从最新 `main@c40ea69` 更新 `codex/platform-thread-base` isolated worktree
- [x] RED：扩 `test_platform_thread_host_ffi_surface`，要求 `platform.thread.base` 存在并拥有
      public carrier types，且 `platform.thread` re-export 而不是直接声明 raw shapes
- [x] RED：扩 `test_platform_ffi_owner_boundary`，把 `nextpas.core.platform.thread.base.pas` 纳入
      platform source owner audit
- [x] RED：扩 `test_platform_thread_no_fpc_units` 与 `test_platform_thread_l0_boundary`，把
      `platform.thread.base` 纳入 hard boundary
- [x] GREEN：新增 `core/src/nextpas.core.platform.thread.base.pas`，并让
      `platform.thread` re-export base types
- [x] 更新 `build/verify_local.sh` required path 与 focused gate summary expectation
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_l0_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
  - `git diff --check`
- [x] commit、择优合并回 `main`
- [x] 清理 worktree / 分支

### Audit Checklist

- [x] `platform.thread.base` 只承载 public carrier type，不含逻辑和 FFI
- [x] `platform.thread` 保持调用方兼容的 public type re-export
- [x] 不新增 `platform.thread.ffi` 或 `platform.thread.intf`
- [x] `platform.thread.base` 进入 no-FPC / L0-boundary / owner-boundary gate
- [x] simulated host compile matrix 覆盖新 base 单元在 Darwin/Android/FreeBSD/generic Unix 分支下可编译

### Implementation Notes

- RED:
  - `test_platform_thread_host_ffi_surface` 初始失败在
    `platform.thread must have a base unit for public carrier types`。
  - `test_platform_ffi_owner_boundary` 初始失败在 non-ffi owner count 不包含 feature base unit。
  - `test_platform_thread_no_fpc_units` 初始失败在
    `platform.thread.base source must exist for no-FPC guard`。
  - `test_platform_thread_l0_boundary` 初始失败在 `platform.thread.base source stays L0 - File not found`。
- Focused GREEN so far:
  - `test_platform_thread_host_ffi_surface` 输出 `1 total, 1 passed, 0 failed`。
  - `test_platform_ffi_owner_boundary` 输出 `2 total, 2 passed, 0 failed`。
  - `test_platform_thread_no_fpc_units` 输出 `2 total, 2 passed, 0 failed`。
  - `test_platform_thread_l0_boundary` 输出 `4 total, 4 passed, 0 failed`。
  - `test_platform_thread` 输出 `8 total, 8 passed, 0 failed`。
  - `test_platform_simulated_host_compile_matrix` 输出 `simulated-host-compile-matrix-status=pass`。
- Final branch verification:
  - `make -C core test` 输出 `All tests passed.`。
  - `make -C core examples` 输出 `All examples compiled.`。
  - `make -C core benchmarks` 输出 `All benchmarks passed.`。
  - `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`。
  - official envelope 包含 `corePlatformThreadCheck=pass`、
    `corePlatformThreadNoFpcCheck=pass`、`corePlatformThreadL0BoundaryCheck=pass`、
    `corePlatformThreadHostFfiSurfaceCheck=pass`、`corePlatformThreadWin64Check=pass`、
    `corePlatformThreadExampleCheck=pass`、`corePlatformThreadBenchCheck=pass` 与
    `corePlatformSimulatedHostCompileMatrixCheck=pass`。
  - `git diff --check` clean。
- Merge / post-merge:
  - `de7efaa platform: move thread carrier types to base` 已 fast-forward 合并进 main。
  - post-merge focused gates 通过：
    `test_platform_thread_host_ffi_surface` 1/1，
    `test_platform_thread_no_fpc_units` 2/2，
    `test_platform_thread_l0_boundary` 4/4，
    `test_platform_thread` 8/8，
    `test_platform_ffi_owner_boundary` 2/2，
    `test_platform_simulated_host_compile_matrix` pass。
  - 主 checkout 存在 unrelated `core/tests/nextpas.core.collections/test_deque/test_deque.lpr`
    WIP，本轮不纳入提交。
  - `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-thread-base` worktree 已删除，
    `codex/platform-thread-base` 分支已删除。

## Addendum: 2026-05-27 Platform Sync Windows Wait-Address Public Result Boundary

### Goal

把 Windows `WaitOnAddress` helper 的 host-owned result projection 与 `platform_wait_address32`
的 public contract 对齐，防止 Windows 路径把“当前值已经不等于 expected”的立即返回误报成成功：

- `platform.sync` 继续拥有 public address-wait contract：nil -> `PLATFORM_ERR_INVALID`，
  value mismatch -> `PLATFORM_ERR_AGAIN`，匹配但超时 -> `PLATFORM_ERR_TIMEOUT`，被唤醒 -> `0`。
- `windows.ffi` 继续拥有 raw `WaitOnAddress`、`GetLastError`、timeout ms conversion 与
  caller-supplied timeout-result helper。
- 不把 `PLATFORM_ERR_AGAIN` public policy 下沉到 `windows.ffi`，也不新增 `platform.sync.ffi`。
- Linux/POSIX/Windows wait path 都应在进入 host wait helper 前完成 public nil/mismatch validation。

### Architecture Decision

- 新增或收紧 `platform.sync` 内部 wait-address public precheck helper，让所有 wait path 复用同一条
  nil/mismatch 判定。
- wake-one/wake-all 仍只需要 nil address validation；它们不检查 expected value。
- 测试边界仍遵守既定规则：Linux runtime 行为测试覆盖抽象 API，Windows 路径通过 source-surface
  gate 和 Win64 compile-only gate 固化，不能把 raw WinAPI 当成 Linux 主机上的 runtime oracle。

### Status

Completed; merged to `main@1c18f86` and cleanup done.

### Planned Steps

- [x] 从最新 `main@6818cd9` 开 `codex/platform-sync-windows-wait-result` isolated worktree
- [x] 跑 focused baseline：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 Windows wait-address branch 先消费
      `platform_sync_validate_wait_address` 再调用 `windows_wait_address_i32_timeout_result`
- [x] GREEN：在 `platform.sync` 提取 wait-address nil/mismatch public precheck，并让 Linux、
      POSIX fallback 与 Windows wait path 统一消费
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
- [x] commit、择优合并回 `main`、清理 worktree / 分支

### Audit Checklist

- [x] Windows `platform_wait_address32` mismatch 不再可能绕过 public `PLATFORM_ERR_AGAIN`
- [x] Linux futex path 不再依赖 host syscall 才得到 mismatch result
- [x] POSIX fallback 继续保持同一 public mismatch behavior
- [x] host `.ffi` 不硬编码 nextPas public `PLATFORM_ERR_AGAIN`
- [x] 不新增 raw OS API runtime 单测

### Implementation Notes

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `platform.sync must own public wait-address nil/mismatch validation before host wait helpers:
platform_sync_validate_wait_address`。
- GREEN:
  - `platform.sync` 新增 `platform_sync_validate_wait_address`，复用
    `platform_sync_validate_address`，再统一处理 `AAddr^ <> AExpected` -> `PLATFORM_ERR_AGAIN`。
  - Linux futex path、POSIX fallback path、Windows wait-address path 都在进入 host wait helper 前消费
    `platform_sync_validate_wait_address`。
  - `windows.ffi` 未新增 public result 常量或 feature-specific FFI 单元。
- Focused GREEN so far:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
    输出 `14 total, 14 passed, 0 failed`。
- Final branch verification:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    输出 `2 total, 2 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出 `simulated-host-compile-matrix-status=pass`。
  - `make -C core test` 输出 `All tests passed.`。
  - `make -C core examples` 输出 `All examples compiled.`。
  - `make -C core benchmarks` 输出 `All benchmarks passed.`。
  - `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`。
- Post-merge verification on `main@1c18f86`:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出 `simulated-host-compile-matrix-status=pass`。
  - `git diff --check` clean。
  - `/home/dtamade/.config/superpowers/worktrees/nextPas/platform-sync-windows-wait-result`
    worktree 已移除，`codex/platform-sync-windows-wait-result` 分支已删除。

## Addendum: 2026-05-27 Platform Sync POSIX Wait-Bucket Policy Ownership

### Goal

把 `platform.sync` 的 address-wait fallback 策略从“代码里刚好存在”提升成明确、可验证的
owner boundary：

- `platform.sync` 是统一跨平台 wait/wake public contract owner。
- Linux futex、Windows WaitOnAddress、pthread condvar/raw errno/clock 继续归各 host `.ffi` owner。
- POSIX wait-bucket fallback 是 nextPas 的跨平台策略，不是 raw OS ABI，因此继续归
  `platform.sync`，不下沉到 `platform.<host>.ffi`。
- runtime behavior tests 只覆盖 `platform_wait_address32` / `platform_wake_address_*` public API，
  不直接测试 raw futex/pthread/WaitOnAddress。

### Architecture Decision

- 不新增 `platform.sync.ffi`，也不新增 `platform.sync.posix.ffi`。
- 不把 wait-bucket bucket count、waiter/generation policy、forced fallback selector 复制到 host ffi。
- 可以对 `platform.sync` 内部 fallback 策略做小的自解释 helper 提取，但 host `.ffi` 仍只提供
  raw ABI 和 caller-supplied result/helper。
- Linux 默认继续走 futex；`NEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK` 只作为 verification
  selector，用 Linux 宿主验证 generic POSIX fallback public behavior。

### Status

Completed; verification passed.

### Planned Steps

- [x] 从最新 `main@8936833` 开 `codex/platform-sync-wait-policy` isolated worktree
- [x] 跑 focused baseline：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
- [x] RED：扩 `test_platform_sync_posix_surface`，冻结 wait-bucket policy owner 留在 `platform.sync`
      而不是 host ffi
- [x] RED：扩 `test_platform_sync`，补 address-wait nil address public API 覆盖
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 public wait/wake 入口统一地址校验
- [x] GREEN：在 `platform.sync` 内提取 wait-bucket release predicate helper，并保持 public API 语义不变
- [x] GREEN：在 `platform.sync` 增加 `platform_sync_validate_address`，让 Linux/fallback/Windows wait/wake
      都先处理 nil address
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
- [ ] commit、择优合并回 `main`、清理 worktree / 分支

### Audit Checklist

- [x] `platform.sync` 保留 `TPosixWaitBucket` / bucket count / generation / waiter policy
- [x] host `.ffi` 不新增 wait-bucket policy token 或 feature-specific sync fallback ffi
- [x] address-wait nil / mismatch / zero-timeout / timeout / wake-one / wake-all public behavior 有覆盖
- [x] forced fallback gate 覆盖 Linux 宿主上的 generic POSIX fallback behavior
- [x] 不新增 raw OS API runtime 单测

### Implementation Notes

- Baseline:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
    第一版测试先失败在路径解析，修正 sibling path 后有效失败在
    `platform.sync must own the wait-bucket release predicate instead of hiding policy inside host ffi:
platform_posix_wait_address_released`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `platform.sync must validate public wait-address pointers before host wait/wake helpers:
platform_sync_validate_address`。
- GREEN so far:
  - `platform_posix_wait_address_released` 提取 generation/value mismatch release predicate。
  - `platform_sync_validate_address` 统一 Linux futex、POSIX fallback、Windows wait/wake public nil guard。
  - `test_platform_sync` 的 `Address wait` 用例现在覆盖 nil wait/wake public API。
- Focused GREEN so far:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
    输出 `14 total, 14 passed, 0 failed`。
- Focused full gate:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_fallback clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    输出 `2 total, 2 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出 `simulated-host-compile-matrix-status=pass`。
- Full GREEN:
  - `make -C core test` 输出 `All tests passed.`。
  - `make -C core examples` 输出 `All examples compiled.`。
  - `make -C core benchmarks` 输出 `All benchmarks passed.`。
  - `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`。

### Non-goals

- 不改变 `platform_wait_address32` / `platform_wake_address_*` public API 名称。
- 不新增真实 macOS / FreeBSD / Android runtime evidence。
- 不把 wait-bucket fallback 算法整体搬进 host ffi。
- 不扩大到 L1 `nextpas.core.sync` 抽象设计。

## Addendum: 2026-05-27 Platform Behavior Tests Abstract API Boundary

### Goal

把用户刚定下来的测试边界落到规则和代码里：

- FPC 源码和平台单元是 ABI 依据，不是 platform 生产代码依赖。
- raw 系统 API / FFI 声明不做 nextPas runtime 单元测试目标。
- `platform.time`、`platform.sync`、`platform.thread` 的行为测试只覆盖统一抽象 public API。
- source-surface / compile-only gate 只用于冻结 owner boundary 和编译一致性，不包装成系统 API
  语义测试。

### Architecture Decision

- 行为测试不能为了方便绕过抽象层去 import `nextpas.core.platform.<host>.ffi`。
- 并发测试需要 worker 时，应通过 `platform.thread` 创建和 join，而不是直接调用 `pthread_create` /
  `pthread_join`。
- `platform.thread_id` 的 native-id 取证继续由 source-surface guard 和 FPC 源码依据承担；runtime
  behavior test 只验证 nextPas public contract（非零、稳定等）。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_ffi_owner_boundary`，禁止 platform behavior tests import host FFI 或直接调
      raw pthread/gettid
- [x] `test_platform_sync` 改为用 `platform.thread` 创建/join worker
- [x] `test_platform_thread` 移除 Linux FFI oracle 和 raw `gettid` 断言
- [x] 更新 `docs/design-conventions.md`、`findings.md`、`progress.md`
- [x] focused：`test_platform_ffi_owner_boundary` / `test_platform_sync` / `test_platform_thread`
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`
- [x] commit

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    初始失败在
    `platform.sync behavior test must not import shared POSIX ffi`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
- Full:
  - `make -C core test` 输出 `All tests passed.`
  - `make -C core examples` 输出 `All examples compiled.`
  - `make -C core benchmarks` 输出 `All benchmarks passed.`
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 不删除 source-surface guard；它们不是系统 API runtime 单元测试，而是 owner boundary 冻结。
- 不宣称新增 Windows/Darwin/FreeBSD/Android runtime evidence。
- 不降低 `platform.time` / `platform.sync` / `platform.thread` public API 行为覆盖率。

## Addendum: 2026-05-27 Platform Time Facade/Base/Host Shape Normalization

### Goal

把 `platform.time` 收回刚固化的 platform host-owner 模型：

- `platform.time` 是跨平台统一 API contract，不是 Pascal interface contract。
- 删除错误的 `nextpas.core.platform.time.intf.pas`。
- 保留 `nextpas.core.platform.time.base.pas` 承载 public carrier types。
- 保留 `nextpas.core.platform.time.host.pas` 承载 host FFI delegation implementation。
- facade 只 re-export `base` 类型并 inline 转发到 `host`。

### Architecture Decision

- `*.intf.pas` 只给真实 Pascal `interface` contract。`platform.time` 当前只有统一的过程/函数 API，
  不应为了模块形态强行暴露 `IPlatformTimeSource`。
- `platform.time`、`platform.sync`、`platform.thread` 不按 feature 重复创建自己的 `*.ffi.pas`，
  而是直接消费 `platform.<host>.base` / `platform.<host>.ffi`。
- 这批先收正 `platform.time` 的 feature shape；后续再把宿主常量/结构继续从各 host ffi 拆进
  `platform.<host>.base`。

### Status

Completed; verification passed.

### Planned Steps

- [x] 文档已固化 host base/ffi owner 规则
- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求 facade 不再使用 `platform.time.intf`
- [x] 删除 `platform.time.intf`，从 facade 移除 `IPlatformTimeSource`
- [x] 保留 `platform.time.base` 的 public carrier types
- [x] 更新 `test_platform_time_l0_boundary` / `test_platform_ffi_owner_boundary` /
      `build/verify_local.sh`
- [x] focused：`test_platform_time_host_ffi_surface` / `test_platform_time_l0_boundary` /
      `test_platform_time_no_fpc_units` / `test_platform_time_helpers` /
      `test_platform_ffi_owner_boundary` / `test_platform` / `nextpas.core.time/test_time` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`
- [x] commit

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在
    `platform.time has no Pascal interface contract, so facade must not use platform.time.intf`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform clean test`
  - `make -C core/tests/nextpas.core.time/test_time clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 这批不新增 `platform.<host>.base` 文件
- 这批不改 public function 名称
- 这批不改变 host ffi helper ownership

## Addendum: 2026-05-27 Platform Sync Windows Busy-result Helper Ownership

### Goal

继续把 Windows trylock 的 busy classifier 从 `platform.sync` consumer 收回 `windows.ffi` owner：

- `platform.sync` 不再自己写三处 `if windows_*trylock(...) then ... else ...`
- `windows.ffi` 显式拥有
  `windows_mutex_trylock_busy_result`、
  `windows_rwlock_tryrdlock_busy_result`、
  `windows_rwlock_trywrlock_busy_result`
- caller 仍保留 nextPas public busy result 常量的最终选择权

### Architecture Decision

- Windows `TryAcquireSRWLock*` 返回 `BOOL` 且失败语义在这里就是 busy；这层 classifier 更接近宿主 helper
  组合，而不是 generic platform policy。
- 为了不把 `PLATFORM_ERR_BUSY` 硬编码进 ffi owner，这批继续采用 caller-supplied busy result 形态；
  `platform.sync` 只把 public busy contract 作为参数传给 `windows.ffi`。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 `windows.ffi` 暴露 trylock busy-result helper，
      且 `platform.sync` 消费这些 helper
- [x] RED：禁止 `platform.sync` 继续保留三处本地 Windows trylock busy mapping
- [x] 在 `windows.ffi` 增加 busy-result helper
- [x] 让 `platform.sync` Windows trylock 分支改为 delegation
- [x] 更新 design/tracking 文档
- [x] focused：`test_platform_sync_host_ffi_surface` / `test_platform_sync` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must expose Windows mutex trylock helper that maps busy semantics for sync: windows_mutex_trylock_busy_result`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`

### Non-goals

- 这批不移走 POSIX errno 到 `PLATFORM_ERR_*` 的映射
- 这批不改变 Windows public opaque storage contract
- 这批不把 timeout-result helper 重新改回 consumer 逻辑

## Addendum: 2026-05-27 Platform Sync Windows Destroy Helper Ownership

### Goal

把 Windows sync 三个“宿主无需 destroy”的 helper family 也收回 `windows.ffi` owner：

- `platform.sync` 不再在 Windows consumer 里直接保留 mutex/rwlock/condvar destroy no-op
- `windows.ffi` 显式拥有 `windows_mutex_destroy` / `windows_rwlock_destroy` /
  `windows_condvar_destroy`
- `platform.sync` 的 Windows helper family 继续更完整地落在 host ffi owner 上

### Architecture Decision

- Windows `SRWLOCK` / `CONDITION_VARIABLE` 的“无需销毁”也是宿主语义的一部分，虽然实现是 no-op，
  但 owner 仍应归 `nextpas.core.platform.windows.ffi`。
- `platform.sync` 继续保留 public opaque storage contract、busy/timeout error mapping 与跨平台
  wait policy；但 destroy family 不再停留在 consumer。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 `windows.ffi` 暴露 destroy helper，且
      `platform.sync` Windows 分支消费这些 helper
- [x] 在 `windows.ffi` 增加 mutex/rwlock/condvar destroy helper
- [x] 让 `platform.sync` Windows destroy 分支改为 delegation
- [x] 更新 design/tracking 文档
- [x] focused：`test_platform_sync_host_ffi_surface` / `test_platform_sync` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must expose Windows mutex destroy helper: windows_mutex_destroy`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`

### Non-goals

- 这批不把 Windows trylock busy-result 映射移出 `platform.sync`
- 这批不把 POSIX errno 到 `PLATFORM_ERR_*` 的映射移出 `platform.sync`
- 这批不改变 Windows public opaque storage contract

## Addendum: 2026-05-27 Platform Time Host-FFI Facade Collapse

### Goal

继续把 `platform.time` consumer 收窄成真正的薄 host-ffi façade：

- 不再按 POSIX / Darwin / Windows 逐段复制三组完全同构的 wrapper body
- `platform_monotonic_ns` / `platform_realtime_ns` /
  `platform_monotonic_resolution_ns` 各只保留一个实现体
- compile-time gate 只反映真实已支持宿主：`NEXTPAS_UNIX` 或 `NEXTPAS_WINDOWS`
- 保持 `platform.time` 仍是 L0 平台时钟 façade，而不是重新混入宿主拼装细节

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 与 `windows.ffi` 继续拥有统一命名的
  `platform_clock_*_ns_u64` helper，仍是时钟结果的单一事实源。
- `platform.time` 只保留 public clock contract 与单层 delegation，不再为不同 target 保留多份相同
  wrapper body。
- `nextpas.core.platform.windows.math` 继续作为纯 helper sibling 保留；它不是 raw ABI owner，
  不应为了“platform.time 更薄”而伪装成 `*.ffi.pas`。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求三组 public façade body 各只出现一次
- [x] 折叠 `platform.time` 中按 target 复制的三组 wrapper body
- [x] 用统一 `NEXTPAS_PLATFORM_TIME_HOST_FFI` gate 表达受支持宿主
- [x] 保持 public API 与 `windows.math` 边界不变
- [x] focused：`test_platform_time_host_ffi_surface` /
      `test_platform_time_helpers` /
      `test_platform_simulated_host_compile_matrix` / Win64 compile-only 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在新增的 single host-ffi façade body 计数断言。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/build/review-win64-time -FE/home/dtamade/projects/nextPas/build/review-win64-time -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.time/test_time/test_time.lpr`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`

### Non-goals

- 这批不改 `platform.time` public API 名称
- 这批不把 `windows.math` 并进 `windows.ffi`
- 这批不把 simulated host compile-only 包装成真实 Darwin/Android/FreeBSD runtime 证据

## Addendum: 2026-05-27 Platform POSIX Timeout Deadline Helper Ownership

### Goal

把 pthread timeout deadline/remaining 语义从 `platform.sync` 继续收回到 host ffi / shared
`posix.ffi` owner：

- `posix.ffi` 统一拥有 “clock now + add ns -> absolute deadline” helper
- `posix.ffi` 统一拥有 “deadline vs now -> remaining ns” helper
- host ffi 继续只暴露 `platform_pthread_timeout_deadline_after_ns` /
  `platform_pthread_timeout_remaining_ns_u64` 给 `platform.sync` 消费
- `platform.sync` 不再直接调用 pthread timeout-clock read helper，也不再在 consumer 里直接拼
  shared POSIX `timespec` deadline arithmetic

### Architecture Decision

- `platform_posix_timespec_add_ns` 与 `platform_posix_timespec_remaining_ns_u64` 仍留在
  shared owner，但 consumer 不再直接用它们拼 timeout policy。
- 新增更高一层 shared helper：
  `platform_posix_clock_deadline_after_ns` /
  `platform_posix_clock_deadline_remaining_ns_u64`。
- host ffi 通过 `PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` 薄委托到上述 shared helper，`platform.sync`
  只消费 host-owned pthread timeout helper。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，冻结 shared timeout deadline helper surface
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，冻结 host pthread timeout helper / consumer boundary
- [x] 在 `posix.ffi` 增加 shared deadline / remaining helper
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 暴露 host-owned pthread timeout deadline / remaining helper
- [x] 让 `platform.sync` 改为消费 host-owned pthread timeout deadline / remaining helper
- [x] focused：`test_platform_posix_ffi_surface` /
      `test_platform_sync_host_ffi_surface` /
      `test_platform_sync` /
      `test_platform_thread_host_ffi_surface` /
      `test_platform_time_host_ffi_surface` /
      `test_platform_simulated_host_compile_matrix` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在
    `posix.ffi must expose shared POSIX clock deadline helper for host ffi owners`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must expose pthread timeout deadline helper for sync`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`

### Non-goals

- 本轮不改 `platform.sync` / `platform.posix.ffi` public API 名称。
- 本轮不把 wait-bucket policy 从 `platform.sync` consumer 移到 ffi owner。
- 本轮不扩到 `platform.thread` 或 `platform.time` 的额外 timeout policy。

## Addendum: 2026-05-27 Platform POSIX Errno/Mutex Projection Shared Helper Ownership

### Goal

继续把 POSIX host ffi 中还剩的一层重复 skeleton 收回 shared owner：

- `linux/android/darwin/freebsd/unix.ffi` 不再各自复制 `errno-location^` 的 value load body
- `linux/android/darwin/freebsd/unix.ffi` 不再各自复制 public mutex kind
  `(normal/errorcheck/recursive)` 到宿主 pthread kind 的 `case` 投影样板
- host ffi 继续只保留真正的宿主 truth：`platform_errno_location` binding 与
  `PLATFORM_PTHREAD_MUTEX_*_KIND` 常量

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 本轮新增：
  - `platform_posix_errno_value_from_location`
  - `platform_posix_pthread_mutex_init_public_kind`
- `linux/android/darwin/freebsd/unix.ffi` 继续暴露既有 public helper 名给
  `platform.thread` / `platform.sync` 消费，但：
  - `platform_posix_errno_value` 改为委托 shared
    `platform_posix_errno_value_from_location`
  - `platform_pthread_mutex_init_platform_kind` 改为委托 shared
    `platform_posix_pthread_mutex_init_public_kind`
- host ffi 继续保留：
  - `platform_errno_location` 的宿主符号绑定
  - `PLATFORM_PTHREAD_MUTEX_NORMAL_KIND` /
    `PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND` /
    `PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND`
- 这批不改变 `platform.thread` / `platform.sync` public API，也不改变宿主 truth 的 owner。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，要求 `posix.ffi` 暴露 shared errno/mutex projection helper
- [x] RED：扩 `test_platform_thread_host_ffi_surface`，要求 POSIX host ffi 委托 shared errno value load helper
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 POSIX host ffi 委托 shared errno/mutex projection helper
- [x] 在 `posix.ffi` 实现 shared errno/mutex projection helper
- [x] 让 `linux/android/darwin/freebsd/unix.ffi` 委托 shared projection helper
- [x] focused：`test_platform_posix_ffi_surface` /
      `test_platform_thread_host_ffi_surface` /
      `test_platform_sync_host_ffi_surface` /
      `test_platform_thread` /
      `test_platform_sync` /
      `test_platform_time_host_ffi_surface` /
      `test_platform_simulated_host_compile_matrix` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在
    `posix.ffi must expose shared POSIX errno-value load helper for host ffi owners`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate errno-value load to shared posix.ffi`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate errno-value load to shared posix.ffi`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`

### Non-goals

- 这批不把 `platform_errno_location` binding 从 host ffi owner 移出
- 这批不把 `PLATFORM_PTHREAD_MUTEX_*_KIND` 的宿主 truth 移出 host ffi owner
- 这批不把 host clock id、timeout clock id、condattr capability 重新收窄进 shared owner

## Addendum: 2026-05-27 Collections Interface Ownership Normalization

### Goal

继续把从 `nextpas.core` 搬入的 collections 按 nextpas.core 三件套范式规整：

- `ICollection` 与 `IGenericCollection<T>` 的真实接口定义进入 `collections.intf`
- `collections.base` 不再拥有这些 interface definition
- 现有 `TCollection` / `TGenericCollection<T>` 代码先保持在 base 内可编译，避免在当前
  `TCollection` class-signature API 尚未改造前引入 `intf <-> abstract` 循环

### Architecture Decision

- 本轮先切接口 ownership，不强行物理搬迁 class skeleton。
- 原因：当前接口契约大量返回/接收 `TCollection`；若直接把 class 搬入 `collections.abstract`，
  `collections.intf` 必须反向引用 `abstract` 才能使用 `TCollection`，而 `abstract` 又必须引用
  `intf` 来实现接口，形成不符合 `base <- intf <- implementation` 的循环。
- 因此本轮让 concrete containers 显式依赖 `collections.intf`，并由具体容器类声明自己的 public
  interface（如 `IVec<T>` / `IHashMap<K,V>` / `IBitSet`），继承自 `TCollection` 的方法继续满足接口。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_abstract`，要求 `ICollection` / `IGenericCollection<T>` 定义位于
      `collections.intf` 且不在 `collections.base`
- [x] 把 `ICollection` / `IGenericCollection<T>` 从 `base` 迁入 `intf`
- [x] `TCollection` / `TGenericCollection<T>` 暂时取消直接 `implements` 迁出的接口，保持 base 无
      `intf` 依赖
- [x] 为 `bitset`、`circularbuffer`、`forward_list`、`list`、`priorityqueue`、`stack`、
      `tree_set`、`treemap` 补显式 `collections.intf` 依赖
- [x] focused collections tests 通过
- [x] fresh `make -C core test`

### Verification

- RED:
  - `make -C tests/nextpas.core.collections/test_abstract clean test`
    初始失败在 `ICollection interface definition should live in collections.intf`。
- Focused GREEN:
  - `make -C tests/nextpas.core.collections/test_abstract clean test`
  - `make -C tests/nextpas.core.collections/test_facade clean test`
  - `make -C tests/nextpas.core.collections/test_vec clean test`
  - `make -C tests/nextpas.core.collections/test_deque clean test`
  - `make -C tests/nextpas.core.collections/test_hashmap clean test`
  - `make -C tests/nextpas.core.collections/test_hashset clean test`
- Full:
  - fresh `make -C core test` 输出 `All tests passed.`

### Non-goals

- 本轮不重写 `TCollection` class API 中仍使用 `TCollection` 的参数/返回类型。
- 本轮不把 `TCollection` / `TGenericCollection<T>` 强搬进 `collections.abstract`；下一步应先设计并
  测试 class API 与 interface API 的过渡边界，再做物理迁移。

## Addendum: 2026-05-27 Platform POSIX Pthread Attr-init Shared Helper Ownership

### Goal

继续把 POSIX host ffi 中仍然重复的 pthread attr-init glue 收回 shared owner：

- `linux/android/darwin/freebsd/unix.ffi` 不再各自复制
  `pthread_mutexattr_init/settype/destroy + pthread_mutex_init`
- `linux/android/darwin/freebsd/unix.ffi` 不再各自复制
  `pthread_condattr_init/destroy + pthread_cond_init` 与 optional
  `pthread_condattr_setclock` 外壳
- host ffi 继续只保留宿主 truth：public kind 到宿主 kind 的映射、timeout clock id、
  condattr setclock binding/capability

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 本轮新增：
  - `TPThreadCondAttrSetClockProc`
  - `platform_posix_pthread_mutex_init_kind`
  - `platform_posix_pthread_condvar_init_with_clock`
- `linux/android/darwin/freebsd/unix.ffi` 继续暴露既有 public helper 名给
  `platform.sync` 消费，但：
  - `platform_pthread_mutex_init` 改为委托 shared
    `platform_posix_pthread_mutex_init_kind`
  - `platform_pthread_condvar_init` 改为委托 shared
    `platform_posix_pthread_condvar_init_with_clock`
- host ffi 继续保留：
  - `platform_pthread_mutex_init_platform_kind` 中的宿主 kind truth
  - `platform_pthread_condattr_setclock` 绑定与
    `PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` /
    `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED`
- 这批不改变 `platform.sync` public API，也不新增新的平台 ABI declaration family。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，要求 `posix.ffi` 暴露 shared pthread attr-init helper
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 POSIX host ffi 委托 shared pthread attr-init helper
- [x] 在 `posix.ffi` 实现 shared pthread attr-init helper
- [x] 让 `linux/android/darwin/freebsd/unix.ffi` 委托 shared attr-init helper
- [x] focused：`test_platform_posix_ffi_surface` /
      `test_platform_sync_host_ffi_surface` /
      `test_platform_sync` /
      `test_platform_thread_host_ffi_surface` /
      `test_platform_time_host_ffi_surface` /
      `test_platform_simulated_host_compile_matrix` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在
    `posix.ffi must expose shared pthread mutex init-with-kind helper for host ffi owners`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate pthread mutex attr-init glue to shared posix.ffi`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `corePlatformPosixFfiSurfaceCheck":"pass"`、
    `corePlatformSyncHostFfiSurfaceCheck":"pass"`、
    `corePlatformSimulatedHostCompileMatrixCheck":"pass"`、
    `corePlatformSyncCheck":"pass"`、
    `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 这批不改变 `platform.sync` public contract
- 这批不把 `platform_pthread_mutex_init_platform_kind` 的宿主 kind truth 移出 host ffi owner
- 这批不把 Darwin / Android / FreeBSD / generic Unix 的 compile-only proof 包装成新的 runtime evidence

## Addendum: 2026-05-27 Platform POSIX Clock/Sync Shared Helper Ownership

### Goal

继续把 POSIX host ffi 中仍然重复的 clock / sync 薄转发收回 shared owner：

- `linux/android/darwin/freebsd/unix.ffi` 不再各自重复 `clock_gettime` / `clock_getres`
  包装和 `timespec -> ns` 投影
- `pthread_mutex_*`、`pthread_rwlock_*`、`pthread_cond_*` 的 host-independent forwarder
  不再在 5 个 host ffi 里各写一份
- host ffi 继续只保留 clock id、timeout clock id、errno binding、mutex/condattr capability
  这类宿主 truth

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 本轮新增 truly shared helper：
  - `platform_posix_clock_now`
  - `platform_posix_clock_getres`
  - `platform_posix_clock_ns_u64`
  - `platform_posix_clock_resolution_ns_u64`
  - `platform_posix_pthread_mutex_destroy/lock/trylock/unlock`
  - `platform_posix_pthread_rwlock_init/destroy/rdlock/tryrdlock/wrlock/trywrlock/unlock`
  - `platform_posix_pthread_condvar_destroy/wait/timedwait_abs/signal/broadcast`
- `linux/android/darwin/freebsd/unix.ffi` 继续暴露既有 public helper 名给
  `platform.time` / `platform.sync` 消费，但实现改为委托 shared `posix.ffi` helper。
- Darwin 的 `darwin_mach_monotonic_ns` /
  `darwin_mach_monotonic_resolution_ns` 继续留在 host owner，不向 shared helper 收窄。
- 旧 `codex/platform-time-integration` 继续只作为历史参考；这批直接在当前 `main` 上收口。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，要求 `posix.ffi` 暴露 shared clock/sync helper
- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求 POSIX host ffi 委托 shared clock helper
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 POSIX host ffi 委托 shared sync helper
- [x] 在 `posix.ffi` 实现 shared clock/sync helper
- [x] 让 `linux/android/darwin/freebsd/unix.ffi` 委托 shared helper
- [x] focused：`test_platform_posix_ffi_surface` / `test_platform_time_host_ffi_surface` /
      `test_platform_sync_host_ffi_surface` / `test_platform_time_helpers` /
      `test_platform_sync` / `test_platform_thread_host_ffi_surface` /
      `test_platform_simulated_host_compile_matrix` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在
    `posix.ffi must expose shared POSIX clock read helper for host ffi owners`。
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate raw POSIX clock reads to shared posix.ffi`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate timeout clock reads to shared posix.ffi`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `corePlatformPosixFfiSurfaceCheck":"pass"`、
    `corePlatformTimeHostFfiSurfaceCheck":"pass"`、
    `corePlatformSyncHostFfiSurfaceCheck":"pass"`、
    `corePlatformSimulatedHostCompileMatrixCheck":"pass"`、
    `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 这批不改 `platform.time` / `platform.sync` public API
- 这批不把 Darwin mach monotonic truth 收窄到 shared owner
- 这批不把 source-surface / compile-only 证据包装成新的 Darwin / Android / FreeBSD runtime truth

## Addendum: 2026-05-27 Platform Thread Shared POSIX Helper Ownership

### Goal

继续把 `platform.thread` 相关的 shared POSIX glue 从各 host ffi 内部复制收回到 shared owner：

- `pthread_self` token 投影、`pthread_create/join/detach`、`sched_yield`、TLS key 读写、
  `sysconf` 正数投影不再在 `linux/android/darwin/freebsd/unix.ffi` 各写一份
- `nanosleep` 的 request 组装与 retry loop 继续留在 FFI 层，但 shared 逻辑下沉到 `posix.ffi`
- host ffi 继续保留 errno binding、`EINTR`、`_SC_NPROCESSORS_ONLN` 与 native thread id ABI

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 本轮新增 shared thread helper：
  `platform_posix_thread_self_token_u64`、
  `platform_posix_sysconf_positive_i32`、
  `platform_posix_pthread_create_handle`、
  `platform_posix_pthread_join_handle`、
  `platform_posix_pthread_detach_handle`、
  `platform_posix_pthread_yield`、
  `platform_posix_pthread_sleep_ns`、
  `platform_posix_pthread_tls_create/destroy/set/get`。
- `linux/android/darwin/freebsd/unix.ffi` 继续暴露既有 public helper 名给 `platform.thread`
  消费，但其实现改为委托 shared `posix.ffi` helper。
- `platform.thread` public API、宿主选择方式与 native thread id contract 不变；这批只收口
  shared-vs-host ownership。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，要求 `posix.ffi` 暴露 shared pthread/thread helper
- [x] RED：扩 `test_platform_thread_host_ffi_surface`，要求 POSIX host ffi 委托 shared `posix.ffi`
- [x] 在 `posix.ffi` 实现 shared pthread/thread helper
- [x] 让 `linux/android/darwin/freebsd/unix.ffi` 委托 shared helper
- [x] focused：`test_platform_posix_ffi_surface` / `test_platform_thread_host_ffi_surface` /
      `test_platform_thread` / `test_platform_sync_host_ffi_surface` /
      `test_platform_sync` / `test_platform_simulated_host_compile_matrix` 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在
    `posix.ffi must expose shared pthread self-token projection for platform.thread host owners`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must delegate pthread self-token projection to shared posix.ffi`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - fresh `make -C core test`
  - fresh `make -C core examples`
  - fresh `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `corePlatformPosixFfiSurfaceCheck":"pass"`、
    `corePlatformThreadHostFfiSurfaceCheck":"pass"`、
    `corePlatformThreadCheck":"pass"`、
    `corePlatformSimulatedHostCompileMatrixCheck":"pass"` 与
    `verify-local=pass` / `human-summary=local verification passed`。

### Non-goals

- 这批不改 `platform.thread` public API
- 这批不把 `platform.time` / `platform.sync` 的 shared POSIX wrapper 一次性全部收口
- 这批不把 compile-only 证据包装成 Darwin / Android / FreeBSD 的 runtime truth

## Addendum: 2026-05-27 Platform Time Windows Math Helper Boundary

### Goal

把 `platform.time` 里纯 QPC 换算逻辑继续从 consumer 收回 owner-side helper，同时避免非 Windows
宿主为了复用纯数学换算而被 `windows.ffi` 污染链接：

- Linux/macOS/Unix 链接路径不能因为 `platform_qpc_to_ns` / `platform_resolution_from_frequency_ns`
  去拉 `kernel32`
- `windows.ffi` 继续拥有真正的 Windows ABI 与 host-owned clock helper
- 纯 QPC 数学换算放进同 host family 的普通 helper unit，而不是伪装成新的 `*.ffi.pas`

### Architecture Decision

- `*.ffi.pas` 继续只表示拥有 `external` ABI declaration 的 owner 单元；纯 helper 不再命名成
  `*.ffi.pas`，避免和 `test_platform_ffi_owner_boundary` 以及文档规则冲突。
- 这批新增 `core/src/nextpas.core.platform.windows.math.pas`，承载
  `windows_qpc_to_ns` / `windows_qpc_resolution_ns` 与相关饱和乘除换算。
- `platform.time` 在 Windows 目标继续通过 `windows.ffi` 暴露的 helper 名消费 Windows 时钟契约；
  非 Windows 目标则复用 `windows.math`，从而保持纯换算语义一致但不引入 `kernel32` 链接依赖。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：`test_platform_time_helpers` 在 Linux 上暴露 `-lkernel32` 链接污染
- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求存在 helper-only Windows math sibling
- [x] 新增 `nextpas.core.platform.windows.math`
- [x] 让 `windows.ffi` 委托纯 QPC 数学给 `windows.math`
- [x] 让 `platform.time` 在非 Windows 目标复用 `windows.math`
- [x] 修正 helper unit 命名，避免把纯 helper 伪装成 `*.ffi.pas`
- [x] focused：`test_platform_time_helpers` / `test_platform_time_host_ffi_surface` /
      `test_platform_ffi_owner_boundary` / Win64 compile-only 通过
- [x] fresh `make -C core test`
- [x] fresh `make -C core examples`
- [x] fresh `make -C core benchmarks`
- [x] fresh `bash build/verify_local.sh`

### Non-goals

- 这批不改 `platform.time` public API 名称
- 这批不新增 Windows runtime 证据
- 这批不把 `platform.time` 里的其余 host-owned clock helper 全部重画边界

## Addendum: 2026-05-27 Platform Sync Windows Timeout Result FFI Ownership

### Goal

继续把 Windows wait timeout 语义从 `platform.sync` consumer 收回 `windows.ffi` owner：

- `platform.sync` 不再自己判断 `windows_error_i32_is_timeout`
- Windows condvar timedwait / address-wait 的 timeout classifier 分支不再散落在 consumer
- caller 仍然保留 nextPas public timeout result 常量的最终选择权

### Architecture Decision

- `SleepConditionVariableSRW` / `WaitOnAddress` 的 raw ABI、`GetLastError` 读取与 `ERROR_TIMEOUT`
  classifier 继续归 `nextpas.core.platform.windows.ffi`。
- 为了不把 nextPas public error 常量硬编码进 ffi owner，这批采用 caller-supplied timeout result
  形态：`windows_condvar_timedwait_timeout_result`、
  `windows_wait_address_i32_timeout_result`。
- `platform.sync` 继续保留 public contract 与 generic error surface，但不再自己写 Windows timeout
  classifier 分支。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 `windows.ffi` 拥有 timeout-result helper
- [x] RED：禁止 `platform.sync` 继续消费 `windows_error_i32_is_timeout` 与 raw timedwait timeout helper
- [x] 在 `windows.ffi` 实现 timeout-result helper
- [x] 切换 `platform.sync` Windows condvar/address-wait consumer
- [x] 同步 design/tracking 文档
- [x] 跑 focused tests
- [x] 跑 fresh `make -C core test`
- [x] 跑 fresh `make -C core examples`
- [x] 跑 fresh `make -C core benchmarks`
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must expose Windows condvar timedwait helper that maps timeout semantics for sync`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Full:
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `corePlatformSyncHostFfiSurfaceCheck":"pass"`、
    `corePlatformSyncCheck":"pass"`、`verify-local=pass` 与
    `human-summary=local verification passed`。

### Non-goals

- 这批不把 `PLATFORM_ERR_TIMEOUT` 常量硬编码进 `windows.ffi`
- 这批不改 `platform.sync` public API
- 这批不处理 Windows trylock busy-result 映射

## Addendum: 2026-05-27 Platform Sync POSIX Helper FFI Ownership

### Goal

继续把 `platform.sync` 里剩余的 shared POSIX helper duplication 收回正确 owner：

- shared `timespec` deadline arithmetic 不再在 `platform.sync` 本地复制
- public mutex kind 到宿主 pthread kind 的映射不再停在 consumer
- owner boundary 继续保持克制，不把整个 wait-bucket / deadline policy 都粗暴塞进 ffi

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 可以拥有真正跨 POSIX 宿主共享的 helper，不只限于 raw `external`
  声明；这批新增的就是 shared `timespec -> ns`、`timespec + ns` 与 remaining-time 算术。
- `TPlatformMutexKind` 到宿主 pthread mutex kind 编号的映射属于 host-owned contract，应该由
  `linux/android/darwin/freebsd/unix.ffi` 各自暴露统一 helper
  `platform_pthread_mutex_init_platform_kind`。
- `platform.sync` 继续保留 public opaque storage contract、error mapping、deadline 计算与
  wait-bucket 策略；这批不重划更大的 sync ownership 边界。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 `test_platform_posix_ffi_surface`，要求 shared `posix.ffi` 显式暴露 POSIX timespec 算术 helper
- [x] 扩 `test_platform_sync_host_ffi_surface`，要求 host ffi owner 暴露 public mutex kind init helper
- [x] 删除 `platform.sync` 本地 timespec / mutex-kind helper duplication，切到 ffi owner helper
- [x] 同步 design/tracking 文档
- [x] 跑 focused tests
- [x] 跑 fresh `make -C core test`
- [x] 跑 fresh `make -C core examples`
- [x] 跑 fresh `make -C core benchmarks`
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - 扩完 `test_platform_posix_ffi_surface` 与 `test_platform_sync_host_ffi_surface` 后，主线先暴露出
    shared POSIX timespec helper 缺失与 `platform.sync` 仍保留 local mutex-kind / deadline helper
    duplication 的 owner-boundary 失败。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `corePlatformPosixFfiSurfaceCheck":"pass"`、
    `corePlatformSyncHostFfiSurfaceCheck":"pass"`、`corePlatformSyncCheck":"pass"`、
    `corePlatformSimulatedHostCompileMatrixCheck":"pass"`、`verify-local=pass` 与
    `human-summary=local verification passed`。

### Non-goals

- 这批不把 `platform.sync` 的 wait-bucket strategy 下沉到 ffi owner
- 这批不新增 public sync API
- 这批不把 compile-only evidence 包装成 Darwin / Android / FreeBSD 的真实 runtime truth

## Addendum: 2026-05-27 Platform Simulated Host Compile Matrix

### Goal

给 `platform` 宿主分支补一条诚实的 compile-proof：

- 在 Linux 主机上用 test-only host override 驱动 Darwin / Android / FreeBSD / generic Unix
  分支选择
- compile-only 验证 `platform.time` / `platform.thread` / `platform.sync` 连同对应 host ffi
  单元的编译自洽
- 把这条 proof 接进 `build/verify_local.sh`，但明确它不是 runtime evidence

### Architecture Decision

- `nextpas.core.settings.inc` 允许 test-only `NEXTPAS_FORCE_HOST_*` 宏覆盖宿主选择，范围仅限独立测试
  项目和 compile-only 证明。
- 这类 proof 验证的是 branch selection correctness、public API surface 与 host ffi compile coherence，
  不是 cross toolchain / cross runtime truth。
- generic Unix fallback 已有 `nextpas.core.platform.unix.ffi` 承载 POSIX clock helper，因此
  `NEXTPAS_POSIX_CLOCK` 必须成为 generic Unix contract 的一部分，不能让 `platform.time`
  继续把 generic Unix 当成 unsupported。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：新增独立 `test_platform_simulated_host_compile_matrix` 项目并在主线上先跑出失败
- [x] 在 `nextpas.core.settings.inc` 增加 test-only `NEXTPAS_FORCE_HOST_*` override
- [x] 修掉 simulated matrix 暴露出的真实分支缺陷
- [x] 将 simulated host compile matrix 接入 `build/verify_local.sh`
- [x] 同步 design/tracking 文档
- [x] 跑 fresh `make -C core test`
- [x] 跑 fresh `make -C core examples`
- [x] 跑 fresh `make -C core benchmarks`
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    初始失败在
    `simulated darwin compile must select NEXTPAS_MACOS`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出四条 target pass 与 `simulated-host-compile-matrix-status=pass`。
- Full:
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `core-platform-simulated-host-compile-matrix-check=pass`、
    `corePlatformSimulatedHostCompileMatrixCheck":"pass"`、`verify-local=pass` 与
    `human-summary=local verification passed`。

### Non-goals

- 这批不把 simulated compile-only proof 伪装成 Darwin / Android / FreeBSD / generic Unix 的真实
  runtime 证据
- 这批不引入新的 public platform API
- 这批不替代后续真实 cross toolchain / runtime 验证

## Addendum: 2026-05-27 Platform Windows Timeout Conversion FFI Ownership

### Goal

继续把 Windows host-specific timeout/sleep policy 收回 `windows.ffi` owner 单元：

- `platform.sync` 不再自己拥有 ns->ms timeout helper
- `platform.thread` 不再自己拥有 Windows sleep rounding/saturation 逻辑
- `windows.ffi` 统一拥有向上取整、`INFINITE` sentinel 与最大有限毫秒截断 policy

### Architecture Decision

- `Sleep`、`WaitOnAddress`、`SleepConditionVariableSRW` 本身继续是 Windows ABI declaration，归
  `nextpas.core.platform.windows.ffi`。
- 与这些 ABI 一起出现的 timeout/sleep conversion truth 也归 `nextpas.core.platform.windows.ffi`；
  这不是 generic arithmetic，而是 Windows wait API contract 的一部分。
- `platform.sync` / `platform.thread` 继续只消费 helper/token，不各自复制 Windows policy。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 thread/sync host ffi surface tests，要求 `windows.ffi` 拥有 timeout/sleep helper
- [x] RED：要求 `platform.sync` / `platform.thread` 消费 helper，并禁止 local helper/raw literal 回归
- [x] 在 `windows.ffi` 实现统一 timeout/sleep conversion helper
- [x] 切换 `platform.sync` / `platform.thread` 的 Windows consumer
- [x] 同步 design/tracking 文档
- [x] 跑 focused tests
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must expose Windows sleep timeout conversion policy`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must expose Windows wait timeout conversion policy`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    通过。
- Full: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不改 `platform.sync` / `platform.thread` 的 public API
- 这批不引入新的 Windows runtime feature detection
- 这批不处理 wait result / last-error mapping 的进一步 ownerization

## Addendum: 2026-05-27 Platform Time Windows FILETIME Host FFI Ownership

### Goal

继续把 `platform.time` 的宿主时钟真相从实现层字面量收回到 host-specific FFI owner：

- Windows `FILETIME` 的 Unix epoch offset 不能继续裸写在 `platform.time`
- Windows `FILETIME` 的 tick size（100ns）也不能继续裸写在 `platform.time`
- focused gate 必须同时冻结 “owner 在 `windows.ffi`” 与 “实现层不回归魔数”

### Architecture Decision

- Windows `FILETIME` 的 API entry points 继续归 `nextpas.core.platform.windows.ffi`。
- 与该 ABI 绑定的 epoch/tick truth 也归 `nextpas.core.platform.windows.ffi`；这类事实不是 shared
  clock algebra，而是宿主时间 ABI 的一部分。
- `platform.time` 继续只负责换算流程与稳定 L0 contract，不再保存 Windows-specific magic number。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求 `windows.ffi` 拥有 FILETIME epoch/tick token
- [x] RED：要求 `platform.time` 消费这些 token，并禁止裸 epoch 魔数回归
- [x] 将 FILETIME epoch/tick truth 下沉到 `windows.ffi`
- [x] 调整 `platform.time` 的 Windows realtime 换算逻辑
- [x] 同步设计约定与 tracking 文档
- [x] 跑 focused tests
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在
    `windows.ffi must own the FILETIME unix epoch offset token for platform.time`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
    通过。
- Full: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不改 `platform.time` 的 public API
- 这批不宣称新的 Windows runtime 证据矩阵已经补齐
- 这批不处理 Darwin mach timebase caching policy

## Addendum: 2026-05-27 Platform Thread Sleep EINTR FFI Ownership

### Goal

继续把 `platform.thread` 的宿主错误语义从实现层下沉到 host-specific FFI owner：

- retryable `nanosleep` errno truth 不能再隐含在实现层 while-loop 里
- Linux / Android / macOS / FreeBSD / generic Unix 各自都要显式拥有 `EINTR` token
- `platform.thread` 必须消费 host-owned errno binding 与 `EINTR` token，而不是对任意错误一律重试

### Architecture Decision

- `nanosleep` 本身仍属于 shared POSIX ABI，所以继续留在 `posix.ffi`。
- “什么错误可以安全重试”属于宿主 errno truth，继续归 `linux/darwin/android/freebsd/unix` 各自 FFI owner。
- `platform.thread` 继续只负责线程 API 契约与 sleep policy，不再凭实现层假设“所有 Unix 错误都可重试”。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 focused tests，要求 host ffi 暴露 `PLATFORM_POSIX_EINTR`
- [x] RED：扩 focused tests，要求 `platform.thread` 消费 host-owned errno binding 与 `EINTR`
- [x] 将 `PLATFORM_POSIX_EINTR` 下沉到各 Unix host ffi
- [x] 调整 `platform.thread` 的 POSIX sleep 只在 `EINTR` 上重试
- [x] 同步设计约定与跟踪文档
- [x] 跑 focused tests
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
    初始失败在 `linux.ffi must expose Linux EINTR for retryable sleep semantics`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux EINTR for retryable nanosleep`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
    通过。
- Full: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不引入新的 thread public API
- 这批不宣称 Darwin / FreeBSD / Android 已获得新的真实 runtime 证据
- 这批不扩展 signal handling 抽象

## Addendum: 2026-05-27 Platform Sync Pthread Capability FFI Ownership

### Goal

继续把 `platform.sync` 需要的宿主 pthread capability / policy truth 从 shared `posix.ffi`
与实现层条件编译下沉到 host-specific FFI owner：

- `pthread_mutex_*` kind 编号必须进入各自 host ffi
- `pthread_condattr_setclock` 的符号拥有权与“是否支持”事实必须进入各自 host ffi
- condvar timedwait 使用哪个 clock id 也必须成为 host-owned token

### Architecture Decision

- `nextpas.core.platform.posix.ffi` 只继续拥有 shared POSIX ABI 形状，不再拥有 per-host mutex kind
  编号，也不继续拥有 `pthread_condattr_setclock` 这种宿主可用性会分叉的绑定。
- `linux/darwin/android/freebsd/unix` 各自拥有
  `PLATFORM_PTHREAD_MUTEX_*_KIND`、
  `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED`、
  `PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` 与
  `platform_pthread_condattr_setclock`。
- `platform.sync` 继续只负责把这些 host-owned truth 组装成稳定的 nextPas 同步契约，不再自己知道
  “macOS 例外” 或 FreeBSD mutex kind 编号。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 focused tests，要求 `posix.ffi` 退出 pthread capability ownership
- [x] RED：扩 focused tests，要求 `platform.sync` 消费新的 host-owned pthread capability token
- [x] 将 pthread mutex kind / condattr clock capability / timeout clock policy 下沉到 host ffi
- [x] 调整 `platform.sync` 消费新的 host-owned token
- [x] 同步设计约定文档
- [x] 跑 focused tests
- [x] 跑 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
    初始失败在 `posix.ffi must not keep per-host pthread mutex kind numbering after ffi partitioning`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `platform.sync must consume host-owned pthread mutex normal numbering`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    通过。
- Full: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不声称 Darwin / FreeBSD / Android 已获得新的真实 runtime 证据
- 这批不扩展新的 L1 sync API
- 这批不新增 Windows-only pthread compatibility 抽象

## Addendum: 2026-05-27 Platform Sync Host FFI Surface Guard

### Goal

给 `platform.sync` 补上和 `platform.time` / `platform.thread` 对等的 host-ffi surface 守卫：

- focused test 必须冻结 `platform.sync` 对 Linux futex ABI、Windows wait-on-address ABI、
  以及 host-owned errno/clock token 的消费关系
- `build/verify_local.sh` 必须把这条新 gate 纳入 official envelope
- 这批收口后要把旧 `platform-time-integration` worktree 的 merge 价值说清楚，避免把过期平台分支误认成待合主线

### Architecture Decision

- `platform.sync` 的生产实现继续只负责同步原语契约、等待策略与错误映射，不在实现单元重新散落 ABI declaration。
- Linux futex ABI 继续归 `nextpas.core.platform.linux.ffi`，Windows wait-address ABI 继续归
  `nextpas.core.platform.windows.ffi`，shared pthread ABI 继续归 `nextpas.core.platform.posix.ffi`，
  host-owned errno/clock token 继续归 `android/darwin/freebsd/unix` 等目标 FFI owner 单元。
- source-surface gate 只冻结“谁拥有 ABI、谁消费 ABI”，不把它伪装成 Darwin / FreeBSD / Android
  已有新的真实 runtime 证据。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：确认 `test_platform_sync_host_ffi_surface` 目录缺失
- [x] RED：确认 `build/verify_local.sh` 尚无 sync host ffi surface gate
- [x] 新增 platform.sync host ffi surface focused test 与独立 Makefile
- [x] 把新 gate 接进 `build/verify_local.sh` 与 final envelope
- [x] 运行 focused test
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 复盘 `platform-time-integration` worktree 的 merge 价值

### Verification

- RED:
  - `test -d core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface`
    初始失败。
  - `rg -n "core-platform-sync-host-ffi-surface-check|corePlatformSyncHostFfiSurfaceCheck" build/verify_local.sh`
    初始无结果。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-sync-host-ffi-surface-check=pass`、
  `corePlatformSyncHostFfiSurfaceCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不修改 `platform.sync` 的行为语义或 public API
- 这批不宣称 Darwin / FreeBSD / Android 已获得新的 host-side runtime 证据
- 这批不直接整条合并旧 `platform-time-integration` worktree

## Addendum: 2026-05-27 Platform Time Host FFI Surface Guard

### Goal

给 `platform.time` 补上和 `platform.thread` 对等的 host-ffi surface 守卫：

- focused test 必须冻结 `platform.time` 对 POSIX/Darwin/Windows 时钟 ABI 的消费关系
- `build/verify_local.sh` 必须把这条新 gate 纳入 official envelope
- `platform.time` 自己的 focused helper tests 要 direct 覆盖 `platform_realtime_ns` 与
  `platform_monotonic_resolution_ns`

### Architecture Decision

- `platform.time` 的生产实现继续只负责稳定 clock contract 与换算逻辑，不散落 ABI declaration。
- 宿主 ABI truth 继续归 `platform.posix.ffi`、`platform.darwin.ffi`、`platform.windows.ffi`
  等 owner 单元；time-focused source-surface 只验证“谁拥有 ABI、谁消费 ABI”。
- 这批不把 source-surface gate 伪装成 Darwin / FreeBSD / Android 已有真实 runtime 证据。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：确认 `test_platform_time_host_ffi_surface` 目录缺失
- [x] RED：确认 `build/verify_local.sh` 尚无 time host ffi surface gate
- [x] 新增 platform.time host ffi surface focused test 与独立 Makefile
- [x] 给 time helpers 追加 direct public API coverage
- [x] 把新 gate 接进 `build/verify_local.sh` 与 final envelope
- [x] 运行 focused tests
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `test -d core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface`
    初始失败。
  - `rg -n "core-platform-time-host-ffi-surface-check|corePlatformTimeHostFfiSurfaceCheck" build/verify_local.sh`
    初始无结果。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
    输出 `11 total, 11 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-time-host-ffi-surface-check=pass`、
  `corePlatformTimeHostFfiSurfaceCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不修改 `platform.time` 生产 ABI 或换算语义
- 这批不宣称 Darwin / FreeBSD / Android 已获得新的 host-side runtime 证据
- 这批不把 L1 `Duration` / `Instant` / `Stopwatch` 混入 platform

## Addendum: 2026-05-27 Platform Thread Native Thread ID Host FFI Hardening

### Goal

把 `platform_thread_id` 从“Unix 下一律拿 `pthread_self` 强转”继续收紧成更诚实的 host-owned ABI：

- Linux / Android 走宿主 `gettid`
- macOS 走 `pthread_threadid_np`
- FreeBSD 走 `pthread_getthreadid_np`
- generic Unix 才保留 `pthread_self` fallback

同时把这批 host-native thread id surface 固定进 focused gate 与 `verify-local` envelope。

### Architecture Decision

- `platform_thread_self` 与 `platform_thread_id` 是两个不同层次的契约：
  前者是 platform token，后者是宿主 native integer thread id。
- host-specific native thread id ABI 必须继续沉到各自 `platform.*.ffi.pas`，而不是让
  `platform.thread` 去假设所有 POSIX 都能把 `pthread_self` 当整数 id。
- 这批不引入新的 L1 thread 抽象，也不把 generic Unix fallback 冒充成 Darwin/FreeBSD/Android
  的真实宿主语义。

### Status

Completed; verification passed.

### Planned Steps

- [x] 先补 RED：让 Linux behavior test 与新的 source-surface test 暴露 thread id FFI 缺口
- [x] 在 `linux.ffi` / `android.ffi` / `darwin.ffi` / `freebsd.ffi` 补 native thread id 声明
- [x] 修改 `platform.thread` 按 host 选择 native thread id ABI
- [x] 把新的 source-surface gate 接进 `build/verify_local.sh`
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
    初始失败在 `Identifier not found "gettid"`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux native thread id ABI: function gettid`。
- GREEN focused:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_l0_boundary clean test`
    通过。
- Aggregate: fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks`
  通过。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-thread-host-ffi-surface-check=pass`、
  `corePlatformThreadHostFfiSurfaceCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不把 `platform_thread_self` 重新定义成 native integer thread id
- 这批不宣称 Darwin / FreeBSD / Android 已获得新的 host-side runtime 证据
- 这批不在 `platform` 层引入更高层线程抽象

## Addendum: 2026-05-27 Platform FFI Owner Boundary Guard

### Goal

把“platform 所需 ABI 归 FFI 子模块所有”从局部约定提升成整组 `platform` 单元的官方 guard：

- 非 `*.ffi.pas` 的 platform 单元不得直接声明 `external` ABI。
- `platform.*.ffi.pas` 必须继续承担 ABI owner 角色，而不是退回实现层散落 `external`。
- 旧的按模块切碎 FFI 形态（例如 `platform.sync.windows.ffi`）不能死灰复燃。

### Architecture Decision

- `platform.time`、`platform.thread`、`platform.sync` 这些实现单元负责策略、错误映射与稳定契约，
  不负责 ABI declaration。
- “所有 `external` 都沉到 `platform.*.ffi.pas`” 应该是整组 `nextpas.core.platform*.pas`
  的通用约束，而不是只靠 `sync` / `time` / `thread` 各自零散静态检查。
- Windows FFI 继续优先保持 host-owned 归并，不接受重新拆回 `platform.sync.windows.ffi`
  这种按模块切碎的 owner 形态。

### Status

Completed; verification passed.

### Planned Steps

- [x] 写新的 platform-level owner-boundary test project
- [x] 在测试里扫描整组 `nextpas.core.platform*.pas`
- [x] 固定非 ffi 单元不得直接声明 `external`
- [x] 固定 ffi 单元必须继续拥有 `external`
- [x] 固定 `platform.sync.windows.ffi` 不得回归
- [x] 把新 gate 接进 `build/verify_local.sh`
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- RED: `test -d core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary` 初始失败，
  证明这条 guard 还不存在。
- GREEN focused:
  `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  通过。
- Aggregate: fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks`
  通过。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-ffi-owner-boundary-check=pass`、
  `corePlatformFfiOwnerBoundaryCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不新增宿主 ABI
- 这批不宣称新增 Darwin / FreeBSD / Android runtime 证据
- 这批不替代后续更细的 host-specific compile/runtime matrix 工作

## Addendum: 2026-05-27 Platform Host-owned FFI Partitioning

### Goal

把 `platform` 的宿主 ABI 真相继续从共享 POSIX 包装层里剥离出来：

- `nextpas.core.platform.posix.ffi` 只保留共享 POSIX ABI 声明。
- Linux、macOS、Android、FreeBSD 与 generic Unix 各自拥有自己的 clock id、`sysconf`
  id、errno 常量与 errno symbol binding。
- 这条 ownership 不只停在源码 diff，而要进入 focused gate 和 `verify-local`
  machine-readable envelope。

### Architecture Decision

- `platform.posix.ffi` 是 shared ABI owner，不再承载 per-host 常量和符号名。
- host-specific truth 必须放进按目标划分的 `platform.*.ffi.pas`；generic Unix fallback 也要有
  自己的 `platform.unix.ffi`，避免继续把 Linux 近似值冒充“通用 Unix”。
- `platform.time`、`platform.thread`、`platform.sync` 只选择并消费对应 host FFI unit，不在实现层
  重新散落宿主 token。

### Status

Completed; verification passed.

### Planned Steps

- [x] 从 `platform.posix.ffi` 移出 host-owned `CLOCK_*`、`_SC_NPROCESSORS_ONLN`、errno surface
- [x] 扩充 `linux.ffi` / `darwin.ffi`，并新增 `android.ffi`、`freebsd.ffi`、`unix.ffi`
- [x] 让 `platform.time`、`platform.thread`、`platform.sync` 切到 host-owned FFI unit
- [x] 新增 `test_platform_ffi_partition_surface`
- [x] 把新 gate 与新文件接进 `build/verify_local.sh`
- [x] 修正新 gate 只在测试目录下才能解析源码路径的运行入口缺口
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- RED: 首次 fresh `bash build/verify_local.sh` 失败在
  `core-platform-ffi-partition-surface-run-failed`；根因是新测试只会按测试目录相对路径读取源码，
  从 repo root 执行时触发 `File not found`。
- GREEN focused:
  `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`、
  `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`、
  `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
  通过。
- Aggregate: fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks`
  通过。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-ffi-partition-surface-check=pass`、
  `corePlatformFfiPartitionSurfaceCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不宣称 Darwin / FreeBSD / Android 已有新的 host-side runtime 证据
- 这批不新增新的 L0 public API
- 这批不把 source-surface proof 伪装成 cross-target compile/runtime closure

## Addendum: 2026-05-27 Platform Sync FFI-owned Opaque Size Derivation

### Goal

把 `platform.sync` 的 public opaque size contract 再往 FFI owner 方向推进一步：

- POSIX size 直接由 `pthread_*` FFI 类型决定，而不是 wrapper 再重复一套平台分支。
- Windows size 直接由 `SRWLOCK` / `CONDITION_VARIABLE` FFI 类型决定，而不是 wrapper
  继续手写数字。
- 这条 ownership 进入 source-surface test，而不是只留在代码风格层。

### Architecture Decision

- wrapper implementation 可以保留 policy 和 error mapping，但 ABI type/size truth 尽量只放在
  `platform.*.ffi.pas`。
- `platform.sync` 的 interface 如果需要公开依赖 `SizeOf(...)`，可以直接 uses nextPas-owned
  FFI 单元；这比在 wrapper 里复制平台数字更诚实。

### Status

Completed; verification passed.

### Planned Steps

- [x] 先把 source-surface test 改成要求 `SizeOf(...)` ownership
- [x] 跑一次 RED，确认当前实现确实还在重复写 size 常量
- [x] 在 Windows FFI 中补 `SRWLOCK` / `CONDITION_VARIABLE` 类型
- [x] 改 `platform.sync` interface size 常量为从 FFI 类型派生
- [x] 跑 focused tests
- [x] 跑 Win64 compile-only proof

### Verification

- RED: fresh `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
  失败在 `platform_mutex_size = sizeof(pthread_mutex_t)` token 缺失。
- GREEN focused: `test_platform_sync_posix_surface clean test`、
  `test_platform_sync_sizes clean test` 通过。
- GREEN Win64 compile-only:
  `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FUcore/build/review-win64-sync -FEcore/build/review-win64-sync -Fucore/src -Ficore/src core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`
  通过。

### Non-goals

- 这批不改变 `platform.sync` 行为语义
- 这批不声称 Darwin/FreeBSD/Android 已新增 runtime 证据
- 这批不新增新的 L0 public API

## Addendum: 2026-05-27 Platform POSIX FFI Target Matrix Hardening

### Goal

把 `platform` 的 POSIX ABI 基线从 “Linux 近似值可以先顶着” 提升到更诚实的 target matrix：

- `nextpas.core.platform.posix.ffi` 的 pthread types/opaque sizes/attr kinds 要开始按 Linux、
  Android、macOS、FreeBSD 分支说真话。
- `platform.sync` 的 public opaque storage 要跟着 target matrix 收紧，至少先把 public
  size/alignment contract 调整到不明显失真。
- 这批 contract 不能只存在于源码 diff 里，要进入 focused gate 与 `verify-local`
  的 machine-readable success envelope。

### Architecture Decision

- platform FFI 继续集中在 nextPas-owned `*.ffi.pas`，实现单元只消费 ABI 声明，不回退到
  FPC 平台单元。
- 对于当前主机暂时无法 cross-compile 的 Darwin/FreeBSD/Android，先用 source-surface gate
  冻结 ABI contract，而不是伪装成“已经有真实跨平台编译证据”。
- `platform.sync` public opaque size 先优先追求 target honesty，再继续做更细的 ABI matrix
  compile/runtime proof。

### Status

Completed; verification passed.

### Planned Steps

- [x] 收紧 `nextpas.core.platform.posix.ffi` 的 pthread target matrix
- [x] 补齐 `pthread_rwlockattr_t`
- [x] 固定 FreeBSD mutex kind 编号
- [x] 调整 `platform.sync` 的 target-specific public opaque sizes
- [x] 修正 `platform.thread` 对 pointer-shaped `pthread_t` 的初始化假设
- [x] 新增 `test_platform_posix_ffi_surface`
- [x] 扩充 `test_platform_sync_posix_surface`
- [x] 把新 gate 与 sync gate result 写进 `build/verify_local.sh`
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- Focused GREEN: `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`、
  `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`、
  `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_sizes clean test`、
  `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test` 通过。
- Aggregate: fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 通过。
- Full: fresh `bash build/verify_local.sh` 输出
  `core-platform-posix-ffi-surface-check=pass`、`corePlatformPosixFfiSurfaceCheck":"pass"`、
  `corePlatformSyncCheck":"pass"`、`corePlatformSyncPosixFallbackCheck":"pass"`、
  `coreSyncPosixFallbackCheck":"pass"`、`verify-local=pass`。

### Non-goals

- 这批不宣称 Darwin/FreeBSD/Android 已有 host-side runtime 证据
- 这批不引入新的 platform public API
- 这批不把 source-surface gate 伪装成 cross-target compile proof

## Addendum: 2026-05-26 Platform Sync POSIX Fallback Runtime Coverage

### Goal

把 `platform.sync` 从 “Linux futex + Windows WaitOnAddress 已落地，其余 Unix 仍是诚实缺口”
推进到更完整的 L0 runtime 形状：

- non-Linux Unix 获得 pthread-backed address-wait fallback，而不是继续停留在 unsupported stub。
- Linux 保持 futex 默认实现，但要能在 Linux 主机上强制切到 POSIX fallback 做 host-side 真实验证。
- 这条 fallback 不只验证 `platform.sync` 自己，也要验证消费它的 `nextpas.core.sync` L1 surface。

### Architecture Decision

- `platform.sync` 继续保持“Linux 默认最快路径 + generic Unix 诚实 fallback”的双层结构，而不是把
  futex 细节抹平成对所有 Unix 都一样。
- forced fallback selector 只用于 verification，不改变 Linux 默认 runtime 策略。
- timeout/error policy 继续由 `platform.sync` 实现层统一；POSIX errno/clock/pthread ABI 仍沉到
  `nextpas.core.platform.posix.ffi`。

### Status

Completed; verification passed.

### Planned Steps

- [x] 为 POSIX errno 增加跨平台常量与 `posix_errno_location` 绑定
- [x] 把 pthread 分支从 Linux-only 扩成 generic `NEXTPAS_UNIX`
- [x] 为 generic Unix 增加 wait-bucket condvar fallback 的 address wait/wake 实现
- [x] 为 Linux 增加 `NEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK` host-side selector
- [x] 新增 source guard，固定 forced fallback surface 真实存在
- [x] 新增 `platform.sync` forced fallback Makefile gate
- [x] 新增 `nextpas.core.sync` forced fallback Makefile gate
- [x] 修正 FPC 宿主 pthread 测试 teardown 崩溃
- [x] 回写 `build/verify_local.sh`
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- RED: `test_platform_sync_posix_surface` 初版失败，因为 `platform.sync` 还没有 generic Unix
  fallback surface。
- Debug/Fix: `test_platform_sync_posix_fallback` 初版虽然 14/14 全绿，但进程在退出时 segfault；
  根因收敛到 FPC 宿主缺少 `cthreads`，修正后 forced fallback tests 稳定通过。
- GREEN focused: `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`、
  `test_platform_sync_posix_fallback clean test`、`test_platform_sync_posix_surface test`、
  `make -C core/tests/nextpas.core.sync/test_sync_posix_fallback clean test` 全部通过。
- Aggregate: fresh `make -C core test`、`make -C core examples`、`make -C core benchmarks` 通过。
- Full: fresh `bash build/verify_local.sh` 输出 `core-platform-sync-posix-surface-check=pass`、
  `core-platform-sync-posix-fallback-check=pass`、`core-sync-posix-fallback-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 这批不声称 macOS / FreeBSD / Android 已有真实宿主运行证据
- 这批不最终冻结 non-Linux Unix 的 opaque size 常量
- 这批不重构 `platform.sync` public API
- 这批不引入新的 L1 sync 抽象

## Addendum: 2026-05-26 Platform Sync FFI Surface Parity

### Goal

把 `platform.sync` 推到与 `platform.time` / `platform.thread` 同等严格的 FFI 与验证形状：

- Windows synchronization ABI 不再留在按模块切碎的 `platform.sync.windows.ffi`，而是尽量归并到
  统一平台单元 `platform.windows.ffi`。
- `platform.sync` 补齐 no-FPC、L0 boundary、example、benchmark 的 official local gates。
- sync benchmark 不再直接旁路 platform contract 去调用裸 POSIX clock FFI。

### Architecture Decision

- platform FFI 优先按宿主平台归并，而不是按 time/sync/thread 各长一套零散 Windows FFI。
- `platform.sync` 的实现层只负责策略、错误码和 timeout 语义，不在实现单元里散落 `external`
  声明。
- benchmark 可以依赖同属 L0 的 `platform.time` 取时，但不能回退到裸 `posix.ffi` 直接碰 ABI。

### Status

Completed; verification passed.

### Planned Steps

- [x] 把 Windows sync ABI 声明并入 `core/src/nextpas.core.platform.windows.ffi.pas`
- [x] 删除 `core/src/nextpas.core.platform.sync.windows.ffi.pas`，并让
      `platform.sync` 只依赖统一 Windows FFI
- [x] 新增 `platform.sync` 的 no-FPC focused test
- [x] 新增 `platform.sync` 的 L0 boundary focused test
- [x] 给 `platform_sync_basics` 增加 machine-readable 输出
- [x] 让 `bench_platform_sync` 改走 `platform.time` 的 L0 时钟源
- [x] 把 sync 的 no-FPC / L0 / example / benchmark gate 纳入 `build/verify_local.sh`
- [x] 运行 focused、aggregate 与 fresh `bash build/verify_local.sh`

### Verification

- RED: `test_platform_sync_no_fpc_units` 初版误把 `linux_syscall` 里的 `syscall` 符号当成
  FPC `Syscall` 单元引用，先失败在 `platform.sync must not reference FPC unit/token: Syscall`。
- GREEN focused: `make -C core/tests/nextpas.core.platform.sync/test_platform_sync test`、
  `test_platform_sync_no_fpc_units test`、`test_platform_sync_l0_boundary test`、
  `test_platform_sync_sizes test`、`make -C core/examples/nextpas.core.platform.sync/platform_sync_basics run`、
  `make -C core/benchmarks/nextpas.core.platform.sync/bench_platform_sync run` 全部通过。
- Aggregate: `make -C core test`、`make -C core examples`、`make -C core benchmarks` 通过。
- Full: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 这批不把 `platform.sync` 扩到 macOS / FreeBSD / Android 的 pthread runtime 语义
- 这批不重新设计 `platform.sync` public API
- 这批不引入新的 L1 sync abstraction
- 这批不改动非 platform 范围的并行工作

## Addendum: 2026-05-26 Batch 104 Function Result Call Type Mismatch Evidence

### Goal

把 Batch 81 之前明确 deferred 的 root-owned function result evidence 推进成第一条安全切片：
当 bare procedure/function call 只有 root-owned 单一 target、arity 已匹配，且参数是同一 root source 中
零参 function 的内建标量/字符串返回值时，若与 target param signature 明确不兼容，发出
`sema.type-mismatch`。

本批次新增并冻结：

- `function Flag: Boolean; Pick(Flag);` 调 `Pick(Value: Integer)` 必须失败为
  `sema.type-mismatch`，且失败调用不注册 `call` binding。
- stable function-result evidence 只接受 root-owned、零参、`function` symbol，且返回类型必须通过
  `TypeIdHasStableScalarFact(...)`。
- imported function result、带参 function result、class/record/alias/Pointer/Text/Variant、member
  function result、多 overload signature no-match 继续 deferred。
- `build/verify_local.sh` 新增 `type-mismatch-function-result-call-check`，固定 stage0 failure
  projection 与 final verify envelope 的 `typeMismatchFunctionResultCallCheck`。

### Architecture Decision

这是 value fact evidence 的第三条安全切片，不是完整 expression evaluator：

- root-owned function symbol 已经在 semantic model 中有 owner、param count 和 return type id，因此
  零参 builtin scalar/string result 可以作为 compile-time type evidence。
- 只扩展 diagnostics evidence，不改变 callable lookup 的 root/imported 优先级，不引入 implicit
  conversion、ranking、effect analysis 或 function pointer semantics。
- 失败时仍通过现有 `LookupCallBindingDeclaration(...)` 的 `type-mismatch` failure kind 投影到
  diagnostics sink。

### Status

Completed

### Planned Steps

- [x] RED：把 focused semantic guard 从 function result deferred 改成 `sema.type-mismatch`
- [x] 新增 `tests/fixtures/type_mismatch_function_result_call` 与 verify gate
- [x] 在 stable evidence 中接受 root-owned 零参 builtin function result
- [x] focused semantic gate 转绿
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-bare-function-result-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出
  `type-mismatch-function-result-call-check=pass`、`typeMismatchFunctionResultCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 imported function result 纳入 type mismatch diagnostics
- 不把带参 function result / function pointer / member function result 纳入 evidence
- 不实现 implicit conversion / overload ranking / no-matching-overload diagnostics
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Time L0 Surface Coverage

### Goal

把 `platform.time` 的可用性证明保持在 L0 系统平台 API 边界内：

- 新增 platform clock 示例项目，展示 `platform_monotonic_ns`、`platform_realtime_ns`、
  `platform_monotonic_resolution_ns` 的系统 API contract。
- 新增 platform clock 基准项目，测量 monotonic/realtime 原生 clock 调用开销。
- 新示例/基准必须位于 `nextpas.core.platform.time` 命名空间，不能出现 `Stopwatch`、`Duration`
  等 L1 convenience API。
- `build/verify_local.sh` 必须把 platform.time 边界测试、示例和基准纳入官方本地验证 envelope。

### Architecture Decision

- `platform.time` 是 L0 clock source，不是计时器、秒表或日期时间库。
- `Duration` / `Instant` / `Stopwatch` / Timer 属于 L1 `nextpas.core.time`
  或后续独立 `nextpas.core.stopwatch`，不能出现在 `nextpas.core.platform.*` 的 API、示例或基准里。
- 示例和基准只调用 platform-owned clock 函数，输出 machine-readable 状态行，便于 gate 检查。
- 旧 `codex/platform-time-integration` 中的 `demo_stopwatch` / `bench_platform_time` 不按原样合入；
  正确的 L1 time 示例应另走 `nextpas.core.time` 批次。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：确认 `core/examples/nextpas.core.platform.time/platform_time_clock` 缺失
- [x] RED：确认 `core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock` 缺失
- [x] 新增 L0 platform clock 示例项目和独立 Makefile
- [x] 新增 L0 platform clock 基准项目和独立 Makefile
- [x] 新增 L0 boundary guard 测试，防止 L1 time API 混入 platform.time
- [x] `build/verify_local.sh` 新增 platform.time boundary/example/benchmark gates
- [x] 运行 focused example/benchmark
- [x] 运行 `make -C core test`
- [x] 运行 `make -C core examples`
- [x] 运行 `make -C core benchmarks`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 复盘

### Verification

- RED: `test -f core/examples/nextpas.core.platform.time/platform_time_clock/platform_time_clock.lpr`
  失败。
- RED: `test -f core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock/bench_platform_time_clock.lpr`
  失败。
- Focused GREEN: `make -C core/examples/nextpas.core.platform.time/platform_time_clock run` 输出
  `platform-time-clock-status=pass`。
- Focused GREEN: `make -C core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock run`
  输出 `platform-time-bench-status=pass`。
- RED: `test -f core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary/test_platform_time_l0_boundary.lpr`
  失败。
- Focused GREEN: `make -C core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary test`
  输出 `nextpas.core.platform.time.l0_boundary: 4 total, 4 passed, 0 failed`。
- Aggregate GREEN: `make test` 输出 `All tests passed.`。
- Aggregate GREEN: `make examples` 输出 `All examples compiled.`。
- Aggregate GREEN: `make benchmarks` 输出 `All benchmarks passed.`。
- Official GREEN: fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeL0BoundaryCheck=pass`、`corePlatformTimeExampleCheck=pass`、
  `corePlatformTimeBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不新增 `Stopwatch` 示例或基准
- 不把 `Duration` / `Instant` 的 L1 行为放进 platform 命名空间
- 不改变 `platform.time` ABI 或 clock conversion 语义
- 不从旧 `platform-time-integration` 整条合入混杂改动

## Addendum: 2026-05-26 Batch 103 Object Release Invalid Trap Policy

### Goal

把 Batch 102 的 no-op invalid-release boundary 推进成最小真实 failure policy：

- `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 必须调用 `@llvm.trap()`。
- trap 后必须发出 `unreachable`，避免非法释放路径继续被视为可正常返回。
- 本批仍不实现结构化 diagnostics、不抛 Pascal exception、不接 `core/` allocator，也不改变 object
  header layout。

### Architecture Decision

invalid release 当前采用 always-trap 策略：

- nil receiver 仍由 `@np_object_free_release` 的 null guard 安全跳过。
- magic-valid release 仍走 `@np_object_release_valid` 并 poison header magic。
- magic mismatch 代表 double free 或 foreign payload pointer；进入 invalid helper 后触发
  `llvm.trap`，这是当前最小 fatal runtime behavior。
- helper ABI 保持 Batch 102 的 `raw` / `size` / `magic` 证据参数，后续结构化 diagnostics 可以复用。

### Status

Completed

### Planned Steps

- [x] 写 RED：invalid helper 必须调用 `@llvm.trap()`、发出 `unreachable` 并声明 intrinsic
- [x] 实现 LLVM invalid-release trap policy
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-invalid-trap-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现结构化 diagnostics / Pascal exception path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 102 Object Release Invalid Boundary

### Goal

继续推进目标树 G3 / G1.5，把 Batch 101 后仍然无声 skip 的 magic mismatch 路径升级成
compiler-owned invalid-release boundary：

- `@np_object_free_release` 在 header magic mismatch 时必须进入 `invalid:` 块。
- `invalid:` 块必须调用 `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)`，再汇合到
  `done:`。
- 本批只固定 invalid-release ABI 和后续 diagnostics/trap 挂载点，不实现 trap、不抛异常、不接
  `core/` allocator，也不改变 object header layout。

### Architecture Decision

invalid-release helper 当前是 no-op boundary：

- `raw` 仍是 object header 起点，`size` 和 `magic` 是已经读取出的 header 证据。
- mismatch path 不再和 nil receiver 一样直接静默进入 `done:`；它先进入唯一的 invalid-release
  hook，再回到 `done:`。
- helper 不做额外 dereference，不 poison header，不调用 allocator free；后续 diagnostics/trap 只能从
  这个边界继续演进。

### Status

Completed

### Planned Steps

- [x] 写 RED：magic mismatch 必须进入 `invalid:` 并调用 invalid-release helper
- [x] 实现 LLVM invalid-release boundary helper
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-header-magic-branch`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Platform API Boundary Cleanup

### Goal

纠正 platform 模块的归属边界：`platform` 是 L0 系统平台 API/ABI 适配层，只承载 OS/CPU、
thread/sync/time clock 等低层契约；`Stopwatch`、`Duration` 等用户便利抽象属于
`nextpas.core.time` 或后续更高层模块。

本批只做边界收口：

- platform.time focused tests 迁入 `core/tests/nextpas.core.platform.time/`。
- `nextpas.core.time/test_time` 继续只覆盖 L1 time public API。
- 顶层 `build/verify_local.sh` 的 platform time gates 指向 platform 命名空间。
- 平台设计约定同步 Windows FFI 文件名，并明确 Linux/macOS/Windows/Unix/BSD/Android 目标。

### Architecture Decision

- `platform` 不放 stopwatch 示例，不把 L1 time API 伪装成 platform 成果。
- platform 子模块的测试、基准、示例命名必须贴着 platform contract；L1 模块使用自己的命名空间。
- 本批不新增平台 ABI、不改 time/sync/thread 行为，只修正 ownership 和验证入口。

### Status

Completed; verification passed.

### Planned Steps

- [x] 停止并删除错误的 `platform-time-extras-preview` 切片，确认未合入 main
- [x] 写 RED：确认 `nextpas.core.platform.time` focused test 目录缺失
- [x] 将 platform.time helper/no-FPC focused tests 移到 `nextpas.core.platform.time`
- [x] 同步 `build/verify_local.sh` focused gate 路径
- [x] 同步平台设计约定中的目标平台和 Windows FFI 文件名
- [x] 跑 focused platform.time tests
- [x] 跑 `make -C core test`
- [x] 跑 `bash build/verify_local.sh`
- [x] 跑 `make -C core examples` 与 `make -C core benchmarks`
- [x] 复盘并准备提交/安全合并

### Verification

- RED: `test -d core/tests/nextpas.core.platform.time/test_platform_time_helpers` 失败，确认
  platform.time tests 仍挂在 L1 time 命名空间。
- Focused GREEN: `test_platform_time_helpers` 输出 `9 total, 9 passed, 0 failed`；
  `test_platform_time_no_fpc_units` 输出 `1 total, 1 passed, 0 failed`。
- Aggregate GREEN: `make -C core test` 输出 `All tests passed.`。
- Examples/benchmarks GREEN: `make -C core examples` 输出 `All examples compiled.`；
  `make -C core benchmarks` 输出 `All benchmarks passed.`。
- Official GREEN: fresh `bash build/verify_local.sh` 输出 `corePlatformTimeHelpersCheck=pass`、
  `corePlatformTimeNoFpcCheck=pass`、`corePlatformTimeWin64Check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不新增 stopwatch 示例或 benchmark
- 不改 `nextpas.core.time` 的 public API
- 不改 platform.time ABI/FFI 行为
- 不声明非 Linux 主机 runtime 已验证

## Addendum: 2026-05-26 Platform Thread L0 Surface Coverage

### Goal

把 `platform.thread` 收口成可证明的 L0 宿主线程 API surface：

- 行为测试覆盖 public interface，不遗漏 `platform_thread_self`。
- example/benchmark 只展示和测量 L0 thread/TLS/yield/create-join 能力。
- official local verification 明确跑 platform.thread behavior/no-FPC/L0-boundary/Win64/example/benchmark gates。
- 不把 ThreadPool、Channel、Future、Scheduler、Task 等 L1 并发抽象放进 platform 命名空间。

### Architecture Decision

- `TPlatformThreadHandle` 是 `platform_thread_create` 返回的 owned handle，只能由
  `platform_thread_join` 或 `platform_thread_detach` 消费并完成生命周期收口。
- `platform_thread_self` 返回 `TPlatformThreadToken`，表示当前线程的 unowned identity token；
  它不是可等待 handle，不能传给 join/detach，也不能假定与平台原生 handle 同形。
- POSIX/Windows 的系统 ABI 继续只通过 nextPas-owned FFI 单元声明；platform.thread 不 `uses`
  FPC `BaseUnix`、`PThreads`、`UnixType`、`Windows` 等平台单元。

### Status

Completed; verification passed.

### Planned Steps

- [x] 对齐 worktree 到最新 `main@88d4147`
- [x] 写 RED：`platform_thread_self` focused test 需要 `TPlatformThreadToken`
- [x] 修改 public API：拆分 owned handle 和 unowned self token
- [x] 补 platform.thread L0 example 和 benchmark
- [x] 补 L0 boundary static test，禁止 L1 thread API token 混入 platform.thread 源码/示例/基准
- [x] 同步 `core/docs/design-conventions.md`
- [x] 同步 `build/verify_local.sh` focused gates 和 final envelope
- [x] 跑 focused tests / example / benchmark
- [x] 跑 `make -C core test`
- [x] 跑 `make -C core examples`
- [x] 跑 `make -C core benchmarks`
- [x] 跑 fresh `bash build/verify_local.sh`
- [x] 提交前复盘，准备提交/合并/清理 worktree

### Verification

- RED: `make -C core/tests/nextpas.core.platform.thread/test_platform_thread test`
  先失败在 `Identifier not found "TPlatformThreadToken"`。
- Focused GREEN: 同一测试随后输出 `8 total, 8 passed, 0 failed`。
- Focused GREEN: no-FPC static 1/1、L0 boundary 3/3、example run pass、
  benchmark 输出 `platform-thread-bench-status=pass`。
- Root-cause fix: official verify 首次暴露 `test_platform_thread_no_fpc_units` 在仓库根运行时
  只能按测试目录相对路径找源码，失败为 `File not found`；修正后测试同时支持 test-dir/root
  两种路径。
- Aggregate GREEN: `make -C core test` 输出 `All tests passed.`。
- Examples/benchmarks GREEN: `make -C core examples` 输出 `All examples compiled.`；
  `make -C core benchmarks` 输出 `All benchmarks passed.`。
- Official GREEN: fresh `bash build/verify_local.sh` 输出 `corePlatformThreadCheck=pass`、
  `corePlatformThreadNoFpcCheck=pass`、`corePlatformThreadL0BoundaryCheck=pass`、
  `corePlatformThreadWin64Check=pass`、`corePlatformThreadExampleCheck=pass`、
  `corePlatformThreadBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 thread pool、scheduler、channel、future、async runtime。
- 不修改 `nextpas.core.thread` 的 L1 public API。
- 不声明 Windows/macOS/Android runtime 行为已在真实设备运行验证；本轮保留 Win64 compile-only gate。
- 不修改 `platform.sync` 或 `platform.time` 语义。

## Addendum: 2026-05-26 Batch 101 Object Release Poison Contract

### Goal

继续推进目标树 G3 / G1.5，把 Batch 100 的 no-op valid-release boundary 推进成最小安全行为：

- `@np_object_release_valid(ptr %raw, i64 %size)` 必须在 valid release 后把 header magic 清零。
- 后续重复释放同一 payload pointer 时，会因为 magic mismatch 走 `done:` skip 路径。
- 本批仍不实现真实 allocator free，不接入 `core/` allocator，不改变 object header layout。

### Architecture Decision

valid-release helper 当前只做 header poisoning：

- raw pointer 仍是 object header 起点，magic slot 固定为 `raw + 8`。
- poison 值固定为 `0`，与 live object magic `1313882451` 区分。
- payload size 保留不变，给后续 diagnostics/statistics/free 继续使用。

### Status

Completed

### Planned Steps

- [x] 写 RED：valid release helper 必须定位 magic slot 并 `store i64 0`
- [x] 实现 LLVM release poison 行为
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-poison-magic-slot`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 100 Object Release Valid Boundary

### Goal

继续推进目标树 G3 / G1.5，把 Batch 99 的 `release:` 占位块升级为 compiler-owned release
boundary：

- `@np_object_free_release` 只有在 object header magic 校验通过后，才能调用
  `@np_object_release_valid(ptr %raw, i64 %size)`。
- 传入 release boundary 的必须是 header raw pointer 与 payload size，避免后续 allocator free
  重新猜测 object layout。
- 当前底层仍只有 bump-style `@np_alloc`，没有配对 free；本批只固定 valid-release ABI，不声明真实
  allocator free 已完成，不修改 `core/`。

### Architecture Decision

释放路径现在分三层固定：

- null receiver 直接进入 `done:`。
- 非 null receiver 回退读取 header；magic mismatch 直接进入 `done:`。
- magic match 进入 `release:` 并调用 `@np_object_release_valid(ptr %raw, i64 %size)`；该 helper
  当前是内部 no-op，占住 future allocator free / poison / statistics 的唯一挂载点。

### Status

Completed

### Planned Steps

- [x] 写 RED：valid release 分支必须调用 `@np_object_release_valid(ptr %raw, i64 %size)` 并存在 helper
- [x] 实现 LLVM release valid boundary helper
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-valid-boundary-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 99 Object Header Magic Validation

### Goal

继续推进目标树 G3 / G1.5，在不修改 `core/` 的前提下，把 object release helper 从“读取
header”推进到“校验 header magic 并分流”：

- `@np_object_free_release` 读取 payload 前 16 bytes header 后，必须校验 magic
  `1313882451`。
- 合法 header 进入 `release:` 占位块，非法 header 直接汇合到 `done:`，为后续真实 allocator
  free / diagnostics / trap 固定分支形状。
- 本批仍不实现真实 free，不接入 `core/` allocator，不改变 object header layout。

### Architecture Decision

object helper 的 ownership contract 继续保持一个入口、一种 header layout：

- Header layout 仍是 16 bytes：offset 0 为 payload size，offset 8 为 magic
  `1313882451`。
- `@np_object_free_release` 先保留 null guard，再回退到 header 并读取 size / magic。
- magic mismatch 当前是 defensive skip：直接进入 `done:`；magic match 进入 `release:` 占位块，
  以后 allocator free 必须挂到这个块里，避免非法 payload pointer 继续走释放路径。

### Status

Completed

### Planned Steps

- [x] 写 RED：release helper 必须包含 magic compare、valid/invalid branch 和 `release:` label
- [x] 实现 LLVM release helper magic 校验分支
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-header-magic-check`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 98 Platform Time FFI Boundary

### Goal

从当前 main 重新整理 clean preview，把 `platform.time` 从 FPC 平台单元迁到 nextPas-owned
FFI 边界：

- `nextpas.core.platform.time` 不直接 `uses Linux`、`UnixType`、`Windows` 等 FPC 平台单元。
- POSIX、macOS 和 Windows ABI 声明分别由 nextPas 自己的 FFI 单元承载。
- time conversion helper 对溢出、负 timespec 和 resolution rounding 给出稳定契约。
- QPC / mach timebase 换算在极大 divisor 的 fractional 路径上不能把可表示结果误判为饱和。
- official local verification 覆盖 no-FPC 静态检查、helper 行为和 Win64 compile-only。

### Status

Completed.

### Planned Steps

- [x] 写 RED：`platform.time` 静态测试禁止 FPC 平台单元和 implementation-local external ABI
- [x] 将 POSIX clock API 改为 `nextpas.core.platform.posix.ffi`
- [x] 新增 `nextpas.core.platform.darwin.ffi`
- [x] 将 Windows QPC/FILETIME API 追加到 `nextpas.core.platform.windows.ffi`
- [x] 补 helper 边界测试和 Win64 compile-only
- [x] 跑 aggregate / official verification
- [x] 复盘后提交并择优合并

### Architecture Decision

- `posix.ffi` 保留 sync/thread 所需 pthread 与 sleep/yield/sysconf 声明，同时追加 time 所需
  `clock_getres`。
- `windows.ffi` 保留 thread/TLS 声明，同时追加 time 所需 `FILETIME`、
  `QueryPerformanceFrequency`、`QueryPerformanceCounter`、`GetSystemTimeAsFileTime`。
- `platform.time` 只保留 platform contract 与换算逻辑，所有 native ABI 声明都在 FFI 单元。
- conversion helpers 用饱和和 ceil 策略避免溢出或高估精度；fractional multiply/divide
  在普通路径保持 O(1)，只在乘法会溢出的边界走逐位 fallback。

### Verification

- RED: `test_platform_time_no_fpc_units` 旧实现失败在 `UnixType`。
- Focused GREEN 已通过：time no-FPC 1/1、time helpers 9/9、time 13/13。
- Win64 compile-only 已通过：`fpc -Twin64 -Cn ... test_time.lpr` 编译 1931 行。
- Aggregate 已通过：`make -C core test`、`make -C core examples`、
  `make -C core benchmarks`。
- Full verification 已通过：fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeHelpersCheck=pass`、`corePlatformTimeNoFpcCheck=pass`、
  `corePlatformTimeWin64Check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 DateTime/timezone/timer/scheduler/async runtime。
- 不声明 macOS 或 Windows runtime 行为已经在真实主机运行验证。
- 不合并旧 `platform-time-integration` 中过期的 sync/thread/compiler 内容。

## Addendum: 2026-05-26 Batch 97 Object Header Ownership Contract

### Goal

继续推进目标树 G3 / G1.5，把 Batch 96 的对象分配/释放 helper boundary 升级为最小
object header ownership contract：

- `@np_object_alloc` 必须分配 `size + 16`，写入 payload size 与 magic header，再返回 payload
  pointer。
- `@np_object_free_release` 必须从 payload pointer 回退到 header 并读取 size / magic，为后续真实
  allocator free 和 ownership validation 固定入口。
- 本批仍不实现真实 free，不改变 constructor lowering，不修改 `core/`。

### Architecture Decision

对象 helper 先拥有 object header 的物理布局，再逐步接 allocator：

- Header layout 当前固定为 16 bytes：offset 0 存 payload size，offset 8 存 magic
  `1313882451`。
- `@np_object_alloc` 从底层 `@np_alloc` 申请 header + payload，返回 header 后的 object payload
  pointer，保持 class field / VMT store 使用 payload 起点。
- `@np_object_free_release` 仍由 object-free nil guard 后调用；helper 自身也防御性处理 null，并从
  payload pointer 回退 16 bytes 读取 header。读取 header 只是 ownership contract 证据，还不释放。

### Status

Completed

### Planned Steps

- [x] 写 RED：allocation helper 必须写 header，release helper 必须读取 header
- [x] 实现 LLVM helper header 写入与 release header 读取
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: class alloc focused test 失败在 `missing-hir-class-alloc-header-size`；
  object-free focused test 失败在 `missing-object-free-release-header-base`。
- GREEN focused: focused tests 输出 `hir-class-alloc-contract-status=pass` 与
  `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-class-alloc-contract=pass`、
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不接入 `core/` allocator 或修改 `core/`
- 不改变 constructor lowering 或 object payload layout
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link

## Addendum: 2026-05-26 Batch 96 Object Allocation Helper Boundary

### Goal

继续推进目标树 G3 / G1.5，把对象生命周期 ABI 从释放侧补齐到分配侧：

- `class_alloc` LLVM lowering 必须调用 compiler-owned `@np_object_alloc(i64 size)`。
- `@np_object_alloc` 当前只作为内部 helper boundary，委托到底层 `@np_alloc`。
- 这一步只建立 object allocation/release 的成对 runtime 接入口；不声明真实 object header、
  ownership metadata、allocator free 或完整 dynamic dispatch runtime 已完成。
- 不修改 `core/`。

### Architecture Decision

对象生命周期边界先分层稳定，再逐步替换底层实现：

- HIR 仍用 `class_alloc` intrinsic 表达 class instance allocation intent。
- LLVM emitter 不再让 `class_alloc` 直接碰底层 bump allocator，而是生成
  `call ptr @np_object_alloc(i64 ...)`。
- `@np_object_alloc` 当前内部调用 `@np_alloc(i64 %size)`；后续 object header、allocator
  ownership 和释放侧真实 free 都应收敛到这个 helper/ABI，而不是散落到 class lowering 中。

### Status

Completed

### Planned Steps

- [x] 写 RED：focused HIR test 必须看到 `@np_object_alloc` call、helper 定义和 `@np_alloc`
      delegate，并拒绝 class allocation site 直接 `@np_alloc`
- [x] 实现 LLVM class allocation helper lowering
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-hir-class-alloc-object-helper-call`。
- GREEN focused: focused HIR test 输出 `hir-class-alloc-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-class-alloc-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不定义 object allocation header / ownership metadata
- 不改变 constructor lowering
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 95 Object-free Heap-release Hook

### Goal

继续推进目标树 G3 / G1.5，把 `object-free-runtime` 中已经记录的 `heap-release true`
从语义意图推进到 HIR/LLVM 后端可见边界：

- `THIRBuilder` 在匹配 owned `Destroy` 后，必须基于 `heap-release true` 追加
  `np.system.object_free.release` intrinsic。
- `THIRLlvmEmitter` 必须把 release marker 降成非空分支内的
  `call void @np_object_free_release(ptr ...)`，顺序为 nil check -> destroy label ->
  `Destroy` call -> release hook -> end label。
- 本批只建立稳定 backend/runtime helper hook；当前 helper 是内部空实现，不声明真实 allocator
  free、object header ownership、完整 dynamic dispatch runtime 或完整 `System` 平替已完成。
- 不修改 `core/`。

### Architecture Decision

object-free lifecycle contract 现在分三段传递：

- semantic typed HIR 继续记录 receiver、effective `Destroy`、`nil-guard true` 与
  `heap-release true`。
- `THIRBuilder` 把 `heap-release true` 保存到 pending object-free contract；只有紧随的
  matching owned `Destroy` 成功消费该 contract 后，才追加 `np.system.object_free.release`。
- `THIRLlvmEmitter` 允许 owned destroy 与 release marker 留在同一个 `objectfree.destroy.*`
  非空分支里；release hook 关闭 guard 并汇合到 `objectfree.end.*`。

### Status

Completed

### Planned Steps

- [x] 写 RED：focused HIR test 必须看到 release intrinsic、LLVM release call 和 release helper
- [x] 实现 builder 侧 `heap-release true` pending contract 消费
- [x] 实现 LLVM release hook emission 与内部 helper 边界
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-intrinsic`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不定义 object allocation header / ownership metadata
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 93 Platform Thread FFI Boundary

### Goal

把 `platform.thread` 从 FPC 平台单元迁到 nextPas-owned FFI 边界，并和已合入主线的
`platform.sync` FFI 声明兼容；本 clean preview 基于 `main@ad236a2`，不混入独立
`platform.time` worktree 的提交。

### Status

Completed.

### Planned Steps

- [x] 写 RED：`platform.thread` 静态测试禁止直接引用 FPC 平台单元和旧 Win32 `@AProc` entry
- [x] 将 POSIX 分支改为 `nextpas.core.platform.posix.ffi`
- [x] 将 Windows 分支改为 `nextpas.core.platform.windows.ffi` trampoline state
- [x] 补 detach focused 行为测试
- [x] 从最新 `main@ad236a2` 整理 clean merge-preview，避免把独立 `platform.time` commit 混入
- [x] 跑 focused / aggregate / verify-local 验证
- [x] 复盘后提交

### Architecture Decision

- POSIX create 返回 nextPas-owned opaque state pointer，join/detach 成功后释放 state。
- Windows create 返回 state pointer，state 内部保存 native handle、user proc、arg、return value 和
  refcount；thread entry 与 join/detach 各释放自己的引用。
- `posix.ffi` 保留 sync 所需 mutex/rwlock/condvar pthread 声明，同时追加 thread 所需
  detach/self/TLS/nanosleep/sched_yield/sysconf。
- `windows.ffi` 本批只声明 thread/TLS/yield/sleep/cpu-count 所需 Win32 ABI，不携带 time-only FFI。

### Verification

- RED: `test_platform_thread_no_fpc_units` 旧实现失败在 `BaseUnix`。
- Focused GREEN 已通过：thread no-FPC static 1/1、platform.thread 7/7、nextpas.core.thread 6/6、
  platform.sync 14/14、platform.sync.sizes 4/4。
- Win64 compile-only 已通过：`fpc -Twin64 -Cn ... test_platform_thread.lpr` 编译 875 行。
- Aggregate 已通过：`make -C core test`、`make -C core examples`、`make -C core benchmarks`。
- Official verify 已通过：`bash build/verify_local.sh` 输出 `verify-local=pass`、
  `human-summary=local verification passed`。

### Non-goals

- 不修改 `platform.sync` 的 public API 或 futex/wait-wake 语义。
- 不声明 Windows runtime 行为已在真实 Windows 主机运行验证；本批只做 Win64 compile-only。
- 不合并独立 `platform.time` worktree 的 hardening commit。
- 不引入完整 thread pool、scheduler 或 async runtime 设计。

## Addendum: 2026-05-26 Batch 94 Object-free LLVM Nil Guard

### Goal

继续推进目标树 G3 / G1.5，把 `np.system.object_free` 从 HIR lifecycle marker 推进到
LLVM HIR emitter 可见的真实 nil guard：

- `np.system.object_free` 必须在 LLVM 文本中生成 receiver pointer 的 `icmp eq ptr ..., null`
  和 conditional branch。
- `np.system.object_free.destroy` 必须落在非空 `objectfree.destroy.*` 分支内，并在析构后
  汇合到 `objectfree.end.*`。
- owned destroy 必须复用 object-free contract 已解析的 receiver pointer，避免 guard 与析构
  call 之间出现额外 receiver reload，把 call 挤出非空分支。
- 本批只实现 nil branch 与 owned destroy call enclosure；不声明 allocator free、完整 dynamic
  dispatch runtime、implicit `System.pas` 自动 assemble/link 或完整 `System` 平替已完成。
- 不修改 `core/`。

### Architecture Decision

object-free 的 backend-facing contract 现在分两层落地：

- `THIRBuilder.ProcessObjectFreeRuntime(...)` 仍负责把 semantic contract 投影为
  `np.system.object_free` marker，并记录 pending destroy 名称、receiver 名称和 receiver pointer。
- 紧随的匹配 `call-runtime <Destroy>` 被改写为 `np.system.object_free.destroy` owned marker，
  且直接复用 pending receiver pointer，不再重复生成 receiver load。
- `THIRLlvmEmitter` 在看到 `np.system.object_free` 时打开 `objectfree.destroy.*` /
  `objectfree.end.*` guard，在 owned destroy call 后关闭 guard；普通 call lowering 继续复用统一
  `EmitCallInstr(...)`。

### Status

Completed

### Planned Steps

- [x] 写 RED：LLVM output 必须包含 object-free null check / conditional branch / destroy-end labels
- [x] 实现 builder receiver pointer reuse，保证 owned destroy call 位于 guard 内
- [x] 实现 `THIRLlvmEmitter` object-free guard start / close
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-llvm-null-check`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 92 Object-free Owned Destroy HIR Marker

### Goal

继续推进目标树 G3 / G1.5，让 `np.system.object_free` 不只作为孤立 marker 存在，还要约束
紧随其后的 effective `Destroy` lowering：

- typed HIR 中 `object-free-runtime` 后接匹配的 `call-runtime <Destroy>` 时，HIR builder
  不能再把这个析构投影成裸 `hikCall`。
- 该析构要成为 `np.system.object_free` contract 拥有的 HIR marker：
  `hikIntrinsic` / `np.system.object_free.destroy`，并保留原 `CallTarget` 与 receiver pointer
  operand。
- LLVM HIR emitter 继续把 owned destroy marker lowering 成现有 call，保持当前可执行析构行为；
  本批不声明真实 nil branch、allocator free 或完整 dynamic dispatch runtime 已完成。
- 不修改 `core/`。

### Architecture Decision

`object-free-runtime` 与后续 `Destroy` 是一个生命周期组，而不是两个互不相关的普通操作：

- `THIRBuilder.ProcessObjectFreeRuntime(...)` 发出 `np.system.object_free` 后，记录一个只允许被
  紧随 `call-runtime` 消费的 pending receiver/destroy contract。
- `ProcessCallRuntime(...)` 只有在 destroy target 和首个 `var <receiver>` operand 同时匹配时，
  才把该 call 改写为 `np.system.object_free.destroy` intrinsic；否则仍保持普通 `hikCall`。
- LLVM emitter 抽出统一 call emission helper，让 `hikCall` 和 owned destroy intrinsic 使用同一
  lowering 逻辑，避免复制和行为漂移。

### Status

Completed

### Planned Steps

- [x] 写 RED：匹配 object-free 后续 `TObject.Destroy` 不能再是裸 `hikCall`
- [x] 实现 pending object-free destroy contract consumption
- [x] 让 LLVM emitter 对 owned destroy marker 走现有 call lowering
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `plain-object-free-destroy-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不生成真实 nil branch
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 91 Object-free Contract HIR Bridge

### Goal

继续推进目标树 G3 / G1.5，把 Batch 90 已经产生的 `np.system.object_free`
typed HIR contract 接到下一层 HIR：

- `THIRBuilder` 不能再静默忽略 `object-free-runtime`。
- HIR 中要有稳定、可验证的 `np.system.object_free` intrinsic marker，保留 receiver pointer
  operand 和 effective `Destroy` target。
- 本批只建立 compiler-owned HIR/backend-facing contract，不声明真实 nil branch、allocator free、
  dynamic dispatch runtime 或 implicit `System.pas` link 已完成。
- 不修改 `core/`。

### Architecture Decision

`object-free-runtime` 是 compound lifecycle contract，不是普通函数调用：

- semantic typed HIR 仍负责选择 effective `Destroy` 并记录 nil guard / heap release intent。
- HIR builder 把 receiver 解析为 pointer operand，把 effective `Destroy` 名称放入
  `CallTarget`，并用 `hikIntrinsic` / `np.system.object_free` 表示后续 runtime helper 接口。
- 当前 LLVM HIR emitter 对这个 intrinsic 仍不展开真实代码，避免把“可见契约”误说成
  “释放实现已完成”。

### Status

Completed

### Planned Steps

- [x] 写 RED：`object-free-runtime` 必须投影成 HIR `np.system.object_free` intrinsic
- [x] 实现 `THIRBuilder.ProcessObjectFreeRuntime`
- [x] 把 focused HIR gate 纳入 `build/verify_local.sh`
- [x] 同步目标树 / semantic / runtime 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-hir-intrinsic`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不生成真实 nil branch
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Sync Merge-preview Closeout

### Goal

把 `platform.sync` hardening 分支合入最新主线预览分支，确保主线新增 core/test 结构与
platform.sync 的无 FPC 平台单元依赖、测试、example、benchmark、官方验证入口能够同时成立。

### Status

Completed

### Planned Steps

- [x] 在干净的 `codex/platform-sync-merge-preview` worktree 合并 `codex/platform-sync-hardening`
- [x] 择优解决文档和跟踪文件冲突
- [x] 收紧 `linux.ffi`，只保留 external ABI 声明
- [x] 为主线新增 core 测试项目补齐单独 Makefile
- [x] 运行 platform.sync focused tests、examples、benchmarks、core aggregate gates 和顶层验证
- [x] 简短 review 后提交 merge-preview

### Verification

- `make -C core test`: All tests passed。
- `make -C core examples`: All examples compiled。
- `make -C core benchmarks`: All benchmarks passed。
- `bash build/verify_local.sh`: `verify-local=pass`、
  `human-summary=local verification passed`。

### Next

主 checkout 仍有未提交同事工作；preview 分支验证通过后，等待主线现场干净或由负责人确认可集成，
再合入 `main`、删除旧 `platform-sync-hardening` worktree，并从最新主线重新开新 worktree。

## Addendum: 2026-05-26 Batch 89 Inherited TObject.Destroy Free Lowering

### Goal

继续推进目标树 G3 / G1.5，把 Batch 88 的 source-backed implicit `System` truth 往对象生命周期
下一层推进：

- 普通 `class` 即使没有显式父类，也要继承 `System.TObject` 的 VMT slot/function truth。
- `Worker.Free` 在 no-fold typed HIR 中不能只停在 `TObject.Free` binding；当 receiver class
  只继承 `System.TObject.Destroy` 时，也要 lowering 到有效 `TObject.Destroy` runtime call。
- 这条 gate 只证明 compiler semantic/HIR 层的 lifecycle intent，不宣称完整 heap free、完整
  virtual dispatch 或 backend/link 已接管 nextPas `System.pas`。
- 不修改 `core/`。

### Architecture Decision

这是最小 `Free -> effective Destroy` semantic lowering，不是完整对象释放：

- `ProcessClassFields(...)` 要同时消费显式父类和 `ProcessTypeSection(...)` 设置的隐式
  `ParentTypeId`，让隐式 `System.TObject` 的 VMT metadata 可以被子类复制。
- `Free` lowering 不再硬写 `TClass.Destroy`；它先查 `TClass$vmt_slot_Destroy`，再通过
  `TClass$vmt_func_<slot>` 找到当前有效 destructor，继承路径可落到 `TObject.Destroy`。
- 仍不在本批处理析构后的内存释放、nil guard、动态 dispatch table 运行时布局或 unit init/fini。

### Status

Completed

### Planned Steps

- [x] 写 RED：implicit source-backed `System` 下，普通 class 的 `Worker.Free` 必须 lowering 到继承的
      `TObject.Destroy`
- [x] 让隐式父类也复制父类 VMT slot/function metadata
- [x] 让 `Free` lowering 使用 VMT slot 对应的有效 destructor function name
- [x] 同步 System / runtime bootstrap / semantic docs 与持续记录
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-implicit-system-free-inherited-destroy-lowering`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不实现完整 heap free / nil guard / dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不实现 unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 88 Implicit Runtime Source-backed System Semantics

### Goal

继续推进目标树 G3 / G1.5，把 implicit runtime 的 `System` 从“只有 graph placeholder”
推进到“语义层可消费 target-installed `System.pas`”：

- 没有显式 `uses System` 的 program 也能在 semantic model 中看到 nextPas-owned
  `System.TObject`。
- 普通 `class` 的隐式父类必须能通过 implicit runtime source-backed `System` 指向
  `TObject`。
- `Worker.Free` 必须绑定到真实 `TObject.Free` method symbol，并从 `query definitions`
  回指 `units/linux-x86_64/System.pas`。
- build/backend 仍不能因为 implicit runtime 自动把 `System.pas` 当作额外 source-backed unit
  编译/链接。
- 显式 `uses System` 仍必须继续解析真实源码，并能把 implicit runtime 节点升级为
  `installed-source` provenance。

### Architecture Decision

这是 semantic truth upgrade，不是 full runtime/link upgrade：

- `EnsureRuntimeUnit` 只给 implicit runtime `System` 填入 target-installed `System.pas` 的
  `SourcePath`，但保留 `OriginClass=implicit-runtime`。
- `TCompilationSession.CollectAdditionalAssemblyBaseNames()` 已跳过 `implicit-runtime`，因此本批不会
  让所有程序额外 assemble/link `System.pas`。
- `ResolveDependency(...)` 遇到显式 `uses System` 时不能因为已有 implicit runtime source path
  就短路；它必须继续走 normal search，并让 `TUnitGraph.AddResolvedUnit(...)` 支持从
  source-backed implicit runtime 升级到 explicit source provenance。
- 不修改 `core/`。

### Status

Completed

### Planned Steps

- [x] 写 RED：无显式 `uses System` 的 `Worker.Free` 必须通过 implicit source-backed System 绑定
- [x] 让 implicit runtime `System` 指向 target-installed `units/linux-x86_64/System.pas`
- [x] 保持 explicit `uses System` 可升级 implicit runtime 节点，不被 source path 短路
- [x] 新增 stage0 query gate，固定 implicit `TObject.Free` binding / definition source path
- [x] 同步 System / RTL / runtime bootstrap / unit resolution / semantic docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused stage0 query 旧实现输出 `query-bindings=[]` 与 `query-definitions=[]`，缺少
  implicit source-backed `TObject.Free` binding。
- GREEN focused: rebuilt stage0 query 已显示 implicit fixture 中 `TWorker.typeParentId` 指向
  `TObject`，`query-bindings` 含 `Free` member-call，`query-definitions.targetSourcePath`
  为 `units/linux-x86_64/System.pas`。
- Full: fresh `bash build/verify_local.sh` 输出
  `stage0-query-system-object-free-implicit-check=pass`、
  `stage0QuerySystemObjectFreeImplicitCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不实现 destructor lowering / virtual dispatch / unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 87 Source-backed System/TObject Truth

### Goal

推进目标树 G3 / G1.5，把 `Obj.Free` 从“缺 System 基线时临时 deferred”推进到
nextPas-owned source-backed truth：

- 提供最小 `System.pas` / `TObject` 源码事实，先覆盖 `Create` / `Destroy` / `Free`。
- 显式 `uses System` 时，resolver / sema 必须消费 target-installed `System.pas`，而不是只看到
  placeholder unit symbol。
- 普通 `class` 在已有 source-backed `System.TObject` 时默认继承 `TObject`。
- `Worker.Free` 必须通过继承 member lookup 绑定到真实 `TObject.Free` method symbol，并能从
  `query definitions` 回指 `units/linux-x86_64/System.pas`。

### Architecture Decision

这是最小 System/TObject truth，不是完整 FPC `System` 重写：

- canonical 位置落在 `rtl/core/system/System.pas`，target-installed truth 落在
  `units/linux-x86_64/System.pas`。
- implicit runtime edge 仍保持 placeholder；本批不让所有 implicit runtime 自动编译/链接
  `System.pas`，避免扩大到宿主 FPC `System` 影子边界。
- 当 source-backed `System.TObject` 已进 semantic model 时，class 默认父类由 `TypeId` 指向
  owner=`system` 的 `TObject`；member lookup 继续沿现有 `ParentTypeId` 链工作。
- 没有 source-backed System truth 的路径仍保持 `Free` deferred，避免把 runtime baseline 缺口误报成
  普通 unknown member。
- 不修改 `core/`。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：显式 source-backed `System` 下普通 `class` 的 `Worker.Free` 必须绑定到
      `System.TObject.Free`
- [x] 新增最小 `rtl/core/system/System.pas` 与 target-installed `units/linux-x86_64/System.pas`
- [x] 让普通 class 在 source-backed `System.TObject` 已解析时默认继承 `TObject`
- [x] 新增 stage0 query fixture / gate，固定 `TObject.Free` symbol、`member-call` binding 和
      definition source path
- [x] 同步 System / RTL / runtime bootstrap / semantic docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-source-backed-system-free-binding`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Focused stage0 query with freshly rebuilt stage0: `query-bindings` 含 `Free` member-call，
  `query-definitions` target 为 `TObject.Free`，`targetSourcePath` 为
  `units/linux-x86_64/System.pas`。
- Full: fresh `bash build/verify_local.sh` 输出 `stage0-query-system-object-free-check=pass`、
  `stage0QuerySystemObjectFreeCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不把 implicit runtime placeholder 自动升级为 source-backed compile/link
- 不实现 destructor lowering / virtual dispatch / unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Sync Worktree-safe Verification

### Goal

收口 `platform.sync` worktree 的官方顶层验证问题：`build/verify_local.sh` 不能再假设仓库路径
一定以 `/nextPas` 结尾，也不能写死主 checkout 的 `/home/dtamade/projects/nextPas` 路径。

### Architecture Decision

`verify_local` 的路径契约继续保持精确，但精确性来自当前 `REPO_ROOT`、workspace artifact root、
distribution/runtime root 等派生变量，而不是固定目录名。对 line output 优先使用 literal
断言；对 JSON envelope 使用经过 ERE escaping 的路径 pattern。

### Status

Completed

### Planned Steps

- [x] 复现 worktree 下的 `missing-stage0-workspace-root`
- [x] 在 `build/verify_local.sh` 增加 ERE path escaping helper 与派生路径 pattern
- [x] 替换所有写死 `.*/nextPas` 与主 checkout 的断言
- [x] 同步 `core-platform-sync-check` 当前 14 项接口覆盖 summary
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh `bash build/verify_local.sh` 失败在 `missing-stage0-workspace-root`，而实际
  `workspace-root` 是当前 linked worktree 路径。
- GREEN: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

## Addendum: 2026-05-26 Batch 86 Unknown Member Diagnostic

### Goal

按目标树 G1.5/G1.6，补上 direct class member-call 的第一条 name miss 诊断：

- `Worker.Missing(1)` 这类 receiver type 已知、class/parent chain 都没有同名 method 的调用
  必须进入 `sema.unknown-member`。
- 诊断进入统一 diagnostics projection，semantic model status 进入 `failure`。
- 失败 member call 不注册 `member-call` binding。

### Architecture Decision

这是 unknown member 的保守首切片，不是完整 member resolver：

- receiver type 必须可由当前 semantic model 解析。
- receiver type 还必须已有 class layout truth；alias、generic specialization、record-like receiver
  继续 deferred，避免把尚未 materialize 的 member truth 误报成 unknown member。
- 已知 field / property name 不报 unknown member，继续 deferred 给后续 field/property access。
- inherited method 仍沿现有 parent chain lookup 成功绑定。
- 在 source-backed nextPas `System` / `TObject` truth 落地前，`Free` 这类最低对象生命周期入口
  不作为普通 unknown member 报错，避免把 System 基线缺口误报成用户成员缺失。
- 未知 receiver、record/property/array/deref receiver、visibility、implicit conversion、default parameter
  与 full overload ranking 不在本批内。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：direct class unknown member 必须产生 `sema.unknown-member`
- [x] 在 semantic analyzer 接入保守 unknown-member failure kind
- [x] 固定同名 field 与临时 System object `Free` deferred 边界，避免 known non-method / System 基线误报
- [x] 固定 specialized generic receiver deferred 边界，避免 generic instantiation truth 未落地前误报
- [x] 新增 stage0 fail fixture 和 `unknown-member-check`
- [x] 同步 sema / semantic model / stage0 / goal tree / rolling plan 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在 `semantic-call-bindings-failure=missing-unknown-member-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- First full attempt: detached clean worktree 暴露 `examples/smoke/llvm_destructor.pas` 的
  `C.Free` 被误报 `sema.unknown-member`；该边界已改为 deferred，并记录为下一步
  source-backed `System` / `TObject` truth 工作。
- Second full attempt: `llvm-destructor-program=pass` 且 `unknown-member-check=pass`，后段
  `stage0-test-smoke-check` 暴露 `tests/parser/generics_pass.pas` 的 specialized generic receiver
  被误报；该边界已收紧为没有 class layout truth 时 deferred。
- Final full: fresh detached clean worktree 已输出 `unknown-member-check=pass`、
  `unknownMemberCheck":"pass"`、`stage0-test-smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Next

下一轮继续 G1.5/G1.6，优先补 callable/member no-matching-overload 或进一步收紧 known non-callable
诊断边界。

## Addendum: 2026-05-26 Batch 85 Latest Baseline Verification Closure

### Goal

把并行推进后的最新 baseline 收口到可继续开发的状态：

- 确认 `sema.unknown-callable` 的保守边界已经不再误伤 compiler self-compile 中的
  `inherited Create` / implicit self bare method call。
- 确认 `unit_root_precedence` 不再被 host FPC 旧 `.ppu/.o/.s` 中间产物污染。
- 保持协作边界：不修改、不 stage、不提交 `core/` 负责人当前工作。

### Status

Completed

### Planned Steps

- [x] 复核最新 HEAD、工作树和非 `core/` 变更边界
- [x] 用 focused semantic call binding test 确认 unknown callable 回归已转绿
- [x] 用 detached clean worktree 运行 fresh `bash build/verify_local.sh`
- [x] 复核 verify 失败历史，确认当前最高 blocker 已从 self-compile / unit-root precedence 关闭
- [x] 同步计划记录，提交本轮收口状态

### Verification

- Focused: `semantic-call-bindings-status=pass`。
- Full: detached clean worktree 基于 `287d13d` 输出
  `unknown-callable-check=pass`、`unit-root-precedence-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Next

下一轮继续走非 `core/` 路线，优先从目标树 G1.5/G1.6 中选择 source-owned、
误报风险可控的 callable/member diagnostics：unknown member 或 no-matching-overload。

## Addendum: 2026-05-26 Batch 84 Unknown Bare Callable Diagnostic

### Goal

按 `docs/architecture/nextpas-goal-tree.md` 的 G1.5/G1.6，补上第一条 source-owned unknown
bare callable 语义诊断：

- `MissingThing(1)` 这类 root source 里没有任何已知 callable/symbol/type/builtin 含义的 bare call
  必须进入 `sema.unknown-callable`。
- 诊断进入统一 diagnostics projection，semantic model status 进入 `failure`。
- 失败调用不注册 `call` binding。

### Architecture Decision

这是 unknown callable 的保守首切片，不是完整 callable resolver：

- 已知 builtin callable 继续 deferred 给现有 runtime/builtin lowering，不报 unknown。
- 已知 symbol 或 type name 不报 unknown；未来再区分 not-callable、typecast、function pointer。
- imported helper no-match、unknown member、record/property/array/deref receiver、implicit conversion、
  no-matching-overload 仍保留给后续 G1.5/G1.6。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：bare unknown callable 必须产生 `sema.unknown-callable`
- [x] 新增 stage0 fail fixture 和 `unknown-callable-check`
- [x] 在 semantic analyzer 接入保守 unknown-callable failure kind
- [x] 同步 sema spec、goal tree、stage0 README 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-bare-unknown-callable-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 必须输出 `unknown-callable-check=pass`、
  `unknownCallableCheck":"pass"`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不修改 `core/` 代码
- 不实现 unknown member
- 不实现 full overload resolver / implicit conversion / no-matching-overload
- 不把 typecast、function pointer 或 known non-callable symbol 误归类为 unknown callable

## Addendum: 2026-05-26 Batch 83 Capability Goal Tree

### Goal

把 nextPas 的长期目标从“继续推进”收成一份可执行、可检查、可复盘的目标树：

- 定义 nextPas 的北极星目标：现代 Pascal 编译器、RTL/core/framework、workspace/package/tooling、
  language service、IDE 与 FPC 兼容生态。
- 把完整能力拆成 G0-G8：项目控制面、编译器语言能力、IR/backend/toolchain、RTL/core/framework、
  workspace/package、developer tools、language service/IDE、FPC compatibility、performance/reliability。
- 标注当前完成度、下一步证据和近期优先级，让后续每轮 batch 都能绑定目标节点。
- 明确当前协作边界：不直接修改 `core/`，core 相关需求以 integration requirement 或 review/suggestion
  形式反馈。

### Architecture Decision

目标树不是新路线图替代品，而是总控索引：

- `docs/architecture/master-roadmap.md` 继续负责产品顺序。
- `docs/architecture/compiler-roadmap.md` 继续负责 compiler execution spine。
- `docs/architecture/bootstrap-roadmap.md` 继续负责 `stage0 -> stage1 -> stage2` 所有权迁移。
- `docs/architecture/nextpas-goal-tree.md` 负责把上述路线收成能力目标、当前状态、优先级和每轮报告格式。

### Status

Completed

### Planned Steps

- [x] 新增 `docs/architecture/nextpas-goal-tree.md`
- [x] 在 `docs/architecture/master-roadmap.md` 接入目标树入口
- [x] 在 `build/verify_local.sh` docs-check 中加入目标树文件
- [x] 同步 rolling plan 顶部状态到 Batch 83
- [x] 同步 `task_plan.md`、`progress.md` 与 `findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 必须输出 `verified-path=docs/architecture/nextpas-goal-tree.md`、
  `docs-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不修改 `core/` 代码
- 不打开 package manager resolver/fetch/install/publish
- 不把目标树当作替代真实功能实现的完成标准

## Addendum: 2026-05-26 Batch 82 Core Time Verification Closure

### Goal

把 `nextpas.core.time` 从“已提交模块但未进入顶层官方验证”的状态收口为可追溯的
core 基础设施批次：

- `core.platform.time` 正式承载平台时间源，并由 `nextpas.core.platform` facade re-export。
- `TInstant.Now` 使用 platform-owned monotonic clock，不在 `time.base` 内直接依赖 OS 单元。
- `build/verify_local.sh` 新增 `core-time-check`，编译并运行
  `core/tests/nextpas.core.time/test_time/test_time.lpr`，最终 envelope 暴露 `coreTimeCheck`。
- `core/README.md` 同步当前 core reality，避免继续只描述 L0 初始状态。

### Architecture Decision

这是 L1 `time` 的验证收口，不扩大成完整跨平台时间/日历库：

- 当前承诺 `Duration`、`Instant`、`Stopwatch` 与 platform monotonic/realtime/resolution 最小入口。
- Linux 路径使用 `clock_gettime` / `clock_getres`；Windows 路径保留
  `QueryPerformanceCounter` / `GetSystemTimeAsFileTime` 结构；未知平台 fallback 只保证可编译。
- 不引入 DateTime、timezone、timer、scheduler、async runtime 或 benchmark layer。

### Status

Completed

### Planned Steps

- [x] 复查 `core.time` / `core.platform.time` 的当前 dirty tree 与 core 模块约定
- [x] 修正 `core.platform.time` 的 implementation `uses` 顺序与保守 fallback
- [x] 给 focused time 测试补 direct platform time facade coverage
- [x] 在 `build/verify_local.sh` 增加 `core-time-check` 与 `coreTimeCheck` envelope field
- [x] 同步 core README 与持续记录
- [x] 运行 focused core test / `make -C core test`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- Focused compile/run 已通过：`nextpas.core.time: 13 total, 13 passed, 0 failed`。
- Core matrix: `make -C core test` 已通过，覆盖 base / errors / platform / time / bytes /
  testing / mem。
- Full: `bash build/verify_local.sh` 已输出 `core-time-check=pass`、
  `coreTimeCheck":"pass"`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 DateTime / timezone / calendar formatting
- 不实现 Timer / scheduler / async runtime
- 不把未知平台 fallback 宣称为高精度时间源
- 不重开 sema / package manager / backend 路线

## Addendum: 2026-05-26 Batch 81 Parameter Call Type Mismatch Evidence

### Goal

把 Batch 80 的稳定变量 evidence 继续推进到过程/函数参数：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且
argument signature 来自当前 callable scope 中已声明为内建标量/字符串类型的参数时，若与 target
param signature 明确不兼容，发出 `sema.type-mismatch`。

本批次新增并冻结：

- parameter symbol 现在记录声明中的 `TypeId`，不再只记录名字与 scope。
- `SeedCallBindingsInNode(...)` 进入 procedure/function declaration body 时切换到对应 callable
  scope，让参数 lookup 消费真实 scope chain。
- stable scalar evidence 只接受 `variable` / `parameter` symbol；function result symbol 即使有
  builtin return type，也继续不作为 diagnostic evidence，且 single-target mismatch 不注册错误 binding。
- `build/verify_local.sh` 新增 `type-mismatch-parameter-call-check` 与
  `member-type-mismatch-parameter-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchParameterCallCheck` / `memberTypeMismatchParameterCallCheck`。

### Architecture Decision

这是 scalar value fact 的第二条安全切片，不是完整 expression value-flow：

- 只覆盖当前 semantic model 中已能稳定解析为内建标量/字符串 type id 的变量与参数。
- function result、class/record/Pointer/Text/Variant、declared alias、成员访问、imported target 与多
  overload signature no-match 继续 deferred；已知 signature mismatch 但缺少 stable evidence 时不诊断也不绑定。
- 不引入 implicit conversion/ranking、default parameter lowering、var/out compatibility 或完整 overload resolver。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Flag)`，其中 `Flag` 是 `Run(Flag: Boolean)` 的参数
- [x] RED：新增 `Self.Pick(Flag)` 的 member 参数 regression
- [x] RED：新增 bare function result guard，确认 `function Flag: Boolean` 不被当成 stable value evidence
- [x] 给 parameter symbol 写入 type id，并让 call binding walker 进入 callable scope
- [x] 将 stable scalar evidence 限定到 variable / parameter symbol
- [x] 新增 `tests/fixtures/type_mismatch_parameter_call` /
      `member_type_mismatch_parameter_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-parameter-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-parameter-call-check=pass`、
  `member-type-mismatch-parameter-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 function result 纳入 type mismatch diagnostic evidence
- 不把 class/record/Pointer/Text/Variant/declared alias 参数纳入 type mismatch evidence
- 不实现 imported target type-mismatch diagnostics
- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics

## Addendum: 2026-05-26 Batch 80 Scalar Variable Call Type Mismatch Evidence

### Goal

把 Batch 79 的 `sema.type-mismatch` evidence 从 literal/纯表达式推进到第一条变量事实：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且
argument signature 来自当前 scope 中已声明为内建标量/字符串类型的变量时，若与 target param signature
明确不兼容，发出 `sema.type-mismatch`。

本批次新增并冻结：

- `ExpressionTypeFactIsStable(...)` 对 identifier 不再只接受 `True` / `False`，还会通过当前 scope
  的 symbol `TypeId` 判断是否为稳定内建标量事实。
- 新增 `TypeIdHasStableScalarFact(...)`，只认可 `Boolean`、整数/浮点、`Char` 与内建字符串族；
  `Pointer`、`Text`、`Variant`、declared class/record/alias 等继续不作为 diagnostic evidence。
- `build/verify_local.sh` 新增 `type-mismatch-variable-call-check` 与
  `member-type-mismatch-variable-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchVariableCallCheck` / `memberTypeMismatchVariableCallCheck`。

### Architecture Decision

这是 variable argument type mismatch evidence 的第一条安全切片，不是完整 variable type flow：

- 只覆盖当前 semantic model 中已能稳定解析为内建标量/字符串 type id 的变量参数。
- class/record/Pointer/Text/Variant、declared alias、成员访问、函数结果、imported target 与多 overload
  signature no-match 继续 deferred。
- 不引入 implicit conversion/ranking、default parameter lowering、var/out compatibility 或完整 overload resolver。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Flag)`，其中 `Flag: Boolean` 调 `Pick(Integer)` 的 focused regression
- [x] RED：新增 `Worker.Pick(Flag)` 的 member focused regression
- [x] 新增内建标量变量 evidence gate
- [x] 新增 `tests/fixtures/type_mismatch_variable_call` /
      `member_type_mismatch_variable_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-variable-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-variable-call-check=pass`、
  `member-type-mismatch-variable-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 class/record/Pointer/Text/Variant/declared alias 变量纳入 type mismatch evidence
- 不实现 imported target type-mismatch diagnostics
- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics

## Addendum: 2026-05-26 Batch 79 Single-target Call Type Mismatch Diagnostics

### Goal

把 semantic binding/type relation 从“能绑定正确 target”推进到第一条可证明 type no-match：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且当前
argument signature 来自 literal/纯表达式等稳定事实、可推断为与 target param signature 明确不兼容时，
发出 `sema.type-mismatch`。

本批次新增并冻结：

- `InferExpressionType(...)` 识别 `True` / `False` 为 `Boolean`，让 boolean literal 进入
  call argument signature。
- `LookupCallBindingDeclaration(...)` 对 bare call 的单一 target signature mismatch 透传
  `type-mismatch` failure kind，不再错误注册 `call` binding。
- `MethodSymbolIdForExactClassTypeMember(...)` 对 direct member-call 的单一 target signature
  mismatch 透传 `type-mismatch` failure kind。
- `build/verify_local.sh` 新增 `type-mismatch-call-check` 与
  `member-type-mismatch-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchCallCheck` / `memberTypeMismatchCallCheck`。

### Architecture Decision

这是 root-owned single-target type mismatch diagnostics，不是完整 no-matching-overload resolver：

- 只覆盖 root-owned target 唯一、arity 已匹配、argument signature 来自稳定 facts 且明确不兼容的路径。
- imported target 继续 deferred；当前 compact signature 尚不足以可靠覆盖 RTL/package helper surface。
- 变量/成员/函数结果相关 no-match 继续 deferred；当前变量声明与 symbol type facts 还不能作为
  diagnostic 证据使用。
- 多 overload 的 signature no-match 仍保持 deferred，避免把 implicit conversion、ranking 或 future
  resolver 能力误报成错误。
- 未知 callable / unknown member、receiver 未覆盖、record/property/array/deref receiver、visibility、
  implicit conversion、default parameter lowering/ranking 与完整 overload ranking 继续 deferred。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(True)` 调 `Pick(Integer)` 的 type mismatch focused regression
- [x] RED：新增 `Worker.Pick(True)` 调 `TWorker.Pick(Integer)` 的 member type mismatch regression
- [x] 让 boolean literal 进入 expression type inference / argument signature
- [x] 在 bare call lookup 中带出 `type-mismatch` failure kind，避免错误绑定
- [x] 在 member target lookup 中带出 `type-mismatch` failure kind
- [x] 新增 `tests/fixtures/type_mismatch_call` / `member_type_mismatch_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full first pass: `bash build/verify_local.sh` 曾失败在
  `compiler-module-workspace-model-self-compile-failed`，原因为 imported `SysUtils.ExpandFileName` /
  `FileExists` 被过宽 type-mismatch 规则误报。
- Full second pass: `bash build/verify_local.sh` 曾失败在 `llvm-linked-list-build-failed`，原因为
  root-owned `SetNext(TNode)` 的变量参数 `B` / `C` 被不稳定 variable type fact 误报。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-call-check=pass`、
  `member-type-mismatch-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics
- 不扩展 record/property/array/deref receiver、virtual dispatch 或完整 member resolver
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 78 Member Wrong Argument Count Diagnostics

### Goal

把 Batch 77 的 `sema.wrong-argument-count` 从 bare call 扩展到当前已支持的 direct
member-call：当 receiver type 上已经存在同名 method，但没有任何同 arity target 时，发出
`sema.wrong-argument-count`。

本批次新增并冻结：

- `MethodSymbolIdForExactClassTypeMember(...)` 在同名 method 已知但 arity 全不匹配时透传
  `wrong-argument-count` failure kind。
- `SeedCallBindingsInNode(...)` 对 direct member-call 的 `wrong-argument-count` failure kind 发
  `sema.wrong-argument-count`。
- `build/verify_local.sh` 新增 `member-wrong-argument-count-check`，固定 stage0 failure projection
  与 final verify envelope 的 `memberWrongArgumentCountCheck`。

### Architecture Decision

这是 direct member-call 的 arity no-match diagnostics，不是完整 Pascal member resolver：

- 只覆盖当前已支持的 direct class/type receiver path。
- 只在 receiver type 已解析且同名 method 已知、但没有任何同 arity target 时发 diagnostic。
- 未知 member、receiver 未覆盖、body mismatch、signature no-match 仍保持 deferred。
- 不实现 implicit conversion、default parameter lowering/ranking、visibility、virtual dispatch、
  record/property receiver 或完整 type-based overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 `Worker.Pick(1, 2)` 的 member wrong-argument-count focused regression
- [x] 在 member target lookup 中带出 `wrong-argument-count` failure kind
- [x] 在 semantic analyzer 中为 direct member-call 发 `sema.wrong-argument-count`
- [x] 新增 `tests/fixtures/member_wrong_argument_count` 与 `member-wrong-argument-count-check`
- [x] 将 `query_member_call_bindings` 的历史缺参负例迁移到 dedicated failure fixture
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-member-wrong-argument-count-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full first pass: `bash build/verify_local.sh` 曾失败在
  `stage0-query-member-call-bindings-failed`，原因为 success query fixture 仍含历史缺参负例。
- Full: `bash build/verify_local.sh` 已输出 `member-wrong-argument-count-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 unknown member diagnostics
- 不实现 type-based no-matching-overload diagnostics
- 不实现 implicit conversion / default parameter lowering/ranking / var-out compatibility / visibility checking
- 不扩展 record/property/array/deref receiver、virtual dispatch 或完整 member resolver
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 77 Bare Wrong Argument Count Diagnostics

### Goal

把 bare callable failure 从 ambiguity 继续推进到第一条 no-match 形态：当 root/imported
优先级内已经存在同名 callable，但没有任何候选的参数个数与调用匹配时，发出
`sema.wrong-argument-count`。

本批次新增并冻结：

- `LookupCallBindingDeclaration(...)` 先按 owner priority 统计同名候选，再判断 call arity 是否落在
  declaration 的必填参数数到总参数数之间。
- root callable name 存在但 arity 全不匹配时，不回落 imported，直接发
  `sema.wrong-argument-count`。
- imported callable name 存在但 arity 全不匹配时，同样发 `sema.wrong-argument-count`。
- `build/verify_local.sh` 新增 `wrong-argument-count-check`，固定 stage0 failure projection 与
  final verify envelope 的 `wrongArgumentCountCheck`。

### Architecture Decision

这是 bare callable 的 arity no-match diagnostics，不是完整 no-matching-overload resolver：

- 只覆盖 bare procedure/function call，不覆盖 member-call wrong arity。
- 只在 callable name 已知、但同优先级没有任何 arity match 时发 diagnostic；默认参数只参与
  bare call 的 arity 区间与 provided-argument signature prefix 判断。
- 可接受 arity 存在但 compact signature match count 为 0 时仍 deferred，避免把 implicit conversion、
  type ranking 或 future resolver 能力误报成 wrong-argument-count。
- builtin / 未知 callable name 继续不报错，避免误伤 `WriteLn` 等内建或未来 callable forms。

### Status

Completed

### Planned Steps

- [x] RED：新增 overloaded bare `Pick` 调用 `Pick(1, 2)` 的 wrong-argument-count regression
- [x] 在 bare call lookup 中带出 `wrong-argument-count` failure kind
- [x] 在 semantic analyzer 中发 `sema.wrong-argument-count`
- [x] 新增 `tests/fixtures/wrong_argument_count` 与 `wrong-argument-count-check`
- [x] 修复 `default_params_pass.pas` 暴露的默认参数 arity false positive
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-wrong-argument-count-diagnostic`。
- RED: 默认参数 focused regression 已失败在
  `semantic-call-bindings-failure=unexpected-default-parameter-diagnostics`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Focused parser: `./tests/run_all_tests.sh --filter parser` 已输出
  `failed-fixture-count=0` 与 `human-summary=group parser passed`。
- Full: `bash build/verify_local.sh` 已输出 `wrong-argument-count-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 member-call wrong-argument-count diagnostics
- 不实现 type-based no-matching-overload diagnostics
- 不把未知 callable / builtin 统一报错
- 不实现 implicit conversion / default parameter lowering/ranking / var-out compatibility / visibility checking
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 76 Member Ambiguous Overload Diagnostics

### Goal

把 Batch 75 的 structured overload failure 从 bare call 推进到 direct member-call：当
`member-call` target lookup 在 receiver exact/parent class 上遇到同 owner、同 qualified name、
同参数个数且 compact signature 无法唯一选择的 method 候选时，发出
`sema.ambiguous-overload`。

本批次新增并冻结：

- `MethodSymbolIdForExactClassTypeMember(...)` / `MethodSymbolIdForClassTypeMember(...)`
  透传 `ambiguous-overload` failure kind。
- `TryRegisterMemberCallBinding(...)` 在明确 member overload ambiguity 时让
  `SeedCallBindingsInNode(...)` 发 `sema.ambiguous-overload`。
- `build/verify_local.sh` 新增 `ambiguous-member-overload-check`，固定 stage0 failure projection 与
  final verify envelope 的 `ambiguousMemberOverloadCheck`。

### Architecture Decision

这是 member-call diagnostics 的第一条 ambiguity 切片，不是完整 Pascal member resolver：

- 只覆盖 direct class/member call 已支持的 receiver path。
- 只在 compact signature collision 或无法签名消歧的多候选上报 ambiguity。
- signature match count 为 0 仍保持 deferred，不报 no-matching-overload。
- 不实现 implicit conversion、default parameter、visibility、virtual dispatch、record/property receiver
  或完整 type-based overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 `Integer` / `LongInt` compact signature collision 的 member-call focused regression
- [x] 在 member target lookup 中带出 `ambiguous-overload` failure kind
- [x] 在 semantic analyzer 中为 direct member-call 发 `sema.ambiguous-overload`
- [x] 新增 `tests/fixtures/ambiguous_member_overload` 与 `ambiguous-member-overload-check`
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-ambiguous-member-overload-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `ambiguous-member-overload-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 no-matching-overload / unresolved callable diagnostics
- 不把全部 member-call binding miss 统一报错
- 不扩展 receiver grammar 或 member lookup coverage
- 不实现 implicit conversion / default parameter / visibility / virtual dispatch
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 75 Bare Ambiguous Overload Diagnostics

### Goal

把 Batch 74 后仍然“静默不绑定”的第一条 overload 失败边界接进结构化 diagnostics：
当 bare procedure/function call 在同一优先级内存在同名同参数个数 callable 候选，但当前
compact argument signature 不能唯一选出 target 时，发出 `sema.ambiguous-overload`。

本批次新增并冻结：

- `LookupCallBindingDeclaration(...)` 在 root/imported 各自优先级内报告
  `ambiguous-overload` resolution failure，而不是只返回“未绑定”。
- `SeedCallBindingsInNode(...)` 只在明确的 ambiguous overload failure 上发
  `sema.ambiguous-overload`，保持普通 unresolved call / builtin / future callable path deferred。
- `build/verify_local.sh` 新增 `ambiguous-overload-check`，固定 stage0 failure projection 与
  final verify envelope 的 `ambiguousOverloadCheck`。

### Architecture Decision

这是 semantic diagnostics 的第一条 overload 失败切片，不是完整 overload resolver：

- 只覆盖 bare procedure/function call，不覆盖 member-call overload ambiguity。
- root callable 仍优先；root 明确 ambiguous 时不会回落 imported 代偿。
- 同名同 arity 候选存在但 signature match count 为 0 时仍保持 deferred，避免把缺失的
  conversion/ranking/内建函数能力误报成 ambiguity。
- 不新增 implicit conversion、default parameter、var/out compatibility、visibility checking 或
  complete Pascal overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 imported `HelperA.Pick(Integer)` / `HelperB.Pick(Integer)` ambiguous diagnostic
      focused regression
- [x] 在 bare call lookup 中带出 `ambiguous-overload` failure kind
- [x] 在 semantic analyzer 中发 `sema.ambiguous-overload`
- [x] 新增 `tests/fixtures/ambiguous_overload` 与 `ambiguous-overload-check`
- [x] 同步 semantic model / sema / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在 `semantic-call-bindings-failure=missing-ambiguous-overload-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `ambiguous-overload-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 member-call ambiguous overload diagnostics
- 不实现 no-matching-overload / unresolved callable diagnostics
- 不把全部 unresolved call 统一报错
- 不实现 implicit conversion / default parameter / var-out compatibility / visibility checking
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 74 Bare Typed Call Binding

### Goal

把 Batch 73 的 compact typed argument relation 从 `member-call` 复用到 bare
procedure/function call binding：当 root 或 imported callable 中存在同名同参数个数但参数类型不同的
overload 时，例如 `Pick(Integer)` 与 `Pick(Boolean)`，`Pick(1)` 和 `Pick(1 = 1)` 应分别绑定到
对应 `ParamSignature` 的 callable symbol。

本批次新增并冻结：

- bare procedure/function symbol 同步记录 `ParamSignature`。
- `LookupCallBindingDeclaration(...)` 在 root/imported 各自优先级内，先按 name + arity 收集候选；
  若同 arity 多候选，则用当前可推断 argument signature 选择唯一 target。
- root callable 继续优先；root 存在同名同 arity 但无法唯一 typed match 时，不回落 imported。
- `querySymbols` / `queryDefinitions` stage0 gate 固定 bare typed overload 的 symbol signature 与
  target signature。

### Architecture Decision

这是 bare call 的最小 typed overload binding，不是完整 Pascal overload resolver：

- argument signature 仍只来自当前 `InferExpressionType(...)` 可证明的表达式类型。
- root/imported 优先级保持 Batch 60 以来的保守策略。
- 无法推断 argument type、同 signature 不唯一、implicit conversion / default parameter /
  var-out compatibility / visibility 等情况仍不绑定。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Integer)` / `Pick(Boolean)` 同 arity focused regression
- [x] 为 bare procedure/function symbol 写入 `ParamSignature`
- [x] bare call lookup 在同 arity 多候选时按 signature 唯一匹配
- [x] 扩展 stage0 `query_call_bindings` fixture 与 verify gate
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在 `semantic-call-bindings-failure=missing-integer-bare-overload-symbol`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 overload ranking
- 不实现 implicit conversion / default parameter / var-out compatibility
- 不改变 selector/member binding 边界
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 73 Member Typed Overload Binding

### Goal

关闭 Batch 72 后的下一条 overload 缺口：当同一个 class 内存在同参数个数但参数类型不同的
method overload 时，例如 `TWorker.Pick(Integer)` 与 `TWorker.Pick(Boolean)`，`Worker.Pick(1)`
和 `Worker.Pick(1 = 1)` 应分别绑定到对应参数签名的 method symbol，而不是因为 arity 相同而
保守不绑定。

本批次新增并冻结：

- `TSemanticSymbol.ParamSignature`，作为当前最小 callable/member 参数类型签名。
- class method symbol 同步记录 `ParamCount` 与 `ParamSignature`。
- member-call lookup 在同 owner / 同 qualified name / 同 arity 有多个候选时，用 call argument
  signature 做二次唯一匹配。
- `queryDefinitions` / `querySymbols` 对 target / symbol 参数签名做只读投影。

### Architecture Decision

这是最小 typed overload binding，不是完整 Pascal overload resolver：

- argument signature 只来自当前 `InferExpressionType(...)` 已能证明的表达式类型。
- 当前签名仍是 compact semantic signature：`i` / `b` / `s` / `r` / `p`。
- 如果 call argument type 无法推断，或同签名候选不唯一，保持不绑定。
- 不实现 implicit conversion ranking、default parameter、open array、var/out compatibility、
  visibility、virtual dispatch 或 property/record/array receiver。

### Status

Completed

### Planned Steps

- [x] RED：新增 Integer / Boolean 同 arity member overload focused regression
- [x] 为 `TSemanticSymbol` 增加 `ParamSignature`
- [x] 为 class method symbol 写入 `ParamSignature`
- [x] 从 member call arguments 推导 compact argument signature
- [x] exact member lookup 在同 arity 多候选时按 signature 唯一匹配
- [x] 扩展 `queryDefinitions` / `querySymbols` 参数签名投影与 stage0 gate
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test build 曾失败在 `Identifier idents no member "ParamSignature"`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 type-based overload ranking
- 不实现 implicit conversion / default parameter / var-out compatibility
- 不实现 visibility checking 或 virtual/override dispatch
- 不实现 record/property/array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 72 Member Overload Target Identity

### Goal

关闭 Batch 71 后暴露出的下一个 member-call identity 缺口：当同一个 class 内存在同名 method
overload 时，例如 `TWorker.Pick` 同时有 0 参数与 1 参数版本，`Worker.Pick(1)` 必须绑定到
1 参数 method symbol，而不是只拿第一个同名 `TWorker.Pick` symbol。

本批次新增并冻结：

- class method declaration 的 parameter list 进入 green tree，不再在 parser 中被跳过。
- `method` semantic symbol 记录 `ParamCount`，member target lookup 用 call arg-count 选择同名
  method symbol。
- `queryDefinitions` 对 target symbol 额外投影 `targetParamCount`，让 stage0 / automation 能直接
  验证 overloaded target identity。

### Architecture Decision

这是 argument-count based overload identity，不是完整 type-based overload resolution：

- target 仍必须同 owner unit、同 qualified method name。
- 同 owner 同名同参数个数 method symbol 若不唯一，保守不绑定。
- body declaration 仍作为二次确认：若存在 method body，则必须恰好一个 body 的参数个数与 call
  arg-count 匹配。
- 不实现 typed argument conversion、default parameter、visibility、virtual/override dispatch 或
  property/record/array receiver。

### Status

Completed

### Planned Steps

- [x] RED：新增同名 `TWorker.Pick` 0 参/1 参 focused semantic regression
- [x] 让 class method declaration parameter list 进入 syntax tree
- [x] 为 `method` symbol 设置 `ParamCount`
- [x] 让 exact member lookup 按 `ParamCount` 选择 target method symbol
- [x] 在 `queryDefinitions` 投影 `targetParamCount`
- [x] 扩展 `stage0-query-member-call-bindings-check`
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在
  `semantic-call-bindings-failure=missing-zero-arg-member-overload-symbol`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 default parameter / implicit conversion matching
- 不实现 visibility checking 或 virtual/override dispatch
- 不实现 record/property/array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 71 Inherited Member Receiver Binding

### Goal

关闭 Batch 70 后最直接的 member-call 缺口：当 receiver 的 declared class type 没有直接声明
目标 method，但其 parent class 声明了该 method 时，例如 `TChild = class(TBase)` 后
`Worker: TChild; Worker.Touch;`，binding table 应注册 `member-call`，target 指向
`TBase.Touch` method symbol。

本批次新增并冻结：

- member target lookup 先查 receiver exact type，再沿 `ParentTypeId` 链查 parent type。
- parent traversal 仍使用 type symbol owner 限定 `TClass.Method`，不回退到裸字符串 lookup。
- child exact type 若已声明同名 method 但 arity/body 不唯一，则保守停止，不穿透到 parent 代偿。

### Architecture Decision

这是 inherited lookup 的最小正向边界，不是完整 Pascal member resolver：

- 只覆盖 class parent chain 上已 seed 的 method symbol 与 body declaration argument count。
- 不实现 visibility rules、override/virtual dispatch semantics、record/property/array/deref receiver、
  runtime constructor lowering 或 type-based overload resolution。
- parent chain 设置仍来自声明期 `TypeId` / `ParentTypeId`，不会从 source text 重新猜 class。

### Status

Completed

### Planned Steps

- [x] RED：新增 `TChild` receiver 调用 inherited `TBase.Touch` 的 focused semantic regression
- [x] 拆出 exact type method lookup，并区分“没找到 method”和“找到但 arity/实现不匹配”
- [x] 让 member target lookup 沿 owner-safe `ParentTypeId` 链查找 inherited method
- [x] focused semantic test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=missing-inherited-member-call-binding`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现 visibility checking
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 70 Owner-aware Member Receiver Binding

### Goal

修正 Batch 69 留下的 owner boundary 风险：当 root source 与 imported unit 同时声明同名 class
（例如都叫 `TWorker`）时，root variable receiver 的 `Worker.Add(...)` 必须绑定到该变量真实
`TypeId` 对应 owner unit 下的 `TWorker.Add`，不能因为 imported type/method 先 seed 而误绑到
imported `Worker.TWorker.Add`。

本批次新增并冻结：

- root declaration type resolution 对同名 imported/root class 保持 owner-aware 优先级。
- member receiver lookup 返回稳定 `TypeId`，target lookup 通过 type symbol owner + class name
  选择 method symbol，而不是只靠 `TClass.Method` 字符串的第一个匹配。
- focused semantic regression 覆盖 root/imported 同名 class 的 direct member function call。

### Architecture Decision

这是 member-call binding 的 identity 修补，不是完整 member resolver：

- root owner unit 中同名 type 优先于 imported unit；若只有一个 imported candidate，则仍可解析。
- target method 必须与 receiver type symbol 的 owner unit 对齐。
- 本批不实现 inherited lookup、visibility rules、record/property/array/deref receiver、runtime
  constructor lowering、virtual dispatch 或 type-based overload。

### Status

Completed

### Planned Steps

- [x] RED：新增 root/imported 同名 `TWorker` focused semantic regression，确认旧实现误绑 imported
      method symbol
- [x] 让 type resolution 对当前 owner unit 优先，并在 ambiguity 时保守失败
- [x] 让 member receiver / target lookup 走 `TypeId` + owner unit，而不是裸 class name
- [x] focused semantic test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=missing-owner-aware-member-call-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- Fresh full verification: `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不实现 inherited member lookup / visibility checking
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 69 Self / Imported Member Receiver Binding

### Goal

把 Batch 68 的 class type-name receiver 继续推进到两个高价值但仍然保守的 member-call
边界：

- class method body 内的 `Self.SetValue(9)` 应解析到当前 method context 的 class type，并注册
  `member-call`，target 指向 `TWorker.SetValue` method symbol。
- root source 中变量类型来自 imported unit 时，例如 `uses Worker; var Worker: TWorker;` 后的
  `Worker.Add(1, 2)`，也应能通过 imported unit 中 seed 出来的 `TWorker` type / `TWorker.Add`
  method symbol 完成同一份 binding truth。

本批次新增并冻结：

- `SeedCallBindingsInNode(...)` 携带当前 qualified method declaration 的 class context，让
  `Self` 不靠文本猜测，而是只在 class method body 语境下解析。
- imported project/source unit 的 type section 与 class method symbols 在 root declarations 之前进入
  `TSemanticModel`，让 root variable type resolution 能消费 imported class types。
- `query symbols` 的 member-call gate 增加 `Self.SetValue(9)` 的 `queryBindings` /
  `queryDefinitions` mirror，证明 stage0 query surface 能消费这条 source occurrence truth。
- focused semantic regression 覆盖 imported class variable receiver，证明 imported class type/method
  symbols 与 root source binding table 之间不需要 CLI 重扫源码或独立 lookup。

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 Pascal member resolver：

- `Self` 只在当前 walker 已进入 `TClass.Method` / `TClass.Function` declaration body 后可解析，
  没有 method context 时仍不特殊处理。
- imported type/method symbols 继续归入各自 owner unit scope；root source 只通过同一份
  `TSemanticModel` 的 type id / method symbol id 消费它们。
- member target 仍复用 `TClass.Method` symbol 与 body declaration argument count 的唯一匹配规则。
- 本批不实现继承链 lookup、visibility rules、virtual dispatch、record/property/array/deref receiver、
  runtime constructor lowering、完整 overload/type dispatch 或 LSP incremental overlay。

### Status

Completed

### Planned Steps

- [x] RED/GREEN：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Self.SetValue(9)` 并要求 `SetValue` binding count 从 1 变为 2
- [x] 在 `TSemanticAnalyzer` 中传递 current method class context，并让 `Self` receiver 消费它
- [x] 为 imported unit class receiver 增加 focused semantic regression
- [x] 在 `SeedImportedUnitBodies` 中 seed imported type sections / class methods，并确保 root
      declarations 可解析 imported class type id
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`，固定 `Self.SetValue(9)` 的 query binding /
      definition projection
- [x] 同步 semantic model / language service / developer tooling / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=unexpected-member-call-argument-binding-count:1`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `Self.SetValue(9)` 的 `member-call` / `queryDefinitions`，target 为 `TWorker.SetValue`
  的 `method` symbol
- Fresh full verification: `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"`、`smoke-check=pass`、`verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不实现完整 member lookup / inherited member lookup / visibility checking
- 不实现 runtime constructor allocation / lowering / initialization semantics
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 68 Constructor Class Receiver Binding

### Goal

关闭 Batch 67 留下的 constructor / class type-name receiver 断点：`TWorker.Create(42)`
这类以已声明 class type 名作为 receiver 的 direct member call，也应注册为 `member-call`，
并指向 class declaration 产生的 `TWorker.Create` method symbol。

本批次新增并冻结：

- direct member-call receiver lookup 先使用变量 receiver 类型；若 receiver 不是变量，再只允许回落到
  已声明的 `type` symbol
- `TWorker.Create(42)` 的 `member-call` binding 与 `queryDefinitions` target projection
- focused semantic regression，证明 class type-name receiver 可被 compiler-owned binding table 消费
- stage0 query gate，证明 CLI-facing query surface 同步公开 constructor receiver binding truth

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 constructor 或 member resolver：

- receiver fallback 只接受同一份 `TSemanticModel` 中已声明的 `type` symbol，不从文本猜 class 名。
- target lookup 继续复用 Batch 66 的 `TClass.Method` method symbol 与 body declaration argument count
  matching。
- binding kind 继续使用 `member-call`，让 query consumer 通过同一份 binding/definition projection
  消费 source occurrence truth。
- 本批不实现 runtime object allocation、constructor lowering、完整 static class method semantics、
  full overload/type dispatch、virtual dispatch、record/property/array/deref receiver 或完整 member resolver。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Worker := TWorker.Create(42);`
- [x] 在 `TSemanticAnalyzer` 中实现 member receiver 的 declared type fallback
- [x] focused semantic call binding test 转绿
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已先失败在 `semantic-call-bindings-failure=missing-member-constructor-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `Create` 的 `member-call` / `queryDefinitions`，target 为 `TWorker.Create` 的 `method`
  symbol
- final: fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"`、`smoke-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 不实现 runtime constructor allocation / lowering / initialization semantics
- 不实现完整 static class method semantics
- 不实现完整 type-based overload resolution
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 67 Expression Member Function Binding

### Goal

关闭 Batch 66 留下的 expression-position member function call 断点：`Halt(Worker.Add(1, 2));`
这类作为表达式参数出现的 direct class variable receiver method call，也应注册为 `member-call`，
并指向 `TWorker.Add` method symbol。

本批次新增并冻结：

- wrapped procedure-call statement 的 inner `gnkFunctionCall` 不再整棵跳过；只跳过 wrapper
  callee 自身，继续递归其参数表达式
- direct class receiver method function call 在表达式位置的 `member-call` binding
- `query symbols` 对 expression-position `member-call` / `queryDefinitions` 的 stage0 gate
- focused semantic regression，证明 `Halt(Worker.Add(1, 2));` 可被 compiler-owned binding table 消费

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 member resolver：

- 重用 Batch 65/66 的 receiver variable type lookup、`TClass.Method` symbol lookup 与 arity matching。
- wrapper child 处理只影响 binding walker 的遍历策略：避免对同 offset wrapper call 重复注册，同时不丢失参数里的嵌套 call。
- 表达式位置只承诺 direct variable receiver 的 dot-access method function call。
- constructor call、record/property/array/deref receiver、virtual/override dispatch 与 type-based overload
  resolution 继续保持 deferred。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Halt(Worker.Add(1, 2));`
- [x] 修正 `SeedCallBindingsInNode(...)` 对 wrapped function-call child 的参数遍历
- [x] focused semantic call binding test 转绿
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在 `semantic-call-bindings-failure=missing-member-function-expression-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`stage0QueryMemberCallBindingsCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 constructor binding
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 66 Member Call Argument Arity

### Goal

把 Batch 65 的 direct class variable receiver member-call 从零参数推进到参数个数匹配：
`Worker.SetValue(7);` 这类带参数 method call 应注册为 `member-call`，并指向
`TWorker.SetValue` method symbol；缺参的 `Worker.SetValue;` 不能因为 name match 被误绑。

本批次新增并冻结：

- direct class receiver method call 的 argument count matching
- `TClass.Method` body declaration arity 作为最小匹配依据
- `query symbols` 对 `member-call` / `queryDefinitions` 的 stage0 gate
- focused semantic regression，证明带参数 member-call 和缺参防误绑同时成立

### Architecture Decision

member-call 仍然归属于 `TSemanticAnalyzer` 的 binding seeding，不引入完整 method overload
resolver：

- receiver 类型仍来自 `TSemanticModel` 中 root variable symbol 的 `TypeId`。
- target symbol 仍是 class declaration 产生的 `TClass.Method` / `method` symbol。
- 参数个数只从同名 `TClass.Method` body declaration 的 `CountDeclParams(...)` 读取；如果存在
  body declarations，则必须恰好一个 declaration 与 call argument count 匹配。
- 没有 body declaration 时只保留零参数 declaration-only binding；非零参调用不猜测参数列表。
- 这不是 type-based overload resolution：同名同参数个数的多个 body declaration 仍不会绑定。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入 `Worker.SetValue(7);`
      与缺参 `Worker.SetValue;`，确认旧实现绑定到了错误 occurrence
- [x] 在 `TSemanticAnalyzer.MethodSymbolIdForClassMember(...)` 中加入 body declaration arity
      matching
- [x] focused semantic call binding test 转绿
- [x] 新增 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas`，并把
      `stage0-query-member-call-bindings-check` 纳入 verify-local
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在
  `semantic-call-bindings-failure=member-call-argument-binding-offset-mismatch`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `member-call` / `queryDefinitions` for `Run` 与 `SetValue`
- final: fresh `bash build/verify_local.sh` 已通过，并确认
  `semantic-call-bindings-check=pass`、`stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 expression-position member function call binding
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver 或 constructor binding
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 65 Class Member Call Binding Foundation

### Goal

把 Batch 64 的 selector/member 误绑定防线推进成第一条正向 member binding truth：当 root
source 中已有 class type、class method declaration 和同类型变量时，`Worker.Run;` 这类
无参数 class method call 应进入 `TSemanticModel` binding table，并指向 `TWorker.Run` method
semantic symbol。

本批次新增并冻结：

- class receiver variable -> declared class type 的最小 lookup
- dot-access method callee -> `TClass.Method` semantic symbol binding
- `member-call` binding kind，用于区别 bare procedure/function `call`
- focused semantic regression，证明 selector/member binding 不再只是“排除误绑”

### Architecture Decision

member call binding 继续归属于 `TSemanticAnalyzer`，但不借助 imported bare callable lookup：

- receiver 的类型先从已 seed 的 root `variable` symbol + `TypeId` 读取，不依赖后端 runtime
  lowering 的 `RegisterClassVar(...)` 副表。
- target 只接受当前 semantic model 已声明的 `method` symbol，名字为 `TClass.Method`。
- 本批次只覆盖直接变量 receiver 的 dot-access class method call；record field、property、
  array/deref receiver、constructor dispatch、override/virtual dispatch 和 overload/type-based
  resolution 继续保持 deferred。
- `query-bindings` / `query-definitions` 复用既有 projection，不新增 language-service session。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，要求 `Worker.Run;`
      产生 `member-call` binding 并指向 `TWorker.Run`
- [x] 在 `TSemanticAnalyzer` 中实现 direct class variable receiver 的 method symbol lookup
- [x] focused semantic call binding test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已先失败在 `missing-member-call-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已通过，并确认
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、
  `stage0QueryBindingsCheck":"pass"`、`stage0QueryDefinitionsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现完整 selector/member access binding
- 不实现 class method overload / virtual dispatch / override dispatch
- 不实现 record method、property accessor、array/deref receiver 或 constructor binding
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 64 Selector Call Binding Guard

### Goal

把 Batch 61-63 已经公开的 call binding / definition target truth 继续加固到 selector/member
边界：在完整 member binding 与 type-based dispatch 尚未实现前，`Holder.Help();` 这类 qualified
callee 不能被 name-only lookup 误绑定成 imported unit 的 bare `Help` procedure。

本批次新增并冻结：

- selector/member statement call 不进入 name-only call binding
- qualified function-call wrapper 不注册 imported bare callable binding
- `semantic-call-bindings-check` 覆盖 `Holder.Help;` 与 `Holder.Help();` 两种 selector statement
  边界

### Architecture Decision

selector/member call guard 继续归属于 `TSemanticAnalyzer` 的 binding seeding：

- `TSemanticModel` 仍只持有已经被 analyzer 确认的 source occurrence binding truth。
- 当前 name-only binding 只适用于 bare procedure/function call；qualified callee 需要后续真正的
  member lookup / type dispatch，而不是借 imported callable lookup 兜底。
- `IsQualifiedCallNode(...)` 只识别当前 parser 已生成的 selector wrapper 形态，不新增完整 member
  resolution、不改 `query` projection、不执行 MIR/backend/toolchain。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入 `Holder.Help();`，确认旧实现
      会产生第二条 imported `Help` binding
- [x] 在 `TSemanticAnalyzer.SeedCallBindingsInNode(...)` 前加入 qualified callee guard
- [x] focused semantic call binding test 重新转绿
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 收口验证中把 `verify_local` 的 stage0 / bench build dirs 改成 run-private 临时目录，并让
      lexer/parser/sema bench 显式投影 process CPU timing source
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在
  `semantic-call-bindings-failure=unexpected-imported-call-binding-count:2`
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已通过，并确认 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`stage0QueryBindingsCheck":"pass"`、
  `stage0QueryDefinitionsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 63 Query Definition Target Projection

### Goal

把 Batch 62 已经公开的 `query-bindings` 从“source occurrence -> target symbol id”
继续推进到可直接消费的 definition target metadata：CLI、automation 与 future
language-service adapter 不应为了 go-to-definition / hover 自己再用 `targetSymbolId`
回扫 `querySymbols` 或重读源码。

本批次新增并冻结：

- `TCompilationSession.DefinitionsJson`
- line-based `query-definitions=<json-array>`
- envelope `queryDefinitions`
- `stage0QueryDefinitionsCheck`

### Architecture Decision

query definition projection 继续归属于 compilation-session-backed query surface：

- `TSemanticModel` 仍持有 binding 与 symbol truth；`TCompilationSession` 只在同一份 model 内把
  `TargetSymbolId` join 到目标 `TSemanticSymbol`
- `TUnitGraph` 只用于补 target owner unit name 与 source path，`stage0` CLI 不重扫源码、不解析
  build output、不维护第二套 semantic lookup
- `query-definitions` 与 `query-bindings`、`query-symbols`、`query-scopes`、`query-types`
  同属只读 semantic query projection，不执行 MIR、backend 或 toolchain
- 每个 definition 条目公开稳定最小字段：binding id/kind/name/owner/offset 与 target
  symbol id/name/kind/owner/source path/offset
- 本批次不新增完整 language service session、不做 references/rename/completion，也不扩展
  selector/member access binding 或 type-based overload resolution

### Status

Completed

### Planned Steps

- [x] RED：新增 `stage0-query-definitions-check`，要求 `query-definitions` 与
      `queryDefinitions` 同时投影 binding target metadata
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel.BindingAt(...)` /
      `SymbolAt(...)` 暴露 `DefinitionsJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `hello_with_units.pas` 的 `SayHello` call definition target 已投影
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 先失败在 `missing-stage0-query-definitions-detail`
- GREEN focused: `nextpas query symbols examples/smoke/hello_with_units.pas ...` 输出
  `query-definitions=[{"bindingId":1,"bindingKind":"call","bindingName":"SayHello",...}]`，
  且 envelope 同步带上 `queryDefinitions`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0-query-definitions-check=pass`、`stage0QueryDefinitionsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 62 Query Binding Projection

### Goal

把 Batch 61 已经进入 `TSemanticModel` 的 call binding truth 公开到
`nextpas query symbols`，让 CLI、automation 与 future language-service adapter 可以直接消费
source occurrence -> semantic symbol 的绑定关系，而不是重扫源码或自己猜名字解析。

本批次新增并冻结：

- `TCompilationSession.BindingsJson`
- line-based `query-bindings=<json-array>`
- envelope `queryBindings`
- `stage0QueryBindingsCheck`

### Architecture Decision

query binding projection 继续归属于 compilation-session-backed query surface：

- `TSemanticModel` 仍是 binding truth owner；`stage0` 只透传 `TCompilationSession` 生成的 JSON。
- `query-bindings` 与 `query-symbols`、`query-scopes`、`query-types` 同属只读 semantic query
  projection，不执行 MIR、backend 或 toolchain。
- 每个 binding 条目先公开稳定最小字段：`bindingId`、`kind`、`name`、`ownerUnitId`、
  `byteOffset`、`targetSymbolId`。
- 本批次不新增完整 language service session、不做 references/rename/completion，也不扩展
  selector/member access binding 或 type-based overload resolution。

### Status

Completed

### Planned Steps

- [x] RED：新增 `stage0-query-bindings-check`，要求 `query-bindings` 与 `queryBindings`
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel.BindingAt(...)` 暴露
      `BindingsJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `hello_with_units.pas` 的 `SayHello` call binding 已投影
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 先失败在 `missing-stage0-query-bindings-detail`
- GREEN focused: `nextpas query symbols examples/smoke/hello_with_units.pas ...` 输出
  `query-bindings=[{"bindingId":1,"kind":"call","name":"SayHello",...}]`，且 envelope 同步带上
  `queryBindings`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0-query-bindings-check=pass`、`stage0QueryBindingsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 61 Target Snapshot and Imported Call Binding Closure

### Goal

把上一批已经暴露出来的两条真实边界一起收口：

- semantic binding 不再只覆盖 root unit 内声明的 callable，root source 中调用 imported unit
  的 procedure/function 时也要能绑定到 imported unit 拥有的 callable semantic symbol。
- `pkg plan` 在 canonical `nextpas.lock` 已经带有 target-sensitive `[[snapshot]]` skeleton 时，
  不能把“没有当前 target snapshot”的 lockfile 误判成 install-plan ready。

本批次新增并冻结：

- imported unit call occurrence -> imported callable `SymbolId`
- owner-aware callable body registry / callable symbol seeding
- `package-lock-target-snapshot-missing`
- `stage0PkgPlanLockTargetSnapshotMissingCheck`
- `tests/fixtures/package_lock_target_snapshot_missing`

### Architecture Decision

semantic follow-up 继续归属于 `TSemanticModel` / `TSemanticAnalyzer`：

- imported unit bodies 只作为 compiler-owned semantic truth 输入，不让 LSP/query/IDE adapter
  自行解析 imported source。
- imported callable symbol 必须带 owner unit id，并挂到对应 unit scope；root callable 优先，
  imported callable 只有唯一匹配时才作为 binding target。
- selector/member access 继续排除，避免把 `Holder.Help` 误绑定成 imported procedure call。

package workflow follow-up 继续保持 read-only preflight：

- `BuildPackageWorkflowTruthFromWorkspaceModel(...)` 把 resolved target id 传入 install-plan truth。
- lockfile valid 且 manifest-lock identity 匹配后，如果 lockfile 已有 snapshot 集合但没有当前
  target snapshot，`pkg plan` 阻塞为 `package-lock-target-snapshot-missing`。
- 没有 `[[snapshot]]` 的既有最小 v1 lockfile 继续兼容 ready path；本批次不执行 resolver、
  version solving、fetch/install、lockfile write 或 migration。

### Status

Completed

### Planned Steps

- [x] RED：扩展 semantic call binding focused test，覆盖 imported unit `Help;`
- [x] 在 semantic analyzer 中为 imported unit callable 补 owner-aware body/symbol registration
- [x] 修正参数签名抽取中的 `TypeChild` nil guard，避免 imported body seeding 触发未初始化访问
- [x] RED：新增 target snapshot missing fixture 与 `stage0PkgPlanLockTargetSnapshotMissingCheck`
- [x] 在 package workflow install-plan truth 中加入 target snapshot preflight blocker
- [x] 调整 semantic smoke symbol count 到 owner-aware imported callable truth 的真实值
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 同步 package workflow / workspace file / semantic / stage0 tooling docs 与持续记录
- [x] 简短 review 后提交

### Verification

- focused semantic test 输出 `semantic-call-bindings-status=pass`
- target snapshot missing fixture 输出 `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-lock-target-snapshot-missing` 与
  `package-install-plan-blocker-message=canonical package lockfile has no snapshot for requested target`
- final: fresh `bash build/verify_local.sh` 通过，并确认
  `semantic-call-bindings-check=pass`、`stage0PkgPlanLockTargetSnapshotMissingCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不执行 package resolver、version solving、fetch/install 或 lockfile write

## Addendum: 2026-05-26 Semantic Call Binding Contract

### Goal

为 FPDev LSP 和后续 language-service 工作暴露第一条 source-addressable callable binding
truth：semantic model 不只告诉调用方“有哪些 callable symbol”，还要能说明 root source 中
某个 procedure/function call occurrence 绑定到了哪个 callable semantic symbol。

本批次新增并冻结：

- `TSemanticBinding`
- root procedure/function call binding -> callable `SymbolId`
- overload arg-count 消歧
- `semantic-call-bindings-check`
- verify-local envelope `semanticCallBindingsCheck`

### Architecture Decision

binding contract 归属于 `TSemanticModel`：

- analyzer 负责从已有 callable body registry 生成 binding
- model 持有稳定 identity：binding kind、name、owner unit id、byte offset、target symbol id
- downstream LSP/query/IDE adapter 只消费 model truth，不重扫源码、不自建 parser/type checker
- wrapper `procedure-call-statement -> function-call` AST 只产生一条 binding，避免同一 source offset
  被重复绑定

本批次仍只承诺 root source call binding。selector/member access、imported unit call binding、
bare identifier function-reference binding、完整 overload/type-based resolution 不在本批次内。

### Status

Completed

### Planned Steps

- [x] RED：新增 `tests/semantic/test_semantic_call_bindings.pas`
- [x] 扩展 `TSemanticModel`，新增 `TSemanticBinding` 与 add/read API
- [x] 扩展 `TSemanticAnalyzer`，在 scope assignment 后生成 call bindings
- [x] 对 overloaded procedure call 使用 argument count 选择 target declaration
- [x] 对 wrapper call AST 去重，避免同一 `Pick(1)` 产生两条 binding
- [x] 新增 `semantic-call-bindings-check` 并纳入 verify-local envelope
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 同步持续记录并提交

### Verification

- RED: focused test 必须先暴露旧实现无法正确处理 overload binding
- GREEN: focused test 输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不新增 standalone language service session
- 不实现 selector/member access binding
- 不实现 imported unit call occurrence binding
- 不把 name-only fallback 包装成 semantic binding truth

## Addendum: 2026-05-25 Batch 60 Package Lock Snapshot Consistency

### Goal

把 Batch 59 已公开的 `[[snapshot]]` skeleton 从“字段可见”推进到“最小一致性可信”：
`nextpas.lock` 仍然只读，但 snapshot replay shape 不能再声明一个 lock entries 中不存在的
selection。

本批次新增并冻结：

- `package.lock.snapshot-selection-unmatched`
- `stage0PkgPlanLockSnapshotInvalidCheck`
- `tests/fixtures/package_lock_snapshot_invalid`

### Architecture Decision

本批次仍只在 lockfile v1 parser 内做 read-only validation：

- snapshot `selection` 必须匹配某个 `[[package]] name/version` 组合，即 `name@version`
- snapshot `digest` 目前只接受 `sha256:` scheme；空 digest 仍沿用 Batch 59 的 missing issue
- 同一 lockfile 内重复 snapshot target 会被标成 invalid issue
- 所有问题都进入 `package-lock-status=invalid` 与 `package-lock-invalid` preflight blocker
- 不做 resolver、version solving、target selection、fetch/install 或 lockfile write

### Status

Completed

### Planned Steps

- [x] RED：新增 snapshot invalid fixture 与 `stage0PkgPlanLockSnapshotInvalidCheck`
- [x] 实现 snapshot selection / digest / target 的最小 parser-side consistency validation
- [x] GREEN：focused fresh `bash build/verify_local.sh` 确认新增 gate 通过
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在
  `missing-stage0-pkg-plan-lock-snapshot-invalid-lock-status`
- GREEN: `tests/fixtures/package_lock_snapshot_invalid` 必须投影
  `package.lock.snapshot-selection-unmatched`，并停在 `package-lock-invalid`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockSnapshotInvalidCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不选择或执行 target snapshot
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`

## Addendum: 2026-05-25 Batch 59 Package Lock Snapshot Skeleton

### Goal

把 `nextpas.lock` 的只读 detail 从 package entries 继续推进到最小 resolver snapshot
skeleton，让 CLI / IDE / automation 能看到 target-sensitive replay shape 的第一层事实，
但仍不执行 resolver、version solving、fetch/install 或 lockfile write：

- `package-lock-snapshot-count`
- `package-lock-snapshots`
- envelope `packageLockSnapshotCount`
- envelope `packageLockSnapshots`

### Architecture Decision

本批次只扩展 lockfile v1 的只读 parser 和 projection：

- `[[snapshot]]` 是 resolver snapshot 的最小可解释骨架，当前只读取
  `target`、`provenance`、`digest` 与 `selection`
- snapshot detail 只进入 package lock truth，不改变 install-plan preflight 的 ready /
  blocked / missing 判定
- 缺少 snapshot 的现有 v1 lockfile 仍然合法；有 `[[snapshot]]` 但缺必需字段时才进入
  `package-lock-invalid`
- `pkg inspect`、`pkg plan`、`pkg graph` 与 `doctor` 继续消费同一份
  `TPackageWorkflowTruth`

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgLockSnapshotCheck`，要求 lock snapshot count/detail line 与 envelope
- [x] 扩展 `np_package_lock.pas` 只读解析 `[[snapshot]]`
- [x] 扩展 package workflow truth 与 stage0 text/json projection
- [x] GREEN：focused rerun 确认 lock detail fixture 输出 snapshot，且现有 ready path 不被阻塞
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在缺少
  `package-lock-snapshot-count` / `package-lock-snapshots`
- GREEN: `tests/fixtures/package_lock_detail` 必须投影一个
  `target=linux-x86_64` 的 snapshot detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgLockSnapshotCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`
- 不把 snapshot skeleton 扩成完整 lock writer grammar

## Addendum: 2026-05-25 Batch 58 Manifest-Lock Mismatch Detail

### Goal

把 `package-lock-out-of-sync` 从一个裸 blocker 推进到可解释的 preflight detail：`pkg plan`
在 manifest package identity 与 lock entries 不一致时，必须同时公开 manifest 期望的
package name/version，以及当前 lockfile 实际 entries。

### Architecture Decision

本批次仍然只做 read-only preflight detail：

- `TPackageInstallPlanTruth` 在 out-of-sync blocker 上携带 expected package identity 与 lock entries
- stage0 line output 新增
  `package-install-plan-blocker-expected-package` 与
  `package-install-plan-blocker-lock-entries`
- command envelope 新增
  `packageInstallPlanBlockerExpectedPackage` 与
  `packageInstallPlanBlockerLockEntries`
- ready path 不输出 blocker detail，避免调用方把空 detail 误解成真实阻塞
- 不做 resolver、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgPlanLockOutOfSyncCheck`，要求 expected package 与 lock entries detail
- [x] 在 install-plan truth 中携带 out-of-sync blocker detail
- [x] 扩展 stage0 text/json projection
- [x] focused GREEN：确认 out-of-sync path 有 detail，ready path 不带 blocker detail
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认旧输出没有
  `package-install-plan-blocker-expected-package` /
  `package-install-plan-blocker-lock-entries`
- GREEN: focused probe 确认 out-of-sync fixture 输出 expected manifest identity 与 actual lock entries，
  且 ready fixture 不输出 blocker detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 57 Manifest-Lock Consistency Preflight

### Goal

把 `pkg plan` 的 lockfile preflight 从“lockfile 可解析”继续推进到“manifest 与 lock 的最小
identity 一致”：当 `nextpas.package.toml` 声明的 package name/version 在 canonical
`nextpas.lock` entries 中找不到同名同版本 package 时，`pkg plan` 必须停在明确的
`package-lock-out-of-sync` blocker。

### Architecture Decision

本批次仍然只做 read-only preflight：

- `TPackageManifestInfo` 开始保存 `[package].version`，并通过 `WorkspaceModel` 传给
  `TPackageWorkflowTruth`
- `BuildPackageInstallPlanTruth` 在 lock status 为 `ready` 后检查 manifest package
  name/version 是否存在于 lock entries
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> lock out of sync -> ready
- 不做 dependency resolution、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] 新增 out-of-sync lock fixture，并把 ready lock fixtures 调整为当前 package identity
- [x] 新增 `stage0PkgPlanLockOutOfSyncCheck`，冻结 `package-lock-out-of-sync` blocker
- [x] 将 package manifest version 纳入 manifest/workspace/workflow truth
- [x] 在 install-plan preflight 中加入 manifest-lock identity match
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认 out-of-sync fixture 在实现前仍被误报为
  `package-install-plan-status=ready`
- GREEN: focused probe 确认 out-of-sync fixture 投影
  `package-install-plan-status=blocked` 与
  `package-install-plan-blocker-code=package-lock-out-of-sync`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 56 Package Lockfile v1 Read-only Detail

### Goal

把 canonical `nextpas.lock` 从“存在即 ready”的布尔事实推进到最小 v1 只读 detail：
CLI / IDE / automation 应能直接看到 lockfile format version、package entries 与 validation
issues，并且 `pkg plan` 在 lockfile 无效时必须停在明确的 `package-lock-invalid` blocker。

### Architecture Decision

本批次新增 `compiler/frontend/np_package_lock.pas`，但仍保持 read-only boundary：

- 当前只读取最小 TOML v1：`[lockfile] format-version = 1` 与 `[[package]] name/version`
- `package-lock-status` 扩展为 `missing|ready|invalid`
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> ready
- 不做 resolver、fetch/install、publish、lockfile writer 或 lockfile mutation

### Status

Completed

### Planned Steps

- [x] 新增 lock detail / invalid lock fixtures，并把既有 ready lock fixtures 升级为最小 v1 TOML
- [x] 新增 `np_package_lock` 只读 parser 与 validation issue model
- [x] 扩展 package workflow truth、line output 与 command envelope 的 lock detail 投影
- [x] 扩展 `build/verify_local.sh`，覆盖 lock detail ready path 与 invalid-lock blocked plan path
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh `bash build/verify_local.sh` 先失败在
  `missing-stage0-pkg-lock-detail-format-version`
- GREEN: fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgLockDetailCheck=pass`、
  `stage0PkgPlanLockInvalidCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不写入或重写 `nextpas.lock`
- 不把最小 v1 skeleton 扩展成完整 resolver snapshot grammar

## Addendum: 2026-05-25 Batch 55 Package Plan Blocker Matrix Gates

### Goal

把 `nextpas pkg plan` 的 install-plan preflight 从“三态已公开”继续推进到“关键 blocker
原因全覆盖”：同一条 `pkg plan` 专用只读面必须覆盖当前 `TPackageWorkflowTruth` 已经拥有的
四类终止原因，避免 CLI / IDE / automation 在 blocked 场景里还要绕回 `pkg inspect` 推断。

### Architecture Decision

本批次仍不新增 resolver、fetch、install 或第二套 planner。`pkg plan` 继续复用
`WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把剩余 blocker 纳入
promotion gate：

- malformed dependency fixture 必须投影 `blocked` 与 `package-dependencies-invalid`
- manifest / lock ready 但无 source roots 的 fixture 必须投影 `blocked` 与
  `package-source-roots-missing`

### Status

Completed

### Planned Steps

- [x] 新增 `package_manifest_no_source_roots` fixture，冻结 manifest / lock ready 但 source roots
      为空的 package truth
- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` dependency-invalid 与 source-roots-missing
      blocked 命令结果
- [x] 同步 tools README、package workflow / developer tooling spec、rolling roadmap 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认
  `stage0PkgPlanDependencyBlockedCheck=pass`、
  `stage0PkgPlanSourceRootsBlockedCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 install plan blocker 顺序
- 不改 lockfile write path

## Addendum: 2026-05-25 Batch 54 Package Plan Blocked/Missing Gates

### Goal

把 `nextpas pkg plan` 从只验证 ready path 推进到完整 preflight 状态边界：同一条公开面必须
直接覆盖 `ready`、`blocked` 与 `missing`，让 CLI / IDE / automation 不需要从
`pkg inspect` 或 `doctor` 间接推断 install plan 为什么不能继续。

### Architecture Decision

本批次不新增第二套 plan logic。`pkg plan` 继续复用 `WorkspaceModel` +
`TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把现有 truth 的 blocked / missing
行为纳入 promotion gate：

- workspace member fixture 缺 canonical lockfile 时必须投影 `blocked` 与
  `package-lock-missing`
- package-free workspace 必须投影 `missing` 与 `package-manifest-missing`

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` blocked 与 missing 正向命令结果
- [x] 同步 tools README、package workflow / developer tooling / stage0 README 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanBlockedCheck=pass`、
  `stage0PkgPlanMissingCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不新增 install planner；只冻结现有 preflight truth 的状态边界

## Addendum: 2026-05-25 Batch 53 Package Plan Read-only Surface

### Goal

把 package workflow 的 install plan preflight truth 公开成真实 `nextpas pkg plan` 面，
让 CLI / IDE / automation 直接消费 workspace-model-backed package install-plan truth，
而不是继续只在 `doctor` / `pkg inspect` 里间接看到它。

### Architecture Decision

`pkg plan` 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。install plan 语义
仍然维持 Batch 48 冻结下来的 `ready|blocked|missing` preflight truth；`pkg plan` 只是把同一份
truth 公开成一个专用只读面，而不是第二套 install planner。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanCheck=pass`、
  `stage0PkgPlanInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package install plan truth

## Addendum: 2026-05-25 Batch 52 Package Graph Read-only Surface

### Goal

把 package workflow 的只读 graph surface 收成真实 `nextpas pkg graph` 公开面，让 CLI / IDE /
automation 直接消费 workspace-model-backed package graph truth，而不是自己重拼 declared
dependency intent。

### Architecture Decision

graph 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。图语义固定为
package root node + declared-dependency nodes + `declared-dependency` edges；它只是同一份
package workflow truth 的另一种只读视图，不是第二套 graph engine。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg graph` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgGraphCheck=pass`、
  `stage0PkgGraphInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package graph truth

## Addendum: 2026-05-24 Batch 51 Env Clean Workspace-Local Cache Cleanup

### Goal

把 `env` family 的最小维护面继续收口到 workspace-local cleanup：

- 新增 `nextpas env clean --target linux-x86_64 --workspace <root>`
- `env clean` 只删除 `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`
- 输出与 `command-envelope=<json>` 必须暴露 cleanup path / status / change /
  removed-count，方便 CLI、IDE 与 automation 判断清理范围

### Architecture Decision

本批次只清理 workspace-local selection / resolution sidecar，不下载、不解包、不安装 runtime SDK，
不改写 workspace descriptor、package manifest、lockfile 或公开 install result。`env clean` 是显式
maintenance surface，不是 `env gc`，也不承诺清掉更广义的 metadata/archive/staging bucket。

### Status

Completed

### Planned Steps

- [x] 确认 `env clean` 只接受 `--target` 与必须的 `--workspace`
- [x] 实现 `env clean` parser、workspace-local selection/resolution 删除与 line / envelope 投影
- [x] 扩展 `build/verify_local.sh`，覆盖首次 removed、二次 unchanged 与 invalid-arguments
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env gc`
- 不下载、不解包、不安装 runtime SDK
- 不改写 workspace descriptor、package manifest、lockfile
- 不删除 `units/`、`lib/`、`share/` 或公开 install result

## Addendum: 2026-05-24 Batch 50 Env Sync Workspace Resolution Cache

### Goal

把 `env` family 从 selection mutation 继续推进到第一条 workspace-local sync 闭环：

- 新增 `nextpas env sync --target linux-x86_64 --workspace <root> [--toolchain-binding <id>]`
- `env sync` 在未显式传 `--toolchain-binding` 时读取 Batch 49 的 workspace selection
- 只写 `<workspace>/.nextpas/env/resolution/<target>.toml`，记录当前 resolved binding、distribution、runtime SDK readiness 与 selection 输入
- 公开输出与 `command-envelope=<json>` 必须暴露 resolution path / status / sync delta，方便 CLI、IDE 与 automation 判断本机环境 resolution 是否已经刷新

### Architecture Decision

本批次只 materialize ArtifactRootSet 管辖下的 machine-local environment resolution cache，
不下载、不解包、不安装 runtime SDK，不改写 `env/selections`、`nextpas.workspace.toml`、
`nextpas.package.toml` 或 `nextpas.lock`。`env sync` 是 workspace-local sync surface，
不是 `env bootstrap` 或完整 distribution installer。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 已有 `status/use` 和 workspace selection sidecar，但没有 `sync` 入口
- [x] 实现 `env sync` parser、resolution sidecar write、line output 与 command envelope projection
- [x] 扩展 `build/verify_local.sh`，覆盖首次 materialized 与二次 unchanged
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env bootstrap`、下载、解包、archive cache、metadata channel resolver 或 runtime SDK 安装
- 不让 `env sync` 改写 selection sidecar；切换 binding 仍由 `env use` 负责
- 不回写 workspace descriptor、package manifest 或 lockfile
- 不让 `build` / `doctor` / `pkg` 在本批次隐式消费 resolution cache

## Addendum: 2026-05-24 Batch 49 Env Use Workspace Selection Sidecar

### Goal

把 `env` family 从纯只读 `status` 推进到第一条真实但最小的 mutation verb：

- 新增 `nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>`
- `env use` 只写 workspace-local machine state：
  `<workspace>/.nextpas/env/selections/<target>.toml`
- `env status --target <target> --workspace <root>` 在没有显式
  `--toolchain-binding` 时读取该 selection，并继续复用同一份 target / binding /
  distribution / runtime projection
- 公开输出与 `command-envelope=<json>` 必须暴露 selection path / status / target /
  selected binding，方便 CLI、IDE 与 automation 判断当前机器选择

### Architecture Decision

本批次只让 `env use` 改变 ArtifactRootSet 管辖下的 machine-local selection sidecar，不改
`nextpas.workspace.toml`、`nextpas.package.toml`、`nextpas.lock`、target config 或 toolchain
binding config。显式 `--toolchain-binding` 继续高于 selection；`env sync` / `env bootstrap`
仍然不开启下载、解包、runtime SDK materialize 或 install result mutation。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 入口只有只读 `status`，且文档已把
      `env/selections` 归入 ArtifactRootSet machine-local sidecar
- [x] 实现 `env use` parser、selection sidecar write，以及
      `env status --workspace` selection read
- [x] 扩展 line-based output、command envelope 与 `build/verify_local.sh` gate
- [x] 同步 stage0 / developer tooling / workspace 文件层文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env sync`、`env bootstrap`、下载、解包或 runtime SDK 安装
- 不让 `build` / `doctor` 在本批次隐式消费 workspace selection
- 不把 active selection 写进 workspace descriptor、package manifest 或 lockfile
- 不新增 channel / distribution resolver；本批次只冻结 preferred binding selection

## Addendum: 2026-05-24 Batch 48 Package Install Plan Preflight Truth

### Goal

把 package workflow 里还停在 `deferred` 的 install plan truth 收成真正可消费的只读预检结果，
让 CLI / automation 能直接判断“现在能不能进入 install plan 生成前置阶段”，而不是只看到一条
没有解释力的占位状态：

- `package-install-plan-status` 继续作为公开 surface，但状态语义改为 `ready|blocked|missing`
- `missing` 只表示 package workflow 本身不可用，或没有可解释的 package truth
- `blocked` 表示 package truth 已存在，但仍有明确阻塞，必要时补 `package-install-plan-blocker-code`
  与 `package-install-plan-blocker-message`
- `ready` 表示 install plan preflight 已满足，仍不代表真正执行 resolver / install / write-back
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不分裂成两套解释

### Architecture Decision

install plan preflight 只负责回答“能否进入下一步”，不提前打开任何 resolver、fetch、install、
lockfile write 或 mutation path。它的状态边界会按 package workflow truth 的现有层级做最小派生：

- manifest 不存在时，install plan 直接 `missing`
- manifest 存在但被 dependency validation、lock presence 或 source-root completeness 阻塞时，install plan
  投影为 `blocked`
- 只有 manifest、lock、dependency 与 source-root 前置条件都满足时，才投影为 `ready`

### Status

Completed

### Planned Steps

- [x] 确认当前 install-plan 投影仍然固定为 `deferred`，并定位相关 truth / projection / verify
      代码路径
- [x] 在 `compiler/frontend/np_package_workflow.pas` 落 install plan preflight truth 与 blocker 详情
- [x] 同步 `tools/stage0` 投影、`tests/toolchain/toolchain_contract_smoke.pas`、`build/verify_local.sh`
      与相关文档
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，最终输出 `verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolver
- 不做 install plan writer
- 不做 lockfile mutation
- 不改 `nextpas.lock` 文件语法或 registry 语义

## Addendum: 2026-05-24 Batch 47 Package Lockfile Presence Truth

### Goal

把 package workflow 里仍然固定为 deferred 的 lock truth 收成真实只读事实：

- `package-lock-status` 继续只读投影 canonical `nextpas.lock` 的存在性
- lockfile 存在时投影 `ready`
- lockfile 不存在时投影 `missing`
- `package-install-plan-status` 继续保持 deferred，本批次不打开 install plan 生成、resolver、
  write-back 或 lockfile mutation
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不再让 lock truth 被固定成
  失真的默认值

### Architecture Decision

lock truth 现在属于 package workflow 的最小可见状态，不再只靠“path 已知但 status deferred”
来表达。我们只读观察 canonical lockfile 是否存在，先让 CLI / automation 能区分“有锁”和“没锁”，
不提前打开真正的 lock write。

### Status

Completed

### Acceptance

- ready package fixture 必须稳定投影 `package-lock-status=ready`
- 没有 lockfile 的 workspace / package root 必须稳定投影 `package-lock-status=missing`
- `command-envelope=<json>.result` 必须同步投影 `packageLockStatus`
- `package-install-plan-status` 仍然保持 deferred
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 lockfile writer
- 不做 dependency resolution
- 不做 install plan generation
- 不改变现有 package manifest / dependency validation grammar

### Planned Steps

- [x] 确认当前 lock truth 与 verify gate 的现状
- [x] 实现 lockfile presence truth 并补 package fixture lockfile
- [x] 同步 verify gate、文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 46 Dependency Requirement Grammar Validation

### Goal

把 Batch 45 已经公开的 declared dependency intent 从“字符串被投影”推进到“格式可信、
违规可解释”的最小 deterministic contract：

- `[dependencies]` 继续只接受 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- dependency requirement string 第一阶段只支持 comparator grammar：`=`、`>`、`>=`、`<`、`<=`
- 多 comparator 用逗号表达 intersection，例如 `>=0.1.0, <0.2.0`
- invalid dependency requirement 不能静默消失；`doctor` / `pkg inspect` 必须能暴露可解释的
  malformed dependency intent
- read-only inspection command 可以继续成功返回，但 package workflow truth 必须把 invalid
  manifest/dependency state 投影给 IDE、CI 与 automation

### Architecture Decision

本批次不打开 resolver。dependency requirement validation 属于 manifest / workflow truth 的输入
可信度边界，先挡住不可信 declaration 进入后续 lock、solver、IDE package view 或 CI automation。

第一阶段明确不支持 union range、feature flag、optional dependency、target-specific dependency
table 或 solver annotation；这些属于 future schema / resolver batch，而不是本批次的 parser
扩张。

### Status

Completed

### Acceptance

- valid examples 必须保留为 declared dependency intent：
  `=0.1.0`、`>0.1.0`、`>=0.1.0`、`<0.2.0`、`<=0.2.0`、
  `>=0.1.0, <0.2.0`
- invalid examples 必须被稳定暴露为 malformed dependency intent，而不是被忽略：
  `^0.1.0`、`~>0.1`、`>=`、`>=0.1.0 || <0.2.0`、empty requirement
- `doctor --workspace` 与 `pkg inspect` 至少一条公开 projection surface 能显示 dependency
  validation status / malformed dependency detail；理想路径是两者共享同一份 package workflow truth
- `build/verify_local.sh` 必须新增 malformed dependency fixture gate，并在最终 envelope 暴露
  对应 check pass 字段
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 dependency resolution、version selection、registry lookup、fetch/install 或 lockfile write
- 不做 semantic version ordering / compatibility solving；本批次只验证 requirement syntax shape
- 不把 target-specific dependency table、optional dependency 或 feature flag 写进当前 grammar
- 不把 diagnostics contract 大重构塞进本批次；只补足本批次需要的 deterministic invalid state

### Planned Steps

- [x] focused probe 当前 parser 对 malformed dependency 的行为，确认 `^0.1.0` 会作为 raw string
      投影且没有 invalid signal
- [x] 设计 manifest/workflow 层的 validation result 承载方式，避免 CLI 两侧各自解析
- [x] 新增 malformed dependency fixture，覆盖 invalid requirement 不静默消失
- [x] 先把 `build/verify_local.sh` gate 写成 RED，冻结 `doctor` / `pkg inspect` 预期
- [x] 实现最小 comparator grammar validation 与 projection
- [x] 同步 stage0 README、workspace/package workflow specs、rolling plan 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 45 Declared Dependencies Projection

### Goal

把 package manifest 的 `[dependencies]` declared intent 接入 shared package workflow truth，并
通过 `doctor --workspace` / `pkg inspect` 做只读投影：

- manifest parser 支持当前规范已冻结的 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- `TPackageManifestInfo`、`TWorkspaceModel.PackageRef` 与 `TPackageManifestTruth` 持有
  declared dependency name / requirement
- line-based output 新增 `package-dependency-count` 与 `package-dependencies=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageDependencyCount` 与 `packageDependencies`
- non-goal：不做 dependency resolution、solver、fetch/install、lockfile write、target-specific
  dependencies 或 feature flags

### Status

Completed

### Planned Steps

- [x] 确认当前 parser/workflow 只持有 package identity 与 source roots
- [x] 扩展 manifest parser、workspace model 与 workflow truth
- [x] 扩展 package projection text/json 输出
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect declared dependency gate
- [x] 同步必要文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 44 Package Source Roots Projection

### Goal

把 package workflow truth 中已经存在的 `SourceRoots` 从内部事实提升为公开只读投影，避免
IDE、CI 或 automation 只能拿到 `package-source-root-count` 后再回头解析 manifest：

- `pkg inspect` 与 `doctor --workspace` 必须继续复用同一份 `PackageWorkflowTruth`
- line-based output 在 `package-source-root-count` 之外新增
  `package-source-roots=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageSourceRoots`
- 缺少 package truth 时投影 `package-source-roots=[]`，与
  `package-source-root-count=0` 保持一致
- non-goal：不做 package resolution、fetch、install、lockfile write 或 manifest 格式扩展

### Status

Completed

### Planned Steps

- [x] 扩展 `TPackageProjectionContext`，承载 `SourceRootsJson`
- [x] 在 `CapturePackageProjectionFromWorkflowTruth(...)` 中从
      `ManifestTruth.SourceRoots` 生成 JSON array
- [x] 扩展 line-based output 与 command envelope
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect package roots detail gate
- [x] 同步最小文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 43 Pkg Inspect Workspace Member Contract

### Goal

把 Batch 42 已冻结的 workspace descriptor root + member package ready contract，从 `doctor`
同步扩展到只读 `pkg inspect`：

- `pkg inspect --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel` /
  `PackageWorkflowTruth`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `pkg inspect` 实现、不做 package resolution/fetch/install、不打开
  lockfile write、publish workflow 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `pkg inspect` 已经返回
      workspace descriptor + member package ready
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-pkg-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0PkgWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 42 Doctor Workspace Member Package Contract

### Goal

把 Batch 41 的 ready package workspace gate 从单包 manifest root 扩展到 workspace descriptor
root + member package 的真实形态：

- `doctor --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `doctor` 实现、不做 package resolution/fetch/install、不打开
  `env sync` 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `doctor` 已经返回
      workspace descriptor + member package ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 41 Doctor Package Workspace Positive Contract

### Goal

把 Batch 40 已接入的 `doctor` package/workspace coherence 从“只冻结缺失路径”推进到
“ready 与 missing 两侧都被 promotion gate 保护”：

- `doctor --workspace <package root>` 必须复用同一份 `WorkspaceModel` / `PackageWorkflowTruth`
- package workspace 正向样本必须稳定投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 manifest/root/name/lockfile
  detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留同一批 package detail fields
- non-goal：不修改 `doctor` 实现、不执行 fetch/install/resolution、不进入 `env sync` 或
  package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/package_manifest_source_root` 下 `doctor` 已经返回
      package workflow ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-package-workspace-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorPackageWorkspaceCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 40 Doctor Package/Workspace Coherence

### Goal

把 `doctor` 的只读 health inspection 再往 package/workspace truth 收拢：在有 `--workspace`
时复用 `ResolvePackageInspectionSourcePath(...)` + `ResolveWorkspaceModel(...)`，打印
`PackageProjection`，并在缺少 package workspace truth 时投影
`doctor.package-workspace-missing`；以 repo root 缺少 package descriptor 作为负向样本，
但继续保持 `doctor` 不是 `env sync`、`env use` 或 `env bootstrap`。

- owner 继续是 `tools/stage0/nextpas_command_doctor.pas` 与
  `tools/stage0/nextpas_projection_context.pas`
- truth objects 是 `TEnvironmentProjectionContext`、`TPackageProjectionContext` 与
  `TDoctorProjectionContext`
- line-based output 与 command envelope 同步投影 package workflow truth
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-doctor-check`
- non-goal：不把 `doctor` 变成 package manager 执行面，也不修改环境状态

### Status

Completed

### Planned Steps

- [x] 先确认 `doctor` 的 package/workspace coherence 仍然是只读 inspection，而不是执行面
- [x] 在 `tools/stage0/nextpas_command_doctor.pas` 中有 `--workspace` 时复用 package inspection
      source path 与 workspace model，并打印 `PackageProjection`
- [x] 在 `tools/stage0/nextpas_projection_context.pas` 中加入
      `doctor.package-workspace-missing` finding，并把 package workflow truth 纳入 doctor check count
- [x] 扩展 `build/verify_local.sh` 的 `stage0-doctor-check`，冻结 repo root 的 package truth
      缺失边界与 envelope finding
- [x] 同步 `tools/stage0/README.md`、architecture specs、roadmap、`task_plan.md`、
      `progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 39 Query Semantic Graph Side Tables

### Goal

把 `query symbols` 从“每个 symbol 都携带可读 metadata”继续推进到可被 CLI、automation
和 future IDE adapter 直接消费的 normalized semantic graph projection：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不重扫源码、不解析 stdout、不维护第二套
  semantic lookup
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol`、`TSemanticScope` 与
  `TSemanticType`
- line-based output 在 `query-symbols` 之外新增 `query-scopes=<json-array>` 与
  `query-types=<json-array>`，让 `scopeId` / `typeId` 可以通过同一份 query result 回查
- `command-envelope=<json>.result` 同步新增 `queryScopes` 与 `queryTypes`
- promotion gate 新增 `stage0-query-symbols-semantic-graph-check`，用 `var_halt.pas`
  冻结 unit scope `VarHalt` 与 builtin type `Integer` side table
- non-goal：不新增 LSP / language service session，不做 overlay、incremental invalidation、
  references、rename、completion，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-graph-check` 写成 RED gate
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel` 暴露 `ScopesJson` 与
      `TypesJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `var_halt.pas` 的 scope/type side tables 与 symbol metadata 同步
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 38 Query Symbols Semantic Metadata

### Goal

把 Batch 37 已经公开的 `query-symbols` 从 raw ids 继续推进到可被 CLI、future IDE adapter
和 automation 直接消费的 semantic metadata projection，同时继续守住 query 只读边界：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不从 stdout、源码文本或 build output
  反推 symbol metadata
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol` / `TSemanticScope` /
  `TSemanticType`，以及同一份 `TUnitGraph` 的 owner unit truth
- `querySymbols[]` 在保留 raw `ownerUnitId`、`scopeId`、`typeId` 的同时，补充
  `ownerUnitName`、`scopeKind`、`scopeName`、`scopeParentId`、`typeName`、`typeKind`
  与 `typeParentId`
- promotion gate 继续落在 `build/verify_local.sh` 的 query check，新增 `var_halt.pas`
  focused probe，冻结变量符号 `x` 的 owner/scope/type metadata
- non-goal：不实现 references、rename、completion、open document overlay、incremental
  invalidation，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-metadata-check` 写成 RED gate
- [x] 在 `TCompilationSession.SymbolsJson` 中从 session-owned model / unit graph 补 semantic metadata
- [x] focused probe 确认 `var_halt.pas` 的变量符号输出 `ownerUnitName`、scope metadata 与 type metadata
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 37 Query Symbols Detail Projection

### Goal

把已经存在的只读 `query symbols` 从“只给 aggregate count”推进到可被 CLI、IDE adapter
和 automation 直接消费的结构化 symbol detail projection，同时继续守住它不是完整
language service / LSP 的边界：

- owner 继续是 `TCompilationSession` / `TSemanticModel`，不在 stage0 CLI 旁路重扫源码或解析输出
- truth object 是当前 semantic symbol graph 中的 `TSemanticSymbol`
- line-based output 必须新增 `query-symbols=<json-array>`，与 `query-result-count` 表达同一批结果
- `command-envelope=<json>.result` 必须新增 `querySymbols`，字段来自同一份 session-owned JSON
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-query-symbols-check`
- non-goal：不实现 LSP server、open document overlay、incremental invalidation、references、
  rename preflight、completion 或 backend/toolchain execution

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-check` 写成 RED gate，要求 line/envelope 两层 symbol detail
- [x] 在 `TCompilationSession` 暴露 session-owned `SymbolsJson`
- [x] 扩展 `TQueryProjectionContext`、text/json projection helper 与 `RunQuerySymbols`
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Rolling Plan Batch 36 Truth Sync

### Goal

把当前 rolling plan 的入口状态同步到真实最新基线，避免后续恢复时误以为 production-path
contract 仍停在 `Batch 35`：

- `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 顶部必须写明当前最新完成批次是
  `Batch 36`
- 当前状态段必须把 stage0 driver decomposition、projection ownership、malformed manifest
  fallback、diagnostic record extensibility 与 resolver search-index staleness tracking 写成
  `Batch 36` 已验证 baseline
- `build/verify_local.sh` docs-check 必须要求当前 rolling plan 存在，避免活动主线入口从验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让下一次“继续”从真实最新批次恢复

### Status

Completed

### Planned Steps

- [x] 同步 rolling plan 顶部状态到 `Batch 36`
- [x] 将 rolling plan 纳入 docs-check
- [x] 同步持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Architecture Principles and Quality Bar

### Goal

把“打造 FreePascal 领域一流现代 Pascal 开发环境”的高阶目标固化为可引用、可验证、
可执行的架构原则，而不是停留在愿景口号：

- 新增 `docs/architecture/architecture-principles-specification.md`，明确正确性、shared truth、
  thin entrypoint、性能前置、可维护性、统一词汇与兼容性诚实这些长期门槛
- 让 `overview.md`、`master-roadmap.md`、仓库 README 与架构目录都把这份规范作为后续设计入口
- 将新规范纳入 `build/verify_local.sh` 的 docs-check，避免架构质量门槛从仓库验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让后续“继续”能直接沿该质量门槛推进

### Status

Completed

### Completed Steps

- [x] 新增 `docs/architecture/architecture-principles-specification.md`
- [x] 同步 README、架构目录、总览、主路线图与 docs-check
- [x] 同步 `task_plan.md`、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`，确认新规范进入 docs-check 且整套
      `verify-local=pass`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 `pkg inspect` package workflow detail hardening

### Goal

把已经存在的 package workflow truth 从 aggregate status 继续推进到可消费的只读细节投影，
同时继续守住 non-executing package manager 边界：

- `pkg inspect` 必须继续复用 `WorkspaceModel` / `PackageWorkflowTruth`，不执行 fetch、install、
  dependency resolution、lockfile write 或 publish workflow
- line-based output 必须冻结 workflow-owned manifest path、package root、package name、
  lock status 与 canonical lockfile path
- `command-envelope=<json>.result` 必须同步带上 `packageWorkflowManifestPath`、
  `packageRootPath`、`packageName`、`packageLockStatus` 与 `packageLockfilePath`
- `build/verify_local.sh` 必须把这批 detail fields 纳入 `stage0-pkg-inspect-check`

### Status

Completed

### Completed Steps

- [x] 扩展 `tools/stage0/nextpas_projection_text.pas`，新增
      `package-workflow-manifest-path`
- [x] 扩展 `tools/stage0/nextpas_projection_json.pas`，新增
      `packageWorkflowManifestPath`
- [x] 加严 `build/verify_local.sh` 的 `stage0-pkg-inspect-check`，冻结
      manifest path、package root、package name、lock status 与 lockfile path 的 line/envelope
      contract
- [x] 同步回写 `tools/stage0/README.md`、package workflow / roadmap docs 与持续记录
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Installed-source Extra Assemble Boundary Closure

### Goal

把这轮 Stage2 / semantic smoke follow-up 从“linked root 缺少 source-backed unit `.o`”和
“unit root 被误扩成 transitive extra assemble”两侧一起收口，形成更诚实的最小边界：

- `compiler/diagnostics/np_diagnostics_sink.pas` 必须能稳定解析同目录
  `nextpas_json_helpers`，不再依赖偶然 search path
- `units/linux-x86_64/SysUtils.pas` 必须补齐当前 compiler path 真实需要的
  `IntToHex(Value: Int64; Digits: Integer)`
- `compiler/frontend/np_compilation_session.pas` 的
  `CollectAdditionalAssemblyBaseNames()` 必须只在 `program|library|package` 这类 linked root
  上收集额外 assemble base name，并允许 `installed-source` units 进入集合
- `unit` root 必须继续停留在 `host-fpc-emit-asm -> native-assemble`，不能为 transitive deps
  伪造 extra assemble steps
- `build/verify_local.sh` 必须把 `hello_with_units` 的 semantic-smoke reality 冻结为
  `typed-hir-node-count=8`、`tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`

### Status

Completed

### Completed Steps

- [x] 先复现 `hello_with_units` link failure，确认真实缺口是
      `Stage0Greeter.o` / `Stage0GreeterImpl.o` 没有物化，而不是 link command 本身错误
- [x] 在 `compiler/diagnostics/np_diagnostics_sink.pas` 补上 `{$UNITPATH .}`，让同目录
      `nextpas_json_helpers` 成为明确依赖
- [x] 在 `units/linux-x86_64/SysUtils.pas` 补上
      `IntToHex(Value: Int64; Digits: Integer)`，消除当前 compiler/self-host path 的 RTL 缺口
- [x] 调整 `CollectAdditionalAssemblyBaseNames()`：
      `unit` root 直接返回空集合；linked root 只跳过 `implicit-runtime`，不再错误排除
      `installed-source`
- [x] 回写 `build/verify_local.sh` 的 semantic-smoke contract，固定
      `hello_with_units` 为 5-step / 16-event，并把 `typedHirNodeCount` 改回真实 `8`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 Self-compile Coverage Parity

### Goal

把 Stage2 compiler-module self-compile 的记录与 promotion path 对齐：上一批 notes 已经把
`np_workspace_model` 写成 fresh 成功，但 `build/verify_local.sh` 只 gate 了
`np_diagnostics_sink` 与 `np_source_database`。这批不扩大 self-hosting 语义，只把已经成立的
`np_workspace_model` unit-root object-file contract 固化进 verify。

### Status

Completed

### Completed Steps

- [x] 核对当前记录与 `build/verify_local.sh`，确认 drift 只在
      `np_workspace_model` 是否进入 promotion path
- [x] 在 `build/verify_local.sh` 增加
      `compiler/frontend/np_workspace_model.pas` self-compile probe
- [x] 复用 unit-root contract：`backend-output-kind=object-file`、
      `toolchain-plan-family=bootstrap-native-assemble`、
      `logical-link-request-status=deferred`
- [x] 额外冻结 `tool-invocation-count=2` / `tool-run-step-count=2` 与 no-`native-link`，
      防止 unit root 漂回 transitive extra assemble 或 link
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 unit self-compile boundary

### Goal

把 Stage2 自编译从“卡在 target-installed `SysUtils` parser failure”和“把 `unit` 误当成
`executable` 去 link”的混合失败，收口成一个真实、可验证、可持续的最小成功边界：

- target-installed / compiler source 里的 `= class(Exception);` shorthand 改成 parser 已稳定支持的
  `class(Exception) ... end;`
- `compiler/backend/np_backend_plan.pas` 改为按 root kind 区分输出：
  `program|library|package -> executable`，`unit -> object-file`
- `compiler/toolchain/np_toolchain_plan.pas` 为 unit roots 走
  `bootstrap-native-assemble`（`host-fpc-emit-asm -> native-assemble`），不再伪造
  `native-link`
- `build/verify_local.sh` 纳入 compiler-module self-compile gate，冻结
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 的 object-file self-host
  contract

### Status

Completed

### Completed Steps

- [x] 重现并定位 `parser.syntax-error: "IMPLEMENTATION" expected but "END" found`
      到 `SysUtils` / compiler units 中的 `class(Exception);` shorthand
- [x] 将 `SysUtils`、compiler/toolchain/frontend 相关 unit 里的 shorthand class 统一改为
      显式空 body 形式
- [x] 让 backend plan 按 root kind 选择 `object-file` / `executable`
- [x] 让 toolchain plan 为 unit roots 选择 `bootstrap-native-assemble`
- [x] 移除遗留 `DBG-FALL:` stderr 调试输出
- [x] `build/verify_local.sh` 新增 compiler-module self-compile gate
- [x] fresh `bash build/verify_local.sh` 通过，确认 `verify-local=pass`

### Notes

- 这批不是宣称 nextPas 已经能把 compiler units “完整链接成可执行”，而是把当前真实 ownership
  诚实地推进到“能把 compiler units 编译成 object-file 并经过 native assemble”
- `np_diagnostics_sink` / `np_source_database` / `np_workspace_model` 现在都已在
  `backend-output-kind=object-file`、`toolchain-plan-family=bootstrap-native-assemble` 下进入
  fresh verify gate
- `array of const` 这一合法参数形态已补入 parser，并在 `TSemanticAnalyzer.GetParamSignature(...)`
  里补了 nil guard；`tests/parser/array_of_const_pass.pas` 已加入 parser smoke，fresh verify 通过

## Addendum: 2026-05-23 HIR LLVM alloca hoisting safety

### Goal

把 HIR LLVM emitter 的 SSA 命名从匿名数值寄存器切到稳定 named values，并让
`THIRBuilder.EnsureAlloca(...)` 真正写入函数 entry block。这样晚到的 slot materialization
不再受 LLVM 文本 IR 顺序编号约束，也不会再依赖 emitter 按 `ResultId` 重新排序 block。

- 修改 `compiler/ir/np_hir_builder.pas`：`EnsureAlloca(...)` 在函数上下文中直接调用
  `FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)`，把 fallback alloca hoist 到 entry block
- 修改 `compiler/ir/np_hir_llvm_emitter.pas`：新增 `ValueRef(...)`，把 raw `%` + 数值引用统一发射为
  `%vN` named SSA values（覆盖定义、使用与 function params）
- 去掉 `EmitFunction(...)` 中按首个 `ResultId` 重新排序 block 的 hack，恢复按 HIR block 原始顺序发射
- 新增 `tests/hir/test_hir_late_alloca_hoist.pas` focused probe：构造“非 entry block 首次 materialize
  late slot” 的 synthetic HIR，断言生成 IR 既能过 `opt` 解析，又把 `alloca` 放在 entry block
- 扩展 `build/verify_local.sh`：正式纳入上述 focused probe，并冻结 `%vN` named-value evidence

### Status

Completed

### Completed Steps

- [x] `THIRBuilder.EnsureAlloca(...)` 改为 entry-block insertion
- [x] `THIRLlvmEmitter` 新增 `ValueRef(...)` 并切换 raw numeric SSA refs 到 `%vN`
- [x] `EmitFunction(...)` 改为按 HIR block 原始顺序发射，不再按 `ResultId` 排序
- [x] 新增 `tests/hir/test_hir_late_alloca_hoist.pas`
- [x] `build/verify_local.sh` 纳入 focused hoist gate，并用 `opt -disable-output` 验证 IR
- [x] fresh `bash build/verify_local.sh` 通过，确认 LLVM/host 路径无回退

### Notes

- 这批不是扩 LLVM 语义面，而是把既有 HIR path 的文本 IR 稳定性补齐，为后续更多 late alloca /
  synthetic slot 场景扫掉结构性约束
- `%arralloc.*`、`%abs.*`、`%is.*`、`%callstr.*` 这类已有显式命名 helper SSA 名继续保留；
  变化的是原先裸 `%1/%2/...` 的 result / operand / param 引用现在统一成为 `%vN`

## Addendum: 2026-05-17 Sema Const Identifier Resolution — Halt(MyConst) → exit(42)

### Goal

把 sema 折叠器从"只折常量字面量表达式"推进到"能解析 const 声明的标识符引用"。
上一批次让 `Halt(40 + 2)` 折叠为 42；这一批让 `const FortyTwo = 42; begin Halt(FortyTwo); end.`
也能正确退出 42。

- 扩展 `compiler/sema/np_semantic_model.pas` 加 `TSemanticConstValue` record 与
  `FConstValues: array of TSemanticConstValue`；新增 `AddConstValue(name, value)` 与
  `LookupConstValue(name, out value): Boolean`
- 扩展 `EvaluateIntegerConstant` 加 `gnkIdentifier` 分支：从 `FModel.LookupConstValue`
  查表，命中即返回常量值
- 改造 `ProcessConstSection`：每个 `gnkConstDecl` 子节点尝试 `EvaluateIntegerConstant`
  折叠值，命中即 `AddConstValue(name, value)` 注册到表
- 新增 `examples/smoke/halt_const.pas`：`program HaltConst; const FortyTwo = 42; begin Halt(FortyTwo); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-const-program` gate：用真 opt/llc/ld 编译
  halt_const.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema model 加 `TSemanticConstValue` 与 `FConstValues` 数组，constructor 初始化
- [x] sema model 加 `AddConstValue` / `LookupConstValue`（大小写不敏感名称比对，重复 name 覆盖旧值）
- [x] `EvaluateIntegerConstant` 新增 `gnkIdentifier` case，从 `LookupConstValue` 查表
- [x] `ProcessConstSection` 遍历每个 `gnkConstDecl` 子节点尝试折叠并 `AddConstValue` 注册
- [x] 新增 `examples/smoke/halt_const.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_CONST_PROGRAM_OUTPUT` /
      `LLVM_HALT_CONST_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-const-program` gate，
      success envelope 加 `llvmHaltConstProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision                                                     | Rationale                                                                                                                                           |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| const 表用大小写不敏感名称比对                               | Pascal 标识符传统大小写不敏感；与 `WalkHaltCalls` 的 `SameText('Halt')` 一致                                                                        |
| ProcessConstSection 折叠失败时只跳过 AddConstValue，不报诊断 | const 声明可能是非整数（字符串、记录），折叠失败不代表错；当前批次只关心整数常量；非整数 const 引用在 EvaluateIntegerConstant 自动失败回到 fallback |
| const 表挂在 `TSemanticModel` 而不是 `TSemanticAnalyzer`     | 与现有 `FSymbols` / `FTypes` 等 model-owned 数据保持一致；分析器只负责填充，model 持有真实数据                                                      |
| 重复名称覆盖而不是报错                                       | 当前 sema 还没有完整 redeclaration 检查；先静默覆盖避免假诊断，等真正的 symbol-redecl 检查批次再加                                                  |

### Notes

- 这是 sema 第一次跨节点引用解析：表达式折叠器从纯 AST-recursive 升级到 model-aware
- 当前 const 表只支持整数类型；string / 浮点 / 数组 const 值仍属未来批次
- `verify-local` 现在含四条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）、
  `llvmHaltConstProgram`（exit 42 from const FortyTwo = 42）

## Addendum: 2026-05-17 Sema Integer Constant Folding — Halt(40 + 2) → exit(42)

### Goal

把 nextPas 的 sema 从"只接受 Halt 直接字面量参数"推进到"折叠任意整数常量表达式"。
上一批次 `Halt(N)` 走 LLVM 退出 N，但 `Halt(40 + 2)` 会因 sema 仅匹配 `gnkIntegerLiteral`
直接子节点而退化到默认 0。这一批让 sema 在编译期完成整数常量折叠，
让 `Halt(N op M)` / `Halt(-N)` 等表达式也能正确决定退出码。

- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `EvaluateIntegerConstant(Node, out Value)`：
  递归折叠 `gnkIntegerLiteral` / `gnkUnaryExpression`(+/-) /
  `gnkBinaryExpression`(+/-/\*/div/mod)；除零返回 false；非整数节点或未识别 op 返回 false
- 改造 `WalkHaltCalls`：把"只匹配 `gnkIntegerLiteral`"换成 `EvaluateIntegerConstant`，
  折叠成功才发射 `halt-call` HIR 节点；失败时 operand 默认 `0`
- 新增 `examples/smoke/halt_expr.pas`：`program HaltExpr; begin Halt(40 + 2); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-expr-program` gate：用真 opt/llc/ld 编译
  halt_expr.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema 加 `EvaluateIntegerConstant` 折叠器（unary +/-、binary +/-/\*/div/mod、字面量）
- [x] `WalkHaltCalls` 改用 `EvaluateIntegerConstant` 替代直接 `gnkIntegerLiteral` 匹配
- [x] 新增 `examples/smoke/halt_expr.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_EXPR_PROGRAM_OUTPUT` /
      `LLVM_HALT_EXPR_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-expr-program` gate，
      success envelope 加 `llvmHaltExprProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision                             | Rationale                                                                                                                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 折叠器在 sema 层而非 MIR lowerer     | 折叠产生的整数常量需要进 HIR 的 `Operand` 字段以传给 MIR；MIR lowerer 只读 HIR 操作数；当前没有 typed value system，sema 是唯一能消费 AST 表达式形态的层                                                     |
| 用 `Int64` 内部计算                  | 避免 Pascal 整数子集分歧；Halt 退出码最终被截到 8 位（POSIX `_exit` 语义），但中间表达式可以触及 64 位范围                                                                                                   |
| 折叠失败默认 0，不发诊断             | 当前批次专注 Halt 表达式折叠路径；非常量表达式（变量、未支持运算）应进入下一批的真实 codegen，不该在此批次假装"已支持但 silently 错"。先静默 fallback、保留 0 行为，等 typed expression codegen 落地再加诊断 |
| 折叠器涵盖 +/-/\*/div/mod 而非仅 +/- | 这五个 op 是 Pascal 整数常量表达式核心子集；新增成本 ~每 op 5 行，但避免下次再来一批 "MUL 折叠"                                                                                                              |

### Notes

- 这是 sema 第一次具备**编译期求值**能力。不是完整 const-eval 系统，但已经能把
  `Halt(40 + 2)` 这类整数常量表达式正确折叠到运行时退出码
- 当前 emitter 仍只看 MIR `halt` op 的 operand 字段；变量、函数返回值、
  字符串等非常量参数仍属下一批次（需要真实 LLVM 表达式 codegen）
- `verify-local` 现在含三条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）

## Addendum: 2026-05-17 MIR-driven LLVM Codegen — Halt(N) → exit(N)

### Goal

把 nextPas 的 LLVM 路径从"无论源代码写什么都 exit 0"推进到"程序退出码由源代码决定"。
这是首个 **MIR 真实决定运行时行为** 的批次：MIR operand 不再恒为空字符串，
LLVM emitter 不再发射固定 empty shell。

- 扩展 `compiler/ir/np_mir_model.pas` 的 `TMirOperation` 加 `Operand: string` 字段，
  `AddOperation` 多一个 operand 参数，新增 `OperationAt(Index)` 让 emitter 能读取 ops
- 扩展 `compiler/sema/np_semantic_model.pas` 的 `TTypedHirNode` 同样加 `Operand: string`
  字段，`AddTypedHirNode` 多一个 operand 参数
- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `WalkHaltCalls` + `SeedHaltCalls`：
  遍历 program body 找 `gnkProcedureCallStatement` 文本为 `Halt`，捕获第一个
  `gnkIntegerLiteral` 子节点作为 operand，发射 `halt-call` HIR 节点
- 扩展 `TMirLowerer.MirKindForTypedHirNode` 把 `halt-call` HIR 翻译为 `halt` MIR op，
  operand 透传
- 扩展 `compiler/backend/np_llvm_emitter.pas`：扫 MIR ops 找 `halt` 提取 operand（默认 0），
  发射 `_start` 时把 syscall arg 写为该 operand 值；emitter 不再写死 `xorl %edi, %edi`
- 新增 `examples/smoke/halt_42.pas` fixture：`program HaltFortyTwo; begin Halt(42); end.`
- 修复 `tests/toolchain/toolchain_contract_smoke.pas` 的 `MirModel.AddOperation` 调用
  对齐新签名
- 新增 `build/verify_local.sh` 的 `llvm-halt-program` gate：用真 opt/llc/ld 编译
  halt_42.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] `TMirOperation` + `AddOperation` 加 Operand 字段，新增 `OperationAt(Index)` accessor
- [x] `TTypedHirNode` + `AddTypedHirNode` 加 Operand 字段；6 处现有调用点全部跟进
- [x] `TSemanticAnalyzer` 新增 `WalkHaltCalls` + `SeedHaltCalls`，挂进 `Analyze`
      末尾在 `SeedRuntimeContracts` 之后
- [x] `TMirLowerer.MirKindForTypedHirNode` 加 `halt-call -> halt` 分支；
      lowerer 主循环把 HIR operand 透传给 MIR `AddOperation`
- [x] `TLlvmEmitter.ResolveExitCode` 扫 MIR ops 找 `halt`，从 operand 解析整数
      （Val 解析失败默认 0）；`EmitToFile` 发射 syscall arg 为该值
- [x] 新增 `examples/smoke/halt_42.pas`
- [x] 修复 `tests/toolchain/toolchain_contract_smoke.pas:536` 的 `AddOperation` 4 参签名
- [x] `build/verify_local.sh` 加 `LLVM_HALT_PROGRAM_OUTPUT` / `LLVM_HALT_PROGRAM_OUT_DIR`
      临时文件，新增 `llvm-halt-program` gate（IR 含 marker、可执行 exit 42），
      success envelope 加 `llvmHaltProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision                                                                   | Rationale                                                                                                                                            |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 用 `string` 字段载 operand，而不是引入 typed `TMirValue` 联合体            | 当前只需透传字面量给 emitter；引入 value system 会牵动 MIR/HIR/sema/emitter 四层，扩展面太大；string 可后续被 typed value 替换而不破坏调用接口       |
| `halt-call` HIR 节点直接挂在 typed-hir 序列尾部，不进 block-structured CFG | 当前 MIR 仍是平铺 op 序列、单 entry block；引入 control-flow 应单独批次                                                                              |
| emitter `ResolveExitCode` 解析失败默认 0，不报 diagnostic                  | sema 已经只在捕获到 `gnkIntegerLiteral` 时才发 operand，emitter 收到非数字 operand 是内部 bug 不是用户错误；先静默 fallback，等 typed value 再加诊断 |
| `WalkHaltCalls` 做大小写不敏感比对（`SameText`）                           | Pascal 标识符传统大小写不敏感；与 `gnkProcedureCallStatement.Text` 保留原 lexeme 一致                                                                |

### Notes

- 这是 MIR 第一次真实决定运行时行为：之前 MIR 即使存在也只是路径占位符，
  `verify-local` 里 empty-program 和 halt-program 现在是两条**结果不同**的真实测试
- 当前 emitter 仍只生成 `_start` + 单条 syscall；多条 `Halt(N)` 会让最后一条赢，
  control-flow / function call / multiple statements 仍属下一批次
- `halt_42.pas` 通过 LLVM binding 编译运行 exit 42，但默认 binding (gnu) 走宿主 FPC，
  那条路径仍由宿主决定行为；这是预期的，因为只有 LLVM 路径走 nextPas 自有 codegen
- 这一批不替换历史 addendum；下一批次自然入口是把 MIR 操作扩到包含
  整数 const / 二元运算 / 简单条件，让 `Halt(2 + 3)` 类表达式也能正确 lower

## Addendum: 2026-05-17 LLVM Backend First Codegen — Empty Program End-to-end

### Goal

把 nextPas 从“所有编译成功都是宿主 FPC 干的”推进到“nextPas 自己拥有 codegen ownership 的最小真实链路”。
之前 `compiler/ir/np_mir_model.pas` 是字符串占位符、`compiler/backend/np_backend_plan.pas` 90% 在算路径
0% 生成代码，所有 `.s` 都来自 `host-fpc-emit-asm`。这一批让 nextPas 自己写出 `.ll` 文件并由 LLVM
工具链产出真实可执行：

- 新增 `compiler/backend/np_llvm_emitter.pas`：从 `TMirModel` + `TTargetFactsView` 发射文本 LLVM IR
  到磁盘；当前批次只发射最小 empty-program shell（`define void @_start` + inline syscall exit(0)），
  绕开缺失的 distribution runtime libc，让 nextPas 真正拥有 entry point
- 让 `TBackendPlanner.Plan` 在 `BackendFamily='llvm'` 时调用 emitter 真实写 `.ll`，
  而不是只注册 artifact 路径
- 把 `compiler/toolchain/np_toolchain_plan.pas` 的 `PlanLlvmIrOptObjectLink` link step 从硬编码的
  `ExecutableSet.Lld` 切到 `LinkerProfile.DriverCandidates`，使 LLVM binding 复用 linker profile
- 把 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml` 的 linker 从 `lld-elf` 切到 `gnu-ld`，
  不引入新依赖（系统未安装 `ld.lld`，但 `ld` 与 native binding 已在用）
- 默认 backend 不变（`bootstrap-native-assemble-link`），LLVM 路径通过
  `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 显式选择

### Status

Completed

### Completed Steps

- [x] 摸清现有 LLVM skeleton：`PlanLlvmIrOptObjectLink`、`PrepareLlvmContract`、`TBackendPlan`
      LLVM 字段已就位；缺口是 (a) 没有 IR emitter，(b) link step 写死 `ld.lld`，(c) binding 配置
      指向未安装的 `ld.lld`
- [x] 手工验证最小 LLVM 链路（`opt → llc → ld` + 自写 `_start` syscall exit(0)）能产出 exit 0
      可执行，确认 IR 模板可行
- [x] 新增 `compiler/backend/np_llvm_emitter.pas`，提供 `TLlvmEmitter.EmitToFile`，按
      target triple/data layout 发射 IR header，再发射 empty-program shell
- [x] 修改 `compiler/backend/np_backend_plan.pas`：在 `BackendFamily='llvm'` 分支调用
      `Emitter.EmitToFile`，`ForceDirectories` 后再发射；失败时 `MarkFailure`
- [x] 修改 `compiler/toolchain/np_toolchain_plan.pas:1394` link step：从 `ExecutableSet.Lld`
      改为 `FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld')`
- [x] 修改 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml`：linker 从 `lld-elf`
      切到 `gnu-ld`
- [x] 修改 `build/verify_local.sh` 的现有 `llvm-binding-smoke` gate：fake stub 从 `ld.lld`
      改名为 `ld`，`linker-profile-id` 断言从 `lld-elf` 改为 `gnu-ld`
- [x] 在 `build/verify_local.sh` 新增 `llvm-empty-program` gate：用真 `opt`/`llc`/`ld` 编译
      `examples/smoke/hello.pas`，断言 `toolchain-plan-family=llvm-ir-opt-llc-link`、
      `backend-artifact-count=4`、`.ll` 文件存在并含 `@_start`、可执行 exit 0
- [x] 把 `llvmBindingSmoke`/`llvmEmptyProgram` 加进 verify-local success envelope
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision                                                                                     | Rationale                                                                                                                                                      |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM linker 切到系统 `ld`（gnu-ld），不装 `ld.lld`                                           | 与 native binding 对称、零新依赖；后续如果引入 `ld.lld` 可独立切回                                                                                             |
| Empty program 自写 `_start` + inline syscall exit(0)，不依赖 libc/\_start                    | 当前 distribution runtime SDK 缺 `lib/nextpas/runtime/linux-x86_64/libc.so`；自写 `_start` 顺带让 nextPas 拥有 entry point ownership，与"独立 RTL"长期方向一致 |
| 默认 backend 保持 `bootstrap-native-assemble-link`，LLVM 通过 `--toolchain-binding` 显式选择 | 现有 40+ verify gate 全围绕 native 默认路径；一次性切默认会大面积翻车，不该和 codegen 引入混在一批                                                             |
| 这一批 emitter 只发射 empty-program shell，不消费 MIR operations                             | 当前 MIR 是字符串占位符（`Kind: string` + `DisplayName`），还没有 value semantics；先把"自有 codegen 链路"打通，再分批扩 IR 表达力                             |

### Notes

- 这是 nextPas 第一次真实生成代码：之前任何 `.s` 都来自 `host-fpc-emit-asm`，现在 `.ll` 由
  `TLlvmEmitter` 自己写
- 当前 LLVM 路径的真实功能只覆盖 `program X; begin end.` 这一种程序：任何带 `WriteLn`、表达式、
  类型、调用的程序都会发射同样的 empty shell（IR 中只有 `_start`+syscall），运行时仍 exit 0
  但实际语义被丢失。下一批次需要在 emitter 中开始消费 MIR operation
- LLVM 路径仍不能 self-host：MIR 还没有 value/type/control-flow，所以 nextPas 自己的 compiler module
  不能用 LLVM backend 编译；这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 的判断一致
- `compiler-roadmap.md` 第 5 段 “Target / Cross / LLVM / C Interop” 的 LLVM 部分从“skeleton 已就位”
  正式进入“最小真实闭环已就位”
- 这一批不替换历史 addendum，也不动 `bootstrap-native-assemble-link` 路径

## Addendum: 2026-05-17 Repo Hygiene + Classes RTL Source-of-truth Convergence

### Goal

把这次会话前发现的两类工作树级问题一次收口，并把下一批次入口明确转向 RTL Classes 实现，
而不是继续在 verify gate 上叠 addendum：

- 工作树污染：`core.997688`（22MB FPC core dump）、四个空 `crash_*.txt`、`ppas.sh`、
  `tools/stage0/nextpas_*.s`（5 个 ~250KB 残留汇编中间产物）必须从 untracked 状态清掉，
  并在 `.gitignore` 中通过 `core.*` / `crash_*.txt` / `ppas.sh` / `tools/stage0/*.s`
  正式 ignore，避免下一次崩溃或中断重新污染
- RTL Classes 必须收敛到与 SysUtils 一致的 source-of-truth 模式：
  `rtl/core/classes/np_classes.pas` 是唯一源，checked-in `Classes.pas` / `Classes.o` /
  `Classes.ppu` 一律由 build 派生并通过 `.gitignore` 排除；删掉之前与 `np_classes.pas`
  字节级一致的 `Classes.pas` 重复源
- 这一批不引入新代码、不改公开 line-based output / `command-envelope=<json>` 契约；
  fresh `bash build/verify_local.sh` 必须继续全绿

### Status

Completed

### Completed Steps

- [x] 删除工作树污染文件：`core.997688`、`crash_err.txt`、`crash_out.txt`、
      `crash_output.txt`、`crash_stdout.txt`、`ppas.sh`、
      `tools/stage0/nextpas_command_envelope.s`、`tools/stage0/nextpas_json_helpers.s`、
      `tools/stage0/nextpas_projection_json.s`、`tools/stage0/nextpas_projection_text.s`、
      `tools/stage0/nextpas_projection_types.s`
- [x] 删除 `rtl/core/classes/Classes.pas`（与 `np_classes.pas` 字节级一致的重复源），
      并清理其残留 `Classes.o` / `Classes.ppu`
- [x] 扩展 `.gitignore`，新增
      `rtl/core/classes/Classes.pas`、`rtl/core/classes/Classes.o`、
      `rtl/core/classes/Classes.ppu`、`core.*`、`crash_*.txt`、`ppas.sh`、
      `tools/stage0/*.s`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision                                                                   | Rationale                                                                                                  |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Classes 收敛到 `np_classes.pas` 唯一源 + ignore 派生 `Classes.{pas,o,ppu}` | 与 `rtl/core/sysutils/` 已建立的模式一致；checked-in 重复源会让 source-of-truth 漂移并误导下游 contributor |
| 工作树污染统一通过 `.gitignore` 模式封堵，不靠每次手动清理                 | FPC 崩溃 core dump、`ppas.sh` 中断脚本、`tools/stage0/*.s` 汇编中间产物都是已知会复现的工件                |
| 这一批不动 `np_classes.pas` 内容，也不实现 Classes 容器                    | 先把 source-of-truth 边界定清楚，再进入 RTL Classes 实现批次；避免一次混入两个方向                         |

### Notes

- 下一批次入口正式转向 RTL Classes 实现：`np_classes.pas` 当前只暴露最小 `TFileStream`
  shape，离 compiler module 真正能 `uses Classes` 还差容器类（`TStringList`、`TList`）；
  这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 列出的 Stage2 阻塞项一致
- 这一批不替换历史 addendum，也不改架构规范；`docs/plans/2026-05-02-rtl-implementation-plan.md`
  仍然是 RTL 推进的 owning plan，本 addendum 只负责把仓库卫生与 source-of-truth 模式
  同步到 task_plan 顶层，避免下一轮恢复时再被这批工件分散注意力

## Addendum: 2026-04-29 Package Workflow Truth Skeleton

### Goal

把 package workflow 的第一批 shared truth 从文档语义推进到 compiler-owned 最小实体，同时继续
守住“只读 truth / 非执行 workflow / 不伪装完整 package manager”这条边界：

- 新增 `compiler/frontend/np_package_workflow.pas`，至少拥有
  `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
  `TPackageWorkflowTruth`
- 这批 truth 必须消费 `np_package_manifest.pas` 已有的 `TPackageManifestInfo`，不重新发明 parser
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 必须冻结
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`
- 文档与持续记录必须同步成当前 reality，并明确这批不做 registry、fetch、install、solver
  或 lockfile write

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 package workflow truth 的 RED contract，并 fresh 运行确认失败点正好落在
      `np_package_workflow` unit 尚未存在
- [x] 新增 `compiler/frontend/np_package_workflow.pas`，最小落地
      `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
      `TPackageWorkflowTruth`
- [x] 让 manifest truth 消费 `TPackageManifestInfo` 的 manifest/package/source-root 事实；
      让 lock/install truth 只暴露 canonical path/provenance，并继续保持 `deferred`
- [x] 同步回写 `docs/architecture/package-workflow-specification.md`、
      `docs/architecture/workspace-file-format-specification.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 package workflow contract 与
      整套 `verify-local=pass`

## Addendum: 2026-04-29 Minimal Query Symbols Surface

### Goal

把 developer tooling 里的第一条 semantic query surface 收成最小但真实的统一 `nextpas`
命令入口，同时继续守住“query / language service / build execution”的分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `query` family，至少支持
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `query symbols` 只负责只读 semantic query，不承担 LSP、open document overlay、
  incremental invalidation、references、rename 或 completion
- 当前 query 必须复用 compilation session 的 syntax / resolution / semantic truth，
  并显式投影 `analysis-source=compilation-session`
- `build/verify_local.sh` 必须新增 `nextpas query symbols` 的 success gate 与 bare
  `nextpas query` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批不执行 MIR、backend 或 toolchain

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace <repo>`
      与 bare `nextpas query` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `query` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `query` command parse/usage 与 `symbols`
      selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `query symbols` 复用 `ResolveWorkspaceModel(...)`、target facts 与
      `TCompilationSession`，只执行 syntax、unit resolution 与 semantic analysis
- [x] 新增最小 query projection，把 `query-kind`、`query-status`、`analysis-source`
      与 `query-result-count` 投影到 line-based output 和 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、`tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/language-service-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0QueryCheck`、
      `stage0QueryInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Stage0 Doctor Minimal Read-only Health Surface

### Goal

把 developer tooling 里下一条最小但真实的 health inspection surface 收成统一 `nextpas`
命令壳，同时继续守住“状态解析 / 健康诊断 / 环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `doctor` family，至少支持
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `doctor` 只负责只读 inspection，不承担 `env sync` / `env use` / `env bootstrap`
  这类环境修改
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实健康摘要通过
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count` 投影
- `build/verify_local.sh` 必须新增 `nextpas doctor` 的 success gate 与 bare
  `nextpas doctor` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 richer finding taxonomy /
  suggested action / `query` / package workflow 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas doctor --target linux-x86_64 --workspace <repo>` 与 bare
      `nextpas doctor` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `doctor` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `doctor` command parse/usage 与最小
      `doctor` selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `doctor` 复用现有 target/toolchain/distribution/runtime truth 与可选 workspace root，
      投影 `runtime-libc-present`、`environment-readiness`、`runtime-sdk-status`、
      `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`
- [x] 保持 `doctor` 为只读 health inspection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不健康”写进 doctor fields
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0DoctorCheck`、
      `stage0DoctorInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Doctor Result Contract Hardening

### Goal

把 `doctor` 从 aggregate health summary 继续加固成可被 CLI、CI 与 future IDE adapter
稳定消费的结构化 result contract，同时不把 health finding 误放进 compiler diagnostics sink：

- `build/verify_local.sh` 必须冻结 `doctor-workspace-status` 与
  `doctor-toolchain-binding-status`
- runtime SDK 缺失必须输出代表性 finding：
  `doctor-finding-code=doctor.runtime-sdk-missing` 与
  `doctor-finding-severity=warning`
- `command-envelope=<json>.result.doctorFindings[]` 必须同步保留
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `doctor-workspace-status`
- [x] 在 `tools/stage0/nextpas.pas` 引入最小 `TDoctorFinding` 与扩展后的
      `TDoctorProjectionContext`，保留 first finding line projection 与 envelope array
- [x] 继续保持 `doctor` 为只读 inspection：当前 runtime SDK 缺失仍返回
      `status=success` / `result=success`，健康问题写进 `doctorFindings`
- [x] 同步回写 `docs/architecture/diagnostics-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认结构化 finding contract 与
      `verify-local=pass`

## Addendum: 2026-04-29 Richer Env Status Readiness Evidence

### Goal

把 `env status` 的只读 state projection 从路径与 runtime 状态继续加固到可供
`doctor` 与 future `env sync` 复用的 readiness evidence：

- `environment-readiness` 保留为兼容字段，但与新增 `environment-status` 使用同一
  derived readiness vocabulary
- `runtime-sdk-status` 继续表达 runtime SDK 是否 ready / missing
- 新增 `toolchain-binding-status` 与 `distribution-status`
- `command-envelope=<json>.result` 必须同步保留 `environmentStatus`、
  `runtimeSdkStatus`、`toolchainBindingStatus` 与 `distributionStatus`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `environment-status`
- [x] 扩展 `tools/stage0/nextpas.pas` 的 `TEnvironmentProjectionContext`，
      从既有 target/binding/distribution/runtime truth 推导 environment、runtime SDK、
      binding 与 distribution readiness
- [x] 保持 `env status` 为 execution-successful 的只读 projection：当前 runtime SDK /
      distribution 仍不完整时继续返回 `status=success` / `result=success`
- [x] 让 `doctor` 复用同一份 `toolchain-binding-status`，避免 doctor/env 各自推导
      binding readiness
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 readiness evidence 与
      `verify-local=pass`

## Addendum: 2026-04-26 Stage0 Env Status Read-only Projection

### Goal

把 developer tooling 里下一条最小但真实的 environment surface 收成统一 `nextpas` 命令壳，
但继续守住“状态解析”和“健康诊断/环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `env` family，至少支持
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]`
- `env status` 只负责解析 target / binding / distribution / runtime state，不承担
  `doctor` 诊断，也不提前引入 `env use` / `env sync` / `env bootstrap`
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实 readiness 继续通过
  `environment-readiness`、`runtime-sdk-status` 与 `runtime-libc-present` 投影
- `build/verify_local.sh` 必须新增 `nextpas env status` 的 success gate 与
  bare `nextpas env` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 mutation verbs / `doctor` /
  `query` 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `nextpas env status --target linux-x86_64` 与
      bare `nextpas env` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `env` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `env` command parse/usage 与最小
      `status` selector，支持可选 `--toolchain-binding <id>`
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 target/toolchain/distribution/runtime truth，
      投影 `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
      `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`
- [x] 保持 `env status` 为只读 state projection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不完整”写进 readiness fields
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0EnvStatusCheck`、
      `stage0EnvInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Workspace Model Shared Truth Convergence

asd

### Goal

把当前已经存在但仍散落在 `tools/stage0/nextpas.pas` driver helper 与 session 选项字段里的
workspace/package/artifact discovery，收口成 compiler-owned shared model，同时保持现有
公开 line-based output、`command-envelope=<json>`、resolver precedence 与 early-failure
behavior 不漂移：

- 新增最小 `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
  Pascal 实体，承接当前真实存在的 workspace root、package refs、source roots、
  artifact root、output dir 与 host-fpc cache root truth
- `TCompilationSession` 正式拥有这份 model，不再只持有一组散落的 workspace/build 字段
- `tools/stage0/nextpas.pas` 只保留 CLI override 与 orchestration，不再自己维护
  workspace discovery、package roots 与 artifact placement 规则
- `build/verify_local.sh` 与 focused smoke 必须继续全绿，证明这次是 ownership convergence，
  不是 surface drift

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 shared workspace model 的 RED contract，覆盖 explicit workspace、
      nearest package manifest 与 workspace member 三条代表路径
- [x] 新增 `compiler/frontend/np_workspace_model.pas`，最小落地
      `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
- [x] 让 `np_package_manifest.pas` 提供 workspace model 所需的 typed inputs，
      保留 parser 职责但不再承担最终 ownership
- [x] 让 `TCompilationSession` 正式拥有 workspace model，并让 session getters /
      resolver roots 从 model 读取，而不是从 driver 拼装字段读取
- [x] 把 `tools/stage0/nextpas.pas` 的 workspace/package/artifact discovery
      切到 shared model，保持 line/envelope/early-failure 契约不变
- [x] 运行 fresh `bash build/verify_local.sh`，并同步回写文档、路线图与持续记录

## Addendum: 2026-04-05 Toolchain Plan Runner Execution Contract

### Goal

把 `Batch 16` / `Batch 17` 已冻结的 typed `TToolchainPlan` 从“可投影对象”推进到
“可真实执行 contract”，但继续守住当前 backend truth 的边界：

- 新增通用 runner，按 step 顺序真实执行 ready `TToolchainPlan`
- runner 必须负责当前已落地的 sidecar kinds：
  `response-file`、`resource-list-script`、`archive-command-script`
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  必须真实执行 fake `as` + `ld` 的 `native-assemble-link` plan，
  验证 object/output 生成、response capture 与 `delete-on-success` cleanup
- 仍不把 `stage0 build` 伪装成已经切到 native assembler/linker production path；
  `compiler/backend/np_backend_plan.pas` 还没有正式拥有 assembly/object
  intermediate artifact truth

### Status

Completed

### Completed Steps

- [x] 审查 `compiler/backend/np_backend_plan.pas`、
      `compiler/toolchain/np_toolchain_plan.pas` 与
      `tests/toolchain/toolchain_contract_smoke.pas`，确认当前最小真实推进点是
      generic runner，而不是强行让 `PlanFromBackend` 改选 `native-assemble-link`
- [x] 新增 `compiler/toolchain/np_toolchain_runner.pas`，提供
      `ExecuteToolchainPlan(...)` 与 per-step `TToolchainRunResult`
- [x] 在 `compiler/toolchain/np_toolchain_plan.pas` 暴露 `StepAt(...)`，
      让 runner / contract smoke 能读取 typed step truth
- [x] 把 `tests/toolchain/toolchain_contract_smoke.pas` 与
      `build/verify_local.sh` 扩成 fake `as` / `ld` 的真实 multi-step execution gate，
      覆盖 response sidecar materialize、capture 与 delete-on-success cleanup
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `native-run-*` contract、
      `toolchainContractCheck=pass` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Host-compiler Runner Reuse + Tool Run Projection

### Goal

把刚落地的 generic `TToolchainPlan` runner 真正接回当前 one-step host-compiler
production path，避免 `stage0 build` 继续维护第二套手写 `TProcess` 执行路径：

- `tools/stage0/nextpas.pas` 不再手工 `ResolveCompilerExecutable + TProcess`
- 当前 host-compiler production path 必须复用 `compiler/toolchain/np_toolchain_runner.pas`
- session / CLI / envelope 需要显式投影真实 execution result：
  `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
- fresh `bash build/verify_local.sh` 必须继续全绿，证明 runner reuse 没有破坏现有
  tool invocation plan、status event、build trace 与 failure diagnostic contract

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `stage0-smoke`、`semantic-smoke` 与
      `toolchain-failure` 写出 `tool-run-*` RED gate，并 fresh 运行确认失败点正好落在
      新增 execution-result fields 缺失
- [x] 在 `compiler/frontend/np_compilation_session.pas` 增加 generic runner 执行入口，
      让 session 正式拥有 `tool run` status / step count / primary-step status
- [x] 把 `tools/stage0/nextpas.pas` 的 host-compiler production path 切到
      `Session.ExecuteToolchain(...)`，去掉 hand-written execute path 与 duplicated state update
- [x] 把 `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
      接进 line-based projection 与 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `tool-run-*` contract 与
      整套 `verify-local=pass`

## Addendum: 2026-04-05 Backend Intermediate Artifact Truth + Logical Object Input

### Goal

把 backend 对 artifact truth 的 ownership 从“只有 final executable”推进到
`assembly-text/object-file/executable` 三类正式 artifacts，同时继续保持当前 production path
仍是 host-compiler single-step execution：

- `compiler/backend/np_backend_plan.pas` 必须正式拥有 target-aware `.s/.o/<program>`
  artifact truth，并把 `.s/.o` 收口到 `<artifact-root>/cache/backend/<target>/`
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  必须把这份 truth 投影成 `backend-artifact-count`、`backend-artifacts` 与 camelCase
  `backendArtifactCount`、`backendArtifacts`
- `compiler/toolchain/np_toolchain_plan.pas` 的 `logical-link-request.objectInputs`
  必须开始消费 backend-owned `object-file` artifact
- `PlanFromBackend` 仍不提前切到 `native-assemble-link`；下一批才处理合法 production-path
  selection

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `backend-artifact-count`、`backend-artifacts`、
      `logical-link-request.objectInputs` 与 camelCase envelope fields 写出 RED gate，
      并 fresh 运行确认失败点落在新 truth 缺失
- [x] 扩展 `compiler/backend/np_backend_plan.pas`，让 backend plan 固定持有
      `assembly-text`、`object-file` 与 `executable` 三类 artifacts，并补齐 helper /
      backend cache root 计算
- [x] 扩展 `compiler/frontend/np_compilation_session.pas` 与
      `tools/stage0/nextpas.pas`，把 backend artifact count / artifact JSON 接进 session、
      line-based projection 与 `command-envelope=<json>.result`
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让
      `logical-link-request.objectInputs` 开始引用 backend-owned `.o`
- [x] 同步回写架构规范、路线图与持续记录，并重新运行 fresh
      `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-04-05 Bootstrap-native Assemble/Link Production Path

### Goal

把已经落地的 backend-owned `assembly-text/object-file/executable` truth 真正接进当前
production path，让 `PlanFromBackend` 不再停留在 single-step host-compiler execution：

- `compiler/toolchain/np_toolchain_plan.pas` 必须合法选择
  `bootstrap-native-assemble-link`
- 当前真实执行面必须改成
  `host-fpc-emit-asm -> native-assemble -> native-link`
- 根程序与 source-backed units 的 `.s`、backend-owned `.o` 和确定性的
  `<program>_link.res` 必须进入 backend cache 并被真实消费
- `build/verify_local.sh`、README、架构规范、路线图与持续记录必须全部同步到这条新 reality
- 当批次结束时仍要诚实标注残余风险：later-step failure attribution 当时还是
  primary-step-centric（已在 2026-04-06 addendum 收口）

### Status

Completed

### Completed Steps

- [x] 先在 `compiler/toolchain/np_toolchain_plan.pas` 审核当前 backend artifact / profile /
      runner 前提，确认最小安全切换点已经具备，不再需要继续停在
      `host-compiler` single-step selection
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 `PlanFromBackend` 直接选择
      `PlanBootstrapNativeAssembleLink(...)`，并真实生成
      `host-fpc-emit-asm`、`native-assemble`、`native-link`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，收集 source-backed units 的额外
      assembly base names，使 explicit unit root / 多文件场景能够继续追加
      `native-assemble-<unit>` steps
- [x] 扩展 `build/verify_local.sh`，把
      `toolchain-plan-family=bootstrap-native-assemble-link`、
      `tool-invocation-count=3`、`tool-run-step-count=3`、
      `primary-tool-step-id=host-fpc-emit-asm`、
      `build-trace-ref=...-host-fpc-emit-asm` 与 extra native-assemble step contract
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `verify-local=pass` 与 `human-summary=local verification passed`

## Addendum: 2026-04-06 Later-step Failure Attribution for bootstrap-native assemble/link

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
从“真实执行但仍锚定 primary step”推进到“失败 metadata 跟随真实失败 step”：

- `native-assemble` / `native-link` failure 必须分别投影
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed`
- `compiler/frontend/np_compilation_session.pas` 必须把 failure diagnostic、build trace、
  status event 与 `buildTraceRef` 对齐到真实失败 step，而不是继续锚定
  `host-fpc-emit-asm`
- `tools/stage0/nextpas.pas` 必须优先使用 session 产出的真实 diagnostic code，
  不能再把 later-step failure 回退成 primary-tool failure mapping
- `build/verify_local.sh` 必须新增 fake `as` / `ld` 负路径 gate，并在 success envelope
  暴露 `assemblerFailureAttributionCheck` / `linkerFailureAttributionCheck`
- 文档与持续记录必须同步成当前 reality，并诚实注明这批收口时留下的
  success-path transcript gap；该缺口已在紧随其后的 transcript addendum 收口

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 写出 fake `as` / `ld` 的 RED gate，确认 later-step failure
      还没有按真实 step 归位
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 invocation steps 显式持有
      `toolRole/profileId/sysrootRef`，并为 `native-assemble` / `native-link` 写入 step context
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 tool status event、diagnostic、
      build trace 与 `buildTraceRef` 在 failure path 上跟随真实失败 step
- [x] 扩展 `tools/stage0/nextpas.pas`，让 runner failure 优先使用 `Session.LastDiagnosticCode`
      作为公开 failure kind
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `assembler-failure-attribution-check=pass`、
      `linker-failure-attribution-check=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-06 Stage0 Test Command Thin Wrapper

### Goal

把 developer tooling 里最容易失真的 `nextpas test` 入口收成最小真实公开面，但继续保持
`tests/run_all_tests.sh` / `tests/harness/runner.pas` 为 execution owner：

- `tools/stage0/nextpas.pas` 必须新增最小 `test` family，至少支持
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]`
- `stage0` 只负责参数解析、workspace root 选择与 thin wrapper；不重写 harness 分组、
  snapshot policy、fixture execution 或 bootstrap diagnostics
- `stage0` 调起 harness 时必须显式传入
  `NEXTPAS_STAGE0`、`NEXTPAS_WORKSPACE_ROOT`、`NEXTPAS_REPO_ROOT`
- `build/verify_local.sh` 必须新增 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass`、`smoke`
  五条 contract
- 文档与持续记录必须同步成当前 reality，并明确这批故意不提前把
  `doctor` / `env` / `query` 拉进来

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas`、`tests/run_all_tests.sh` 与
      `tests/harness/runner.pas`，确认这批最小真实推进点是 stage0 thin wrapper，而不是
      再发明一套 driver-owned test runner
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `test` command parse/usage，
      支持 `--list-groups`、`--filter <group>` 与可选 `--workspace <root>`，并把
      driver-side test parse failure 映射成 `selector=test`
- [x] 在 `tools/stage0/nextpas.pas` 中通过 `/usr/bin/env` thin-wrap
      `tests/run_all_tests.sh`，显式传入 `NEXTPAS_STAGE0`、
      `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT`
- [x] 扩展 `build/verify_local.sh`，把 `nextpas test` 的 list-groups、
      invalid-arguments、unknown-group、compiler-pass 与 smoke contract
      纳入正式 gate
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `nextpas test` gate 与
      整套 `verify-local=pass`

## Addendum: 2026-04-06 Success-path Toolchain Observability Transcript Hardening

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 success-path observability
从“仍有单步摘要残留”推进到“success/failure 都暴露完整 executed-step
transcript”：

- `compiler/toolchain/np_toolchain_runner.pas` 必须把 executed sidecar truth 收进正式
  transcript，至少暴露 `materialized` 与 `cleanupStatus`
- `compiler/frontend/np_compilation_session.pas` 必须让 success/failure 两侧都按全部
  executed steps 投影 `tool-status-events` 与 `buildTrace.steps[*]`
- `buildTraceRef` 必须统一升级成 plan-level
  `trace-<session-id>-toolchain-plan`，而不是继续随某个 step 变化
- `build/verify_local.sh` 必须冻结 success-path `tool-status-event-count=10`、
  later-step failure 的 plan-level trace ref，以及 `native-run-transcript` 的
  sidecar cleanup truth
- 文档与持续记录必须同步成当前 reality，把“success path 仍是单步摘要”的旧说法
  全部清掉

### Status

Completed

### Completed Steps

- [x] 扩展 `compiler/toolchain/np_toolchain_runner.pas`，把 executed sidecar truth 收进
      `TToolchainExecutedStep`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 success/failure 两侧都按全部
      executed steps 投影 `tool-status-events` / `buildTrace.steps[*]`，并把
      `buildTraceRef` 升级成 plan-level locator
- [x] 扩展 `tests/toolchain/toolchain_contract_smoke.pas`，新增
      `native-run-transcript=<json>` 输出，冻结 sidecar execution truth
- [x] 扩展 `build/verify_local.sh`，把 success-path transcript、plan-level trace ref、
      later-step failure transcript 与 `native-run-transcript` sidecar cleanup truth
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`toolchainFailureCheck=pass`、
      `assemblerFailureAttributionCheck=pass`、`linkerFailureAttributionCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Clear/Capture Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection ownership 收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `ClearSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段清理逻辑
- `CaptureSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段复制逻辑
- `ClearBuildCommandContext(...)` / `CaptureBuildCommandContext(...)` 也应对齐到同样的 helper
  形状，避免 clear/capture 路径继续半收口半内联
- fresh `verify_local` 必须继续全绿，证明这次只是 clear/capture helper convergence，
  不是行为或契约漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `ClearBuildCommandContext(...)`、
      `ClearSessionContext(...)`、`CaptureBuildCommandContext(...)`、
      `CaptureSessionContext(...)` 的剩余大块字段搬运，确认最小安全边界是按现有
      build/session/diagnostics/syntax/resolution/semantic/mir/backend/toolchain record
      抽 helper，而不是改输出 surface
- [x] 新增按 record 分组的 clear helper 与 capture helper，并让上述四个入口统一调 helper，
      保持字段来源、更新时机和 pre-session/session-owned 边界不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection 实现收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `BuildCommandEnvelopeJson(...)` 不应继续内联维护一整段分组字段拼接逻辑
- `PrintSessionProjection(...)` 不应继续内联维护按 group 展开的 line-based projection 细节
- fresh `verify_local` 必须继续全绿，证明这次只是 helper convergence，不是字段顺序、
  启停条件或 pre-session/session-owned 边界漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `BuildCommandEnvelopeJson(...)` /
      `PrintSessionProjection(...)` 的剩余内联 projection 逻辑，确认最小安全边界是抽出
      JSON helper 与 print helper，而不是继续改公开字段
- [x] 新增按 build/session/syntax/resolution/semantic/mir/backend/toolchain 分组的 JSON helper，
      并新增 session identity / diagnostics / syntax / resolution / semantic / MIR /
      backend / toolchain / diagnostics detail / build trace / lifecycle 的 print helper，
      再把 `BuildCommandEnvelopeJson(...)` 与 `PrintSessionProjection(...)` 改成统一调 helper
- [x] 核对 helper 化后的字段顺序与启停条件，特别确认
      `diagnosticCount` / `diagnosticErrorCount` / `diagnosticWarningCount` /
      `diagnosticsPolicy` 仍位于 `sessionLifetime` / `unitLifetime` / `stageLifetime` 之前
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Owner Context Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection state 收口到一致的 owned shape，
但仍不改公开 line-based output / `command-envelope=<json>` 契约：

- 剩余的 `ActiveSession*`、`ActiveSyntax*`、`ActiveResolution*`、
  `ActiveSemantic*`、`ActiveMir*`、`ActiveBackend*` 不应继续散落成平铺全局
- `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 应统一走分组 record
- fresh `verify_local` 必须继续全绿，证明这次只是 owner-context convergence，
  不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中剩余 session/syntax/resolution/semantic/mir/backend
      平铺 `Active*` 状态，确认最小安全边界是按 projection 分组收口，而不是再改输出 helper
- [x] 引入 `TSessionProjectionContext`、`TSyntaxProjectionContext`、
      `TResolutionProjectionContext`、`TSemanticProjectionContext`、
      `TMirProjectionContext`、`TBackendProjectionContext`，并同步替换
      `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
      `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 的消费点
- [x] 用搜索确认 `tools/stage0/nextpas.pas` 中已不再残留这批旧
      `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
      `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 平铺字段
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Convergence-first Verification Hygiene + Build-context Compaction

### Goal

把当前 rolling window 的优先级继续收回到“已落地路径的收敛质量”，而不是继续向外扩 richer
toolchain 表面：

- `verify_local` 不能再让 toolchain contract smoke 的二进制 / `.o` 落回源码树
- `harness` bootstrap failure 不能再吞掉关键回放线索
- `stage0` / `CompilationSession` 共享的 build truth 要继续从散落字段收口到更小的 owned shape
- 文档、路线图和持续记录必须同步这条 convergence-first 取向

### Status

Completed

### Completed Steps

- [x] 把 `build/verify_local.sh` 的 toolchain contract smoke 改成编译到临时 `mktemp -d`
      build dir，并显式断言源码树里不存在
      `tests/toolchain/toolchain_contract_smoke` 与
      `tests/toolchain/toolchain_contract_smoke.o`
- [x] 让 `tests/run_all_tests.sh` 在 stage0 bootstrap failure 时稳定投影
      `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并在 stderr 文件存在内容时回显原始 evidence
- [x] 在 `tools/stage0/nextpas.pas` 用 `TBuildCommandContext` 收拢 command-level build truth，
      并在 `compiler/frontend/np_compilation_session.pas` 用 `TBuildContext` 收拢 session-owned build context
- [x] 回写 `build/README.md`、`tests/harness/README.md`、
      `docs/architecture/test-harness-specification.md`、
      `docs/architecture/stage0-driver-specification.md`、`tools/stage0/README.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 运行 fresh `bash build/verify_local.sh`，确认
      `toolchainContractCheck=pass`、`harnessBootstrapDiagnosticsCheck=pass` 与整套
      `verify-local` 继续全绿

## Addendum: 2026-04-02 Stage0 Projection Context Compaction Closure

### Goal

把上一轮已经开始的 `stage0` 内部状态收口继续做完，但只限于实现内部，不改公开
line-based output / `command-envelope=<json>` 契约：

- `tools/stage0/nextpas.pas` 不应再在 projection record 已落地后，继续混用残留的
  `ActiveDiagnostic*` / `ActiveToolchain*` 平铺全局
- `PrintSessionProjection(...)` 必须和 `BuildCommandEnvelopeJson(...)`、
  `ClearSessionContext(...)`、`CaptureSessionContext(...)` 一样，统一走 owned context
- fresh `verify_local` 必须继续全绿，证明这次只是内部 compaction，不是行为漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 diagnostics/toolchain projection 的剩余旧引用，
      确认遗留点集中在 `PrintSessionProjection(...)`
- [x] 把 stdout/stderr session projection 中残留的旧平铺字段访问全部改为
      `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Writer Convergence

### Goal

继续收紧 `tools/stage0/nextpas.pas` 的内部实现形状，但仍不改公开 CLI / envelope 契约：

- `PrintBuildContextProjection(...)` 与 `PrintSessionProjection(...)` 不应继续维护
  stdout/stderr 两套大段镜像逻辑
- projection 输出路径应收敛到一组统一 helper，降低后续继续 compaction 时的漏改风险
- fresh `verify_local` 必须继续全绿，证明只是 writer convergence，不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 build/session projection 的 stdout/stderr
      双分支重复，确认最小安全边界只需要收敛 writer helper，不需要改字段本身
- [x] 引入统一 projection writer helper，并把
      `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
      改成单一路径输出，保持字段名、顺序和条件不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-03-27 Toolchain Contract Hardening + Roadmap Review

### Goal

把上一轮审查里价值最高、且已经能在当前仓库落地的几项建议直接收口成代码和文档：

- 让 `session-id`、`tool-invocation-plan-ref`、`build-trace-ref` 改成每次 build 唯一
- 给 diagnostics sink 补上最小 warning / warning-as-error contract
- 给 unit resolver 补上可复用的 root index，避免重复全量重扫 search roots
- 回写路线图与实现计划，把近期优先级从“继续堆 toolchain projection”调回
  semantic/workspace truth

### Status

Completed

### Completed Steps

- [x] 先把 `build/verify_local.sh` 和 `tests/toolchain/toolchain_contract_smoke.pas`
      扩成会先对唯一 locator、warning contract 和 resolver index 提出 RED
- [x] 在 `np_compilation_session.pas` 里把 build session locator 改成带 timestamp + nonce 的唯一值
- [x] 在 `np_diagnostics_sink.pas` 里补齐 `EmitWarning`、`WarningCount`、
      `SetWarningAsError`
- [x] 在 `np_unit_resolver.pas` 里补齐最小 per-root search index，并暴露 index status /
      indexed root count / scan count contract
- [x] 回写 `master-roadmap.md`、`stage0-driver-specification.md`、
      `toolchain-specification.md`、`diagnostics-specification.md`、
      `tools/stage0/README.md` 与 master roadmap plan
- [x] 运行 fresh `./build/verify_local.sh`，确认整套 verify-local 继续全绿

## Addendum: 2026-03-27 Diagnostics Accounting + Search-index Projection Sync

### Goal

把上一轮已经落地的两条最小 contract 写成正式、持续一致的仓库 truth：

- diagnostics 不再只写 total count，而要明确 split error/warning accounting
- resolver search index 不再只留在 resolver 内部，而要作为 session-owned projection
  被公开说明
- 路线图与持续记录要明确这条 search index 仍然是 lazy contract，而不是假装“总该 ready”

### Status

Completed

### Completed Steps

- [x] 回看 `np_diagnostics_sink.pas`、`np_compilation_session.pas`、
      `np_unit_resolver.pas`、`tools/stage0/nextpas.pas`、
      `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`，
      确认真实 contract 已经在代码和 verify path 中生效
- [x] 回写 `compiler-specification.md`，把 diagnostics split accounting 与
      search-index projection 写成 compiler-owned truth
- [x] 回写 `diagnostics-specification.md`，把 `ErrorCount` / `WarningCount` /
      warning-as-error promotion contract 写清楚
- [x] 回写 `unit-resolution-specification.md`，把 per-root lazy search index 与
      `deferred -> ready` 投影行为写清楚
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，同步这轮已验证结论
- [x] 重新运行 fresh `./build/verify_local.sh`，确认 docs/planning sync 之后整套 verify-local 继续全绿

## Addendum: 2026-03-27 Partial Search-index Contract Hardening

### Goal

把 resolver search-index 的第三种真实状态 `partial` 正式冻结进 promotion path，避免后续
precedence 路径悄悄退化成 eager 全扫描或丢失 scan accounting。

### Status

Completed

### Completed Steps

- [x] 用 focused probe 确认 `explicit_unit_root`、`package_manifest_source_precedence`、
      `root_source_precedence`、`unit_root_precedence` 四类成功路径都会稳定投影
      `search-index-status=partial`
- [x] 在 `build/verify_local.sh` 为上述 representative precedence 路径补齐
      line-based 与 envelope 两层 `searchIndexStatus` / `indexedSearchRootCount` /
      `searchIndexScanCount` 断言
- [x] 回写 `unit-resolution-specification.md` 与 `tools/stage0/README.md`，
      说明 `partial` 表示“高优先级 root 提前命中后，低优先级 tiers 未被继续扫描”
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，记录这次 verify hardening
- [x] 重新运行 fresh `./build/verify_local.sh`，确认新增 partial-state gate 后整套 verify-local 继续全绿

## Current Phase

Completed

## Phases

### Phase 1: Review Report Against Codebase Reality

- [x] 逐条对照外部审查报告与当前代码
- [x] 确认优先级切到 `P0` 验证失真，再到 `P1` resolver correctness
- [x] 锁定当前最小收口范围：
      harness truthfulness、resolver correctness、docs sync、repo hygiene、fresh verification
- **Status:** completed

### Phase 2: Harness Truthfulness

- [x] 修正 `tests/harness/runner.pas`，让 fixture 收集只接收符合 group 契约的 `.pas`
- [x] 让 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
      都走真实执行路径，而不是只统计 fixture / snapshot
- [x] 为 group 与 smoke 补齐真实执行投影：
      `fixture-result`、`executed-fixture-count`、`passed-fixture-count`、
      `failed-fixture-count`、`smoke-group ... executed=<n>`
- [x] 让 snapshot-bearing groups 比较 canonical actual text，并在 mismatch / missing 时写出
      diff evidence
- [x] 把 runner bootstrap 产物从源码树移到 `.sisyphus/tmp/harness/bootstrap/runner`
- **Status:** completed

### Phase 3: Resolver Correctness

- [x] 修正 `ResolveRoot(...)`，让根单元也解析 `implementation uses`
- [x] 修正 `ResolveDependency(...)`，要求 requested unit name 与文件内部声明名一致
- [x] 新增 `resolver.unit-name-mismatch` failure baseline 与对应 fixture/snapshot
- [x] 修正 synthetic `System` 行为：
      implicit runtime placeholder 可以存在，但显式 `uses System` 仍必须尝试加载真实源码
- [x] 让 `TUnitGraph.AddResolvedUnit(...)` 支持从 placeholder 升级为真实 source-backed unit
- **Status:** completed

### Phase 4: Docs, Hygiene, and Planning Sync

- [x] 更新 `.gitignore`，把 `.sisyphus/`、FPC 生成物、runner/bootstrap 产物、snapshot
      diff evidence 和当前已知 smoke/example 产物统一排除
- [x] 清理源码树里的历史 runner/fixture 生成物与过期 diff
- [x] 更新 `tests/harness/README.md`、`tests/README.md`
- [x] 更新 `test-harness-specification.md` 与 `unit-resolution-specification.md`
- [x] 更新 `task_plan.md`、`findings.md` 与 `progress.md`
- **Status:** completed

### Phase 5: Fresh Verification

- [x] 运行 fresh `./tests/run_all_tests.sh --filter smoke`
- [x] 运行 fresh `./build/verify_local.sh`
- [x] 记录当前收口结论时，明确区分“真实 resolution / harness gate”与“仍 host-backed 的外层编译路径”
- **Status:** completed

### Phase 6: Workspace Discovery Truth Projection

- [x] 为 `build/verify_local.sh` 补齐 workspace/artifact discovery projection gate：
      `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
      `package-manifest-path`、`artifact-root`、`output-dir`，以及 envelope 对应 camelCase 字段
- [x] 为 `TCompilationOptions` / `TCompilationSession` 补齐最小 discovery metadata owned fields
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 nearest workspace/package helper，
      把当前真实 workspace/package/artifact 事实投影到 line-based output 与
      `command-envelope=<json>`
- [x] 运行 fresh `bash build/verify_local.sh`，确认 stage0 smoke、
      package manifest fixture 与 workspace member fixture 全部转绿
- **Status:** completed

### Phase 7: Pre-session Build Context Projection

- [x] 为 `build/verify_local.sh` 的 `invalid-unit-root-check` 补齐 early failure gate：
      line-based output 至少要保留 `workspace-root`、`workspace-discovery-kind`、
      `artifact-root`、`output-dir`，而 envelope 继续带上
      `failureKind`、`source`、`target`、`workspaceRoot`、`workspaceDiscoveryKind`、
      `artifactRoot`、`outputDir`
- [x] 在 `tools/stage0/nextpas.pas` 里把 source/target/workspace/artifact/output
      这批 command-level truth 提前 capture 到 `Active...` context，
      不再等 session 创建后才可见
- [x] 让 `PrintSessionProjection(...)` 先打印 build context，再只在有 `session-id`
      时继续打印 session-owned fields，避免伪造 pseudo-session
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `invalid-unit-root` 这类
      pre-session failure 也能稳定投影已知 build context，且 verify-local 全绿
- **Status:** completed

### Phase 8: Pre-session Failure Gate Expansion

- [x] 先做 focused probe，确认 `invalid-out-dir` 与 `invalid-artifact-root`
      当前已经真实复用同一条 pre-session build-context projection，
      不需要再改 `tools/stage0/nextpas.pas`
- [x] 为 `build/verify_local.sh` 增加 `invalid-out-dir-check`，冻结
      `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`
      及 envelope 对应 camelCase 字段
- [x] 为 `build/verify_local.sh` 增加 `invalid-artifact-root-check`，冻结同一批
      pre-session build context fields
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 全绿，
      且 `invalid-unit-root` / `invalid-out-dir` / `invalid-artifact-root`
      三条 early failure baseline 同时受保护
- **Status:** completed

### Phase 9: Source-directory-fallback Verify Coverage

- [x] 先做 focused probe，确认不传 `--workspace`、且 source 周围没有 workspace/package marker 时，
      当前真实行为已经是 `workspace-discovery-kind=source-directory-fallback`
- [x] 为 `build/verify_local.sh` 增加 `source-directory-fallback-check`，冻结
      `workspace-root`、`workspace-discovery-kind=source-directory-fallback`、
      `artifact-root`、`output-dir`、artifact 默认落点、tool plan argv 与 envelope 对应字段
- [x] 额外断言这条路径不会投影 `workspace-descriptor-path` / `package-manifest-path`
- [x] 同步补齐 `verify-local` success envelope，把
      `sourceDirectoryFallbackCheck`、`invalidOutDirCheck`、`invalidArtifactRootCheck`
      正式写进结构化结果
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 与整套 verify-local 全绿
- **Status:** completed

### Phase 10: Verify-local Success Envelope Parity

- [x] 对照 `build/verify_local.sh` 的 `*=pass` gate 集合与最终
      `command-envelope=<json>.result`，确认结构化结果仍缺
      `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
      `packageManifestSourcePrecedenceCheck`
- [x] 在 `build/verify_local.sh` 补齐上述三条 success field，保持 verify-local 的
      machine-readable result 与真实 promotion path 同步
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这次 envelope parity 修补
- [x] 运行 fresh `bash build/verify_local.sh`，确认 success envelope 扩充后整套 verify-local 继续全绿
- **Status:** completed

### Phase 11: Success-path Envelope Coverage Hardening

- [x] 对 `explicit-unit-root`、`out-dir-override`、`package-manifest-source-precedence`、
      `root-source-precedence`、`unit-root-precedence` 做 focused probe，确认当前真实输出
      已经在 `command-envelope=<json>.result` 中带上 `outputDir`、`artifact`、`searchPathCount`
      与 `searchPaths`
- [x] 在 `build/verify_local.sh` 为上述 gate 补齐最小 machine-readable 断言，
      冻结 success path 的 envelope search-path/output truth，而不改 stage0 实现
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 verify hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 envelope 断言后整套 verify-local 继续全绿
- **Status:** completed

### Phase 12: Descriptor/Manifest Presence Contract Hardening

- [x] 对 `stage0-smoke`、`package-manifest-source-root`、
      `package-manifest-source-precedence`、`source-directory-fallback`、
      `invalid-unit-root`、`invalid-out-dir`、`invalid-artifact-root`
      做 focused probe，确认 `workspaceDescriptorPath` / `packageManifestPath`
      当前真实行为是“按需出现、否则省略”，而不是投影成空字段
- [x] 在 `build/verify_local.sh` 为上述代表性路径补齐出现/缺失断言，冻结
      line-based output 与 `command-envelope=<json>.result` 的 presence-vs-absence contract
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 absence hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认 descriptor/manifest absence 断言加入后整套 verify-local 继续全绿
- **Status:** completed

### Phase 13: Explicit-workspace Omission Coverage Expansion

- [x] 对 `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
      `root-source-precedence`、`unit-root-precedence`、`toolchain-failure`
      做 focused probe，确认这些 remaining explicit-workspace 路径也都会稳定省略
      `workspaceDescriptorPath` / `packageManifestPath`
- [x] 在 `build/verify_local.sh` 为上述路径补齐 line/envelope absence 断言，
      把 explicit-workspace omission contract 从“代表性覆盖”扩成“主要路径全覆盖”
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 omission coverage expansion
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 absence gate 后整套 verify-local 继续全绿
- **Status:** completed

### Phase 14: Summary Surface Contract Hardening

- [x] 对 `stage0-smoke`、`semantic-smoke`、`syntax-failure`、`missing-unit`、
      `duplicate-import`、`toolchain-failure` 与显式 workspace 的 pre-session failure
      做 focused probe，确认当前真实输出已经稳定携带
      line-based `diagnostics-summary` / `human-summary`，以及 envelope 中的
      `diagnosticsSummary` / `humanSummary`
- [x] 在 `build/verify_local.sh` 为上述代表性 success / sessionful failure /
      pre-session failure 路径补齐 summary-surface 断言，不改 `tools/stage0/nextpas.pas`
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 summary contract hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 summary 断言后整套 verify-local 继续全绿
- **Status:** completed

## Decisions Made

| Decision                                                                                          | Rationale                                                                                          |
| ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------- |
| 先修验证失真，再谈更多架构扩张                                                                    | 假绿会污染后续所有判断，先修它才能让路线图有可信地基                                               |
| harness 继续只保留 6 个稳定 group，`smoke` 保持为 cross-group minimal view                        | 保持公开 surface 少而硬，不增加无必要实体                                                          |
| `compiler-fail` / `diagnostics` 统一改成 canonical actual text compare                            | 让 snapshot baseline 对比真正基于执行结果，而不是文件存在性                                        |
| synthetic `System` 只保留为 implicit runtime edge 的 placeholder，不再遮蔽真实 source             | 同时保留 graph 显式性与正确 provenance                                                             |
| 当前文档必须诚实写出 host-backed 边界和 search path 限制                                          | 避免对内排期和对外表述高估现状                                                                     |
| pre-session failure 要投影已知 command truth，但不能伪造 session-owned state                      | 让 early failure 更诚实，同时保持 session ownership 边界                                           |
| 对已存在的 early-failure 行为，优先先补 verify gate，再决定是否需要改实现                         | 保持批次 grounded，避免为“也许存在的问题”过早改结构                                                |
| verify 脚本自己的 success envelope 也必须跟上真实 gate 集合                                       | 避免 shell gate 已扩充，但结构化 verify 结果仍落后                                                 |
| `diagnostics-summary` / `human-summary` 也要被当成共享 command contract，而不是 incidental stdout | 规格已经把它们列为最小结果表面，verify 应同时保护 line/envelope 两层 mirror                        |
| resolver search index 继续保持 lazy，并把 `deferred                                               | partial                                                                                            | ready` 当成真实 session truth | 避免为了看起来“更完整”而引入 eager 扫描副作用，反而模糊真实 ownership |
| precedence success path 上的 `partial` 必须进入 verify gate，而不只停在手工 probe                 | 这能防止 resolver 以后命中高优先级 root 后仍去全扫低优先级 tiers，或者丢掉 indexed/scan accounting |

## Notes

- 工作区不是 Git 仓库。
- 当前 `build/verify_local.sh` 已经把以下 gate 纳入 promotion path：
  `missing-unit-check`、`ambiguous-unit-check`、
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `source-directory-fallback-check`、`invalid-unit-root-check`、`invalid-out-dir-check`、
  `invalid-artifact-root-check`、`harness-compiler-pass-check`、`smoke-check`
- 最小 package/workspace-declared source roots 已真实落地：
  nearest `nextpas.package.toml` 的 `[sources].roots` 与
  `nextpas.workspace.toml` 的 member package source roots 已进入
  `TCompilationOptions` / `TSearchPathSet` / verify path。
- 当前 stage0 CLI / envelope 也已把最小 workspace discovery truth 正式投影出来：
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，以及
  `workspaceRoot`、`workspaceDiscoveryKind`、`workspaceDescriptorPath`、
  `packageManifestPath`、`artifactRoot`、`outputDir`。
- 当前 `invalid-unit-root` 这类在 `TCompilationSession` 创建前就失败的路径，也会继续投影
  已知的 build command context：line-based output 至少保留 `target`、
  `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 则继续带上 `source`、`target` 与对应 camelCase
  build-context 字段。
- 当前同一类 pre-session build-context projection 也已经被 verify gate 扩到
  `invalid-out-dir` 与 `invalid-artifact-root`，所以 workspace/artifact/output truth
  不再只在一条 `invalid-unit-root` 路径上被保护。
- 当前 `source-directory-fallback` 成功路径也已经有 verify gate：
  不传 `--workspace` 时，workspace root 会退回 source 所在目录，artifact 默认进入
  `<source-dir>/.nextpas/out/<target>/`，并且不会凭空投影
  `workspace-descriptor-path` / `package-manifest-path`。
- 当前 `verify-local` 的 success envelope 也已经和真实 gate 集合对齐：
  `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
  `packageManifestSourcePrecedenceCheck` 不再只存在于 shell 输出里，而会进入最终
  `command-envelope=<json>.result`。
- 当前 success path 上与 search precedence / out-dir override 相关的 gate，
  也已经不只冻结 line-based output：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 现在都会额外断言 `command-envelope=<json>.result` 中的
  `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`。
- 当前 `workspace-descriptor-path` / `package-manifest-path` 的出现边界也已经被 verify
  冻结到“出现与缺失”两个方向：
  `stage0-smoke`、`source-directory-fallback` 与显式 workspace 的 pre-session failure
  不会误投影这两个字段；`package-manifest-source-root` 与
  `package-manifest-source-precedence` 则会继续稳定表现为“只有 manifest，没有 descriptor”。
- 当前 explicit-workspace 主路径上的 omission contract 也已经从代表性 case 扩成主要路径全覆盖：
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 `toolchain-failure`
  也都会显式验证 descriptor/manifest 字段不会误投影。
- 当前 summary surface 也不再只靠实现自觉：
  `stage0-smoke` / `semantic-smoke` 会稳定验证 `diagnostics-summary=none` 与
  `human-summary=build succeeded`，而 representative sessionful failure /
  pre-session failure 也会同时验证 line-based summary 与 envelope
  `diagnosticsSummary` / `humanSummary` mirror。
- 当前 diagnostics accounting 也已经不是只有 total count：
  `diagnostics-error-count`、`diagnostics-warning-count` 与 envelope 对应的
  `diagnosticErrorCount`、`diagnosticWarningCount` 已进入 `stage0-smoke`、
  `semantic-smoke` 与 `toolchain-contract` gate。
- 当前 resolver search index 也已经作为 session-owned truth 进入 verify path：
  `examples/smoke/hello.pas` 会稳定表现为 `search-index-status=deferred`、
  `indexed-search-root-count=0`、`search-index-scan-count=0`；
  `examples/smoke/hello_with_units.pas` 则会稳定表现为
  `search-index-status=ready`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`。
- 当前 `partial` 也已经不再只靠 focused probe 留证：
  `explicit-unit-root`、`package-manifest-source-precedence`、
  `root-source-precedence`、`unit-root-precedence` 现在都会额外断言
  `search-index-status=partial` 与对应 `indexedSearchRootCount` /
  `searchIndexScanCount`，其中 root-source precedence 稳定为 `1/1`，
  explicit/package precedence 代表路径稳定为 `2/2`。
- 这批只补“当前命令级 truth 的稳定投影”，不宣称完整 `WorkspaceModel`、
  richer package/workspace graph 或 target default persistence 已落地。
- `resolver.unit-not-found` 与 `resolver.ambiguous-unit-source` 当前也已经消费
  `TSearchPathSet` 的 typed metadata，在 diagnostic message 中投影
  `scope` / `provenance` / `root`，并在 candidate 场景额外投影 `path`。
- 当前仍未完成的更大项不是这轮收口内容：
  完整 multi-root workspace model、更丰富的 package/workspace provenance 与
  nextPas 完整脱离宿主 FPC 的最终 codegen

## Addendum: 2026-05-27 Platform Windows Wait/Error Semantics Ownerization

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

把 Windows wait result / last-error semantics 继续从 `platform.thread`、
`platform.sync` 的 consumer 实现里抽离到 host-owned
`nextpas.core.platform.windows.ffi`，让 platform L0 owner boundary 更诚实。

### Current Gap

- 前几批已经把 Windows timeout conversion 和 `FILETIME` token 下沉到了
  `windows.ffi`，但 `platform.thread`、`platform.sync` 里仍有 raw
  `GetLastError`、`WAIT_OBJECT_0`、`ERROR_TIMEOUT` 语义。
- 这些 raw Windows token 还没有被 focused source-surface gate 冻结为
  “必须由 host ffi owner 提供”的公开约束。

### Architecture Decision

- Windows wait result / error semantics 与 timeout conversion 一样，都属于宿主 ABI /
  policy truth，应继续归 `nextpas.core.platform.windows.ffi` owner。
- `platform.thread`、`platform.sync` 继续负责 nextPas 的稳定错误映射和 API 契约，
  但不直接持有 raw `GetLastError` / `WAIT_*` / `ERROR_*` 语义。
- 这批只收紧 owner boundary，不改变 `platform.thread` / `platform.sync`
  对外 public API，也不伪装成已经拿到 Windows runtime evidence。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `nextpas.core.platform.windows.ffi`，补齐 Windows last-error / wait-result helper
- [x] 让 `platform.thread` 改为消费 host-owned Windows error / wait semantics
- [x] 让 `platform.sync` 改为消费 host-owned Windows error / timeout semantics
- [x] 扩充 `test_platform_thread_host_ffi_surface`
- [x] 扩充 `test_platform_sync_host_ffi_surface`
- [x] 运行 focused tests
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `windows.ffi must expose Windows last-error conversion helper`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `windows.ffi must expose Windows last-error conversion helper`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不改 Windows wait API 的 public contract
- 这批不声称 macOS / FreeBSD / Android 已有新增 runtime evidence
- 这批不继续扩 `platform.time` / `platform.sync` 的下一轮 ownerization 目标

## Addendum: 2026-05-27 Platform POSIX Errno Read Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 POSIX errno 读取语义从 `platform.thread` / `platform.sync` 的 consumer 实现层下沉到
host-owned ffi owner，让“当前 errno 值怎么读”不再散落在平台实现单元里。

### Current Gap

- `linux/darwin/android/freebsd/unix` ffi 单元已经拥有 `platform_errno_location` 外部符号绑定，
  但 `platform.thread` 与 `platform.sync` 仍各自本地解引用 errno storage。
- 这让 errno symbol binding 已经 host-owned，但 errno value read 仍停在 consumer 层，owner boundary
  还差半步。

### Architecture Decision

- `platform_errno_location` 的绑定继续留在各 host ffi owner。
- 基于该绑定读取当前 errno 的 helper 也继续归各 host ffi owner，因此 consumer 只消费
  `platform_posix_errno_value`，不直接写 `platform_errno_location^`。
- 这批只收紧 owner boundary，不改 `platform.thread` / `platform.sync` public API，也不宣称新增
  Darwin / FreeBSD / Android runtime evidence。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `linux/darwin/android/freebsd/unix` ffi，补齐 `platform_posix_errno_value`
- [x] 让 `platform.thread` 改为消费 host-owned errno value helper
- [x] 让 `platform.sync` 改为消费 host-owned errno value helper
- [x] 扩充 `test_platform_thread_host_ffi_surface`
- [x] 扩充 `test_platform_sync_host_ffi_surface`
- [x] 运行 focused tests
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux errno value helper for retryable nanosleep`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux errno value helper for sync`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不新增宿主 ABI externals
- 这批不修改 `platform.time`
- 这批不把 POSIX error-code 到 nextPas error-code 的映射再下沉到 ffi

## Addendum: 2026-05-27 Platform Time Host Clock Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.time` 里的 Darwin / Windows 宿主时钟 helper 从 consumer 实现层下沉到
host-owned ffi owner，让 `platform.time` 尽量只保留跨平台 clock contract 与通用安全换算。

### Current Gap

- `platform.time` 虽然已经不再依赖 FPC 平台单元，也已经通过 `windows.ffi` /
  `darwin.ffi` 声明 raw externals，但 macOS monotonic 路径仍把
  `mach_timebase_info` cache / sanitize 逻辑留在 consumer。
- Windows monotonic / realtime 路径也仍直接在 consumer 中调用
  `QueryPerformanceFrequency`、`QueryPerformanceCounter` 与
  `GetSystemTimeAsFileTime`，并自己维护 QPC 频率初始化。

### Architecture Decision

- `platform.time` 继续拥有跨平台通用的安全换算 helper，例如 `platform_qpc_to_ns`、
  `platform_resolution_from_frequency_ns`、`platform_timespec_to_ns`。
- Darwin `mach` timebase cache / sanitize 与 monotonic helper 继续归
  `nextpas.core.platform.darwin.ffi` owner。
- Windows QPC 频率读取、counter 读取与 `FILETIME -> Unix ns` realtime helper
  继续归 `nextpas.core.platform.windows.ffi` owner。
- 这批只收紧 owner boundary，不改变 `platform.time` public API，也不伪装成已经拿到
  Darwin runtime evidence。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `test_platform_time_host_ffi_surface`，先把 Darwin / Windows host clock helper gate 打成 RED
- [x] 在 `darwin.ffi` 新增 Darwin monotonic / resolution helper
- [x] 在 `windows.ffi` 新增 QPC frequency / counter / FILETIME realtime helper
- [x] 让 `platform.time` 改为消费 host-owned helper
- [x] 运行 focused tests
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在 `darwin.ffi must expose Darwin monotonic clock helper for platform.time`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `fpc -Twin64 -Cn -Fi/home/dtamade/projects/nextPas/core/src -Fu/home/dtamade/projects/nextPas/core/src -FE/home/dtamade/projects/nextPas/.sisyphus/tmp/manual_core_platform_time_win64 -FU/home/dtamade/projects/nextPas/.sisyphus/tmp/manual_core_platform_time_win64 /home/dtamade/projects/nextPas/core/tests/nextpas.core.time/test_time/test_time.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`
- Additional evidence gap:
  - `fpc -Tdarwin -Cn ... core/tests/nextpas.core.time/test_time/test_time.lpr`
    在当前 Linux 宿主失败于 `Can't find unit system`，因此这批没有新增 Darwin compile/runtime proof

### Non-goals

- 这批不改 `platform.time` public API
- 这批不把 `clock_gettime/getres` 从 shared `posix.ffi` 再抽走
- 这批不声称当前 Linux 宿主已获得 Darwin runtime evidence

## Addendum: 2026-05-27 Platform Thread Host Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` 里仍散落在 consumer 的 Windows / Unix 线程 helper 下沉到各自
host-owned ffi owner，让 `platform.thread` 更聚焦于 L0 thread contract 和 handle 生命周期。

### Current Gap

- `platform.thread` 虽然已经把 Windows wait/error、sleep timeout 和 POSIX errno truth
  下沉到了 host ffi，但 consumer 仍直接调用 Windows `GetCurrentThreadId`、
  `SwitchToThread`、`Tls*`、`GetSystemInfo`。
- Unix 分支也仍直接调用 `pthread_self`、`gettid`、`pthread_threadid_np`、
  `pthread_getthreadid_np` 与 `sysconf(...)`，使当前线程 token、native thread id 和
  CPU count helper 仍泄漏在 consumer。

### Architecture Decision

- Windows current-thread id、yield、TLS alloc/free/set/get、CPU count helper 继续归
  `nextpas.core.platform.windows.ffi` owner。
- Linux/Android/Darwin/FreeBSD/generic Unix 统一新增
  `platform_thread_self_token_u64`、`platform_native_thread_id_u64`、
  `platform_cpu_count_i32`，把 Unix host helper 继续收进各宿主 ffi owner。
- `platform.thread` 只继续拥有 create/join/detach state、public API 契约与跨平台
  `nanosleep` request construction，不再直接散落上述 raw helper 调用。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `test_platform_thread_host_ffi_surface`，先把 Windows / Unix helper owner boundary 打成 RED
- [x] 在 `windows.ffi` 新增 current-thread / yield / TLS / CPU count helper
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 新增 self token / native id / CPU count helper
- [x] 让 `platform.thread` 改为消费 host-owned helper
- [x] 运行 focused tests
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `windows.ffi must expose Windows current-thread id helper`
  - 同一测试扩充 Unix helper gate 后再次 RED，失败在
    `linux.ffi must expose Linux thread self token helper`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `fpc -Twin64 -Cn -Fi/home/dtamade/projects/nextPas/core/src -Fu/home/dtamade/projects/nextPas/core/src -FE/home/dtamade/projects/nextPas/.sisyphus/tmp/manual_core_platform_thread_win64 -FU/home/dtamade/projects/nextPas/.sisyphus/tmp/manual_core_platform_thread_win64 /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.thread/test_platform_thread/test_platform_thread.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不重写 Windows create/join/detach state machine
- 这批不改 `platform.thread` public API
- 这批不声称新增 Darwin / FreeBSD / Android runtime evidence

## Addendum: 2026-05-27 Platform Thread Windows Lifecycle Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` 的 Windows handle lifecycle / sleep / atomic refcount helper
从 consumer 实现层收回 `nextpas.core.platform.windows.ffi`，让 `platform.thread`
更像 public contract consumer，而不是继续散落 raw WinAPI 调用。

### Current Gap

- `platform.thread` 虽然已经把 Windows wait/error、current-thread id、TLS、CPU count
  等 helper 收回 host ffi owner，但 Windows 分支仍直接调用
  `CreateThread`、`WaitForSingleObject`、`CloseHandle`、`Sleep` 与
  `InterlockedDecrement`。
- 这意味着 owned thread handle 的底层创建/等待/关闭语义，以及 thread state 的 atomic
  refcount 细节，仍泄漏在 consumer 里。

### Architecture Decision

- `nextpas.core.platform.windows.ffi` 继续拥有 raw Windows thread lifecycle ABI truth，并新增：
  - `windows_thread_create_handle`
  - `windows_thread_wait_terminated`
  - `windows_thread_close_handle`
  - `windows_thread_sleep_ns`
  - `windows_atomic_decrement_i32`
- `platform.thread` 继续保留 `TPlatformThreadHandle` public contract、Windows thread state
  record、join/detach 生命周期收口与返回值语义，但不再直接写 raw
  `CreateThread` / `WaitForSingleObject` / `CloseHandle` / `Sleep` /
  `InterlockedDecrement`。
- 这批不改 public API，不重写整个 Windows state machine；范围只收紧 helper ownership。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `test_platform_thread_host_ffi_surface`，先把 Windows lifecycle helper owner boundary 打成 RED
- [x] 在 `windows.ffi` 新增 Windows thread lifecycle / sleep / atomic helper wrappers
- [x] 让 `platform.thread` 的 Windows 分支改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `windows.ffi must expose Windows thread create helper: windows_thread_create_handle`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/core/build/review-win64-thread -FE/home/dtamade/projects/nextPas/core/build/review-win64-thread -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.thread/test_platform_thread/test_platform_thread.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不改 `platform.thread` public API
- 这批不引入 Windows runtime-only 证据；新增的是 Win64 compile-only + fresh 主门证明
- 这批不顺手扩到 POSIX pthread lifecycle helper ownerization

## Addendum: 2026-05-27 Platform Thread POSIX Lifecycle Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` 的 POSIX pthread lifecycle / TLS / yield / sleep raw 调用从 consumer
实现层收回当前选定宿主的 ffi owner，让 `platform.thread` 在 Unix 路径下也保持和 Windows
路径同样干净的 owner boundary。

### Current Gap

- `platform.thread` 虽然已经把 Unix self token、native thread id、CPU count 和 errno read
  helper 收回各宿主 ffi owner，但 consumer 仍直接调用 `pthread_create`、`pthread_join`、
  `pthread_detach`、`pthread_key_*`、`sched_yield` 与 `nanosleep`。
- 这意味着 POSIX thread handle lifecycle、TLS key 操作和 sleep retry 语义仍泄漏在
  consumer，而不是收口到当前宿主 ffi owner。

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 统一新增：
  - `platform_pthread_create_handle`
  - `platform_pthread_join_handle`
  - `platform_pthread_detach_handle`
  - `platform_pthread_yield`
  - `platform_pthread_sleep_ns`
  - `platform_pthread_tls_create`
  - `platform_pthread_tls_destroy`
  - `platform_pthread_tls_set`
  - `platform_pthread_tls_get`
- `platform.thread` 继续保留 `TPlatformThreadHandle` public contract、`TPosixThreadState`
  state record、join/detach 收口时机与返回值语义，但不再直接写 raw `pthread_*` /
  `sched_yield` / `nanosleep`。
- 这批不改 public API，不顺手扩到 `platform.sync` 的 pthread helper ownerization。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `test_platform_thread_host_ffi_surface`，先把 POSIX lifecycle/TLS/yield/sleep helper owner boundary 打成 RED
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 新增 POSIX pthread helper wrappers
- [x] 让 `platform.thread` 的 Unix 分支改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux pthread create helper: platform_pthread_create_handle`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/core/build/review-win64-thread -FE/home/dtamade/projects/nextPas/core/build/review-win64-thread -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.thread/test_platform_thread/test_platform_thread.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不改 `platform.thread` public API
- 这批不声称新增 Darwin / FreeBSD / Android runtime evidence；新增的是 source-surface proof、Linux focused runtime 与 Win64 compile-only
- 这批不顺手把 `platform.sync` 的 pthread raw 调用一起抽走

## Addendum: 2026-05-27 Platform Sync POSIX Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.sync` 的 POSIX pthread mutex / rwlock / condvar / timeout clock raw 调用
从 consumer 实现层收回当前宿主 ffi owner，让 `platform.sync` 在 Unix 路径下也像 Windows /
Linux futex 路径那样保持清晰的 owner boundary。

### Current Gap

- `platform.sync` 虽然已经把 pthread capability token、Linux futex helper、Windows sync helper
  和 errno read truth 收回 host ffi owner，但 consumer 仍直接调用
  `clock_gettime`、`pthread_mutexattr_*`、`pthread_mutex_*`、`pthread_rwlock_*`、
  `pthread_condattr_*`、`pthread_cond_*` 与 `sched_yield`。
- 这意味着 POSIX timeout clock 读取、mutex/cond attr 初始化、raw pthread 调用和 spin-yield
  细节仍泄漏在 consumer，而不是收口到当前宿主 ffi owner。

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 统一新增：
  - `platform_pthread_timeout_clock_now`
  - `platform_pthread_mutex_*`
  - `platform_pthread_rwlock_*`
  - `platform_pthread_condvar_*`
- `platform.sync` 继续保留 `PLATFORM_ERR_*` 映射、public opaque storage contract、
  deadline 计算与 wait-bucket fallback 策略，但不再直接写 raw `clock_gettime` /
  `pthread_*` / `sched_yield`。
- 这批不改 public API，不顺手改变 Linux futex path 或 Windows helper 形状。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩充 `test_platform_sync_host_ffi_surface`，先把 POSIX sync helper owner boundary 打成 RED
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 新增 POSIX sync helper wrappers
- [x] 让 `platform.sync` 的 Unix 分支改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose pthread timeout clock helper for sync: platform_pthread_timeout_clock_now`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/core/build/review-win64-sync -FE/home/dtamade/projects/nextPas/core/build/review-win64-sync -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不改 `platform.sync` public API
- 这批不声称新增 Darwin / FreeBSD / Android runtime evidence；新增的是 source-surface proof、Linux focused runtime 与 Win64 compile-only
- 这批不顺手改写 wait-bucket fallback 算法或跨模块抽象

## Addendum: 2026-05-27 Platform Time POSIX Clock Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.time` 的 POSIX raw clock 调用从 consumer 实现层收回当前宿主 ffi owner，让
`platform.time` 的 Unix / Darwin 路径也像 `platform.thread` / `platform.sync` 一样保持清晰的
host helper boundary。

### Current Gap

- `platform.time` 虽然已经把 Windows QPC / FILETIME helper、Darwin `mach_*` helper 和
  host clock id token 收回 `*.ffi` owner，但 POSIX 路径仍在 consumer 里直接调用
  `clock_gettime` / `clock_getres`。
- 这意味着 monotonic / realtime / resolution 的 raw POSIX clock 调用细节和 host clock id
  依赖仍泄漏在 consumer，而不是继续收口到当前宿主 ffi owner。

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 统一新增：
  - `platform_clock_monotonic_now`
  - `platform_clock_realtime_now`
  - `platform_clock_monotonic_getres`
- `platform.time` 继续保留 `platform_timespec_to_ns`、QPC/frequency 安全换算和 public clock
  contract，但不再直接写 raw `clock_gettime` / `clock_getres` 或 host clock id token。
- 这批不改 `platform.time` public API，不改 Windows helper 形状，也不顺手引入 L1 `core.time`
  抽象。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 `test_platform_time_host_ffi_surface`，先把 POSIX clock helper owner boundary 打成 RED
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 新增 host clock helper wrappers
- [x] 让 `platform.time` 的 POSIX / Darwin realtime 路径改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose host monotonic clock helper for platform.time: platform_clock_monotonic_now`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_no_fpc_units clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -Fi/home/dtamade/projects/nextPas/core/src -Fu/home/dtamade/projects/nextPas/core/src -FE/home/dtamade/projects/nextPas/core/build/review-win64-time -FU/home/dtamade/projects/nextPas/core/build/review-win64-time /home/dtamade/projects/nextPas/core/tests/nextpas.core.time/test_time/test_time.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不改 `platform.time` public API
- 这批不声称新增 Darwin / FreeBSD / Android runtime evidence；新增的是 source-surface proof、Linux focused runtime 与 Win64 compile-only
- 这批不顺手改变 L1 `core.time` 示例/基准或 `Stopwatch` 归属

## Addendum: 2026-05-27 Platform Sync Windows Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.sync` 的 Windows 同步 helper 从 consumer 实现层下沉到
`nextpas.core.platform.windows.ffi`，让 `platform.sync` 更像 public contract consumer，
而不是散落 raw WinAPI 调用的脚本层。

### Current Gap

- `platform.sync` 虽然已经把 Windows sync ABI declaration 统一并入
  `nextpas.core.platform.windows.ffi`，但 Windows 分支仍直接调用
  `InitializeSRWLock`、`AcquireSRWLock*`、`SleepConditionVariableSRW`、
  `WaitOnAddress`、`WakeByAddress*`。
- `test_platform_sync_host_ffi_surface` 之前只冻结了 wait/error/timeout helper，
  还没有把 mutex/rwlock/condvar/address-wait helper owner boundary 一起锁死。

### Architecture Decision

- `windows.ffi` 继续拥有 raw Windows sync ABI declaration，并新增：
  - `windows_mutex_*`
  - `windows_rwlock_*`
  - `windows_condvar_*`
  - `windows_wait_address_i32`
  - `windows_wake_address_*`
- `platform.sync` 继续保留 nextPas public opaque storage contract、`PLATFORM_ERR_BUSY` /
  `PLATFORM_ERR_TIMEOUT` 映射，以及 `windows_timeout_ns_to_ms` +
  `windows_last_error_is_timeout` 这层跨平台 wait policy 消费。
- 这批不扩到 Linux futex helper ownerization；范围只收紧 Windows sync helper boundary。

### Status

Completed; verification passed.

### Planned Steps

- [x] 修正 `test_platform_sync_host_ffi_surface` 到正确的 Windows helper contract，并观察 RED
- [x] 在 `windows.ffi` 新增 Windows mutex/rwlock/condvar/address-wait helper wrappers
- [x] 让 `platform.sync` 的 Windows 分支改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `windows.ffi must expose Windows mutex init helper: windows_mutex_init`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/core/build/review-win64-sync -FE/home/dtamade/projects/nextPas/core/build/review-win64-sync -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不重写 Linux futex 路径
- 这批不改 `platform.sync` public API
- 这批不声称新增 Windows runtime evidence；新增的是 Win64 compile-only + Linux 主门证据

## Addendum: 2026-05-27 Platform Sync Linux Futex Helper Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.sync` 的 Linux futex helper 从 consumer 实现层下沉到
`nextpas.core.platform.linux.ffi`，让 Linux path 与刚收口的 Windows helper owner boundary
保持同一形状。

### Current Gap

- `platform.sync` 虽然已经通过 `linux.ffi` 拥有 futex ABI declaration、syscall number、
  `FUTEX_*` 常量和 errno helper，但 Linux address-wait path 仍在 consumer 里直接拼
  `linux_syscall + FUTEX_* + timespec`。
- `test_platform_sync_host_ffi_surface` 之前只冻结“使用 `linux.ffi`”这一级，还没有明确要求
  futex wait/wake helper 本身归 `linux.ffi` owner。

### Architecture Decision

- `linux.ffi` 继续保留 raw futex ABI declaration 与 constants，并新增：
  - `linux_futex_wait_i32`
  - `linux_futex_wake_one_i32`
  - `linux_futex_wake_all_i32`
- `platform.sync` 继续保留 nextPas public contract 检查（例如 nil/value mismatch）与
  `platform_posix_map_error` 映射，但不再直接写 raw futex syscall 拼装。
- 这批不把 POSIX fallback bucket runtime 再抽走；范围只收紧 Linux futex helper boundary。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 `test_platform_sync_host_ffi_surface`，先把 Linux futex helper owner boundary 打成 RED
- [x] 在 `linux.ffi` 新增 futex wait/wake helper wrappers
- [x] 让 `platform.sync` 的 Linux futex path 改为消费这些 helper
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `linux.ffi must expose Linux futex wait helper for sync: linux_futex_wait_i32`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Win64 compile-only:
  - `fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FU/home/dtamade/projects/nextPas/core/build/review-win64-sync -FE/home/dtamade/projects/nextPas/core/build/review-win64-sync -Fu/home/dtamade/projects/nextPas/core/src -Fi/home/dtamade/projects/nextPas/core/src /home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不重写 pthread mutex/rwlock/condvar path
- 这批不改 `platform.sync` public API
- 这批不声称新增 Linux futex semantic matrix 以外的平台 runtime evidence

## Addendum: 2026-05-27 Platform ABI Size Token Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` / `platform.sync` 仍然留在 consumer 里的 raw ABI size truth 收回
host ffi owner，让“谁拥有 raw ABI type 形状，谁就拥有由它派生出来的 opaque storage size token”
这条边界闭合。

### Current Gap

- 前几轮虽然已经把 pthread / futex / Windows sync / POSIX clock 的 raw declaration 和 helper
  收进 `*.ffi` owner，但 `platform.thread` 仍直接在 consumer state record 里保存 `pthread_t`。
- `platform.sync` 仍在 consumer interface 里直接写
  `SizeOf(pthread_mutex_t)` / `SizeOf(pthread_rwlock_t)` / `SizeOf(pthread_cond_t)` /
  `SizeOf(SRWLOCK)` / `SizeOf(CONDITION_VARIABLE)`，所以 public opaque storage size truth
  还没有真正归回 host ffi owner。
- `test_platform_sync_posix_surface` 也还冻结着旧设计，要求 consumer 直接写 raw `SizeOf(...)`，
  会和新的 owner boundary 冲突。

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 统一继续拥有：
  - `PLATFORM_PTHREAD_TOKEN_SIZE`
  - `PLATFORM_PTHREAD_MUTEX_SIZE`
  - `PLATFORM_PTHREAD_RWLOCK_SIZE`
  - `PLATFORM_PTHREAD_CONDVAR_SIZE`
- `windows.ffi` 继续拥有：
  - `PLATFORM_WINDOWS_MUTEX_SIZE`
  - `PLATFORM_WINDOWS_RWLOCK_SIZE`
  - `PLATFORM_WINDOWS_CONDVAR_SIZE`
- `platform.thread` 的 Unix consumer 继续保留 nextPas 自己的 state record、join/detach
  生命周期收口与 public contract，但 thread token storage 改成 nextPas-owned opaque byte
  storage，不再直接保存 raw `pthread_t`。
- `platform.sync` 继续保留 nextPas 的 public opaque storage contract、error mapping 与 wait
  policy，但 public size 常量只消费 host-owned size token，不再在 consumer 里再次
  `SizeOf(...)` raw type。
- 这批不扩到新的 public API，也不顺手改写更高层的并发抽象。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 thread/sync host ffi surface tests，先把 size-token owner boundary 打成 RED
- [x] 在 POSIX host ffi / windows.ffi 暴露 ABI size token
- [x] 让 `platform.thread` / `platform.sync` 改为消费这些 token
- [x] 修正 stale `test_platform_sync_posix_surface` 到新的 owner boundary
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `platform_pthread_token_size`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `platform_pthread_mutex_size`
  - 首轮 `bash build/verify_local.sh` 初始失败在 stale
    `test_platform_sync_posix_surface`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
- Win64 compile-only:
  - `fpc -Twin64 ... test_platform_thread.lpr`
  - `fpc -Twin64 ... test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass`

### Non-goals

- 这批不新增 Darwin / FreeBSD / Android runtime 证据
- 这批不改 `platform.thread` / `platform.sync` public API
- 这批不把 ABI shape 本身从 shared `posix.ffi` 搬走；搬走的是 consumer 里的 size truth

## Addendum: 2026-05-27 Platform ABI Alignment Carrier Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` / `platform.sync` consumer 里残留的 raw ABI alignment truth 收回
host ffi owner，让“谁拥有 raw ABI type，谁就拥有由它派生出来的 alignment carrier”这条边界和
上一轮的 size-token ownerization 一起闭合。

### Current Gap

- 前一轮已经把 opaque storage 的 size truth 收回 host ffi owner，但 `platform.thread` 的 Unix
  state record 仍用 `FAlign: PtrUInt` 继承对齐，`platform.sync` 的 public opaque storage 仍用
  `FAlign: UInt64` 近似对齐。
- 这些 generic scalar 在 Linux x86_64 上碰巧没炸，不代表 owner boundary 正确；Darwin /
  FreeBSD / Android / Windows 的 native pthread 或 SRWLOCK / CONDITION_VARIABLE 对齐事实，
  仍不该由 consumer 继续硬猜。
- `test_platform_thread_host_ffi_surface` 与 `test_platform_sync_host_ffi_surface` 之前也还没有
  source-surface gate 明确冻结 “align carrier type 必须由 host ffi owner 暴露并被 consumer
  消费” 这条契约。

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 统一继续拥有：
  - `TPlatformPThreadTokenAlign`
  - `TPlatformPThreadMutexAlign`
  - `TPlatformPThreadRwLockAlign`
  - `TPlatformPThreadCondVarAlign`
- `windows.ffi` 继续拥有：
  - `TPlatformWindowsMutexAlign`
  - `TPlatformWindowsRwLockAlign`
  - `TPlatformWindowsCondVarAlign`
- `platform.thread` 的 Unix consumer 继续保留 nextPas 自己的 opaque byte storage，但通过
  host-owned `TPlatformPThreadTokenAlign` 继承 pthread token 的宿主对齐，而不再保留
  `FAlign: PtrUInt`。
- `platform.sync` 继续保留 nextPas 的 public opaque storage contract、error mapping 与 wait
  policy，但 `TPlatformMutex` / `TPlatformRwLock` / `TPlatformCondVar` 的 variant-record 对齐分支
  只消费 host-owned align carrier type，不再保留 `FAlign: UInt64` 这种 consumer-side 猜测。
- 这批不扩到新的 public API；收紧的是 ABI ownership 边界与 source-surface guard。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 thread/sync host ffi surface tests，先把 align-carrier owner boundary 打成 RED
- [x] 在 POSIX host ffi / windows.ffi 暴露 host-owned align carrier type
- [x] 让 `platform.thread` / `platform.sync` 改为消费这些 align carrier
- [x] 在 Linux `test_platform_sync_sizes` 补一条 native embedding alignment 对照 proof
- [x] 修正 `build/verify_local.sh` 对 `test_platform_sync_sizes` summary 的 stale 断言
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `tplatformpthreadtokenalign`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `tplatformpthreadmutexalign`
  - 首轮 `bash build/verify_local.sh` 初始失败在 stale
    `missing-core-platform-sync-size-pass-summary`，根因是
    `test_platform_sync_sizes` summary 已从 `4 total, 4 passed` 变成 `5 total, 5 passed`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_sizes clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Win64 compile-only:
  - `fpc -Twin64 ... test_platform_thread.lpr`
  - `fpc -Twin64 ... test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass`

### Non-goals

- 这批不新增 Darwin / FreeBSD / Android runtime 证据
- 这批不改 `platform.thread` / `platform.sync` public API
- 这批不把 deadline arithmetic、errno mapping 或 wait policy 挪进 ffi；收回的是 raw ABI alignment truth

## Addendum: 2026-05-27 Platform Windows ABI Type Leakage Ownership

### Goal Node

- `G3: RTL、core 和 framework`

### Goal

继续把 `platform.thread` / `platform.sync` Windows consumer 里残留的 raw ABI type / calling
convention / scalar conversion 泄漏收回 `windows.ffi` owner，让 Windows 宿主细节不只拥有 raw
API declaration 和 helper 名称，也继续拥有 thread state thunk、TLS key ABI 投影以及 timeout /
error 的 `DWORD` 中间形状。

### Current Gap

- 之前虽然已经把 Windows lifecycle helper、TLS raw helper、timeout conversion 与 last-error
  semantics 收进 `windows.ffi`，但 `platform.thread` 仍保留本地 `HANDLE` 字段、
  `DWORD` TLS key 转换和 `stdcall` thread entry thunk。
- `platform.sync` 的 Windows condvar / `WaitOnAddress` 路径仍保留 `DWORD` timeout 临时变量，以及
  `windows_last_error_is_timeout(DWORD(LError))` 这种 consumer-side ABI scalar 投影。
- 这些 raw type / calling convention 细节在 source-surface 上仍然说明 owner boundary 没有彻底闭合。

### Architecture Decision

- `nextpas.core.platform.windows.ffi` 继续拥有 raw Windows declaration，并新增：
  - `TPlatformWindowsThreadProc`
  - `PPlatformWindowsThreadState` / `TPlatformWindowsThreadState`
  - `windows_thread_state_create`
  - `windows_thread_state_join`
  - `windows_thread_state_detach`
  - `windows_tls_create_platform_key`
  - `windows_tls_destroy_platform_key`
  - `windows_tls_set_platform_key`
  - `windows_tls_get_platform_key`
  - `windows_error_i32_is_timeout`
  - `windows_condvar_timedwait_ns`
  - `windows_wait_address_i32_timeout_ns`
- `platform.thread` 继续保留 nextPas 的 public thread contract、join/detach API 和 thread proc
  contract，但 Windows 分支不再自己声明 raw `HANDLE` / `DWORD` state、`stdcall` thunk 或 TLS
  key 投影。
- `platform.sync` 继续保留 nextPas 的 `PLATFORM_ERR_TIMEOUT` 映射和跨平台 wait policy，但 Windows
  分支不再自己保留 `DWORD` timeout / timeout-classifier 中间层。

### Status

Completed; verification passed.

### Planned Steps

- [x] 扩 thread/sync host ffi surface tests，先把 Windows ABI type leakage boundary 打成 RED
- [x] 在 `windows.ffi` 增加 Windows thread-state / TLS platform-key / timeout-classifier helper
- [x] 让 `platform.thread` / `platform.sync` 改为消费这些 ownerized helper/type
- [x] 运行 focused tests
- [x] 运行 Win64 compile-only
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在 `tplatformwindowsthreadproc`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在 `windows_error_i32_is_timeout`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- Win64 compile-only:
  - `fpc -Twin64 ... test_platform_thread.lpr`
  - `fpc -Twin64 ... test_platform_sync.lpr`
- Full:
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass`

### Non-goals

- 这批不新增 Darwin / FreeBSD / Android runtime 证据
- 这批不改 `platform.thread` / `platform.sync` public API
- 这批不把 nextPas 的 timeout/error mapping 直接塞进 ffi；收回的是 Windows ABI type / thunk / scalar leakage

## Addendum: 2026-05-27 Platform Time Host Clock Ns Helper Ownership

### Goal

继续把 `platform.time` 的宿主时钟 ownership 再收紧一层：

- host ffi owner 不只暴露 raw `timespec` / mach / QPC / FILETIME helper
- 各宿主 ffi owner 直接暴露统一命名的高层 clock result helper
- `platform.time` consumer 尽量只保留 public clock contract 和对 host helper 的薄 delegation

### Architecture Decision

- `linux/android/darwin/freebsd/unix.ffi` 与 `windows.ffi` 统一继续拥有：
  - `platform_clock_monotonic_ns_u64`
  - `platform_clock_realtime_ns_u64`
  - `platform_clock_monotonic_resolution_ns_u64`
- shared `posix.ffi` 允许继续拥有所有 POSIX 宿主都复用的饱和 `timespec -> ns` helper；这类 helper 不携带
  host capability truth，也不回退成 consumer 本地逻辑复制。
- `platform.time` 继续保留 public pure helper API 和 public clock contract，但 consumer 分支不再直接消费
  `platform_clock_monotonic_now` / `platform_clock_realtime_now` /
  `platform_clock_monotonic_getres`、Darwin `mach_*` helper，或 Windows `windows_qpc_*` /
  `windows_filetime_now_unix_ns`。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 `test_platform_time_host_ffi_surface`，要求 host ffi owner 暴露 `platform_clock_*_ns_u64`
- [x] RED：禁止 `platform.time` consumer 继续直接消费 raw timespec/Darwin/Windows clock helper
- [x] 在 `posix.ffi` 增加共享 `platform_posix_timespec_to_ns_u64`
- [x] 在 Linux/Android/Darwin/FreeBSD/Unix/Windows ffi owner 中补齐 `platform_clock_*_ns_u64`
- [x] 让 `platform.time` 改成薄 delegation
- [x] 回写文档与跟踪文件
- [x] 运行 fresh `make -C core test`
- [x] 运行 fresh `make -C core examples`
- [x] 运行 fresh `make -C core benchmarks`
- [x] 运行 fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在 `platform_clock_monotonic_ns_u64`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - fresh `bash build/verify_local.sh`
    输出 `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 这批不改 `platform.time` public API
- 这批不宣称 Darwin / FreeBSD / Android / Windows 新增 runtime truth
- 这批不把 `TDuration`、`TInstant`、`TStopwatch` 或其他 L1 时间抽象带回 platform

## Addendum: 2026-05-27 Platform Host Base/FFI Split

### Goal

把 `platform.<host>.ffi` 继续拆成更符合四件套范式的 host owner：

- `platform.<host>.base` 承载宿主常量、record、ABI scalar/type alias、opaque carrier、
  size/align token 与 capability token。
- `platform.<host>.ffi` 只承载 external declaration 与围绕宿主 ABI 的 thin helper。
- `platform.time`、`platform.sync`、`platform.thread` 作为跨宿主统一 contract，直接消费
  `platform.<host>.base` / `platform.<host>.ffi`，不再把 feature-specific ffi 作为默认形态。

### Architecture Decision

- 新增 `posix/linux/darwin/android/freebsd/unix/windows.base`，把原来散落在 `.ffi` 的
  ABI 载体、opaque storage、size/align token、clock/sysconf/errno/futex/Windows 常量迁入 base。
- `.ffi` 明确 `uses` 自己的 host `.base`，需要 POSIX 共享 ABI 形状时再 `uses posix.base`。
- `platform.sync` 的 interface 只引用 host `.base` 暴露 public opaque storage，implementation
  再引用 host `.ffi`；避免 public surface 因为类型常量而拉入 raw external owner。
- source-surface gates 升级为同时冻结 base 文件存在性、`.ffi -> .base` 消费关系，以及
  feature consumer 不回退到重复 ABI 载体。

### Status

Completed; verification passed in isolated worktree.

### Planned Steps

- [x] RED：扩 `test_platform_ffi_partition_surface`，要求 host base files 存在并被 `.ffi` 消费
- [x] RED：扩 `test_platform_ffi_owner_boundary`，把 base 视为非 FFI owner 并冻结 owner 边界
- [x] 新增 7 个 host/shared base 单元并迁移 ABI 常量/类型/opaque carrier
- [x] 更新 time/sync/thread consumer 与 host ffi uses 关系
- [x] 更新 source-surface、simulated-host、sync/thread/time focused tests
- [x] 更新 `build/verify_local.sh` 与设计文档
- [x] 运行 focused tests、full core test/example/benchmark、fresh `bash build/verify_local.sh`

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
    初始失败在缺少 `nextpas.core.platform.posix.base.pas`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    初始失败在 base absence / non-ffi owner count
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_posix_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_sizes clean test`
- Full:
  - `make -C core test` 输出 `All tests passed.`
  - `make -C core examples` 输出 `All examples compiled.`
  - `make -C core benchmarks` 输出 `All benchmarks passed.`
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不新增 `platform.time.ffi` / `platform.sync.ffi` / `platform.thread.ffi`
- 这批不改变 time/sync/thread public API
- 这批不宣称新增 macOS / FreeBSD / Android / Windows runtime 证据

## Addendum: 2026-05-27 Platform POSIX Math Helper Split

### Goal

修正 `platform.time.host` 为了纯 `timespec -> ns` 换算而无条件拉入 `posix.ffi` 的边界问题：

- 纯 POSIX timespec 数学放入 helper-only `nextpas.core.platform.posix.math`。
- `posix.ffi` 继续拥有 POSIX external declaration 和贴近 external 的共享 helper。
- `platform.time.host` 对 public timespec 换算只依赖 `posix.math`，只有 Unix host clock 分支才拉入
  `posix.ffi`。

### Architecture Decision

- 新增 `core/src/nextpas.core.platform.posix.math.pas`，承载
  `platform_posix_timespec_to_ns_u64`、`platform_posix_timespec_add_ns` 与
  `platform_posix_timespec_remaining_ns_u64`。
- `posix.ffi` 改为消费 `posix.math`，不再定义这些纯数学 helper。
- `platform.time.host` 的 uses 边界改为：
  - unconditionally consume `posix.base` / `posix.math`
  - only under `NEXTPAS_UNIX` consume `posix.ffi` and host ffi owners
- `build/verify_local.sh` 的输入面加入 `posix.math`。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：扩 time/posix/owner source-surface tests，要求 `posix.math` 存在
- [x] RED：要求 `posix.ffi` 不再定义纯 timespec 数学 helper
- [x] 新增 `posix.math` 并迁移 pure helper
- [x] 更新 `posix.ffi` 和 `platform.time.host` uses 边界
- [x] 运行 affected focused tests
- [x] 运行 full core test/example/benchmark 和 fresh `bash build/verify_local.sh`
- [x] 合并前更新最终验证证据

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
    初始失败在 `File not found`
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在 `File not found`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    初始失败在 helper-only math unit 计数不足
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - `make -C core test` 输出 `All tests passed.`
  - `make -C core examples` 输出 `All examples compiled.`
  - `make -C core benchmarks` 输出 `All benchmarks passed.`
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 这批不新增 feature-specific `platform.time.ffi`
- 这批不改变 public time/sync/thread API
- 这批不宣称新增 Windows runtime link evidence；先用 source-surface、Linux runtime 和 compile-only
  matrix 收紧边界

## Addendum: 2026-05-27 Platform POSIX Mutex Timedlock ABI Surface

### Goal

按“FPC 源码是 ABI 依据，不是运行时依赖”的规则，补齐有明确证据的 POSIX mutex timedlock ABI surface：

- `posix.ffi` 拥有 `pthread_mutex_timedlock` raw declaration 与 shared thin helper。
- `linux/android/freebsd.base` 显式标记 timedlock supported。
- `darwin/unix.base` 显式标记 timedlock unsupported / unknown，host ffi 暴露 ENOTSUP stub。
- 不新增 `platform.sync` public API，不对 raw pthread timedlock 做 runtime 单元测试。

### Architecture Decision

- Linux 与 FreeBSD 的 FPC `pthread.inc` 明确声明 `pthread_mutex_timedlock`；Linux 声明覆盖 Android
  分支，因此这三类宿主可委托 shared `platform_posix_pthread_mutex_timedlock_abs`。
- FPC Darwin pthread 声明没有 `pthread_mutex_timedlock`，generic Unix 也没有足够宿主依据；这两个
  host owner 暴露同名 helper 但返回 `PLATFORM_POSIX_ENOTSUP`。
- `pthread_rwlock_timedrdlock` / `pthread_rwlock_timedwrlock` 这轮不搬入通用 POSIX surface，因为当前
  FPC 证据只在 `netwlibc`，不是 Linux/FreeBSD/Darwin/Android host pthread 依据。

### Status

Completed; verification passed in isolated worktree.

### Planned Steps

- [x] RED：扩 `test_platform_posix_ffi_surface`，要求 shared timedlock declaration/helper
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 host capability token 与 host helper/stub
- [x] RED：扩 `test_platform_ffi_partition_surface`，要求 timedlock capability 属于 host base
- [x] 实现 host base capability、`posix.ffi` raw declaration/shared helper、host ffi wrapper/stub
- [x] 运行 focused gates 与 simulated host compile matrix
- [x] 运行 full core test/example/benchmark 与 fresh `bash build/verify_local.sh`
- [x] commit / merge / cleanup

### Verification

- RED:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
    初始失败在缺少 `platform_posix_pthread_mutex_timedlock_abs`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在缺少 `platform_pthread_mutex_timedlock_supported`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
    初始失败在缺少 `platform_pthread_mutex_timedlock_supported`
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform/test_platform_posix_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_partition_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- Full:
  - `make -C core test` 输出 `All tests passed.`
  - `make -C core examples` 输出 `All examples compiled.`
  - `make -C core benchmarks` 输出 `All benchmarks passed.`
  - fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`

### Non-goals

- 不新增 `platform_mutex_timedlock` public API。
- 不把 raw `pthread_mutex_timedlock` 当成 nextPas runtime 单测目标。
- 不搬入当前 host FPC pthread 证据不足的 rwlock timedlock ABI。

## Addendum: 2026-05-27 Platform Time Integration Worktree Closeout

### Goal

审查并收口旧 `codex/platform-time-integration` worktree，避免它继续被误认为待合主线：

- 不整条合入会回滚当前 host-owner platform 架构的旧提交。
- 只择优移植仍有价值且未被主线吸收的小颗粒。
- 清理历史 worktree / 分支，减少并行开发噪音。

### Decision

`codex/platform-time-integration @ 02be065` 相对当前主线只领先 1 个旧提交，但主线已经领先 91+
个提交。该提交混合了过期 platform.time FFI 形态、L1 `demo_stopwatch`、L1 time benchmark、
旧 Makefile 脚本与 text 边界补丁；其中 platform/time/build 方向已被主线以更好的
`platform.time facade + base + host`、host `base/ffi` owner、platform 专属 example/benchmark、
source-surface gate 和 full verification 吸收。

本轮只择优保留 text public contract 边界：

- `TextSplit('a,,c', ',')` 保留空字段。
- `TextSplit('abc', '')` 返回原字符串单元素数组。
- `TextIndexOf('hello', '')` 返回 0。

### Planned Steps

- [x] 对比 `main...codex/platform-time-integration` 提交和文件差异
- [x] 确认整条合并会删除/回滚当前 platform host-owner 成果
- [x] 移植仍有价值的 text 边界测试
- [x] 修复 `TextIndexOf` 空 substring contract
- [x] 跑 focused / broader verification
- [x] 删除旧 worktree 和分支
- [x] 提交 closeout

### Verification

- RED:
  - `make -C core/tests/nextpas.core.text/test_text clean test` 失败在
    `TextIndexOf('hello', '')` expected 0, got -1。
- GREEN:
  - `make -C core/tests/nextpas.core.text/test_text clean test` 通过，21/21 pass。
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_helpers clean test` 通过，11/11 pass。
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary clean test` 通过，6/6 pass。
  - `make -C core/tests/nextpas.core.platform.time/test_platform_time_host_ffi_surface clean test` 通过，1/1 pass。
  - `make -C core test` 输出 `All tests passed.`
  - `make -C core examples` 输出 `All examples compiled.`
  - `make -C core benchmarks` 输出 `All benchmarks passed.`

### Non-goals

- 不合入旧 `demo_stopwatch` 到 platform。
- 不恢复旧 `core/scripts/project.mk` 构建形态。
- 不回退当前 `platform.time`、`platform.sync`、`platform.thread` host-owner FFI 分层。

## Addendum: 2026-05-27 Platform ABI Owner Audit And Gap Matrix

### Goal

从最新 `main` 重新进入 platform 下一轮，不继续背旧 `platform-time-integration` 分支：

- 以 `task_plan.md` 为准绳，先补计划再实施。
- 全量审计 `platform.time` / `platform.sync` / `platform.thread` 是否还残留 raw OS ABI token、
  raw scalar、calling convention、errno 读取、timeout 换算、`SizeOf(raw type)` 或 inline
  `external` 声明。
- 把确认存在的宿主 truth 下沉到 `platform.<host>.base` / `platform.<host>.ffi`，把纯数学 helper
  放到 `posix.math` / `windows.math` 这类普通 helper owner。
- 建立真实的 platform gap matrix，明确 Linux runtime、Win64 compile-only、simulated host compile-only
  与尚未覆盖的 macOS / Android / FreeBSD / Windows runtime 缺口。

### Current Decision

下一轮优先从 `platform.thread` 做 owner audit。理由：

- `platform.thread` 是 L0 系统线程 API，不是 L1 `ThreadPool` / `Channel` / `Future`。
- 它同时碰到 POSIX `pthread`、`nanosleep`、TLS、native thread id、CPU count、Windows thread state
  与 Windows TLS key，最容易把宿主 ABI 细节泄回 consumer。
- 当前 `platform.time`、`platform.sync` 已有较强 source-surface gate；thread 继续审计能补齐三者一致性。

### Planned Steps

- [x] 在最新 `main` 开 `codex/platform-thread-owner-audit` isolated worktree
- [x] 跑 platform focused baseline：
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_l0_boundary clean test`
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 审计 `core/src/nextpas.core.platform.thread.pas` 与 host `base/ffi` consumer boundary
- [x] 先扩 source-surface test 成 RED，冻结发现的 owner gap
- [x] 再移动最小实现，让 RED 变 GREEN
- [x] 同步 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates、`make -C core test`、`make -C core examples`、`make -C core benchmarks`
- [x] 跑 fresh `bash build/verify_local.sh`
- [x] 复盘、提交、合并回 `main`，再清理 worktree / 分支

### Audit Checklist

- [x] production platform code 不 `uses Linux`、`UnixType`、`PThreads`、`BaseUnix`、`Syscall`、`Windows`
- [x] production platform implementation 不散落新的 raw `external` 声明
- [x] `platform.thread` 不创建 feature-specific `platform.thread.ffi`
- [x] `platform.thread` consumer 不保留 raw Windows `HANDLE` / `DWORD` / `stdcall` thunk
- [x] `platform.thread` consumer 不保留 raw POSIX `pthread_t` / `pthread_key_t` / `nanosleep` ABI 细节
- [x] host size / align / capability token 只由 host `.base` 暴露
- [x] host ABI wrapper、errno binding、native thread id、TLS key glue 只由 host `.ffi` / shared `posix.ffi`
      暴露
- [x] POSIX thread state carrier 与分配/释放归 host `.base` / `.ffi`，`platform.thread` 只消费
      `platform_pthread_state_create/join/detach`
- [x] runtime tests 只覆盖 `platform.thread` public contract，不直接测试 raw OS API

### Verification Plan

- Focused RED/GREEN gate 必须记录初始失败点和修复后通过命令。
- Linux runtime 证据以 `test_platform_thread`、example、benchmark 为主。
- Win64 仍为 compile-only；不能包装成 Windows runtime truth。
- Darwin / Android / FreeBSD / generic Unix 仍以 simulated host compile-only 和 source-surface gate 为主；
  不能包装成真实 runtime truth。
- 收口前必须 fresh 跑：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`

### Non-goals

- 不改 L1 `nextpas.core.thread`。
- 不加入 `ThreadPool`、`Channel`、`Future`、scheduler、task 等 L1 抽象。
- 不对 raw `pthread_*`、`nanosleep`、Windows thread API 做 runtime 单测。
- 不宣称新增 macOS / Android / FreeBSD / Windows runtime 证据。
- 不为 `platform.thread` 新建 feature-specific `*.ffi.pas`，除非先证明它不属于任何 host owner。

### Implementation Notes

- 审计发现 `platform.thread` 的 POSIX 路径还保留本地
  `PPosixThreadState` / `TPosixThreadState`、`New(LState)`、`Dispose(LState)` 与
  `@LState^.Thread[0]`。这层生命周期和 storage offset 不属于 unified consumer，应归 host
  `base/ffi` owner。
- RED:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    初始失败在
    `linux.ffi must expose Linux pthread state create helper: platform_pthread_state_create`。
- GREEN:
  - `linux/android/darwin/freebsd/unix.base` 新增
    `PPlatformPThreadState` / `TPlatformPThreadState`。
  - shared `posix.ffi` 新增
    `platform_posix_pthread_state_create/join/detach`，只处理 pthread token storage 的通用 glue。
  - `linux/android/darwin/freebsd/unix.ffi` 新增
    `platform_pthread_state_create/join/detach`，负责 state 分配、清零、释放与 shared helper
    委托。
  - `platform.thread` POSIX 分支删除本地 state carrier 和直接 `New/Dispose`，只消费 host-owned
    state helper。
- 期间 focused 行为测试第一次失败在
  `nextpas.core.platform.thread.pas(140,8) Error: ENDIF without IF(N)DEF`，原因是删除本地
  POSIX state type 时误删了 Unix implementation guard；已恢复 `{$IFDEF NEXTPAS_UNIX}`。
- Fresh verification:
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
    输出 `8 total, 8 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_no_fpc_units clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_l0_boundary clean test`
    输出 `3 total, 3 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    输出 `2 total, 2 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出 `simulated-host-compile-matrix-status=pass`。
  - `make -C core test` 输出 `All tests passed.`。
  - `make -C core examples` 输出 `All examples compiled.`。
  - `make -C core benchmarks` 输出 `All benchmarks passed.`。
  - `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`。
- Merge closeout:
  - worktree commit `45f867a platform: ownerize posix thread state`。
  - feature 分支合入最新 `main@9793e94` 后生成整合提交 `a49af35`，无冲突，并保留主线新增
    collections/mem contract tests。
  - `main` 已 fast-forward 到 `a49af35`。
  - 合并后主线 focused verification:
    - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread_host_ffi_surface clean test`
      输出 `1 total, 1 passed, 0 failed`。
    - `make -C core/tests/nextpas.core.platform.thread/test_platform_thread clean test`
      输出 `8 total, 8 passed, 0 failed`。
    - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
      输出 `simulated-host-compile-matrix-status=pass`。
    - `git diff --check` 无输出。
  - `codex/platform-thread-owner-audit` worktree 与分支已删除。
  - 注意：主线仍有非本轮 collections WIP（`core/src/nextpas.core.collections.deque.pas` 与
    `core/tests/nextpas.core.collections/test_deque/test_deque.lpr`），本轮未修改、未提交。

## Addendum: 2026-05-27 Platform Sync POSIX Error Result Host Ownership

### Goal

继续从最新 `main` 执行 platform ABI owner gap matrix，这轮只收 `platform.sync` 中仍由 consumer
直接保存的 POSIX errno classifier：

- `PLATFORM_ERR_*` 是 nextPas public sync result contract，继续归 `platform.sync` 所有。
- `PLATFORM_POSIX_EAGAIN` / `PLATFORM_POSIX_EBUSY` / `PLATFORM_POSIX_EINVAL` /
  `PLATFORM_POSIX_ENOTSUP` / `PLATFORM_POSIX_ETIMEDOUT` 是 host errno truth，不应继续被
  `platform.sync` consumer 直接 case。
- POSIX host `.ffi` 暴露 caller-supplied public-result helper，让 host owner 负责 errno
  分类，consumer 只传入 public result 值。

### Architecture Decision

- 不新增 `platform.sync.ffi`。`platform.sync` 是统一跨宿主 L0 public contract，不是 FFI owner。
- shared `posix.ffi` 可以承载无宿主 truth 的 classifier skeleton，但具体 errno token 来自
  `linux/android/darwin/freebsd/unix.base`，并通过各 host `.ffi` helper 暴露。
- `platform.sync` 保留 public opaque storage、public error constants、wait-bucket fallback 策略与
  wait/wake public contract。
- raw pthread/futex/errno API 不进入 runtime 单元测试；本轮 evidence 以 RED/GREEN source-surface
  guard、focused public behavior test 与 compile-only matrix 为主。

### Planned Steps

- [x] 在最新 `main` 开 `codex/platform-sync-owner-audit` isolated worktree
- [x] 跑 focused baseline：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
- [x] RED：扩 `test_platform_sync_host_ffi_surface`，要求 POSIX host ffi 暴露
      `platform_pthread_sync_result`，并禁止 `platform.sync` 继续引用 `PLATFORM_POSIX_E*`
- [x] 在 shared `posix.ffi` 增加 caller-supplied errno classifier skeleton helper
- [x] 在 `linux/android/darwin/freebsd/unix.ffi` 增加 host-owned sync-result wrapper
- [x] 修改 `platform.sync` POSIX 路径，让所有 pthread/futex 返回码走 host helper 映射到
      `PLATFORM_ERR_*`
- [x] 更新 `core/docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 跑 focused gates：
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
- [x] 跑 full verification：
  - `make -C core test`
  - `make -C core examples`
  - `make -C core benchmarks`
  - `bash build/verify_local.sh`
- [x] commit、择优合并回 `main`、清理 worktree / 分支

### Audit Checklist

- [x] `platform.sync` 不直接引用 `PLATFORM_POSIX_EAGAIN` / `PLATFORM_POSIX_EBUSY` /
      `PLATFORM_POSIX_EINVAL` / `PLATFORM_POSIX_ENOTSUP` / `PLATFORM_POSIX_ETIMEDOUT`
- [x] `platform.sync` 不新增 raw `external` 声明，不 uses FPC platform/RTL binding unit
- [x] `platform.sync` 不创建 feature-specific `platform.sync.ffi`
- [x] POSIX host `.ffi` helper 接收 caller-supplied public result，避免 host ffi 硬编码
      `PLATFORM_ERR_*`
- [x] Windows sync helper ownership 不被本轮回退

### Implementation Notes

- RED:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    初始失败在
    `linux must delegate POSIX sync error classification to shared posix.ffi skeleton: platform_posix_sync_result_from_error`。
- GREEN:
  - `nextpas.core.platform.posix.ffi` 新增
    `platform_posix_sync_result_from_error`，只做 caller-supplied errno token 与 caller-supplied
    public result 的参数化投影，不保存任何宿主 errno 数字，也不硬编码 `PLATFORM_ERR_*`。
  - `linux/android/darwin/freebsd/unix.ffi` 新增
    `platform_pthread_sync_result`，把各自 host-owned `PLATFORM_POSIX_E*` token 交给 shared skeleton。
  - `platform.sync` 的 `platform_posix_map_error` 改成 thin adapter，只把 nextPas public
    `PLATFORM_ERR_*` result 值传给 host helper。
  - `test_platform_sync_host_ffi_surface` 现在同时冻结 shared skeleton、host wrapper 与 consumer
    不再引用 `PLATFORM_POSIX_E*`。
- Focused GREEN:
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    输出 `14 total, 14 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_no_fpc_units clean test`
    输出 `1 total, 1 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_ffi_owner_boundary clean test`
    输出 `2 total, 2 passed, 0 failed`。
  - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
    输出 `simulated-host-compile-matrix-status=pass`。
- Full GREEN:
  - `make -C core test` 输出 `All tests passed.`。
  - `make -C core examples` 输出 `All examples compiled.`。
  - `make -C core benchmarks` 输出 `All benchmarks passed.`。
  - `bash build/verify_local.sh` 输出 `verify-local=pass` 与
    `human-summary=local verification passed`。
- Merge closeout:
  - committed as `fce88c3 platform: ownerize posix sync errno result mapping`。
  - fast-forward merged into `main`。
  - removed `platform-sync-owner-audit` worktree and deleted `codex/platform-sync-owner-audit` branch。
  - post-merge focused gates on `main` passed:
    - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync_host_ffi_surface clean test`
    - `make -C core/tests/nextpas.core.platform.sync/test_platform_sync clean test`
    - `make -C core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix clean test`
  - post-merge `git diff --check` passed and `git status --short --branch` showed clean `main`。

### Non-goals

- 不改变 `platform.sync` public API 名称或 public result 常量值。
- 不移动 wait-bucket fallback 策略。
- 不对 raw pthread/futex/errno API 写 runtime 单元测试。
- 不宣称新增 macOS / Android / FreeBSD / Windows runtime evidence。

## Active Session: 2026-06-04 branch cleanup tranche 2

### Goal

继续按“一个分支一个分支”的方式处理剩余小分支，只保留 current `main` 仍然缺的净价值：

- 重新核对 `codex/platform-host-ffi-wave15-helper-names`
- 重新核对 `worktree-json-yaml-coverage`
- 重新核对 `codex/platform-pty-integration`
- 把真实需要保留的差异吸收到统一 integration queue
- 删除已经过时、被吸收或明显不该合入主线的源分支

### Checklist

- [x] 用 current `main` 重新比对 3 条候选分支的净差异，而不是沿用旧 worktree 结论。
- [x] 判定 `codex/platform-host-ffi-wave15-helper-names` 是否仍符合 current Wave 15 FFI 边界。
- [x] 判定 `worktree-json-yaml-coverage` 是否仍为 current `main` 缺失覆盖。
- [x] 判定 `codex/platform-pty-integration` 两个独有提交里哪些仍值得保留。
- [x] 在隔离 integration worktree 上 refresh `codex/worktree-triage-integration-20260604` 到 current `main`。
- [x] 只吸收 `231ad0a6 test(core): add missing Makefiles for marshal/template/validation`。
- [x] 跑 3 个对应 focused tests 验证新 Makefile 可用。
- [x] 删除 3 条已经完成价值审计的源分支。
- [x] 删除临时 integration refresh worktree。

### Current Verdict

- `codex/platform-host-ffi-wave15-helper-names`
  - 不合入。
  - 依据：current `core/docs/platform-host-ffi-gap-matrix.md` 与
    `core/docs/platform-ffi-source-evidence-index.md` 已明确 Wave 15 修正方向为
    “host/shared .ffi 只保留 raw external declarations”；该分支的 host helper rename
    方向已被文档明示 superseded。
  - 处理：删除 branch ref，不保留代码。
- `worktree-json-yaml-coverage`
  - 不合入。
  - 依据：用 current `main` 对比后，branch 在 `json`/`yaml block` 两个测试文件上已无净增量，
    并且在 `test_yaml_builder.lpr` 上反而落后于主线，缺少
    `TestBuildOwnsQuotedSpecialStrings` 当前覆盖。
  - 处理：删除 branch ref，不保留代码。
- `codex/platform-pty-integration`
  - 只保留 `231ad0a6 test(core): add missing Makefiles for marshal/template/validation`。
  - `1cf558e2 test(regex): avoid duplicate split edge case test name` 不保留：
    current `main` 已有 `TestSplitEdgeCases2`，该提交只做命名换皮，没有行为或覆盖净增量。
  - 处理：把 `231ad0a6` 吸收到 `codex/worktree-triage-integration-20260604`，随后删除
    `codex/platform-pty-integration` branch。
- integration queue 当前已 refresh 到 current `main`，相对 `main` 保留 7 个待主线吸收提交：
  - `9c96305b`
  - `83c6a83b`
  - `1e2bea56`
  - `89b9944f`
  - `bc046e86`
  - `ab1813a1` merge main refresh
  - `e1444c77`

### Constraints

- root `main` worktree 仍有用户/同事的编译器与 planning 脏改动，不直接移动 `main` ref。
- 编译器 live lane 仍不在本轮范围内：
  - `codex/compiler-truth-audit-main-20260603`
  - `fix/sema-include-resolver`
- 当前代码保全锚点是 `codex/worktree-triage-integration-20260604`，不是脏 root `main`。

## Active Session: 2026-06-04 C5 var-param call validation closeout

### Goal

确认当前 `C5` 结构化 call/by-ref 改动的真实状态，避免把 stale stage0 编译器造成的假红点误判成新的编译器语义 bug。

### Checklist

- [x] 重新读取设计规范、目标树、当前 `/plan` 文件，并把本轮范围收束在 compiler 主线。
- [x] 用 fresh focused tests 复核 ordinary member / virtual / interface / direct `var`-param structured call 覆盖。
- [x] 复现 `examples/smoke/llvm_var_param.pas`，确认旧 `EXIT:102` 仍存在于 stale stage0 二进制。
- [x] 运行 fresh `bash scripts/rebuild-compiler.sh`，排除 stale PPU / stale bootstrap 干扰。
- [x] 用 fresh rebuilt stage0 重新 build+run `llvm_var_param`，确认真实结果。
- [ ] 同步 `progress.md` / `findings.md`，清理临时 debug harness，并做 path-limited commit。

### Current Verdict

- 当前 `compiler/` 工作树里的 `var`-param structured call 改动已经能通过 focused tests：
  - `compiler/tests/test_hir_builder_expr_fallback` -> `EXIT:0`
  - `compiler/tests/test_semantic_hir_expr_producer` -> `EXIT:0`
- `examples/smoke/llvm_var_param.pas` 是本轮新增的真实 smoke 扩展，用来覆盖：
  - direct free-function `var` class param
  - ordinary member statement call `var` class param
  - virtual statement call `var` class param
  - interface statement call `var` class param
- 旧结论 `EXIT:102` 不是新的语义回归，而是 stale bootstrap compiler 误导：
  - 旧 `.sisyphus/tmp/stage0-bootstrap/nextpas` 生成的 IR 仍包含
    `call i64 @TNodeHelper.ClearNode(ptr %v58, ptr %v59)`，其中 `%v59` 是错误的 loaded value
  - fresh `bash scripts/rebuild-compiler.sh` 之后，stage0 输出 `45315 lines compiled`
  - 用 fresh rebuilt stage0 再跑 `llvm_var_param`，程序退出码为 `7`
  - fresh IR 已改成 `call i64 @TNodeHelper.ClearNode(ptr %v58, ptr %v2)`，第二个参数变回 caller slot address
- 本轮因此不再继续对 `llvm_var_param` 做生产代码扩张；下一步应基于 fresh gate 识别 `C5 -> C6/C8` 的下一个真实阻塞，而不是围绕已消失的假红点空转。

## Active Session: 2026-06-04 compiler truth absorb live verification and recategorization

### Goal

把编译器清理线从“初步分类”推进到“带 fresh gate 证据的分类”，确认当前单线升级候选是否应收敛到
`codex/compiler-truth-absorb-20260604`，并明确哪些原始分支还不能删。

### Checklist

- [x] 重新检查 live worktree / branch / archive tag 状态，确认 `compiler-truth-integration` 已安全归档清理。
- [x] 在 `codex/compiler-truth-absorb-20260604` fresh 跑 `make rebuild-compiler`。
- [x] 在 `codex/compiler-truth-absorb-20260604` fresh 跑 `bash build/verify_local.sh`，确认当前 full gate 真失败点。
- [x] 重新比较 `codex/compiler-truth-audit-main-20260603` 与 `codex/compiler-truth-absorb-20260604` 的 `git cherry` / diff。
- [x] 基于 live 证据刷新 6 条目标线的分类。
- [ ] 把 `build/verify_local.sh` 里 `llvm_var_param` 预期值修正提交成 absorb 候选线的干净 follow-up。
- [ ] 逐提交判定 `codex/compiler-truth-audit-main-20260603` 仍未 patch-equivalent 的 audit-only 提交是吸收、丢弃还是保留。
- [ ] 设计把 absorb 候选安全带回真实 `codex/compiler-c8-np-allocator-20260604` 的方案，不触碰其当前 dirty WIP。

### Current Verdict

- `codex/compiler-truth-integration-20260604-main0915`
  - 已完成安全处理：
    - archive tag：`archive/compiler-truth-integration-20260604-main0915`
    - branch / worktree：已删除
  - 它不再是后续 merge 候选，而是历史保全锚点。
- `codex/compiler-truth-absorb-20260604`
  - 当前是唯一带 fresh 编译器 gate 证据的升级候选线。
  - fresh `make rebuild-compiler`：
    - `48332 lines compiled`
  - fresh `bash build/verify_local.sh`：
    - compiler / HIR / stage0 / platform / sync 路径继续通过
    - 当前失败点收敛到：
      - `failure-kind=rtl-sysutils-run-failed`
      - `rtl/core/sysutils/np_sysutils_test.pas`
      - 7 条旧红：
        - `ExtractFileDir trailing slash`
        - `Include delimiter empty`
        - `FileExists existing file`
        - `ExpandFileName starts with /`
        - `Now returns reasonable date after 2009`
        - `ExtractFileDir single-level path`
        - `ExtractFileDir root`
  - 这说明 absorb 线已经越过当前 compiler/stage0/toolchain gate；full gate 现在卡在独立的 `rtl/sysutils` 旧红，而不是新 compiler regression。
  - 当前 worktree 仍有 1 个未提交改动：
    - `build/verify_local.sh`
    - 内容是把 `llvm_var_param` 期望 exit 纠正回 fresh truth `7`
- `codex/compiler-c8-np-allocator-20260604`
  - 仍是有价值主线，但不能直接移动 branch ref：
    - live worktree 仍 dirty
    - 含 `compiler/sema`、`compiler/syntax`、`compiler/toolchain`、tests 与 target facade 的未提交 / 未跟踪 WIP
  - 在 absorb 线整理稳定前，不应直接回写这条真实 C8 线。
- `codex/compiler-truth-audit-main-20260603`
  - 不能因为 absorb 已存在就直接降级成“可删”。
  - fresh `git cherry` 显示：
    - 很多 committed truth 已被 absorb 以新 commit 形式重放
    - 但仍有一批 audit 提交没有形成 patch-equivalent，需要逐提交复核
  - 在这一步做完前，这条线应继续保留。
- `fix/sema-include-resolver`
  - 仍未完成当前 `C8` imported/include truth 的 live 对照，继续保留在“待继续审查”。
- `backup/accidental-mixed-commit-20260603` / `backup/sema-no-matching-overload-before-rebase`
  - 继续维持 archive 倾向，不进入主线吸收。

### Refreshed Classification

- 已合并可删：
  - 当前剩余 live 目标线里暂无。
- 有价值但需要整理后合并：
  - `codex/compiler-truth-absorb-20260604`
  - `codex/compiler-c8-np-allocator-20260604`
- 实验 / 不建议合并但要 archive：
  - `backup/accidental-mixed-commit-20260603`
  - `backup/sema-no-matching-overload-before-rebase`
  - `codex/compiler-truth-integration-20260604-main0915`：已 archive 并清理完成
- 不确定，需要继续审查：
  - `codex/compiler-truth-audit-main-20260603`
  - `fix/sema-include-resolver`

### Route Position

- 当前总路线图位置：
  - `C6-A / C8-F`
- 当前这轮复盘后的最佳动作：
  - 先把 absorb 候选线收成干净 commit
  - 再做 `truth-audit` 剩余未等价提交的逐提交判定
  - 最后才处理真实 C8 dirty 线的安全回流
