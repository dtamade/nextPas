{**
 * Unit: nextpas.core.tls.random
 * Purpose: Compatibility shim — CSPRNG owner is nextpas.core.crypto.random.
 *
 * Prefer: nextpas.core.crypto.random in new code.
 *}

unit nextpas.core.tls.random;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.crypto.random
  {$IFDEF USE_RANDOM_POOL}
  , nextpas.core.tls.random.pool
  {$ENDIF}
  ;

type
  { Alias for existing TLS call sites. }
  ESecureRandomError = ECryptoRandomError;

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean; inline;
function GenerateSecureRandomBytes(ACount: Integer): TBytes; inline;
function GenerateSecureRandomHex(ALength: Integer): string;
function IsSecureRandomAvailable: Boolean; inline;

implementation

uses
  nextpas.core.text.conv;

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
begin
  {$IFDEF USE_RANDOM_POOL}
  if PooledRandomBytes(ABuffer, ACount) then
    Exit(True);
  {$ENDIF}
  Result := nextpas.core.crypto.random.SecureRandomBytes(ABuffer, ACount);
end;

function IsSecureRandomAvailable: Boolean;
begin
  Result := nextpas.core.crypto.random.IsSecureRandomAvailable;
end;

function GenerateSecureRandomBytes(ACount: Integer): TBytes;
begin
  Result := nextpas.core.crypto.random.GenerateSecureRandomBytes(ACount);
end;

function GenerateSecureRandomHex(ALength: Integer): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  LBytes: TBytes;
  LByteCount, I: Integer;
begin
  if ALength <= 0 then
  begin
    Result := '';
    Exit;
  end;
  LByteCount := (ALength + 1) div 2;
  LBytes := GenerateSecureRandomBytes(LByteCount);
  SetLength(Result, ALength);
  for I := 0 to LByteCount - 1 do
  begin
    if (I * 2 + 1) <= ALength then
      Result[I * 2 + 1] := HexChars[LBytes[I] shr 4];
    if (I * 2 + 2) <= ALength then
      Result[I * 2 + 2] := HexChars[LBytes[I] and $0F];
  end;
end;

end.
