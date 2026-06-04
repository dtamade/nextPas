# Task Plan: WebSocket fragmented UTF-8 text sequence acceptance

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
允许 text message 的 UTF-8 byte sequence 跨 frame fragmentation 边界拆分；server-side
`ReadFrame` 不应在首个 `FIN=0` text frame 上按单帧 UTF-8 误拒绝，而应在 final
continuation 到达后校验累计 text message。

要求：

- 先 RED：`FIN=0 text #$C3` + final continuation `#$A9` 当前被首片 UTF-8 校验误拒。
- GREEN：`ReadFrame` 对 fragmented text 累计 payload，在 final continuation 校验整体 UTF-8。
- handler 在两个 frame 都读到后可返回正常 text response。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket fragmented data-frame policy 缺口。
- [x] 在 `test_http_websocket` 写 RED：合法跨片 UTF-8 text sequence 不应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 fragmented text 累计 UTF-8 校验。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.websocket.pas`
- `tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr`

## Intended outcome

- 合法的 fragmented UTF-8 text sequence 不再因首片不完整而被拒绝。
- handler 可连续读取首片 text 与 final continuation，并返回正常 text response。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection、reserved opcode rejection、fragmented control-frame rejection、invalid close-code rejection、invalid UTF-8 rejection 保持不变。
