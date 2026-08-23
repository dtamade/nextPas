{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.error - 内存分配错误与异常类型
## Abstract 摘要

Memory allocation error and exception types.
内存分配错误与异常类型。

## Declaration 声明

Author:    nextpas.core
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.error;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.mem.base;

type
  {**
   * TAllocError
   *
   * @desc 内存分配错误码
   *       Memory allocation error codes
   *
   * @note 零值表示成功，方便条件判断
   *}
  TAllocError = (
    {** 无错误，分配成功 | No error, allocation succeeded *}
    aeNone = 0,

    {** 内存不足 | Out of memory *}
    aeOutOfMemory,

    {** 无效布局（大小或对齐无效）| Invalid layout (size or alignment) *}
    aeInvalidLayout,

    {** 对齐要求不支持 | Alignment not supported *}
    aeAlignmentNotSupported,

    {** 容量已满（用于固定大小池）| Capacity exhausted (for fixed pools) *}
    aeCapacityExhausted,

    {** 无效指针（释放时）| Invalid pointer (on deallocation) *}
    aeInvalidPointer,

    {** 双重释放 | Double free detected *}
    aeDoubleFree,

    {** Realloc 不支持（用于只读池或 arena）| Realloc not supported *}
    aeReallocNotSupported,

    {** 大小不匹配（Realloc 时）| Size mismatch *}
    aeSizeMismatch,

    {** 池已关闭或销毁 | Pool closed or destroyed *}
    aePoolClosed,

    {** 内部错误 | Internal error *}
    aeInternalError,

    {** 哨兵值被破坏（缓冲区溢出）| Sentinel corrupted (buffer overflow) *}
    aeSentinelCorrupted,

    {** 元数据校验和失败 | Metadata checksum failure *}
    aeChecksumFailure,

    {** 栈溢出（递归分配深度超限）| Stack overflow (recursion depth exceeded) *}
    aeStackOverflow
  );

  {**
   * EAllocError
   *
   * @desc 分配异常基类
   *       Base exception for allocation errors
   *
   * @note 仅在需要异常语义时使用，热路径不应抛异常
   *}
  EAllocError = class(nextpas.core.exception.ENextPasError)
  private
    FError: TAllocError;
  public
    constructor Create(aError: TAllocError; const aMsg: string = '');
    property Error: TAllocError read FError;
  end;

  EOutOfMemory = class(nextpas.core.exception.EOutOfMemory)
  private
    FError: TAllocError;
  public
    constructor Create(aError: TAllocError; const aMsg: string = '');
    {** 快捷构造：自动使用 aeOutOfMemory，18 处调用点统一。 }
    constructor CreateMsg(const aMsg: string);
    property Error: TAllocError read FError;
  end;
  EInvalidLayout = class(EAllocError);
  EInvalidPointer = class(EAllocError);
  EDoubleFree = class(EAllocError);
  EStackOverflow = class(EAllocError);

{**
 * AllocErrorToString
 *
 * @desc 获取错误码的字符串描述
 *       Get string description for error code
 *}
function AllocErrorToString(aError: TAllocError): string;

{** Canonical raise-site message stem: Type.Method: reason
 *  Pass the result as aMsg to EAllocError.Create / EOutOfMemory.Create.
 *  Create appends code label via BuildAllocMsg as "stem [Code label]". }
function FormatAllocErrorMsg(const ATypeName, AMethod, AReason: string): string;

{** True when AMsg matches Type.Method: reason (dot before ": "). }
function IsWellFormedAllocErrorMsg(const AMsg: string): Boolean;

{** Extract TAllocError from EAllocError or mem EOutOfMemory; False otherwise.
 *  Use with except on E: ENextPasError — do not require is EAllocError alone. }
function TryAllocErrorCode(E: Exception; out ACode: TAllocError): Boolean;

{** SanitizeRuntimeAlignment: for runtime allocation calls where 0 is invalid.
 *  Clamp AAlignment to >= SizeOf(Pointer), then validate power-of-two.
 *  Returns the sanitized value. Raises EAllocError if alignment is not a
 *  power of two after clamping.
 *  Use this for AllocAligned/FreeAligned runtime paths. }
function SanitizeRuntimeAlignment(AAlignment: SizeUInt): SizeUInt;

{** SanitizeConfigAlignment: for config/constructor alignment parameters.
    0→DEFAULT_ALIGNMENT, validate power-of-two, clamp to DEFAULT_ALIGNMENT.
    Raises EAllocError(aeAlignmentNotSupported) if not power of two.
    Use this for TArenaConfig/TChunkedArenaConfig/constructor alignment args. }
function SanitizeConfigAlignment(AAlignment: SizeUInt): SizeUInt;

implementation

const
  ERROR_MESSAGES: array[TAllocError] of string = (
    'Success',
    'Out of memory',
    'Invalid layout',
    'Alignment not supported',
    'Capacity exhausted',
    'Invalid pointer',
    'Double free detected',
    'Realloc not supported',
    'Size mismatch',
    'Pool closed',
    'Internal error',
    'Sentinel corrupted (buffer overflow)',
    'Metadata checksum failure',
    'Stack overflow (recursion depth exceeded)'
  );

function AllocErrorToString(aError: TAllocError): string;
begin
  Result := ERROR_MESSAGES[aError];
end;

function FormatAllocErrorMsg(const ATypeName, AMethod, AReason: string): string;
begin
  Result := ATypeName + '.' + AMethod + ': ' + AReason;
end;

function IsWellFormedAllocErrorMsg(const AMsg: string): Boolean;
var
  I, LDot, LColon: Integer;
begin
  LDot := 0;
  LColon := 0;
  for I := 1 to Length(AMsg) do
  begin
    if (AMsg[I] = '.') and (LDot = 0) then
      LDot := I
    else if (AMsg[I] = ':') and (LColon = 0) then
      LColon := I;
  end;
  Result := (LDot > 1) and (LColon > LDot + 1) and
    (LColon + 1 <= Length(AMsg)) and (AMsg[LColon + 1] = ' ');
end;

function AllocErrorCategory(aError: TAllocError): TErrorCategory;
begin
  case aError of
    aeOutOfMemory, aeCapacityExhausted:
      Result := ecResourceExhausted;
    aeInvalidLayout, aeAlignmentNotSupported, aeSizeMismatch:
      Result := ecInvalidArgument;
    aeInvalidPointer, aeDoubleFree, aePoolClosed, aeReallocNotSupported:
      Result := ecInvalidOperation;
    aeSentinelCorrupted, aeChecksumFailure, aeStackOverflow:
      Result := ecInvalidOperation;
    aeInternalError:
      Result := ecInternal;
  else
    Result := ecNone;
  end;
end;

function BuildAllocMsg(aError: TAllocError; const aMsg: string): string; inline;
begin
  if aMsg <> '' then
    Result := aMsg + ' [' + ERROR_MESSAGES[aError] + ']'
  else
    Result := ERROR_MESSAGES[aError];
end;

function TryAllocErrorCode(E: Exception; out ACode: TAllocError): Boolean;
begin
  if E is EAllocError then
  begin
    ACode := EAllocError(E).Error;
    Exit(True);
  end;
  if E is EOutOfMemory then
  begin
    ACode := EOutOfMemory(E).Error;
    Exit(True);
  end;
  ACode := aeNone;
  Result := False;
end;

{ EAllocError }

constructor EAllocError.Create(aError: TAllocError; const aMsg: string);
begin
  if aError = aeNone then
    raise EAllocError.Create(aeInternalError,
      FormatAllocErrorMsg('EAllocError', 'Create', 'aeNone is not a valid error code'));
  FError := aError;
  inherited Create(BuildAllocMsg(aError, aMsg), AllocErrorCategory(aError));
end;

{ EOutOfMemory }

constructor EOutOfMemory.Create(aError: TAllocError; const aMsg: string);
begin
  if aError = aeNone then
    raise EAllocError.Create(aeInternalError,
      FormatAllocErrorMsg('EOutOfMemory', 'Create', 'aeNone is not a valid error code'));
  FError := aError;
  inherited Create(BuildAllocMsg(aError, aMsg));
end;

constructor EOutOfMemory.CreateMsg(const aMsg: string);
begin
  FError := aeOutOfMemory;
  inherited Create(BuildAllocMsg(aeOutOfMemory, aMsg));
end;

function SanitizeRuntimeAlignment(AAlignment: SizeUInt): SizeUInt;
begin
  if AAlignment < SizeOf(Pointer) then
    AAlignment := SizeOf(Pointer);
  if (AAlignment and (AAlignment - 1)) <> 0 then
    raise EAllocError.Create(aeAlignmentNotSupported,
      FormatAllocErrorMsg('SanitizeRuntimeAlignment', 'Sanitize',
        'alignment must be power of two and >= pointer size'));
  Result := AAlignment;
end;

function SanitizeConfigAlignment(AAlignment: SizeUInt): SizeUInt;
begin
  if AAlignment = 0 then
    Exit(DEFAULT_ALIGNMENT);
  if (AAlignment and (AAlignment - 1)) <> 0 then
    raise EAllocError.Create(aeAlignmentNotSupported,
      FormatAllocErrorMsg('SanitizeConfigAlignment', 'Sanitize',
        'alignment must be power of 2'));
  if AAlignment < DEFAULT_ALIGNMENT then
    AAlignment := DEFAULT_ALIGNMENT;
  Result := AAlignment;
end;

end.
