# Task Plan: HTTP keep-alive tail policy bridge proof

## Goal

补一条能支撑 keep-alive request-tail policy decision 的 bridge proof：

- `chunked + trailer + partial follow-up request line`
- 在后续字节补全时，第二个请求可以合法完成
- 因而 transport 不能把这类 partial tail 过早视为 malformed

## Checklist

- [x] 确认本轮只处理 HTTP 目标路径。
- [x] 新增 parser bridge proof。
- [x] 新增 server bridge proof。
- [x] 只跑 `test_http_h1parser`、`test_http_server`。
- [x] 记录 direct GREEN / 是否需要生产修复。
- [x] 最小更新 coverage 与控制文件。
- [ ] path-limited commit。

## Result

- 首轮 direct GREEN。
- 本轮没有生产代码改动。
