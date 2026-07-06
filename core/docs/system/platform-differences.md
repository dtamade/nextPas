# nextpas.core.system Platform Differences

本规范定义 system kernel 在不同目标平台上的差异、平台特定行为和跨平台编程指南。

## 1. 支持的平台

### 1.1 平台矩阵

| 平台 | 架构 | 状态 | 备注 |
|------|------|------|------|
| linux-x86_64 | AMD64 | ✅ 主要平台 | 完整支持 |
| linux-aarch64 | ARM64 | 🔲 计划中 | 未来支持 |
| windows-x86_64 | AMD64 | 🔲 计划中 | 未来支持 |
| darwin-x86_64 | AMD64 | 🔲 计划中 | macOS Intel |
| darwin-aarch64 | ARM64 | 🔲 计划中 | macOS Apple Silicon |

### 1.2 平台标识

```pascal
{ 操作系统标识 }
{$IFDEF LINUX}
  // Linux 特定代码
{$ENDIF}

{$IFDEF WINDOWS}
  // Windows 特定代码
{$ENDIF}

{$IFDEF DARWIN}
  // macOS 特定代码
{$ENDIF}

{ 架构标识 }
{$IFDEF CPU64}
  // 64-bit 特定代码
{$ENDIF}

{$IFDEF CPU32}
  // 32-bit 特定代码
{$ENDIF}

{$IFDEF CPUX86_64}
  // x86_64 特定代码
{$ENDIF}

{$IFDEF CPUAARCH64}
  // ARM64 特定代码
{$ENDIF}

{ 字节序标识 }
{$IFDEF ENDIAN_LITTLE}
  // 小端字节序
{$ENDIF}

{$IFDEF ENDIAN_BIG}
  // 大端字节序
{$ENDIF}
```

## 2. 基本类型差异

### 2.1 指针大小

| 类型 | 32-bit | 64-bit |
|------|--------|--------|
| `SizeInt` | 4 bytes (LongInt) | 8 bytes (Int64) |
| `SizeUInt` | 4 bytes (LongWord) | 8 bytes (QWord) |
| `PtrInt` | 4 bytes (LongInt) | 8 bytes (Int64) |
| `PtrUInt` | 4 bytes (LongWord) | 8 bytes (QWord) |
| `NativeInt` | 4 bytes (LongInt) | 8 bytes (Int64) |
| `NativeUInt` | 4 bytes (LongWord) | 8 bytes (QWord) |
| `Pointer` | 4 bytes | 8 bytes |

**使用规则**：
- 数组索引、内存大小用 `SizeInt`
- 指针运算用 `PtrInt`/`PtrUInt`
- 与 C 库交互用 `CLong`/`CULong`

### 2.2 C ABI 类型

| 类型 | linux-x86_64 | windows-x86_64 | linux-aarch64 |
|------|-------------|----------------|---------------|
| `CInt` | 4 bytes (LongInt) | 4 bytes (LongInt) | 4 bytes (LongInt) |
| `CUInt` | 4 bytes (LongWord) | 4 bytes (LongWord) | 4 bytes (LongWord) |
| `CLong` | 8 bytes (Int64) | 4 bytes (LongInt) | 8 bytes (Int64) |
| `CULong` | 8 bytes (QWord) | 4 bytes (LongWord) | 8 bytes (QWord) |
| `CChar` | 1 byte (AnsiChar) | 1 byte (AnsiChar) | 1 byte (AnsiChar) |

**注意**：
- Windows 上 `long` 是 4 字节，Linux/macOS 上是 8 字节
- 与 C 库交互时必须使用正确的 `CLong`/`CULong`

### 2.3 字符类型

| 类型 | FPC 默认 | nextPas 默认 |
|------|---------|-------------|
| `Char` | AnsiChar (1 byte) | WideChar (2 bytes) |
| `String` | AnsiString | UnicodeString |

**使用规则**：
- 处理 ASCII 用 `AnsiChar`/`AnsiString`
- 处理 Unicode 用 `WideChar`/`UnicodeString`
- 与 C 库交互用 `CChar`/`PAnsiChar`

## 3. 字节序差异

### 3.1 字节序类型

| 字节序 | 架构 | 特征 |
|--------|------|------|
| 小端 (Little-Endian) | x86, x86_64, ARM (默认) | 低位字节在前 |
| 大端 (Big-Endian) | PowerPC, SPARC, 网络协议 | 高位字节在前 |

### 3.2 字节序检测

```pascal
{$IFDEF ENDIAN_LITTLE}
  // 小端平台
  const IsLittleEndian = True;
{$ENDIF}

{$IFDEF ENDIAN_BIG}
  // 大端平台
  const IsLittleEndian = False;
{$ENDIF}
```

### 3.3 字节序转换

```pascal
// 平台无关的字节序转换
function SwapEndian(AValue: LongInt): LongInt;

// 大端到平台本机字节序
function BEtoN(AValue: LongInt): LongInt;

// 小端到平台本机字节序
function LEtoN(AValue: LongInt): LongInt;

// 平台本机字节序到大端
function NtoBE(AValue: LongInt): LongInt;

// 平台本机字节序到小端
function NtoLE(AValue: LongInt): LongInt;

// 网络字节序（大端）转换
function HTonN(AValue: Word): Word;
function HTonN(AValue: LongWord): LongWord;
function NToHs(AValue: Word): Word;
function NToHs(AValue: LongWord): LongWord;
```

### 3.4 使用示例

```pascal
// 网络编程中的字节序转换
var
  LPort: Word;
begin
  LPort := 8080;
  // 端口号需要转换为网络字节序（大端）
  LPort := HTonN(LPort);
end;

// 读取二进制文件
var
  LValue: LongInt;
begin
  // 假设文件是小端格式
  BlockRead(F, LValue, SizeOf(LValue));
  LValue := LEtoN(LValue);  // 转换为平台本机字节序
end;
```

## 4. 调用约定差异

### 4.1 调用约定矩阵

| 调用约定 | linux-x86_64 | windows-x86_64 | linux-aarch64 |
|---------|-------------|----------------|---------------|
| `register` | System V AMD64 ABI | Microsoft x64 ABI | AAPCS64 |
| `cdecl` | System V AMD64 ABI | Microsoft x64 ABI | AAPCS64 |
| `stdcall` | 不支持 | Microsoft x64 ABI | 不支持 |
| `pascal` | 不支持 | 不支持 | 不支持 |

### 4.2 register 调用约定

**linux-x86_64 (System V AMD64 ABI)**：
- 整数参数：RDI, RSI, RDX, RCX, R8, R9
- 浮点参数：XMM0-XMM7
- 返回值：RAX (整数), XMM0 (浮点)
- 栈对齐：16 字节

**windows-x86_64 (Microsoft x64 ABI)**：
- 整数参数：RCX, RDX, R8, R9
- 浮点参数：XMM0-XMM3
- 返回值：RAX (整数), XMM0 (浮点)
- 栈对齐：16 字节
- 影子空间：32 字节

**linux-aarch64 (AAPCS64)**：
- 整数参数：X0-X7
- 浮点参数：D0-D7
- 返回值：X0 (整数), D0 (浮点)
- 栈对齐：16 字节

### 4.3 接口调用约定

接口方法使用 `stdcall` 调用约定（COM 兼容）：

```pascal
IUnknown = interface
  function QueryInterface(const IID: TGUID; out Obj): LongInt; stdcall;
  function _AddRef: LongInt; stdcall;
  function _Release: LongInt; stdcall;
end;
```

**注意**：
- Windows 上 `stdcall` 是真正的 stdcall
- Linux/macOS 上 `stdcall` 映射到 `cdecl`

## 5. VMT 布局差异

### 5.1 VMT 偏移

VMT 布局在所有平台上相同（与 FPC 兼容）：

```pascal
vmtInstanceSize = 0;
vmtParent = SizeOf(SizeInt) * 2;      // 16 on 64-bit, 8 on 32-bit
vmtClassName = SizeOf(SizeInt) * 3;    // 24 on 64-bit, 12 on 32-bit
// ...
```

**注意**：
- VMT 偏移使用 `SizeOf(SizeInt)` 计算，在 32-bit 和 64-bit 上自动调整
- VMT 布局常量已冻结，不得修改

### 5.2 实例大小

```pascal
// 64-bit 平台
TObject = class
  // VMT 指针: 8 bytes
end;
// InstanceSize = 8

// 32-bit 平台
TObject = class
  // VMT 指针: 4 bytes
end;
// InstanceSize = 4
```

## 6. 内存布局差异

### 6.1 字符串布局

**AnsiString**（所有平台相同）：
```
offset -12: CodePage (2 bytes)
offset -10: ElementSize (2 bytes)
offset -8:  RefCount (4 bytes)
offset -4:  Length (4 bytes)
offset  0:  Data
```

**UnicodeString**（所有平台相同）：
```
offset -12: CodePage (2 bytes, = 65001)
offset -10: ElementSize (2 bytes, = 2)
offset -8:  RefCount (4 bytes)
offset -4:  Length (4 bytes, in chars)
offset  0:  Data (UTF-16LE)
```

**注意**：
- 字符串布局在所有平台上相同
- 引用计数是 4 字节有符号整数

### 6.2 动态数组布局

```
offset -8:  RefCount (4 bytes)
offset -4:  Length (4 bytes)
offset  0:  Data
```

**注意**：
- 动态数组布局在所有平台上相同
- 元素对齐取决于元素类型

### 6.3 Variant 布局

```
offset 0:  VType (2 bytes)
offset 2:  Reserved (6 bytes)
offset 8:  Payload (8 bytes)
```

**注意**：
- Variant 布局在所有平台上相同
- Payload 解释取决于 VType

## 7. 线程模型差异

### 7.1 线程实现

| 平台 | 线程实现 | 备注 |
|------|---------|------|
| Linux | pthread | POSIX 线程 |
| Windows | Windows Threads | Win32 API |
| macOS | pthread | POSIX 线程 |

### 7.2 临界区实现

| 平台 | 实现 | 备注 |
|------|------|------|
| Linux | pthread_mutex_t | POSIX 互斥锁 |
| Windows | CRITICAL_SECTION | Win32 临界区 |
| macOS | pthread_mutex_t | POSIX 互斥锁 |

**注意**：
- `TRTLCriticalSection` 是平台相关的 opaque 类型
- 在 Linux/macOS 上是 `pthread_mutex_t`（40 bytes）
- 在 Windows 上是 `CRITICAL_SECTION`（40 bytes）

### 7.3 线程 ID

| 平台 | 类型 | 大小 |
|------|------|------|
| Linux | pthread_t | 8 bytes |
| Windows | DWORD | 4 bytes |
| macOS | pthread_t | 8 bytes |

**注意**：
- `TThreadID` 定义为 `QWord`（8 bytes），兼容所有平台

## 8. I/O 差异

### 8.1 文件路径分隔符

| 平台 | 分隔符 | 示例 |
|------|--------|------|
| Linux | `/` | `/home/user/file.txt` |
| Windows | `\` | `C:\Users\user\file.txt` |
| macOS | `/` | `/Users/user/file.txt` |

**使用规则**：
- 使用 `PathDelim` 常量获取平台分隔符
- 使用 `IncludeTrailingPathDelimiter` 添加分隔符
- 使用 `ExtractFilePath`/`ExtractFileName` 操作路径

### 8.2 换行符

| 平台 | 换行符 | ASCII |
|------|--------|-------|
| Linux | LF | #10 |
| Windows | CR+LF | #13#10 |
| macOS | LF | #10 |

**使用规则**：
- 使用 `LineEnding` 常量获取平台换行符
- 文本模式文件自动处理换行符转换

### 8.3 文件句柄

| 平台 | 类型 | 备注 |
|------|------|------|
| Linux | cint (int) | POSIX 文件描述符 |
| Windows | HANDLE | Win32 句柄 |
| macOS | cint (int) | POSIX 文件描述符 |

**注意**：
- `TFileRec.Handle` 是 `LongInt`，兼容所有平台
- Windows 上需要特殊处理句柄转换

## 9. 信号和异常差异

### 9.1 信号处理

| 平台 | 信号机制 | 备注 |
|------|---------|------|
| Linux | POSIX signals | SIGSEGV, SIGFPE, etc. |
| Windows | Structured Exception Handling (SEH) | __try/__except |
| macOS | POSIX signals | SIGSEGV, SIGFPE, etc. |

### 9.2 异常展开

| 平台 | 展开机制 | 备注 |
|------|---------|------|
| Linux | DWARF-based | .eh_frame section |
| Windows | SEH-based | .pdata section |
| macOS | DWARF-based | .eh_frame section |

**注意**：
- nextPas 计划使用 table-based exceptions
- 不同平台的展开表格式不同

## 10. 平台特定函数

### 10.1 平台检测

```pascal
function GetPlatform: string;
begin
  {$IFDEF LINUX}
  Result := 'linux';
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := 'windows';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := 'darwin';
  {$ENDIF}
end;
```

### 10.2 架构检测

```pascal
function GetArchitecture: string;
begin
  {$IFDEF CPUX86_64}
  Result := 'x86_64';
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  Result := 'aarch64';
  {$ENDIF}
end;
```

### 10.3 字节序检测

```pascal
function IsLittleEndian: Boolean;
begin
  {$IFDEF ENDIAN_LITTLE}
  Result := True;
  {$ENDIF}
  {$IFDEF ENDIAN_BIG}
  Result := False;
  {$ENDIF}
end;
```

## 11. 跨平台编程指南

### 11.1 类型选择

| 场景 | 推荐类型 | 避免类型 |
|------|---------|---------|
| 数组索引 | `SizeInt` | `LongInt` |
| 指针运算 | `PtrInt`/`PtrUInt` | `LongInt` |
| C 交互 | `CInt`/`CLong` | `LongInt` |
| 文件大小 | `Int64` | `LongInt` |
| 时间戳 | `Int64` | `LongInt` |

### 11.2 字符串处理

```pascal
// ✅ 正确：使用 UnicodeString 处理文本
var
  LText: UnicodeString;
begin
  LText := '你好，世界！';
end;

// ✅ 正确：使用 AnsiString 与 C 库交互
var
  LPath: AnsiString;
begin
  LPath := '/home/user/file.txt';
end;

// ❌ 错误：假设 Char 是 1 字节
var
  LChar: Char;
begin
  LChar := 'A';
  WriteLn(SizeOf(LChar));  // 可能是 2（nextPas）或 1（FPC）
end;
```

### 11.3 文件路径

```pascal
// ✅ 正确：使用 PathDelim
var
  LPath: string;
begin
  LPath := 'home' + PathDelim + 'user' + PathDelim + 'file.txt';
end;

// ✅ 正确：使用路径函数
var
  LPath: string;
begin
  LPath := IncludeTrailingPathDelimiter('/home/user') + 'file.txt';
end;

// ❌ 错误：硬编码路径分隔符
var
  LPath: string;
begin
  LPath := '/home/user/file.txt';  // Linux only
  LPath := 'C:\Users\user\file.txt';  // Windows only
end;
```

### 11.4 字节序

```pascal
// ✅ 正确：使用字节序函数
var
  LValue: LongInt;
begin
  LValue := LEtoN(LittleEndianValue);  // 小端到本机
  LValue := BEtoN(BigEndianValue);     // 大端到本机
end;

// ❌ 错误：假设字节序
var
  LBytes: array[0..3] of Byte;
  LValue: LongInt;
begin
  // 假设小端
  LValue := PLongInt(@LBytes)^;  // 可能在大端平台上错误
end;
```

### 11.5 调用约定

```pascal
// ✅ 正确：使用默认调用约定
procedure MyProc(AValue: LongInt);
begin
  // 使用 register 调用约定
end;

// ✅ 正确：接口使用 stdcall
IUnknown = interface
  function QueryInterface(const IID: TGUID; out Obj): LongInt; stdcall;
end;

// ❌ 错误：使用不存在的调用约定
procedure MyProc(AValue: LongInt); safecall;  // 可能不支持
```

## 12. 平台特定代码组织

### 12.1 条件编译

```pascal
// 在 .inc 文件中使用条件编译
{$IFDEF LINUX}
  {$I nextpas.core.system.linux.inc}
{$ENDIF}

{$IFDEF WINDOWS}
  {$I nextpas.core.system.windows.inc}
{$ENDIF}

{$IFDEF DARWIN}
  {$I nextpas.core.system.darwin.inc}
{$ENDIF}
```

### 12.2 平台抽象层

```pascal
// 平台抽象接口
type
  IPlatformOS = interface
    function GetPlatformName: string;
    function GetLastError: LongInt;
    // ...
  end;

// 平台特定实现
type
  TLinuxOS = class(TInterfacedObject, IPlatformOS)
    function GetPlatformName: string;
    function GetLastError: LongInt;
    // ...
  end;

  TWindowsOS = class(TInterfacedObject, IPlatformOS)
    function GetPlatformName: string;
    function GetLastError: LongInt;
    // ...
  end;
```

### 12.3 运行时检测

```pascal
// 运行时检测平台
function GetPlatformName: string;
begin
  {$IFDEF LINUX}
  Result := 'Linux';
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := 'Windows';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := 'macOS';
  {$ENDIF}
end;

// 运行时检测架构
function GetArchitectureName: string;
begin
  {$IFDEF CPUX86_64}
  Result := 'x86_64';
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  Result := 'aarch64';
  {$ENDIF}
end;
```

## 13. 平台兼容性测试

### 13.1 测试矩阵

| 测试类型 | Linux x86_64 | Windows x86_64 | macOS x86_64 | macOS aarch64 |
|---------|-------------|----------------|--------------|---------------|
| 编译测试 | ✅ | 🔲 | 🔲 | 🔲 |
| 单元测试 | ✅ | 🔲 | 🔲 | 🔲 |
| 集成测试 | ✅ | 🔲 | 🔲 | 🔲 |
| 性能测试 | ✅ | 🔲 | 🔲 | 🔲 |

### 13.2 跨平台测试

```pascal
// 平台特定测试
procedure TestPlatformSpecific;
begin
  {$IFDEF LINUX}
  // Linux 特定测试
  Assert(PathDelim = '/');
  {$ENDIF}

  {$IFDEF WINDOWS}
  // Windows 特定测试
  Assert(PathDelim = '\');
  {$ENDIF}
end;

// 字节序测试
procedure TestEndian;
var
  LValue: LongInt;
begin
  LValue := $01020304;
  {$IFDEF ENDIAN_LITTLE}
  Assert(PByte(@LValue)^ = $04);
  {$ENDIF}
  {$IFDEF ENDIAN_BIG}
  Assert(PByte(@LValue)^ = $01);
  {$ENDIF}
end;
```

## 14. 平台特定注意事项

### 14.1 Linux 特定

1. **文件路径**：区分大小写
2. **文件权限**：使用 POSIX 权限模型
3. **信号处理**：使用 POSIX 信号
4. **线程**：使用 pthread
5. **动态库**：.so 文件

### 14.2 Windows 特定

1. **文件路径**：不区分大小写（但保留大小写）
2. **文件权限**：使用 ACL 权限模型
3. **异常处理**：使用 SEH
4. **线程**：使用 Windows Threads
5. **动态库**：.dll 文件
6. **换行符**：CR+LF
7. **路径分隔符**：反斜杠 `\`

### 14.3 macOS 特定

1. **文件路径**：区分大小写（默认 HFS+ 不区分）
2. **文件权限**：使用 POSIX 权限模型
3. **信号处理**：使用 POSIX 信号
4. **线程**：使用 pthread
5. **动态库**：.dylib 文件
6. **代码签名**：需要代码签名

## 15. 迁移指南

### 15.1 从 32-bit 迁移到 64-bit

1. 使用 `SizeInt` 代替 `LongInt` 作为数组索引
2. 使用 `PtrInt`/`PtrUInt` 进行指针运算
3. 检查整数溢出（`SizeInt` 比 `LongInt` 大）
4. 检查指针大小假设

### 15.2 从 Linux 迁移到 Windows

1. 使用 `PathDelim` 代替硬编码路径分隔符
2. 使用 `LineEnding` 代替硬编码换行符
3. 检查文件路径大小写
4. 检查文件权限模型

### 15.3 从 x86_64 迁移到 aarch64

1. 检查字节序假设
2. 检查对齐要求
3. 检查调用约定
4. 检查内联汇编

## 16. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | ABI 细节：类型大小、内存布局 |
| `api-reference.md` | API 清单：类型、函数、常量 |
| `design-decisions.md` | 设计决策：DD-3 VMT 布局、DD-12 线程模型 |
| `thread-safety.md` | 线程安全：同步原语、并发编程 |
| `error-handling.md` | 错误处理：异常、信号 |
