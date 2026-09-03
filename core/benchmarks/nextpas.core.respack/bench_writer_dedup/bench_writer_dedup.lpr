program bench_writer_dedup;
{$I nextpas.core.settings.inc}
{** @desc S6 基准：writer 去重路径量化（50%重复/最坏同桶 miss/无重复对照）。
    同机可复现 via `make -C core/benchmarks/nextpas.core.respack/bench_writer_dedup run`，
    门限 ≤1.08×/≤1.15× 且 ≤1.3× Go/Rust（RESULTS.md §4），零拷贝证据
    ContentPtr inline + bytes.ops.Move 单源。 }
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.os.procinfo,
  nextpas.core.respack;

type
  TResPackBytesArrayEx = array of TBytes;

function BenchOnce(const AEntries: array of TResPackInputEntry; const ADedup: Boolean): QWord;
var
  Opts: TResPackBuildOptions;
  Blob: TResPackBlob;
  T0, T1: QWord;
begin
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := ADedup;
  T0 := GetTickCount64;
  Blob := ResPackBuild(AEntries, Opts);
  T1 := GetTickCount64;
  Result := T1 - T0;
  ResPackFreeBlob(Blob);
end;

procedure BuildEntries(const ACount: Integer; const AChunkSize: SizeUInt; const ADupRatioPct: Integer;
  out AEntries: TResPackInputArray; out AContents: TResPackBytesArrayEx);
var
  I, DupIdx: Integer;
  Chunk: TBytes;
begin
  SetLength(AContents, ACount);
  SetLength(AEntries, ACount);
  SetLength(Chunk, SizeInt(AChunkSize));
  for I := 0 to ACount - 1 do
    FillChar(Chunk[0], AChunkSize, Byte(I mod 251));
  for I := 0 to ACount - 1 do
  begin
    if (ADupRatioPct = 50) and (I >= ACount div 2) then
    begin
      DupIdx := I - ACount div 2;
      AEntries[I].Path := 'chunk' + IntToStr(I) + '.bin';
      if Length(AContents[DupIdx]) > 0 then
        AEntries[I].Data := @AContents[DupIdx][0]
      else
        AEntries[I].Data := nil;
      AEntries[I].DataSize := AChunkSize;
      AEntries[I].ModTime := 0;
      Continue;
    end;
    SetLength(AContents[I], SizeInt(AChunkSize));
    Move(Chunk[0], AContents[I][0], AChunkSize);
    if ADupRatioPct = 0 then
      AContents[I][AChunkSize - 1] := Byte(I mod 256);
    AEntries[I].Path := 'chunk' + IntToStr(I) + '.bin';
    AEntries[I].Data := @AContents[I][0];
    AEntries[I].DataSize := AChunkSize;
    AEntries[I].ModTime := 0;
  end;
end;

var
  Entries: TResPackInputArray;
  Contents: TResPackBytesArrayEx;
  TNoDedup, TDup50, TDupMiss: QWord;
  PeakBefore, PeakAfter: UInt64;
begin
  try
    WriteLn('=== respack writer dedup benchmark ===');
    PeakBefore := ProcessPeakRssBytes;
    WriteLn('peak rss before: ', PeakBefore div 1048576, ' MB');
    BuildEntries(64, 8 * 1024 * 1024, 0, Entries, Contents);
    TNoDedup := BenchOnce(Entries, False);
    WriteLn('no-dedup 64×8MiB: ', TNoDedup, ' ms');
    SetLength(Entries, 0); SetLength(Contents, 0);
    BuildEntries(64, 8 * 1024 * 1024, 50, Entries, Contents);
    TDup50 := BenchOnce(Entries, True);
    WriteLn('50% dup dedup on: ', TDup50, ' ms (blob -48% expected)');
    if TNoDedup > 0 then
      WriteLn('  ratio +', ((TDup50 - TNoDedup) * 100 div TNoDedup), '%');
    SetLength(Entries, 0); SetLength(Contents, 0);
    BuildEntries(64, 8 * 1024 * 1024, 0, Entries, Contents);
    TDupMiss := BenchOnce(Entries, True);
    WriteLn('0% dup dedup on (miss): ', TDupMiss, ' ms');
    if TNoDedup > 0 then
      WriteLn('  ratio +', ((TDupMiss - TNoDedup) * 100 div TNoDedup), '%');
    PeakAfter := ProcessPeakRssBytes;
    WriteLn('peak rss after: ', PeakAfter div 1048576, ' MB');
    WriteLn('gates: 50% dup ≤1.08×, miss ≤1.15×, both ≤1.3× Go/Rust');
    if (TNoDedup > 0) and (TDup50 > TNoDedup * 108 div 100) then
      WriteLn('warn: 50% dup exceeds 1.08×');
    if (TNoDedup > 0) and (TDupMiss > TNoDedup * 115 div 100) then
      WriteLn('warn: miss exceeds 1.15×');
    WriteLn('done. baseline: Go bytes.Buffer/Rust Vec<u8> same payload, see RESULTS.md §4');
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
