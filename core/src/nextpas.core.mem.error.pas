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

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.error;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

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
    aeInternalError
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
    property Error: TAllocError read FError;
  end;
  EInvalidLayout = class(EAllocError);
  EInvalidPointer = class(EAllocError);
  EDoubleFree = class(EAllocError);

{**
 * AllocErrorToString
 *
 * @desc 获取错误码的字符串描述
 *       Get string description for error code
 *}
function AllocErrorToString(aError: TAllocError): string;

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
    'Internal error'
  );

function AllocErrorToString(aError: TAllocError): string;
begin
  Result := ERROR_MESSAGES[aError];
end;

function AllocErrorCategory(aError: TAllocError): TErrorCategory;
begin
  case aError of
    aeOutOfMemory, aeCapacityExhausted:
      Result := ecResourceExhausted;
    aeInvalidLayout, aeAlignmentNotSupported, aeSizeMismatch:
      Result := ecInvalidArgument;
    aeInvalidPointer, aeDoubleFree:
      Result := ecInvalidOperation;
    aePoolClosed, aeReallocNotSupported:
      Result := ecInvalidOperation;
    aeInternalError:
      Result := ecInternal;
  else
    Result := ecNone;
  end;
end;

{ EAllocError }

constructor EAllocError.Create(aError: TAllocError; const aMsg: string);
begin
  FError := aError;
  if aMsg <> '' then
    inherited Create(aMsg + ': ' + ERROR_MESSAGES[aError], AllocErrorCategory(aError))
  else
    inherited Create(ERROR_MESSAGES[aError], AllocErrorCategory(aError));
end;

{ EOutOfMemory }

constructor EOutOfMemory.Create(aError: TAllocError; const aMsg: string);
begin
  FError := aError;
  if aMsg <> '' then
    inherited Create(aMsg + ': ' + ERROR_MESSAGES[aError])
  else
    inherited Create(ERROR_MESSAGES[aError]);
end;

end.
