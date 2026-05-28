unit nextpas.core.platform.args;

{$I nextpas.core.settings.inc}

interface

function platform_args_count: Int32;
function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_args_exe_path(ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
{$ENDIF}

function platform_args_count: Int32;
begin
  Result := System.ParamCount;
end;

function platform_args_get(AIndex: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  S: string;
  L, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if (AIndex < 0) or (AIndex > System.ParamCount) then
  begin
    ABuf[0] := #0;
    Exit(-1);
  end;
  S := System.ParamStr(AIndex);
  L := Length(S);
  if L >= ABufLen then
    L := ABufLen - 1;
  for I := 1 to L do
    ABuf[I - 1] := S[I];
  ABuf[L] := #0;
  Result := Length(S);
end;

function platform_args_exe_path(ABuf: PAnsiChar; ABufLen: Int32): Int32;
{$IFDEF NEXTPAS_LINUX}
var
  L: PtrInt;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  L := readlink('/proc/self/exe', ABuf, ABufLen - 1);
  if L < 0 then
    Exit(Int32(platform_get_errno));
  ABuf[L] := #0;
  Result := Int32(L);
end;
{$ELSE}
begin
  Result := platform_args_get(0, ABuf, ABufLen);
end;
{$ENDIF}

end.
