program bench_number_ops;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.base, nextpas.core.text, nextpas.core.text.conv;
var GSink: UInt64;
procedure BenchInt64ToStr(const ACtx: IBenchContext);
var LS: string;
begin LS := IntToStr(-1234567890123456789); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchUInt64ToStr(const ACtx: IBenchContext);
var LS: string;
begin LS := UIntToStr(High(UInt64)); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchHexStr64(const ACtx: IBenchContext);
var LS: string;
begin LS := HexStr(UInt64($DEADBEEFCAFEBABE), 16); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchStrToInt64(const ACtx: IBenchContext);
var LV: Int64;
begin LV := StrToInt('-1234567890123456789'); GSink := GSink xor UInt64(LV); end;
procedure BenchStrToFloat(const ACtx: IBenchContext);
var LV: Double;
begin LV := StrToFloat('1234567.89012345'); GSink := GSink xor UInt64(PUInt64(@LV)^); end;
procedure BenchFloatToStr(const ACtx: IBenchContext);
var LS: string;
begin LS := FloatToStr(1234567.89012345); GSink := GSink xor UInt64(Length(LS)); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('number-ops');
  LSuite.Add('Int64ToStr', @BenchInt64ToStr).Add('UInt64ToStr', @BenchUInt64ToStr).Add('HexStr64', @BenchHexStr64)
    .Add('StrToInt64', @BenchStrToInt64).Add('StrToFloat', @BenchStrToFloat).Add('FloatToStr', @BenchFloatToStr);
  WriteLn(LSuite.Run.PrintToConsole);
end.
