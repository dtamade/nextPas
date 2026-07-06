# nextpas.core.http 变更日志

## 2026-07-06: Response Parser Pause + Same-Read Tail Detection

### 修复

- **Response parser pause**: `CbOnMessageComplete` 移除 `FParserType=ptRequest` 门控，response parser 在 keep-alive 连接上也暂停，防止消费后续响应
- **Same-read tail 检测**: 当 server 在同一 TCP segment 发送两个响应时，`FPending` 正确保留未消费字节，`LHasResponseTail=true` 阻止连接池化
- **信息响应保留**: 1xx 跳过路径不再丢弃 `LPending`，确保后续响应不丢失

### 改动

- `core/src/nextpas.core.http.impl.h1.parser.pas`: 移除 `FParserType=ptRequest` 条件
- `core/src/nextpas.core.http.impl.h1.pas`: 添加 `FPending` 字段，修改 `ReadResponse` 使用实例变量

### 测试

- 18 套件 599 pass / 7 fail (预存 source contract ENOENT) / 0 leak
- `Client drops pooled connection with same-read response tail`: ✅ 通过

---

## 2026-07-05: IPv4 Byte Order + H1 Parser Connection:close

### 修复

- **IPv4 字节序**: `platform_sockaddr_from_ipv4` 添加 `htonl`，`platform_sockaddr_to_ipv4` 添加 `ntohl`，`platform_ipv4_to_string` 修正八位组顺序
- **Connection:close 响应**: response parser 的 `HPE_CLOSED_CONNECTION` 处理容忍额外数据
- **Chunked trailer**: 回退 `HPE_PAUSED` "data after close" 检查

### 改动

- `core/src/nextpas.core.platform.socket.pas`: 4 处 htonl/ntohl + 2 处 ipv4_to_string 修正
- `core/src/nextpas.core.http.impl.h1.parser.pas`: HPE_CLOSED_CONNECTION 区分 request/response

### 测试

- 从 ~461 pass / ~70 fail 改善到 687 pass / 1 fail

---

## 2026-07-04: 初始 HTTP 模块

### 功能

- HTTP/1.1 完整实现 (llhttp 绑定)
- HTTP/2 核心协议 (帧、HPACK、流、会话)
- 客户端 (连接池、重试、重定向)
- 服务器 (线程池、路由、中间件)
- TLS 集成 (ALPN 协商)
- WebSocket 升级
- 静态文件服务
- 安全防护 (请求走私、Host 注入、路径遍历、Header 注入)

### 测试

- 31 套件 ~1400+ 测试
