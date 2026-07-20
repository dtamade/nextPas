{**
 * Unit: nextpas.core.crypto.random
 * Purpose: Cryptographically secure random for crypto primitives.
 *
 * Owner: nextpas.core.crypto (must not depend on tls).
 * Uses platform CSPRNG via nextpas.core.platform.random.
 *}

unit nextpas.core.crypto.random;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  ECryptoRandomError = class(Exception);

{ Fill buffer with cryptographically secure random bytes. }
function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;

{ Allocate and fill a TBytes of ACount random bytes. Raises on failure. }
function GenerateSecureRandomBytes(ACount: Integer): TBytes;

function IsSecureRandomAvailable: Boolean;

implementation

uses
  nextpas.core.platform.random;

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
begin
  Result := False;
  if (ABuffer = nil) or (ACount <= 0) then
    Exit;
  Result := platform_random_bytes(ABuffer, PtrUInt(ACount)) = 0;
end;

function IsSecureRandomAvailable: Boolean;
var
  LByte: Byte;
begin
  Result := SecureRandomBytes(@LByte, 1);
end;

function GenerateSecureRandomBytes(ACount: Integer): TBytes;
begin
  Result := nil;
  if ACount <= 0 then
    raise ECryptoRandomError.CreateFmt('Invalid byte count: %d', [ACount]);

  SetLength(Result, ACount);
  if not SecureRandomBytes(@Result[0], ACount) then
  begin
    FillChar(Result[0], ACount, 0);
    SetLength(Result, 0);
    raise ECryptoRandomError.Create('Failed to generate secure random bytes');
  end;
end;

end.
