program bench_io;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer,
  nextpas.core.io.util;

procedure Bench(const AName: string; const ABytes: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LMBps: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
    LMBps := (ABytes / (1024.0 * 1024.0)) / (LNs / 1000000000.0)
  else
    LMBps := 0;
  WriteLn(Format('  %-30s %10d bytes  %8.2f ms  %8.1f MB/s',
    [AName, ABytes, LNs / 1000000.0, LMBps]));
end;

procedure BenchCopy(const ASize: SizeUInt);
var
  LSrc, LDst: IStream;
  LData: TBytes;
  LI: Integer;
  LStart: TInstant;
  LN: Int64;
begin
  SetLength(LData, ASize);
  for LI := 0 to ASize - 1 do
    LData[LI] := Byte(LI and $FF);
  LSrc := CreateBytesStreamFrom(LData);
  LDst := CreateBytesStream(ASize);
  LStart := TInstant.Now;
  LN := IoCopy(LDst as IWriter, LSrc);
  Bench(Format('Copy %dKB', [ASize div 1024]), LN, LStart.Elapsed);
end;

procedure BenchBufferedReader(const ASize: SizeUInt);
var
  LSrc: IStream;
  LR: IReader;
  LData: TBytes;
  LBuf: array[0..4095] of Byte;
  LI: Integer;
  LStart: TInstant;
  LTotal: Int64;
  LN: SizeUInt;
begin
  SetLength(LData, ASize);
  for LI := 0 to ASize - 1 do
    LData[LI] := Byte(LI and $FF);
  LSrc := CreateBytesStreamFrom(LData);
  LR := CreateBufferedReader(LSrc, 4096);
  LTotal := 0;
  LStart := TInstant.Now;
  repeat
    LN := LR.Read(LBuf[0], 4096);
    Inc(LTotal, LN);
  until LN = 0;
  Bench(Format('BufReader 4KB read %dKB', [ASize div 1024]), LTotal, LStart.Elapsed);
end;

procedure BenchBufferedWriter(const ASize: SizeUInt);
var
  LDst: IStream;
  LW: IWriter;
  LData: array[0..4095] of Byte;
  LI: Integer;
  LStart: TInstant;
  LTotal: Int64;
  LRemaining: SizeUInt;
begin
  for LI := 0 to 4095 do
    LData[LI] := Byte(LI and $FF);
  LDst := CreateBytesStream(ASize);
  LW := CreateBufferedWriter(LDst as IWriter, 4096);
  LTotal := 0;
  LRemaining := ASize;
  LStart := TInstant.Now;
  while LRemaining > 0 do
  begin
    if LRemaining >= 4096 then
    begin
      LW.Write(LData[0], 4096);
      Dec(LRemaining, 4096);
      Inc(LTotal, 4096);
    end
    else
    begin
      LW.Write(LData[0], LRemaining);
      Inc(LTotal, LRemaining);
      LRemaining := 0;
    end;
  end;
  (LW as IFlusher).Flush;
  Bench(Format('BufWriter 4KB write %dKB', [ASize div 1024]), LTotal, LStart.Elapsed);
end;

procedure BenchReadAll(const ASize: SizeUInt);
var
  LSrc: IStream;
  LData: TBytes;
  LI: Integer;
  LStart: TInstant;
  LResult: TBytes;
begin
  SetLength(LData, ASize);
  for LI := 0 to ASize - 1 do
    LData[LI] := Byte(LI and $FF);
  LSrc := CreateBytesStreamFrom(LData);
  LStart := TInstant.Now;
  LResult := IoReadAll(LSrc);
  Bench(Format('ReadAll %dKB', [ASize div 1024]), Length(LResult), LStart.Elapsed);
end;

begin
  WriteLn('=== nextpas.core.io benchmarks ===');
  WriteLn('');

  BenchCopy(1024 * 1024);
  BenchCopy(10 * 1024 * 1024);

  BenchBufferedReader(1024 * 1024);
  BenchBufferedReader(10 * 1024 * 1024);

  BenchBufferedWriter(1024 * 1024);
  BenchBufferedWriter(10 * 1024 * 1024);

  BenchReadAll(1024 * 1024);
  BenchReadAll(10 * 1024 * 1024);

  WriteLn('');
  WriteLn('Done.');
end.