{**
 * nextpas.core.platform.posix.helpers - POSIX 错误处理辅助函数
 *
 * 职责：提供统一的 POSIX 错误处理模式，消除代码重复
 * 层次：POSIX 平台内部辅助，不对外暴露
 *
 * 设计原则：
 *   - 所有辅助函数都是 inline，零开销
 *   - 统一错误码转换模式
 *   - 类型安全的文件描述符/句柄转换
 *}
unit nextpas.core.platform.posix.helpers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base;

{** @desc 将 POSIX 返回值转换为平台错误码
    @param AResult POSIX 函数返回值（-1 表示失败）
    @return 0 成功，否则返回 platform_get_errno *}
function PosixResultToError(AResult: cint): Int32; inline;

{** @desc 将 POSIX 文件描述符转换为平台句柄
    @param AFd POSIX 文件描述符（-1 表示失败）
    @param AHandle 输出平台句柄
    @return 0 成功，否则返回 platform_get_errno *}
function PosixFdToHandle(AFd: cint; out AHandle: Int32): Int32; inline;

{** @desc 将 POSIX ssize_t 返回值转换为平台结果
    @param AResult POSIX ssize_t 返回值（-1 表示失败）
    @param ACount 输出实际字节数
    @return 0 成功，否则返回 platform_get_errno *}
function PosixSsizeToResult(AResult: PtrInt; out ACount: PtrUInt): Int32; inline;

{** @desc 检查 POSIX 返回值并返回错误码（用于无输出参数的函数）
    @param AResult POSIX 函数返回值（0 成功，-1 失败）
    @return 0 成功，否则返回 platform_get_errno *}
function PosixCheck(AResult: cint): Int32; inline;

{** @desc 检查 POSIX 返回值是否为成功（0）
    @param AResult POSIX 函数返回值
    @return True 成功，False 失败 *}
function PosixSuccess(AResult: cint): Boolean; inline;

{** @desc 检查 POSIX 返回值是否为失败（-1）
    @param AResult POSIX 函数返回值
    @return True 失败，False 成功 *}
function PosixFailed(AResult: cint): Boolean; inline;

{** @desc 获取当前 errno 值（别名）
    @return 当前 errno 值 *}
function GetErrno: Int32; inline;

{** @desc 检查 errno 是否为指定错误码
    @param ACode 错误码
    @return True 匹配 *}
function ErrnoIs(ACode: Int32): Boolean; inline;

{** @desc 检查 errno 是否为 EINTR（被中断）
    @return True 是 EINTR *}
function ErrnoIsIntr: Boolean; inline;

{** @desc 检查 errno 是否为 EAGAIN/EWOULDBLOCK（资源暂时不可用）
    @return True 是 EAGAIN *}
function ErrnoIsAgain: Boolean; inline;

{** @desc 检查 errno 是否为 ENOENT（文件不存在）
    @return True 是 ENOENT *}
function ErrnoIsNoent: Boolean; inline;

{** @desc 检查 errno 是否为 EEXIST（文件已存在）
    @return True 是 EEXIST *}
function ErrnoIsExist: Boolean; inline;

{** @desc 将 POSIX off_t 返回值转换为平台结果
    @param AResult POSIX off_t 返回值（-1 表示失败）
    @param APos 输出位置值
    @return 0 成功，否则返回 platform_get_errno *}
function PosixOffToResult(AResult: Int64; out APos: Int64): Int32; inline;

implementation

uses
  {$IFDEF NEXTPAS_LINUX}
  nextpas.core.platform.linux.base
  {$ELSEIF defined(NEXTPAS_MACOS)}
  nextpas.core.platform.darwin.base
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  nextpas.core.platform.freebsd.base
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  nextpas.core.platform.android.base
  {$ELSE}
  nextpas.core.platform.unix.base
  {$ENDIF}
  ;

function PosixResultToError(AResult: cint): Int32;
begin
  if AResult < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function PosixFdToHandle(AFd: cint; out AHandle: Int32): Int32;
begin
  if AFd < 0 then
  begin
    AHandle := -1;
    Result := platform_get_errno;
  end
  else
  begin
    AHandle := AFd;
    Result := 0;
  end;
end;

function PosixSsizeToResult(AResult: PtrInt; out ACount: PtrUInt): Int32;
begin
  if AResult < 0 then
  begin
    ACount := 0;
    Result := platform_get_errno;
  end
  else
  begin
    ACount := PtrUInt(AResult);
    Result := 0;
  end;
end;

function PosixCheck(AResult: cint): Int32;
begin
  if AResult < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function PosixSuccess(AResult: cint): Boolean;
begin
  Result := AResult >= 0;
end;

function PosixFailed(AResult: cint): Boolean;
begin
  Result := AResult < 0;
end;

function GetErrno: Int32;
begin
  Result := platform_get_errno;
end;

function ErrnoIs(ACode: Int32): Boolean;
begin
  Result := platform_get_errno = ACode;
end;

function ErrnoIsIntr: Boolean;
begin
  Result := platform_get_errno = ESysEINTR;
end;

function ErrnoIsAgain: Boolean;
begin
  Result := platform_get_errno = ESysEAGAIN;
end;

function ErrnoIsNoent: Boolean;
begin
  { Keep errno truth on nextPas-owned host tables instead of importing FPC
    baseunix directly. Android/generic Unix only expose a smaller ESys* subset
    today, so ENOENT/EEXIST fall back to the canonical platform codes there. }
  {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  Result := platform_get_errno = ESysENOENT;
  {$ELSE}
  Result := platform_get_errno = PLATFORM_ERR_NOENT;
  {$ENDIF}
end;

function ErrnoIsExist: Boolean;
begin
  {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  Result := platform_get_errno = ESysEEXIST;
  {$ELSE}
  Result := platform_get_errno = PLATFORM_ERR_EXIST;
  {$ENDIF}
end;

function PosixOffToResult(AResult: Int64; out APos: Int64): Int32;
begin
  if AResult < 0 then
  begin
    APos := -1;
    Result := platform_get_errno;
  end
  else
  begin
    APos := AResult;
    Result := 0;
  end;
end;

end.
