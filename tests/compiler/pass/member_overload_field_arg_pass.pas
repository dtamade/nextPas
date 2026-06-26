{$mode objfpc}{$H+}
program test_member_overload_field_arg_pass;

type
  TPickConfig = record
    Value: Integer;
  end;

  TOverloadProbe = class
  private
    FConfig: TPickConfig;
    function Pick(ASeed: Integer; AValue: Integer): Integer; overload;
    function Pick(ASeed: Integer; const AConfig: TPickConfig): Integer; overload;
  public
    constructor Create;
    function Run: Integer;
  end;

constructor TOverloadProbe.Create;
begin
  inherited Create;
  FConfig.Value := 41;
end;

function TOverloadProbe.Pick(ASeed: Integer; AValue: Integer): Integer;
begin
  Result := ASeed + AValue;
end;

function TOverloadProbe.Pick(ASeed: Integer; const AConfig: TPickConfig): Integer;
begin
  Result := ASeed - AConfig.Value;
end;

function TOverloadProbe.Run: Integer;
begin
  Result := Pick(1, FConfig.Value);
end;

var
  Probe: TOverloadProbe;
begin
  Probe := TOverloadProbe.Create;
  try
    if Probe.Run <> 42 then
      Halt(1);
  finally
    Probe.Free;
  end;

  WriteLn('member_overload_field_arg OK');
end.
