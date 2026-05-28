unit nextpas.core.platform.pipe;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformPipe = record
    ReadFd: Int32;
    WriteFd: Int32;
  {$IFDEF NEXTPAS_WINDOWS}
    ReadHandle: PtrUInt;
    WriteHandle: PtrUInt;
  {$ENDIF}
  end;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
function platform_pipe_close(var APipe: TPlatformPipe): Int32;
function platform_dup2(AOldFd: Int32; ANewFd: Int32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
var
  LFds: array[0..1] of Int32;
begin
  FillChar(APipe, SizeOf(APipe), 0);
  if pipe(@LFds[0]) <> 0 then
    Exit(platform_get_errno);
  APipe.ReadFd := LFds[0];
  APipe.WriteFd := LFds[1];
  Result := 0;
end;

function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadFd < 0 then Exit(9);
  close(APipe.ReadFd);
  APipe.ReadFd := -1;
  Result := 0;
end;

function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin
  if APipe.WriteFd < 0 then Exit(9);
  close(APipe.WriteFd);
  APipe.WriteFd := -1;
  Result := 0;
end;

function platform_pipe_close(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadFd >= 0 then close(APipe.ReadFd);
  if APipe.WriteFd >= 0 then close(APipe.WriteFd);
  APipe.ReadFd := -1;
  APipe.WriteFd := -1;
  Result := 0;
end;

function platform_dup2(AOldFd: Int32; ANewFd: Int32): Int32;
begin
  if dup2(AOldFd, ANewFd) < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_pipe_create(out APipe: TPlatformPipe): Int32;
var
  LRead, LWrite: HANDLE;
begin
  FillChar(APipe, SizeOf(APipe), 0);
  if not CreatePipe(@LRead, @LWrite, nil, 0) then
    Exit(Int32(GetLastError));
  APipe.ReadHandle := PtrUInt(LRead);
  APipe.WriteHandle := PtrUInt(LWrite);
  APipe.ReadFd := Int32(LRead);
  APipe.WriteFd := Int32(LWrite);
  Result := 0;
end;

function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin
  if APipe.ReadHandle = 0 then Exit(6);
  CloseHandle(HANDLE(APipe.ReadHandle));
  APipe.ReadHandle := 0;
  APipe.ReadFd := -1;
  Result := 0;
end;

function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin
  if APipe.WriteHandle = 0 then Exit(6);
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

function platform_dup2(AOldFd: Int32; ANewFd: Int32): Int32;
begin
  Result := Int32(GetLastError);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_pipe_create(out APipe: TPlatformPipe): Int32;
begin FillChar(APipe, SizeOf(APipe), 0); Result := -1; end;
function platform_pipe_close_read(var APipe: TPlatformPipe): Int32;
begin Result := -1; end;
function platform_pipe_close_write(var APipe: TPlatformPipe): Int32;
begin Result := -1; end;
function platform_pipe_close(var APipe: TPlatformPipe): Int32;
begin Result := -1; end;
function platform_dup2(AOldFd: Int32; ANewFd: Int32): Int32;
begin Result := -1; end;
{$ENDIF}

end.
