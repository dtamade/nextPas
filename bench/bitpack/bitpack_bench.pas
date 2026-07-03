program bitpack_bench;
{$mode ObjFPC}{$H+}
uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 8192;
  ITERS = 10000;

var
  GSrc: array[0..N-1] of Byte;
  GDst: array[0..N-1] of Byte;
  GWordSrc: array[0..N-1] of Word;
  GLongSrc: array[0..N-1] of UInt32;
  GSink: QWord;

procedure InitData;
var
  I: Integer;
  Seed: UInt32;
begin
  Seed := 42;
  for I := 0 to N - 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    GSrc[I] := Byte(Seed);
    GWordSrc[I] := Word(Seed);
    GLongSrc[I] := Seed;
  end;
end;

{ === Track 1: NonZeroCount — count non-zero bytes (minimal work/element) === }

procedure BenchNonZeroCount(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Count: QWord;
begin
  Count := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      if GSrc[I] <> 0 then
        Inc(Count);
  GSink := Count;
  ACtx.SetBytes(ITERS * N);
end;

{ === Track 2: ByteSum — accumulate bytes into QWord (1 add/element) === }

procedure BenchByteSum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: QWord;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      Sum += GSrc[I];
  GSink := Sum;
  ACtx.SetBytes(ITERS * N);
end;

{ === Track 3: ByteMax — find max byte (1 compare/element) === }

procedure BenchByteMax(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  MaxVal, B: Byte;
  TotalMax: QWord;
begin
  TotalMax := 0;
  for Iter := 1 to ITERS do
  begin
    MaxVal := 0;
    for I := 0 to N - 1 do
    begin
      B := GSrc[I];
      if B > MaxVal then
        MaxVal := B;
    end;
    TotalMax += MaxVal;
  end;
  GSink := TotalMax;
  ACtx.SetBytes(ITERS * N);
end;

{ === Track 4: XorAccum — XOR accumulate bytes (1 xor/element) === }

procedure BenchXorAccum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  XorVal: Byte;
begin
  XorVal := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      XorVal := XorVal xor GSrc[I];
  GSink := XorVal;
  ACtx.SetBytes(ITERS * N);
end;

{ === Track 5: MaskCopy — copy bytes > threshold (branch + copy) === }

procedure BenchMaskCopy(const ACtx: IBenchContext);
const
  THRESHOLD = 128;
var
  Iter, I, J: Integer;
begin
  J := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      if GSrc[I] > THRESHOLD then
      begin
        GDst[J and (N-1)] := GSrc[I];
        Inc(J);
      end;
  GSink := J;
  ACtx.SetBytes(ITERS * N);
end;

{ === Track 6: WordSum — accumulate words (1 add/element on 16-bit) === }

procedure BenchWordSum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: QWord;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      Sum += GWordSrc[I];
  GSink := Sum;
  ACtx.SetBytes(ITERS * N * 2);
end;

{ === Track 7: DWordSum — accumulate dwords (1 add/element on 32-bit) === }

procedure BenchDWordSum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: QWord;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      Sum += GLongSrc[I];
  GSink := Sum;
  ACtx.SetBytes(ITERS * N * 4);
end;

{ === Track 8: NibbleSwap — swap high/low nibbles of each byte === }

procedure BenchNibbleSwap(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: QWord;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
    begin
      GDst[I] := (GSrc[I] shl 4) or (GSrc[I] shr 4);
      Sum += GDst[I];
    end;
  GSink := Sum;
  ACtx.SetBytes(ITERS * N);
end;

var
  LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('BitPack');
  LSuite.Add('NonZeroCount', @BenchNonZeroCount);
  LSuite.Add('ByteSum',      @BenchByteSum);
  LSuite.Add('ByteMax',      @BenchByteMax);
  LSuite.Add('XorAccum',     @BenchXorAccum);
  LSuite.Add('MaskCopy',     @BenchMaskCopy);
  LSuite.Add('WordSum',      @BenchWordSum);
  LSuite.Add('DWordSum',     @BenchDWordSum);
  LSuite.Add('NibbleSwap',   @BenchNibbleSwap);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);
  LSuite.Run.ToBenchStat;
end.
