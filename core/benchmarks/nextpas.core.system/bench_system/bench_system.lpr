program bench_system;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.system.classes.impl,
  Classes,
  SysUtils;

const
  N_LIST = 100000;
  N_STR  = 10000;
  N_TXT  = 1000;
  MEM_1MB = 1024 * 1024;

var
  LResults: IBenchResults;
  GSink: Int64;
  GStr: string;

procedure BenchNpTListAdd(aIters: Int64);
var it: Int64; i: Integer; L: nextpas.core.system.classes.impl.TList;
begin
  for it := 1 to aIters do
  begin
    L := nextpas.core.system.classes.impl.TList.Create;
    for i := 0 to N_LIST - 1 do
      L.Add(Pointer(PtrInt(i)));
    GSink := GSink + L.Count;
    L.Free;
  end;
end;

procedure BenchFpcTListAdd(aIters: Int64);
var it: Int64; i: Integer; L: Classes.TList;
begin
  for it := 1 to aIters do
  begin
    L := Classes.TList.Create;
    for i := 0 to N_LIST - 1 do
      L.Add(Pointer(PtrInt(i)));
    GSink := GSink + L.Count;
    L.Free;
  end;
end;

procedure BenchNpTStringListAdd(aIters: Int64);
var it: Int64; i: Integer; L: nextpas.core.system.classes.impl.TStringList;
begin
  for it := 1 to aIters do
  begin
    L := nextpas.core.system.classes.impl.TStringList.Create;
    for i := 0 to N_STR - 1 do
      L.Add('item' + IntToStr(i));
    GSink := GSink + L.Count;
    L.Free;
  end;
end;

procedure BenchFpcTStringListAdd(aIters: Int64);
var it: Int64; i: Integer; L: Classes.TStringList;
begin
  for it := 1 to aIters do
  begin
    L := Classes.TStringList.Create;
    for i := 0 to N_STR - 1 do
      L.Add('item' + IntToStr(i));
    GSink := GSink + L.Count;
    L.Free;
  end;
end;

procedure BenchNpGetText(aIters: Int64);
var it: Int64; i: Integer; L: nextpas.core.system.classes.impl.TStringList;
begin
  L := nextpas.core.system.classes.impl.TStringList.Create;
  for i := 0 to N_TXT - 1 do L.Add('line' + IntToStr(i) + '_data_payload');
  for it := 1 to aIters do
    GStr := L.Text;
  GSink := GSink + Length(GStr);
  L.Free;
end;

procedure BenchFpcGetText(aIters: Int64);
var it: Int64; i: Integer; L: Classes.TStringList;
begin
  L := Classes.TStringList.Create;
  for i := 0 to N_TXT - 1 do L.Add('line' + IntToStr(i) + '_data_payload');
  for it := 1 to aIters do
    GStr := L.Text;
  GSink := GSink + Length(GStr);
  L.Free;
end;

procedure BenchNpDelimitedText(aIters: Int64);
var it: Int64; i: Integer; L: nextpas.core.system.classes.impl.TStringList;
begin
  L := nextpas.core.system.classes.impl.TStringList.Create;
  L.Delimiter := ','; L.QuoteChar := '"';
  for i := 0 to N_TXT - 1 do L.Add('val' + IntToStr(i));
  for it := 1 to aIters do
    GStr := L.DelimitedText;
  GSink := GSink + Length(GStr);
  L.Free;
end;

procedure BenchFpcDelimitedText(aIters: Int64);
var it: Int64; i: Integer; L: Classes.TStringList;
begin
  L := Classes.TStringList.Create;
  L.Delimiter := ','; L.QuoteChar := '"';
  for i := 0 to N_TXT - 1 do L.Add('val' + IntToStr(i));
  for it := 1 to aIters do
    GStr := L.DelimitedText;
  GSink := GSink + Length(GStr);
  L.Free;
end;

procedure BenchNpMemoryStream(aIters: Int64);
var it: Int64; i: Integer; MS: nextpas.core.system.classes.impl.TMemoryStream; Buf: array[0..4095] of Byte;
begin
  for i := 0 to 4095 do Buf[i] := Byte(i);
  for it := 1 to aIters do
  begin
    MS := nextpas.core.system.classes.impl.TMemoryStream.Create;
    i := 0;
    while MS.Size < MEM_1MB do
    begin
      MS.Write(Buf[0], 4096);
      Inc(i);
    end;
    GSink := GSink + MS.Size;
    MS.Free;
  end;
end;

procedure BenchFpcMemoryStream(aIters: Int64);
var it: Int64; i: Integer; MS: Classes.TMemoryStream; Buf: array[0..4095] of Byte;
begin
  for i := 0 to 4095 do Buf[i] := Byte(i);
  for it := 1 to aIters do
  begin
    MS := Classes.TMemoryStream.Create;
    i := 0;
    while MS.Size < MEM_1MB do
    begin
      MS.Write(Buf[0], 4096);
      Inc(i);
    end;
    GSink := GSink + MS.Size;
    MS.Free;
  end;
end;

begin
  WriteLn('=== nextpas.core.system vs FPC RTL (N_LIST=', N_LIST, ' N_STR=', N_STR, ' N_TXT=', N_TXT, ') ===');
  WriteLn;
  // perf: compare nextPas system shim (bytes.ops single source, zero-copy, amortized O(1)) vs FPC RTL baseline
  LResults := TBenchSuite.Create('system')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(80))
    .SetMinSamples(5)
    .AddLoop('system/TList.Add/N=100000/nextPas', @BenchNpTListAdd)
    .AddLoop('system/TList.Add/N=100000/FPC', @BenchFpcTListAdd)
    .AddLoop('system/TStringList.Add/N=10000/nextPas', @BenchNpTStringListAdd)
    .AddLoop('system/TStringList.Add/N=10000/FPC', @BenchFpcTStringListAdd)
    .AddLoop('system/TStringList.Text/N=1000/nextPas', @BenchNpGetText)
    .AddLoop('system/TStringList.Text/N=1000/FPC', @BenchFpcGetText)
    .AddLoop('system/TStringList.DelimitedText/N=1000/nextPas', @BenchNpDelimitedText)
    .AddLoop('system/TStringList.DelimitedText/N=1000/FPC', @BenchFpcDelimitedText)
    .AddLoop('system/TMemoryStream.Write1MB/nextPas', @BenchNpMemoryStream)
    .AddLoop('system/TMemoryStream.Write1MB/FPC', @BenchFpcMemoryStream)
    .Run;
  WriteLn(LResults.PrintToConsole);
  // stability: GSink prevents dead-code elimination
  if GSink = -1 then WriteLn(GSink);
  if Length(GStr) = 0 then WriteLn('empty');
end.
