unit nextpas.core.platform.pipe;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 管道句柄记录，封装平台相关的读写端 *}
  TPlatformPipe = record
    ReadFd: PtrInt;
    WriteFd: PtrInt;
  {$IFDEF NEXTPAS_WINDOWS}
    ReadHandle: PtrUInt;
    WriteHandle: PtrUInt;
  {$ENDIF}
    {** @desc 检查管道读端是否有效
        @return True 如果读端有效 *}
    function IsReadValid: Boolean; inline;
    {** @desc 检查管道写端是否有效
        @return True 如果写端有效 *}
    function IsWriteValid: Boolean; inline;
    {** @desc 检查管道是否完全有效（读写端都有效）
        @return True 如果管道完全有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查管道是否无效（任一端无效）
        @return True 如果管道无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 关闭管道读端
        @return 0 成功，PLATFORM_ERR_BADF 管道无效 *}
    function CloseRead: Int32;
    {** @desc 关闭管道写端
        @return 0 成功，PLATFORM_ERR_BADF 管道无效 *}
    function CloseWrite: Int32;
    {** @desc 关闭管道两端
        @return 0 成功 *}
    function Close: Int32;
  end;

{** @desc 创建匿名管道
    @param APipe 输出参数，返回创建的管道句柄
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_pipe_create(out APipe: TPlatformPipe): Int32;

{** @desc 关闭管道读端
    @param APipe 管道句柄
    @return 0 成功，PLATFORM_ERR_BADF 管道无效 *}
function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;

{** @desc 关闭管道写端
    @param APipe 管道句柄
    @return 0 成功，PLATFORM_ERR_BADF 管道无效 *}
function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;

{** @desc 关闭管道两端
    @param APipe 管道句柄
    @return 0 成功 *}
function platform_pipe_close(var APipe: TPlatformPipe): Int32;

{** @desc 复制文件描述符（POSIX dup2 封装）
    @param AOldFd 源文件描述符
    @param ANewFd 目标文件描述符
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_dup2(AOldFd: PtrInt; ANewFd: PtrInt): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
  {$ENDIF}
  ;

function TPlatformPipe.IsReadValid: Boolean;
begin
  Result := ReadFd >= 0;
end;

function TPlatformPipe.IsWriteValid: Boolean;
begin
  Result := WriteFd >= 0;
end;

function TPlatformPipe.IsValid: Boolean;
begin
  Result := (ReadFd >= 0) and (WriteFd >= 0);
end;

function TPlatformPipe.IsInvalid: Boolean;
begin
  Result := (ReadFd < 0) or (WriteFd < 0);
end;

function TPlatformPipe.CloseRead: Int32;
begin
  Result := platform_pipe_close_read(Self);
end;

function TPlatformPipe.CloseWrite: Int32;
begin
  Result := platform_pipe_close_write(Self);
end;

function TPlatformPipe.Close: Int32;
begin
  Result := platform_pipe_close(Self);
end;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
var
  LFds: array[0..1] of Int32;
begin
  FillChar(APipe, SizeOf(APipe), 0);
{$IFDEF NEXTPAS_LINUX}
  Result := PosixCheck(pipe2(@LFds[0], O_CLOEXEC));
{$ELSE}
  Result := PosixCheck(pipe(@LFds[0]));
  if Result = 0 then
  begin
    fcntl(cint(LFds[0]), F_SETFD, FD_CLOEXEC);
    fcntl(cint(LFds[1]), F_SETFD, FD_CLOEXEC);
  end;
{$ENDIF}
  if Result = 0 then
  begin
    APipe.ReadFd := LFds[0];
    APipe.WriteFd := LFds[1];
  end;
end;

function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadFd < 0 then Exit(PLATFORM_ERR_BADF);
  Result := PosixCheck(close(cint(APipe.ReadFd)));
  APipe.ReadFd := -1;
end;

function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin
  if APipe.WriteFd < 0 then Exit(PLATFORM_ERR_BADF);
  Result := PosixCheck(close(cint(APipe.WriteFd)));
  APipe.WriteFd := -1;
end;

function platform_pipe_close(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadFd >= 0 then close(cint(APipe.ReadFd));
  if APipe.WriteFd >= 0 then close(cint(APipe.WriteFd));
  APipe.ReadFd := -1;
  APipe.WriteFd := -1;
  Result := 0;
end;

function platform_dup2(AOldFd: PtrInt; ANewFd: PtrInt): Int32;
begin
  Result := PosixCheck(dup2(cint(AOldFd), cint(ANewFd)));
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function TPlatformPipe.IsReadValid: Boolean;
begin
  Result := ReadFd >= 0;
end;

function TPlatformPipe.IsWriteValid: Boolean;
begin
  Result := WriteFd >= 0;
end;

function TPlatformPipe.IsValid: Boolean;
begin
  Result := (ReadFd >= 0) and (WriteFd >= 0);
end;

function TPlatformPipe.IsInvalid: Boolean;
begin
  Result := (ReadFd < 0) or (WriteFd < 0);
end;

function TPlatformPipe.CloseRead: Int32;
begin
  Result := platform_pipe_close_read(Self);
end;

function TPlatformPipe.CloseWrite: Int32;
begin
  Result := platform_pipe_close_write(Self);
end;

function TPlatformPipe.Close: Int32;
begin
  Result := platform_pipe_close(Self);
end;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
var
  LRead, LWrite: HANDLE;
begin
  FillChar(APipe, SizeOf(APipe), 0);
  if not CreatePipe(@LRead, @LWrite, nil, 0) then
    Exit(Int32(GetLastError));
  APipe.ReadHandle := PtrUInt(LRead);
  APipe.WriteHandle := PtrUInt(LWrite);
  APipe.ReadFd := PtrInt(LRead);
  APipe.WriteFd := PtrInt(LWrite);
  Result := 0;
end;

function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadHandle = 0 then Exit(PLATFORM_ERR_BADF);
  CloseHandle(HANDLE(APipe.ReadHandle));
  APipe.ReadHandle := 0;
  APipe.ReadFd := -1;
  Result := 0;
end;

function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin
  if APipe.WriteHandle = 0 then Exit(PLATFORM_ERR_BADF);
  CloseHandle(HANDLE(APipe.WriteHandle));
  APipe.WriteHandle := 0;
  APipe.WriteFd := -1;
  Result := 0;
end;

function platform_pipe_close(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadHandle <> 0 then CloseHandle(HANDLE(APipe.ReadHandle));
  if APipe.WriteHandle <> 0 then CloseHandle(HANDLE(APipe.WriteHandle));
  APipe.ReadHandle := 0;
  APipe.WriteHandle := 0;
  APipe.ReadFd := -1;
  APipe.WriteFd := -1;
  Result := 0;
end;

function platform_dup2(AOldFd: PtrInt; ANewFd: PtrInt): Int32;
begin
  Result := Int32(ERROR_NOT_SUPPORTED);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function TPlatformPipe.IsReadValid: Boolean;
begin
  Result := ReadFd >= 0;
end;

function TPlatformPipe.IsWriteValid: Boolean;
begin
  Result := WriteFd >= 0;
end;

function TPlatformPipe.IsValid: Boolean;
begin
  Result := (ReadFd >= 0) and (WriteFd >= 0);
end;

function TPlatformPipe.IsInvalid: Boolean;
begin
  Result := (ReadFd < 0) or (WriteFd < 0);
end;

function TPlatformPipe.CloseRead: Int32;
begin
  Result := platform_pipe_close_read(Self);
end;

function TPlatformPipe.CloseWrite: Int32;
begin
  Result := platform_pipe_close_write(Self);
end;

function TPlatformPipe.Close: Int32;
begin
  Result := platform_pipe_close(Self);
end;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
begin FillChar(APipe, SizeOf(APipe), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pipe_close(var APipe: TPlatformPipe): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dup2(AOldFd: PtrInt; ANewFd: PtrInt): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
