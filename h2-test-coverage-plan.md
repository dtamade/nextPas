# H2 单元测试全覆盖 + 基准方案

## 现状概览

| 文件 | 行数 | 现有测试 | 缺口 |
|---|---|---|---|
| types.pas | 578 | 9 | 大量 validation 错误路径、负测试 |
| frame.pas | 678 | 13 | 帧类型完整解码/编码、padding variants |
| stream.pas | 747 | 5 | ⚠️ 最严重，仅有 5 个 |
| session.pas | 1441 | 23 | 连接生命周期、error paths |
| client.pas | 1463 | 15 | retry、连接错误、流控 edge cases |
| hpack.pas | 661 | 9 | 动态表协商、编码器边缘 |
| huffman | 649 | 18 | 相对较好 |
| **总计** | **~6217** | **~80** | **缺口 ~200+ 测试** |

## Phase 1: 深挖单元测试

### 目标覆盖率
每 25 行源码至少 1 个测试 → ~250 个测试

### 逐文件方案

#### 1. stream.pas (747 lines, 5→30 tests) — 最高优先级
- 状态转换全覆盖：idle→open→half-closed→closed 所有合法/非法路径
- trailers 接收验证
- IH2StreamControl.Reset 的正确行为
- padding 帧解码（HEADERS_PADDED, DATA_PADDED）
- 多段 CONTINUATION 帧组装
- send/receive 窗口同时耗尽 + WINDOW_UPDATE 恢复
- EndStreamReceived + EndStreamSent + ResetReceived 所有组合
- 构造函数/析构函数零值安全

#### 2. types.pas (578 lines, 9→30 tests)
- TH2FlowState: 负值窗口操作、溢出、TryReserve/ReleaseReserved/CommitSend 不匹配
- TH2Settings: Validate() 失败的每种输入
- TH2ClientTransportOptions.Validate(): 非法 PoolSize、负 Timeout、超限 WindowSize
- TH2ServerTransportOptions.Validate(): MaxBodySize 超限、非法 IdleTimeout
- ToSettings() 的 EnablePush 一致性
- ApplyPeerSettings 字段级验证

#### 3. frame.pas (678 lines, 13→35 tests)
- H2ValidateFrame 每个帧类型的正确/错误输入（DATA, HEADERS, PRIORITY, RST_STREAM, SETTINGS, PUSH_PROMISE, PING, GOAWAY, WINDOW_UPDATE, CONTINUATION）
- 有 padding 的 DATA/HEADERS 帧解码
- HEADERS_PRIORITY 5 字节前缀
- GOAWAY DebugData 边界
- WINDOW_UPDATE 零值是 PROTOCOL_ERROR
- WINDOW_UPDATE (H2_MAX_WINDOW_SIZE) 溢出校验
- PING ACK 标志
- H2EncodeFrame payload 长度超限（>2^24-1）
- 帧头部保留位 masking 验证
- 单字节/空 payload 帧边界

#### 4. session.pas (1441 lines, 23→55 tests)
- Preface 校验的每种错误模式
- SETTINGS 协商：无效 identifier、无效 payload 长度、重复 ACK
- MaxConcurrentStreams 超限拒绝
- Frame 解码失败 → 连接关闭
- 非法帧序列（HEADERS 前发 DATA、CONTINUATION 前发 HEADERS 等）
- 超大 header block（>MaxHeaderListSize）
- RST_STREAM on idle stream
- GOAWAY 后新流拒绝
- PING 超时
- trailers 完整流程：接收 + 不覆盖请求头
- stream 上发生错误后剩余 frame 处理
- connection flow control 发送 WINDOW_UPDATE 时机
- idle stream frame 分类
- Run() 的 Accept/HandleConnection lifecycle

#### 5. client.pas (1463 lines, 15→55 tests)
- Connection timeout 超时断开
- 服务端返回非法响应解码失败
- HPACK 编码失败
- Pool 边界：MaxPoolSize=0、MaxPoolSize=1、池满关闭
- 幂等重试的每种路径
- 重试时 body rewind 正确性
- SETTINGS_MAX_FRAME_SIZE 变更后发送 chunk 大小调整
- GET 无 body、POST 小 body、POST 大 body（分块）
- 连接关闭后 RoundTrip 抛错
- 服务端 GOAWAY + 连接关闭
- 多个 RoundTrip 流 ID 单调递增
- PingTimeout 触发
- 需要继续读未完成响应时连接断开
- ENABLE_PUSH False 收到 PUSH_PROMISE 拒绝

#### 6. hpack.pas (661 lines, 9→30 tests)
- THPackEncoder 索引引用未索引的 header
- THPackEncoder 动态表溢出自动驱逐
- SETTINGS_HEADER_TABLE_SIZE 动态变更驱逐
- 解码器拒绝超出 MaxDynamicTableSize
- 编码器/解码器空 header list
- huffman 解码无效 pad
- Huffman EOS 符号解码
- 大动态表（>4096）驱逐顺序
- 编码后解码 roundtrip 一致性

## Phase 2: 基准测试

### 需要哪些基准
1. **HPACK 编码/解码吞吐** — 不同大小 header list 编码后解码的 ops/sec
2. **帧编解码吞吐** — 编解码 N 帧/秒
3. **H2 客户端 RoundTrip 延迟** — 完整请求-响应周期 latency
4. **H2 服务端吞吐** — 并发请求处理速率
5. **流控窗口管理** — 小窗口/大窗口下吞吐比较
6. **WINDOW_UPDATE 每 N 帧** — 流控帧频率 vs 内存

### benchmark 工程结构
```
core/tests/nextpas.core.http/bench_http_h2_hpack/
    Makefile, bench_http_h2_hpack.lpr
core/tests/nextpas.core.http/bench_http_h2_frame/
    Makefile, bench_http_h2_frame.lpr
core/tests/nextpas.core.http/bench_http_h2_session/
    Makefile, bench_http_h2_session.lpr
```

### 基准报告格式
每个基准输出：ops/sec、ns/op、bytes/op、allocs/op

执行顺序：先补单元测试（Phase 1），再做基准（Phase 2）。Phase 1 按 coverage 缺口从大到小：stream → types → frame → hpack → client → session。
