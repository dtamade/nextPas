# nextpas.core.http Goal Tree

HTTP 模块分阶段目标树。每个阶段有明确的退出证据。

## H0 基础类型与接口

- [x] 定义 `THttpMethod`, `THttpVersion`, `THttpStatusCode` 枚举
- [x] 定义 `IHttpHeaders`, `IHttpRequest`, `IHttpResponse` 接口
- [x] 定义 `IHttpHandler`, `IHttpMiddleware`, `IHttpRouter` 接口
- [x] URL 解析 (`TUrl`, authority/host/port/path/query 分解)
- [x] HTTP 头管理 (大小写不敏感查找、多值、token 验证)

Exit evidence: `test_http_base`, `test_http_headers`, `test_http_url`, `test_http_message`

## H1 HTTP/1.1 协议层

- [x] llhttp 绑定 (FFI, 零拷贝解析)
- [x] 请求/响应解析器 (`TH1Parser`, request/response 双模式)
- [x] Chunked 传输编码 (编码+解码+trailer)
- [x] 快速路径解析器 (GET 200 Content-Length 场景零分配)
- [x] 扫描器 (body 边界检测、Connection: close、Transfer-Encoding)
- [x] 写入器 (请求/响应序列化、chunked 编码输出)
- [x] 出站缓冲区 (gather write、flush 策略)

Exit evidence: `test_http_h1parser`, `test_http_h1chunked`, `test_http_h1fast`, `test_http_h1scan`, `test_http_h1writer`, `test_http_h1outbound`

## H2 HTTP/2 协议层

- [x] 帧编解码 (DATA/HEADERS/RST_STREAM/SETTINGS/PING/GOAWAY)
- [x] HPACK 头压缩 (静态表、动态表、Huffman 编码)
- [x] 流状态机 (idle/open/half-closed/closed)
- [x] 会话管理 (流复用、流控、优先级)
- [x] 客户端实现 (ALPN 协商、流创建)
- [x] 服务器实现 (连接接受、流分发)
- [x] TLS 集成 (ALPN h2 协商、TLS 流适配)

Exit evidence: `test_http_h2_frame`, `test_http_h2_types`, `test_http_h2_hpack`, `test_http_h2_hpack_block`, `test_http_h2_stream`, `test_http_h2_session`, `test_http_h2_client`

## H3 客户端

- [x] 连接池 (per-host:port, 空闲检测, 大小限制)
- [x] 重试逻辑 (幂等请求、可回溯 body)
- [x] 重定向跟随 (301/302/303/307/308, 最大次数)
- [x] 超时管理 (连接超时、读写超时)
- [x] Connection: close 检测 (响应尾部、same-read 检测)
- [x] Host 头自动设置
- [ ] HTTP/2 多路复用客户端
- [ ] 请求取消 (AbortController 等价)

Exit evidence: `test_http_client`

## H4 服务器

- [x] 线程池服务器 (`TTcpThreadedServer`)
- [x] 会话管理 (连接生命周期、keep-alive)
- [x] 路由器 (路径匹配、参数提取、方法分发)
- [x] 中间件框架 (洋葱模型、链式调用)
- [x] 内置中间件 (CORS, Logger, Recovery, Timeout)
- [x] 静态文件服务 (MIME 检测、目录列表、条件请求)
- [x] WebSocket 升级
- [x] TLS 服务器 (ALPN h2/http1.1)
- [ ] HTTP/2 服务器推送
- [ ] Graceful shutdown

Exit evidence: `test_http_server`, `test_http_router`, `test_http_middleware`, `test_http_middlewares`, `test_http_static`, `test_http_websocket`

## H5 安全与集成

- [x] 请求走私防护 (Transfer-Encoding 优先级)
- [x] Host 头注入检测
- [x] 路径遍历防护 (静态文件)
- [x] CORS 预检 (OPTIONS 处理)
- [x] Header 注入检测 (CR/LF 防护)
- [x] 集成测试 (端到端请求/响应)
- [ ] 速率限制中间件
- [ ] 请求体大小限制

Exit evidence: `test_http_security`, `test_http_integration`

## H6 性能与基准

- [x] 解析器基准 (llhttp vs 手写)
- [x] 快速路径基准 (GET 200 零分配)
- [x] 连接池基准 (并发复用)
- [x] HPACK 基准 (压缩率 vs 速度)
- [ ] 对标 Go net/http 基准
- [ ] 对标 Rust hyper 基准

Exit evidence: `test_http_benchmarks`

## H7 文档与治理

- [x] 代码契约 (`docs/contracts/http.md`)
- [x] 模块文档体系 (`docs/http/`)
- [ ] API 参考文档
- [ ] 迁移指南 (从 Indy/Synapse)
- [ ] 性能调优指南

Exit evidence: `docs/http/` 完整文档
