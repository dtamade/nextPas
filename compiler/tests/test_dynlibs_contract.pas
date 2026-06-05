program test_dynlibs_contract;

{$mode objfpc}{$H+}

uses
  Dynlibs;

var
  LibHandle: TLibHandle;
begin
  LibHandle := LoadLibrary('libc.so.6');
  if LibHandle = NilHandle then
    Halt(1);
  try
    if GetProcedureAddress(LibHandle, 'getenv') = nil then
      Halt(2);
  finally
    if not FreeLibrary(LibHandle) then
      Halt(3);
  end;
end.
