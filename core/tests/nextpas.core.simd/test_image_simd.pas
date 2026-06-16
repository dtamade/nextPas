program test_image_simd;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.simd.image;

var
  LSrc, LDst: TSimdImage;
  i: Integer;
  LPass, LFail: Integer;
  LExpected: Byte;
  var_v: Integer;

begin
  LPass := 0;
  LFail := 0;

  // Test RgbaToGray
  LSrc := TSimdImage.Create(16, 1, spfRGBA32);
  LDst := TSimdImage.Create(16, 1, spfGray8);
  for i := 0 to 15 do
  begin
    LSrc.Data[i*4] := Byte(i * 16);       // R
    LSrc.Data[i*4+1] := Byte(i * 8);      // G
    LSrc.Data[i*4+2] := Byte(i * 4);      // B
    LSrc.Data[i*4+3] := 255;              // A
  end;
  RgbaToGray(LSrc, LDst);
  for i := 0 to 15 do
  begin
    LExpected := Byte((77 * (i*16) + 150 * (i*8) + 29 * (i*4)) shr 8);
    if (LDst.Data[i] = LExpected) or (System.Abs(Integer(LDst.Data[i]) - Integer(LExpected)) <= 1) then
      Inc(LPass)
    else
    begin
      WriteLn('  FAIL RgbaToGray[', i, ']: got=', LDst.Data[i], ' exp=', LExpected);
      Inc(LFail);
    end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test RgbaToGray: pure red
  LSrc := TSimdImage.Create(4, 1, spfRGBA32);
  LDst := TSimdImage.Create(4, 1, spfGray8);
  for i := 0 to 3 do begin LSrc.Data[i*4] := 255; LSrc.Data[i*4+1] := 0; LSrc.Data[i*4+2] := 0; LSrc.Data[i*4+3] := 255; end;
  RgbaToGray(LSrc, LDst);
  LExpected := Byte((77 * 255) shr 8);
  for i := 0 to 3 do
    if (LDst.Data[i] = LExpected) or (System.Abs(Integer(LDst.Data[i]) - Integer(LExpected)) <= 1) then Inc(LPass)
    else begin WriteLn('  FAIL RgbaToGray_red[', i, ']'); Inc(LFail); end;
  LSrc.Free;
  LDst.Free;

  // Test InvertGray
  LSrc := TSimdImage.Create(64, 4, spfGray8);
  LDst := TSimdImage.Create(64, 4, spfGray8);
  for i := 0 to 255 do
    LSrc.Data[i] := Byte(i);
  InvertGray(LSrc, LDst);
  for i := 0 to 255 do
  begin
    if LDst.Data[i] = Byte(255 - i) then
      Inc(LPass)
    else
    begin
      WriteLn('  FAIL InvertGray[', i, ']: got=', LDst.Data[i], ' expect=', 255 - i);
      Inc(LFail);
    end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test ThresholdGray
  LSrc := TSimdImage.Create(64, 4, spfGray8);
  LDst := TSimdImage.Create(64, 4, spfGray8);
  for i := 0 to 255 do
    LSrc.Data[i] := Byte(i);
  ThresholdGray(LSrc, LDst, 128);
  for i := 0 to 255 do
  begin
    if i >= 128 then LExpected := 255 else LExpected := 0;
    if LDst.Data[i] = LExpected then
      Inc(LPass)
    else
    begin
      WriteLn('  FAIL ThresholdGray[', i, ']: got=', LDst.Data[i], ' expect=', LExpected);
      Inc(LFail);
    end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test ThresholdGray edge: threshold=0 (all pass)
  LSrc := TSimdImage.Create(16, 1, spfGray8);
  LDst := TSimdImage.Create(16, 1, spfGray8);
  for i := 0 to 15 do LSrc.Data[i] := Byte(i);
  ThresholdGray(LSrc, LDst, 0);
  for i := 0 to 15 do
  begin
    if LDst.Data[i] = 255 then Inc(LPass)
    else begin WriteLn('  FAIL Thresh0[', i, ']'); Inc(LFail); end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test ThresholdGray edge: threshold=255
  LSrc := TSimdImage.Create(16, 1, spfGray8);
  LDst := TSimdImage.Create(16, 1, spfGray8);
  for i := 0 to 15 do LSrc.Data[i] := Byte(i * 17);
  ThresholdGray(LSrc, LDst, 255);
  for i := 0 to 15 do
  begin
    if i * 17 >= 255 then LExpected := 255 else LExpected := 0;
    if LDst.Data[i] = LExpected then Inc(LPass)
    else begin WriteLn('  FAIL Thresh255[', i, ']: got=', LDst.Data[i], ' exp=', LExpected); Inc(LFail); end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test BrightnessContrast: identity (brightness=0, contrast=1.0)
  LSrc := TSimdImage.Create(64, 4, spfGray8);
  LDst := TSimdImage.Create(64, 4, spfGray8);
  for i := 0 to 255 do LSrc.Data[i] := Byte(i);
  BrightnessContrast(LSrc, LDst, 0, 1.0);
  for i := 0 to 255 do
  begin
    if LDst.Data[i] = Byte(i) then Inc(LPass)
    else begin WriteLn('  FAIL BC_id[', i, ']: got=', LDst.Data[i], ' exp=', i); Inc(LFail); end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test BrightnessContrast: brightness=50, contrast=1.0
  LSrc := TSimdImage.Create(64, 4, spfGray8);
  LDst := TSimdImage.Create(64, 4, spfGray8);
  for i := 0 to 255 do LSrc.Data[i] := Byte(i);
  BrightnessContrast(LSrc, LDst, 50, 1.0);
  for i := 0 to 255 do
  begin
    LExpected := Byte(System.Round((i - 128) * 1.0 + 128 + 50));
    if i + 50 > 255 then LExpected := 255;
    if LDst.Data[i] = LExpected then Inc(LPass)
    else begin WriteLn('  FAIL BC_b50[', i, ']: got=', LDst.Data[i], ' exp=', LExpected); Inc(LFail); end;
  end;
  LSrc.Free;
  LDst.Free;

  // Test BrightnessContrast: contrast=2.0
  LSrc := TSimdImage.Create(16, 1, spfGray8);
  LDst := TSimdImage.Create(16, 1, spfGray8);
  for i := 0 to 15 do LSrc.Data[i] := Byte(i * 17);
  BrightnessContrast(LSrc, LDst, 0, 2.0);
  for i := 0 to 15 do
  begin
    var_v := Round((i * 17 - 128) * 2.0 + 128);
    if var_v < 0 then var_v := 0;
    if var_v > 255 then var_v := 255;
    LExpected := Byte(var_v);
    if (LDst.Data[i] = LExpected) or (System.Abs(Integer(LDst.Data[i]) - Integer(LExpected)) <= 1) then
      Inc(LPass)
    else
    begin
      WriteLn('  FAIL BC_c2[', i, ']: got=', LDst.Data[i], ' exp=', LExpected);
      Inc(LFail);
    end;
  end;
  LSrc.Free;
  LDst.Free;

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then
    WriteLn('All tests passed!')
  else
    Halt(1);
end.
