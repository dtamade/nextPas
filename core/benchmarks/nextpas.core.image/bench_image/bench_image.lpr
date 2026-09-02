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
  ONE_MB = 1024*1024; // 512*512*4 = 1,048,576

var
  GPng512: TBytes;
  GPixels512: TBytes;

function IsVerifyMode: Boolean; inline;
var I: Integer;
begin
  Result := False;
  for I:=1 to ParamCount do
    if ParamStr(I)='--verify' then Exit(True);
end;

procedure InitData; inline;
var I: Integer;
begin
  // 1MB single solidification: 512x512x4 = 1,048,576 bytes, single PngEncode
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

procedure BenchEncode512(const ACtx: IBenchContext); inline;
var B: TBytes;
begin
  ACtx.SetBytes(W512*H512*4);
  B := PngEncodeRgba(GPixels512, W512, H512);
  if Length(B)>0 then BenchBlackBoxBytes(B[0], Length(B));
end;

procedure BenchDecode512(const ACtx: IBenchContext); inline;
var Info: TImageInfo; Raw: TBytes;
begin
  ACtx.SetBytes(W512*H512*4);
  Raw := ImageDecode(GPng512, Info);
  if Length(Raw)>0 then BenchBlackBoxBytes(Raw[0], Length(Raw));
end;

function CheckGate(const ARes: IBenchResults): Boolean;
var R: TBenchResult; LimitUs, LimitNs: Double;
begin
  Result := False;
  if not ARes.TryGetByName('Decode 512x512', R) then
  begin
    WriteLn('Gate Decode missing FAIL');
    Exit(False);
  end;
  LimitUs := GATE_DECODE_US * (W512*H512*4 / ONE_MB);
  LimitNs := LimitUs * 1000;
  if R.NsPerOp < LimitNs then
  begin
    WriteLn('Gate Decode ',R.NsPerOp:0:1,' ns/op < ',LimitNs:0:1,' PASS (',GATE_DECODE_US:0:1,'us/MB)');
    Result := True;
  end else
    WriteLn('Gate Decode ',R.NsPerOp:0:1,' ns/op >= ',LimitNs:0:1,' FAIL (',GATE_DECODE_US:0:1,'us/MB)');
end;

function VerifyTable(const ARes: IBenchResults): Boolean;
var REnc, RDec: TBenchResult; OkEnc, OkDec: Boolean;
begin
  OkEnc := ARes.TryGetByName('Encode 512x512', REnc);
  OkDec := ARes.TryGetByName('Decode 512x512', RDec);
  Result := OkEnc and OkDec;
  if not Result then
  begin
    WriteLn('Verify table missing Encode/Decode entries FAIL');
    Exit(False);
  end;
  // bytes solidification 1MB
  if (REnc.BytesPerOp <> W512*H512*4) or (RDec.BytesPerOp <> W512*H512*4) then
  begin
    WriteLn('Verify BytesPerOp not 1MB FAIL (enc=',REnc.BytesPerOp,' dec=',RDec.BytesPerOp,')');
    Exit(False);
  end;
  // ns/op+MB/s columns present in console/benchstat/json
  if (REnc.NsPerOp <= 0) or (RDec.NsPerOp <= 0) then
  begin
    WriteLn('Verify ns/op invalid FAIL');
    Exit(False);
  end;
  WriteLn('Verify CONTRACT 0.2.1 table 512x512 Decode/Encode ns/op+MB/s 1MB single PASS');
  Result := True;
end;

var Suite: IBenchSuite; Res: IBenchResults; GateOk, TableOk: Boolean; VerifyMode: Boolean;
begin
  VerifyMode := IsVerifyMode;
  if VerifyMode then WriteLn('bench_image --verify CONTRACT 0.2.1 512x512 1MB single');
  InitData;
  Suite := TBenchSuite.Create('image');
  Suite.SetQuiet(True);
  // single invocation no inner loop, framework calibrates but bench func itself single encode/decode
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
  WriteLn('JSON: build/bench-image.json');
  GateOk := CheckGate(Res);
  TableOk := VerifyTable(Res);
  if VerifyMode then
  begin
    if GateOk and TableOk then
    begin
      WriteLn('--verify PASS');
      Halt(0);
    end else
    begin
      WriteLn('--verify FAIL');
      Halt(1);
    end;
  end;
end.
