unit nextpas.core.tls.tls12.handshakecrypto;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TTLS12KeyBlock = record
    ClientWriteMACKey: TBytes;
    ServerWriteMACKey: TBytes;
    ClientWriteKey: TBytes;
    ServerWriteKey: TBytes;
    ClientWriteIV: TBytes;
    ServerWriteIV: TBytes;
  end;

function TLS12ComputeMasterSecret_SHA256(
  const APreMasterSecret: TBytes;
  const AClientRandom, AServerRandom: TBytes
): TBytes;

function TLS12ComputeMasterSecret_SHA384(
  const APreMasterSecret: TBytes;
  const AClientRandom, AServerRandom: TBytes
): TBytes;

function TLS12ComputeMasterSecret_EMS_SHA256(
  const APreMasterSecret: TBytes;
  const AHandshakeHash: TBytes
): TBytes;

function TLS12ComputeMasterSecret_EMS_SHA384(
  const APreMasterSecret: TBytes;
  const AHandshakeHash: TBytes
): TBytes;

function TLS12DeriveKeyBlock_SHA256(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;

function TLS12DeriveKeyBlock_SHA384(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;

function TLS12DeriveKeyBlockFull_SHA256(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AMACKeyLen, AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;

function TLS12DeriveKeyBlockFull_SHA384(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AMACKeyLen, AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;

function TLS12ComputeFinished_SHA256(
  const AMasterSecret: TBytes;
  const AHandshakeHash: TBytes;
  AIsClient: Boolean
): TBytes;

function TLS12ComputeFinished_SHA384(
  const AMasterSecret: TBytes;
  const AHandshakeHash: TBytes;
  AIsClient: Boolean
): TBytes;

implementation

uses
  nextpas.core.tls.crypto.tls12prf;

function TLS12ComputeMasterSecret_SHA256(
  const APreMasterSecret: TBytes;
  const AClientRandom, AServerRandom: TBytes
): TBytes;
var
  LSeed: TBytes;
begin
  SetLength(LSeed, 64);
  Move(AClientRandom[0], LSeed[0], 32);
  Move(AServerRandom[0], LSeed[32], 32);
  Result := TLS12PRF_SHA256(APreMasterSecret, 'master secret', LSeed, 48);
end;

function TLS12ComputeMasterSecret_SHA384(
  const APreMasterSecret: TBytes;
  const AClientRandom, AServerRandom: TBytes
): TBytes;
var
  LSeed: TBytes;
begin
  SetLength(LSeed, 64);
  Move(AClientRandom[0], LSeed[0], 32);
  Move(AServerRandom[0], LSeed[32], 32);
  Result := TLS12PRF_SHA384(APreMasterSecret, 'master secret', LSeed, 48);
end;

function TLS12ComputeMasterSecret_EMS_SHA256(
  const APreMasterSecret: TBytes;
  const AHandshakeHash: TBytes
): TBytes;
begin
  Result := TLS12PRF_SHA256(APreMasterSecret, 'extended master secret', AHandshakeHash, 48);
end;

function TLS12ComputeMasterSecret_EMS_SHA384(
  const APreMasterSecret: TBytes;
  const AHandshakeHash: TBytes
): TBytes;
begin
  Result := TLS12PRF_SHA384(APreMasterSecret, 'extended master secret', AHandshakeHash, 48);
end;

function DeriveKeyBlock(const AMasterSecret, AServerRandom, AClientRandom: TBytes;
  AMACKeyLen, AKeyLen, AIVLen: Integer; AUseSHA384: Boolean): TTLS12KeyBlock;
var
  LSeed, LKeyMaterial: TBytes;
  LNeeded, LOffset: Integer;
begin
  SetLength(LSeed, 64);
  Move(AServerRandom[0], LSeed[0], 32);
  Move(AClientRandom[0], LSeed[32], 32);

  LNeeded := 2 * AMACKeyLen + 2 * AKeyLen + 2 * AIVLen;
  if AUseSHA384 then
    LKeyMaterial := TLS12PRF_SHA384(AMasterSecret, 'key expansion', LSeed, LNeeded)
  else
    LKeyMaterial := TLS12PRF_SHA256(AMasterSecret, 'key expansion', LSeed, LNeeded);

  LOffset := 0;

  SetLength(Result.ClientWriteMACKey, AMACKeyLen);
  if AMACKeyLen > 0 then
    Move(LKeyMaterial[LOffset], Result.ClientWriteMACKey[0], AMACKeyLen);
  Inc(LOffset, AMACKeyLen);

  SetLength(Result.ServerWriteMACKey, AMACKeyLen);
  if AMACKeyLen > 0 then
    Move(LKeyMaterial[LOffset], Result.ServerWriteMACKey[0], AMACKeyLen);
  Inc(LOffset, AMACKeyLen);

  SetLength(Result.ClientWriteKey, AKeyLen);
  Move(LKeyMaterial[LOffset], Result.ClientWriteKey[0], AKeyLen);
  Inc(LOffset, AKeyLen);

  SetLength(Result.ServerWriteKey, AKeyLen);
  Move(LKeyMaterial[LOffset], Result.ServerWriteKey[0], AKeyLen);
  Inc(LOffset, AKeyLen);

  SetLength(Result.ClientWriteIV, AIVLen);
  if AIVLen > 0 then
    Move(LKeyMaterial[LOffset], Result.ClientWriteIV[0], AIVLen);
  Inc(LOffset, AIVLen);

  SetLength(Result.ServerWriteIV, AIVLen);
  Move(LKeyMaterial[LOffset], Result.ServerWriteIV[0], AIVLen);
end;

function TLS12DeriveKeyBlock_SHA256(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;
begin
  Result := DeriveKeyBlock(AMasterSecret, AServerRandom, AClientRandom, 0, AKeyLen, AIVLen, False);
end;

function TLS12DeriveKeyBlock_SHA384(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;
begin
  Result := DeriveKeyBlock(AMasterSecret, AServerRandom, AClientRandom, 0, AKeyLen, AIVLen, True);
end;

function TLS12DeriveKeyBlockFull_SHA256(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AMACKeyLen, AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;
begin
  Result := DeriveKeyBlock(AMasterSecret, AServerRandom, AClientRandom, AMACKeyLen, AKeyLen, AIVLen, False);
end;

function TLS12DeriveKeyBlockFull_SHA384(
  const AMasterSecret: TBytes;
  const AServerRandom, AClientRandom: TBytes;
  AMACKeyLen, AKeyLen, AIVLen: Integer
): TTLS12KeyBlock;
begin
  Result := DeriveKeyBlock(AMasterSecret, AServerRandom, AClientRandom, AMACKeyLen, AKeyLen, AIVLen, True);
end;

function TLS12ComputeFinished_SHA256(
  const AMasterSecret: TBytes;
  const AHandshakeHash: TBytes;
  AIsClient: Boolean
): TBytes;
var
  LLabel: string;
begin
  if AIsClient then
    LLabel := 'client finished'
  else
    LLabel := 'server finished';
  Result := TLS12PRF_SHA256(AMasterSecret, LLabel, AHandshakeHash, 12);
end;

function TLS12ComputeFinished_SHA384(
  const AMasterSecret: TBytes;
  const AHandshakeHash: TBytes;
  AIsClient: Boolean
): TBytes;
var
  LLabel: string;
begin
  if AIsClient then
    LLabel := 'client finished'
  else
    LLabel := 'server finished';
  Result := TLS12PRF_SHA384(AMasterSecret, LLabel, AHandshakeHash, 12);
end;

end.
