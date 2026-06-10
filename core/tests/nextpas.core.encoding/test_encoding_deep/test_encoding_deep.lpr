program test_encoding_deep;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.encoding,
  nextpas.core.encoding.base;

var
  T: TTestRunner;

function StrToBytes(const AStr: string): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AStr));
  for LI := 1 to Length(AStr) do
    Result[LI - 1] := Ord(AStr[LI]);
end;

function BytesToStr(const AData: TBytes): string;
var
  LI: Integer;
begin
  SetLength(Result, Length(AData));
  for LI := 0 to High(AData) do
    Result[LI + 1] := Chr(AData[LI]);
end;

function BytesEqual(const A, B: TBytes): Boolean;
var
  LI: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for LI := 0 to High(A) do
    if A[LI] <> B[LI] then Exit(False);
  Result := True;
end;

procedure ExpectConvertError(const AProc: TProcedure; const AMessage: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc;
  except
    on E: EConvertError do
      LRaised := True;
  end;
  Check(LRaised, AMessage);
end;

{ ===== Base64 RFC 4648 Test Vectors ===== }

procedure TestBase64RFC4648Empty;
var LData: TBytes;
begin
  SetLength(LData, 0);
  CheckEqual('', Base64Encode(LData));
  LData := Base64Decode('');
  CheckEqual(Int64(0), Int64(Length(LData)));
end;

{ RFC 4648 Section 10 test vectors }
procedure TestBase64RFC4648_f;
begin
  CheckEqual('Zg==', Base64Encode(StrToBytes('f')));
  CheckEqual('f', BytesToStr(Base64Decode('Zg==')));
end;

procedure TestBase64RFC4648_fo;
begin
  CheckEqual('Zm8=', Base64Encode(StrToBytes('fo')));
  CheckEqual('fo', BytesToStr(Base64Decode('Zm8=')));
end;

procedure TestBase64RFC4648_foo;
begin
  CheckEqual('Zm9v', Base64Encode(StrToBytes('foo')));
  CheckEqual('foo', BytesToStr(Base64Decode('Zm9v')));
end;

procedure TestBase64RFC4648_foob;
begin
  CheckEqual('Zm9vYg==', Base64Encode(StrToBytes('foob')));
  CheckEqual('foob', BytesToStr(Base64Decode('Zm9vYg==')));
end;

procedure TestBase64RFC4648_fooba;
begin
  CheckEqual('Zm9vYmE=', Base64Encode(StrToBytes('fooba')));
  CheckEqual('fooba', BytesToStr(Base64Decode('Zm9vYmE=')));
end;

procedure TestBase64RFC4648_foobar;
begin
  CheckEqual('Zm9vYmFy', Base64Encode(StrToBytes('foobar')));
  CheckEqual('foobar', BytesToStr(Base64Decode('Zm9vYmFy')));
end;

procedure TestBase64AllZeros;
var LData, LDec: TBytes;
begin
  SetLength(LData, 3);
  LData[0] := 0; LData[1] := 0; LData[2] := 0;
  CheckEqual('AAAA', Base64Encode(LData));
  LDec := Base64Decode('AAAA');
  Check(BytesEqual(LData, LDec), 'all zeros round-trip');
end;

procedure TestBase64AllOnes;
var LData, LDec: TBytes;
begin
  SetLength(LData, 3);
  LData[0] := $FF; LData[1] := $FF; LData[2] := $FF;
  CheckEqual('////', Base64Encode(LData));
  LDec := Base64Decode('////');
  Check(BytesEqual(LData, LDec), 'all ones round-trip');
end;

procedure TestBase64PaddingOneByte;
var LData, LDec: TBytes;
begin
  { Single byte -> 2 chars + == }
  SetLength(LData, 1);
  LData[0] := $AB;
  LDec := Base64Decode(Base64Encode(LData));
  Check(BytesEqual(LData, LDec), 'single byte round-trip');
end;

procedure TestBase64PaddingTwoBytes;
var LData, LDec: TBytes;
begin
  { Two bytes -> 3 chars + = }
  SetLength(LData, 2);
  LData[0] := $AB; LData[1] := $CD;
  LDec := Base64Decode(Base64Encode(LData));
  Check(BytesEqual(LData, LDec), 'two bytes round-trip');
end;

procedure TestBase64LargeRoundTrip;
var LData, LDec: TBytes;
    LI: Integer;
begin
  SetLength(LData, 256);
  for LI := 0 to 255 do
    LData[LI] := Byte(LI);
  LDec := Base64Decode(Base64Encode(LData));
  Check(BytesEqual(LData, LDec), '256-byte round-trip');
end;

procedure TestBase64InvalidChar;
var LGotException: Boolean;
begin
  LGotException := False;
  try
    Base64Decode('Z!!!');
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'should raise on invalid char');
end;

{ ===== Base64 URL-safe ===== }

procedure TestBase64UrlNoPadding;
var LData: TBytes;
    LEnc: string;
begin
  SetLength(LData, 1);
  LData[0] := $FB;
  LEnc := Base64UrlEncode(LData);
  { URL-safe should not have padding }
  Check(Pos('=', LEnc) = 0, 'URL-safe should not pad');
end;

procedure TestBase64UrlSpecialChars;
var LData, LDec: TBytes;
begin
  { Bytes that produce + and / in standard base64 }
  SetLength(LData, 3);
  LData[0] := $FB; LData[1] := $FF; LData[2] := $BE;
  CheckEqual('-_--', Base64UrlEncode(LData));
  LDec := Base64UrlDecode('-_--');
  Check(BytesEqual(LData, LDec), 'URL-safe round-trip');
end;

procedure TestBase64UrlRoundTrip;
var LData, LDec: TBytes;
    LI: Integer;
begin
  SetLength(LData, 100);
  for LI := 0 to 99 do
    LData[LI] := Byte(LI * 3);
  LDec := Base64UrlDecode(Base64UrlEncode(LData));
  Check(BytesEqual(LData, LDec), 'URL-safe 100-byte round-trip');
end;

{ ===== Hex ===== }

procedure TestHexRFC4648Empty;
var LData: TBytes;
begin
  SetLength(LData, 0);
  CheckEqual('', HexEncode(LData));
  LData := HexDecode('');
  CheckEqual(Int64(0), Int64(Length(LData)));
end;

procedure TestHexKnownVectors;
var LData, LDec: TBytes;
begin
  SetLength(LData, 5);
  LData[0] := $48; LData[1] := $65; LData[2] := $6C;
  LData[3] := $6C; LData[4] := $6F;
  CheckEqual('48656c6c6f', HexEncode(LData, hcLower));
  CheckEqual('48656C6C6F', HexEncode(LData, hcUpper));
  LDec := HexDecode('48656c6c6f');
  Check(BytesEqual(LData, LDec), 'hex decode lowercase');
  LDec := HexDecode('48656C6C6F');
  Check(BytesEqual(LData, LDec), 'hex decode uppercase');
end;

procedure TestHexAllBytes;
var LData, LDec: TBytes;
    LI: Integer;
begin
  SetLength(LData, 256);
  for LI := 0 to 255 do
    LData[LI] := Byte(LI);
  LDec := HexDecode(HexEncode(LData));
  Check(BytesEqual(LData, LDec), 'all 256 byte values round-trip');
end;

procedure TestHexOddLength;
var LGotException: Boolean;
begin
  LGotException := False;
  try
    HexDecode('abc');
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'odd-length hex should raise');
end;

procedure TestHexInvalidChars;
var LGotException: Boolean;
begin
  LGotException := False;
  try
    HexDecode('ZZZZ');
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'invalid hex chars should raise');
end;

procedure TestHexMixedCase;
var LDec: TBytes;
begin
  LDec := HexDecode('aAbBcCdDeEfF');
  CheckEqual(Int64(6), Int64(Length(LDec)));
  Check(LDec[0] = $AA, 'mixed case byte 0');
  Check(LDec[1] = $BB, 'mixed case byte 1');
  Check(LDec[2] = $CC, 'mixed case byte 2');
  Check(LDec[3] = $DD, 'mixed case byte 3');
  Check(LDec[4] = $EE, 'mixed case byte 4');
  Check(LDec[5] = $FF, 'mixed case byte 5');
end;

{ ===== URL Encoding ===== }

procedure TestUrlEmpty;
begin
  CheckEqual('', UrlEncode(''));
  CheckEqual('', UrlDecode(''));
end;

procedure TestUrlUnreservedPassthrough;
begin
  CheckEqual('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~',
    UrlEncode('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~'));
end;

procedure TestUrlSpaceEncoding;
begin
  CheckEqual('%20', UrlEncode(' '));
  CheckEqual(' ', UrlDecode('%20'));
  { + decodes to space (form encoding) }
  CheckEqual(' ', UrlDecode('+'));
end;

procedure TestUrlSpecialChars;
begin
  CheckEqual('%21', UrlEncode('!'));
  CheckEqual('%23', UrlEncode('#'));
  CheckEqual('%24', UrlEncode('$'));
  CheckEqual('%26', UrlEncode('&'));
  CheckEqual('%27', UrlEncode(''''));
  CheckEqual('%2F', UrlEncode('/'));
  CheckEqual('%3A', UrlEncode(':'));
  CheckEqual('%3B', UrlEncode(';'));
  CheckEqual('%3D', UrlEncode('='));
  CheckEqual('%3F', UrlEncode('?'));
  CheckEqual('%40', UrlEncode('@'));
end;

procedure TestUrlRoundTrip;
var LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'hello world & foo=bar';
  LEncoded := UrlEncode(LOriginal);
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded);
end;

procedure TestUrlUTF8Bytes;
begin
  { UTF-8 for Chinese chars }
  CheckEqual('%E4%BD%A0%E5%A5%BD', UrlEncode(#$E4#$BD#$A0#$E5#$A5#$BD));
  CheckEqual(#$E4#$BD#$A0#$E5#$A5#$BD, UrlDecode('%E4%BD%A0%E5%A5%BD'));
end;

procedure TestUrlDecodeRejectsMalformedUTF8PercentBytes;
begin
  CheckEqual(#$E4#$BD#$A0#$E5#$A5#$BD, UrlDecode('%E4%BD%A0%E5%A5%BD'));
  ExpectConvertError(
    procedure
    begin
      UrlDecode('%C0%80');
    end,
    'overlong UTF-8 percent bytes should raise'
  );
  ExpectConvertError(
    procedure
    begin
      UrlDecode('%80');
    end,
    'lone continuation percent byte should raise'
  );
  ExpectConvertError(
    procedure
    begin
      UrlDecode('%E2%82');
    end,
    'truncated UTF-8 percent sequence should raise'
  );
  ExpectConvertError(
    procedure
    begin
      UrlDecode('%ED%A0%80');
    end,
    'surrogate UTF-8 percent bytes should raise'
  );
end;

procedure TestUrlAlreadyEncoded;
begin
  { Encoding an already-encoded string should double-encode }
  CheckEqual('%2525', UrlEncode('%25'));
  CheckEqual('%25', UrlDecode('%2525'));
end;

procedure TestUrlTruncatedPercent;
var LGotException: Boolean;
begin
  LGotException := False;
  try
    UrlDecode('%2');
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'truncated percent should raise');
end;

procedure TestUrlInvalidPercentHex;
var LGotException: Boolean;
begin
  LGotException := False;
  try
    UrlDecode('%ZZ');
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'invalid percent hex should raise');
end;

{ ===== Varint ===== }

procedure TestVarintZeroDeep;
var LData: TBytes;
    LRead: Integer;
begin
  LData := VarintEncode(0);
  CheckEqual(Int64(1), Int64(Length(LData)));
  Check(LData[0] = 0, 'varint(0) = [0x00]');
  CheckEqual(Int64(0), Int64(VarintDecode(LData, LRead)));
  CheckEqual(Int64(1), Int64(LRead));
end;

procedure TestVarintOneByte;
var LData: TBytes;
    LRead: Integer;
begin
  LData := VarintEncode(1);
  CheckEqual(Int64(1), Int64(Length(LData)));
  Check(LData[0] = 1, 'varint(1) = [0x01]');
  CheckEqual(Int64(1), Int64(VarintDecode(LData, LRead)));

  LData := VarintEncode(127);
  CheckEqual(Int64(1), Int64(Length(LData)));
  Check(LData[0] = 127, 'varint(127) = [0x7F]');
  CheckEqual(Int64(127), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarintTwoBytes;
var LData: TBytes;
    LRead: Integer;
begin
  LData := VarintEncode(128);
  CheckEqual(Int64(2), Int64(Length(LData)));
  Check(LData[0] = $80, 'varint(128)[0]');
  Check(LData[1] = $01, 'varint(128)[1]');
  CheckEqual(Int64(128), Int64(VarintDecode(LData, LRead)));
  CheckEqual(Int64(2), Int64(LRead));

  LData := VarintEncode(16383);
  CheckEqual(Int64(2), Int64(Length(LData)));
  Check(LData[0] = $FF, 'varint(16383)[0]');
  Check(LData[1] = $7F, 'varint(16383)[1]');
  CheckEqual(Int64(16383), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarintThreeBytes;
var LData: TBytes;
    LRead: Integer;
begin
  LData := VarintEncode(16384);
  CheckEqual(Int64(3), Int64(Length(LData)));
  CheckEqual(Int64(16384), Int64(VarintDecode(LData, LRead)));
  CheckEqual(Int64(3), Int64(LRead));
end;

procedure TestVarintMaxUInt64Deep;
var LData: TBytes;
    LRead: Integer;
    LVal: UInt64;
begin
  LData := VarintEncode(High(UInt64));
  CheckEqual(Int64(10), Int64(Length(LData)));
  LVal := VarintDecode(LData, LRead);
  Check(LVal = High(UInt64), 'max uint64 round-trip');
  CheckEqual(Int64(10), Int64(LRead));
end;

procedure TestVarintProtobufVector300;
var LData: TBytes;
    LRead: Integer;
begin
  { protobuf spec: 300 = 0xAC 0x02 }
  LData := VarintEncode(300);
  CheckEqual(Int64(2), Int64(Length(LData)));
  Check(LData[0] = $AC, 'varint(300)[0] = 0xAC');
  Check(LData[1] = $02, 'varint(300)[1] = 0x02');
  CheckEqual(Int64(300), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarintOverflow;
var LData: TBytes;
    LRead: Integer;
    LGotException: Boolean;
begin
  { 11 continuation bytes = overflow }
  SetLength(LData, 11);
  LData[0] := $80; LData[1] := $80; LData[2] := $80;
  LData[3] := $80; LData[4] := $80; LData[5] := $80;
  LData[6] := $80; LData[7] := $80; LData[8] := $80;
  LData[9] := $80; LData[10] := $01;
  LGotException := False;
  try
    VarintDecode(LData, LRead);
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'varint overflow should raise');
end;

procedure TestVarintEmptyInput;
var LData: TBytes;
    LRead: Integer;
    LGotException: Boolean;
begin
  SetLength(LData, 0);
  LGotException := False;
  try
    VarintDecode(LData, LRead);
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'empty varint should raise');
end;

procedure TestVarintNonCanonicalEncoding;
var
  LData: TBytes;
  LRead: Integer;
  LGotException: Boolean;
begin
  SetLength(LData, 2);
  LData[0] := $80;
  LData[1] := $00;
  LGotException := False;
  try
    VarintDecode(LData, LRead);
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'overlong zero varint should raise');

  LData[0] := $81;
  LData[1] := $00;
  LGotException := False;
  try
    SignedVarintDecode(LData, LRead);
  except
    on E: EConvertError do
      LGotException := True;
  end;
  Check(LGotException, 'overlong signed varint should raise');
end;

procedure TestSignedVarintZigZag;
var LData: TBytes;
    LRead: Integer;
begin
  { ZigZag: 0->0, -1->1, 1->2, -2->3, 2->4 }
  LData := SignedVarintEncode(0);
  CheckEqual(Int64(0), Int64(SignedVarintDecode(LData, LRead)));

  LData := SignedVarintEncode(-1);
  CheckEqual(Int64(-1), Int64(SignedVarintDecode(LData, LRead)));

  LData := SignedVarintEncode(1);
  CheckEqual(Int64(1), Int64(SignedVarintDecode(LData, LRead)));

  LData := SignedVarintEncode(-2);
  CheckEqual(Int64(-2), Int64(SignedVarintDecode(LData, LRead)));

  LData := SignedVarintEncode(2147483647);
  CheckEqual(Int64(2147483647), Int64(SignedVarintDecode(LData, LRead)));

  LData := SignedVarintEncode(-2147483648);
  CheckEqual(Int64(-2147483648), Int64(SignedVarintDecode(LData, LRead)));
end;

{ ===== Main ===== }

begin
  T := TTestRunner.Create('nextpas.core.encoding.deep');

  { Base64 RFC 4648 }
  T.Run('Base64 RFC4648 empty', @TestBase64RFC4648Empty);
  T.Run('Base64 RFC4648 "f"', @TestBase64RFC4648_f);
  T.Run('Base64 RFC4648 "fo"', @TestBase64RFC4648_fo);
  T.Run('Base64 RFC4648 "foo"', @TestBase64RFC4648_foo);
  T.Run('Base64 RFC4648 "foob"', @TestBase64RFC4648_foob);
  T.Run('Base64 RFC4648 "fooba"', @TestBase64RFC4648_fooba);
  T.Run('Base64 RFC4648 "foobar"', @TestBase64RFC4648_foobar);
  T.Run('Base64 all zeros', @TestBase64AllZeros);
  T.Run('Base64 all ones', @TestBase64AllOnes);
  T.Run('Base64 padding 1 byte', @TestBase64PaddingOneByte);
  T.Run('Base64 padding 2 bytes', @TestBase64PaddingTwoBytes);
  T.Run('Base64 large round-trip', @TestBase64LargeRoundTrip);
  T.Run('Base64 invalid char', @TestBase64InvalidChar);

  { Base64 URL-safe }
  T.Run('Base64URL no padding', @TestBase64UrlNoPadding);
  T.Run('Base64URL special chars', @TestBase64UrlSpecialChars);
  T.Run('Base64URL round-trip', @TestBase64UrlRoundTrip);

  { Hex }
  T.Run('Hex empty', @TestHexRFC4648Empty);
  T.Run('Hex known vectors', @TestHexKnownVectors);
  T.Run('Hex all bytes', @TestHexAllBytes);
  T.Run('Hex odd length', @TestHexOddLength);
  T.Run('Hex invalid chars', @TestHexInvalidChars);
  T.Run('Hex mixed case', @TestHexMixedCase);

  { URL }
  T.Run('URL empty', @TestUrlEmpty);
  T.Run('URL unreserved passthrough', @TestUrlUnreservedPassthrough);
  T.Run('URL space encoding', @TestUrlSpaceEncoding);
  T.Run('URL special chars', @TestUrlSpecialChars);
  T.Run('URL round-trip', @TestUrlRoundTrip);
  T.Run('URL UTF-8 bytes', @TestUrlUTF8Bytes);
  T.Run('URL malformed UTF-8 percent bytes', @TestUrlDecodeRejectsMalformedUTF8PercentBytes);
  T.Run('URL already encoded', @TestUrlAlreadyEncoded);
  T.Run('URL truncated percent', @TestUrlTruncatedPercent);
  T.Run('URL invalid percent hex', @TestUrlInvalidPercentHex);

  { Varint }
  T.Run('Varint zero', @TestVarintZeroDeep);
  T.Run('Varint one byte', @TestVarintOneByte);
  T.Run('Varint two bytes', @TestVarintTwoBytes);
  T.Run('Varint three bytes', @TestVarintThreeBytes);
  T.Run('Varint max UInt64', @TestVarintMaxUInt64Deep);
  T.Run('Varint protobuf 300', @TestVarintProtobufVector300);
  T.Run('Varint overflow', @TestVarintOverflow);
  T.Run('Varint empty input', @TestVarintEmptyInput);
  T.Run('Varint non-canonical encoding', @TestVarintNonCanonicalEncoding);
  T.Run('Signed varint zigzag', @TestSignedVarintZigZag);

  T.Summary;
end.
