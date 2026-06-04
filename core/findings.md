# Findings: Static MIME case-insensitive contract

## Scope

本轮补齐 `ServeFile` / `ServeDir` 的 helper-level MIME coverage。静态资源 helper
已经通过 facade 公开，MIME 推断不应因为扩展名大小写不同而退化成
`application/octet-stream`。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_static` 新增 `ServeDir MIME case-insensitive and fallback` 后首次
focused gate 失败：

- `10 total, 9 passed, 1 failed`
- failure: `uppercase JSON extension maps to application/json`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `MimeTypeFromExt` 对扩展名大小写敏感，`.JSON` 会误走 fallback。

### 2. 最小修复

`nextpas.core.http.static.MimeTypeFromExt` 现在先对扩展名调用 `LowerCase`，再进入
既有 MIME table。未知扩展名仍保持 `application/octet-stream` fallback。

### 3. Focused proof

`test_http_static` 现在同时覆盖：

- `ServeFile` / `ServeDir` 既有文件内容、Content-Type、Content-Length、missing file。
- path traversal / absolute path rejection。
- uppercase `.JSON` MIME case-insensitive mapping。
- unknown extension safe fallback。

## Remaining gaps / risks

- 本轮不扩大 MIME table，只修正匹配语义。
- 当前 static helper 仍以 `ReadFileText` 读取内容；二进制大文件 streaming / range request
  属于后续性能与生产化增强，不在本切片。
- 后续如果把更多 static helper API 公开，应补相应 helper-level focused tests。
