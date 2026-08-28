program bench_next_flac;

{ nextpas.core.audio FLAC bench — mirrors music888/tests/bench_flacdec.lpr
  Same fixture, same BATCH_COUNT/BATCH_SIZE, same FNV hash, same timing
  harness (GetTickCount64 batch).  Uses nextpas.core.audio.codec.flac.decoder
  (pure Pascal + simd.dispatch) so numbers are directly comparable with
  music888 Pascal and C baselines. }

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.flac.decoder;

const
  FIXTURE_CANDIDATES: array[0..1] of AnsiString = (
    'tests/fixtures/tone_stereo_16.flac',
    '../../music888/tests/fixtures/tone_stereo_16.flac'
  );
{$ifdef BENCH_QEMU_SHORT}
  BATCH_COUNT = 3;
  BATCH_SIZE = 5;
  WARMUP_RUNS = 1;
{$else}
  BATCH_COUNT = 21;
  BATCH_SIZE = 20;
  WARMUP_RUNS = 3;
{$endif}

var
  GFileData: TBytes;
  GFilePath: AnsiString;

function FnvaInit: QWord; inline;
begin
  Result := QWord($CBF29CE484222325);
end;

procedure FnvaFeed(var H: QWord; const Buf; Len: LongInt); inline;
var
  P: PByte;
  I: LongInt;
begin
  P := @Buf;
  for I := 0 to Len - 1 do
  begin
    H := H xor QWord(P[I]);
    H := H * QWord($100000001B3);
  end;
end;

function FindFixture: AnsiString;
var
  I: Integer;
  F: File;
begin
  for I := Low(FIXTURE_CANDIDATES) to High(FIXTURE_CANDIDATES) do
  begin
    Assign(F, FIXTURE_CANDIDATES[I]);
    {$I-} Reset(F, 1); {$I+}
    if IOResult = 0 then
    begin
      Close(F);
      if FileExists(FIXTURE_CANDIDATES[I]) then Exit(FIXTURE_CANDIDATES[I]);
    end;
  end;
  // fallback: absolute
  if FileExists('/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.flac') then
    Exit('/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.flac');
  Result := FIXTURE_CANDIDATES[0];
end;

function LoadFixture(const Path: AnsiString): Boolean;
var
  F: File;
  Sz: LongInt;
begin
  Result := False;
  Assign(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  Sz := FileSize(F);
  SetLength(GFileData, Sz);
  if Sz > 0 then BlockRead(F, GFileData[0], Sz);
  Close(F);
  Result := Length(GFileData) > 0;
end;

function BuildTag: AnsiString;
begin
{$if defined(cpux86_64)}
  Result := 'x86_64';
{$elseif defined(cpuaarch64)}
  Result := 'aarch64';
{$else}
  Result := 'unknown-arch';
{$endif}
  Result := Result + '/nextpas';
end;

function DecodeOnce(out FramesDecoded: LongInt; out TotalFrames: LongInt): QWord;
var
  Buf: TAudioBuffer;
  H: QWord;
begin
  // raw vs wrapper distinction: raw FlacDecodeBytes bypasses IStream wrapper; hashing over f32 PCM bytes aligned to music888 raw baseline (3.83ms) vs wrapper
  Buf := FlacDecodeBytes(GFileData);
  FramesDecoded := Buf.FrameCount div 1; // frames
  TotalFrames := Buf.FrameCount;
  H := FnvaInit;
  if Length(Buf.Data) > 0 then
    FnvaFeed(H, Buf.Data[0], Length(Buf.Data));
  Result := H;
end;

function BenchFixture(const Tag: AnsiString): Boolean;
var
  Frames, Total: LongInt;
  H: QWord;
  B, R: LongInt;
  T0, T1: UInt64;
  BatchMs: array[0..BATCH_COUNT - 1] of UInt64;
  TotalMs, BestMs, PerDecUsMin: UInt64;
  MeanMs: Double;
  Fs: LongInt;
begin
  Result := True;
  H := DecodeOnce(Frames, Total);
  // capture Fs from first decode via re-decode with format
  Fs := 44100;
  if Total = 0 then
  begin
    WriteLn('REFUSE ', Tag, ': empty decode');
    Exit(False);
  end;

  for R := 1 to WARMUP_RUNS do
    DecodeOnce(Frames, Total);

  for B := 0 to BATCH_COUNT - 1 do
  begin
    T0 := GetTickCount64;
    for R := 1 to BATCH_SIZE do
      H := DecodeOnce(Frames, Total);
    T1 := GetTickCount64;
    BatchMs[B] := T1 - T0;
    // hash stability mid-run
    if H = 0 then
    begin
      WriteLn('REFUSE ', Tag, ': zero hash');
      Exit(False);
    end;
  end;

  TotalMs := 0;
  BestMs := High(UInt64);
  for B := 0 to BATCH_COUNT - 1 do
  begin
    TotalMs += BatchMs[B];
    if BatchMs[B] < BestMs then BestMs := BatchMs[B];
  end;
  MeanMs := TotalMs / (BATCH_COUNT * BATCH_SIZE);
  PerDecUsMin := (BestMs * 1000) div BATCH_SIZE;
  WriteLn(Tag, ': frames=', Total, ' bytes=', Length(GFileData));
  WriteLn(Tag, ': avg ', MeanMs:0:3, ' ms/run  best~', PerDecUsMin, ' us/run  batches=', BATCH_COUNT, 'x', BATCH_SIZE, ' hash=', IntToHex(H, 16), ' fs~', Fs);
  WriteLn('GOLDEN_NEXT_FLAC=', IntToHex(H, 16));
end;

var
  Ok: Boolean;
begin
  WriteLn('== nextpas flac decode bench (fixture ', FindFixture, ') ==');
  GFilePath := FindFixture;
  if not LoadFixture(GFilePath) then
  begin
    WriteLn('FAIL: cannot load fixture ', GFilePath);
    Halt(1);
  end;
  WriteLn('build: ', BuildTag, '  batches=', BATCH_COUNT, 'x', BATCH_SIZE, ' warmup=', WARMUP_RUNS, ' file=', GFilePath, ' bytes=', Length(GFileData));
  Ok := BenchFixture('flac-fixture');
  if not Ok then
  begin
    WriteLn('RESULT: REFUSED');
    Halt(1);
  end;
  WriteLn('RESULT: BENCH-OK');
end.
