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

### 标准形态（四件套 + 实现）

这是完整模块可能采用的最大形态，不是每个模块都必须机械创建所有文件。
每个文件是否存在，由真实职责决定：

- `base`：只有模块需要公开常量、record、enum、type alias 等公共载体类型时存在。
- `intf`：只有模块确实定义 Pascal `interface` 契约时存在。普通函数式 API 或 platform
  统一过程/函数契约，不为了“凑四件套”创建 `*.intf.pas`。
- `ffi`：只有模块本身拥有 foreign binding / ABI 声明时存在。不能把普通 helper 或抽象层伪装成
  `*.ffi.pas`。
- 实现子模块：只有门面需要拆出具体实现、策略或算法时存在。

```
nextpas.core.<module>.pas           ← 门面：纯 re-export，不含逻辑
nextpas.core.<module>.base.pas      ← 基本类型定义（record、enum、const、type alias）
nextpas.core.<module>.intf.pas      ← 接口定义（interface 声明）
nextpas.core.<module>.ffi.pas       ← FFI / ABI 声明（模块需要 foreign binding 时存在）
nextpas.core.<module>.<impl>.pas    ← 实现子模块
```

子模块可递归此范式：

```
nextpas.core.<module>.<sub>.pas
nextpas.core.<module>.<sub>.base.pas
nextpas.core.<module>.<sub>.intf.pas
nextpas.core.<module>.<sub>.ffi.pas
```

### 依赖方向

```
base ← intf ← 实现 ← 门面(聚合)
base ← ffi  ← 实现
```

- `base` 不依赖同模块任何文件（纯数据类型）
- `intf` 依赖 `base`（接口签名需要类型）
- `ffi` 是实现侧 ABI / foreign binding seam；默认只依赖 RTL 与宿主声明，若签名需要模块内公共载体类型，可依赖 `base`
- 实现依赖 `intf` + `base`，需要 foreign binding 时再依赖 `ffi`
- 门面 uses 所有子模块，re-export 给外部
- 如果模块没有 `intf` 或 `ffi`，实现层直接依赖实际存在的 `base`、宿主 FFI 或其他下层 contract；
  禁止为了满足图形范式而引入空文件或错误职责文件。

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
- 需要 foreign ABI / external 声明 → 引 `*.ffi.pas`（通常仅实现单元或桥接层使用）
- 开箱即用 → 引门面

### 模块归属原则

- 不存在孤立的小单元，所有功能归属于某个功能域模块
- 功能域划分遵循通行标准（参考 Rust std、Go 标准库、.NET BCL）

### 范式例外

- `nextpas.core.base` 是根模块，不递归四件套范式（不存在 `nextpas.core.base.base.pas`）
- `nextpas.core.base` 直接作为基础类型定义单元，同时承担 `base` 和门面的角色
- 顶层 `platform` 的 OS/CPU/endian inquiry 遵循 facade/base/implementation 分工：
  `nextpas.core.platform.base` 只拥有 enum 与 `CURRENT_*` compile-time truth，
  `nextpas.core.platform.info` 拥有 `CurrentOS`、`CurrentCPU`、`CurrentEndian`、
  `OSName`、`CPUName` 的纯 Pascal 实现，`nextpas.core.platform` 只 re-export public type 并
  inline forward。`platform.info` 不创建 `*.base`、`*.intf` 或 `*.ffi`。
- `platform` 的 feature 子模块遵循 host-owner 模型：`platform.time`、`platform.sync`、
  `platform.thread` 这类跨平台统一 API 默认不创建自己的 `*.ffi.pas`，而是消费
  `platform.<host>.base` / `platform.<host>.ffi`。只有当某个 feature 自身真的拥有独立于宿主
  owner 的 foreign ABI 时，才允许创建 `platform.<feature>.ffi.pas`，并必须在设计文档中说明原因。

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
     ↑ 只依赖 FPC RTL

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

| 选择        | 判断条件                              | 示例                            |
| ----------- | ------------------------------------- | ------------------------------- |
| `record`    | 纯数据、值语义、无生命周期管理        | `TPoint`、`TDuration`、`TColor` |
| `interface` | 对外 API 契约、需要多实现或自动释放   | `IHasher`、`IReader`、`ILogger` |
| `class`     | 内部实现细节、实现 interface 的具体类 | `TSha256Hasher`、`TFileReader`  |

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
nextpas.core.crypto.ffi.pas          ← 模块级统一 ABI / FFI 声明（可选）
nextpas.core.crypto.sha256.pas       ← 纯 Pascal 实现
nextpas.core.crypto.sha256.ossl.pas  ← OpenSSL 绑定实现
nextpas.core.crypto.ossl.ffi.pas     ← 纯 cdecl external 声明
```

### FFI 文件规则

- FFI 声明独立文件；模块级统一 binding seam 用 `*.ffi.pas`
- 某个具体后端 / 宿主 / C 库的 binding seam 用 `*.<lib>.ffi.pas` 或 `*.<host>.ffi.pas`
- FFI 文件只包含 cdecl external 声明，不含逻辑
- 封装实现 uses FFI 文件，对上层提供与纯 Pascal 实现相同的接口
- 如果某个宿主还需要不含 `external` 的纯 helper（例如可在非该宿主链接路径复用的计数器换算），
  应放在同 host family 的普通 helper unit，例如 `nextpas.core.platform.windows.math.pas`，
  不要伪装成 `*.ffi.pas`

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

| 标签      | 用途                   |
| --------- | ---------------------- |
| `@desc`   | 功能简述               |
| `@params` | 参数说明（有必要时）   |
| `@return` | 返回值说明（有必要时） |
| `@note`   | 需要注意的点           |

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

| 类别            | 惯例                                 | 示例                                         |
| --------------- | ------------------------------------ | -------------------------------------------- |
| 关键字          | 全小写                               | `begin`, `end`, `function`, `type`, `var`    |
| 类型名          | PascalCase + `T` 前缀                | `TMutex`, `TVec`                             |
| 接口名          | PascalCase + `I` 前缀                | `IMutex`, `IVec`                             |
| 异常类          | PascalCase + `E` 前缀                | `ENotFound`, `ETimeout`                      |
| 常量            | UPPER_SNAKE_CASE                     | `MAX_BUFFER_SIZE`                            |
| 字段            | PascalCase + `F` 前缀                | `FCount`, `FBuffer`                          |
| 参数            | PascalCase + `A` 前缀                | `ACapacity`, `AValue`                        |
| 局部变量        | PascalCase + `L` 前缀                | `LValue`, `LCount`, `LIdx`                   |
| 函数/方法/类名  | PascalCase（首字母大写）             | `GetCapacity`, `TryReserve`                  |
| platform 层函数 | C 风格 snake*case + `platform*` 前缀 | `platform_mutex_lock`, `platform_futex_wait` |
| 编译器宏        | UPPER_SNAKE_CASE                     | `NEXTPAS_CORE_USE_FUTEX`                     |

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

---

## 15. 模块清单

### 分层规则补充

- 只能向下依赖，不能向上依赖
- 同层内允许单向依赖，禁止循环依赖

### L0: 内核（只依赖 FPC RTL）

| 模块       | 职责                                           |
| ---------- | ---------------------------------------------- |
| `base`     | 基础类型、公共定义、编译器设置（settings.inc） |
| `errors`   | 异常层次结构                                   |
| `platform` | OS/CPU 检测、平台类型（句柄等）                |
| `mem`      | 内存管理（分配器抽象、arena、pool）            |
| `log.intf` | ILogger 接口 + NullLogger（零开销）            |

### L1: 基础设施（只依赖 L0）

| 模块          | 职责                                              |
| ------------- | ------------------------------------------------- |
| `bytes`       | 字节容器（Buffer、Builder、字节序）               |
| `text`        | 字符串操作、Unicode、格式化                       |
| `encoding`    | 编解码（base64、hex、url、字符集、varint）        |
| `collections` | 容器（Vec、HashMap、Deque、Set、List、LRU、Pool） |
| `sync`        | 同步原语（Mutex、RWLock、Atomic、WaitGroup）      |
| `thread`      | 线程池、Channel、Future                           |
| `async`       | 事件循环、Reactor、异步运行时                     |
| `io`          | 流抽象（Reader、Writer、Buffer）                  |
| `time`        | DateTime、Duration、Timer、Stopwatch              |
| `id`          | UUID/ULID/Snowflake/NanoID                        |
| `testing`     | 测试框架（初期极简，后期迭代）                    |

### L2: 系统能力（只依赖 L0-L1）

| 模块         | 职责                               |
| ------------ | ---------------------------------- |
| `fs`         | 文件系统（同步 + 异步）            |
| `net`        | TCP/UDP Socket、地址解析           |
| `tls`        | TLS/SSL                            |
| `dns`        | DNS 解析                           |
| `crypto`     | 哈希、加密、签名                   |
| `compress`   | gzip/zlib/zstd                     |
| `json`       | JSON                               |
| `yaml`       | YAML                               |
| `toml`       | TOML                               |
| `xml`        | XML（低优先级）                    |
| `regex`      | 正则表达式                         |
| `sqlite`     | SQLite                             |
| `pg`         | PostgreSQL                         |
| `process`    | 进程管理                           |
| `args`       | 命令行解析                         |
| `validation` | 数据校验（类型、范围、格式、嵌套） |

### L3: 框架（只依赖 L0-L2）

| 模块        | 职责                                                       |
| ----------- | ---------------------------------------------------------- |
| `log`       | 完整日志实现（格式化、输出、异步）                         |
| `config`    | 配置管理（多源、热加载）                                   |
| `redis`     | Redis 客户端                                               |
| `http`      | HTTP 服务器/客户端（路由、中间件、静态文件、SSE、OpenAPI） |
| `websocket` | WebSocket（帧协议、Room、广播）                            |
| `mail`      | SMTP/IMAP/POP3                                             |
| `tui`       | 终端 UI（渲染、布局、Widget、事件）                        |
| `migration` | 数据库迁移                                                 |
| `ratelimit` | 限流、熔断、重试、降级                                     |
| `auth`      | JWT/Session/认证/权限                                      |
| `template`  | 模板引擎                                                   |
| `metrics`   | 指标采集、Prometheus、健康检查                             |
| `event`     | 进程内事件总线（pub/sub）                                  |
| `job`       | 异步任务队列（重试、死信、优先级）                         |
| `app`       | 应用启动编排（Bootstrap、Graceful Shutdown）               |

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
- 目标平台：Linux、macOS、Windows、通用 Unix/BSD 与 Android（x86_64、aarch64）

### 硬规则：platform 模块不依赖 FPC 单元

`platform` 是 nextPas 标准库接触宿主 ABI 的最底层边界。将来 nextPas
编译器不会携带 FPC 的 `Linux`、`UnixType`、`PThreads`、`BaseUnix`、
`Syscall`、`Windows` 等平台单元，所以 **platform 层禁止 `uses` 任何 FPC
平台/RTL 单元**。

所有系统调用和平台 API 必须通过 nextPas 自己维护的 FFI 文件声明：

```
src/nextpas.core.platform.posix.base.pas  ← POSIX 共享常量、结构、ABI 类型
src/nextpas.core.platform.posix.math.pas  ← POSIX 共享纯数学 helper（无 external）
src/nextpas.core.platform.posix.ffi.pas   ← POSIX 系统调用（cdecl external 'c'）
src/nextpas.core.platform.linux.base.pas  ← Linux 常量、结构、ABI 类型
src/nextpas.core.platform.linux.ffi.pas   ← Linux 特有（syscall numbers 等）
src/nextpas.core.platform.darwin.base.pas ← macOS 常量、结构、ABI 类型
src/nextpas.core.platform.darwin.ffi.pas  ← macOS 特有（mach_* 等）
src/nextpas.core.platform.android.base.pas ← Android 常量、结构、ABI 类型
src/nextpas.core.platform.android.ffi.pas ← Android 特有 ABI 绑定
src/nextpas.core.platform.freebsd.base.pas ← FreeBSD 常量、结构、ABI 类型
src/nextpas.core.platform.freebsd.ffi.pas ← FreeBSD 特有 ABI 绑定
src/nextpas.core.platform.unix.base.pas   ← generic Unix fallback 常量、结构、ABI 类型
src/nextpas.core.platform.unix.ffi.pas    ← generic Unix fallback ABI 绑定
src/nextpas.core.platform.windows.base.pas ← Windows 常量、结构、ABI 类型
src/nextpas.core.platform.windows.ffi.pas ← Windows API（stdcall external）
```

FPC 源码和平台单元可以作为 ABI 声明的重要依据：系统调用号、常量值、record layout、
opaque storage 大小、调用约定、外部库名和符号名都可以从 FPC 对应平台单元里核对后搬入
nextPas 自己的 `platform.<host>.base` / `platform.<host>.ffi`。必要时也可以写
test-only / reference-only 的对照工具来核对这些声明。但这只是 reference authority，不是
runtime dependency：platform 生产代码仍然禁止 `uses Linux`、`Windows`、`UnixType`、
`PThreads` 等 FPC 单元。从 FPC 参考来的声明必须按 nextPas 的 host owner 分层落位，并用
source-surface / compile gate 冻结，避免后续又退回对 FPC RTL 的隐式依赖。

测试边界也要保持同一条线：raw 系统 API 和 FFI 声明的 ABI 正确性以 FPC 源码取证、
人工审查、source-surface guard 与 compile-only gate 为主，不把 `clock_gettime`、`pthread_*`、
`futex`、`QueryPerformanceCounter`、`WaitOnAddress` 等系统入口本身当作 nextPas 单元测试目标。
运行时行为测试只覆盖 `platform.time`、`platform.sync`、`platform.thread` 这类统一抽象子模块的
public contract；测试需要造并发、睡眠或 TLS 场景时，也应优先通过 nextPas 的 platform 抽象 API
完成，而不是直接调用宿主 FFI。

当前 host ABI 覆盖面与已知缺口集中记录在 `docs/platform-host-ffi-gap-matrix.md`。该矩阵是
source-surface guard 的文档事实源，用来约束 Linux、Android、Darwin、FreeBSD、generic Unix 与
Windows 的 host `base/ffi` ownership；它不是跨宿主 runtime proof。

扩充顺序应保持清晰：先把各宿主平台的 ABI 声明尽可能完整地沉到
`platform.<host>.base` / `platform.<host>.ffi`，再由 `platform.time`、`platform.sync`、
`platform.thread` 以及后续通用 platform 子模块抽象出统一 API、错误码、timeout 语义、对象生命周期和
资源释放契约。host ffi 负责“系统有什么”，通用子模块负责“nextPas 暴露什么稳定契约”。

示例边界：

- `nextpas.core.platform.<host>.base`：宿主平台定义，如常量、record、opaque carrier、
  ABI scalar/type alias、capability token。
- `nextpas.core.platform.<host>.ffi`：宿主平台 API 绑定，如 `cdecl/stdcall external`
  声明、syscall wrapper、libc/kernel32/pthread/mach 入口，以及围绕这些 ABI 的 host-owned
  thin helper。
- `nextpas.core.platform.posix.base` / `nextpas.core.platform.posix.math` /
  `nextpas.core.platform.posix.ffi`：分别承载真正跨 POSIX 宿主共享的 ABI 形状、纯数学 helper、
  以及 external 绑定和贴近 external 的共享 helper。
- Windows 专有 ABI 必须放入 nextPas 自己的 Windows base/FFI 单元，不能通过 FPC `Windows`
  单元取得声明。

FFI 声明应使用明确的 ABI 类型、调用约定和外部符号名，例如
`cdecl; external 'c' name 'clock_gettime'` 或
`cdecl; external 'pthread' name 'pthread_mutex_lock'`。platform 子模块（time、
sync、thread 等）只依赖这些自有 FFI 单元，并把错误码、超时语义、对象尺寸和对齐要求整理成
nextPas 自己的稳定契约。

顶层 platform inquiry 不是 raw ABI owner：`platform.base` 保存 `TOSKind`、`TCPUArch`、
`TEndianness` 与 `CURRENT_*` truth，`platform.info` 负责把这些 truth 暴露成
`CurrentOS` / `CurrentCPU` / `CurrentEndian` / `OSName` / `CPUName`，顶层
`nextpas.core.platform` 只做 public re-export 与 inline forwarding。不要把 OS/CPU name mapping
逻辑放回顶层门面，也不要为 `platform.info` 创建 `platform.info.ffi` 或 `platform.info.intf`。

FFI 文件应优先按宿主平台归并，而不是按单个上层模块零散切分。例如 Windows 的 thread、
time、sync ABI 应尽量统一沉到 `nextpas.core.platform.windows.ffi`，Linux 专有 ABI 统一沉到
`nextpas.core.platform.linux.ffi`，macOS 专有 ABI 统一沉到
`nextpas.core.platform.darwin.ffi`。`platform.time`、`platform.sync`、`platform.thread`
等实现单元负责策略、契约和错误码映射，不在实现体里散落 `external` 声明。

换句话说，`platform.time`、`platform.sync`、`platform.thread` 是 platform 层在不同宿主之上的
统一 API contract：它们把 Linux、Windows、macOS、Android、FreeBSD、generic Unix 等宿主差异整理成
nextPas 自己稳定的过程/函数、类型和错误语义。它们应直接消费各自宿主的
`platform.<host>.base` / `platform.<host>.ffi`，不再重复创建
`platform.time.ffi`、`platform.sync.ffi`、`platform.thread.ffi` 这类按 feature 切碎的 FFI 单元。
如果后来确实出现 feature-specific foreign ABI，必须先证明它不属于任何 host owner，再单独建
`platform.<feature>.ffi`。

`nextpas.core.platform.posix.base` 这类 shared base 单元只保留真正跨宿主共享的 ABI 形状，例如
`timespec`、pthread opaque types、pthread callback signature 与 shared opaque carrier。普遍存在的
pthread/system call external 声明仍归 `posix.ffi`。像 mutex kind 编号、
`pthread_condattr_setclock` 是否可用、condvar timeout 应绑定哪一个 clock id 这类宿主 capability /
policy token，必须下沉到各自 `linux/darwin/android/freebsd/unix` base owner 单元，不要继续塞在
shared `posix.base` / `posix.math` / `posix.ffi` 或实现层条件编译里。

但 shared `posix.ffi` 也不该被收窄成“只能放 raw externals”。像 `pthread_self` token 投影、
`pthread_create/join/detach`、`sched_yield`、TLS key 读写、`sysconf` 正数投影这类在 POSIX 宿主间
语义完全共享的 thread glue，应直接在 `posix.ffi` 形成单一事实源；各 host ffi 只保留 errno
binding、native thread id ABI 这类必须触碰宿主 external 的 truth，再把 shared helper 委托出去。
`EINTR`、`_SC_NPROCESSORS_ONLN` 这类编号 token 属于 host base。

如果共享 helper 完全不需要 external 绑定，只是跨宿主复用的纯数学换算，就不应该让非 POSIX
链接路径为它拉入 `posix.ffi`。例如 `timespec -> ns`、`timespec + ns` 与 deadline remaining
算术归 `nextpas.core.platform.posix.math`；`posix.ffi` 可以消费这些 helper，但不能重新成为
纯数学 owner。

同样，`nanosleep` 这类 shared POSIX ABI 的 retry/error 语义也不能由实现层凭空假设。像
`EINTR` 这样的 retryable errno token 必须由各宿主 FFI owner 提供，`platform.thread` 等实现单元只消费
这些 host-owned token，而不是把“所有 Unix 都按同一个 errno 编号重试”写死在实现里。

同样，像 `PLATFORM_PTHREAD_TOKEN_SIZE`、`PLATFORM_PTHREAD_MUTEX_SIZE`、
`PLATFORM_PTHREAD_RWLOCK_SIZE`、`PLATFORM_PTHREAD_CONDVAR_SIZE`、
`PLATFORM_WINDOWS_MUTEX_SIZE`、`PLATFORM_WINDOWS_RWLOCK_SIZE`、
`PLATFORM_WINDOWS_CONDVAR_SIZE` 这类“从 raw ABI type 计算出的 opaque storage size truth”，
也属于 host base owner，而不是 consumer。`platform.thread`、`platform.sync` 这类实现单元只消费
这些 host-owned size token，不直接在 consumer 里再次写 `SizeOf(pthread_*_t)`、
`SizeOf(SRWLOCK)` 或 `SizeOf(CONDITION_VARIABLE)`。

同样，opaque storage / handle wrapper 的 ABI alignment truth 也属于 host ffi owner，而不是
consumer 自己拿 `PtrUInt`、`UInt64` 之类 generic scalar 去猜。像
`TPlatformPThreadTokenAlign`、`TPlatformPThreadMutexAlign`、`TPlatformPThreadRwLockAlign`、
`TPlatformPThreadCondVarAlign`、`TPlatformWindowsMutexAlign` 这类 host-owned align carrier type，
应该由对应 `*.base` 单元显式暴露；`platform.thread`、`platform.sync` 等 consumer 只通过 variant
record 消费这些 carrier type，把宿主原生对齐要求继承进 nextPas 自己的 opaque storage contract，
而不是在实现层保留 `FAlign: PtrUInt`、`FAlign: UInt64` 这类近似占位。

不仅 errno token 要按宿主 owner，下层“当前 errno 值怎么读”这件事本身也属于 host ABI truth。
`platform_errno_location` 这类外部符号绑定与基于它读取当前 errno 的 helper，都应放进
`linux/darwin/android/freebsd/unix` 等 host ffi owner 单元；`platform.thread`、
`platform.sync` 等 consumer 只消费 `platform_posix_errno_value` 这类 helper，不直接在实现层
解引用 errno storage。

为了验证这些宿主分支不会只在 Linux 主机上“看起来没问题”，platform 层允许有限的
**test-only simulated host selection**：`nextpas.core.settings.inc` 可以识别
`NEXTPAS_FORCE_HOST_WINDOWS`、`NEXTPAS_FORCE_HOST_LINUX`、
`NEXTPAS_FORCE_HOST_DARWIN`、`NEXTPAS_FORCE_HOST_ANDROID`、
`NEXTPAS_FORCE_HOST_FREEBSD`、`NEXTPAS_FORCE_HOST_UNIX`，仅供独立测试项目用
`-Cn` 做 compile-only host matrix proof。这个 override 只用于验证分支选择、unit surface 与
FFI compile coherence，不得拿来宣称真实 cross toolchain / runtime 已验证通过。

generic Unix fallback 既然已经有 `nextpas.core.platform.unix.ffi` 承载
`clock_gettime` / `clock_getres` / pthread timeout clock truth，就必须把
`NEXTPAS_POSIX_CLOCK` 视为这条 fallback contract 的一部分。也就是说，generic Unix 不能一边暴露
`unix.ffi` 的 POSIX clock helper，一边让 `platform.time` 因为缺少
`NEXTPAS_POSIX_CLOCK` 而退化成 unsupported。

### `platform.time` 的边界

`nextpas.core.platform.time` 只提供系统时钟源和平台换算工具，例如 monotonic clock、
realtime clock、clock resolution，以及不同平台计数器到纳秒的安全转换。它不提供业务语义、
对象生命周期或便利封装。

像 Windows `FILETIME` 的 Unix epoch offset、tick size（100ns）这类宿主时钟 ABI truth，也必须由
`nextpas.core.platform.windows.ffi` 这类 host ffi owner 单元提供；`platform.time` 只消费这些 token，
不能把裸魔数常量继续埋在实现里。

如果某段 Windows 时钟换算只是纯数学 helper，本身不需要 `QueryPerformanceCounter`、
`GetSystemTimeAsFileTime` 这类 raw ABI 绑定，但又需要让非 Windows 宿主复用同一套换算语义，
应放在同 host family 的普通 helper unit（例如 `nextpas.core.platform.windows.math`），而不是让
Linux/macOS 链接路径为了复用纯换算逻辑去引入 `windows.ffi` 并污染 `kernel32` 依赖。
同理，`platform.time.host` 的 public `timespec` 换算 helper 应消费
`nextpas.core.platform.posix.math`，不能为了纯换算无条件拉入 `posix.ffi`。

同样，Windows `Sleep`、`WaitOnAddress`、`SleepConditionVariableSRW` 这类 API 的超时换算 policy
（纳秒到毫秒的向上取整、`INFINITE` sentinel、最大有限超时截断）也应该归
`nextpas.core.platform.windows.ffi` 统一拥有；`platform.thread`、`platform.sync` 等 consumer
只消费 helper/token，不要各自复制一份 Windows timeout 语义。

同样，Windows wait result / last-error 语义也属于 host-owned ABI truth。像
`GetLastError` 到 nextPas `Int32` 的投影、`ERROR_TIMEOUT` 是否映射为 platform timeout、
`WaitForSingleObject` 返回值里哪一个表示 signaled，这些都应由
`nextpas.core.platform.windows.ffi` 提供 helper/token；`platform.thread`、
`platform.sync` 等 consumer 只消费这些 helper，不直接散落
`GetLastError`、`WAIT_OBJECT_0`、`ERROR_TIMEOUT` 之类 raw 宿主语义。
如果 consumer 还需要把宿主 timeout 失败投影成自己的 public timeout result，优先让
`windows.ffi` 暴露带 caller-supplied timeout result 的 helper，例如
`windows_condvar_timedwait_timeout_result`、
`windows_wait_address_i32_timeout_result`，而不是让 consumer 自己再写
`if windows_error_i32_is_timeout(...) then ... else ...` 分支。

如果 consumer 只是为了把 Windows 的 `DWORD` timeout / error token 转成 nextPas 自己的
`Int32` / `Int64` 契约而临时声明 raw ABI scalar，那这层转换也应继续归
`nextpas.core.platform.windows.ffi` owner。优先提供像 `windows_error_i32_is_timeout`、
`windows_condvar_timedwait_ns`、`windows_wait_address_i32_timeout_ns` 这类 platform-neutral helper，
而不是让 `platform.sync` 之类 consumer 自己保留 `DWORD` 临时变量、ns->ms 中间值或
`DWORD(AError)` 这类宿主类型投影。

同理，Darwin `mach_timebase_info` 的 cache / sanitize policy，以及 Windows
`QueryPerformanceFrequency` / `QueryPerformanceCounter` / `GetSystemTimeAsFileTime`
这些宿主时钟 API 的 stateful helper，也应尽量收在各自 host ffi owner 单元里。`platform.time`
可以继续拥有 public clock contract 与对外暴露的纯换算 API，但不应继续在 consumer 里散落 raw
`mach_*` / QPC / FILETIME 调用、宿主计数器初始化细节，或直接消费宿主专用 helper 组合再自己拼出
monotonic / realtime / resolution 结果。更理想的边界是由各宿主 ffi owner 直接提供
`platform_clock_monotonic_ns_u64`、`platform_clock_realtime_ns_u64`、
`platform_clock_monotonic_resolution_ns_u64` 这类高层 clock helper，`platform.time` 只做薄
delegation。

POSIX 的 `clock_gettime` / `clock_getres` 也遵循同一条 owner boundary。shared
`nextpas.core.platform.posix.ffi` 保留共享 ABI 形状，例如 `timespec`、raw declaration，以及所有
POSIX 宿主都会复用的饱和 `timespec -> ns`、`timespec + ns` 与 deadline remaining 算术 helper。
这类 helper 虽然不是 raw `external` 声明，但只要语义在各 POSIX 宿主间完全共享，且被多个 host ffi
owner / consumer 复用，就可以继续留在 shared `posix.ffi` 作为单一事实源。

同样，只要 helper 本身不携带宿主 capability truth，shared `posix.ffi` 也可以继续拥有参数化的
POSIX clock thin wrapper，例如 `platform_posix_clock_now`、
`platform_posix_clock_getres`、`platform_posix_clock_ns_u64`、
`platform_posix_clock_resolution_ns_u64`。这类 helper 统一承载 raw `clock_gettime` /
`clock_getres` 调用、shared `timespec` 投影与最小分辨率钳制；各 host ffi owner 只继续提供
clock id token、errno binding 与 timeout clock truth，再把这些 shared helper 委托出去。

因此，`linux/android/darwin/freebsd/unix.ffi` 这类 host ffi owner 继续暴露
`platform_clock_monotonic_now`、`platform_clock_realtime_now`、
`platform_clock_monotonic_getres` 以及更高层的
`platform_clock_monotonic_ns_u64`、`platform_clock_realtime_ns_u64`、
`platform_clock_monotonic_resolution_ns_u64` helper，但其实现可以是对 shared `posix.ffi`
clock helper 的薄委托。`platform.time` consumer 不再直接写 raw `clock_gettime` /
`clock_getres`、宿主 clock id，也尽量不再自己保留宿主专用 timespec 拼装流程。

`TDuration`、`TInstant`、`TStopwatch`、Timer 等时间抽象属于 L1 `nextpas.core.time`
或后续独立的 `nextpas.core.stopwatch` 模块。platform 层的示例、测试和基准只能验证
platform clock API 本身，不能把这些 L1 API 放进 `nextpas.core.platform.*` 命名空间。

### `platform.sync` 的边界

`nextpas.core.platform.sync` 只提供宿主同步原语：mutex、rwlock、condvar 与 address-wait。
它不提供 monitor、semaphore、channel、thread pool、scheduler 或其他 L1/L2 并发抽象。

Windows `SRWLOCK`、`CONDITION_VARIABLE`、`WaitOnAddress` 的 raw ABI 声明，以及围绕它们的
init/lock/trylock/unlock/destroy/wait/wake helper，都应尽量继续归
`nextpas.core.platform.windows.ffi` owner。`platform.sync` 只消费像
`windows_mutex_*`、`windows_rwlock_*`、`windows_condvar_*`、
`windows_wait_address_i32`、`windows_wake_address_*` 这类 host-owned helper，并保留
nextPas 自己的 public opaque storage contract 与跨平台 wait policy；如果 Windows helper 还需要把
宿主 false/timeout 结果投影成 nextPas public busy/timeout result，优先像
`windows_mutex_trylock_busy_result`、`windows_rwlock_tryrdlock_busy_result`、
`windows_rwlock_trywrlock_busy_result`、
`windows_condvar_timedwait_timeout_result`、
`windows_wait_address_i32_timeout_result` 这样用 caller-supplied result helper 继续留在 ffi owner，
而不是让 consumer 自己再写 `if windows_* ... then ... else ...` 分支。不要在 consumer 里重新散落 raw `InitializeSRWLock`、
`AcquireSRWLock*`、`SleepConditionVariableSRW`、`WaitOnAddress`、`WakeByAddress*`
调用。

同样，Linux futex 的 raw syscall 编号、`FUTEX_*` opcode 与 `syscall(...)` 拼装，也应继续归
`nextpas.core.platform.linux.ffi` owner。`platform.sync` 可以保留 nil/value mismatch 这类
nextPas public contract 检查，以及最终 public result 常量的选择；但 POSIX errno token 到
`PLATFORM_ERR_*` 的分类应继续归当前 host ffi owner，通过 caller-supplied result helper
完成，不要在 consumer 里重新散落 raw `linux_syscall`、`LINUX_SYSCALL_FUTEX`、`FUTEX_WAIT`、
`FUTEX_WAKE` 组合逻辑或 `PLATFORM_POSIX_E*` case；
优先消费 `linux_futex_wait_i32`、`linux_futex_wake_one_i32`、`linux_futex_wake_all_i32`
这类 host-owned helper。

`platform_wait_address32` 的 public mismatch 语义必须由 `platform.sync` 统一拥有。Linux futex、
Windows `WaitOnAddress` 与 POSIX fallback 在 raw API 层对“当前值已经不等于 expected”的返回形态
并不完全一样，因此所有 wait path 都应在进入 host wait helper 前消费同一个 `platform.sync`
public precheck：nil address 返回 `PLATFORM_ERR_INVALID`，value mismatch 返回
`PLATFORM_ERR_AGAIN`。timeout / last-error / raw wait success 仍由 host ffi helper 投影，不能把
`PLATFORM_ERR_AGAIN` 硬编码进 `windows.ffi` 或其他 host ffi owner。

同样，POSIX pthread mutex / rwlock / condvar / timeout-clock 的 raw 调用也应继续归当前宿主的
ffi owner，而不是继续留在 `platform.sync` consumer。即使 `pthread_mutex_*`、
`pthread_rwlock_*`、`pthread_cond_*` 与 `clock_gettime` 的 ABI 形状来自 shared `posix.ffi`，
mutex attr / cond attr 初始化、condattr clock capability、timeout clock id / errno truth 这类
宿主差异，仍属于 `linux/darwin/android/freebsd/unix.ffi` owner truth。

但 shared `posix.ffi` 也可以继续拥有 truly shared 的 pthread sync thin forwarder，例如
`platform_posix_pthread_mutex_destroy/lock/trylock/unlock`、
`platform_posix_pthread_rwlock_init/destroy/rdlock/tryrdlock/wrlock/trywrlock/unlock`、
`platform_posix_pthread_condvar_destroy/wait/timedwait_abs/signal/broadcast`。这些 helper 不携带
宿主 capability 差异，只统一承载 raw pthread 调用；各 host ffi owner 只把宿主 truth 叠在外层，
再把 shared forwarder 委托出去。

`pthread_mutex_timedlock` 这类 ABI 要按 FPC 源码证据和宿主 capability 分层落位：Linux/Android 与
FreeBSD 的 FPC pthread 声明可作为 ABI 依据，因此 raw declaration 和
`platform_posix_pthread_mutex_timedlock_abs` 这类 truly shared forwarder 可以进入
`posix.ffi`，但各 host 是否支持必须由 `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED` 等
host `.base` token 表达。没有足够依据或明确不支持的宿主（例如当前 Darwin / generic Unix 路径）
应在 host `.ffi` 暴露同名 helper 并返回 `PLATFORM_POSIX_ENOTSUP`，而不是让 consumer 猜测或直接
调用 raw pthread symbol。

同理，只要 helper 本身不内嵌宿主 truth，shared `posix.ffi` 也可以继续拥有参数化的 attr-init glue，
例如 `platform_posix_pthread_mutex_init_kind` 与
`platform_posix_pthread_condvar_init_with_clock`。这类 helper 统一承载
`pthread_mutexattr_*` / `pthread_condattr_*` / `pthread_cond_init` 的通用样板；各 host ffi owner
继续只提供 public kind 到宿主 kind 的映射、timeout clock id、condattr setclock binding 与
capability token，再把这些 truth 作为参数交给 shared helper。

同样，只要 helper 本身不携带宿主 truth，shared `posix.ffi` 也可以继续拥有更薄的一层参数化
projection skeleton，例如 `platform_posix_errno_value_from_location` 与
`platform_posix_sync_result_from_error`、`platform_posix_pthread_mutex_init_public_kind`。
`platform_posix_errno_value_from_location` 只统一承载 `errno-location -> current errno value` 的
解引用样板；`platform_posix_sync_result_from_error` 只统一承载 caller-supplied errno token 到
caller-supplied public result 的投影；`platform_posix_pthread_mutex_init_public_kind` 只统一承载
public mutex kind `(normal/errorcheck/recursive)` 到 caller-supplied host kind token 的投影，再复用
shared `platform_posix_pthread_mutex_init_kind`。各 host ffi owner 继续只保留
`platform_errno_location` symbol binding、`PLATFORM_POSIX_E*`、`PLATFORM_PTHREAD_MUTEX_*_KIND`
这类宿主 truth，不再各自复制同一份 load/public-result/public-kind projection skeleton。

同样，只要 helper 本身不携带宿主 truth，shared `posix.ffi` 也可以继续拥有参数化的 timeout
deadline skeleton，例如 `platform_posix_clock_deadline_after_ns` 与
`platform_posix_clock_deadline_remaining_ns_u64`。前者统一承载“按 caller-supplied clock id
读取当前时间并追加 ns timeout”的通用样板；后者统一承载“按同一 clock id 读取当前时间并计算离
absolute deadline 还剩多少 ns”的通用样板。各 host ffi owner 继续只保留
`PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID` 与 `platform_errno_location` 这类宿主 truth，再把这些 truth
作为参数交给 shared helper。

因此，优先消费 `platform_pthread_timeout_deadline_after_ns`、
`platform_pthread_timeout_remaining_ns_u64`、`platform_pthread_timeout_clock_now`、
`platform_pthread_mutex_init_platform_kind`、`platform_pthread_mutex_*`、
`platform_pthread_rwlock_*`、`platform_pthread_condvar_*`、`platform_pthread_sync_result`
这类 helper；`platform.sync` 只继续保留 NextPas 的 public result adapter、wait-bucket 策略
与跨平台 wake/wait public contract。public opaque storage contract 由
`nextpas.core.platform.sync.base` 统一拥有，包括 `TPlatformMutexAlign`、
`TPlatformRwLockAlign`、`TPlatformCondVarAlign`、`TPlatformMutex`、`TPlatformRwLock`、
`TPlatformCondVar`、`PLATFORM_MUTEX_SIZE`、`PLATFORM_RWLOCK_SIZE`、`PLATFORM_CONDVAR_SIZE`、
`PLATFORM_MUTEX_*` 与 `PLATFORM_ERR_*`。`nextpas.core.platform.sync` 只 re-export 这些
public type/constant 并实现统一 API，不能重新在 facade/implementation 单元里直接声明 opaque
record、host size alias 或 public error constant。对应地，`platform.sync`
不应继续自留 public mutex kind 到宿主 pthread kind 的映射逻辑，不应继续在 consumer 里直接
读取 pthread timeout clock、复制 shared POSIX `timespec` deadline arithmetic，或直接 case
宿主 `PLATFORM_POSIX_E*` errno token。

POSIX wait-bucket fallback 是 `platform.sync` 为 `platform_wait_address32` /
`platform_wake_address_*` 提供的跨平台 policy，不是宿主 ABI truth。`POSIX_WAIT_BUCKET_COUNT`、
`TPosixWaitBucket`、waiter/generation 计数、release predicate 与 forced fallback selector 应继续留在
`platform.sync`，用于把“Linux futex / Windows WaitOnAddress / generic POSIX condvar fallback”
收敛成同一组 public wait/wake 语义。host `.ffi` 只能拥有 raw futex、pthread condvar、Windows
WaitOnAddress 绑定及 caller-supplied result helper，不能反向拥有 wait-bucket 策略或创建
`platform.sync.ffi` 这类按 feature 切碎的 FFI 单元。所有 public wait/wake 入口还必须在
`platform.sync` 层先验证地址参数，例如 nil address 统一返回 `PLATFORM_ERR_INVALID`，不能把无效
public 输入直接交给宿主 ABI helper。

### `platform.thread` 的边界

`nextpas.core.platform.thread` 只提供宿主线程原语：线程创建、join/detach、当前线程身份、
yield/sleep、TLS key 与 CPU count。它不提供任务调度、线程池、channel、future、async runtime
或其他用户态并发模型。

`TPlatformThreadHandle` 只表示由 `platform_thread_create` 创建出来、需要调用方用
`platform_thread_join` 或 `platform_thread_detach` 完成生命周期收口的 owned handle。
`platform_thread_self` 返回 `TPlatformThreadToken`，这是当前线程的 unowned identity token，
不能传给 join/detach，也不能假定它与平台原生可等待 handle 同形。
`platform_thread_id` 返回宿主提供的 native thread id（例如 Linux/Android `gettid`、macOS
`pthread_threadid_np`、FreeBSD `pthread_getthreadid_np`）；它是稳定的整数标识，但不要求与
`platform_thread_self` 同值，也不能把它当作 join/detach handle 使用。
`TPlatformThreadHandle`、`TPlatformThreadToken`、`TPlatformThreadProc` 与 `TPlatformTLSKey`
这些 public carrier type 由 `nextpas.core.platform.thread.base` 统一拥有；
`nextpas.core.platform.thread` 只做 public re-export 与行为实现，不能重新在 facade/implementation
单元里直接声明 `Pointer`、`UInt64`、`PtrUInt` 形状。

同样，当前线程 token、native thread id、TLS key create/free/set/get、CPU count、
yield 这类宿主 helper 也应尽量继续归各自 host ffi owner。像 Windows
`GetCurrentThreadId` / `Tls*` / `GetSystemInfo`，以及 Unix
`pthread_self` / `gettid` / `pthread_threadid_np` / `pthread_getthreadid_np` /
`sysconf(_SC_NPROCESSORS_ONLN)` 的选择与 fallback，不应继续散落在 `platform.thread`
consumer 里。

POSIX pthread lifecycle / TLS / yield / sleep 的 raw 调用也应继续归选定宿主的 ffi owner，而不是
留在 `platform.thread` consumer。即使 `pthread_create` / `pthread_join` / `pthread_detach`、
`pthread_key_*`、`sched_yield`、`nanosleep` 的 ABI 形状来自 shared `posix.ffi`，真正的宿主
retry / errno / token truth 仍然属于当前选择的 `linux/darwin/android/freebsd/unix.ffi` owner。
`platform.thread` 不直接消费低层 `platform_pthread_create_handle` /
`platform_pthread_join_handle` / `platform_pthread_detach_handle`，也不在 consumer 中保存
`PPosixThreadState` / `TPosixThreadState`、`New` / `Dispose` 或 pthread token storage offset。
POSIX thread state carrier 类型放在各 host `.base`，创建、join、detach 与 state 释放放在各
host `.ffi` 的 `platform_pthread_state_create/join/detach` helper；shared `posix.ffi` 只提供对
pthread token storage 的通用 create/join/detach 胶水。`platform.thread` 只继续保留
`TPlatformThreadHandle` 的 public contract，并消费 host-owned state helper、
`platform_pthread_yield`、`platform_pthread_sleep_ns` 与 `platform_pthread_tls_*`。

Windows 线程生命周期相关的 raw 宿主调用也应继续归
`nextpas.core.platform.windows.ffi` owner。像 `CreateThread`、
`WaitForSingleObject`、`CloseHandle`、`Sleep` 与 `InterlockedDecrement`
这类 API，不应继续直接散落在 `platform.thread` consumer 里；优先由
`windows_thread_create_handle`、`windows_thread_wait_terminated`、
`windows_thread_close_handle`、`windows_thread_sleep_ns`、
`windows_atomic_decrement_i32` 这类 host-owned helper 提供。`platform.thread`
只继续保留 `TPlatformThreadHandle` 的 public contract、join/detach 收口时机、
thread entry state 与返回值语义，而不重新承担 Windows handle lifecycle /
sleep / atomic refcount 的 ABI truth。

如果 Windows consumer 只是为了桥接宿主 ABI 形状而声明本地 `HANDLE` 字段、`DWORD` TLS key、
`stdcall` thread entry thunk 或 refcount state record，那这层 ABI type leakage 也应继续收回
`nextpas.core.platform.windows.ffi`。优先把 `TPlatformWindowsThreadState`、
`windows_thread_state_create/join/detach`、`windows_tls_create_platform_key` /
`destroy/set/get` 这类 helper/type 放在 ffi owner 单元里，让 `platform.thread`
尽量只消费 nextPas-owned contract 与 host-owned wrapper，不在 consumer 里重新展开 raw Windows
type / calling convention 细节。

`ThreadPool`、`TChannel`、`Future`、Scheduler、Task 等抽象属于 L1 `nextpas.core.thread`
或更高层模块。platform.thread 的测试、示例、基准只能验证 L0 线程 API 本身，不能把这些 L1
并发抽象放进 `nextpas.core.platform.*` 命名空间。

### 框架整体依赖规则

| 允许依赖                                                          | 不允许依赖                                                                             |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| FPC System 单元（隐式）— nextPas 会平替                           | SysUtils、Classes、Linux、PThreads、UnixType、BaseUnix、Syscall、Windows 等 FPC 库单元 |
| 编译器内置特性（string、动态数组、interface、try/except、GetMem） | 任何 FPC 特有的库/包                                                                   |
| 自己的 FFI 声明（cdecl/stdcall external）                         |                                                                                        |

**注意：** 当前自举阶段（FPC 3.3.1 编译），部分模块暂时使用了 SysUtils（Exception、TBytes、Format 等）。这是已知的临时依赖，需要逐步替换为框架自身提供的等价实现。新代码应尽量避免引入新的 FPC 单元依赖。

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
