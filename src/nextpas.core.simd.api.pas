// Legacy compatibility layer — prefer nextpas.core.simd.api.v2 for new code.
unit nextpas.core.simd.api;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

// === SIMD 门面函数 API ===
// High-level facade entrypoints that dispatch to the best runtime SIMD implementation.

// === 内存操作函数 ===

// 内存比较
function MemEqual(a, b: Pointer; len: SizeUInt): LongBool; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 字节查找
function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 差异范围检测
function MemDiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 内存复制
procedure MemCopy(src, dst: Pointer; len: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 内存设置
procedure MemSet(dst: Pointer; len: SizeUInt; value: Byte); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 内存反转
procedure MemReverse(p: Pointer; len: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// === 统计函数 ===

// 字节求和
function SumBytes(p: Pointer; len: SizeUInt): UInt64; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 最值查找
procedure MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// 字节计数
function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// === 文本处理函数 ===

// UTF-8 验证
function Utf8Validate(p: Pointer; len: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// ASCII 忽略大小写比较
function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// ASCII 转小写
procedure ToLowerAscii(p: Pointer; len: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// ASCII 转大写
procedure ToUpperAscii(p: Pointer; len: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// === 搜索函数 ===

// 字节序列搜索
function BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

// === 位集函数 ===

// 位集合人口计数
function BitsetPopCount(p: Pointer; byteLen: SizeUInt): SizeUInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

implementation

uses
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct;

function GetFacadeDispatch: PSimdDispatchTable; inline;
begin
  Result := GetDirectDispatchTable;
end;

// === 内存操作函数实现 ===
// 通过已发布的 dataplane dispatch snapshot 调用当前活跃后端

function MemEqual(a, b: Pointer; len: SizeUInt): LongBool;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.MemEqual(a, b, len);
end;

function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.MemFindByte(p, len, value);
end;

function MemDiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.MemDiffRange(a, b, len, firstDiff, lastDiff);
end;

procedure MemCopy(src, dst: Pointer; len: SizeUInt);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.MemCopy(src, dst, len);
end;

procedure MemSet(dst: Pointer; len: SizeUInt; value: Byte);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.MemSet(dst, len, value);
end;

procedure MemReverse(p: Pointer; len: SizeUInt);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.MemReverse(p, len);
end;

// === 统计函数实现 ===

function SumBytes(p: Pointer; len: SizeUInt): UInt64;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.SumBytes(p, len);
end;

procedure MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.MinMaxBytes(p, len, minVal, maxVal);
end;

function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.CountByte(p, len, value);
end;

// === 文本处理函数实现 ===

function Utf8Validate(p: Pointer; len: SizeUInt): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.Utf8Validate(p, len);
end;

function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.AsciiIEqual(a, b, len);
end;

procedure ToLowerAscii(p: Pointer; len: SizeUInt);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.ToLowerAscii(p, len);
end;

procedure ToUpperAscii(p: Pointer; len: SizeUInt);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  dispatch^.ToUpperAscii(p, len);
end;

// === 搜索函数实现 ===

function BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.BytesIndexOf(haystack, haystackLen, needle, needleLen);
end;

// === 位集函数实现 ===

function BitsetPopCount(p: Pointer; byteLen: SizeUInt): SizeUInt;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetFacadeDispatch;
  Result := dispatch^.BitsetPopCount(p, byteLen);
end;

end.


