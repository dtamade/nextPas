# nextpas.core.system Usage Guide

本手册指导开发者如何扩展和使用 system kernel。面向两类读者：
- **内核贡献者**：扩展内核功能
- **框架消费者**：使用内核类型和函数

## 1. 快速开始

### 1.1 引入 system

```pascal
uses nextpas.core.system;           // 根门面：基础类型、常量、内核
uses nextpas.core.system.typinfo;   // RTTI 门面：PTypeInfo、GetEnumName 等
uses nextpas.core.system.sysutils;  // SysUtils 门面：FileExists、ExtractFilePath 等
uses nextpas.core.system.errors;    // 异常门面：EArgumentError、ecArgument 等
```

### 1.2 基本用法

```pascal
uses nextpas.core.system;

var
  LBytes: TBytes;
  LObj: TObject;
begin
  // 动态数组
  SetLength(LBytes, 1024);
  FillByte(LBytes[0], Length(LBytes), 0);

  // 对象创建
  LObj := TObject.Create;
  try
    WriteLn(LObj.ClassName);  // 'TObject'
  finally
    LObj.Free;
  end;
end;
```

## 2. 扩展内核

### 2.1 添加新类型

**规则**：新类型必须放在正确的子模块中。

| 类型类别 | 放置位置 | 示例 |
|---------|---------|------|
| 基础类型（整数、指针） | `base.inc` | `SizeInt`, `PByte` |
| 字符串类型 | `str.inc` | `AnsiString`, `UnicodeString` |
| 接口类型 | `intf.inc` | `TGUID`, `IUnknown` |
| 类类型 | `cls.inc` | `TObject`, `TClass` |
| RTTI 类型 | `rtti.inc` | `TTypeKind`, `TTypeInfo` |
| 异常类型 | `except.inc` | `Exception`, `EAbort` |
| 线程类型 | `thread.inc` | `TThread`, `TRTLCriticalSection` |
| I/O 类型 | `io.inc` | `TFileRec`, `TTextRec` |

**步骤**：

1. 确定类型类别
2. 打开对应的 `.inc` 文件
3. 在 `type` 块中添加类型定义
4. 如果需要实现，在 `implementation` 块中添加
5. 更新 `abi-specification.md` 的内存布局
6. 更新 `api-reference.md` 的类型清单
7. 添加测试

**示例**：添加一个新的整数类型

```pascal
// 在 base.inc 的 type 块中添加
type
  {$IFDEF CPU64}
    MaxInt = Int64;
  {$ELSE}
    MaxInt = LongInt;
  {$ENDIF}
```

### 2.2 添加新函数

**规则**：函数必须放在正确的子模块中，并遵循 owner boundary。

| 函数类别 | 放置位置 | 示例 |
|---------|---------|------|
| 内存操作 | `mem.inc` | `ZeroMem`, `FreeAndNil` |
| 字节序转换 | `endian.inc` | `SwapEndian`, `BEtoN` |
| 内存屏障 | `barrier.inc` | `ReadBarrier`, `WriteBarrier` |
| 内建函数 | `intrinsics.inc` | `FillByte`, `IndexChar` |
| 线程管理 | `thread.inc` | `BeginThread`, `EnterCriticalSection` |
| I/O 操作 | `io.inc` | `AssignFile`, `Read`, `Write` |
| 内存管理器 | `memmgr.inc` | `GetMemoryManager`, `SetMemoryManager` |
| 生命周期 | `lifecycle.inc` | `InitModule`, `FinalizeModule` |

**步骤**：

1. 确定函数类别
2. 打开对应的 `.inc` 文件
3. 在 `interface` 部分声明函数
4. 在 `implementation` 部分实现函数
5. 更新 `api-reference.md` 的函数清单
6. 添加测试

**示例**：添加内存比较函数

```pascal
// 在 mem.inc 的 interface 部分
function CompareMemRange(const APtr1, APtr2; ASize: SizeInt): SizeInt;

// 在 mem.inc 的 implementation 部分
function CompareMemRange(const APtr1, APtr2; ASize: SizeInt): SizeInt;
var
  LP1, LP2: PByte;
  I: SizeInt;
begin
  LP1 := @APtr1;
  LP2 := @APtr2;
  for I := 0 to ASize - 1 do
  begin
    if LP1[I] <> LP2[I] then
      Exit(I);
  end;
  Result := ASize;
end;
```

### 2.3 添加新的 fpc_* 函数

**规则**：fpc_* 函数是编译器内部函数，只有编译器需要时才添加。

**步骤**：

1. 确认编译器确实需要这个函数
2. 在 `comp.inc` 中添加声明（带 `compilerproc` 指令）
3. 添加桩实现（真实实现由运行时提供）
4. 更新 `abi-specification.md` 的 fpc_* 清单
5. 更新 `runtime-contracts.md` 的契约映射

**示例**：添加新的字符串函数

```pascal
// 在 comp.inc 中
function np_ansistr_upper(S: Pointer): AnsiString; compilerproc;

// 在 implementation 部分
function np_ansistr_upper(S: Pointer): AnsiString;
begin
  Result := '';  // 桩实现
end;
```

### 2.4 扩展 TypInfo 门面

**规则**：扩展需要有真实消费压力和 `Needs Review` 流程。

**步骤**：

1. 确认有真实消费压力（不是"未来可能需要"）
2. 准备 `Needs Review` 包：
   - 符号列表
   - Owner 边界
   - Focused API 测试
3. 通过审查后，在 `typinfo.pas` 中添加
4. 更新 `typinfo-minimal-pressure.md`

**示例**：添加 `GetTypeKind` 函数

```pascal
// 在 typinfo.pas 中
function GetTypeKind(ATypeInfo: PTypeInfo): TTypeKind;
begin
  Result := ATypeInfo^.Kind;
end;
```

### 2.5 扩展 SysUtils 门面

**规则**：扩展必须委托给 owner 模块，不能直接实现。

**步骤**：

1. 确认函数属于哪个 owner 模块
2. 确认 owner 模块已实现该函数
3. 在 `sysutils.pas` 中添加委托函数
4. 添加测试

**示例**：添加 `ExpandFileName` 函数

```pascal
// 在 sysutils.pas 中
function ExpandFileName(const AFileName: string): string;
begin
  Result := nextpas.core.path.ExpandFileName(AFileName);
end;
```

## 3. 使用内核类型

### 3.1 使用 SizeInt

```pascal
var
  LSize: SizeInt;
begin
  LSize := SizeOf(Pointer);  // 8 on 64-bit, 4 on 32-bit
  LSize := Length(SomeArray); // 数组长度
  LSize := SizeInt(Pointer);  // 指针转整数
end;
```

### 3.2 使用 TBytes

```pascal
var
  LBytes: TBytes;
begin
  SetLength(LBytes, 1024);
  FillByte(LBytes[0], Length(LBytes), 0);
  LBytes[0] := $FF;
  SetLength(LBytes, 0);  // 释放
end;
```

### 3.3 使用 Variant

```pascal
var
  LVar: Variant;
begin
  LVar := 42;           // varInteger
  LVar := 'Hello';      // varUString
  LVar := 3.14;         // varDouble
  LVar := True;         // varBoolean
  LVar := Null;         // varNull
  LVar := Unassigned;   // varEmpty
end;
```

### 3.4 使用 TGUID

```pascal
const
  IID_IMyInterface: TGUID = '{12345678-1234-1234-1234-123456789ABC}';

var
  LGUID: TGUID;
begin
  LGUID := IID_IMyInterface;
  if LGUID = IID_IMyInterface then
    WriteLn('Match');
end;
```

### 3.5 使用接口

```pascal
type
  IMyInterface = interface(IUnknown)
    ['{12345678-1234-1234-1234-123456789ABC}']
    procedure DoSomething;
  end;

  TMyClass = class(TObject, IMyInterface)
    procedure DoSomething;
    // IUnknown 由编译器自动实现
  end;

procedure TMyClass.DoSomething;
begin
  WriteLn('Hello from interface');
end;

var
  LIntf: IMyInterface;
begin
  LIntf := TMyClass.Create;
  LIntf.DoSomething;
  // LIntf 离开作用域时自动释放
end;
```

### 3.6 使用 RTTI

```pascal
uses nextpas.core.system, nextpas.core.system.typinfo;

type
  TColor = (clRed, clGreen, clBlue);

var
  LInfo: PTypeInfo;
  LName: ShortString;
  LValue: SizeInt;
begin
  LInfo := TypeInfo(TColor);

  // 枚举名 → 值
  LValue := GetEnumValue(LInfo, 'clGreen');  // 1

  // 值 → 枚举名
  LName := GetEnumName(LInfo, 0);  // 'clRed'
end;
```

### 3.7 使用异常

```pascal
uses nextpas.core.system, nextpas.core.system.errors;

procedure DoSomething;
begin
  raise EArgumentError.Create('Invalid argument');
end;

begin
  try
    DoSomething;
  except
    on E: EArgumentError do
      WriteLn('Argument error: ', E.Message);
    on E: Exception do
      WriteLn('Other error: ', E.Message);
  end;
end.
```

## 4. 使用门面函数

### 4.1 数值转换

```pascal
uses nextpas.core.system.sysutils;

var
  I: LongInt;
  I64: Int64;
  F: Double;
  S: string;
begin
  I := StrToInt('42');           // 42
  I64 := StrToInt64('1234567890'); // 1234567890
  F := StrToFloat('3.14');       // 3.14

  S := IntToStr(42);             // '42'
  S := IntToStr(I64);            // '1234567890'
  S := FloatToStr(3.14);         // '3.14'
end;
```

### 4.2 文件系统

```pascal
uses nextpas.core.system.sysutils;

var
  LPath: string;
begin
  LPath := GetCurrentDir;
  WriteLn('Current: ', LPath);

  if not DirectoryExists('data') then
    CreateDir('data');

  if FileExists('config.ini') then
    CopyFile('config.ini', 'config.bak');

  DeleteFile('temp.txt');
end;
```

### 4.3 路径操作

```pascal
uses nextpas.core.system.sysutils;

var
  LPath, LName, LExt: string;
begin
  LPath := '/home/user/file.txt';

  LName := ExtractFileName(LPath);   // 'file.txt'
  LExt := ExtractFileExt(LPath);     // '.txt'
  LPath := ExtractFilePath(LPath);   // '/home/user/'

  LPath := ChangeFileExt(LPath, '.pas'); // '/home/user/file.pas'
  LPath := IncludeTrailingPathDelimiter('/home/user'); // '/home/user/'
end;
```

### 4.4 环境变量

```pascal
uses nextpas.core.system.sysutils;

var
  LHome, LPath: string;
  I: LongInt;
begin
  LHome := GetEnvironmentVariable('HOME');
  WriteLn('Home: ', LHome);

  for I := 0 to ParamCount do
    WriteLn('Param[', I, ']: ', ParamStr(I));
end;
```

### 4.5 错误处理

```pascal
uses nextpas.core.system.sysutils, nextpas.core.system.errors;

begin
  try
    // 某些操作
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      WriteLn('Last OS error: ', GetLastOSError);
      WriteLn('OS message: ', SysErrorMessage(GetLastOSError));
    end;
  end;
end.
```

## 5. 使用线程

### 5.1 创建线程

```pascal
uses nextpas.core.system;

type
  TMyThread = class(TThread)
  protected
    procedure Execute; override;
  end;

procedure TMyThread.Execute;
begin
  while not Terminated do
  begin
    // 执行工作
    Sleep(100);
  end;
end;

var
  LThread: TMyThread;
begin
  LThread := TMyThread.Create(False);  // 立即启动
  try
    // 主线程继续工作
    Sleep(1000);
    LThread.Terminate;
    LThread.WaitFor;
  finally
    LThread.Free;
  end;
end;
```

### 5.2 使用临界区

```pascal
uses nextpas.core.system;

var
  LSection: TRTLCriticalSection;
  LCounter: LongInt = 0;

procedure IncrementCounter;
begin
  EnterCriticalSection(LSection);
  try
    Inc(LCounter);
  finally
    LeaveCriticalSection(LSection);
  end;
end;

begin
  InitCriticalSection(LSection);
  try
    // 多线程调用 IncrementCounter
  finally
    DoneCriticalSection(LSection);
  end;
end.
```

### 5.3 使用原子操作

```pascal
uses nextpas.core.system;

var
  LCounter: LongInt = 0;

procedure IncrementInThread;
begin
  InterlockedIncrement(LCounter);  // 原子递减
end;

procedure DecrementInThread;
begin
  InterlockedDecrement(LCounter);  // 原子递减
end;
```

## 6. 使用 I/O

### 6.1 文本文件

```pascal
uses nextpas.core.system;

var
  F: Text;
  S: string;
begin
  AssignFile(F, 'data.txt');
  try
    Rewrite(F);  // 创建新文件
    WriteLn(F, 'Hello');
    WriteLn(F, 'World');
    CloseFile(F);

    Reset(F);  // 打开读取
    while not EOF(F) do
    begin
      ReadLn(F, S);
      WriteLn(S);
    end;
    CloseFile(F);
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end;
```

### 6.2 二进制文件

```pascal
uses nextpas.core.system;

type
  TRecord = record
    ID: LongInt;
    Name: array[0..31] of AnsiChar;
  end;

var
  F: File of TRecord;
  LRec: TRecord;
begin
  AssignFile(F, 'data.dat');
  try
    Rewrite(F);
    LRec.ID := 1;
    LRec.Name := 'Test';
    Write(F, LRec);
    CloseFile(F);

    Reset(F);
    Read(F, LRec);
    WriteLn('ID: ', LRec.ID);
    CloseFile(F);
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end;
```

## 7. 使用内存管理器

### 7.1 查看当前内存管理器

```pascal
uses nextpas.core.system;

var
  LMemMgr: TMemoryManager;
begin
  GetMemoryManager(LMemMgr);
  WriteLn('NeedLock: ', LMemMgr.NeedLock);
  WriteLn('GetMem: ', Pointer(@LMemMgr.GetMem));
end;
```

### 7.2 自定义内存管理器

```pascal
uses nextpas.core.system;

function MyGetMem(Size: SizeInt): Pointer;
begin
  // 自定义分配逻辑
  Result := GetMem(Size);
end;

function MyFreeMem(P: Pointer): SizeInt;
begin
  // 自定义释放逻辑
  Result := FreeMem(P);
end;

var
  LOldMgr, LNewMgr: TMemoryManager;
begin
  GetMemoryManager(LOldMgr);  // 保存旧管理器

  LNewMgr := LOldMgr;
  LNewMgr.GetMem := @MyGetMem;
  LNewMgr.FreeMem := @MyFreeMem;
  SetMemoryManager(LNewMgr);  // 设置新管理器

  try
    // 使用自定义管理器
  finally
    SetMemoryManager(LOldMgr);  // 恢复旧管理器
  end;
end;
```

## 8. 常见问题

### 8.1 什么时候用 SizeInt，什么时候用 LongInt？

- **SizeInt**：数组索引、内存大小、指针运算（平台相关，64-bit 上是 Int64）
- **LongInt**：固定 32-bit 整数，不随平台变化

```pascal
// ✅ 正确
var LIndex: SizeInt;
LIndex := Length(SomeArray);

// ❌ 错误（可能溢出）
var LIndex: LongInt;
LIndex := Length(SomeArray);  // 如果数组 > 2G 个元素会溢出
```

### 8.2 什么时候用 AnsiString，什么时候用 UnicodeString？

- **AnsiString**：与 C 库交互、文件路径、旧代码兼容
- **UnicodeString**：现代代码、用户界面、国际化

```pascal
// ✅ 文件路径用 AnsiString
var LPath: AnsiString;
LPath := '/home/user/file.txt';

// ✅ 用户界面用 UnicodeString
var LMsg: UnicodeString;
LMsg := '你好，世界！';
```

### 8.3 接口变量什么时候自动释放？

接口变量在以下情况自动释放：
1. 离开作用域（局部变量）
2. 被赋值为 nil
3. 被赋值为另一个接口

```pascal
var
  LIntf: IMyInterface;
begin
  LIntf := TMyClass.Create;  // 引用计数 = 1
  LIntf := nil;              // 引用计数 = 0，自动释放
end;

// 或者
var
  LIntf: IMyInterface;
begin
  LIntf := TMyClass.Create;  // 引用计数 = 1
end;  // 离开作用域，引用计数 = 0，自动释放
```

### 8.4 如何避免接口循环引用？

使用弱引用（不调用 _AddRef/_Release）：

```pascal
type
  IWeakRef = interface
    function GetTarget: IInterface;
  end;

  TWeakRef = class(TInterfacedObject, IWeakRef)
  private
    FTarget: Pointer;  // 不增加引用计数
  public
    constructor Create(const ATarget: IInterface);
    function GetTarget: IInterface;
  end;
```

### 8.5 FreeAndNil 和 SafeFree 的区别？

- **FreeAndNil**：调用 Free 并置 nil，如果 Free 抛出异常则不置 nil
- **SafeFree**：调用 Free 并置 nil，即使 Free 抛出异常也置 nil

```pascal
var
  LObj: TMyClass;
begin
  LObj := TMyClass.Create;

  FreeAndNil(LObj);   // 如果 Destroy 抛出异常，LObj 不为 nil
  SafeFree(LObj);     // 即使 Destroy 抛出异常，LObj 也为 nil
end;
```

## 9. 最佳实践

### 9.1 类型选择

1. 优先使用 `SizeInt` 而不是 `LongInt` 作为数组索引
2. 优先使用 `UnicodeString` 而不是 `AnsiString` 处理文本
3. 优先使用 `TBytes` 而不是 `array of Byte` 处理二进制数据
4. 优先使用接口而不是对象指针管理生命周期

### 9.2 内存管理

1. 使用 `FreeAndNil` 或 `SafeFree` 释放对象
2. 使用接口自动管理生命周期
3. 使用 `ZeroMem` 初始化内存
4. 使用 `CompareMem` 比较内存

### 9.3 错误处理

1. 使用异常而不是错误码
2. 在边界处统一捕获异常
3. 使用 `try...finally` 确保资源释放
4. 使用 `nextpas.core.system.errors` 的异常类别

### 9.4 线程安全

1. 使用 `TRTLCriticalSection` 保护共享数据
2. 使用 `InterlockedIncrement` 等原子操作
3. 避免全局变量
4. 使用线程局部存储（`threadvar`）

### 9.5 性能

1. 使用 `FillByte` 而不是循环填充
2. 使用 `MoveChar0` 处理 null-terminated 字符串
3. 使用 `CompareChar` 比较字符串
4. 避免不必要的字符串转换

## 10. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | ABI 细节：内存布局、VMT、fpc_* 签名 |
| `api-reference.md` | API 速查：类型、函数、常量 |
| `design-decisions.md` | 设计决策：为什么这样设计 |
| `runtime-contracts.md` | 运行时契约：np.system.* 名称 |
| `lifecycle-contracts.md` | 生命周期契约：异常、RTTI、单元生命周期 |
| `contract-coverage-table.md` | 契约覆盖：HIR/LLVM/测试证据 |
| `kernel-design.md` | 内核架构：文件结构、FPC 映射 |
| `README.md` | 模块概览：位置、边界、路线图 |
