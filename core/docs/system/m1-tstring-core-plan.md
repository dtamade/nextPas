# M1 实施计划: TString Core

> **状态**: Codex R1 修订版 — 准备实施
> **前置**: Phase 1a 计划 v2.3 (commit `0c493d6cc`)
> **路线图**: `docs/plans/2026-06-18-system-kernel-roadmap.md` Section 3 / S7.1-S7.3
> **设计规范**: `core/docs/design-conventions.md`

---

## 1. 文件清单

| 文件 | 职责 | 新增 |
|------|------|------|
| `core/src/nextpas.core.text.tstring.pas` | TString/TStringHeader 类型 + 核心操作 (合并为单文件) | ✅ |
| `core/tests/nextpas.core.text/test_tstring/test_tstring.lpr` | 30 个测试 | ✅ |
| `core/tests/nextpas.core.text/test_tstring/Makefile` | 构建入口 | ✅ |

**文件命名说明**: 遵循 text 子模块扁平命名惯例 (view/strings/builder/utf8 等无 `.base` 后缀)。
类型定义和实现在同一文件中，因为 TString record 本身携带方法（advancedrecords）。
与 Phase 1a 计划中 `string_types`/`string_core` 的命名已统一为 `tstring`。

---

## 2. 类型定义

```pascal
const
  TSTRING_SSO_TAG  = Byte(0);
  TSTRING_HEAP_TAG = Byte($FF);
  TSTRING_SSO_MAX  = 15;         { SSO 最大内联字节数 }

type
  PStringHeader = ^TStringHeader;
  TStringHeader = record
    RefCount: SizeInt;    { 原子引用计数, 1 = 独占, <0 = literal (不可 free) }
    Capacity: SizeUInt;   { payload 容量 (不含 header + null terminator) }
    Flags: SizeUInt;      { 保留: encoding hints, small-buffer reclaim 等 }
  end;
  { SizeOf(TStringHeader) = 24 bytes }

  TString = record
    case Boolean of
      False: (
        SSOTag: Byte;
        SSOLen: Byte;
        SSOBuf: array[0..TSTRING_SSO_MAX - 1] of Byte;
        SSOPad: array[0..6] of Byte;
      );
      True: (
        HeapTag: Byte;
        HeapPad: array[0..6] of Byte;
        HeapHeader: PStringHeader;
        HeapLen: SizeUInt;
      );
  end;
  { SizeOf(TString) = 24 bytes, 8-byte aligned }
```

**编译期断言**: `{$ASSERT SizeOf(TString) = 24}` + `{$ASSERT SizeOf(TStringHeader) = 24}`

---

## 3. 公共 API

```pascal
{ 生命周期 }
procedure StringInit(var S: TString);
procedure StringFini(var S: TString);
procedure StringAssign(var ADest: TString; const ASource: TString);
procedure StringMove(var ADest: TString; var ASource: TString);  { 转移 ownership, src 置零 }
procedure StringSetLength(var S: TString; ANewLen: SizeUInt);

{ 查询 }
function StringLen(const S: TString): SizeUInt; inline;
function StringData(const S: TString): PByte; inline;
function StringRefCount(const S: TString): SizeInt; inline;  { SSO→0, Heap→refcount }
function StringIsEmpty(const S: TString): Boolean; inline;

{ 工厂 }
function StringCreate(const AData: PByte; ALen: SizeUInt): TString;
function StringFromFPC(const AStr: string): TString;
function StringToFPC(const S: TString): string;

{ 比较 }
function StringEqual(const A, B: TString): Boolean;
function StringCompare(const A, B: TString): SizeInt;

{ TString record 方法 (委托给顶层函数) }
TString = record
  class function Empty: TString; static; inline;
  class function Create(const AData: PByte; ALen: SizeUInt): TString; static;
  class function FromFPC(const AStr: string): TString; static;
  procedure Done;
  function Len: SizeUInt; inline;
  function Data: PByte; inline;
  function RefCount: SizeInt; inline;
  function IsEmpty: Boolean; inline;
  function IsSSO: Boolean; inline;
  function IsHeap: Boolean; inline;
  function ToFPC: string;
  function Equals(const AOther: TString): Boolean;
end;
```

---

## 4. 核心实现细节

### 4.1 StringAssign CoW (经典顺序: 先 incr 源, 再 decr 旧目标)

```
SSO→SSO: Move(ADest, ASource, 24) — 天然自赋值安全

Heap→any:
  LNewHeader := ASource.HeapHeader   // 保存源 header
  AtomicIncr(LNewHeader^.RefCount)   // 1. 先 incr 源
  if ADest.IsHeap then
    HeapDecrAndMaybeFree(ADest)      // 2. 再 decr 旧目标 (自赋值时 net=0, 不 free)
  ADest.HeapHeader := LNewHeader
  ADest.HeapLen := ASource.HeapLen
  ADest.HeapTag := TSTRING_HEAP_TAG

SSO→Heap / Heap→SSO: 类似路径
```

**原子操作**: 使用 `InterlockedIncrement` / `InterlockedDecrement` (FPC System 内建) 直接操作 `PStringHeader^.RefCount` 字段。不用 TAtomicISize 包装，因为 RefCount 是 record 内的裸字段。

### 4.2 内部分配辅助

```pascal
function HeapAlloc(ACapacity: SizeUInt): PStringHeader;
  { GetMem(SizeOf(TStringHeader) + ACapacity + 1) — 单次分配 }
  { 初始化 RefCount=1, Capacity=ACapacity, Flags=0 }
  { 在 payload 末尾写 null terminator }

procedure HeapFree(AHeader: PStringHeader);
  { FreeMem(AHeader) — 一次释放 header + payload }
```

所有堆分配集中在这两个函数，Phase 1b TCache 替换时只需改此处。

### 4.3 堆分配布局

```
Offset 0:             TStringHeader (24B: RefCount + Capacity + Flags)
Offset 24:            payload[0..Capacity-1] — 字符串数据
Offset 24+Capacity:   #0 (null terminator, 不计入 Len)
总分配:               24 + Capacity + 1 字节
```

- `Capacity >= Len` (分配时可能 over-allocate，M1 简化为 Capacity = Len)
- `StringSetLength` 缩短时不缩小分配

### 4.4 StringSetLength SSO→Heap 提升

```
ANewLen > TSTRING_SSO_MAX 且当前 SSO:
  1. HeapAlloc(ANewLen)
  2. Move(SSOBuf, payload, SSOLen)  // 复制旧数据
  3. 切换 tag 为 TSTRING_HEAP_TAG
  4. 设置 HeapLen = ANewLen
  5. 清零 SSOBuf 以外的字段
```

### 4.5 StringRefCount 语义

- SSO 路径返回 **0** (不参与 refcount 协议, 不可共享但非 literal)
- Heap 路径返回 `Header^.RefCount`

### 4.6 依赖

```
nextpas.core.text.tstring  ← uses nextpas.core.base, nextpas.core.atomic.types
                                uses System (FillChar/Move/GetMem/FreeMem)
```

---

## 5. 测试矩阵 (30 个)

| # | 测试 | 覆盖 |
|---|------|------|
| 1 | TestSizeOf | SizeOf(TString)=24, SizeOf(TStringHeader)=24 |
| 2 | TestCompileAssert | 编译期 {$ASSERT} 通过 |
| 3 | TestZeroInit | 零初始化=空串, Len=0, IsSSO, IsEmpty |
| 4 | TestEmptyFactory | TString.Empty 等同零初始化 |
| 5 | TestSSOShort | ≤15B: SSO, Len正确, Data内容正确 |
| 6 | TestSSOExactly15 | 恰好15B: SSO边界 |
| 7 | TestSSOExactly16 | 恰好16B: Heap路径边界 |
| 8 | TestHeapString | >15B: Heap, Len正确, Data内容正确 |
| 9 | TestFiniSSO | SSO Done: 清零 |
| 10 | TestFiniHeap | Heap Done: 无泄漏 |
| 11 | TestAssignSSO | SSO→SSO赋值: memcpy, 独立修改不影响对方 |
| 12 | TestAssignHeap | Heap→Heap赋值: refcount=2 |
| 13 | TestAssignMixed1 | SSO→Heap混合赋值 |
| 14 | TestAssignMixed2 | Heap→SSO混合赋值 |
| 15 | TestCoWRefcount | 多次赋值 refcount 正确 |
| 16 | TestCoWSelfAssign | S:=S 自赋值不崩溃 |
| 17 | TestCoWUnique | refcount=1 直接修改不copy |
| 18 | TestCoWCopyOnWrite | refcount>1 时修改触发copy |
| 19 | TestAssignReplacesOld | 赋值覆盖旧Heap值,正确释放 |
| 20 | TestMoveSSO | SSO Move: 转移,源清零 |
| 21 | TestMoveHeap | Heap Move: 转移refcount,源清零 |
| 22 | TestSetLengthSSO | SetLength SSO范围 |
| 23 | TestSetLengthPromote | SetLength >15: SSO→Heap提升 |
| 24 | TestUTF8Chinese | 中文15B SSO |
| 25 | TestUTF8Long | 长中文串 Heap, UTF-8透传 |
| 26 | TestNullTerminator | Data末尾是#0 |
| 27 | TestStringCreate | StringCreate从raw bytes |
| 28 | TestStringCreateZero | StringCreate(nil,0)=空串 |
| 29 | TestFPCRoundtrip | FromFPC→ToFPC roundtrip |
| 30 | TestCompareEqual | StringEqual + StringCompare |

---

## 6. 任务清单

| 步骤 | 任务 |
|------|------|
| T1 | 创建 `nextpas.core.text.tstring.pas` — 类型 + 操作 |
| T2 | 创建 `test_tstring/Makefile` + `test_tstring.lpr` — 30 个测试 |
| T3 | 编译运行, 修复所有问题 |
| T4 | 验证 heaptrc 0 leak |
| T5 | Codex 审查 |
| T6 | 整改 |
| T7 | git commit + 进度报告 |
