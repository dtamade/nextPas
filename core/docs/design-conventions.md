# nextpas.core 设计风格与范式规范

本文档是 nextpas.core 框架的设计基准，所有代码必须遵循此规范。

---

## 1. 命名约定

### 单元命名

- 前缀：`nextpas.core.`
- 风格：dotted namespace，全小写
- 文件名即单元名：`nextpas.core.zip.pas`
- 所有单元名必须使用小写字母（不允许大写）

### 类型前缀

| 前缀 | 用途 |
|------|------|
| `T` | 类（class）、记录（record） |
| `I` | 接口（interface） |
| `E` | 异常（exception） |

### 文件组织

- 所有源码平铺在单一 `src/` 目录下
- `.inc` 文件同样放在 `src/` 目录下
- `.inc` 文件命名跟随所属单元：`nextpas.core.platform.unix.inc`、`nextpas.core.platform.windows.inc`
- `.inc` 用于要求高效实现的地方（平台分支、内联汇编等）
- 要求优雅的地方用多态

---

## 2. 模块结构范式

### 标准形态（三件套 + 实现）

```
nextpas.core.<module>.pas           ← 门面：纯 re-export，不含逻辑
nextpas.core.<module>.base.pas      ← 基本类型定义（record、enum、const、type alias）
nextpas.core.<module>.intf.pas      ← 接口定义（interface 声明）
nextpas.core.<module>.<impl>.pas    ← 实现子模块
```

子模块可递归此范式：

```
nextpas.core.<module>.<sub>.pas
nextpas.core.<module>.<sub>.base.pas
nextpas.core.<module>.<sub>.intf.pas
```

### 依赖方向

```
base ← intf ← 实现 ← 门面(聚合)
```

- `base` 不依赖同模块任何文件（纯数据类型）
- `intf` 依赖 `base`（接口签名需要类型）
- 实现依赖 `intf` + `base`
- 门面 uses 所有子模块，re-export 给外部

### 门面职责

- 门面通过类型别名和 inline 转发函数聚合子模块的公共 API
- FPC 不支持自动 re-export，门面必须显式重新声明类型和函数
- 消费方大多数时候只 `uses nextpas.core.<module>` 即可

```pascal
unit nextpas.core.crypto;
interface
uses
  nextpas.core.crypto.base,
  nextpas.core.crypto.intf,
  nextpas.core.crypto.sha256;

type
  THashAlgorithm = nextpas.core.crypto.base.THashAlgorithm;
  IHasher = nextpas.core.crypto.intf.IHasher;

function Sha256(const AData: TBytes): TBytes; inline;

implementation

function Sha256(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.crypto.sha256.Sha256(AData);
end;

end.
```

### 消费方引用粒度

- 只需类型定义 → 引 `*.base.pas`
- 面向接口编程 → 引 `*.intf.pas`
- 开箱即用 → 引门面

### 模块归属原则

- 不存在孤立的小单元，所有功能归属于某个功能域模块
- 功能域划分遵循通行标准（参考 Rust std、Go 标准库、.NET BCL）

### 范式例外

- `nextpas.core.base` 是根模块，不递归三件套范式（不存在 `nextpas.core.base.base.pas`）
- `nextpas.core.base` 直接作为基础类型定义单元，同时承担 `base` 和门面的角色

### 单元体积指引

- 单个单元文件超过 800 行时应考虑拆分为子模块
- 软性指引，内聚性强的代码可以例外

### 子模块依赖规则

- 同一模块内子模块之间严格单向依赖
- 特殊情况允许：A 在 interface 部分引用 B，B 在 implementation 部分引用 A

---

## 3. 分层规则

### 四层架构

```
L0: 内核 (base, errors, platform, mem, log.intf)
     ↑ bootstrap 阶段只依赖最低限度宿主能力；platform ABI 通过自有 FFI 声明

L1: 基础设施 (bytes, text, encoding, collections, sync, thread, async, io, time, id, testing)
     ↑ 只依赖 L0

L2: 系统能力 (fs, net, tls, dns, crypto, compress, json, yaml, toml, xml, regex, sqlite, pg, process, args, validation)
     ↑ 只依赖 L0-L1

L3: 框架 (log, config, redis, http, websocket, mail, tui, migration, ratelimit, auth, template, metrics, event, job, app)
     ↑ 只依赖 L0-L2
```

### 依赖约束

- 只能向下依赖，不能向上依赖
- 同层内允许单向依赖，禁止循环依赖
- 特殊情况允许 interface/implementation 分区引用打破循环（同子模块规则）

### 特殊依赖关系：encoding / bytes / text

这三个 L1 模块天然紧密协作，采用 interface/implementation 分区引用：

```
encoding (interface 部分 uses bytes, text 的类型)
    ↑
bytes (implementation 部分 uses encoding，提供便利方法)
text  (implementation 部分 uses encoding，提供便利方法)
```

### 层级归属管理

- 每个模块的层级归属在模块注册表中声明
- 后期通过构建脚本自动校验依赖合规性

---

## 4. 接口设计原则

### 错误处理策略

**默认用异常，调用方写直线代码：**

```pascal
// 调用方不需要 try/catch，异常自动传播（等同于 Rust 的 ? 操作符）
Data := ReadFile('/path/to/file');
```

- 异常用于意外情况（编程错误、资源耗尽、违反不变量）
- 边界处统一捕获（HTTP handler 入口、TUI 事件循环入口、main）
- TryXxx 作为便利补充，仅在调用方确实需要区分成功/失败走不同分支时提供
- "无值"用 nil 表达（接口/指针返回 nil），不引入 Result 或 Optional 类型
- 不使用 Result<T,E> 作为错误处理机制（Pascal 无 `?` 操作符，Result 反而增加冗余）

```pascal
// TryXxx：调用方需要显式处理失败分支时使用
if TryParseInt(S, Value) then
  // 成功分支
else
  // 失败分支

// 无值：返回 nil
User := FindUser(Id);  // 找不到返回 nil，不抛异常
if User <> nil then ...
```

### 门面 API 风格

两种形态：

**简单过程/函数 —— 一行搞定：**

```pascal
Compressed := nextpas.core.compress.GzipEncode(Data);
```

**Fluent Builder —— 链式调用：**

```pascal
TZipArchiver.New
  .AddFile('readme.txt', Content)
  .AddFile('data.bin', BinData)
  .SaveToFile('output.zip');
```

### Builder 生命周期

- Builder 对外暴露 interface，走 COM 引用计数自动管理
- 调用方不需要手动释放

---

## 5. 接口设计风格

### 接口粒度

小接口 + 组合接口（Rust trait / Go interface 风格）：

```pascal
// 原子接口：单一能力
IReader = interface
  function Read(var ABuf: TBytes; ACount: SizeUInt): SizeUInt;
end;

IWriter = interface
  function Write(const ABuf: TBytes; ACount: SizeUInt): SizeUInt;
end;

// 组合接口：继承一个父接口，手动包含其他接口的方法
// （FPC interface 只支持单继承）
IStream = interface(IReader)
  function Write(const ABuf: TBytes; ACount: SizeUInt): SizeUInt;
  procedure Seek(AOffset: Int64; AOrigin: TSeekOrigin);
  procedure Close;
end;
```

实现类可以同时实现多个独立接口：

```pascal
TFileStream = class(TInterfacedObject, IReader, IWriter, IStream)
```

- 消费方只依赖自己需要的能力
- 实现类只实现自己能提供的能力
- 测试时只 mock 需要的接口

### 接口继承

最多两层：原子接口 → 组合接口。不做深层继承链。

需要更多能力时横向组合，不纵向继承。

### interface vs class vs record 选择标准

| 选择 | 判断条件 | 示例 |
|------|----------|------|
| `record` | 纯数据、值语义、无生命周期管理 | `TPoint`、`TDuration`、`TColor` |
| `interface` | 对外 API 契约、需要多实现或自动释放 | `IHasher`、`IReader`、`ILogger` |
| `class` | 内部实现细节、实现 interface 的具体类 | `TSha256Hasher`、`TFileReader` |

简单判断流程：
1. 纯数据、无行为或行为简单 → **record**
2. 对外 API 契约、需要多实现或自动释放 → **interface**
3. 内部实现细节 → **class**

### 接口上的 property

接口使用 property 暴露属性，调用方体验更自然。getter/setter 方法必须显式声明：

```pascal
IStream = interface
  function GetSize: Int64;
  function GetPosition: Int64;
  procedure SetPosition(AValue: Int64);
  property Size: Int64 read GetSize;
  property Position: Int64 read GetPosition write SetPosition;
end;
```

实现类匹配 `GetXxx`/`SetXxx` 方法名。

---

## 6. C 库绑定策略

### 核心原则

C 绑定和纯 Pascal 实现不冲突，通过模块隔离共存。同一接口可以有多个实现，消费方按策略选择。

### 标准形态

```
nextpas.core.crypto.pas              ← 门面
nextpas.core.crypto.base.pas         ← 类型定义
nextpas.core.crypto.intf.pas         ← 接口定义
nextpas.core.crypto.sha256.pas       ← 纯 Pascal 实现
nextpas.core.crypto.sha256.ossl.pas  ← OpenSSL 绑定实现
nextpas.core.crypto.ossl.ffi.pas     ← 纯 cdecl external 声明
```

### FFI 文件规则

- FFI 声明独立文件，命名为 `*.<lib>.ffi.pas`
- FFI 文件只包含 cdecl external 声明，不含逻辑
- 封装实现 uses FFI 文件，对上层提供与纯 Pascal 实现相同的接口

---

## 7. 稳定性分级

- 稳定性分级在模块注册表中标注
- 具体分级规则和晋升条件见单独文档

---

## 8. 回调/事件风格

### 三种回调形式同时支持

- 方法指针（`procedure of object`）
- 匿名函数（`reference to procedure`）
- 普通过程（`procedure`）

### 统一存储范式

内部统一用 `reference to procedure` 存储，对外提供三个重载。
参数类型必须使用命名的过程类型（FPC 不支持内联过程类型作为参数）：

```pascal
type
  TDataHandler = reference to procedure(const AData: TBytes);
  TDataHandlerMethod = procedure(const AData: TBytes) of object;
  TDataHandlerProc = procedure(const AData: TBytes);

procedure OnData(AHandler: TDataHandler); overload;
procedure OnData(AHandler: TDataHandlerMethod); overload;
procedure OnData(AHandler: TDataHandlerProc); overload;
```

调用方用任何风格都自然：

```pascal
// 匿名函数
Server.OnData(procedure(const D: TBytes) begin ... end);

// 方法指针
Server.OnData(@Self.HandleData);

// 普通过程
Server.OnData(@HandleData);
```

### 性能说明

- 通用回调场景（HTTP handler、UI 事件、定时器）使用此范式，开销可忽略
- 极端热路径（每字节解析、高频渲染回调）不使用此范式，走 `.inc` 内联或具体类型直接调用

---

## 9. 泛型使用策略

### 适用场景

- 容器：`TVector<T>`、`THashMap<K,V>`
- 通用算法：Sort、Find、Filter
- 与具体类型无关的抽象

### 不适用场景

- 业务语义明确的类型（`THttpRequest`、`TJsonValue`）
- 接口定义

### 原则

泛型只用于"容器/算法"类与具体类型无关的抽象，不滥用。

---

## 10. 文档注释风格

### 格式

使用 `{** ... *}` JavaDoc 风格块注释：

```pascal
{**
 * @desc 简述功能
 *
 * @params
 *   AName  参数说明
 *
 * @return 返回值说明
 *
 * @note 需要注意的点
 *}
```

### 保留标签

| 标签 | 用途 |
|------|------|
| `@desc` | 功能简述 |
| `@params` | 参数说明（有必要时） |
| `@return` | 返回值说明（有必要时） |
| `@note` | 需要注意的点 |

### 轻量类型注释

简单类型用单行大括号注释：

```pascal
{ EJsonParseError - JSON 解析错误异常 }
EJsonParseError = class(Exception)
```

### 实现区分隔

用单行大括号注释做分区：

```pascal
{ TVec<T> - Write 系列 }
{ TVec<T> - Read 系列 }
```

### 原则

- 不写 `@complexity`、`@rust_equivalent`、`@usage`、`@example` 等重标签
- 复杂度看实现即知，示例放测试或独立文档
- 命名自解释的方法可以不写注释

---

## 11. 编译器约定

### 标准文件头

所有单元统一使用：

```pascal
{$mode objfpc}{$H+}
```

根据需要可追加：

```pascal
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
```

### 编译器兼容性

- 最低要求：FPC 3.3.1（trunk）
- 目标兼容：未来的 nextPas 编译器
- 不兼容 FPC 3.2.x 及更早版本
- 原因：泛型和匿名回调（`reference to`）需要 3.3.1 特性支持

---

## 12. 测试组织

### 目录结构

```
tests/nextpas.core.time/       ← 模块测试目录
  test_duration/               ← 独立测试项目
    test_duration.lpr
  test_timer/                  ← 独立测试项目
    test_timer.lpr

benchmarks/nextpas.core.time/  ← 模块基准测试目录
  bench_duration/              ← 独立基准测试项目
    bench_duration.lpr

examples/nextpas.core.time/    ← 模块示例目录
  demo_stopwatch/              ← 独立示例项目
    demo_stopwatch.lpr
```

### 规则

- `tests/` — 验证正确性（断言、回归测试）
- `benchmarks/` — 性能基准测试
- `examples/` — 演示用法（示例代码、demo）
- 按模块名建子目录，每个子目录内可有多个独立项目
- 每个测试/示例项目是独立的 `.lpr`，各自编译成独立可执行文件
- 不使用统一 test runner
- 公开接口必须满覆盖：每个 public type、const、函数、方法、错误分支和边界语义都要有对应测试
- 审查时必须明确报告接口覆盖缺口，不能只用 happy path 测试代替接口契约覆盖

### 测试框架 & 基准框架

- 初期零依赖（直接用 assert 或简单的 WriteLn 验证）
- 后期随框架成熟，逐步依赖框架内部模块构建更完善的测试框架和基准框架
- benchmarks 同 tests 结构，按模块分子目录，独立 .lpr 项目

---

## 13. 代码风格

### 缩进

- 2 空格缩进，不使用 Tab

### begin/end 对齐

- 函数体 `begin` 在声明下一行，与 `function`/`procedure` 同列
- `if` 多行用 `begin/end`，Allman 风格变体（`end` 后换行接 `else`）

```pascal
function DoSomething: Boolean;
begin
  if Condition then
  begin
    DoA;
    DoB;
  end
  else
  begin
    DoC;
  end;
end;
```

### 大小写惯例

| 类别 | 惯例 | 示例 |
|------|------|------|
| 关键字 | 全小写 | `begin`, `end`, `function`, `type`, `var` |
| 类型名 | PascalCase + `T` 前缀 | `TMutex`, `TVec` |
| 接口名 | PascalCase + `I` 前缀 | `IMutex`, `IVec` |
| 异常类 | PascalCase + `E` 前缀 | `ENotFound`, `ETimeout` |
| 常量 | UPPER_SNAKE_CASE | `MAX_BUFFER_SIZE` |
| 字段 | PascalCase + `F` 前缀 | `FCount`, `FBuffer` |
| 参数 | PascalCase + `A` 前缀 | `ACapacity`, `AValue` |
| 局部变量 | PascalCase + `L` 前缀 | `LValue`, `LCount`, `LIdx` |
| 函数/方法/类名 | PascalCase（首字母大写） | `GetCapacity`, `TryReserve` |
| platform 层函数 | C 风格 snake_case + `platform_` 前缀 | `platform_mutex_lock`, `platform_futex_wait` |
| 编译器宏 | UPPER_SNAKE_CASE | `NEXTPAS_CORE_USE_FUTEX` |

### 参数声明风格

- 不修改的参数严格使用 `const`
- 参数名 `A` 前缀 + PascalCase 单词
- 参数名后 `:` 跟一个空格

```pascal
procedure Connect(const AHost: string; const APort: Word);
function TryParse(const AInput: string; out AValue: Integer): Boolean;
```

### 变量声明

- `var` 独占一行，与 `begin` 同级
- 每个变量单独一行，缩进 2 空格
- 局部变量统一使用 `L` 前缀

```pascal
var
  LValue: Integer;
  LBuffer: TBytes;
  LStream: IStream;
```

### uses 子句

- 标准库单元放第一行
- 框架内部单元按逻辑分组，每行缩进 2 空格
- 条件编译的 uses 用 `{$IFDEF}` 内联

```pascal
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.sync.base
  {$IFDEF UNIX}, nextpas.core.sync.mutex.unix{$ENDIF}
  {$IFDEF WINDOWS}, nextpas.core.sync.mutex.windows{$ENDIF};
```

### 空行规则

- `interface` / `implementation` 前后各空 1 行
- 方法实现之间空 1 行
- 逻辑段落用 `{ 注释标题 }` 分隔
- 文件以 `end.` 结尾，前面空 1 行

### 对齐

- 多个相关赋值语句可用空格对齐 `:=`

```pascal
FBuf   := TVecBuf.Create(ACapacity);
FCount := 0;
```

---

## 14. 构建系统

### 工具

- 使用 Makefile

### 构建产物隔离

- 中间文件（`.o`、`.ppu`）和二进制文件分别放在不同目录
- 不允许在 `src/` 或源码目录产生任何构建文件

```
build/
  lib/        ← 中间文件（.o、.ppu）
  bin/        ← 编译产物（可执行文件、.so/.a）
```

### 基本目标

- `make build` — 编译框架
- `make test` — 编译并运行所有测试
- `make examples` — 编译所有示例
- `make clean` — 清理所有构建产物

### 项目卫生

- 每轮验证后检查 `git status --short`
- 不留下临时文件、未跟踪产物或无意生成的目录
- 需要保留的构建产物必须由 `.gitignore` 明确忽略，不能让项目目录变得脏乱

---

## 15. 模块清单

### 分层规则补充

- 只能向下依赖，不能向上依赖
- 同层内允许单向依赖，禁止循环依赖

### L0: 内核（bootstrap 阶段只依赖最低限度宿主能力）

| 模块 | 职责 |
|------|------|
| `base` | 基础类型、公共定义、编译器设置（settings.inc） |
| `errors` | 异常层次结构 |
| `platform` | OS/CPU 检测、平台类型（句柄等） |
| `mem` | 内存管理（分配器抽象、arena、pool） |
| `log.intf` | ILogger 接口 + NullLogger（零开销） |

### L1: 基础设施（只依赖 L0）

| 模块 | 职责 |
|------|------|
| `bytes` | 字节容器（Buffer、Builder、字节序） |
| `text` | 字符串操作、Unicode、格式化 |
| `encoding` | 编解码（base64、hex、url、字符集、varint） |
| `collections` | 容器（Vec、HashMap、Deque、Set、List、LRU、Pool） |
| `sync` | 同步原语（Mutex、RWLock、Atomic、WaitGroup） |
| `thread` | 线程池、Channel、Future |
| `async` | 事件循环、Reactor、异步运行时 |
| `io` | 流抽象（Reader、Writer、Buffer） |
| `time` | DateTime、Duration、Timer、Stopwatch |
| `id` | UUID/ULID/Snowflake/NanoID |
| `testing` | 测试框架（初期极简，后期迭代） |

### L2: 系统能力（只依赖 L0-L1）

| 模块 | 职责 |
|------|------|
| `fs` | 文件系统（同步 + 异步） |
| `net` | TCP/UDP Socket、地址解析 |
| `tls` | TLS/SSL |
| `dns` | DNS 解析 |
| `crypto` | 哈希、加密、签名 |
| `compress` | gzip/zlib/zstd |
| `json` | JSON |
| `yaml` | YAML |
| `toml` | TOML |
| `xml` | XML（低优先级） |
| `regex` | 正则表达式 |
| `sqlite` | SQLite |
| `pg` | PostgreSQL |
| `process` | 进程管理 |
| `args` | 命令行解析 |
| `validation` | 数据校验（类型、范围、格式、嵌套） |

### L3: 框架（只依赖 L0-L2）

| 模块 | 职责 |
|------|------|
| `log` | 完整日志实现（格式化、输出、异步） |
| `config` | 配置管理（多源、热加载） |
| `redis` | Redis 客户端 |
| `http` | HTTP 服务器/客户端（路由、中间件、静态文件、SSE、OpenAPI） |
| `websocket` | WebSocket（帧协议、Room、广播） |
| `mail` | SMTP/IMAP/POP3 |
| `tui` | 终端 UI（渲染、布局、Widget、事件） |
| `migration` | 数据库迁移 |
| `ratelimit` | 限流、熔断、重试、降级 |
| `auth` | JWT/Session/认证/权限 |
| `template` | 模板引擎 |
| `metrics` | 指标采集、Prometheus、健康检查 |
| `event` | 进程内事件总线（pub/sub） |
| `job` | 异步任务队列（重试、死信、优先级） |
| `app` | 应用启动编排（Bootstrap、Graceful Shutdown） |

---

## 16. 项目目录结构

```
nextpas.core/
  src/            ← 所有源码（.pas + .inc 平铺）
  tests/          ← 测试项目（按模块分子目录）
  benchmarks/     ← 基准测试项目（按模块分子目录）
  examples/       ← 示例项目（按模块分子目录）
  vendors/        ← 第三方 C 库源码（vendored）
  docs/           ← 设计文档、规范
  scripts/        ← 构建脚本、codegen 脚本
  build/          ← 构建产物（git ignored）
    lib/          ← 中间文件（.o、.ppu）
    bin/          ← 可执行文件、.so/.a
  Makefile        ← 构建入口
  LICENSE         ← MIT
  README.md
```

---

## 17. 第三方 C 库管理

### 存放位置

- 所有第三方 C 库源码统一放在 `vendors/` 目录下
- 每个库一个子目录：`vendors/libuv/`、`vendors/yyjson/`、`vendors/sqlite3/`

### 链接方式

- 同时支持静态链接和动态链接
- 构建脚本、目录结构和文档都要完备整洁
- 默认静态链接（单二进制部署），可选动态链接

---

## 18. 平台支持

### 目标

- nextPas 编译器基于 LLVM 后端，core 框架要全平台支持
- 当前优先实现 Linux x86_64
- 设计上预留全平台（通过 .inc 平台分支和多态）
- 目标平台：Linux、macOS、Windows（x86_64、aarch64）

### platform 层不得依赖 FPC 平台单元

`platform` 是 nextPas 标准库接触宿主 ABI 的最底层边界。将来 nextPas
编译器不会携带 FPC 的 `Linux`、`UnixType`、`PThreads`、`BaseUnix`、
`Syscall`、`Windows` 等平台单元，所以 `platform` 下的实现单元不得 `uses`
这些单元。

平台 API 必须通过 nextPas 自己维护的 FFI 单元声明，例如：

- `nextpas.core.platform.posix.ffi`：POSIX 通用 ABI，如 `timespec`、
  `clock_gettime`、pthread 类型与函数。
- `nextpas.core.platform.linux.ffi`：Linux 专有 ABI，如 `syscall`、
  `SYS_futex`、`FUTEX_WAIT`、`FUTEX_WAKE`。
- Windows 专有 ABI 也必须放入 nextPas 自己的 FFI 单元，不能通过 FPC
  `Windows` 单元取得声明。

FFI 声明应使用明确的 ABI 类型、调用约定和外部符号名，例如
`cdecl; external 'c' name 'clock_gettime'` 或
`cdecl; external 'pthread' name 'pthread_mutex_lock'`。上层 `platform.*`
实现只依赖这些自有 FFI 单元，并把错误码、超时语义、对象尺寸和对齐要求整理成
nextPas 自己的稳定契约。

---

## 19. 许可证

MIT

---

## 20. 内存所有权约定

### 核心规则

**谁创建谁释放。**

- 函数/方法创建并返回的对象，由调用方负责释放
- 函数/方法内部创建的临时对象，由函数自己释放
- interface 类型走引用计数自动管理，不需要手动释放
- Builder 返回 interface，自动管理

### 例外

- 容器拥有其元素的所有权（容器释放时释放元素）
- 明确文档标注的"借用"场景（返回内部引用，调用方不得释放）

---

## 21. 字符串约定

- 全框架统一 UTF-8
- `string` 类型（`{$H+}` 下为 AnsiString）始终存储 UTF-8 编码
- 与外部系统交互时在边界处做编码转换

---

## 22. 线程安全约定

### 默认规则

- 所有类型默认不线程安全（假设单线程使用）
- 需要并发访问时，调用方使用 `sync` 模块原语保护
- 不在非必要的地方加锁（性能优先）

### 线程安全类型

明确设计为线程安全的类型在文档注释中标注：

```pascal
{**
 * @desc 线程安全的并发队列
 * @note 线程安全
 *}
IConcurrentQueue = interface
```

不标注 = 默认不安全。
