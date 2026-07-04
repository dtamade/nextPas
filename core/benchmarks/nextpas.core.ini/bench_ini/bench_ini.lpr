program bench_ini;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.ini;
var GSmallIni: string; GLargeIni: string; GReadIni: TIniFile; GSink: UInt64;
function BuildIni(AKeyCount: Integer): string;
var LLen, LCap, LI: Integer; LBuffer: string;
begin
  LLen := 0; LCap := 0; LBuffer := '';
  for LI := 0 to AKeyCount - 1 do begin
    if LLen + 40 > LCap then begin if LCap = 0 then LCap := 4096 else LCap := LCap * 2; SetLength(LBuffer, LCap); end;
    LLen := LLen + FormatBuf(LBuffer[LLen + 1], '[settings]'#10'key%0:3d=value_%0:6d'#10, [LI, LI]);
  end;
  SetLength(LBuffer, LLen); Result := LBuffer;
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LIni: TIniFile;
begin LIni := TIniFile.Create(GSmallIni); GSink := GSink xor UInt64(LIni.Count); LIni.Free; end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LIni: TIniFile;
begin LIni := TIniFile.Create(GLargeIni); GSink := GSink xor UInt64(LIni.Count); LIni.Free; end;
procedure BenchReadString(const ACtx: IBenchContext);
var LVal: string;
begin LVal := GReadIni.ReadString('settings', 'key050000', ''); GSink := GSink xor UInt64(Length(LVal)); end;
var LSuite: IBenchSuite;
begin
  GSmallIni := BuildIni(50); GLargeIni := BuildIni(500);
  GReadIni := TIniFile.Create(BuildIni(100000));
  LSuite := TBenchSuite.Create('ini');
  LSuite.Add('Parse/small', @BenchParseSmall).Add('Parse/large', @BenchParseLarge).Add('ReadString', @BenchReadString);
  WriteLn(LSuite.Run.PrintToConsole);
  GReadIni.Free;
end.
