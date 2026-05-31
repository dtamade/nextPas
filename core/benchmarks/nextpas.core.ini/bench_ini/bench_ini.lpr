program bench_ini;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.ini;

type
  TBenchProc = procedure(AIterations: Int64);

var
  GSmallIni: string;
  GLargeIni: string;
  GReadIni: TIniFile;
  GSink: UInt64;

procedure EnsureCapacity(var ABuffer: string; var ALength, ACapacity: Integer; AAdditional: Integer);
var
  LRequired: Integer;
begin
  LRequired := ALength + AAdditional;
  if LRequired <= ACapacity then
    Exit;
  if ACapacity = 0 then
    ACapacity := 1024;
  while ACapacity < LRequired do
    ACapacity := ACapacity * 2;
  SetLength(ABuffer, ACapacity);
end;

procedure AppendString(var ABuffer: string; var ALength, ACapacity: Integer; const AText: string);
var
  LTextLen: Integer;
begin
  LTextLen := Length(AText);
  if LTextLen = 0 then
    Exit;
  EnsureCapacity(ABuffer, ALength, ACapacity, LTextLen);
  Move(AText[1], ABuffer[ALength + 1], LTextLen);
  Inc(ALength, LTextLen);
end;

function PadInt(AValue, AWidth: Integer): string;
begin
  Result := IntToStr(AValue);
  while Length(Result) < AWidth do
    Result := '0' + Result;
end;

function BuildIni(AKeyCount: Integer): string;
var
  LLen, LCap, LI: Integer;
  LBuffer: string;
begin
  LLen := 0;
  LCap := 0;
  LBuffer := '';
  AppendString(LBuffer, LLen, LCap, '[settings]' + #10);
  for LI := 0 to AKeyCount - 1 do
    AppendString(LBuffer, LLen, LCap,
      'key' + PadInt(LI, 3) + '=value_' + PadInt(LI, 6) + #10);
  SetLength(LBuffer, LLen);
  Result := LBuffer;
end;

procedure PrintHeader;
begin
  WriteLn('  操作名                              迭代次数        总耗时          ns/op');
end;

procedure PrintResult(const AName: string; AIterations: Int64; AElapsed: UInt64);
var
  LNsPerOp: Double;
begin
  if AIterations > 0 then
    LNsPerOp := Double(AElapsed) / Double(AIterations)
  else
    LNsPerOp := 0.0;
  WriteLn(Format('  %-32s %10d %12.3f ms %12.1f ns/op',
    [AName, AIterations, Double(AElapsed) / 1000000.0, LNsPerOp]));
end;

procedure RunBench(const AName: string; AIterations: Int64; AProc: TBenchProc);
var
  LStart, LFinish: UInt64;
begin
  AProc(2);
  LStart := platform_monotonic_ns;
  AProc(AIterations);
  LFinish := platform_monotonic_ns;
  PrintResult(AName, AIterations, LFinish - LStart);
end;

procedure BenchParseSmall(AIterations: Int64);
var
  LI: Int64;
  LIni: TIniFile;
begin
  for LI := 1 to AIterations do
  begin
      LIni := TIniFile.Create;
    try
      LIni.LoadFromString(GSmallIni);
      GSink := GSink xor UInt64(Length(LIni.ReadString('settings', 'key049', '')));
    finally
      LIni.Free;
    end;
  end;
end;

procedure BenchParseLarge(AIterations: Int64);
var
  LI: Int64;
  LIni: TIniFile;
begin
  for LI := 1 to AIterations do
  begin
    LIni := TIniFile.Create;
    try
      LIni.LoadFromString(GLargeIni);
      GSink := GSink xor UInt64(Length(LIni.ReadString('settings', 'key499', '')));
    finally
      LIni.Free;
    end;
  end;
end;

procedure BenchReadString(AIterations: Int64);
var
  LI: Int64;
  LValue: string;
begin
  for LI := 1 to AIterations do
  begin
    LValue := GReadIni.ReadString('settings', 'key499', '');
    GSink := GSink xor UInt64(Length(LValue));
  end;
end;

begin
  GSmallIni := BuildIni(50);
  GLargeIni := BuildIni(500);
  GReadIni := TIniFile.Create;
  try
    GReadIni.LoadFromString(GLargeIni);
    GSink := 0;

    WriteLn('=== nextpas.core.ini benchmark ===');
    WriteLn('  small INI bytes: ', Length(GSmallIni), ' (50 keys)');
    WriteLn('  large INI bytes: ', Length(GLargeIni), ' (500 keys)');
    PrintHeader;
    RunBench('ini parse 1KB / 50 keys', 5000, @BenchParseSmall);
    RunBench('ini parse 10KB / 500 keys', 1000, @BenchParseLarge);
    RunBench('ini ReadString key499', 100000, @BenchReadString);
    WriteLn('  sink=', GSink);
  finally
    GReadIni.Free;
  end;
end.
