unit nextpas.core.crypto.p256ecdh;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}

interface

uses
  nextpas.core.base;

const
  P256ECDH_PRIVATE_SIZE = 32;
  P256ECDH_PUBLIC_SIZE = 65;
  P256ECDH_SHARED_SIZE = 32;

procedure GenerateP256ECDHKeyPair(out APrivateKey, APublicKey: TBytes);
function TryGenerateP256ECDHKeyPair(out APrivateKey, APublicKey: TBytes; out AError: string): Boolean;
function TryP256ECDHSharedSecret(const APrivateKey, APeerPublicKey: TBytes; out ASharedSecret: TBytes; out AError: string): Boolean;

implementation

uses
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.random,
  nextpas.core.crypto.p256.field,
  nextpas.core.crypto.p256.point,
  nextpas.core.mem.secure,
  nextpas.core.errors;

const
  P256_ORDER_N: array[0..31] of Byte = (
    $FF, $FF, $FF, $FF, $00, $00, $00, $00,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $BC, $E6, $FA, $AD, $A7, $17, $9E, $84,
    $F3, $B9, $CA, $C2, $FC, $63, $25, $51
  );

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function IsZeroBytes(const A: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) = 0 then Exit(True);
  for I := 0 to High(A) do
    if A[I] <> 0 then Exit(False);
  Result := True;
end;

function CompareBigEndian(const A, B: TBytes): Integer;
var
  I: Integer;
  LA, LB: TBytes;
  LOffA, LOffB: Integer;
begin
  LA := A;
  LB := B;
  LOffA := 0;
  while (LOffA < Length(LA)) and (LA[LOffA] = 0) do Inc(LOffA);
  LOffB := 0;
  while (LOffB < Length(LB)) and (LB[LOffB] = 0) do Inc(LOffB);
  if (Length(LA) - LOffA) < (Length(LB) - LOffB) then Exit(-1);
  if (Length(LA) - LOffA) > (Length(LB) - LOffB) then Exit(1);
  for I := 0 to (Length(LA) - LOffA - 1) do
  begin
    if LA[LOffA + I] < LB[LOffB + I] then Exit(-1);
    if LA[LOffA + I] > LB[LOffB + I] then Exit(1);
  end;
  Result := 0;
end;

function IsValidPrivateScalar(const A: TBytes): Boolean;
var
  LOrder: TBytes;
begin
  if Length(A) <> 32 then Exit(False);
  if IsZeroBytes(A) then Exit(False);
  SetLength(LOrder, 32);
  Move(P256_ORDER_N[0], LOrder[0], 32);
  if CompareBigEndian(A, LOrder) >= 0 then Exit(False);
  Result := True;
end;

function TryEncodePublicKey(const APoint: TECPoint; out AEncoded: TBytes; out AError: string): Boolean;
var
  LX, LY: TBytes;
begin
  Result := False;
  SetLength(AEncoded, 0);
  AError := '';
  if APoint.IsInfinity then
  begin
    AError := 'P-256 ECDH point is infinity';
    Exit;
  end;
  if not TryToFixedLength32(APoint.X, LX, AError) then Exit;
  if not TryToFixedLength32(APoint.Y, LY, AError) then Exit;
  SetLength(AEncoded, 65);
  AEncoded[0] := $04;
  Move(LX[0], AEncoded[1], 32);
  Move(LY[0], AEncoded[33], 32);
  Result := True;
end;

function TryGenerateValidPrivate(out APriv: TBytes; out AError: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AError := '';
  SetLength(APriv, 0);
  for I := 0 to 255 do
  begin
    APriv := GenerateSecureRandomBytes(32);
    if IsValidPrivateScalar(APriv) then
      Exit(True);
    SecureZeroBytes(APriv);
    SetLength(APriv, 0);
  end;
  AError := 'P-256 ECDH failed to sample valid private scalar';
  Result := False;
end;

procedure GenerateP256ECDHKeyPair(out APrivateKey, APublicKey: TBytes);
var
  LError: string;
begin
  if not TryGenerateP256ECDHKeyPair(APrivateKey, APublicKey, LError) then
    raise EInvalidOperationError.Create('P-256 ECDH key generation failed: ' + LError);
end;

function TryGenerateP256ECDHKeyPair(out APrivateKey, APublicKey: TBytes; out AError: string): Boolean;
var
  LPoint: TECPoint;
begin
  Result := False;
  SetLength(APrivateKey, 0);
  SetLength(APublicKey, 0);
  AError := '';
  if not TryGenerateValidPrivate(APrivateKey, AError) then Exit;
  if not TryP256ScalarMultBase(APrivateKey, LPoint, AError) then
  begin
    SecureZeroBytes(APrivateKey);
    SetLength(APrivateKey, 0);
    AError := 'P-256 ECDH public key generation failed: ' + AError;
    Exit(False);
  end;
  if LPoint.IsInfinity then
  begin
    SecureZeroBytes(APrivateKey);
    SetLength(APrivateKey, 0);
    AError := 'P-256 ECDH generated infinity public key';
    Exit(False);
  end;
  if not TryEncodePublicKey(LPoint, APublicKey, AError) then
  begin
    SecureZeroBytes(APrivateKey);
    SetLength(APrivateKey, 0);
    SetLength(APublicKey, 0);
    Exit(False);
  end;
  Result := True;
end;

function TryP256ECDHSharedSecret(const APrivateKey, APeerPublicKey: TBytes; out ASharedSecret: TBytes; out AError: string): Boolean;
var
  LPeerPoint: TECPoint;
  LSharedPoint: TECPoint;
  LSharedX: TBytes;
  I: Integer;
  LZero: Boolean;
begin
  Result := False;
  SetLength(ASharedSecret, 0);
  AError := '';
  if not IsValidPrivateScalar(APrivateKey) then
  begin
    AError := 'P-256 ECDH private key is zero or out of range';
    Exit;
  end;
  if not TryParseP256PublicPoint(APeerPublicKey, LPeerPoint, AError) then
  begin
    AError := 'P-256 ECDH peer public key rejected: ' + AError;
    Exit;
  end;
  if not TryP256ScalarMult(APrivateKey, LPeerPoint, LSharedPoint, AError) then
  begin
    AError := 'P-256 ECDH shared secret computation failed: ' + AError;
    Exit;
  end;
  if LSharedPoint.IsInfinity then
  begin
    AError := 'P-256 ECDH shared secret is point at infinity';
    Exit;
  end;
  if not TryToFixedLength32(LSharedPoint.X, LSharedX, AError) then Exit;
  LZero := True;
  for I := 0 to High(LSharedX) do
    if LSharedX[I] <> 0 then
    begin
      LZero := False;
      Break;
    end;
  if LZero then
  begin
    SecureZeroBytes(LSharedX);
    AError := 'P-256 ECDH shared secret is all-zero';
    Exit;
  end;
  ASharedSecret := LSharedX;
  Result := True;
end;

end.
