program bench_io;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.base,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.io.base, nextpas.core.io.intf,
  nextpas.core.io.memory, nextpas.core.io.buffer, nextpas.core.io.util,
  nextpas.core.fs;
var GSink: UInt64;
procedure BenchCopy64KB(const ACtx: IBenchContext);
var LSrc, LDst: IStream; LData: TBytes; LI: Integer; LN: Int64;
begin
  SetLength(LData, 65536); for LI := 0 to 65535 do LData[LI] := Byte(LI and $FF);
  LSrc := CreateBytesStreamFrom(LData); LDst := CreateBytesStream(65536);
  LN := IoCopy(LDst as IWriter, LSrc);
  ACtx.SetBytes(LN); GSink := GSink xor UInt64(LN);
end;
procedure BenchBufferedReader64KB(const ACtx: IBenchContext);
var LSrc: IStream; LR: IReader; LData: TBytes; LBuf: array[0..4095] of Byte; LI: Integer; LN: SizeUInt;
begin
  SetLength(LData, 65536); for LI := 0 to 65535 do LData[LI] := Byte(LI and $FF);
  LSrc := CreateBytesStreamFrom(LData); LR := CreateBufferedReader(LSrc, 4096);
  repeat LN := LR.Read(LBuf[0], 4096); GSink := GSink xor UInt64(LN); until LN = 0;
  ACtx.SetBytes(65536);
end;
procedure BenchBufferedWriter64KB(const ACtx: IBenchContext);
var LDst: IStream; LW: IWriter; LData: array[0..4095] of Byte; LI: Integer; LRem: SizeUInt;
begin
  for LI := 0 to 4095 do LData[LI] := Byte(LI and $FF);
  LDst := CreateBytesStream(65536); LW := CreateBufferedWriter(LDst as IWriter, 4096);
  LRem := 65536;
  while LRem > 0 do begin if LRem > 4096 then LW.Write(LData[0], 4096) else LW.Write(LData[0], LRem); Dec(LRem, 4096); end;
  ACtx.SetBytes(65536);
end;
var LResults: IBenchResults;
begin
  GSink := 0;
  LResults := TBenchSuite.Create('io')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Copy/64KB', @BenchCopy64KB).Add('BufReader/64KB', @BenchBufferedReader64KB).Add('BufWriter/64KB', @BenchBufferedWriter64KB)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-io.json');
end.
