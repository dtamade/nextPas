unit nextpas.core.platform.dl;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 动态库句柄，封装平台相关的库引用 *}
  TPlatformLibrary = record
  {$IFDEF NEXTPAS_WINDOWS}
    Handle: PtrUInt;
  {$ELSE}
    Handle: Pointer;
  {$ENDIF}
    {** @desc 检查库句柄是否有效
        @return True 如果库句柄有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查库句柄是否无效
        @return True 如果库句柄无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 查找动态库中的符号
        @param AName 符号名称
        @param AAddr 输出参数，返回符号地址
        @return 0 成功，PLATFORM_ERR_NOTFOUND 符号不存在 *}
    function Sym(const AName: PAnsiChar; out AAddr: Pointer): Int32;
    {** @desc 关闭动态库
        @return 0 成功，PLATFORM_ERR_* 错误码 *}
    function Close: Int32;
  end;

  {** @desc 动态库打开标志 *}
  TPlatformDlFlag = (
    dlfLazy,    {**< 延迟绑定（符号首次调用时解析） *}
    dlfNow,     {**< 立即绑定（打开时解析所有符号） *}
    dlfGlobal   {**< 全局符号可见（后续加载的库可引用） *}
  );
  {** @desc 动态库打开标志集合 *}
  TPlatformDlFlags = set of TPlatformDlFlag;

const
  {** 延迟绑定（符号首次调用时解析） *}
  PLATFORM_DL_LAZY   = 1;
  {** 立即绑定（打开时解析所有符号） *}
  PLATFORM_DL_NOW    = 2;
  {** 全局符号可见（后续加载的库可引用） *}
  PLATFORM_DL_GLOBAL = 4;

{** @desc 打开动态链接库
    @param APath 库文件路径
    @param AFlags 打开标志（PLATFORM_DL_*）
    @param ALib 输出参数，返回库句柄
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;

{** @desc 查找动态库中的符号
    @param ALib 库句柄
    @param AName 符号名称
    @param AAddr 输出参数，返回符号地址
    @return 0 成功，PLATFORM_ERR_NOTFOUND 符号不存在 *}
function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;

{** @desc 关闭动态库
    @param ALib 库句柄（关闭后句柄清零）
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_dl_close(var ALib: TPlatformLibrary): Int32;

{** @desc 获取动态库操作的错误信息
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return 错误信息长度 *}
function platform_dl_error(ABuf: PAnsiChar; ABufSize: Int32): Int32;

{** @desc 将类型安全的标志集合转换为整数标志
    @param AFlags 标志集合
    @return 整数标志值 *}
function platform_dl_flags_to_int(AFlags: TPlatformDlFlags): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
{$ENDIF}
  ;

function TPlatformLibrary.IsValid: Boolean;
begin
  Result := Handle <> nil;
end;

function TPlatformLibrary.IsInvalid: Boolean;
begin
  Result := Handle = nil;
end;

function TPlatformLibrary.Sym(const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  Result := platform_dl_sym(Self, AName, AAddr);
end;

function TPlatformLibrary.Close: Int32;
begin
  Result := platform_dl_close(Self);
end;

{** @desc 将类型安全的标志集合转换为整数标志
    @param AFlags 标志集合
    @return 整数标志值 *}
function platform_dl_flags_to_int(AFlags: TPlatformDlFlags): Int32;
begin
  Result := 0;
  if dlfLazy in AFlags then
    Result := Result or PLATFORM_DL_LAZY;
  if dlfNow in AFlags then
    Result := Result or PLATFORM_DL_NOW;
  if dlfGlobal in AFlags then
    Result := Result or PLATFORM_DL_GLOBAL;
end;

function MapFlags(AFlags: Int32): Int32;
var
  LResult: Int32;
begin
  if (AFlags and PLATFORM_DL_NOW) <> 0 then
    LResult := RTLD_NOW
  else
    LResult := RTLD_LAZY;
  if (AFlags and PLATFORM_DL_GLOBAL) <> 0 then
    LResult := LResult or RTLD_GLOBAL;
  Result := LResult;
end;

function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
begin
  FillChar(ALib, SizeOf(ALib), 0);
  { nil path = load self (dlopen(NULL, ...) semantics) }
  ALib.Handle := dlopen(APath, MapFlags(AFlags));
  if ALib.Handle = nil then
  begin
    { Map errno to a more specific error when possible;
      caller can always use platform_dl_error for the full message. }
    case platform_get_errno of
      ESysENOENT: Result := PLATFORM_ERR_NOENT;
      ESysEACCES: Result := PLATFORM_ERR_PERM;
      ESysENOMEM: Result := PLATFORM_ERR_NOMEM;
    else
      Result := PLATFORM_ERR_NOENT;
    end;
  end
  else
    Result := 0;
end;


function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  AAddr := nil;
  if ALib.Handle = nil then
    Exit(PLATFORM_ERR_INVALID);
  if AName = nil then
    Exit(PLATFORM_ERR_INVALID);
  dlerror; // clear previous error
  AAddr := dlsym(ALib.Handle, AName);
  if AAddr = nil then
  begin
    if dlerror <> nil then
      Result := PLATFORM_ERR_ENOENT // symbol not found
    else
      Result := 0; // symbol genuinely maps to nil (rare but valid)
  end
  else
    Result := 0;
end;

function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin
  if ALib.Handle = nil then
    Exit(PLATFORM_ERR_INVALID);
  if dlclose(ALib.Handle) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
  ALib.Handle := nil;
end;

function platform_dl_error(ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LMsg: PAnsiChar;
  LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(-1);
  LMsg := dlerror;
  if LMsg = nil then
  begin
    ABuf[0] := #0;
    Exit(0);
  end;
  LLen := 0;
  while LMsg[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufSize then
    LLen := ABufSize - 1;
  for I := 0 to LLen - 1 do
    ABuf[I] := LMsg[I];
  ABuf[LLen] := #0;
  Result := LLen;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;

function TPlatformLibrary.IsValid: Boolean;
begin
  Result := Handle <> 0;
end;

function TPlatformLibrary.IsInvalid: Boolean;
begin
  Result := Handle = 0;
end;

function TPlatformLibrary.Sym(const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  Result := platform_dl_sym(Self, AName, AAddr);
end;

function TPlatformLibrary.Close: Int32;
begin
  Result := platform_dl_close(Self);
end;

function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
var
  LPath: UnicodeString;
begin
  FillChar(ALib, SizeOf(ALib), 0);
  if APath = nil then
  begin
    { nil path = load self: GetModuleHandleW(nil) returns the handle
      of the calling process, equivalent to dlopen(NULL, ...). }
    ALib.Handle := PtrUInt(GetModuleHandleW(nil));
    if ALib.Handle = 0 then
      Exit(Int32(GetLastError));
    Exit(0);
  end;
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  ALib.Handle := PtrUInt(LoadLibraryW(PWideChar(LPath)));
  if ALib.Handle = 0 then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  AAddr := nil;
  if ALib.Handle = 0 then
    Exit(Int32(87)); // ERROR_INVALID_PARAMETER
  if AName = nil then
    Exit(PLATFORM_ERR_INVALID);
  AAddr := Pointer(GetProcAddress(HMODULE(ALib.Handle), AName));
  if AAddr = nil then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin
  if ALib.Handle = 0 then
    Exit(Int32(6)); // ERROR_INVALID_HANDLE
  if FreeLibrary(HMODULE(ALib.Handle)) then
    Result := 0
  else
    Result := Int32(GetLastError);
  ALib.Handle := 0;
end;

function platform_dl_error(ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LErr: DWORD;
  LLen: DWORD;
  I: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(-1);
  LErr := GetLastError;
  if LErr = 0 then
  begin
    ABuf[0] := #0;
    Exit(0);
  end;
  LLen := FormatMessageA(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil, LErr, 0, ABuf, DWORD(ABufSize), nil);
  if LLen = 0 then
  begin
    ABuf[0] := #0;
    Exit(Int32(LErr));
  end;
  I := Int32(LLen);
  while (I > 0) and ((ABuf[I-1] = #13) or (ABuf[I-1] = #10)) do
    Dec(I);
  ABuf[I] := #0;
  Result := I;
end;

{** @desc 将类型安全的标志集合转换为整数标志
    @param AFlags 标志集合
    @return 整数标志值 *}
function platform_dl_flags_to_int(AFlags: TPlatformDlFlags): Int32;
begin
  Result := 0;
  if dlfLazy in AFlags then
    Result := Result or PLATFORM_DL_LAZY;
  if dlfNow in AFlags then
    Result := Result or PLATFORM_DL_NOW;
  if dlfGlobal in AFlags then
    Result := Result or PLATFORM_DL_GLOBAL;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function TPlatformLibrary.IsValid: Boolean;
begin Result := Handle <> nil; end;
function TPlatformLibrary.IsInvalid: Boolean;
begin Result := Handle = nil; end;
function TPlatformLibrary.Sym(const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin Result := platform_dl_sym(Self, AName, AAddr); end;
function TPlatformLibrary.Close: Int32;
begin Result := platform_dl_close(Self); end;
function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
begin FillChar(ALib, SizeOf(ALib), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin AAddr := nil; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dl_error(ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin if ABuf <> nil then ABuf[0] := #0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dl_flags_to_int(AFlags: TPlatformDlFlags): Int32;
begin Result := 0; end;
{$ENDIF}

end.
