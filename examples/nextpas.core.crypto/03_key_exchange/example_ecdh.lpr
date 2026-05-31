program example_ecdh;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.x25519;

function ToHex(const A: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do Result := Result + LowerCase(IntToHex(A[I], 2));
end;

var
  LAlicePriv, LAlicePub: TBytes;
  LBobPriv, LBobPub: TBytes;
  LSharedA, LSharedB: TBytes;
begin
  WriteLn('=== X25519 Key Exchange (ECDH) ===');
  WriteLn;

  // Alice generates her key pair
  GenerateX25519KeyPair(LAlicePriv, LAlicePub);
  WriteLn('Alice public: ', Copy(ToHex(LAlicePub), 1, 16), '...');

  // Bob generates his key pair
  GenerateX25519KeyPair(LBobPriv, LBobPub);
  WriteLn('Bob public:   ', Copy(ToHex(LBobPub), 1, 16), '...');

  // Both compute the shared secret
  LSharedA := X25519ComputeSharedSecret(LAlicePriv, LBobPub);
  LSharedB := X25519ComputeSharedSecret(LBobPriv, LAlicePub);

  WriteLn;
  WriteLn('Alice shared: ', Copy(ToHex(LSharedA), 1, 16), '...');
  WriteLn('Bob shared:   ', Copy(ToHex(LSharedB), 1, 16), '...');

  if CompareMem(@LSharedA[0], @LSharedB[0], 32) then
    WriteLn('Match: YES (both derived the same 32-byte secret)')
  else
  begin
    WriteLn('ERROR: shared secrets do not match!');
    Halt(1);
  end;

  WriteLn;
  WriteLn('nextpas.core.crypto.x25519=ready');
end.
