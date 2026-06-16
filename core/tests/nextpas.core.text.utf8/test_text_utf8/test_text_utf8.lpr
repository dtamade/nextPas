program test_text_utf8;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.utf8,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestDecodeAscii;
var
  D: TUTF8DecodeResult;
  B: Byte;
begin
  B := Ord('A');
  D := UTF8Decode(@B, 1);
  CheckEqual(Int64(65), Int64(D.CodePoint), 'A=65');
  CheckEqual(Int64(1), Int64(D.ByteLen), '1 byte');
end;

procedure TestDecode2Byte;
var
  D: TUTF8DecodeResult;
  Buf: array[0..1] of Byte;
begin
  Buf[0] := $C3; Buf[1] := $A9;
  D := UTF8Decode(@Buf[0], 2);
  CheckEqual(Int64($E9), Int64(D.CodePoint), 'e-acute U+00E9');
  CheckEqual(Int64(2), Int64(D.ByteLen), '2 bytes');
end;

procedure TestDecode3Byte;
var
  D: TUTF8DecodeResult;
  Buf: array[0..2] of Byte;
begin
  Buf[0] := $E4; Buf[1] := $B8; Buf[2] := $AD;
  D := UTF8Decode(@Buf[0], 3);
  CheckEqual(Int64($4E2D), Int64(D.CodePoint), 'CJK U+4E2D');
  CheckEqual(Int64(3), Int64(D.ByteLen), '3 bytes');
end;

procedure TestDecode4Byte;
var
  D: TUTF8DecodeResult;
  Buf: array[0..3] of Byte;
begin
  Buf[0] := $F0; Buf[1] := $9F; Buf[2] := $98; Buf[3] := $80;
  D := UTF8Decode(@Buf[0], 4);
  CheckEqual(Int64($1F600), Int64(D.CodePoint), 'emoji U+1F600');
  CheckEqual(Int64(4), Int64(D.ByteLen), '4 bytes');
end;

procedure TestDecodeInvalid;
var
  D: TUTF8DecodeResult;
  Buf: array[0..3] of Byte;
begin
  Buf[0] := $FE;
  D := UTF8Decode(@Buf[0], 1);
  CheckEqual(Int64(0), Int64(D.ByteLen), 'invalid lead byte');

  Buf[0] := $C0; Buf[1] := $80;
  D := UTF8Decode(@Buf[0], 2);
  CheckEqual(Int64(0), Int64(D.ByteLen), 'overlong 2-byte');

  Buf[0] := $ED; Buf[1] := $A0; Buf[2] := $80;
  D := UTF8Decode(@Buf[0], 3);
  CheckEqual(Int64(0), Int64(D.ByteLen), 'surrogate U+D800');
end;

procedure TestNilNonzeroSpan;
var
  D: TUTF8DecodeResult;
  Iter: TUTF8Iterator;
  CP: UInt32;
begin
  D := UTF8Decode(nil, 1);
  CheckEqual(Int64(0), Int64(D.ByteLen), 'nil decode fails closed');
  CheckEqual(Int64(0), Int64(D.CodePoint), 'nil decode codepoint = 0');
  Check(not UTF8IsValid(nil, 1), 'nil span is not valid UTF-8');
  CheckEqual(Int64(0), Int64(UTF8CodePointCount(nil, 1)), 'nil span has no codepoints');

  Iter.Init(nil, 1);
  Check(not Iter.HasNext, 'nil iterator has no next');
  CheckEqual(Int64(0), Int64(Iter.Remaining), 'nil iterator remaining = 0');
  Check(not Iter.Next(CP), 'nil iterator does not decode');
  CheckEqual(Int64(0), Int64(CP), 'nil iterator codepoint = 0');
end;

procedure TestEncode;
var
  Buf: array[0..5] of Byte;
  N: Byte;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  N := UTF8Encode($41, @Buf[0]);
  CheckEqual(Int64(1), Int64(N), 'ASCII 1 byte');
  Check(Buf[0] = $41, 'A');

  N := UTF8Encode($E9, @Buf[0]);
  CheckEqual(Int64(2), Int64(N), 'e-acute 2 bytes');
  Check(Buf[0] = $C3, 'byte 0');
  Check(Buf[1] = $A9, 'byte 1');

  N := UTF8Encode($4E2D, @Buf[0]);
  CheckEqual(Int64(3), Int64(N), 'CJK 3 bytes');

  N := UTF8Encode($1F600, @Buf[0]);
  CheckEqual(Int64(4), Int64(N), 'emoji 4 bytes');

  N := UTF8Encode($D800, @Buf[0]);
  CheckEqual(Int64(0), Int64(N), 'surrogate rejected');

  N := UTF8Encode($110000, @Buf[0]);
  CheckEqual(Int64(0), Int64(N), 'out of range rejected');
end;

procedure TestEncodeNilDestinationFailsClosed;
begin
  CheckEqual(Int64(0), Int64(UTF8Encode($41, nil)), 'nil destination rejects ASCII');
  CheckEqual(Int64(0), Int64(UTF8Encode($1F600, nil)), 'nil destination rejects emoji');
end;

procedure TestIsValid;
const
  VALID: array[0..5] of Byte = ($48, $65, $6C, $6C, $6F, $21);
  INVALID: array[0..2] of Byte = ($C0, $80, $41);
  EMOJI: array[0..3] of Byte = ($F0, $9F, $98, $80);
begin
  Check(UTF8IsValid(@VALID[0], 6), 'ASCII valid');
  Check(not UTF8IsValid(@INVALID[0], 3), 'overlong invalid');
  Check(UTF8IsValid(@EMOJI[0], 4), 'emoji valid');
end;

procedure TestCodePointCount;
const
  ASCII: array[0..4] of Byte = ($48, $65, $6C, $6C, $6F);
  MIXED: array[0..7] of Byte = ($48, $C3, $A9, $6C, $6C, $C3, $B6, $21);
  ISOLATED_CONT: array[0..1] of Byte = ($80, $41);
  TRUNCATED_THREE: array[0..2] of Byte = ($E2, $82, $5A);
begin
  CheckEqual(Int64(5), Int64(UTF8CodePointCount(@ASCII[0], 5)), 'ASCII 5 cp');
  CheckEqual(Int64(6), Int64(UTF8CodePointCount(@MIXED[0], 8)), 'mixed 6 cp');
  CheckEqual(Int64(2), Int64(UTF8CodePointCount(@ISOLATED_CONT[0], 2)),
    'isolated continuation counts as replacement plus ASCII');
  CheckEqual(Int64(3), Int64(UTF8CodePointCount(@TRUNCATED_THREE[0], 3)),
    'truncated sequence consumes one replacement byte at a time');
end;

procedure TestStringWrappers;
var
  LValue: string;
begin
  CheckEqual(Int64(5), Int64(UTF8Length('hello')), 'string ASCII length');
  CheckEqual(Int64($4E2D), Int64(UTF8CodePointAt(#$E4#$B8#$AD, 0)), 'string CJK codepoint');

  LValue := #$80 + 'A';
  CheckEqual(Int64(2), Int64(UTF8Length(LValue)), 'invalid byte still counts once');
  CheckEqual(Int64($FFFD), Int64(UTF8CodePointAt(LValue, 0)), 'invalid byte wrapper returns replacement');
  CheckEqual(Int64(Ord('A')), Int64(UTF8CodePointAt(LValue, 1)), 'wrapper keeps following ASCII addressable');
end;

procedure TestIterator;
var
  Iter: TUTF8Iterator;
  CP: UInt32;
  Count: Integer;
const
  DATA: array[0..6] of Byte = ($41, $C3, $A9, $E4, $B8, $AD, $21);
begin
  Iter.Init(@DATA[0], 7);
  Count := 0;
  while Iter.Next(CP) do
    Inc(Count);
  CheckEqual(Int64(4), Int64(Count), '4 codepoints');
  Check(not Iter.HasNext, 'exhausted');
end;

procedure TestIteratorInvalid;
var
  Iter: TUTF8Iterator;
  CP: UInt32;
const
  DATA: array[0..2] of Byte = ($FE, $41, $42);
begin
  Iter.Init(@DATA[0], 3);
  Check(Iter.Next(CP), 'first');
  CheckEqual(Int64($FFFD), Int64(CP), 'replacement char');
  Check(Iter.Next(CP), 'second');
  CheckEqual(Int64($41), Int64(CP), 'A after invalid');
end;

procedure TestByteLength;
begin
  CheckEqual(Int64(1), Int64(UTF8ByteLength($41)), 'ASCII');
  CheckEqual(Int64(2), Int64(UTF8ByteLength($C3)), '2-byte lead');
  CheckEqual(Int64(3), Int64(UTF8ByteLength($E4)), '3-byte lead');
  CheckEqual(Int64(4), Int64(UTF8ByteLength($F0)), '4-byte lead');
  CheckEqual(Int64(1), Int64(UTF8ByteLength($80)), 'continuation (fallback)');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.utf8');
  T.Run('decode ASCII', @TestDecodeAscii);
  T.Run('decode 2-byte', @TestDecode2Byte);
  T.Run('decode 3-byte', @TestDecode3Byte);
  T.Run('decode 4-byte', @TestDecode4Byte);
  T.Run('decode invalid', @TestDecodeInvalid);
  T.Run('nil nonzero span', @TestNilNonzeroSpan);
  T.Run('encode', @TestEncode);
  T.Run('encode nil destination fails closed', @TestEncodeNilDestinationFailsClosed);
  T.Run('isValid', @TestIsValid);
  T.Run('codepoint count', @TestCodePointCount);
  T.Run('string wrappers', @TestStringWrappers);
  T.Run('iterator', @TestIterator);
  T.Run('iterator invalid', @TestIteratorInvalid);
  T.Run('byte length', @TestByteLength);
  T.Summary;
end.
