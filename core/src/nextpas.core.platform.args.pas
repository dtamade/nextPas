unit nextpas.core.platform.args;

{$I nextpas.core.settings.inc}

interface

{** @desc 获取命令行参数个数
    @return 参数个数（不包含程序名） *}
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
  {$ENDIF}
  ;

function platform_args_count: Int32;
begin
  Result := System.ParamCount;
end;

function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  S: string;
  L, I: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  if (AIndex < 0) or (AIndex > System.ParamCount) then
  begin
    ABuf[0] := #0;
    Exit(PLATFORM_ERR_INVALID);
  end;
  S := System.ParamStr(AIndex);
  L := Length(S);
  if L >= ABufSize then
    L := ABufSize - 1;
  for I := 1 to L do
    ABuf[I - 1] := S[I];
  ABuf[L] := #0;
  Result := Length(S);
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

end.
