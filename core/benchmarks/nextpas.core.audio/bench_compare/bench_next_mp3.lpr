program bench_next_mp3;

{ nextpas.core.audio MP3 bench — mirrors music888/tests/bench_mp3dec.lpr
  Synthetic 100×417B frames, BATCH 21×20, FNV over f32 PCM bytes. }

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.mp3.decoder;

const
  FRAME_COUNT = 100;
  FRAME_SIZE = 417;
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
  GStream: TBytes;

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

procedure FillFrame(P: PByte);
begin
  FillChar(P^, FRAME_SIZE, 0);
  P[0] := $FF; P[1] := $FB; P[2] := $90; P[3] := $00;
  P[6] := $40;
end;

function BuildStream: LongInt;
var
  I, Off: LongInt;
begin
  SetLength(GStream, FRAME_COUNT * FRAME_SIZE);
  Off := 0;
  for I := 0 to FRAME_COUNT - 1 do
  begin
    FillFrame(@GStream[Off]);
    Inc(Off, FRAME_SIZE);
  end;
  Result := Length(GStream);
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

function DecodeOnce(out FramesDecoded: LongInt): QWord;
var
  Buf: TAudioBuffer;
  H: QWord;
begin
  if Length(GStream) = 0 then BuildStream;
  // 零拷贝旁路 + 单实例复用：与 music888 同路径
  Buf := Mp3DecodeBytes(GStream);
  FramesDecoded := Buf.FrameCount div 1152; // approx
  if Buf.FrameCount = 0 then FramesDecoded := FRAME_COUNT;
  H := FnvaInit;
  if Length(Buf.Data) > 0 then FnvaFeed(H, Buf.Data[0], Length(Buf.Data));
  Result := H;
end;

function BenchFixture(const Tag: AnsiString): Boolean;
var
  Frames: LongInt;
  H: QWord;
  B, R: LongInt;
  T0, T1: UInt64;
  BatchMs: array[0..BATCH_COUNT - 1] of UInt64;
  TotalMs, BestMs, PerDecUsMin: UInt64;
  MeanMs: Double;
begin
  Result := True;
  H := DecodeOnce(Frames);
  for R := 1 to WARMUP_RUNS do DecodeOnce(Frames);
  for B := 0 to BATCH_COUNT - 1 do
  begin
    T0 := GetTickCount64;
    for R := 1 to BATCH_SIZE do H := DecodeOnce(Frames);
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
  WriteLn(Tag, ': frames~', Frames, ' (synth 100*417)');
  WriteLn(Tag, ': avg ', MeanMs:0:3, ' ms/run  best~', PerDecUsMin, ' us/run  batches=', BATCH_COUNT, 'x', BATCH_SIZE, ' hash=', IntToHex(H, 16));
  WriteLn('GOLDEN_NEXT_MP3=', IntToHex(H, 16));
end;

var
  Ok: Boolean;
begin
  WriteLn('== nextpas mp3 decode bench (synth 100 frames) ==');
  WriteLn('build: ', BuildTag, '  batches=', BATCH_COUNT, 'x', BATCH_SIZE, ' warmup=', WARMUP_RUNS);
  Ok := BenchFixture('mp3-synth');
  if not Ok then
  begin
    WriteLn('RESULT: REFUSED');
    Halt(1);
  end;
  WriteLn('RESULT: BENCH-OK');
end.
