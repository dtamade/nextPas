program bench_next_vorbis;

{ nextpas.core.audio Vorbis bench — mirrors bench_vorbisdec.lpr
  Two fixtures, BATCH 7×8, FNV over f32 PCM. }

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.vorbis.decoder;

{$ifdef unix}
{$linklib m}
{$endif}

const
  FixtureStereo = '/home/dtamade/projects/music888/tests/fixtures/tone_stereo_44k1.ogg';
  FixtureMono   = '/home/dtamade/projects/music888/tests/fixtures/tone_mono_44k1.ogg';
{$ifdef BENCH_QEMU_SHORT}
  BATCH_COUNT = 3;
  BATCH_SIZE = 5;
  WARMUP_RUNS = 1;
{$else}
  BATCH_COUNT = 7;
  BATCH_SIZE = 8;
  WARMUP_RUNS = 3;
{$endif}

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

function LoadFileBytes(const Path: AnsiString; out Data: TBytes): Boolean;
var
  F: File;
  Sz: LongInt;
begin
  Result := False;
  Assign(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  Sz := FileSize(F);
  SetLength(Data, Sz);
  if Sz > 0 then BlockRead(F, Data[0], Sz);
  Close(F);
  Result := True;
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

var
  GDataStereo, GDataMono: TBytes;

function DecodeOnce(const FileName: AnsiString; out NSamples: LongInt): QWord;
var
  Data: TBytes;
  Buf: TAudioBuffer;
  H: QWord;
begin
  if FileName = FixtureStereo then Data := GDataStereo
  else if FileName = FixtureMono then Data := GDataMono
  else
  begin
    if not LoadFileBytes(FileName, Data) then
    begin
      WriteLn('FAIL(load): ', FileName);
      Halt(1);
    end;
  end;
  // raw vs wrapper distinction: raw VorbisDecodeBytes hashes PCM bytes; wrapper would go via IStream+DecodeWhole – keep aligned to music888 baseline
  Buf := VorbisDecodeBytes(Data);
  NSamples := Buf.FrameCount;
  H := FnvaInit;
  if Length(Buf.Data) > 0 then FnvaFeed(H, Buf.Data[0], Length(Buf.Data));
  Result := H;
end;

function BenchFixture(const Tag, FileName: AnsiString): Boolean;
var
  NSamples: LongInt;
  H: QWord;
  B, R: LongInt;
  T0, T1: UInt64;
  BatchMs: array[0..BATCH_COUNT - 1] of UInt64;
  TotalMs, BestMs, PerDecUsMin: UInt64;
  MeanMs: Double;
begin
  Result := True;
  H := DecodeOnce(FileName, NSamples);
  for R := 1 to WARMUP_RUNS do DecodeOnce(FileName, NSamples);
  for B := 0 to BATCH_COUNT - 1 do
  begin
    T0 := GetTickCount64;
    for R := 1 to BATCH_SIZE do H := DecodeOnce(FileName, NSamples);
    T1 := GetTickCount64;
    BatchMs[B] := T1 - T0;
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
  WriteLn(Tag, ': samples=', NSamples);
  WriteLn(Tag, ': avg ', MeanMs:0:2, ' ms/dec  best~', PerDecUsMin, ' us/dec hash=', IntToHex(H, 16));
end;

var
  Ok1, Ok2: Boolean;
begin
  if not LoadFileBytes(FixtureStereo, GDataStereo) then begin WriteLn('FAIL preload stereo'); Halt(1); end;
  if not LoadFileBytes(FixtureMono, GDataMono) then begin WriteLn('FAIL preload mono'); Halt(1); end;
  WriteLn('== nextpas vorbis decode bench ==');
  WriteLn('build: ', BuildTag, '  batches=', BATCH_COUNT, 'x', BATCH_SIZE, ' warmup=', WARMUP_RUNS);
  Ok1 := BenchFixture('stereo', FixtureStereo);
  Ok2 := BenchFixture('mono', FixtureMono);
  if (not Ok1) or (not Ok2) then
  begin
    WriteLn('RESULT: REFUSED');
    Halt(1);
  end;
  WriteLn('RESULT: BENCH-OK');
end.
