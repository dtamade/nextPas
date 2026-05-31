unit nextpas.core.crypto.x25519;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.errors;

const
  X25519_KEY_SIZE = 32;

function ClampX25519Scalar(const AScalar: TBytes): TBytes;
function GenerateX25519PrivateKey: TBytes;
procedure GenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes);

function X25519ScalarMult(const AScalar, AInputU: TBytes): TBytes;
function X25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;
function X25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes): TBytes;

function TryX25519ScalarMult(const AScalar, AInputU: TBytes;
  out AResult: TBytes; out AError: string): Boolean;
function TryX25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes;
  out ASharedSecret: TBytes; out AError: string): Boolean;
function TryGenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes;
  out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.random,
  nextpas.core.crypto.field25519;

procedure EnsureKeyLength(const AValue: TBytes; const AParamName: string);
begin
  if Length(AValue) <> X25519_KEY_SIZE then
    RaiseInvalidParameter(AParamName);
end;

function IsAllZero(const AData: TBytes): Boolean;
var
  I: Integer;
  LOr: Byte;
begin
  LOr := 0;
  for I := 0 to High(AData) do
    LOr := LOr or AData[I];
  Result := LOr = 0;
end;

function ClampX25519Scalar(const AScalar: TBytes): TBytes;
begin
  EnsureKeyLength(AScalar, 'X25519Scalar');
  Result := nil;
  SetLength(Result, X25519_KEY_SIZE);
  Move(AScalar[0], Result[0], X25519_KEY_SIZE);
  Result[0] := Result[0] and $F8;
  Result[31] := (Result[31] and $7F) or $40;
end;

function GenerateX25519PrivateKey: TBytes;
begin
  Result := GenerateSecureRandomBytes(X25519_KEY_SIZE);
  EnsureKeyLength(Result, 'X25519PrivateKey');
  Result := ClampX25519Scalar(Result);
end;

procedure GenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes);
begin
  APrivateKey := GenerateX25519PrivateKey;
  APublicKey := X25519PublicKeyFromPrivate(APrivateKey);
end;

function X25519ScalarMult(const AScalar, AInputU: TBytes): TBytes;
var
  LClampedScalar: TBytes;
  LX1, LX2, LZ2, LX3, LZ3: TFe25519;
  LA, LB, LAA, LBB, LE: TFe25519;
  LC, LD, LDA, LCB: TFe25519;
  LT0, LT1: TFe25519;
  LA24: TFe25519;
  LSwap: Int64;
  LBit: Int64;
  I: Integer;
  LResultBytes: TBytes;
begin
  EnsureKeyLength(AScalar, 'X25519Scalar');
  EnsureKeyLength(AInputU, 'X25519InputU');

  LClampedScalar := ClampX25519Scalar(AScalar);

  FeFromBytes(LX1, AInputU, 0);
  LX2 := FE_ONE;
  LZ2 := FE_ZERO;
  FeCopy(LX3, LX1);
  LZ3 := FE_ONE;
  LA24 := FE_ZERO;
  LA24[0] := 121665;
  LSwap := 0;

  for I := 254 downto 0 do
  begin
    LBit := (LClampedScalar[I shr 3] shr (I and 7)) and 1;
    LSwap := LSwap xor LBit;

    FeCSwap(LX2, LX3, LSwap);
    FeCSwap(LZ2, LZ3, LSwap);
    LSwap := LBit;

    FeAdd(LA, LX2, LZ2);
    FeSub(LB, LX2, LZ2);
    FeSq(LAA, LA);
    FeSq(LBB, LB);
    FeSub(LE, LAA, LBB);

    FeAdd(LC, LX3, LZ3);
    FeSub(LD, LX3, LZ3);
    FeMul(LDA, LD, LA);
    FeMul(LCB, LC, LB);

    FeAdd(LT0, LDA, LCB);
    FeSq(LX3, LT0);

    FeSub(LT1, LDA, LCB);
    FeSq(LT1, LT1);
    FeMul(LZ3, LX1, LT1);

    FeMul(LX2, LAA, LBB);
    FeMul(LT0, LE, LA24);
    FeAdd(LT0, LAA, LT0);
    FeMul(LZ2, LE, LT0);
  end;

  FeCSwap(LX2, LX3, LSwap);
  FeCSwap(LZ2, LZ3, LSwap);

  FeInvert(LZ2, LZ2);
  FeMul(LX2, LX2, LZ2);
  FeToBytes(LResultBytes, LX2);
  Result := LResultBytes;
end;

function X25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;
var
  LBasePoint: TBytes;
begin
  EnsureKeyLength(APrivateKey, 'X25519PrivateKey');
  LBasePoint := nil;
  SetLength(LBasePoint, X25519_KEY_SIZE);
  FillChar(LBasePoint[0], X25519_KEY_SIZE, 0);
  LBasePoint[0] := 9;
  Result := X25519ScalarMult(APrivateKey, LBasePoint);
end;

function X25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes): TBytes;
begin
  EnsureKeyLength(APrivateKey, 'X25519PrivateKey');
  EnsureKeyLength(APeerPublicKey, 'X25519PeerPublicKey');
  Result := X25519ScalarMult(APrivateKey, APeerPublicKey);
  if IsAllZero(Result) then
    RaiseKeyDerivationError('X25519 shared secret is all-zero');
end;

function TryX25519ScalarMult(const AScalar, AInputU: TBytes;
  out AResult: TBytes; out AError: string): Boolean;
begin
  AError := '';
  SetLength(AResult, 0);
  if (Length(AScalar) <> X25519_KEY_SIZE) or (Length(AInputU) <> X25519_KEY_SIZE) then
  begin
    AError := 'X25519: scalar and input must be 32 bytes';
    Exit(False);
  end;
  try
    AResult := X25519ScalarMult(AScalar, AInputU);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TryX25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes;
  out ASharedSecret: TBytes; out AError: string): Boolean;
begin
  AError := '';
  SetLength(ASharedSecret, 0);
  if (Length(APrivateKey) <> X25519_KEY_SIZE) or (Length(APeerPublicKey) <> X25519_KEY_SIZE) then
  begin
    AError := 'X25519: keys must be 32 bytes';
    Exit(False);
  end;
  try
    ASharedSecret := X25519ScalarMult(APrivateKey, APeerPublicKey);
    if IsAllZero(ASharedSecret) then
    begin
      AError := 'X25519: shared secret is all-zero (invalid peer key)';
      SetLength(ASharedSecret, 0);
      Exit(False);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TryGenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes;
  out AError: string): Boolean;
begin
  AError := '';
  SetLength(APrivateKey, 0);
  SetLength(APublicKey, 0);
  try
    GenerateX25519KeyPair(APrivateKey, APublicKey);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

end.
