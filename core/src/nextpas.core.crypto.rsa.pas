unit nextpas.core.crypto.rsa;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv;

function TryRSAES_PKCS1v15_Encode(
  const AMessage: TBytes;
  AKeyOctetLength: Integer;
  out AEncodedMessage: TBytes;
  out AError: string
): Boolean;

function TryRSAES_PKCS1v15_Encrypt(
  const AMessage: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out ACiphertext: TBytes;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.tls.random,
  nextpas.core.crypto.bigint;

function TryRSAES_PKCS1v15_Encode(
  const AMessage: TBytes;
  AKeyOctetLength: Integer;
  out AEncodedMessage: TBytes;
  out AError: string
): Boolean;
var
  LMLen, LPSLen, I: Integer;
  LRandomByte: Byte;
begin
  SetLength(AEncodedMessage, 0);
  AError := '';
  Result := False;

  LMLen := Length(AMessage);
  if LMLen > AKeyOctetLength - 11 then
  begin
    AError := Format('Message too long for RSAES-PKCS1-v1_5 (mLen=%d, k=%d, max=%d)',
      [LMLen, AKeyOctetLength, AKeyOctetLength - 11]);
    Exit;
  end;

  LPSLen := AKeyOctetLength - LMLen - 3;

  SetLength(AEncodedMessage, AKeyOctetLength);
  AEncodedMessage[0] := $00;
  AEncodedMessage[1] := $02;

  for I := 0 to LPSLen - 1 do
  begin
    repeat
      SecureRandomBytes(@LRandomByte, 1);
    until LRandomByte <> 0;
    AEncodedMessage[2 + I] := LRandomByte;
  end;

  AEncodedMessage[2 + LPSLen] := $00;

  if LMLen > 0 then
    Move(AMessage[0], AEncodedMessage[3 + LPSLen], LMLen);

  Result := True;
end;

function TryRSAES_PKCS1v15_Encrypt(
  const AMessage: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out ACiphertext: TBytes;
  out AError: string
): Boolean;
var
  LEncoded: TBytes;
  LKeyLen: Integer;
  LResult: TBytes;
begin
  SetLength(ACiphertext, 0);
  AError := '';
  Result := False;

  LKeyLen := Length(AModulus);
  if (LKeyLen < 64) then
  begin
    AError := 'RSA modulus too short';
    Exit;
  end;

  if not TryRSAES_PKCS1v15_Encode(AMessage, LKeyLen, LEncoded, AError) then
    Exit;

  if not TryBigIntModExpFromUnsignedBytes(
    LEncoded,
    APublicExponent,
    AModulus,
    LResult,
    AError
  ) then
  begin
    AError := 'RSA modular exponentiation failed: ' + AError;
    Exit;
  end;

  if not TryBigIntToFixedLengthFromUnsignedBytes(
    LResult,
    LKeyLen,
    ACiphertext,
    AError
  ) then
  begin
    AError := 'RSA ciphertext sizing failed: ' + AError;
    Exit;
  end;

  Result := True;
end;

end.
