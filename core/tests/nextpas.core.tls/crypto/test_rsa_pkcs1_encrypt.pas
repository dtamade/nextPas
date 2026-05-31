program test_rsa_pkcs1_encrypt;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.crypto.rsa;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

procedure TestRSAES_PKCS1v15_Encode;
var
  LMessage, LModulus, LExponent: TBytes;
  LEncoded: TBytes;
  LOk: Boolean;
  LError: string;
  PadEnd, I: Integer;
  AllNonZero: Boolean;
begin
  WriteLn('Test: RSAES-PKCS1-v1_5 encoding structure');
  SetLength(LMessage, 48);
  FillChar(LMessage[0], 48, $03);

  SetLength(LModulus, 256);
  FillChar(LModulus[0], 256, $FF);
  LModulus[0] := $C0;

  LOk := TryRSAES_PKCS1v15_Encode(LMessage, 256, LEncoded, LError);
  Check(LOk, 'Encoding should succeed');
  Check(Length(LEncoded) = 256, 'Encoded message should be k bytes');
  Check(LEncoded[0] = $00, 'First byte must be 0x00');
  Check(LEncoded[1] = $02, 'Second byte must be 0x02 (encryption)');

  PadEnd := -1;
  for I := 2 to Length(LEncoded) - 1 do
    if LEncoded[I] = $00 then
    begin
      PadEnd := I;
      Break;
    end;
  Check(PadEnd >= 10, 'Padding must be at least 8 bytes (separator at index >= 10)');
  Check(PadEnd = 256 - 48 - 1, 'Separator position should be k - mLen - 1');

  AllNonZero := True;
  for I := 2 to PadEnd - 1 do
    if LEncoded[I] = 0 then
      AllNonZero := False;
  Check(AllNonZero, 'Padding bytes must all be non-zero');
end;

procedure TestRSAES_PKCS1v15_MessageTooLong;
var
  LMessage: TBytes;
  LEncoded: TBytes;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: RSAES-PKCS1-v1_5 message too long');
  SetLength(LMessage, 256 - 11 + 1);
  FillChar(LMessage[0], Length(LMessage), $AA);

  LOk := TryRSAES_PKCS1v15_Encode(LMessage, 256, LEncoded, LError);
  Check(not LOk, 'Encoding should fail for message too long');
  Check(Length(LEncoded) = 0, 'No output on failure');
end;

procedure TestRSAES_PKCS1v15_TLS12PreMasterSecret;
var
  LPMS: TBytes;
  LEncoded: TBytes;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: RSAES-PKCS1-v1_5 TLS 1.2 pre_master_secret (48 bytes)');
  SetLength(LPMS, 48);
  LPMS[0] := $03;
  LPMS[1] := $03;
  FillChar(LPMS[2], 46, $AB);

  LOk := TryRSAES_PKCS1v15_Encode(LPMS, 256, LEncoded, LError);
  Check(LOk, 'TLS 1.2 PMS encoding should succeed');
  Check(Length(LEncoded) = 256, 'Encoded PMS should be 256 bytes (2048-bit RSA)');
end;

procedure TestRSAES_PKCS1v15_Randomness;
var
  LMessage: TBytes;
  LEncoded1, LEncoded2: TBytes;
  LOk: Boolean;
  LError: string;
  Same: Boolean;
  I: Integer;
begin
  WriteLn('Test: RSAES-PKCS1-v1_5 randomized padding');
  SetLength(LMessage, 48);
  FillChar(LMessage[0], 48, $CC);

  LOk := TryRSAES_PKCS1v15_Encode(LMessage, 256, LEncoded1, LError);
  Check(LOk, 'First encoding should succeed');

  LOk := TryRSAES_PKCS1v15_Encode(LMessage, 256, LEncoded2, LError);
  Check(LOk, 'Second encoding should succeed');

  Same := True;
  for I := 2 to 256 - 48 - 2 do
    if LEncoded1[I] <> LEncoded2[I] then
    begin
      Same := False;
      Break;
    end;
  Check(not Same, 'Two encodings of same message must have different random padding');
end;

begin
  WriteLn('=== RSA PKCS#1 v1.5 Encryption Tests ===');
  WriteLn('');

  TestRSAES_PKCS1v15_Encode;
  TestRSAES_PKCS1v15_MessageTooLong;
  TestRSAES_PKCS1v15_TLS12PreMasterSecret;
  TestRSAES_PKCS1v15_Randomness;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
