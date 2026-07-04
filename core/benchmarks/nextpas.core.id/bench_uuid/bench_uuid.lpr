program bench_uuid;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.id.uuid;
var GParseInput: string; GFormatInput: TUuid;
procedure InitData;
begin GParseInput := '550e8400-e29b-41d4-a716-446655440000'; GFormatInput := TUuid.NewV4; end;
procedure BenchNewV4(const ACtx: IBenchContext); var LU: TUuid; begin LU := TUuid.NewV4; end;
procedure BenchNewV7(const ACtx: IBenchContext); var LU: TUuid; begin LU := TUuid.NewV7; end;
procedure BenchUuidV4Str(const ACtx: IBenchContext); var LS: string; begin LS := UuidV4; end;
procedure BenchUuidV7Str(const ACtx: IBenchContext); var LS: string; begin LS := UuidV7; end;
procedure BenchParse(const ACtx: IBenchContext); var LU: TUuid; begin LU := TUuid.Parse(GParseInput); end;
procedure BenchToString(const ACtx: IBenchContext); var LS: string; begin LS := GFormatInput.ToString; end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('uuid');
  LSuite
    .Add('NewV4', @BenchNewV4).Add('NewV7', @BenchNewV7)
    .Add('UuidV4 (string)', @BenchUuidV4Str).Add('UuidV7 (string)', @BenchUuidV7Str)
    .Add('Parse', @BenchParse).Add('ToString', @BenchToString);
  WriteLn(LSuite.Run.PrintToConsole);
end.
