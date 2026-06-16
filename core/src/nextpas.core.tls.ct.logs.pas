unit nextpas.core.tls.ct.logs;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.system.sysutils;

// No FPC RTL dependencies - using pure nextPas framework

type
  TCTLogEntry = record
    Found: Boolean;
    Name: string;
    OperatorName: string;
    URL: string;
    State: string;
    LogID: TBytes;
    PublicKeySPKI: TBytes;
    PublicKey: TBytes;
    KeyType: string;
  end;

function FindCTLogByID(const ALogID: TBytes): TCTLogEntry;
procedure RegisterAdditionalCTLog(
  const AName: string;
  const ALogID: TBytes;
  const APublicKey: TBytes;
  const AKeyType: string
);
procedure ClearAdditionalCTLogs;

implementation

uses
  nextpas.core.tls.base64,
  nextpas.core.crypto.hash;

type
  TBuiltinCTLogDefinition = record
    Name: string;
    OperatorName: string;
    URL: string;
    State: string;
    KeyType: string;
    PublicKeySPKIBase64: string;
  end;

var
  GAdditionalCTLogs: array of TCTLogEntry;

function CopyBytes(const AData: TBytes): TBytes;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
end;

function SameBytes(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;

  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

function EmptyCTLogEntry: TCTLogEntry;
begin
  Result.Found := False;
  Result.Name := '';
  Result.OperatorName := '';
  Result.URL := '';
  Result.State := '';
  SetLength(Result.LogID, 0);
  SetLength(Result.PublicKeySPKI, 0);
  SetLength(Result.PublicKey, 0);
  Result.KeyType := '';
end;

function TryExtractP256PublicKeyFromSPKI(const ASPKI: TBytes; out APublicKey: TBytes): Boolean;
begin
  SetLength(APublicKey, 0);
  Result := False;

  if (Length(ASPKI) <> 91) or
    (ASPKI[0] <> $30) or (ASPKI[1] <> $59) or
    (ASPKI[23] <> $03) or (ASPKI[24] <> $42) or (ASPKI[25] <> $00) or
    (ASPKI[26] <> $04) then
    Exit;

  APublicKey := Copy(ASPKI, 26, 65);
  Result := Length(APublicKey) = 65;
end;

function TryExtractEd25519PublicKeyFromSPKI(const ASPKI: TBytes; out APublicKey: TBytes): Boolean;
begin
  SetLength(APublicKey, 0);
  Result := False;

  if (Length(ASPKI) <> 44) or
    (ASPKI[0] <> $30) or (ASPKI[1] <> $2A) or
    (ASPKI[2] <> $30) or (ASPKI[3] <> $05) or
    (ASPKI[4] <> $06) or (ASPKI[5] <> $03) or
    (ASPKI[6] <> $2B) or (ASPKI[7] <> $65) or (ASPKI[8] <> $70) or
    (ASPKI[9] <> $03) or (ASPKI[10] <> $21) or (ASPKI[11] <> $00) then
    Exit;

  APublicKey := Copy(ASPKI, 12, 32);
  Result := Length(APublicKey) = 32;
end;

function ExtractVerifierPublicKey(const ASPKI: TBytes; const AKeyType: string): TBytes;
begin
  SetLength(Result, 0);

  if SameText(AKeyType, 'ECDSA') then
    TryExtractP256PublicKeyFromSPKI(ASPKI, Result)
  else if SameText(AKeyType, 'Ed25519') then
    TryExtractEd25519PublicKeyFromSPKI(ASPKI, Result);
end;

function GoogleArgon2026H1: TBuiltinCTLogDefinition;
begin
  Result.Name := 'Google Argon2026h1';
  Result.OperatorName := 'Google';
  Result.URL := 'https://ct.googleapis.com/logs/us1/argon2026h1/';
  Result.State := 'usable';
  Result.KeyType := 'ECDSA';
  Result.PublicKeySPKIBase64 :=
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEB/we6GOO/xwxivy4HhkrYFAAPo6e2nc' +
    '346Wo2o2U+GvoPWSPJz91s/xrEvA3Bk9kWHUUXVZS5morFEzsgdHqPg==';
end;

function CloudflareNimbus2026: TBuiltinCTLogDefinition;
begin
  Result.Name := 'Cloudflare Nimbus2026';
  Result.OperatorName := 'Cloudflare';
  Result.URL := 'https://ct.cloudflare.com/logs/nimbus2026/';
  Result.State := 'usable';
  Result.KeyType := 'ECDSA';
  Result.PublicKeySPKIBase64 :=
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE2FxhT6xq0iCATopC9gStS9SxHHmOKT' +
    'LeaVNZ661488Aq8tARXQV+6+jB0983v5FkRm4OJxPqu29GJ1iG70Ahow==';
end;

function DigiCertWyvern2026H1: TBuiltinCTLogDefinition;
begin
  Result.Name := 'DigiCert Wyvern2026h1';
  Result.OperatorName := 'DigiCert';
  Result.URL := 'https://wyvern.ct.digicert.com/2026h1/';
  Result.State := 'usable';
  Result.KeyType := 'ECDSA';
  Result.PublicKeySPKIBase64 :=
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE7Lw0OeKajbeZepHxBXJS2pOJXToHi5' +
    'ntgKUW2nMhIOuGlofFxtkXum65TBNY1dGD+HrfHge8Fc3ASs0qMXEHVQ==';
end;

function DigiCertYeti2025: TBuiltinCTLogDefinition;
begin
  Result.Name := 'DigiCert Yeti2025';
  Result.OperatorName := 'DigiCert';
  Result.URL := 'https://yeti2025.ct.digicert.com/log/';
  Result.State := 'rejected';
  Result.KeyType := 'ECDSA';
  Result.PublicKeySPKIBase64 :=
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE35UAXhDBAfc34xB00f+yypDtMplfDD' +
    'n+odETEazRs3OTIMITPEy1elKGhj3jlSR82JGYSDvw8N8h8bCBWlklQw==';
end;

function BuiltinCTLogCount: Integer;
begin
  Result := 4;
end;

function BuiltinCTLogDefinition(AIndex: Integer): TBuiltinCTLogDefinition;
begin
  case AIndex of
    0: Result := GoogleArgon2026H1;
    1: Result := CloudflareNimbus2026;
    2: Result := DigiCertWyvern2026H1;
    3: Result := DigiCertYeti2025;
  else
    Result.Name := '';
    Result.OperatorName := '';
    Result.URL := '';
    Result.State := '';
    Result.KeyType := '';
    Result.PublicKeySPKIBase64 := '';
  end;
end;

function BuildBuiltinEntry(const ADefinition: TBuiltinCTLogDefinition): TCTLogEntry;
begin
  Result := EmptyCTLogEntry;
  if ADefinition.PublicKeySPKIBase64 = '' then
    Exit;

  Result.Found := True;
  Result.Name := ADefinition.Name;
  Result.OperatorName := ADefinition.OperatorName;
  Result.URL := ADefinition.URL;
  Result.State := ADefinition.State;
  Result.KeyType := ADefinition.KeyType;
  Result.PublicKeySPKI := TBase64Utils.Decode(ADefinition.PublicKeySPKIBase64);
  Result.LogID := SHA256(Result.PublicKeySPKI);
  Result.PublicKey := ExtractVerifierPublicKey(Result.PublicKeySPKI, Result.KeyType);
end;

function FindCTLogByID(const ALogID: TBytes): TCTLogEntry;
var
  I: Integer;
  LEntry: TCTLogEntry;
begin
  Result := EmptyCTLogEntry;

  if Length(ALogID) <> 32 then
    Exit;

  for I := 0 to High(GAdditionalCTLogs) do
    if SameBytes(GAdditionalCTLogs[I].LogID, ALogID) then
      Exit(GAdditionalCTLogs[I]);

  for I := 0 to BuiltinCTLogCount - 1 do
  begin
    LEntry := BuildBuiltinEntry(BuiltinCTLogDefinition(I));
    if SameBytes(LEntry.LogID, ALogID) then
      Exit(LEntry);
  end;
end;

procedure RegisterAdditionalCTLog(
  const AName: string;
  const ALogID: TBytes;
  const APublicKey: TBytes;
  const AKeyType: string
);
var
  LIndex: Integer;
begin
  if Length(ALogID) <> 32 then
    raise EArgumentError.Create('CT log ID must be 32 bytes');

  if Length(APublicKey) = 0 then
    raise EArgumentError.Create('CT log public key must not be empty');

  if (not SameText(AKeyType, 'ECDSA')) and (not SameText(AKeyType, 'Ed25519')) then
    raise EArgumentError.Create('Unsupported CT log key type');

  LIndex := Length(GAdditionalCTLogs);
  SetLength(GAdditionalCTLogs, LIndex + 1);
  GAdditionalCTLogs[LIndex] := EmptyCTLogEntry;
  GAdditionalCTLogs[LIndex].Found := True;
  GAdditionalCTLogs[LIndex].Name := AName;
  GAdditionalCTLogs[LIndex].OperatorName := 'Additional';
  GAdditionalCTLogs[LIndex].State := 'additional';
  GAdditionalCTLogs[LIndex].LogID := CopyBytes(ALogID);
  GAdditionalCTLogs[LIndex].PublicKeySPKI := CopyBytes(APublicKey);
  GAdditionalCTLogs[LIndex].PublicKey := CopyBytes(APublicKey);
  GAdditionalCTLogs[LIndex].KeyType := AKeyType;
end;

procedure ClearAdditionalCTLogs;
begin
  SetLength(GAdditionalCTLogs, 0);
end;

end.
