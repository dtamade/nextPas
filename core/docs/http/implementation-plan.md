# HTTP 推迟项实施计划

**开始日期**: 2026-07-06
**目标**: 完成 P3-10 WebSocket 客户端 + P3-11 模糊测试 + P3-7 HTTPS 重定向测试
**总工作量**: 28h

---

## Phase 1: WebSocket 客户端 ✅ (2026-07-06)

### 1.1 修改 TWebSocketImpl 支持客户端模式 ✅
- 添加 `FIsClient: Boolean` 字段
- 修改 `WriteFrame`: 客户端模式掩码，服务端模式不掩码
- 修改 `ReadFrame`: 客户端模式不验证掩码，服务端模式验证掩码
- 更新构造函数支持 `AIsClient` 参数

### 1.2 实现 ConnectWebSocket 函数 ✅
- 解析 URL 获取 host/port/path
- 建立 TCP 连接 (ws://) 或 TLS 连接 (wss://)
- 生成 16 字节随机 Sec-WebSocket-Key
- 发送升级请求
- 读取响应，验证 101 状态码
- 验证 Sec-WebSocket-Accept 值
- 返回 IWebSocket 接口

### 1.3 URL 解析 + 连接建立 ✅
- 使用 TUrl.Parse 支持 ws:// 和 wss://
- 处理默认端口 (ws://80, wss://443)

### 1.4 测试编写 ✅
- WebSocket client echoes text
- WebSocket client handles ping/pong
- WebSocket client rejects invalid scheme
- 3 tests, 0 leaks

### 1.5 文档更新 ✅
- 更新 CONTRACT.md
- 更新 GOAL_TREE.md

**交付物**:
- `core/src/nextpas.core.http.websocket.pas` (修改)
- `core/src/nextpas.core.http.pas` (修改)
- `core/tests/nextpas.core.http/test_http_websocket_client/` (新增)
- 文档更新
- 客户端握手成功 (ws://)
- 客户端握手失败 (非 101)
- 客户端掩码帧验证
- 服务器不掩码帧验证
- Ping/Pong 心跳
- Close 握手
- wss:// TLS 连接
- 并发客户端

### 1.5 文档更新 (1h)
- 更新 CONTRACT.md
- 更新 README.md
- 更新 GOAL_TREE.md

**交付物**:
- `core/src/nextpas.core.http.websocket.pas` (修改)
- `core/tests/nextpas.core.http/test_http_websocket_client/` (新增)
- 文档更新

---

## Phase 2: 模糊测试 (8h) - 进行中

### 2.1 实现 TFuzzMutator (2h)
- FlipBits: 随机翻转 1-4 位
- InsertBytes: 随机位置插入 1-16 字节
- DeleteBytes: 随机删除 1-16 字节
- ReplaceBytes: 随机替换 1-16 字节
- 边界值替换: 0x00, 0xFF, 0x7F, 0x80

### 2.2 实现 TFuzzRunner (2h)
- RunHttpParserFuzz: HTTP 请求/响应 fuzz
- RunWebSocketFuzz: WebSocket 帧 fuzz
- 统计崩溃/泄漏次数

### 2.3 种子语料库 (1h)
- HTTP 请求种子 (GET, POST, PUT, DELETE)
- HTTP 响应种子 (200, 301, 404, 500)
- WebSocket 帧种子 (text, binary, ping, pong, close)

### 2.4 测试编写 (2h)
- HTTP parser fuzz - 1000 iterations
- HTTP response fuzz - 1000 iterations
- WebSocket frame fuzz - 1000 iterations

### 2.5 文档更新 (1h)
- 更新 GOAL_TREE.md

**交付物**:
- `core/src/nextpas.core.http.fuzz.pas` (新增)
- `core/tests/nextpas.core.http/test_http_fuzz/` (新增)
- 文档更新

---

## Phase 3: HTTPS 重定向测试 (9h)

### 3.1 修改 THttpClient 支持 https (3h)
- 解析 URL scheme
- 如果是 https://，建立 TLS 连接
- 使用 TLS 连接发送 HTTP 请求
- 处理证书验证

### 3.2 Mock TLS 服务器 (2h)
- 创建自签名证书上下文
- 启动 TLS 服务器
- 处理 TLS 握手

### 3.3 测试编写 (3h)
- http→https 重定向 (301/302)
- https→http 重定向 (301/302)
- https→https 重定向 (301/302)
- 重定向循环检测
- 重定向次数限制
- TLS 证书验证

### 3.4 文档更新 (1h)
- 更新 GOAL_TREE.md

**交付物**:
- `core/src/nextpas.core.http.client.pas` (修改)
- `core/tests/nextpas.core.http/test_http_https_redirect/` (新增)
- 文档更新

---

## 验证标准

### 每个 Phase 完成时
- [ ] 所有测试通过
- [ ] 0 内存泄漏 (heaptrc)
- [ ] `git diff --check` 通过
- [ ] `make hygiene` 通过
- [ ] 文档更新完成

### 整体完成时
- [ ] 21 套件 ~630 pass + 新增测试
- [ ] 0 泄漏
- [ ] 所有推迟项完成
- [ ] 调研报告验收标准全部勾选

---

## 风险缓解

| 风险 | 缓解措施 |
|------|---------|
| WebSocket 帧掩码错误 | 严格遵循 RFC 6455 §5.3，参考现有服务端实现 |
| Fuzzer 发现 parser 崩溃 | 修复发现的问题，添加到测试用例 |
| TLS 集成复杂度 | 使用现有 TLS 基础设施，参考 H2 TLS 集成 |
| 测试环境不稳定 | 使用 mock 服务器，避免外部依赖 |

---

*计划制定: 2026-07-06*
*执行人: Claude (AI)*
