# Platform 和 HTTP 模块开发实践总结

> 创建时间：2026-07-11
> 目的：学习成熟模块的开发实践，指导 core-net-async-io 模块改进

## 一、Platform 模块开发实践

### 1. 核心设计原则

#### 1.1 分层架构
```
L0: platform.* (仅依赖 FPC RTL)
    ├── platform.base/posix/unix/windows.*  ← 原始 FFI 层
    └── platform.io/fs/socket/sync.*       ← 特性语义层
```

**关键分离**：
- **原始 FFI 层**：`platform.<host>.base` 和 `platform.<host>.ffi` 拥有原始 ABI 声明
- **特性语义层**：拥有可移植语义、错误折叠、资源所有权

#### 1.2 真相分层 (Truth Tiers)
```pascal
| Tier            | 证据                     | 可以声称                     |
|-----------------|--------------------------|------------------------------|
| source-contract | 静态/聚焦源码守卫        | 所有者边界或源码形状已锁定   |
| forced-compile  | 强制目标编译通过         | 符号/类型/使用编译一致       |
| focused-runtime | 真实主机上的聚焦行为门禁 | 命名路径在该主机上工作       |
| ci-matrix       | CI 跨主机/架构重复运行   | 运行时真相对这些条目持久     |
```

**核心规则**：没有真实运行时证据，主机就不能声称运行时就绪。

#### 1.3 错误处理策略
```pascal
// ✅ 所有平台调用返回 Int32 错误码，不抛异常
function platform_file_open(...): Int32;  // 0 = 成功，正数 = errno

// 错误码常量
PLATFORM_ERR_INVALID (22)     — 无效参数/nil 指针
PLATFORM_ERR_ENOENT (2)       — 文件不存在
PLATFORM_ERR_UNSUPPORTED (95) — 不支持的操作
```

### 2. 开发最佳实践

#### 2.1 资源管理 (RAII 模式)
```pascal
// ✅ 及时关闭资源
var
  LFile: TPlatformFileHandle;
begin
  LFile := platform_file_open(...);
  if LFile.Value <> PLATFORM_INVALID_HANDLE then
  begin
    try
      // 使用资源
    finally
      platform_file_close(LFile);
    end;
  end;
end;

// ✅ 使用守卫模式管理锁
var
  LGuard: ILockGuard;
begin
  LGuard := TLockGuard.Create(FMutex);
  // 临界区代码 - 离开作用域自动解锁
end;
```

#### 2.2 线程安全
```pascal
// ✅ 平台原语本身线程安全
// ✅ 同步原语遵循 POSIX 语义
// ✅ 除非特别标注，platform_* 函数均为线程安全
// ✅ 同一句柄不可并发操作
```

#### 2.3 内存管理
```pascal
// ✅ 平台句柄由调用方负责关闭
// ✅ mmap 映射由调用方负责 platform_mmap_unmap
// ✅ aligned_alloc 由调用方负责 platform_aligned_free
// ✅ 测试构建启用 heaptrc，0 unfreed 为通过标准
```

### 3. 测试策略

#### 3.1 测试覆盖
- **88 个测试套件**
- **跨平台覆盖**：Linux/macOS/Windows/FreeBSD/Android
- **质量门禁**：heaptrc、nil guard、边界值、跨平台

#### 3.2 测试结构
```
core/tests/nextpas.core.platform.*/
├── test_platform_io/          # 文件 I/O
├── test_platform_files/       # 文件操作
├── test_platform_fs/          # 文件系统
├── test_platform_process/     # 进程管理
├── test_platform_thread/      # 线程管理
├── test_platform_sync/        # 同步原语
├── test_platform_socket/      # 网络
└── ...
```

### 4. 文档体系

#### 4.1 核心文档
```
core/docs/platform/
├── CONTRACT.md              # 代码契约（接口、不变量、错误处理）
├── BEST-PRACTICES.md        # 最佳实践
├── API-REFERENCE.md         # API 参考
├── GOVERNANCE-PLAN.md       # 治理计划
├── ROADMAP.md               # 路线图
├── TEST-COVERAGE-REPORT.md  # 测试覆盖报告
└── USABILITY-ASSESSMENT.md  # 可用性评估
```

#### 4.2 文档特点
- **契约驱动**：每个模块有明确的代码契约
- **证据分层**：每个状态声明必须有证据支撑
- **持续更新**：文档与代码同步更新

---

## 二、HTTP 模块开发实践

### 1. 核心设计原则

#### 1.1 统一门面 + 协议实现隔离
```pascal
// 消费方只需 uses nextpas.core.http 即可获得完整 HTTP 能力
uses
  nextpas.core.http;  // 自动获得 H1/H2 能力

// 默认版本解析对应用层透明
// 显式注入优先于 registry 默认解析
NewHttpClient([Transport][, Options]);
NewHttpServer(Handler[, Transport][, Options]);
```

#### 1.2 分层架构
```
L3: http.* (依赖 L0-L2: net, tls, json)
├── http.base/headers/request/response  ← 基础类型
├── http.client/server                  ← 传输抽象
├── http.middleware.*                   ← 中间件
├── http.impl.h1.*                     ← HTTP/1.1 实现
├── http.impl.h2.*                     ← HTTP/2 实现
└── http.pas                           ← 门面
```

#### 1.3 协议版本管理
```pascal
// 内建 registry
hvHttp10 / hvHttp11 → H1 transport
hvHttp2 → H2 transport

// 默认版本
client/server 默认版本: hvHttp11

// 扩展 seam
NewHttpClient([Transport][, Options]);  // 显式注入
NewHttpServer(Handler[, Transport][, Options]);
```

### 2. 开发最佳实践

#### 2.1 安全优先
```pascal
// ✅ 所有外部输入必须验证
// ✅ 拒绝 CR/LF/控制字符（允许 HTAB）
// ✅ 大小写不敏感查找（小写存储）
// ✅ 显式 400 拒绝恶意请求

// 安全证明覆盖
- malformed chunk framing
- duplicate Content-Length
- null-byte header
- CRLF injection
- request-line splitting
- negative Content-Length
- very long method
```

#### 2.2 性能优化
```pascal
// ✅ llhttp C 库解析（比 Pascal 实现快 ~10x）
// ✅ SIMD fast path（完整 HTTP/1.1、单 Host、无复杂头）
// ✅ HPACK MRU cache（减少重复头部传输）
// ✅ 连接池复用（避免 TCP 握手开销）
// ✅ TBytes 零拷贝传递（引用计数）
```

#### 2.3 并发模型
```pascal
// ✅ 分层并发
- public layer: 同步、直线型 contract
- foundation runtime: backend 选择、listen/accept/shutdown
- protocol layer: per-connection state object

// ✅ poll-driven session
- reactor 负责 request-side read/parse
- worker 只负责 response production
- completion wake 回到 reactor 后统一 drain

// ✅ 有界响应队列
- active drain + 1 queued response
- 避免打乱 wire 顺序
```

### 3. 测试策略

#### 3.1 测试覆盖
- **31 个测试套件**，~1447 测试
- **18 个纳入 Makefile 门禁**
- **关键覆盖**：HTTP/1.1 解析、HTTP/2 帧、HPACK、keep-alive、chunked、CORS、中间件

#### 3.2 安全证明 (Security Proof)
```pascal
// ✅ 三层聚焦证明
parser → server → security

// ✅ 每个安全边界都有 focused proof
- malformed request: 显式 400
- EOF truncation: 显式 400
- CL-TE conflict: 显式 400
- trailer isolation: 不污染请求头
- oversize trailer: 431 或安全关闭
```

#### 3.3 测试结构
```
core/tests/nextpas.core.http/
├── test_http_h1parser/        # H1 解析器
├── test_http_h1writer/        # H1 写入器
├── test_http_h2_frame/        # H2 帧
├── test_http_h2_hpack/        # HPACK
├── test_http_server/          # HTTP 服务器
├── test_http_security/        # 安全测试
├── test_http_middleware/       # 中间件
├── test_http_websocket/       # WebSocket
└── ...
```

### 4. 文档体系

#### 4.1 核心文档
```
core/docs/http/
├── ARCHITECTURE.md            # 架构设计
├── CONTRACT.md                # 代码契约
├── API_COVERAGE.md            # API 覆盖矩阵
├── BENCHMARKS.md              # 性能基准
├── GOAL_TREE.md               # 目标树
├── inbox.md                   # 当前批次工作
└── ...
```

#### 4.2 文档特点
- **架构驱动**：明确的分层架构和职责边界
- **契约明确**：接口、不变量、错误处理、线程安全
- **证据支撑**：每个状态声明都有测试证据
- **持续演进**：inbox 记录当前工作进展

---

## 三、可借鉴的开发实践

### 1. 架构设计

#### 1.1 分层清晰
```pascal
// ✅ 明确的层级依赖
L0: platform.* (仅依赖 FPC RTL)
L1: async/io/sync.* (依赖 L0)
L2: net/tls/json.* (依赖 L0-L1)
L3: http/websocket.* (依赖 L0-L2)

// ✅ 职责边界清晰
- 原始 FFI 层 vs 特性语义层
- 传输抽象 vs 协议实现
- 公共接口 vs 内部实现
```

#### 1.2 接口设计
```pascal
// ✅ 值类型 vs 引用类型
THttpRequest = record       // 值类型，调用方管理生命周期
IHttpClient = interface     // 引用类型，内部管理连接池

// ✅ 选项对象模式
THttpClientOptions = record // 配置集中管理
THttpServerOptions = record

// ✅ 工厂函数
NewHttpClient([Transport][, Options]);
NewHttpServer(Handler[, Transport][, Options]);
```

### 2. 质量保证

#### 2.1 测试策略
```pascal
// ✅ 多层测试
- 单元测试：每个模块独立测试
- 集成测试：模块间交互测试
- 安全测试：恶意输入处理
- 性能测试：基准测试和对比

// ✅ 质量门禁
- heaptrc: 0 unfreed
- nil guard: 所有指针检查
- 边界值: 0/nil/MAX_INT/-1
- 跨平台: 全平台覆盖
```

#### 2.2 证据驱动
```pascal
// ✅ 真相分层
source-contract → forced-compile → focused-runtime → ci-matrix

// ✅ 每个状态声明必须有证据
- 代码契约：接口、不变量、错误处理
- 测试证据：通过的测试、覆盖率
- 性能证据：基准测试、对比数据
```

### 3. 文档实践

#### 3.1 契约驱动
```pascal
// ✅ 每个模块有明确的代码契约
CONTRACT.md:
- 接口契约：核心接口、API 签名
- 不变量：必须保持的条件
- 错误处理：错误码、异常类型
- 线程安全：并发访问规则
- 内存管理：生命周期、所有权
```

#### 3.2 持续更新
```pascal
// ✅ 文档与代码同步更新
- 变更记录：日期、版本、变更描述
- 版本管理：语义化版本
- 状态追踪：inbox 记录当前工作
```

### 4. 开发流程

#### 4.1 渐进式开发
```pascal
// ✅ 分阶段实现
Phase 1: 基础功能
Phase 2: 高级特性
Phase 3: 性能优化
Phase 4: 质量加固

// ✅ 每个阶段有明确的退出标准
- 测试通过
- 文档完整
- 证据充分
```

#### 4.2 持续改进
```pascal
// ✅ 定期审查
- 代码审查：Codex review
- 架构审查：边界检查
- 安全审查：恶意输入测试
- 性能审查：基准测试对比

// ✅ 技术债务管理
- debt-roadmap.md
- 定期清理
- 优先级排序
```

---

## 四、对 core-net-async-io 模块的启示

### 1. 架构改进

#### 1.1 分层清晰化
```pascal
// 当前状态
async.base/timer/loop/task  ← 异步框架
net.base/intf/tcp/udp       ← 网络层
io.poller                   ← I/O 轮询器

// 建议改进
L1: async.* (异步框架)
├── async.base              ← 基础类型
├── async.timer             ← 定时器
├── async.loop              ← 事件循环
└── async.task              ← 异步任务

L2: io.* (I/O 抽象)
├── io.poller               ← I/O 轮询器
├── io.reactor.*            ← 反应器实现
└── io.completion           ← 完成回调

L2: net.* (网络层)
├── net.base/intf           ← 基础类型和接口
├── net.tcp/udp             ← 传输实现
└── net.server.*            ← 服务器框架
```

#### 1.2 接口设计改进
```pascal
// ✅ 值类型 vs 引用类型
TAsyncTask = record          // 值类型
IAsyncLoop = interface       // 引用类型（建议）

// ✅ 选项对象模式
TAsyncLoopOptions = record   // 配置集中管理
TNetServerOptions = record

// ✅ 工厂函数
NewAsyncLoop([Options]);
NewTcpServer(Handler[, Options]);
```

### 2. 质量保证改进

#### 2.1 测试策略
```pascal
// ✅ 多层测试
- 单元测试：每个模块独立测试
- 集成测试：async + net 协同测试
- 安全测试：恶意输入处理
- 性能测试：基准测试和对比

// ✅ 质量门禁
- heaptrc: 0 unfreed
- nil guard: 所有指针检查
- 边界值: 0/nil/MAX_INT/-1
- 跨平台: 全平台覆盖
```

#### 2.2 证据驱动
```pascal
// ✅ 真相分层
source-contract → forced-compile → focused-runtime → ci-matrix

// ✅ 每个状态声明必须有证据
- 代码契约：接口、不变量、错误处理
- 测试证据：通过的测试、覆盖率
- 性能证据：基准测试、对比数据
```

### 3. 文档改进

#### 3.1 契约驱动
```pascal
// ✅ 创建模块代码契约
core/docs/net-async-io/CONTRACT.md:
- 接口契约：核心接口、API 签名
- 不变量：必须保持的条件
- 错误处理：错误码、异常类型
- 线程安全：并发访问规则
- 内存管理：生命周期、所有权
```

#### 3.2 架构文档
```pascal
// ✅ 创建架构文档
core/docs/net-async-io/ARCHITECTURE.md:
- 分层架构：模块职责和依赖
- 并发模型：线程安全、锁策略
- 性能特征：复杂度、优化点
- 扩展点：插件、中间件
```

### 4. 开发流程改进

#### 4.1 渐进式开发
```pascal
// ✅ 分阶段实现
Phase 1: 基础功能（已完成）
Phase 2: 架构增强（进行中）
Phase 3: 高级特性（计划中）
Phase 4: 质量加固（计划中）

// ✅ 每个阶段有明确的退出标准
- 测试通过
- 文档完整
- 证据充分
```

#### 4.2 持续改进
```pascal
// ✅ 定期审查
- 代码审查：Codex review
- 架构审查：边界检查
- 安全审查：恶意输入测试
- 性能审查：基准测试对比

// ✅ 技术债务管理
- debt-roadmap.md
- 定期清理
- 优先级排序
```

---

## 五、总结

### 1. 核心经验

1. **分层清晰**：明确的层级依赖和职责边界
2. **契约驱动**：每个模块有明确的代码契约
3. **证据驱动**：每个状态声明必须有测试证据
4. **质量优先**：测试覆盖、安全检查、性能优化
5. **文档同步**：文档与代码同步更新

### 2. 关键实践

1. **真相分层**：source-contract → forced-compile → focused-runtime → ci-matrix
2. **安全证明**：三层聚焦证明（parser → server → security）
3. **渐进开发**：分阶段实现，每个阶段有明确退出标准
4. **持续改进**：定期审查、技术债务管理

### 3. 下一步行动

1. **创建模块契约**：`core/docs/net-async-io/CONTRACT.md`
2. **创建架构文档**：`core/docs/net-async-io/ARCHITECTURE.md`
3. **完善测试覆盖**：多层测试、安全测试、性能测试
4. **建立证据体系**：真相分层、测试证据、性能证据

---

*本文档基于 platform 和 http 模块的开发实践总结，旨在指导 core-net-async-io 模块的持续改进。*
