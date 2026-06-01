unit nextpas.core.tls.quic.crypto;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base;

const
  QUIC_VERSION_1 = $00000001;
  QUIC_INITIAL_SALT_V1: array[0..19] of Byte = (
    $38, $76, $2c, $f7, $f5, $59, $34, $b3, $4d, $17,
    $9a, $e6, $a4, $c8, $0c, $ad, $cc, $bb, $7f, $0a
  );

type
  TQUICPacketType = (
    qptInitial = 0,
    qptZeroRTT = 1,
    qptHandshake = 2,
    qptRetry = 3,
    qptOneRTT = 4
  );

  TQUICKeys = record
    Key: TBytes;
    IV: TBytes;
    HP: TBytes;
  end;

function QUICDeriveInitialSecret(const AConnectionID: TBytes): TBytes;
function QUICDeriveClientInitialKeys(const AInitialSecret: TBytes): TQUICKeys;
function QUICDeriveServerInitialKeys(const AInitialSecret: TBytes): TQUICKeys;

implementation

uses
  nextpas.core.crypto.hkdf, nextpas.core.crypto.hash;

function StringToBytes(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function QUICDeriveInitialSecret(const AConnectionID: TBytes): TBytes;
var
  LSalt: TBytes;
begin
  SetLength(LSalt, 20);
  Move(QUIC_INITIAL_SALT_V1[0], LSalt[0], 20);
  Result := HKDF_Extract_SHA256(LSalt, AConnectionID);
end;

function HKDFExpandLabel(const ASecret: TBytes; const ALabel: string; ALength: Integer): TBytes;
var
  LInfo: TBytes;
  LLabelBytes: TBytes;
  LPos: Integer;
begin
  LLabelBytes := StringToBytes('tls13 ' + ALabel);
  SetLength(LInfo, 2 + 1 + Length(LLabelBytes) + 1);
  LInfo[0] := Byte(ALength shr 8);
  LInfo[1] := Byte(ALength);
  LInfo[2] := Byte(Length(LLabelBytes));
  Move(LLabelBytes[0], LInfo[3], Length(LLabelBytes));
  LPos := 3 + Length(LLabelBytes);
  LInfo[LPos] := 0; // context length = 0
  Result := HKDF_Expand_SHA256(ASecret, LInfo, ALength);
end;

function QUICDeriveClientInitialKeys(const AInitialSecret: TBytes): TQUICKeys;
var
  LClientSecret: TBytes;
begin
  LClientSecret := HKDFExpandLabel(AInitialSecret, 'client in', 32);
  Result.Key := HKDFExpandLabel(LClientSecret, 'quic key', 16);
  Result.IV := HKDFExpandLabel(LClientSecret, 'quic iv', 12);
  Result.HP := HKDFExpandLabel(LClientSecret, 'quic hp', 16);
end;

function QUICDeriveServerInitialKeys(const AInitialSecret: TBytes): TQUICKeys;
var
  LServerSecret: TBytes;
begin
  LServerSecret := HKDFExpandLabel(AInitialSecret, 'server in', 32);
  Result.Key := HKDFExpandLabel(LServerSecret, 'quic key', 16);
  Result.IV := HKDFExpandLabel(LServerSecret, 'quic iv', 12);
  Result.HP := HKDFExpandLabel(LServerSecret, 'quic hp', 16);
end;

end.
