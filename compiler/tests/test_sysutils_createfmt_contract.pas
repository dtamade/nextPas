program test_sysutils_createfmt_contract;

{$mode objfpc}{$H+}

uses
  SysUtils;

var
  ExceptionClass: ExceptClass;
  E: Exception;
  Formatted: string;
begin
  Formatted := Format('value=%d text=%s', [42, 'nextpas']);
  if Formatted <> 'value=42 text=nextpas' then
    Halt(1);

  E := Exception.CreateFmt('value=%d text=%s', [42, 'nextpas']);
  try
    if E.Message <> 'value=42 text=nextpas' then
      Halt(2);
  finally
    E.Free;
  end;

  ExceptionClass := EAssertionFailed;
  E := ExceptionClass.CreateFmt('value=%d text=%s', [42, 'nextpas']);
  try
    if not (E is EAssertionFailed) then
      Halt(3);
    if E.Message <> 'value=42 text=nextpas' then
      Halt(4);
  finally
    E.Free;
  end;
end.
