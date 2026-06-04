# Task Plan: Static MIME case-insensitive contract

## Goal

继续推进 `HttpServer 完成` 主线中的 static serving public helper 完整性。`ServeFile`
/ `ServeDir` 已经通过 `nextpas.core.http` facade 公开，静态资源 MIME 推断应匹配
常见服务器语义：文件扩展名大小写不敏感，未知扩展名安全回退到
`application/octet-stream`。

要求：

- 先 RED：`.JSON` 这类大小写混合扩展名当前落到 fallback。
- GREEN：扩展名归一化后再匹配 MIME。
- 保持未知扩展名 fallback。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_static` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 static helper-level MIME coverage 缺口。
- [x] 在 `test_http_static` 写 RED：`data.JSON` 应返回 `application/json`。
- [x] 同一 focused test 锁定未知扩展名 fallback 到 `application/octet-stream`。
- [x] 在 `nextpas.core.http.static` 对扩展名做 lowercase 后匹配。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.static.pas`
- `tests/nextpas.core.http/test_http_static/test_http_static.lpr`

## Intended outcome

- `ServeDir` serving `data.JSON` 返回 `content-type: application/json`。
- `ServeDir` serving unknown extension 返回 `content-type: application/octet-stream`。
- 已有 static serving status/content-length/path traversal 行为保持不变。
