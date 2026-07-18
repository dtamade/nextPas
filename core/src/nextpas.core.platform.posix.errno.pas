unit nextpas.core.platform.posix.errno;

{$I nextpas.core.settings.inc}

interface

{** @desc 获取当前线程的 errno 值
    跨平台：Linux/macOS/FreeBSD 通过 TLS 指针解引用获取，
    其他平台返回 0。调用者应仅在系统调用返回 -1 后读取 errno。
    @return 当前 errno 值 *}
function platform_get_errno: Int32; inline;

implementation

uses
  nextpas.core.platform.posix.ffi;

function platform_get_errno: Int32; inline;
begin
{$IFDEF NEXTPAS_LINUX}
  Result := __errno_location^;
{$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  Result := __error^;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

end.
