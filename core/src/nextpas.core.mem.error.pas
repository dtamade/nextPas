{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.error - 内存分配错误类型
## Abstract 摘要

Memory allocation error types for Rust-style error handling.
Rust 风格的内存分配错误类型。

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.error;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base;  // ✅ MEM-002: 引入 ECore 基类

type
  {**
   * TAllocError
   *
   * @desc 内存分配错误码
   *       Memory allocation error codes
   *
   * @note 设计原则：
   *   - 零值表示成功，方便条件判断
   *   - 枚举值可直接作为 Result 类型使用
   *   - 性能关键：不使用异常，使用返回值
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
   * TAllocResult
   *
   * @desc 分配结果类型（Rust Result<*mut u8, AllocError> 风格）
   *       Allocation result type
   *
   * @note 性能关键：
   *   - 16 字节（指针 + 错误码 + 填充）
   *   - 所有方法都是 inline
   *   - 无异常，纯值类型
   *}
  TAllocResult = record
  private
    FPtr: Pointer;
    FError: TAllocError;
  public
    {** 获取指针（不检查错误）| Get pointer without checking *}
    property Ptr: Pointer read FPtr;

    {** 获取错误码 | Get error code *}
    property Error: TAllocError read FError;

    {**
     * Ok
     *
     * @desc 创建成功结果
     *       Create success result
     *
     * @params
     *   aPtr: Pointer 分配的指针
     *
     * @return 成功的 TAllocResult
     *}
    class function Ok(aPtr: Pointer): TAllocResult; static; inline;

    {**
     * Err
     *
     * @desc 创建错误结果
     *       Create error result
     *
     * @params
     *   aError: TAllocError 错误码
     *
     * @return 错误的 TAllocResult
     *}
    class function Err(aError: TAllocError): TAllocResult; static; inline;

    {**
     * IsOk
     *
     * @desc 检查是否成功
     *       Check if allocation succeeded
     *
     * @return True 如果成功
     *}
    function IsOk: Boolean; inline;

    {**
     * IsErr
     *
     * @desc 检查是否失败
     *       Check if allocation failed
     *
     * @return True 如果失败
     *}
    function IsErr: Boolean; inline;

    {**
     * Unwrap
     *
     * @desc 获取指针，失败时返回 nil
     *       Get pointer, nil on failure
     *
     * @return 指针或 nil
     *
     * @note 不抛异常，性能安全
     *}
    function Unwrap: Pointer; inline;

    {**
     * UnwrapOr
     *
     * @desc 获取指针，失败时返回默认值
     *       Get pointer, or default on failure
     *
     * @params
     *   aDefault: Pointer 默认值
     *
     * @return 指针或默认值
     *}
    function UnwrapOr(aDefault: Pointer): Pointer; inline;

    {**
     * ExpectPtr
     *
     * @desc 获取指针，失败时抛出异常
     *       Get pointer, raise exception on failure
     *
     * @params
     *   aMsg: string 错误消息
     *
     * @return 指针
     *
     * @exception EOutOfMemory 分配失败时
     *
     * @note 仅在确实需要异常时使用
     *}
    function ExpectPtr(const aMsg: string = ''): Pointer;
  end;

  {**
   * EAllocError
   *
   * @desc 分配异常基类
   *       Base exception for allocation errors
   *
   * @note 仅在需要异常语义时使用，热路径不应抛异常
   *}
  EAllocError = class(ECore)  // ✅ MEM-002: 继承自 ECore
  private
    FError: TAllocError;
  public
    constructor Create(aError: TAllocError; const aMsg: string = '');
    property Error: TAllocError read FError;
  end;

  EOutOfMemory = class(EAllocError);
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

{ TAllocResult }

class function TAllocResult.Ok(aPtr: Pointer): TAllocResult;
begin
  Result.FPtr := aPtr;
  Result.FError := aeNone;
end;

class function TAllocResult.Err(aError: TAllocError): TAllocResult;
begin
  Result.FPtr := nil;
  Result.FError := aError;
end;

function TAllocResult.IsOk: Boolean;
begin
  Result := FError = aeNone;
end;

function TAllocResult.IsErr: Boolean;
begin
  Result := FError <> aeNone;
end;

function TAllocResult.Unwrap: Pointer;
begin
  // ✅ OPT: 直接返回 FPtr，因为 Err() 构造时已将 FPtr 设为 nil
  // 无需条件判断，减少分支预测开销
  Result := FPtr;
end;

function TAllocResult.UnwrapOr(aDefault: Pointer): Pointer;
begin
  if FError = aeNone then
    Result := FPtr
  else
    Result := aDefault;
end;

function TAllocResult.ExpectPtr(const aMsg: string): Pointer;

  procedure RaiseSpecificException(aError: TAllocError; const aMessage: string);
  begin
    case aError of
      aeOutOfMemory:
        raise EOutOfMemory.Create(aError, aMessage);
      aeInvalidLayout, aeAlignmentNotSupported, aeSizeMismatch:
        raise EInvalidLayout.Create(aError, aMessage);
      aeInvalidPointer, aeCapacityExhausted, aePoolClosed, aeReallocNotSupported:
        raise EInvalidPointer.Create(aError, aMessage);
      aeDoubleFree:
        raise EDoubleFree.Create(aError, aMessage);
      aeInternalError:
        raise EAllocError.Create(aError, aMessage);  // ✅ m-5: 显式处理 aeInternalError
    else
      raise EAllocError.Create(aError, aMessage);
    end;
  end;

begin
  Result := nil;  // ✅ C-1: 初始化 Result 避免编译器警告
  if FError = aeNone then
    Result := FPtr
  else
    RaiseSpecificException(FError, aMsg);
end;

{ EAllocError }

constructor EAllocError.Create(aError: TAllocError; const aMsg: string);
begin
  FError := aError;
  if aMsg <> '' then
    inherited Create(aMsg + ': ' + ERROR_MESSAGES[aError])
  else
    inherited Create(ERROR_MESSAGES[aError]);
end;

end.
