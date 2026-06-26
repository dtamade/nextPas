{$mode objfpc}{$H+}
program test_constructor_alias_overload_pass;

uses
  constructor_alias_overload_support;

type
  TProbeConfig = record
    MinShift: Integer;
  end;

  TProbe = class
  private
    FConfig: TProbeConfig;
  public
    constructor Create(ACapacity: Integer; AAllocator: IAllocator; AMinShift: Integer); overload;
    constructor Create(ACapacity: Integer; const AConfig: TProbeConfig; AAllocator: IAllocator); overload;
    function Value: Integer;
  end;

constructor TProbe.Create(ACapacity: Integer; AAllocator: IAllocator; AMinShift: Integer);
begin
  inherited Create;
  FConfig.MinShift := AMinShift + ACapacity;
end;

constructor TProbe.Create(ACapacity: Integer; const AConfig: TProbeConfig; AAllocator: IAllocator);
begin
  FConfig := AConfig;
  Create(ACapacity, AAllocator, FConfig.MinShift);
end;

function TProbe.Value: Integer;
begin
  Result := FConfig.MinShift;
end;

var
  Allocator: IAllocator;
  Config: TProbeConfig;
  Probe: TProbe;
begin
  Config.MinShift := 5;
  Allocator := nil;
  Probe := TProbe.Create(7, Config, Allocator);
  try
    if Probe.Value <> 12 then
      Halt(1);
  finally
    Probe.Free;
  end;

  WriteLn('constructor_alias_overload OK');
end.
