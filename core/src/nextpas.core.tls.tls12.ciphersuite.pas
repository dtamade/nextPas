unit nextpas.core.tls.tls12.ciphersuite;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TTLS12CipherSuiteList = array of Word;

  TTLS12RecordMode = (rmGCM, rmCBC, rmChaCha20Poly1305);
  TTLS12KeyExchange = (kxECDHE);
  TTLS12AuthType = (atRSA, atECDSA);
  TTLS12PRFHash = (phSHA256, phSHA384);

  TTLS12CipherSuiteInfo = record
    ID: Word;
    Name: string;
    KeyExchange: TTLS12KeyExchange;
    AuthType: TTLS12AuthType;
    RecordMode: TTLS12RecordMode;
    KeyLen: Integer;
    IVLen: Integer;
    MACKeyLen: Integer;
    PRFHash: TTLS12PRFHash;
  end;

function TLS12GetCipherSuiteInfo(AID: Word; out AInfo: TTLS12CipherSuiteInfo): Boolean;
function TLS12CipherSuiteIsCBC(AID: Word): Boolean;
function TLS12CipherSuiteUseSHA384(AID: Word): Boolean;
function TLS12CipherSuiteKeyLen(AID: Word): Integer;
function TLS12CipherSuiteMACKeyLen(AID: Word): Integer;

implementation

uses
  nextpas.core.tls.tls12.wire;

const
  SUITE_COUNT = 8;
  SUITES: array[0..SUITE_COUNT-1] of TTLS12CipherSuiteInfo = (
    (ID: $C02F; Name: 'ECDHE-RSA-AES128-GCM-SHA256';
     KeyExchange: kxECDHE; AuthType: atRSA; RecordMode: rmGCM;
     KeyLen: 16; IVLen: 4; MACKeyLen: 0; PRFHash: phSHA256),
    (ID: $C030; Name: 'ECDHE-RSA-AES256-GCM-SHA384';
     KeyExchange: kxECDHE; AuthType: atRSA; RecordMode: rmGCM;
     KeyLen: 32; IVLen: 4; MACKeyLen: 0; PRFHash: phSHA384),
    (ID: $C02B; Name: 'ECDHE-ECDSA-AES128-GCM-SHA256';
     KeyExchange: kxECDHE; AuthType: atECDSA; RecordMode: rmGCM;
     KeyLen: 16; IVLen: 4; MACKeyLen: 0; PRFHash: phSHA256),
    (ID: $C02C; Name: 'ECDHE-ECDSA-AES256-GCM-SHA384';
     KeyExchange: kxECDHE; AuthType: atECDSA; RecordMode: rmGCM;
     KeyLen: 32; IVLen: 4; MACKeyLen: 0; PRFHash: phSHA384),
    (ID: $C027; Name: 'ECDHE-RSA-AES128-CBC-SHA256';
     KeyExchange: kxECDHE; AuthType: atRSA; RecordMode: rmCBC;
     KeyLen: 16; IVLen: 0; MACKeyLen: 32; PRFHash: phSHA256),
    (ID: $C028; Name: 'ECDHE-RSA-AES256-CBC-SHA384';
     KeyExchange: kxECDHE; AuthType: atRSA; RecordMode: rmCBC;
     KeyLen: 32; IVLen: 0; MACKeyLen: 48; PRFHash: phSHA384),
    (ID: $CCA8; Name: 'ECDHE-RSA-CHACHA20-POLY1305-SHA256';
     KeyExchange: kxECDHE; AuthType: atRSA; RecordMode: rmChaCha20Poly1305;
     KeyLen: 32; IVLen: 12; MACKeyLen: 0; PRFHash: phSHA256),
    (ID: $CCA9; Name: 'ECDHE-ECDSA-CHACHA20-POLY1305-SHA256';
     KeyExchange: kxECDHE; AuthType: atECDSA; RecordMode: rmChaCha20Poly1305;
     KeyLen: 32; IVLen: 12; MACKeyLen: 0; PRFHash: phSHA256)
  );

function TLS12GetCipherSuiteInfo(AID: Word; out AInfo: TTLS12CipherSuiteInfo): Boolean;
var
  I: Integer;
begin
  for I := 0 to SUITE_COUNT - 1 do
    if SUITES[I].ID = AID then
    begin
      AInfo := SUITES[I];
      Exit(True);
    end;
  Result := False;
end;

function TLS12CipherSuiteIsCBC(AID: Word): Boolean;
var
  LInfo: TTLS12CipherSuiteInfo;
begin
  if TLS12GetCipherSuiteInfo(AID, LInfo) then
    Result := LInfo.RecordMode = rmCBC
  else
    Result := False;
end;

function TLS12CipherSuiteUseSHA384(AID: Word): Boolean;
var
  LInfo: TTLS12CipherSuiteInfo;
begin
  if TLS12GetCipherSuiteInfo(AID, LInfo) then
    Result := LInfo.PRFHash = phSHA384
  else
    Result := False;
end;

function TLS12CipherSuiteKeyLen(AID: Word): Integer;
var
  LInfo: TTLS12CipherSuiteInfo;
begin
  if TLS12GetCipherSuiteInfo(AID, LInfo) then
    Result := LInfo.KeyLen
  else
    Result := 0;
end;

function TLS12CipherSuiteMACKeyLen(AID: Word): Integer;
var
  LInfo: TTLS12CipherSuiteInfo;
begin
  if TLS12GetCipherSuiteInfo(AID, LInfo) then
    Result := LInfo.MACKeyLen
  else
    Result := 0;
end;

end.
