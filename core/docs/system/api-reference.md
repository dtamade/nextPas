# nextpas.core.system API Reference

本手册是 system kernel 的**开发者速查手册**。ABI 细节见 `abi-specification.md`，设计决策见 `kernel-design.md`。

## 1. 门面文件概览

| 门面 | 路径 | 职责 |
|------|------|------|
| `nextpas.core.system` | `core/src/nextpas.core.system.pas` | 根门面：re-export 基础类型、常量、内核子模块 |
| `nextpas.core.system.typinfo` | `core/src/nextpas.core.system.typinfo.pas` | RTTI 门面：PTypeInfo/TTypeKind/PPropInfo/PPropList/GetPropInfo/GetPropList/GetEnumName/GetEnumValue |
| `nextpas.core.system.sysutils` | `core/src/nextpas.core.system.sysutils.pas` | SysUtils 门面：40+ 函数委托给 owner 模块 |
| `nextpas.core.system.errors` | `core/src/nextpas.core.system.errors.pas` | 异常分类门面：38 exception + 18 error category |

## 2. 根门面导出清单

### 2.1 基础类型（来自 base.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `SizeInt` | `Int64` (64-bit) / `LongInt` (32-bit) | 平台相关有符号整数 |
| `SizeUInt` | `QWord` (64-bit) / `LongWord` (32-bit) | 平台相关无符号整数 |
| `PtrInt` | 同 `SizeInt` | 指针宽度有符号整数 |
| `PtrUInt` | 同 `SizeUInt` | 指针宽度无符号整数 |
| `NativeInt` | 同 `SizeInt` | 原生整数 |
| `NativeUInt` | 同 `SizeUInt` | 原生无符号整数 |
| `PByte` | `^Byte` | 字节指针 |
| `PWord` | `^Word` | 字指针 |
| `PLongInt` | `^LongInt` | 长整型指针 |
| `PLongWord` | `^LongWord` | 长无符号整型指针 |
| `PInt64` | `^Int64` | 64位整型指针 |
| `PQWord` | `^QWord` | 64位无符号整型指针 |
| `PPointer` | `^Pointer` | 指针的指针 |
| `PSizeInt` | `^SizeInt` | SizeInt 指针 |
| `PSizeUInt` | `^SizeUInt` | SizeUInt 指针 |

### 2.2 C ABI 类型（来自 base.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `CInt` | `LongInt` | C `int` |
| `CUInt` | `LongWord` | C `unsigned int` |
| `CLong` | `Int64` (64-bit) / `LongInt` (32-bit) | C `long` |
| `CULong` | `QWord` (64-bit) / `LongWord` (32-bit) | C `unsigned long` |
| `CChar` | `AnsiChar` | C `char` |
| `PCChar` | `^CChar` | C `char*` |

### 2.3 字符串类型（来自 str.inc）

| 类型 | 内存模型 | 用途 |
|------|---------|------|
| `ShortString` | 值类型，最大 255 字节 | FPC 兼容短字符串 |
| `AnsiString` | 引用计数，堆分配 | ANSI/UTF-8 字符串 |
| `WideString` | COM 兼容，无引用计数 | UTF-16 字符串（COM） |
| `UnicodeString` | 引用计数，堆分配 | UTF-16 字符串（原生） |
| `Char` | `AnsiChar` (FPC) / `WideChar` (nextPas) | 默认字符类型 |
| `AnsiChar` | 1 字节 | ANSI 字符 |
| `WideChar` | 2 字节 | Unicode 字符 |
| `PAnsiChar` | `^AnsiChar` | ANSI 字符串指针 |
| `PWideChar` | `^WideChar` | Unicode 字符串指针 |
| `PUnicodeChar` | `^WideChar` | Unicode 字符指针 |

### 2.4 Variant 类型（来自 base.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TVarType` | `Word` | Variant 类型标签 |
| `TVarData` | packed record, 16 bytes | Variant 存储布局 |
| `PVarData` | `^TVarData` | Variant 数据指针 |

**Variant 常量**：
```
varEmpty=$0000  varNull=$0001  varSmallint=$0002  varInteger=$0003
varSingle=$0004 varDouble=$0005 varCurrency=$0006  varDate=$0007
varOleStr=$0008 varDispatch=$0009 varError=$000A   varBoolean=$000B
varVariant=$000C varUnknown=$000D varShortInt=$0010 varByte=$0011
varWord=$0012   varLongWord=$0013 varInt64=$0014    varQWord=$0015
varString=$0100 varAny=$0101    varUString=$0102
```

### 2.5 动态数组类型（来自 base.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TBytes` | `array of Byte` | 字节数组 |
| `TCharArray` | `array of Char` | 字符数组 |

### 2.6 接口类型（来自 intf.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TGUID` | record (D1:DWord, D2:Word, D3:Word, D4:array[0..7] of Byte) | GUID/UUID |
| `PGUID` | `^TGUID` | GUID 指针 |
| `IUnknown` | interface (QueryInterface, _AddRef, _Release) | COM 接口基类 |
| `IInterface` | `= IUnknown` | 接口别名 |
| `TInterfaceEntry` | record (IID, VTable, IOffset, IsField) | 接口表条目 |
| `PInterfaceEntry` | `^TInterfaceEntry` | 接口表条目指针 |
| `TInterfaceTable` | record (EntryCount, Entries[0..9999]) | 接口表 |
| `PInterfaceTable` | `^TInterfaceTable` | 接口表指针 |
| `TMethod` | record (Code, Data) | 方法指针 |
| `PMethod` | `^TMethod` | 方法指针指针 |

### 2.7 类类型（来自 cls.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TObject` | class | 所有类的根 |
| `TClass` | class of TObject | 类引用类型 |
| `TVmt` | record | VMT 表结构 |
| `PVmt` | `^TVmt` | VMT 指针 |

**VMT 常量**（共 28 个）：
```
vmtInstanceSize=0       vmtParent=16          vmtClassName=24
vmtDynamicTable=32      vmtMethodTable=40     vmtFieldTable=48
vmtTypeInfo=56          vmtInitTable=64       vmtAutoTable=72
vmtIntfTable=80         vmtMsgStrPtr=88       vmtDestroy=96
vmtNewInstance=104      vmtFreeInstance=112   vmtDefaultHandler=120
vmtAfterConstruction=128 vmtBeforeDestruction=136 vmtDefaultHandlerStr=144
vmtDispatch=152         vmtDispatchStr=160    vmtEquals=168
vmtGetHashCode=176      vmtToString=184       vmtSafeCallException=192
vmtGetInterface=200     vmtGetInterfaceWeak=208 vmtGetInterfaceStrong=216
```

### 2.8 RTTI 类型（来自 rtti.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TTypeKind` | enum (tkUnknown..tkPointer, 30 个值) | 类型种类枚举 |
| `PTypeInfo` | `^TTypeInfo` | 类型信息指针 |
| `TTypeInfo` | record (Kind, Name) | 类型信息 |
| `PPTypeInfo` | `^PTypeInfo` | 类型信息二级指针 |
| `PTypeData` | `^TTypeData` | 类型数据指针 |
| `TTypeData` | record (按 TTypeKind 分支) | 类型特定数据 |

**TTypeKind 枚举值**：
```
tkUnknown=0   tkInteger=1    tkChar=2       tkEnumeration=3
tkFloat=4     tkSet=5        tkMethod=6     tkSString=7
tkLString=8   tkAString=9    tkWString=10   tkVariant=11
tkArray=12    tkRecord=13    tkInterface=14 tkClass=15
tkObject=16   tkWChar=17     tkBool=18      tkInt64=19
tkQWord=20    tkDynArray=21  tkInterfaceRaw=22 tkProcVar=23
tkUString=24  tkUChar=25     tkHelper=26    tkFile=27
tkClassRef=28 tkPointer=29
```

### 2.9 异常类型（来自 except.inc）

| 类型 | 基类 | 用途 |
|------|------|------|
| `Exception` | TObject | 异常基类 |
| `EAbort` | Exception | 静默中止 |
| `EConvertError` | Exception | 类型转换错误 |
| `EAssertionFailed` | Exception | 断言失败 |
| `ENextPasError` | Exception | nextPas 运行时错误 |

### 2.10 线程类型（来自 thread.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TThreadFunc` | `function(AParam: Pointer): PtrInt` | 线程函数类型 |
| `TThreadID` | `QWord` | 线程 ID |
| `TRTLCriticalSection` | record (FSection: array[0..31] of Byte) | 临界区 |
| `PRTLCriticalSection` | `^TRTLCriticalSection` | 临界区指针 |
| `TThread` | class | 线程基类 |
| `TThreadClass` | class of TThread | 线程类引用 |
| `TNotifyEvent` | `procedure(Sender: TObject) of object` | 通知事件 |

### 2.11 I/O 类型（来自 io.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TFileRec` | record (Handle, Mode, Flags, RecSize, BufSize, ...) | 文件记录 |
| `PFileRec` | `^TFileRec` | 文件记录指针 |
| `TTextRec` | record (Handle, Mode, Flags, BufSize, LineEnd, ...) | 文本文件记录 |
| `PTextRec` | `^TTextRec` | 文本文件记录指针 |
| `File` | file | 文件类型 |
| `Text` | file of TextRec | 文本文件类型 |
| `TFileDate` | `LongInt` | 文件日期 |
| `TSearchRec` | record (Time, Size, Attr, Name, ...) | 文件搜索记录 |

**文件模式常量**：
```
fmClosed=$D7B0  fmInput=$D7B1  fmOutput=$D7B2  fmInOut=$D7B3
```

**文件属性常量**：
```
faReadOnly=$00000001  faHidden=$00000002  faSysFile=$00000004
faVolumeID=$00000008  faDirectory=$00000010  faArchive=$00000020
faAnyFile=$0000003F
```

### 2.12 内存管理器类型（来自 memmgr.inc）

| 类型 | 定义 | 用途 |
|------|------|------|
| `TMemoryManager` | record (NeedLock, GetMem, FreeMem, ...) | 内存管理器接口 |
| `PMemoryManager` | `^TMemoryManager` | 内存管理器指针 |
| `TMemoryManagerEx` | record (Version, NeedLock, GetMem, ...) | 扩展内存管理器 |
| `PMemoryManagerEx` | `^TMemoryManagerEx` | 扩展内存管理器指针 |
| `THeapStatus` | record (TotalAddrSpace, TotalAllocated, ...) | 堆状态 |
| `TFPCHeapStatus` | record (CurrHeapSize, CurrHeapFree, ...) | FPC 堆状态 |

**内存管理器回调类型**：
```
TGetMem      = function(Size: SizeInt): Pointer
TFreeMem     = function(P: Pointer): SizeInt
TFreeMemSize = function(P: Pointer; Size: SizeInt): SizeInt
TAllocMem    = function(Size: SizeInt): Pointer
TReAllocMem  = function(P: Pointer; Size: SizeInt): Pointer
TMemSize     = function(P: Pointer): SizeInt
```

## 3. 函数清单

### 3.1 内存操作（mem.inc）

```pascal
procedure ZeroMem(var APtr; ASize: SizeInt);     // 零填充
procedure FillMem(var APtr; ASize: SizeInt; AValue: Byte); // 字节填充
procedure CopyMem(var ADest; const ASrc; ASize: SizeInt); // 内存拷贝
function CompareMem(const APtr1, APtr2; ASize: SizeInt): Boolean; // 内存比较
procedure FreeAndNil(var AObj);                   // 释放并置 nil
procedure SafeFree(var AObj);                     // 安全释放（不抛异常）
function Supports(const AObj: TObject; const IID: TGUID; out AIntf): Boolean; overload;
function Supports(const AIntf: IUnknown; const IID: TGUID; out AResult): Boolean; overload;
```

### 3.2 TObject 方法（cls.inc）

```pascal
{ 构造/析构 }
constructor Create;                               // 创建实例
procedure Free;                                   // 释放（nil 安全）
procedure Destroy;                                // 析构（虚方法）
class function InitInstance(Self: Pointer): TObject; // 初始化实例
procedure CleanupInstance;                        // 清理实例

{ 类信息 }
class function ClassType: TClass;                 // 获取类引用
class function ClassName: ShortString;            // 获取类名
class function ClassNameIs(const Name: string): Boolean; // 类名比较
class function ClassParent: TClass;               // 获取父类
class function InstanceSize: SizeInt;             // 获取实例大小
class function InheritsFrom(AClass: TClass): Boolean; // 继承判断
class function StringMessageTable: Pointer;       // 消息表

{ 接口 }
class function GetInterfaceEntry(const IID: TGUID): PInterfaceEntry;
class function GetInterfaceTable: PInterfaceTable;
class function GetInterfaceCount: SizeInt;
class function GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
class function GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;
function GetInterface(const IID: TGUID; out Obj): Boolean;
function GetInterfaceWeak(const IID: TGUID; out Obj): Boolean;
function GetInterfaceStrong(const IID: TGUID; out Obj): Boolean;

{ 虚方法 }
function Equals(Obj: TObject): Boolean; virtual;
function GetHashCode: SizeInt; virtual;
function ToString: AnsiString; virtual;
function SafeCallException(ExceptObject: TObject; ExceptAddr: Pointer): LongInt; virtual;
procedure Dispatch(var Message); virtual;
procedure DispatchStr(var Message); virtual;
procedure DefaultHandler(var Message); virtual;
procedure DefaultHandlerStr(var Message); virtual;
procedure AfterConstruction; virtual;
procedure BeforeDestruction; virtual;
procedure Initialize; virtual;
procedure Finalize; virtual;
```

### 3.3 RTTI 函数（rtti.inc）

```pascal
procedure InitializeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure FinalizeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure CopyArray(Dest, Src: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure Initialize(P: Pointer; TypeInfo: Pointer);
procedure Finalize(P: Pointer; TypeInfo: Pointer);
procedure CopyRecord(Dest, Src: Pointer; TypeInfo: Pointer);
```

### 3.4 字节序转换（endian.inc）

```pascal
function SwapEndian(AValue: SmallInt): SmallInt; overload;
function SwapEndian(AValue: Word): Word; overload;
function SwapEndian(AValue: LongInt): LongInt; overload;
function SwapEndian(AValue: LongWord): LongWord; overload;
function SwapEndian(AValue: Int64): Int64; overload;
function SwapEndian(AValue: QWord): QWord; overload;

function BEtoN(AValue: SmallInt): SmallInt; overload;  // Big-Endian → Native
function BEtoN(AValue: Word): Word; overload;
function BEtoN(AValue: LongInt): LongInt; overload;
function BEtoN(AValue: LongWord): LongWord; overload;
function BEtoN(AValue: Int64): Int64; overload;
function BEtoN(AValue: QWord): QWord; overload;

function LEtoN(AValue: SmallInt): SmallInt; overload;  // Little-Endian → Native
function LEtoN(AValue: Word): Word; overload;
function LEtoN(AValue: LongInt): LongInt; overload;
function LEtoN(AValue: LongWord): LongWord; overload;
function LEtoN(AValue: Int64): Int64; overload;
function LEtoN(AValue: QWord): QWord; overload;

function NtoBE(AValue: SmallInt): SmallInt; overload;  // Native → Big-Endian
function NtoBE(AValue: Word): Word; overload;
function NtoBE(AValue: LongInt): LongInt; overload;
function NtoBE(AValue: LongWord): LongWord; overload;
function NtoBE(AValue: Int64): Int64; overload;
function NtoBE(AValue: QWord): QWord; overload;

function NtoLE(AValue: SmallInt): SmallInt; overload;  // Native → Little-Endian
function NtoLE(AValue: Word): Word; overload;
function NtoLE(AValue: LongInt): LongInt; overload;
function NtoLE(AValue: LongWord): LongWord; overload;
function NtoLE(AValue: Int64): Int64; overload;
function NtoLE(AValue: QWord): QWord; overload;
```

### 3.5 内存屏障（barrier.inc）

```pascal
procedure ReadBarrier;
procedure ReadWriteBarrier;
procedure WriteBarrier;
procedure Prefetch(var AAddress);
```

### 3.6 内存操作内建函数（intrinsics.inc）

```pascal
procedure FillByte(var ADest; ACount: SizeInt; AValue: Byte);
procedure FillDWord(var ADest; ACount: SizeInt; AValue: LongWord);
procedure FillQWord(var ADest; ACount: SizeInt; AValue: QWord);

function IndexChar(const ABuf; ABufLen: SizeInt; AValue: AnsiChar): SizeInt;
function IndexByte(const ABuf; ABufLen: SizeInt; AValue: Byte): SizeInt;
function IndexWord(const ABuf; ABufLen: SizeInt; AValue: Word): SizeInt;
function IndexDWord(const ABuf; ABufLen: SizeInt; AValue: LongWord): SizeInt;

function CompareChar(const ABuf1, ABuf2; ACount: SizeInt): SizeInt;
function CompareByte(const ABuf1, ABuf2; ACount: SizeInt): SizeInt;
function CompareWord(const ABuf1, ABuf2; ACount: SizeInt): SizeInt;
function CompareDWord(const ABuf1, ABuf2; ACount: SizeInt): SizeInt;

procedure MoveChar0(const ASrc; var ADest; ACount: SizeInt);
function MemPos(const ANeedle; ANeedleLen: SizeInt; const AHaystack; AHaystackLen: SizeInt): SizeInt;
function StackTop: Pointer;
```

### 3.7 线程管理（thread.inc）

```pascal
{ 线程创建/销毁 }
function BeginThread(AThreadFunc: TThreadFunc; AParam: Pointer; out AThreadID: TThreadID): TThreadID;
procedure EndThread(AReturnValue: PtrInt);

{ 临界区 }
procedure InitCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure DoneCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure EnterCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure LeaveCriticalSection(var ACriticalSection: TRTLCriticalSection);
function TryEnterCriticalSection(var ACriticalSection: TRTLCriticalSection): Boolean;

{ 原子操作 }
function InterlockedIncrement(var ATarget: LongInt): LongInt;
function InterlockedDecrement(var ATarget: LongInt): LongInt;
function InterlockedExchange(var ATarget: LongInt; ASource: LongInt): LongInt;
function InterlockedCompareExchange(var ATarget: LongInt; ASource: LongInt; AComparand: LongInt): LongInt;
function InterlockedExchangeAdd(var ATarget: LongInt; ASource: LongInt): LongInt;
```

### 3.8 I/O 操作（io.inc）

```pascal
{ 文件操作 }
procedure AssignFile(var AFile: File; const AName: string); overload;
procedure AssignFile(var AText: Text; const AName: string); overload;
procedure Reset(var AFile: File); overload;
procedure Reset(var AText: Text); overload;
procedure Rewrite(var AFile: File); overload;
procedure Rewrite(var AText: Text); overload;
procedure Append(var AText: Text);
procedure CloseFile(var AFile: File); overload;
procedure CloseFile(var AText: Text); overload;
procedure Erase(var AFile: File);
procedure Rename(var AFile: File; const ANewName: string);
procedure Seek(var AFile: File; APosition: LongInt);
function FilePos(var AFile: File): LongInt;
function FileSize(var AFile: File): LongInt;
function EOF(var AFile: File): Boolean; overload;
function EOF(var AText: Text): Boolean; overload;
procedure Truncate(var AFile: File);
procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt); overload;
procedure BlockRead(var AFile: File; var ABuffer; ACount: LongInt; var AResult: LongInt); overload;
procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt); overload;
procedure BlockWrite(var AFile: File; const ABuffer; ACount: LongInt; var AResult: LongInt); overload;

{ 文本 I/O }
procedure Read(var AText: Text; var Args); overload;
procedure ReadLn(var AText: Text); overload;
procedure ReadLn(var AText: Text; var Args); overload;
procedure Write(var AText: Text; const Args); overload;
procedure WriteLn(var AText: Text); overload;
procedure WriteLn(var AText: Text; const Args); overload;

{ 标准句柄 }
var Input, Output, ErrOutput, StdIn, StdOut, StdErr: Text;
```

### 3.9 内存管理器（memmgr.inc）

```pascal
procedure GetMemoryManager(var AMemMgr: TMemoryManager);
procedure SetMemoryManager(const AMemMgr: TMemoryManager);
function IsMemoryManagerSet: Boolean;
```

### 3.10 程序生命周期（lifecycle.inc）

```pascal
procedure InitModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);
procedure FinalizeModule(AAddr: Pointer; ATable: Pointer; ACount: LongInt);
```

## 4. TypInfo 门面（nextpas.core.system.typinfo）

```pascal
uses nextpas.core.system.typinfo;

// 类型
PTypeInfo, TTypeInfo, PPTypeInfo, PTypeData, TTypeData, TTypeKind
PPropInfo, PPropList

// 函数
function GetPropInfo(AInstance: TObject; const APropName: string): PPropInfo;
function GetPropList(ATypeInfo: PTypeInfo; out APropList: PPropList): SizeInt;
function GetPropList(AClass: TClass; out APropList: PPropList): Integer;
function GetEnumName(ATypeInfo: PTypeInfo; AValue: SizeInt): ShortString;
function GetEnumValue(ATypeInfo: PTypeInfo; const AName: string): SizeInt;
```

## 5. SysUtils 门面（nextpas.core.system.sysutils）

```pascal
uses nextpas.core.system.sysutils;

{ 数值转换 }
function StrToInt(const S: string): LongInt;
function StrToInt64(const S: string): Int64;
function StrToFloat(const S: string): Double;
function IntToStr(AValue: LongInt): string; overload;
function IntToStr(AValue: Int64): string; overload;
function FloatToStr(AValue: Double): string;
function CurrToStr(AValue: Currency): string;

{ 字符串 }
function Format(const AFormat: string; const AArgs: array of const): string;
function SameText(const S1, S2: string): Boolean;
function Trim(const S: string): string;

{ 日期时间 }
function Now: TDateTime;
function Date: TDateTime;
function Time: TDateTime;
function DateToStr(ADate: TDateTime): string;
function TimeToStr(ATime: TDateTime): string;
function DateTimeToStr(ADateTime: TDateTime): string;
function FormatDateTime(const AFormat: string; ADateTime: TDateTime): string;

{ 文件系统 }
function FileExists(const AFileName: string): Boolean;
function DirectoryExists(const ADirectory: string): Boolean;
function CreateDir(const ADir: string): Boolean;
function RemoveDir(const ADir: string): Boolean;
function ForceDirectories(const ADir: string): Boolean;
function DeleteFile(const AFileName: string): Boolean;
function RenameFile(const AOldName, ANewName: string): Boolean;
function CopyFile(const ASrc, ADest: string): Boolean;

{ 路径 }
function ExtractFilePath(const AFileName: string): string;
function ExtractFileName(const AFileName: string): string;
function ExtractFileExt(const AFileName: string): string;
function ChangeFileExt(const AFileName, ANewExt: string): string;
function IncludeTrailingPathDelimiter(const APath: string): string;

{ 环境 }
function GetCurrentDir: string;
function SetCurrentDir(const ADir: string): Boolean;
function ParamCount: LongInt;
function ParamStr(AIndex: LongInt): string;
function GetEnvironmentVariable(const AName: string): string;

{ 计时 }
procedure Sleep(AMilliseconds: Cardinal);

{ 错误 }
function SysErrorMessage(AErrorCode: LongInt): string;
function GetLastOSError: LongInt;
```

## 6. Errors 门面（nextpas.core.system.errors）

```pascal
uses nextpas.core.system.errors;

{ 异常类型别名 (38 个) }
// 从 nextpas.core.exception re-export：
EArgumentError, EInvalidArgument, EArgumentNil, EArgumentOutOfRange
ETimeoutError, EIOError, EFileNotFound, EDirectoryNotFound
EOutOfMemoryError, EStackOverflow, EAccessViolation, EBusError
ESignalError, EAssertionFailed, EConvertError, EInvalidCast
EInvalidOp, EZeroDivide, EOverflow, EUnderflow
EExternalException, EControlC, EPrivilege, EResNotFound
EAbort, EPropReadOnly, EPropWriteOnly, EAbstractError
EIntfCastError, EIntOverflow, ESafecallException, EVariantError
ENotImplemented, ENetworkError, EEncryptionError, ECompressionError
EThreadError, EResourceNotFound

{ 错误类别常量 (18 个) }
ecArgument, ecTimeout, ecIO, ecMemory, ecStack, ecAccess,
ecSignal, ecAssertion, ecConvert, ecInvalidCast, ecFloatOp,
ecExternal, ecPrivilege, ecResource, ecPropAccess, ecAbstract,
ecInterface, ecMisc
```

## 7. 编译器内部函数（comp.inc — 119 个 fpc_*）

这些函数由编译器自动调用，用户不应直接使用。按系列分组：

| 系列 | 数量 | 用途 |
|------|------|------|
| AnsiString | 23 | 引用计数、赋值、比较、拼接、截取、转换 |
| WideString | 18 | 同上（WideString 版本） |
| UnicodeString | 18 | 同上（UnicodeString 版本） |
| Dynamic Array | 12 | 引用计数、赋值、长度、SetLength、拷贝、删除、插入 |
| Variant | 18 | 初始化、清理、赋值、比较、转换 |
| Interface | 10 | 引用计数、赋值、QueryInterface |
| Exception | 10 | setjmp/longjmp、try/except/finally、raise |
| Memory | 7 | getmem/freemem/reallocmem/allocmem/memsize |
| Halt/Exit | 3 | 程序终止 |

详见 `abi-specification.md` 第 6 节完整签名。

## 8. 编译器指令

| 指令 | 位置 | 作用 |
|------|------|------|
| `{$compiler_root}` | cls.inc:TObject | 标记为编译器根类 |
| `{$compiler_type_kind}` | rtti.inc:TTypeKind | 标记为类型种类枚举 |
| `compilerproc` | comp.inc 所有 fpc_* | 标记为编译器内部函数 |

## 9. 使用示例

### 9.1 基本类型使用

```pascal
uses nextpas.core.system;

var
  LSize: SizeInt;
  LPtr: Pointer;
  LBytes: TBytes;
begin
  LSize := SizeOf(Pointer);  // 8 on 64-bit
  SetLength(LBytes, 1024);
  ZeroMem(LBytes[0], Length(LBytes));
end;
```

### 9.2 对象创建和释放

```pascal
uses nextpas.core.system;

type
  TMyClass = class
    FValue: LongInt;
  end;

var
  LObj: TMyClass;
begin
  LObj := TMyClass.Create;
  try
    LObj.FValue := 42;
  finally
    LObj.Free;  // nil 安全
  end;
end;
```

### 9.3 接口使用

```pascal
uses nextpas.core.system;

type
  IMyInterface = interface(IUnknown)
    ['{12345678-1234-1234-1234-123456789ABC}']
    procedure DoSomething;
  end;

  TMyClass = class(TObject, IMyInterface)
    procedure DoSomething;
    // IUnknown 由编译器自动实现
  end;

var
  LIntf: IMyInterface;
begin
  LIntf := TMyClass.Create;
  LIntf.DoSomething;
  // LIntf 离开作用域时自动调用 _Release
end;
```

### 9.4 RTTI 使用

```pascal
uses nextpas.core.system, nextpas.core.system.typinfo;

type
  TColor = (clRed, clGreen, clBlue);

var
  LInfo: PTypeInfo;
  LName: ShortString;
begin
  LInfo := TypeInfo(TColor);
  LName := GetEnumName(LInfo, Ord(clGreen));  // 'clGreen'
end;
```

### 9.5 SysUtils 使用

```pascal
uses nextpas.core.system.sysutils;

var
  LPath: string;
  LExists: Boolean;
begin
  LPath := ExtractFilePath(ParamStr(0));
  LExists := FileExists(LPath + 'config.ini');
  if not LExists then
    CreateDir(LPath + 'data');
end;
```
