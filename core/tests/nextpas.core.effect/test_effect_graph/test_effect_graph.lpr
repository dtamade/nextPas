program test_effect_graph;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.graphics.base,
  nextpas.core.graphics.errors,
  nextpas.core.graphics.effect.graph,
  nextpas.core.image.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary;

var T: TTestSuite;
  GEffTmp: TEffectGraph;
  GEffTmpBytes: TBytes;
  GEffTmpBitmap: TBitmap;
  GEffTmpBytes2: TBytes;

procedure DoEffAddBlurNegative;
begin
  GEffTmp.AddBlur(-1);
end;

procedure DoEffAddLUTBad;
begin
  GEffTmp.AddLUT(GEffTmpBytes);
end;

procedure DoEffDeserializeTruncated;
begin
  GEffTmp.Deserialize(Copy(GEffTmpBytes, 0, 2));
end;

procedure DoEffBakeEmpty;
begin
  GEffTmp.Bake(GEffTmpBitmap);
end;

procedure TestEmpty;
var G: TEffectGraph;
begin
  G.Clear;
  Check(G.IsEmpty, 'empty');
  CheckEqual(0, G.Count, 'count 0');
end;

procedure TestAdd;
var G: TEffectGraph; Data: TBytes;
begin
  G.Clear;
  G.AddBlur(2.5);
  CheckEqual(1, G.Count, 'blur');
  G.AddDropShadow(2,2,3, Color32(0,0,0,128));
  CheckEqual(2, G.Count, 'shadow');
  G.AddHue(30);
  CheckEqual(3, G.Count, 'hue');
  SetLength(Data, 768); Data[0]:=1;
  G.AddLUT(Data);
  CheckEqual(4, G.Count, 'lut');
  GEffTmp := G; GEffTmpBytes := nil;
  CheckRaises(EArgumentError, @DoEffAddBlurNegative, 'radius must be');
  SetLength(Data, 10); GEffTmpBytes := Data; GEffTmp := G;
  CheckRaises(EArgumentError, @DoEffAddLUTBad, 'LUT must be');
end;

procedure TestSerialize;
var G, G2: TEffectGraph; B: TBytes; Data: TBytes;
begin
  G.Clear;
  G.AddBlur(5);
  G.AddHue(10);
  B := G.Serialize;
  Check(Length(B) >= 4, 'serialize len');
  // bytes.ops single source: WriteUInt32LE/Read via bytes.binary single source
  CheckEqual(LongWord(2), ReadUInt32LE(@B[0]), 'node count');
  G2.Clear; G2.Deserialize(B);
  CheckEqual(2, G2.Count, 'deserialize count');
  // corrupt truncate should raise EEffectError with try/finally safe
  GEffTmp := G2; GEffTmpBytes := B;
  CheckRaises(EEffectError, @DoEffDeserializeTruncated, 'truncated');
  SetLength(Data, 768);
  G.Clear; G.AddLUT(Data);
  B := G.Serialize;
  G2.Clear; G2.Deserialize(B);
  CheckEqual(1, G2.Count, 'lut roundtrip');
end;

procedure TestBake;
var G: TEffectGraph; Src, Dst: TBitmap;
begin
  Src := TBitmap.Create(8,8, bfRGBA);
  // fill red via row ptr zero-copy
  Src.RowPtr(0)[0]:=255;
  G.Clear;
  G.AddBlur(1);
  Dst := G.Bake(Src);
  Check(not Dst.IsEmpty, 'baked');
  CheckEqual(8, Dst.Width, 'w');
  // empty src should raise EEffectError and not leak (try/finally in BoxBlur)
  Src.Clear; GEffTmp := G; GEffTmpBitmap := Src;
  CheckRaises(EEffectError, @DoEffBakeEmpty, 'src empty');
end;

procedure TestBytesOps;
var A,B: TBytes;
begin
  A := TBytes.Create(1,2,3);
  B := SpanClone(TByteSpan.FromBytes(A));
  Check(BytesEqual(A,B), 'span single source');
end;

begin
  T := TTestSuite.Create('nextpas.core.effect.graph');
  T.Test('empty', @TestEmpty);
  T.Test('add', @TestAdd);
  T.Test('serialize', @TestSerialize);
  T.Test('bake', @TestBake);
  T.Test('bytes ops', @TestBytesOps);
  if not T.Run then Halt(1);
end.
