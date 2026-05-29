program test_utf8_validate;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

function Utf8Validate(p: Pointer; len: SizeUInt): Boolean;
var dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  if (dt <> nil) and Assigned(dt^.Utf8Validate) then
    Result := dt^.Utf8Validate(p, len)
  else
    Result := True;
end;

var
  LPass, LFail: Integer;

procedure Check(const aName: string; aGot, aExpect: Boolean);
begin
  if aGot = aExpect then Inc(LPass)
  else begin WriteLn('  FAIL ', aName, ': got=', aGot, ' expect=', aExpect); Inc(LFail); end;
end;

var
  LAscii: array[0..127] of Byte;
  LUtf8_2byte: array[0..5] of Byte;
  LUtf8_3byte: array[0..8] of Byte;
  LUtf8_4byte: array[0..7] of Byte;
  LInvalid: array[0..3] of Byte;
  LBig: array[0..1023] of Byte;
  i: Integer;
begin
  InitializeDispatch;
  LPass := 0;
  LFail := 0;

  // === Valid ASCII ===
  for i := 0 to 127 do LAscii[i] := i;
  Check('ASCII_128', Utf8Validate(@LAscii[0], 128), True);
  Check('ASCII_empty', Utf8Validate(@LAscii[0], 0), True);
  Check('ASCII_1', Utf8Validate(@LAscii[65], 1), True);

  // === Valid 2-byte UTF-8 (U+0080 - U+07FF) ===
  // é = C3 A9
  LUtf8_2byte[0] := $C3; LUtf8_2byte[1] := $A9;
  // ñ = C3 B1
  LUtf8_2byte[2] := $C3; LUtf8_2byte[3] := $B1;
  // ü = C3 BC
  LUtf8_2byte[4] := $C3; LUtf8_2byte[5] := $BC;
  Check('2byte_valid', Utf8Validate(@LUtf8_2byte[0], 6), True);

  // === Valid 3-byte UTF-8 (U+0800 - U+FFFF) ===
  // 中 = E4 B8 AD
  LUtf8_3byte[0] := $E4; LUtf8_3byte[1] := $B8; LUtf8_3byte[2] := $AD;
  // 文 = E6 96 87
  LUtf8_3byte[3] := $E6; LUtf8_3byte[4] := $96; LUtf8_3byte[5] := $87;
  // € = E2 82 AC
  LUtf8_3byte[6] := $E2; LUtf8_3byte[7] := $82; LUtf8_3byte[8] := $AC;
  Check('3byte_valid', Utf8Validate(@LUtf8_3byte[0], 9), True);

  // === Valid 4-byte UTF-8 (U+10000 - U+10FFFF) ===
  // 😀 = F0 9F 98 80
  LUtf8_4byte[0] := $F0; LUtf8_4byte[1] := $9F; LUtf8_4byte[2] := $98; LUtf8_4byte[3] := $80;
  // 𝄞 = F0 9D 84 9E
  LUtf8_4byte[4] := $F0; LUtf8_4byte[5] := $9D; LUtf8_4byte[6] := $84; LUtf8_4byte[7] := $9E;
  Check('4byte_valid', Utf8Validate(@LUtf8_4byte[0], 8), True);

  // === Invalid: lone continuation byte ===
  LInvalid[0] := $80;
  Check('invalid_lone_cont', Utf8Validate(@LInvalid[0], 1), False);

  // === Invalid: truncated 2-byte ===
  LInvalid[0] := $C3;  // expects continuation
  Check('invalid_trunc_2byte', Utf8Validate(@LInvalid[0], 1), False);

  // === Invalid: truncated 3-byte ===
  LInvalid[0] := $E4; LInvalid[1] := $B8;  // expects one more continuation
  Check('invalid_trunc_3byte', Utf8Validate(@LInvalid[0], 2), False);

  // === Invalid: truncated 4-byte ===
  LInvalid[0] := $F0; LInvalid[1] := $9F; LInvalid[2] := $98;
  Check('invalid_trunc_4byte', Utf8Validate(@LInvalid[0], 3), False);

  // === Invalid: overlong 2-byte (U+0000 encoded as C0 80) ===
  LInvalid[0] := $C0; LInvalid[1] := $80;
  Check('invalid_overlong_2', Utf8Validate(@LInvalid[0], 2), False);

  // === Invalid: overlong 3-byte (U+007F encoded as E0 81 BF) ===
  LInvalid[0] := $E0; LInvalid[1] := $81; LInvalid[2] := $BF;
  Check('invalid_overlong_3', Utf8Validate(@LInvalid[0], 3), False);

  // === Invalid: code point > U+10FFFF (F4 90 80 80) ===
  LInvalid[0] := $F4; LInvalid[1] := $90; LInvalid[2] := $80; LInvalid[3] := $80;
  Check('invalid_too_large', Utf8Validate(@LInvalid[0], 4), False);

  // === Invalid: FE/FF bytes (never valid) ===
  LInvalid[0] := $FE;
  Check('invalid_FE', Utf8Validate(@LInvalid[0], 1), False);
  LInvalid[0] := $FF;
  Check('invalid_FF', Utf8Validate(@LInvalid[0], 1), False);

  // === Large buffer: 1024 bytes ASCII ===
  for i := 0 to 1023 do LBig[i] := 32 + (i mod 95);
  Check('large_ascii_1024', Utf8Validate(@LBig[0], 1024), True);

  // === Large buffer with valid UTF-8 mixed ===
  // Fill with ASCII then insert valid 3-byte at position 500
  for i := 0 to 1023 do LBig[i] := Ord('A') + (i mod 26);
  LBig[500] := $E4; LBig[501] := $B8; LBig[502] := $AD;  // 中
  Check('large_mixed_valid', Utf8Validate(@LBig[0], 1024), True);

  // === Large buffer with invalid byte at end ===
  LBig[1023] := $C3;  // truncated 2-byte at end
  Check('large_invalid_end', Utf8Validate(@LBig[0], 1024), False);

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then WriteLn('All tests passed!')
  else Halt(1);
end.
