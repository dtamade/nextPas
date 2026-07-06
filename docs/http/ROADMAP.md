# nextpas.core.http 路线图

> **更新**: 2026-07-06
> **状态**: 活跃开发

---

## 当前状态

- **协议**: HTTP/1.1 + HTTP/2 双协议完整实现
- **客户端**: 连接池、重试、重定向、超时
- **服务器**: 线程池、路由、中间件、WebSocket、静态文件
- **TLS**: ALPN 协商、证书验证、多后端支持
- **测试**: 31 套件 ~1400+ 测试，0 内存泄漏
- **性能**: 快速路径零分配、llhttp 绑定

---

## Phase 1: 协议完善 (当前)

### 1.1 HTTP/1.1 解析器强化

- [x] llhttp FFI 绑定
- [x] 请求/响应双模式解析
- [x] Chunked 编解码
- [x] Connection: close 响应尾部检测
- [x] Same-read 响应尾部检测 (response parser pause)
- [ ] 分块 trailer 完整验证
- [ ] 100 Continue 完整流程

### 1.2 HTTP/2 协议完善

- [x] 帧编解码
- [x] HPACK 头压缩
- [x] 流状态机
- [x] 流控窗口
- [ ] 服务器推送 (Server Push)
- [ ] 优先级树
- [ ] ALPS (Application-Layer Protocol Settings)

---

## Phase 2: 客户端增强

### 2.1 HTTP/2 多路复用客户端

- [ ] 单连接多流复用
- [ ] 流优先级调度
- [ ] 连接级流控
- [ ] GOAWAY 优雅降级

### 2.2 请求管理

- [ ] 请求取消 (AbortController 等价)
- [ ] 请求超时 per-request
- [ ] 请求重试策略 (指数退避)
- [ ] 断点续传 (Range 请求)

### 2.3 连接管理

- [ ] 连接预热 (pre-connect)
- [ ] 连接健康检查 (HTTP/2 PING)
- [ ] Happy Eyeballs (IPv4/IPv6 并行)
- [ ] 代理支持 (HTTP/SOCKS5)

---

## Phase 3: 服务器增强

### 3.1 HTTP/2 服务器

- [ ] 服务器推送
- [ ] 流优先级处理
- [ ] 连接级流控
- [ ] GOAWAY 发送

### 3.2 生命周期管理

- [ ] Graceful shutdown (drain 进行中请求)
- [ ] 连接限制 (最大并发连接数)
- [ ] 请求速率限制
- [ ] 慢速攻击防护 (Slowloris)

### 3.3 中间件扩展

- [ ] 速率限制中间件
- [ ] 请求体大小限制中间件
- [ ] 压缩中间件 (gzip/brotli)
- [ ] 会话管理中间件
- [ ] CSRF 防护中间件

---

## Phase 4: 性能优化

### 4.1 解析器优化

- [ ] 快速路径扩展 (POST Content-Length)
- [ ] 零拷贝 header 传递
- [ ] SIMD 加速 header 匹配

### 4.2 连接池优化

- [ ] 连接复用率监控
- [ ] 自适应池大小
- [ ] 连接预创建

### 4.3 内存优化

- [ ] 响应体流式处理 (不缓冲整个 body)
- [ ] 大文件零拷贝 (sendfile)
- [ ] Arena 分配器集成

---

## Phase 5: 生态集成

### 5.1 OpenAPI / Swagger

- [ ] 路由自动生成 OpenAPI spec
- [ ] 请求/响应 schema 验证
- [ ] Swagger UI 集成

### 5.2 gRPC

- [ ] HTTP/2 trailer 支持
- [ ] Protobuf 序列化集成
- [ ] 流式 RPC

### 5.3 WebSocket 增强

- [ ] WebSocket 压缩 (permessage-deflate)
- [ ] WebSocket 心跳
- [ ] WebSocket 广播

---

## 里程碑

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| M1 | HTTP/1.1 完整实现 | ✅ 完成 |
| M2 | HTTP/2 核心协议 | ✅ 完成 |
| M3 | 客户端连接池 | ✅ 完成 |
| M4 | 服务器路由+中间件 | ✅ 完成 |
| M5 | TLS 集成 | ✅ 完成 |
| M6 | 安全加固 | ✅ 完成 |
| M7 | HTTP/2 多路复用客户端 | 📋 计划中 |
| M8 | Graceful shutdown | 📋 计划中 |
| M9 | 性能优化 | 📋 计划中 |
| M10 | 生态集成 | 📋 计划中 |
