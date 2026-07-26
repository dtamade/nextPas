unit nextpas.core.platform.args;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.errno;

{** @desc 获取命令行参数个数（不含程序名）
    @return 参数个数；主机读取失败时返回 0 *}
function platform_args_count: Int32;

{** @desc 获取指定索引的命令行参数
    @param AIndex 参数索引（0 = 程序名）
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return >= 0 参数实际长度，PLATFORM_ERR_* 错误码 *}
function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;

{** @desc 获取可执行文件完整路径
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return >= 0 路径实际长度，PLATFORM_ERR_* 错误码 *}
function platform_args_exe_path(ABuf: PAnsiChar; ABufSize: Int32): Int32;

implementation

uses
  nextpas.core.platform.error
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  {$ELSE}
  , nextpas.core.platform.unix.base
  {$ENDIF}
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_UNIX}

const
  PLATFORM_ARGS_CMDLINE_PATH: PAnsiChar = '/proc/self/cmdline';
  PLATFORM_ARGS_CMDLINE_CAP = 65536;

function PlatformArgsOpenCmdline: PtrInt;
begin
  Result := open(PLATFORM_ARGS_CMDLINE_PATH, O_RDONLY, 0);
end;

function PlatformArgsReadAll(AFd: PtrInt; ABuf: PAnsiChar; ACap: Int32): Int32;
var
  LOff: Int32;
  LN: ssize_t;
begin
  LOff := 0;
  while LOff < ACap do
  begin
    LN := read(cint(AFd), @ABuf[LOff], size_t(ACap - LOff));
    if LN < 0 then
    begin
      if platform_get_errno = ESysEINTR then
        Continue;
      Exit(PLATFORM_ERR_IO);
    end;
    if LN = 0 then
      Break;
    Inc(LOff, Int32(LN));
  end;
  Result := LOff;
end;

function PlatformArgsSegmentCount(AData: PAnsiChar; ALen: Int32): Int32;
var
  I: Int32;
  LInSeg: Boolean;
begin
  Result := 0;
  LInSeg := False;
  I := 0;
  while I < ALen do
  begin
    if AData[I] <> #0 then
    begin
      if not LInSeg then
      begin
        Inc(Result);
        LInSeg := True;
      end;
    end
    else
      LInSeg := False;
    Inc(I);
  end;
end;

function PlatformArgsFindSegment(AData: PAnsiChar; ALen, AIndex: Int32;
  out ASeg: PAnsiChar; out ASegLen: Int32): Boolean;
var
  I, LIdx: Int32;
  LStart: Int32;
begin
  Result := False;
  ASeg := nil;
  ASegLen := 0;
  if AIndex < 0 then
    Exit;
  LIdx := 0;
  LStart := 0;
  I := 0;
  while I < ALen do
  begin
    if AData[I] = #0 then
    begin
      if I > LStart then
      begin
        if LIdx = AIndex then
        begin
          ASeg := @AData[LStart];
          ASegLen := I - LStart;
          Exit(True);
        end;
        Inc(LIdx);
      end;
      LStart := I + 1;
    end;
    Inc(I);
  end;
  if (I > LStart) and (LIdx = AIndex) then
  begin
    ASeg := @AData[LStart];
    ASegLen := I - LStart;
    Result := True;
  end;
end;

function PlatformArgsCopySeg(ASeg: PAnsiChar; ASegLen: Int32;
  ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LCopy: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LCopy := ASegLen;
  if LCopy >= ABufSize then
    LCopy := ABufSize - 1;
  if LCopy > 0 then
    Move(ASeg^, ABuf^, LCopy);
  ABuf[LCopy] := #0;
  Result := ASegLen;
end;

function platform_args_count: Int32;
var
  LFd: PtrInt;
  LBuf: array[0..PLATFORM_ARGS_CMDLINE_CAP - 1] of AnsiChar;
  LLen, LSegs: Int32;
begin
  Result := 0;
  LFd := PlatformArgsOpenCmdline;
  if LFd < 0 then
    Exit;
  LLen := PlatformArgsReadAll(LFd, @LBuf[0], PLATFORM_ARGS_CMDLINE_CAP);
  close(cint(LFd));
  if LLen < 0 then
    Exit(0);
  LSegs := PlatformArgsSegmentCount(@LBuf[0], LLen);
  if LSegs > 0 then
    Result := LSegs - 1
  else
    Result := 0;
end;

function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LFd: PtrInt;
  LBuf: array[0..PLATFORM_ARGS_CMDLINE_CAP - 1] of AnsiChar;
  LLen: Int32;
  LSeg: PAnsiChar;
  LSegLen: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  ABuf[0] := #0;
  if AIndex < 0 then
    Exit(PLATFORM_ERR_INVALID);
  LFd := PlatformArgsOpenCmdline;
  if LFd < 0 then
    Exit(PLATFORM_ERR_IO);
  LLen := PlatformArgsReadAll(LFd, @LBuf[0], PLATFORM_ARGS_CMDLINE_CAP);
  close(cint(LFd));
  if LLen < 0 then
    Exit(LLen);
  if not PlatformArgsFindSegment(@LBuf[0], LLen, AIndex, LSeg, LSegLen) then
    Exit(PLATFORM_ERR_INVALID);
  Result := PlatformArgsCopySeg(LSeg, LSegLen, ABuf, ABufSize);
end;

function platform_args_exe_path(ABuf: PAnsiChar; ABufSize: Int32): Int32;
{$IFDEF NEXTPAS_LINUX}
var
  L: PtrInt;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  L := readlink('/proc/self/exe', ABuf, ABufSize - 1);
  if L < 0 then
    Exit(Int32(platform_get_errno));
  ABuf[L] := #0;
  Result := Int32(L);
end;
{$ELSE}
begin
  Result := platform_args_get(0, ABuf, ABufSize);
end;
{$ENDIF}

{$ELSEIF defined(NEXTPAS_WINDOWS)}

type
  PPWideChar = ^PWideChar;

function WideLen(A: PWideChar): Int32;
begin
  Result := 0;
  if A = nil then
    Exit;
  while A[Result] <> #0 do
    Inc(Result);
end;

function WideToUtf8(AWide: PWideChar; ABuf: PAnsiChar; ABufSize: Int32;
  out AActual: Int32): Int32;
var
  LNeed: Int32;
begin
  AActual := 0;
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  if AWide = nil then
  begin
    ABuf[0] := #0;
    Exit(0);
  end;
  LNeed := WideCharToMultiByte(CP_UTF8, 0, AWide, -1, nil, 0, nil, nil);
  if LNeed <= 0 then
    Exit(platform_map_windows_error_code(GetLastError));
  AActual := LNeed - 1;
  if WideCharToMultiByte(CP_UTF8, 0, AWide, -1, ABuf, ABufSize, nil, nil) = 0 then
  begin
    if GetLastError = ERROR_INSUFFICIENT_BUFFER then
    begin
      if ABufSize > 0 then
        ABuf[ABufSize - 1] := #0;
      Exit(AActual);
    end;
    Exit(platform_map_windows_error_code(GetLastError));
  end;
  Result := AActual;
end;

function platform_args_count: Int32;
var
  LCmd: LPCWSTR;
  LArgv: PPWideChar;
  LN: Int32;
begin
  Result := 0;
  LCmd := GetCommandLineW;
  if LCmd = nil then
    Exit;
  LArgv := CommandLineToArgvW(LCmd, @LN);
  if LArgv = nil then
    Exit;
  if LN > 0 then
    Result := LN - 1
  else
    Result := 0;
  LocalFree(LArgv);
end;

function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LCmd: LPCWSTR;
  LArgv: PPWideChar;
  LN, LActual: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  ABuf[0] := #0;
  if AIndex < 0 then
    Exit(PLATFORM_ERR_INVALID);
  LCmd := GetCommandLineW;
  if LCmd = nil then
    Exit(PLATFORM_ERR_IO);
  LArgv := CommandLineToArgvW(LCmd, @LN);
  if LArgv = nil then
    Exit(platform_map_windows_error_code(GetLastError));
  if AIndex >= LN then
  begin
    LocalFree(LArgv);
    Exit(PLATFORM_ERR_INVALID);
  end;
  Result := WideToUtf8(LArgv[AIndex], ABuf, ABufSize, LActual);
  LocalFree(LArgv);
end;

function platform_args_exe_path(ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LWide: array[0..MAX_PATH] of WideChar;
  LN, LActual: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LN := GetModuleFileNameW(HMODULE(0), @LWide[0], MAX_PATH + 1);
  if LN = 0 then
    Exit(platform_map_windows_error_code(GetLastError));
  Result := WideToUtf8(@LWide[0], ABuf, ABufSize, LActual);
end;

{$ELSE}

function platform_args_count: Int32;
begin
  Result := 0;
end;

function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  ABuf[0] := #0;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_args_exe_path(ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  ABuf[0] := #0;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

{$ENDIF}

end.
