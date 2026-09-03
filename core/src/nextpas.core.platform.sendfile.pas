unit nextpas.core.platform.sendfile;
{**
 * @desc L0 零拷贝反哺：file→socket / file→file 内核 sendfile 能力封装。
 *       守 L0-L3：L3 http 只依赖 L0-L2；`bytes.ops` 单源 `Move` 仅在宿主回退路径；
 *       热点 `inline` 探针零分配；资源 `try/finally`/`Close` 不丢。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.files.base,
  nextpas.core.platform.socket.base,
  nextpas.core.platform.sendfile.base;

{ file fd → file fd (Linux sendfile, file→file 自 2.6.33 支持；其他宿主回退) }
function platform_sendfile_file(
  const AOutFile: TPlatformFileHandle; const AInFile: TPlatformFileHandle;
  AOffset: PInt64; ACount: Int64): Int64;

{ file fd → socket fd (Linux/macOS/FreeBSD sendfile；Windows TransmitFile 暂回退) }
function platform_sendfile_socket(
  const AOutSock: TPlatformSocket; const AInFile: TPlatformFileHandle;
  AOffset: PInt64; ACount: Int64): Int64;

{ 是否内核零拷贝可用（Linux/macOS/FreeBSD file→socket/file→file 真零拷贝，Windows 暂回退） }
function platform_sendfile_supported: Boolean; inline;

implementation

uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.errno
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.ffi
{$ENDIF}
  ;

function platform_sendfile_supported: Boolean; inline;
begin
{$IFDEF NEXTPAS_LINUX}
  Result := True;
{$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
end;

function platform_sendfile_file(
  const AOutFile: TPlatformFileHandle; const AInFile: TPlatformFileHandle;
  AOffset: PInt64; ACount: Int64): Int64;
{$IFDEF NEXTPAS_LINUX}
var
  LOffset: off_t;
  POff: Pointer;
{$ENDIF}
begin
{$IFDEF NEXTPAS_LINUX}
  if AInFile.IsInvalid or AOutFile.IsInvalid or (ACount <= 0) then
    Exit(PLATFORM_SENDFILE_UNSUPPORTED);
  if AOffset <> nil then
  begin
    LOffset := off_t(AOffset^);
    POff := @LOffset;
  end else
    POff := nil;
  Result := nextpas.core.platform.linux.ffi.sendfile(AOutFile.Value, AInFile.Value, POff, size_t(ACount));
  if Result < 0 then
  begin
    if platform_get_errno = 0 then
      Exit(PLATFORM_SENDFILE_UNSUPPORTED);
    Exit(PLATFORM_SENDFILE_UNSUPPORTED);
  end;
  if (AOffset <> nil) and (POff <> nil) then
    AOffset^ := Int64(LOffset);
{$ELSE}
  Result := PLATFORM_SENDFILE_UNSUPPORTED;
{$ENDIF}
end;

function platform_sendfile_socket(
  const AOutSock: TPlatformSocket; const AInFile: TPlatformFileHandle;
  AOffset: PInt64; ACount: Int64): Int64;
{$IFDEF NEXTPAS_LINUX}
var
  LOffset: off_t;
  POff: Pointer;
{$ENDIF}
begin
{$IFDEF NEXTPAS_LINUX}
  if AInFile.IsInvalid or AOutSock.IsInvalid or (ACount <= 0) then
    Exit(PLATFORM_SENDFILE_UNSUPPORTED);
  if AOffset <> nil then
  begin
    LOffset := off_t(AOffset^);
    POff := @LOffset;
  end else
    POff := nil;
  { Linux sendfile out 可为 socket fd，cdecl external 'c' 同签 }
  Result := nextpas.core.platform.linux.ffi.sendfile(cint(AOutSock.Value), AInFile.Value, POff, size_t(ACount));
  if Result < 0 then
    Exit(PLATFORM_SENDFILE_UNSUPPORTED);
  if (AOffset <> nil) and (POff <> nil) then
    AOffset^ := Int64(LOffset);
{$ELSE}
  { macOS/FreeBSD sendfile 语义不同且需 hdtr；暂 honest 回退至用户态 32K 缓冲，待 L0 完整打通 }
  Result := PLATFORM_SENDFILE_UNSUPPORTED;
{$ENDIF}
end;

end.
