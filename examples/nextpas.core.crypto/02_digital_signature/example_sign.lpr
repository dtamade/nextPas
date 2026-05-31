program example_sign;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.ed25519;

function ToHex(const A: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do Result := Result + LowerCase(IntToHex(A[I], 2));
end;

var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  WriteLn('=== Ed25519 Digital Signature ===');
  WriteLn;

  // Generate key pair (32-byte private key → 32-byte public key)
  SetLength(LPriv, 32);
  Randomize;
  // In production use a CSPRNG; this is just a demo
  LPriv[0] := $9d; LPriv[1] := $61; LPriv[2] := $b1; LPriv[3] := $9d;
  LPriv[4] := $ef; LPriv[5] := $fd; LPriv[6] := $5a; LPriv[7] := $60;
  LPriv[8] := $ba; LPriv[9] := $84; LPriv[10] := $4a; LPriv[11] := $f4;
  LPriv[12] := $92; LPriv[13] := $ec; LPriv[14] := $2c; LPriv[15] := $c4;
  LPriv[16] := $44; LPriv[17] := $49; LPriv[18] := $c5; LPriv[19] := $69;
  LPriv[20] := $7b; LPriv[21] := $32; LPriv[22] := $69; LPriv[23] := $19;
  LPriv[24] := $70; LPriv[25] := $3b; LPriv[26] := $ac; LPriv[27] := $03;
  LPriv[28] := $1c; LPriv[29] := $ae; LPriv[30] := $7f; LPriv[31] := $60;

  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  WriteLn('Public key: ', Copy(ToHex(LPub), 1, 16), '...');

  // Sign a message
  LMsg := TEncoding.UTF8.GetBytes(UnicodeString('Transfer 100 tokens to Alice'));
  if Ed25519Sign(LPriv, LMsg, LSig) then
    WriteLn('Signature:  ', Copy(ToHex(LSig), 1, 16), '... (64 bytes)')
  else
  begin
    WriteLn('ERROR: signing failed');
    Halt(1);
  end;

  // Verify
  if Ed25519Verify(LPub, LMsg, LSig) then
    WriteLn('Verification: VALID')
  else
  begin
    WriteLn('ERROR: verification failed');
    Halt(1);
  end;

  // Tamper with message
  LMsg[0] := LMsg[0] xor $01;
  if not Ed25519Verify(LPub, LMsg, LSig) then
    WriteLn('Tampered message: REJECTED (expected)')
  else
    WriteLn('ERROR: tampered message accepted!');

  WriteLn;
  WriteLn('nextpas.core.crypto.ed25519=ready');
end.
