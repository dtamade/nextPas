{******************************************************************************}
{  Security Module Unit Test                                                   }
{  Tests for nextpas.core.tls.secure.pas                                            }
{******************************************************************************}

program test_secure;

{$mode objfpc}{$H+}
{$UNITPATH framework}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.secure,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rand,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

// ============================================================================
// TSecureString Tests
// ============================================================================

procedure TestSecureStringCreate;
var
  SS: TSecureString;
begin
  WriteLn;
  WriteLn('=== TSecureString.Create ===');

  SS := TSecureString.Create('Hello World');
  Runner.Check('Create non-empty', SS.Size = 11);
  Runner.Check('ToString matches', SS.ToString = 'Hello World');
  Runner.Check('Data not nil', SS.Data <> nil);
end;

procedure TestSecureStringEmpty;
var
  SS: TSecureString;
begin
  WriteLn;
  WriteLn('=== TSecureString Empty ===');

  SS := TSecureString.Create('');
  Runner.Check('Empty size', SS.Size = 0);
  Runner.Check('Empty toString', SS.ToString = '');
end;

procedure TestSecureStringClear;
var
  SS: TSecureString;
begin
  WriteLn;
  WriteLn('=== TSecureString.Clear ===');

  SS := TSecureString.Create('Secret Password');
  Runner.Check('Before clear', SS.Size = 15);

  SS.Clear;
  Runner.Check('After clear size', SS.Size = 0);
end;

procedure TestSecureStringCopyFrom;
var
  SS1, SS2: TSecureString;
begin
  WriteLn;
  WriteLn('=== TSecureString.CopyFrom ===');

  SS1 := TSecureString.Create('Original');
  SS2 := TSecureString.Create('');

  SS2.CopyFrom(SS1);
  Runner.Check('Copy size', SS2.Size = SS1.Size);
  Runner.Check('Copy content', SS2.ToString = 'Original');
end;

// ============================================================================
// TSecureBytes Tests
// ============================================================================

procedure TestSecureBytesCreate;
var
  Data: TBytes;
  SB: TSecureBytes;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TSecureBytes.Create ===');

  SetLength(Data, 16);
  for I := 0 to 15 do
    Data[I] := I;

  SB := TSecureBytes.Create(Data);
  Runner.Check('Create size', SB.Size = 16);
  Runner.Check('First byte', SB.Data[0] = 0);
  Runner.Check('Last byte', SB.Data[15] = 15);
end;

procedure TestSecureBytesToBytes;
var
  Data: TBytes;
  SB: TSecureBytes;
  Result: TBytes;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== TSecureBytes.ToBytes ===');

  SetLength(Data, 32);
  for I := 0 to 31 do
    Data[I] := I * 2;

  SB := TSecureBytes.Create(Data);
  Result := SB.ToBytes;

  Runner.Check('Result size', Length(Result) = 32);

  Match := True;
  for I := 0 to 31 do
    if Result[I] <> Data[I] then
    begin
      Match := False;
      Break;
    end;
  Runner.Check('Data matches', Match);
end;

procedure TestSecureBytesRandom;
var
  SB1, SB2: TSecureBytes;
  I: Integer;
  AllZero, AllSame: Boolean;
begin
  WriteLn;
  WriteLn('=== TSecureBytes.CreateRandom ===');

  SB1 := TSecureBytes.CreateRandom(32);
  Runner.Check('Random size', SB1.Size = 32);

  // Check not all zeros
  AllZero := True;
  for I := 0 to 31 do
    if SB1.Data[I] <> 0 then
    begin
      AllZero := False;
      Break;
    end;
  Runner.Check('Not all zeros', not AllZero);

  // Create another random and check they differ
  SB2 := TSecureBytes.CreateRandom(32);
  AllSame := True;
  for I := 0 to 31 do
    if SB1.Data[I] <> SB2.Data[I] then
    begin
      AllSame := False;
      Break;
    end;
  Runner.Check('Two randoms differ', not AllSame);
end;

// ============================================================================
// TSecureRandom Tests
// ============================================================================

procedure TestSecureRandomGenerate;
var
  Data1, Data2: TBytes;
  AllSame: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TSecureRandom.Generate ===');

  Data1 := TSecureRandom.Generate(64);
  Runner.Check('Generate size', Length(Data1) = 64);

  Data2 := TSecureRandom.Generate(64);
  AllSame := True;
  for I := 0 to 63 do
    if Data1[I] <> Data2[I] then
    begin
      AllSame := False;
      Break;
    end;
  Runner.Check('Two generates differ', not AllSame);
end;

procedure TestSecureRandomGenerateInt;
var
  Val: Integer;
  I: Integer;
  InRange: Boolean;
begin
  WriteLn;
  WriteLn('=== TSecureRandom.GenerateInt ===');

  InRange := True;
  for I := 1 to 100 do
  begin
    Val := TSecureRandom.GenerateInt(10, 20);
    if (Val < 10) or (Val > 20) then
    begin
      InRange := False;
      Break;
    end;
  end;
  Runner.Check('GenerateInt in range', InRange);
end;

// ============================================================================
// SecureCompare Tests (Timing Attack Resistant)
// ============================================================================

procedure TestSecureCompareEqual;
var
  A, B: TBytes;
begin
  WriteLn;
  WriteLn('=== SecureCompare Equal ===');

  A := TBytes.Create(1, 2, 3, 4, 5);
  B := TBytes.Create(1, 2, 3, 4, 5);

  Runner.Check('Equal arrays', SecureCompare(A, B));
end;

procedure TestSecureCompareNotEqual;
var
  A, B: TBytes;
begin
  WriteLn;
  WriteLn('=== SecureCompare Not Equal ===');

  A := TBytes.Create(1, 2, 3, 4, 5);
  B := TBytes.Create(1, 2, 3, 4, 6);

  Runner.Check('Different last byte', not SecureCompare(A, B));

  B := TBytes.Create(0, 2, 3, 4, 5);
  Runner.Check('Different first byte', not SecureCompare(A, B));

  B := TBytes.Create(1, 2, 9, 4, 5);
  Runner.Check('Different middle byte', not SecureCompare(A, B));
end;

procedure TestSecureCompareDifferentLength;
var
  A, B: TBytes;
begin
  WriteLn;
  WriteLn('=== SecureCompare Different Length ===');

  A := TBytes.Create(1, 2, 3, 4, 5);
  B := TBytes.Create(1, 2, 3, 4);

  Runner.Check('Shorter B', not SecureCompare(A, B));

  B := TBytes.Create(1, 2, 3, 4, 5, 6);
  Runner.Check('Longer B', not SecureCompare(A, B));
end;

procedure TestSecureCompareEmpty;
var
  A, B: TBytes;
begin
  WriteLn;
  WriteLn('=== SecureCompare Empty ===');

  SetLength(A, 0);
  SetLength(B, 0);

  Runner.Check('Both empty', SecureCompare(A, B));

  A := TBytes.Create(1);
  Runner.Check('One empty', not SecureCompare(A, B));
end;

procedure TestSecureCompareStrings;
begin
  WriteLn;
  WriteLn('=== SecureCompareStrings ===');

  Runner.Check('Equal strings', SecureCompareStrings('password123', 'password123'));
  Runner.Check('Different strings', not SecureCompareStrings('password123', 'password124'));
  Runner.Check('Different length', not SecureCompareStrings('pass', 'password'));
  Runner.Check('Empty strings', SecureCompareStrings('', ''));
end;

procedure TestSecureCompareSecure;
var
  A, B: TSecureBytes;
begin
  WriteLn;
  WriteLn('=== SecureCompareSecure ===');

  A := TSecureBytes.Create(TBytes.Create(1, 2, 3, 4, 5));
  B := TSecureBytes.Create(TBytes.Create(1, 2, 3, 4, 5));

  Runner.Check('Equal secure bytes', SecureCompareSecure(A, B));

  B := TSecureBytes.Create(TBytes.Create(1, 2, 3, 4, 6));
  Runner.Check('Different secure bytes', not SecureCompareSecure(A, B));
end;

// ============================================================================
// ISecureKeyStore Tests
// ============================================================================

procedure TestKeyStoreBasic;
var
  Store: ISecureKeyStore;
  Key, Retrieved: TSecureBytes;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== ISecureKeyStore Basic ===');

  Store := CreateSecureKeyStore;
  Runner.Check('Create store', Store <> nil);

  // Store a key
  Key := TSecureBytes.CreateRandom(32);
  Store.StoreKey('test-key-1', Key, 'password123');
  Runner.Check('HasKey after store', Store.HasKey('test-key-1'));
  Runner.Check('Not has unknown key', not Store.HasKey('unknown'));

  // Retrieve the key
  Retrieved := Store.LoadKey('test-key-1', 'password123');
  Runner.Check('Retrieved size', Retrieved.Size = 32);

  Match := True;
  for I := 0 to 31 do
    if Retrieved.Data[I] <> Key.Data[I] then
    begin
      Match := False;
      Break;
    end;
  Runner.Check('Retrieved matches original', Match);
end;

procedure TestKeyStoreDelete;
var
  Store: ISecureKeyStore;
  Key: TSecureBytes;
begin
  WriteLn;
  WriteLn('=== ISecureKeyStore Delete ===');

  Store := CreateSecureKeyStore;
  Key := TSecureBytes.CreateRandom(16);

  Store.StoreKey('temp-key', Key, 'pass');
  Runner.Check('Key exists', Store.HasKey('temp-key'));

  Store.DeleteKey('temp-key');
  Runner.Check('Key deleted', not Store.HasKey('temp-key'));
end;

procedure TestKeyStoreLock;
var
  Store: ISecureKeyStore;
  Key: TSecureBytes;
  Locked: Boolean;
begin
  WriteLn;
  WriteLn('=== ISecureKeyStore Lock ===');

  Store := CreateSecureKeyStore;
  Key := TSecureBytes.CreateRandom(16);

  Runner.Check('Initially unlocked', not Store.IsLocked);

  Store.Lock;
  Runner.Check('After lock', Store.IsLocked);

  // Try to store while locked - should fail
  Locked := False;
  try
    Store.StoreKey('locked-key', Key, 'pass');
  except
    Locked := True;
  end;
  Runner.Check('Store fails when locked', Locked);

  Store.Unlock('master');
  Runner.Check('After unlock', not Store.IsLocked);
end;

begin
  WriteLn('Security Module Unit Tests');
  WriteLn('==========================');

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmEVP, osmRAND, osmKDF]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    // TSecureString tests
    TestSecureStringCreate;
    TestSecureStringEmpty;
    TestSecureStringClear;
    TestSecureStringCopyFrom;

    // TSecureBytes tests
    TestSecureBytesCreate;
    TestSecureBytesToBytes;
    TestSecureBytesRandom;

    // TSecureRandom tests
    TestSecureRandomGenerate;
    TestSecureRandomGenerateInt;

    // SecureCompare tests
    TestSecureCompareEqual;
    TestSecureCompareNotEqual;
    TestSecureCompareDifferentLength;
    TestSecureCompareEmpty;
    TestSecureCompareStrings;
    TestSecureCompareSecure;

    // ISecureKeyStore tests
    TestKeyStoreBasic;
    TestKeyStoreDelete;
    TestKeyStoreLock;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
