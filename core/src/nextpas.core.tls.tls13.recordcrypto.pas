{**
 * Unit: nextpas.core.tls.tls13.recordcrypto
 * Purpose: TLS 1.3 记录层加密相关基础工具（不依赖外部库）
 *
 * 提供：
 * - TLSCiphertext AAD 构造
 * - 记录 nonce（static_iv XOR seq）
 * - TLSInnerPlaintext 编解码
 *}

unit nextpas.core.tls.tls13.recordcrypto;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.tls13.wire;

function BuildTLS13RecordAAD(AEncryptedLength: Word): TBytes;
function BuildTLS13RecordNonce(const AStaticIV: TBytes; ASequenceNumber: QWord): TBytes;

function BuildTLS13InnerPlaintext(const AFragment: TBytes; AContentType: Byte): TBytes;
function TryParseTLS13InnerPlaintext(const APlaintext: TBytes; out AFragment: TBytes; out AContentType: Byte): Boolean;

function IncrementTLS13Sequence(var ASequenceNumber: QWord): Boolean;

implementation

uses
  nextpas.core.tls.errors;

const
  TLS13_IV_SIZE = 12;

function BuildTLS13RecordAAD(AEncryptedLength: Word): TBytes;
begin
  Result := nil;
  SetLength(Result, 5);
  Result[0] := TLS_CONTENT_TYPE_APPLICATION_DATA;
  Result[1] := Byte(TLS_LEGACY_VERSION shr 8);
  Result[2] := Byte(TLS_LEGACY_VERSION and $FF);
  Result[3] := Byte((AEncryptedLength shr 8) and $FF);
  Result[4] := Byte(AEncryptedLength and $FF);
end;

function BuildTLS13RecordNonce(const AStaticIV: TBytes; ASequenceNumber: QWord): TBytes;
var
  LSeqBytes: array[0..7] of Byte;
  I: Integer;
begin
  if Length(AStaticIV) <> TLS13_IV_SIZE then
    RaiseInvalidParameter('TLS13StaticIV');

  Result := nil;
  SetLength(Result, Length(AStaticIV));
  Move(AStaticIV[0], Result[0], Length(AStaticIV));

  for I := 0 to 7 do
    LSeqBytes[7 - I] := Byte((ASequenceNumber shr (I * 8)) and $FF);

  for I := 0 to 7 do
    Result[Length(Result) - 8 + I] := Result[Length(Result) - 8 + I] xor LSeqBytes[I];
end;

function BuildTLS13InnerPlaintext(const AFragment: TBytes; AContentType: Byte): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AFragment) + 1);

  if Length(AFragment) > 0 then
    Move(AFragment[0], Result[0], Length(AFragment));

  Result[Length(AFragment)] := AContentType;
end;

function TryParseTLS13InnerPlaintext(const APlaintext: TBytes; out AFragment: TBytes; out AContentType: Byte): Boolean;
var
  I: Integer;
begin
  SetLength(AFragment, 0);
  AContentType := 0;
  Result := False;

  if Length(APlaintext) = 0 then
    Exit;

  I := High(APlaintext);
  while (I >= 0) and (APlaintext[I] = 0) do
    Dec(I);

  if I < 0 then
    Exit;

  AContentType := APlaintext[I];

  SetLength(AFragment, I);
  if I > 0 then
    Move(APlaintext[0], AFragment[0], I);

  Result := True;
end;

function IncrementTLS13Sequence(var ASequenceNumber: QWord): Boolean;
begin
  if ASequenceNumber = High(QWord) then
    Exit(False);

  Inc(ASequenceNumber);
  Result := True;
end;

end.
