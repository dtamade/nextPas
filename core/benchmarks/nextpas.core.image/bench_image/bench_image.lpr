program bench_image;
{$mode objfpc}{$H+}
uses
  nextpas.core.base,
  nextpas.core.image.base,
  nextpas.core.image.png,
  nextpas.core.image.dispatch,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.bytes.ops,
  nextpas.core.fs;

const
  W512 = 512;
  H512 = 512;
  GATE_DECODE_US = 800.0;

var
  GPng512: TBytes;
  GPixels512: TBytes;

procedure InitData;
var I: Integer;
begin
  SetLength(GPixels512, W512*H512*4);
  for I:=0 to W512*H512-1 do
  begin
    GPixels512[I*4]:= Byte(I and $FF);
    GPixels512[I*4+1]:= Byte((I shr 8) and $FF);
    GPixels512[I*4+2]:= 128;
    GPixels512[I*4+3]:= 255;
  end;
  GPng512 := PngEncodeRgba(GPixels512, W512, H512);
end;

procedure BenchEncode512(const ACtx: IBenchContext);
var B: TBytes;
begin
  ACtx.SetBytes(W512*H512*4);
  B := PngEncodeRgba(GPixels512, W512, H512);
  BenchBlackBoxBytes(B[0], Length(B));
end;

procedure BenchDecode512(const ACtx: IBenchContext);
var Info: TImageInfo; Raw: TBytes;
begin
  ACtx.SetBytes(W512*H512*4);
  Raw := ImageDecode(GPng512, Info);
  BenchBlackBoxBytes(Raw[0], Length(Raw));
end;

procedure CheckGate(const ARes: IBenchResults);
var R: TBenchResult;
begin
  if ARes.TryGetByName('Decode 512x512', R) then
  begin
    // 800us gate for 512x512 ~1MB raw (512*512*4)
    if R.NsPerOp/1000 < GATE_DECODE_US* (W512*H512*4/ (1024*1024)) then
      WriteLn('Gate Decode ',R.NsPerOp:0:1,' ns/op PASS')
    else WriteLn('Gate Decode ',R.NsPerOp:0:1,' ns/op FAIL');
  end;
end;

var Suite: IBenchSuite; Res: IBenchResults;
begin
  InitData;
  Suite := TBenchSuite.Create('image');
  Suite.SetQuiet(True);
  Suite.SetMinDuration(TDuration.FromMilliseconds(50));
  Suite.SetMinSamples(5);
  Suite.Add('Encode 512x512', @BenchEncode512);
  Suite.Add('Decode 512x512', @BenchDecode512);
  Res := Suite.Run;
  WriteLn(Res.PrintToConsole);
  WriteLn(Res.ToSummary);
  WriteLn(Res.ToBenchstat);
  WriteLn(Res.ToJSON);
  ForceDirectories('build');
  Res.SaveToJSON('build/bench-image.json');
  Res.SaveToHTML('build/bench-image.html');
  WriteLn('HTML: build/bench-image.html');
  CheckGate(Res);
end.
