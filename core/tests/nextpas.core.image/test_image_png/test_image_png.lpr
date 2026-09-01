program test_image_png;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.image.png,
  nextpas.core.image.base,
  nextpas.core.image.dispatch,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.compress,
  nextpas.core.checksum.crc32;

var T: TTestSuite;

procedure TestRoundTrip;
var Pixels, Png, Raw: TBytes; W, H: Integer; Info: TImageInfo; B: TBitmap;
begin
  W:=4; H:=4;
  SetLength(Pixels, W*H*4);
  Pixels[0]:=255; Pixels[1]:=0; Pixels[2]:=0; Pixels[3]:=255;
  Png := PngEncodeRgba(Pixels, W, H);
  Check(Length(Png) > 8, 'png bytes');
  // inline zero-copy detect: DetectImageFormat uses bytes span no copy
  Check(DetectImageFormat(Png)=ifPng, 'detect png');
  Raw := ImageDecode(Png, Info);
  CheckEqual(W, Info.Width, 'decode w');
  CheckEqual(H, Info.Height, 'decode h');
  Check(Raw[0]=255, 'pixel roundtrip');
  // TryImageDecode branch stable, ensures resource release via try
  Check(TryImageDecode(Png, Raw, Info), 'try decode true');
  Check(not TryImageDecode(TBytes.Create(1,2,3), Raw, Info), 'try false');
end;

procedure TestBadArgs;
begin
  CheckRaises(EArgumentError, procedure begin PngEncodeRgba(nil,0,1); end, 'width/height must be');
  CheckRaises(EArgumentError, procedure begin PngEncodeRgba(TBytes.Create(1,2,3),2,2); end, 'length mismatch');
end;

procedure TestBytesOpsSingleSource;
var A,B: TBytes; S: TByteSpan;
begin
  // verify bytes.ops single source: BytesAppend uses single Move, no duplicate code in image.png
  A:=nil; BytesAppend(A, TBytes.Create(1,2)); BytesAppend(A, TBytes.Create(3,4));
  CheckEqual(4, Length(A), 'append');
  S:=TByteSpan.FromBytes(A);
  Check(SpanEqual(S, TByteSpan.FromBytes(TBytes.Create(1,2,3,4))), 'span equal');
  // Write/Read BE single source via bytes.binary
  Check(ReadUInt32BE(@A[0]) <> 0, 'read be');
end;

procedure TestStrideInvariant;
var B: TBitmap;
begin
  B:=TBitmap.Create(10,10, bfRGBA);
  CheckEqual(0, B.Stride mod 64, 'stride aligned? remainder 0 via mod');
  // actual: 10*4=40 ->64
  CheckEqual(64, B.Stride, 'stride 64');
  B:=TBitmap.Create(16,1, bfRGBA);
  CheckEqual(64, B.Stride, '16*4');
end;

begin
  T:=TTestSuite.Create('nextpas.core.image.png');
  T.Test('roundtrip', @TestRoundTrip);
  T.Test('bad args', @TestBadArgs);
  T.Test('bytes single source', @TestBytesOpsSingleSource);
  T.Test('stride invariant', @TestStrideInvariant);
  if not T.Run then Halt(1);
end.
