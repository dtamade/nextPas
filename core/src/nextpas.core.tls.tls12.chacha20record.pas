unit nextpas.core.tls.tls12.chacha20record;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.exception,
  nextpas.core.base;

function TLS12ChaCha20Poly1305EncryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;

function TLS12ChaCha20Poly1305DecryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.tls.tls13.chacha20poly1305;

const
  TAG_LEN = 16;

function BuildNonce(const AImplicitNonce: TBytes; ASeqNum: UInt64): TBytes;
var
  LPaddedSeq: TBytes;
  I: Integer;
begin
  if Length(AImplicitNonce) <> 12 then
    raise Exception.Create('ChaCha20 implicit nonce must be 12 bytes');

  SetLength(LPaddedSeq, 12);
  FillChar(LPaddedSeq[0], 12, 0);
  LPaddedSeq[4] := Byte(ASeqNum shr 56);
  LPaddedSeq[5] := Byte(ASeqNum shr 48);
  LPaddedSeq[6] := Byte(ASeqNum shr 40);
  LPaddedSeq[7] := Byte(ASeqNum shr 32);
  LPaddedSeq[8] := Byte(ASeqNum shr 24);
  LPaddedSeq[9] := Byte(ASeqNum shr 16);
  LPaddedSeq[10] := Byte(ASeqNum shr 8);
  LPaddedSeq[11] := Byte(ASeqNum);

  SetLength(Result, 12);
  for I := 0 to 11 do
    Result[I] := AImplicitNonce[I] xor LPaddedSeq[I];
end;

function BuildAAD(ASeqNum: UInt64; AContentType: Byte; APlaintextLen: Integer): TBytes;
begin
  SetLength(Result, 13);
  Result[0] := Byte(ASeqNum shr 56);
  Result[1] := Byte(ASeqNum shr 48);
  Result[2] := Byte(ASeqNum shr 40);
  Result[3] := Byte(ASeqNum shr 32);
  Result[4] := Byte(ASeqNum shr 24);
  Result[5] := Byte(ASeqNum shr 16);
  Result[6] := Byte(ASeqNum shr 8);
  Result[7] := Byte(ASeqNum);
  Result[8] := AContentType;
  Result[9] := 3; // TLS 1.2 major
  Result[10] := 3; // TLS 1.2 minor
  Result[11] := Byte(APlaintextLen shr 8);
  Result[12] := Byte(APlaintextLen);
end;

function TLS12ChaCha20Poly1305EncryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;
var
  LNonce, LAAD: TBytes;
begin
  AError := '';
  SetLength(AEncrypted, 0);

  LNonce := BuildNonce(AImplicitNonce, ASeqNum);
  LAAD := BuildAAD(ASeqNum, AContentType, Length(APlaintext));

  if not TryChaCha20Poly1305EncryptCombined(AKey, LNonce, LAAD, APlaintext, AEncrypted) then
  begin
    AError := 'ChaCha20-Poly1305 encryption failed';
    Exit(False);
  end;

  Result := True;
end;

function TLS12ChaCha20Poly1305DecryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;
var
  LNonce, LAAD: TBytes;
  LPlaintextLen: Integer;
begin
  AError := '';
  SetLength(APlaintext, 0);

  if Length(AEncrypted) < TAG_LEN then
  begin
    AError := 'bad_record_mac';
    Exit(False);
  end;

  LPlaintextLen := Length(AEncrypted) - TAG_LEN;
  LNonce := BuildNonce(AImplicitNonce, ASeqNum);
  LAAD := BuildAAD(ASeqNum, AContentType, LPlaintextLen);

  if not TryChaCha20Poly1305DecryptCombined(AKey, LNonce, LAAD, AEncrypted, APlaintext) then
  begin
    AError := 'bad_record_mac';
    Exit(False);
  end;

  Result := True;
end;

end.
