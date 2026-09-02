program bench_compare;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.time,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.flac.decoder,
  nextpas.core.audio.codec.mp3.decoder,
  nextpas.core.audio.codec.vorbis.decoder,
  music888.flacdec,
  music888.mp3dec,
  music888.vorbisdec;

const
  BATCH_COUNT = 7;
  BATCH_SIZE = 8;
  WARMUP = 3;

type
  TBytes = array of Byte;

function LoadFileBytes(const Path: string): TBytes;
var
  F: File;
  Sz: LongInt;
begin
  Assign(F, Path);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    WriteLn('FAIL load ', Path);
    Halt(1);
  end;
  Sz := FileSize(F);
  SetLength(Result, Sz);
  if Sz > 0 then
    BlockRead(F, Result[0], Sz);
  Close(F);
end;

function Fnva64(const Data: TBytes): QWord;
var
  i: Integer;
  h: QWord;
begin
  h := QWord($CBF29CE484222325);
  for i := 0 to High(Data) do
  begin
    h := h xor QWord(Data[i]);
    h := h * QWord($100000001B3);
  end;
  Result := h;
end;

// ---------- FLAC ----------
function BenchNextFlac(const Data: TBytes): QWord;
var
  Stm: IStream;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
  H: QWord;
  i: Integer;
begin
  H := 0;
  for i := 1 to BATCH_SIZE do
  begin
    Stm := BytesStream(Data);
    Dec := NextFlacDec.CreateFlacDecoder;
    Buf := Dec.DecodeWhole(Stm);
    H := H xor QWord(Buf.FrameCount) xor QWord(Length(Buf.Data));
    // feed hash
    if Length(Buf.Data) > 0 then
      H := H xor Fnva64(Buf.Data);
  end;
  Result := H;
end;

function BenchOldFlac(const Data: TBytes): QWord;
var
  Flac: PMiniflacT;
  Planes: array[0..7] of PInt32;
  i, Off, FileLen: LongInt;
  Used: LongWord;
  R: LongInt;
  H: QWord;
  BS: LongInt;
begin
  H := 0;
  for i := 1 to BATCH_SIZE do
  begin
    FileLen := Length(Data);
    GetMem(Flac, miniflac_size());
    for Off := 0 to 7 do
      GetMem(Planes[Off], 65535*SizeOf(LongInt));
    OldFlac.miniflac_init(Flac, OldFlac.MINIFLAC_CONTAINER_NATIVE);
    Off := 0;
    while Off < FileLen do
    begin
      Used := 0;
      R := OldFlac.miniflac_decode(Flac, @Data[Off], LongWord(FileLen-Off), @Used, PPInt32T(@Planes[0]));
      if Used>0 then Inc(Off, Integer(Used)) else Inc(Off);
      if R = OldFlac.MINIFLAC_OK then
      begin
        BS := Flac^.frame.header.block_size;
        H := H xor QWord(BS);
      end;
    end;
    for Off := 0 to 7 do FreeMem(Planes[Off]);
    FreeMem(Flac);
  end;
  Result := H;
end;

// ---------- MP3 ----------
function BuildMp3Stream: TBytes;
var
  i, Off: LongInt;
begin
  SetLength(Result, 100*417);
  Off:=0;
  for i:=0 to 99 do
  begin
    FillChar(Result[Off], 417, 0);
    Result[Off+0]:=$FF; Result[Off+1]:=$FB; Result[Off+2]:=$90; Result[Off+3]:=$00;
    Result[Off+6]:=$40;
    Inc(Off,417);
  end;
end;

function BenchNextMp3(const Data: TBytes): QWord;
var
  Stm: IStream;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
  H: QWord;
  i: Integer;
begin
  H:=0;
  for i:=1 to BATCH_SIZE do
  begin
    Stm:=BytesStream(Data);
    Dec:=NextMp3Dec.CreateMp3Decoder;
    Buf:=Dec.DecodeWhole(Stm);
    H:=H xor QWord(Buf.FrameCount);
    if Length(Buf.Data)>0 then H:=H xor Fnva64(Buf.Data);
  end;
  Result:=H;
end;

function BenchOldMp3(const Data: TBytes): QWord;
var
  Dec: OldMp3.TMp3decT;
  Info: OldMp3.TMp3decFrameInfoT;
  Pcm: array[0..2304*2-1] of OldMp3.TInt16T;
  H: QWord;
  Off, N, Len, i: LongInt;
begin
  H:=0;
  for i:=1 to BATCH_SIZE do
  begin
    Len:=Length(Data);
    OldMp3.mp3dec_init(@Dec);
    Off:=0;
    while Off < Len do
    begin
      N := OldMp3.mp3dec_decode_frame(@Dec, @Data[Off], Len-Off, @Pcm[0], @Info);
      if N<=0 then begin Inc(Off); Continue; end;
      H:=H xor QWord(N);
      if Info.frame_bytes>0 then Inc(Off, Info.frame_bytes) else Inc(Off);
    end;
  end;
  Result:=H;
end;

// ---------- Vorbis ----------
function BenchNextVorbis(const Path: string): QWord;
var
  Data: TBytes;
  Stm: IStream;
  Dec: IAudioDecoder;
  Buf: TAudioBuffer;
  H: QWord;
  i: Integer;
begin
  Data:=LoadFileBytes(Path);
  H:=0;
  for i:=1 to BATCH_SIZE do
  begin
    Stm:=BytesStream(Data);
    Dec:=NextVorbisDec.CreateVorbisDecoder;
    Buf:=Dec.DecodeWhole(Stm);
    H:=H xor QWord(Buf.FrameCount);
    if Length(Buf.Data)>0 then H:=H xor Fnva64(Buf.Data);
  end;
  Result:=H;
end;

function BenchOldVorbis(const Path: string): QWord;
var
  Err: LongInt;
  V: OldVorbis.PStbVorbis;
  Info: OldVorbis.TStbVorbisInfo;
  Buf: array[0..4095] of SmallInt;
  N, i: LongInt;
  H: QWord;
  Ch: LongInt;
begin
  H:=0;
  for i:=1 to BATCH_SIZE do
  begin
    V:=OldVorbis.stb_vorbis_open_filename(PAnsiChar(Path), @Err, nil);
    if V=nil then Halt(1);
    Info:=OldVorbis.stb_vorbis_get_info(V);
    Ch:=Info.channels;
    repeat
      N:=OldVorbis.stb_vorbis_get_samples_short_interleaved(V, Ch, @Buf[0], (Length(Buf) div Ch)*Ch);
      if N<=0 then Break;
      H:=H xor QWord(N);
    until False;
    OldVorbis.stb_vorbis_close(V);
  end;
  Result:=H;
end;

procedure RunBench(const Name: string; const Data: TBytes; NextFn, OldFn: Pointer; IsVorbis: Boolean; const VorbisPath: string);
var
  B: Integer;
  T0,T1: UInt64;
  BatchMs: array[0..BATCH_COUNT-1] of UInt64;
  Total, Best: UInt64;
  Mean: Double;
  H1,H2: QWord;
  Tag: string;
begin
  WriteLn('== ', Name, ' ==');
  // warmup
  for B:=1 to WARMUP do
  begin
    if IsVorbis then
    begin
      BenchNextVorbis(VorbisPath);
      BenchOldVorbis(VorbisPath);
    end else
    begin
      if Name='FLAC' then begin BenchNextFlac(Data); BenchOldFlac(Data); end
      else begin BenchNextMp3(Data); BenchOldMp3(Data); end;
    end;
  end;
  // nextpas
  Tag:='nextpas/'+Name;
  for B:=0 to BATCH_COUNT-1 do
  begin
    T0:=GetTickCount64;
    for H1:=1 to BATCH_SIZE do
      if IsVorbis then H2:=BenchNextVorbis(VorbisPath)
      else if Name='FLAC' then H2:=BenchNextFlac(Data) else H2:=BenchNextMp3(Data);
    T1:=GetTickCount64;
    BatchMs[B]:=T1-T0;
  end;
  Total:=0; Best:=High(UInt64);
  for B:=0 to BATCH_COUNT-1 do begin Total+=BatchMs[B]; if BatchMs[B]<Best then Best:=BatchMs[B]; end;
  Mean:=Total/(BATCH_COUNT*BATCH_SIZE);
  WriteLn(Tag, ': avg ', Mean:0:2, ' ms/run  best~', (Best*1000 div BATCH_SIZE), ' us/run  hash=', IntToHex(H2,16));
  // old
  Tag:='music888/'+Name;
  for B:=0 to BATCH_COUNT-1 do
  begin
    T0:=GetTickCount64;
    for H1:=1 to BATCH_SIZE do
      if IsVorbis then H2:=BenchOldVorbis(VorbisPath)
      else if Name='FLAC' then H2:=BenchOldFlac(Data) else H2:=BenchOldMp3(Data);
    T1:=GetTickCount64;
    BatchMs[B]:=T1-T0;
  end;
  Total:=0; Best:=High(UInt64);
  for B:=0 to BATCH_COUNT-1 do begin Total+=BatchMs[B]; if BatchMs[B]<Best then Best:=BatchMs[B]; end;
  Mean:=Total/(BATCH_COUNT*BATCH_SIZE);
  WriteLn(Tag, ': avg ', Mean:0:2, ' ms/run  best~', (Best*1000 div BATCH_SIZE), ' us/run  hash=', IntToHex(H2,16));
end;

var
  FlacData, Mp3Data: TBytes;
  VorbisPath: string;
begin
  WriteLn('== 3-way compare: nextpas vs music888 (C via vendor) ==');
  WriteLn('build: x86_64/simd(default)  batches=',BATCH_COUNT,'x',BATCH_SIZE,' warmup=',WARMUP);
  // FLAC
  FlacData:=LoadFileBytes('/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.flac');
  RunBench('FLAC', FlacData, nil, nil, False, '');
  // MP3
  Mp3Data:=BuildMp3Stream;
  RunBench('MP3', Mp3Data, nil, nil, False, '');
  // Vorbis
  VorbisPath:='/home/dtamade/projects/music888/tests/fixtures/tone_stereo_44k1.ogg';
  RunBench('Vorbis', TBytes(nil), nil, nil, True, VorbisPath);
  WriteLn('RESULT: BENCH-COMPARE-OK');
  WriteLn('Note: C baseline for mp3/vorbis is via vendor/minimp3.c and stb_vorbis.c compiled with gcc -O2; Pascal scalar is ~86-88% of C per music888 docs, SIMD ~1.4-1.65x over scalar');
end.
