program test_encoding;

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

{ Base64 tests }

procedure TestBase64Empty;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  CheckEqual('', Base64Encode(LData));
  LData := Base64Decode('');
  CheckEqual(Int64(0), Int64(Length(LData)));
end;

procedure TestBase64F;
begin
  CheckEqual('Zg==', Base64Encode(StrToBytes('f')));
  CheckEqual('f', BytesToStr(Base64Decode('Zg==')));
end;

procedure TestBase64Fo;
begin
  CheckEqual('Zm8=', Base64Encode(StrToBytes('fo')));
  CheckEqual('fo', BytesToStr(Base64Decode('Zm8=')));
end;

procedure TestBase64Foo;
begin
  CheckEqual('Zm9v', Base64Encode(StrToBytes('foo')));
  CheckEqual('foo', BytesToStr(Base64Decode('Zm9v')));
end;

procedure TestBase64Foobar;
begin
  CheckEqual('Zm9vYmFy', Base64Encode(StrToBytes('foobar')));
  CheckEqual('foobar', BytesToStr(Base64Decode('Zm9vYmFy')));
end;

procedure TestBase64Binary;
var
  LData, LDecoded: TBytes;
begin
  SetLength(LData, 4);
  LData[0] := $00; LData[1] := $FF; LData[2] := $80; LData[3] := $7F;
  CheckEqual('AP+Afw==', Base64Encode(LData));
  LDecoded := Base64Decode('AP+Afw==');
  CheckEqual(Int64(4), Int64(Length(LDecoded)));
  Check(LDecoded[0] = $00);
  Check(LDecoded[1] = $FF);
  Check(LDecoded[2] = $80);
  Check(LDecoded[3] = $7F);
end;

procedure TestBase64UrlSafe;
var
  LData, LDecoded: TBytes;
begin
  SetLength(LData, 3);
  LData[0] := $FB; LData[1] := $FF; LData[2] := $BE;
  CheckEqual('-_--', Base64UrlEncode(LData));
  LDecoded := Base64UrlDecode('-_--');
  CheckEqual(Int64(3), Int64(Length(LDecoded)));
  Check(LDecoded[0] = $FB);
  Check(LDecoded[1] = $FF);
  Check(LDecoded[2] = $BE);
end;

{ Hex tests }

procedure TestHexEmpty;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  CheckEqual('', HexEncode(LData));
  LData := HexDecode('');
  CheckEqual(Int64(0), Int64(Length(LData)));
end;

procedure TestHexSingleByte;
var
  LData: TBytes;
begin
  SetLength(LData, 1);
  LData[0] := $AB;
  CheckEqual('ab', HexEncode(LData, hcLower));
  CheckEqual('AB', HexEncode(LData, hcUpper));
end;

procedure TestHexMultiBytes;
var
  LData, LDecoded: TBytes;
begin
  SetLength(LData, 4);
  LData[0] := $DE; LData[1] := $AD; LData[2] := $BE; LData[3] := $EF;
  CheckEqual('deadbeef', HexEncode(LData));
  LDecoded := HexDecode('DEADBEEF');
  CheckEqual(Int64(4), Int64(Length(LDecoded)));
  Check(LDecoded[0] = $DE);
  Check(LDecoded[1] = $AD);
  Check(LDecoded[2] = $BE);
  Check(LDecoded[3] = $EF);
end;

{ Varint tests }

procedure TestVarintZero;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := VarintEncode(0);
  CheckEqual(Int64(1), Int64(Length(LData)));
  Check(LData[0] = 0);
  CheckEqual(Int64(0), Int64(VarintDecode(LData, LRead)));
  CheckEqual(Int64(1), Int64(LRead));
end;

procedure TestVarintOne;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := VarintEncode(1);
  CheckEqual(Int64(1), Int64(Length(LData)));
  CheckEqual(Int64(1), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarint127;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := VarintEncode(127);
  CheckEqual(Int64(1), Int64(Length(LData)));
  Check(LData[0] = 127);
  CheckEqual(Int64(127), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarint128;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := VarintEncode(128);
  CheckEqual(Int64(2), Int64(Length(LData)));
  Check(LData[0] = $80);
  Check(LData[1] = $01);
  CheckEqual(Int64(128), Int64(VarintDecode(LData, LRead)));
  CheckEqual(Int64(2), Int64(LRead));
end;

procedure TestVarint300;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := VarintEncode(300);
  CheckEqual(Int64(2), Int64(Length(LData)));
  CheckEqual(Int64(300), Int64(VarintDecode(LData, LRead)));
end;

procedure TestVarintMaxUInt64;
var
  LData: TBytes;
  LRead: Integer;
  LVal: UInt64;
begin
  LData := VarintEncode(High(UInt64));
  CheckEqual(Int64(10), Int64(Length(LData)));
  LVal := VarintDecode(LData, LRead);
  Check(LVal = High(UInt64));
end;

procedure TestSignedVarintPositive;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := SignedVarintEncode(1);
  CheckEqual(Int64(1), Int64(SignedVarintDecode(LData, LRead)));
  LData := SignedVarintEncode(150);
  CheckEqual(Int64(150), Int64(SignedVarintDecode(LData, LRead)));
end;

procedure TestSignedVarintNegative;
var
  LData: TBytes;
  LRead: Integer;
begin
  LData := SignedVarintEncode(-1);
  CheckEqual(Int64(-1), Int64(SignedVarintDecode(LData, LRead)));
  LData := SignedVarintEncode(-150);
  CheckEqual(Int64(-150), Int64(SignedVarintDecode(LData, LRead)));
end;

{ URL tests }

procedure TestUrlSpace;
begin
  CheckEqual('%20', UrlEncode(' '));
  CheckEqual(' ', UrlDecode('%20'));
  CheckEqual(' ', UrlDecode('+'));
end;

procedure TestUrlChinese;
var
  LEncoded: string;
begin
  LEncoded := UrlEncode(#$E4#$BD#$A0#$E5#$A5#$BD);
  CheckEqual('%E4%BD%A0%E5%A5%BD', LEncoded);
  CheckEqual(#$E4#$BD#$A0#$E5#$A5#$BD, UrlDecode(LEncoded));
end;

procedure TestUrlReserved;
begin
  CheckEqual('%26', UrlEncode('&'));
  CheckEqual('%3D', UrlEncode('='));
  CheckEqual('%3F', UrlEncode('?'));
  CheckEqual('%2F', UrlEncode('/'));
end;

procedure TestUrlNoDoubleEncode;
begin
  CheckEqual('%2525', UrlEncode('%25'));
end;

procedure TestUrlUnreserved;
begin
  CheckEqual('abc123-_.~', UrlEncode('abc123-_.~'));
end;

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.encoding');

  T.Run('Base64 empty', @TestBase64Empty);
  T.Run('Base64 "f"', @TestBase64F);
  T.Run('Base64 "fo"', @TestBase64Fo);
  T.Run('Base64 "foo"', @TestBase64Foo);
  T.Run('Base64 "foobar"', @TestBase64Foobar);
  T.Run('Base64 binary', @TestBase64Binary);
  T.Run('Base64 URL-safe', @TestBase64UrlSafe);

  T.Run('Hex empty', @TestHexEmpty);
  T.Run('Hex single byte', @TestHexSingleByte);
  T.Run('Hex multi bytes', @TestHexMultiBytes);

  T.Run('Varint 0', @TestVarintZero);
  T.Run('Varint 1', @TestVarintOne);
  T.Run('Varint 127', @TestVarint127);
  T.Run('Varint 128', @TestVarint128);
  T.Run('Varint 300', @TestVarint300);
  T.Run('Varint max UInt64', @TestVarintMaxUInt64);
  T.Run('Signed varint positive', @TestSignedVarintPositive);
  T.Run('Signed varint negative', @TestSignedVarintNegative);

  T.Run('URL space', @TestUrlSpace);
  T.Run('URL Chinese', @TestUrlChinese);
  T.Run('URL reserved chars', @TestUrlReserved);
  T.Run('URL no double encode', @TestUrlNoDoubleEncode);
  T.Run('URL unreserved passthrough', @TestUrlUnreserved);

  T.Summary;
end.
