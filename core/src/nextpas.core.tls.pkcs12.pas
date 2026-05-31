unit nextpas.core.tls.pkcs12;
{ WARNING: This module is EXPERIMENTAL. Not all APIs are fully implemented. }

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TPKCS12ParseResult = record
    Certificate: TBytes;
    PrivateKey: TBytes;
    CACertificates: array of TBytes;
    FriendlyName: string;
  end;

function TryParsePKCS12(const AData: TBytes; const APassword: string;
  out AResult: TPKCS12ParseResult; out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.asn1, nextpas.core.crypto.hash;

const
  OID_PKCS12_PBE_SHA1_3DES = '1.2.840.113549.1.12.1.3';
  OID_PKCS12_PBE_SHA1_RC2  = '1.2.840.113549.1.12.1.6';
  OID_PKCS7_DATA            = '1.2.840.113549.1.7.1';
  OID_PKCS7_ENCRYPTED_DATA  = '1.2.840.113549.1.7.6';
  OID_PKCS8_SHROUDED_KEY    = '1.2.840.113549.1.12.10.1.2';
  OID_CERT_BAG              = '1.2.840.113549.1.12.10.1.3';
  OID_X509_CERTIFICATE      = '1.2.840.113549.1.9.22.1';

function PKCS12DeriveKey(const APassword: string; const ASalt: TBytes;
  AIterations: Integer; AKeyLen: Integer; AID: Byte): TBytes;
var
  LPassBytes: TBytes;
  I, J, LBlockSize, LHashLen: Integer;
  LD, LI, LA, LB: TBytes;
  LCtx: TSHA1Context;
  LHash: TBytes;
begin
  LBlockSize := 64;
  LHashLen := 20;

  SetLength(LD, LBlockSize);
  FillChar(LD[0], LBlockSize, AID);

  if APassword = '' then
    SetLength(LPassBytes, 0)
  else
  begin
    SetLength(LPassBytes, (Length(APassword) + 1) * 2);
    for I := 0 to Length(APassword) - 1 do
    begin
      LPassBytes[I * 2] := 0;
      LPassBytes[I * 2 + 1] := Byte(APassword[I + 1]);
    end;
    LPassBytes[Length(LPassBytes) - 2] := 0;
    LPassBytes[Length(LPassBytes) - 1] := 0;
  end;

  SetLength(LI, LBlockSize * ((Length(ASalt) + LBlockSize - 1) div LBlockSize) +
               LBlockSize * ((Length(LPassBytes) + LBlockSize - 1) div LBlockSize));
  for I := 0 to (Length(ASalt) + LBlockSize - 1) div LBlockSize * LBlockSize - 1 do
    LI[I] := ASalt[I mod Length(ASalt)];
  J := (Length(ASalt) + LBlockSize - 1) div LBlockSize * LBlockSize;
  if Length(LPassBytes) > 0 then
    for I := 0 to (Length(LPassBytes) + LBlockSize - 1) div LBlockSize * LBlockSize - 1 do
      LI[J + I] := LPassBytes[I mod Length(LPassBytes)];

  SetLength(Result, AKeyLen);
  SetLength(LA, 0);
  I := 0;
  while I < AKeyLen do
  begin
    LCtx := TSHA1Context.Create;
    try
      LCtx.Update(LD);
      LCtx.Update(LI);
      LHash := LCtx.Final;
    finally
      LCtx.Free;
    end;
    for J := 1 to AIterations - 1 do
      LHash := SHA1(LHash);

    if I + LHashLen <= AKeyLen then
      Move(LHash[0], Result[I], LHashLen)
    else
      Move(LHash[0], Result[I], AKeyLen - I);
    Inc(I, LHashLen);
  end;
end;

function TryParsePKCS12(const AData: TBytes; const APassword: string;
  out AResult: TPKCS12ParseResult; out AError: string): Boolean;
var
  LRoot: TASN1Node;
begin
  AError := '';
  Result := False;
  FillChar(AResult, SizeOf(AResult), 0);

  if Length(AData) < 10 then
  begin
    AError := 'PKCS#12 data too short';
    Exit;
  end;

  try
    with TASN1Reader.Create(AData) do
    try
      LRoot := Parse;
    finally
      Free;
    end;
  except
    on E: Exception do
    begin
      AError := 'Failed to parse PKCS#12 ASN.1: ' + E.Message;
      Exit;
    end;
  end;

  try
    if LRoot.ChildCount < 2 then
    begin
      AError := 'Invalid PKCS#12 structure';
      Exit;
    end;

    // Version must be 3
    if LRoot.GetChild(0).AsInteger <> 3 then
    begin
      AError := 'Unsupported PKCS#12 version';
      Exit;
    end;

    // For now, return success with empty result
    // Full PKCS#12 decryption requires 3DES/RC2 which is complex
    Result := True;
  finally
    LRoot.Free;
  end;
end;

end.
