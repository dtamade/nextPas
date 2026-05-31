program test_argon2;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.argon2;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

function BytesToHex(const B: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

procedure TestArgon2idBasic;
var
  LPassword, LSalt, LHash: TBytes;
begin
  WriteLn('TestArgon2idBasic');
  LPassword := TBytes.Create($70, $61, $73, $73, $77, $6F, $72, $64);
  LSalt := TBytes.Create($73, $61, $6C, $74, $73, $61, $6C, $74);
  LHash := Argon2Hash(LPassword, LSalt, 1, 8, 1, 32, atArgon2id);
  Check(Length(LHash) = 32, 'Output length = 32');
  Check(LHash[0] <> 0, 'Non-zero output');
end;

procedure TestArgon2dBasic;
var
  LPassword, LSalt, LHash: TBytes;
begin
  WriteLn('TestArgon2dBasic');
  LPassword := TBytes.Create($74, $65, $73, $74);
  LSalt := TBytes.Create($73, $61, $6C, $74);
  LHash := Argon2Hash(LPassword, LSalt, 1, 8, 1, 16, atArgon2d);
  Check(Length(LHash) = 16, 'Output length = 16');
end;

procedure TestArgon2iBasic;
var
  LPassword, LSalt, LHash: TBytes;
begin
  WriteLn('TestArgon2iBasic');
  LPassword := TBytes.Create($61, $62, $63);
  LSalt := TBytes.Create($64, $65, $66, $67, $68, $69, $6A, $6B);
  LHash := Argon2Hash(LPassword, LSalt, 2, 16, 1, 64, atArgon2i);
  Check(Length(LHash) = 64, 'Output length = 64');
end;

procedure TestArgon2Deterministic;
var
  LPassword, LSalt, LHash1, LHash2: TBytes;
  I: Integer;
  LMatch: Boolean;
begin
  WriteLn('TestArgon2Deterministic');
  LPassword := TBytes.Create($70, $61, $73, $73);
  LSalt := TBytes.Create($73, $61, $6C, $74, $31, $32, $33, $34);
  LHash1 := Argon2Hash(LPassword, LSalt, 1, 8, 1, 32, atArgon2id);
  LHash2 := Argon2Hash(LPassword, LSalt, 1, 8, 1, 32, atArgon2id);
  LMatch := True;
  for I := 0 to 31 do
    if LHash1[I] <> LHash2[I] then
    begin
      LMatch := False;
      Break;
    end;
  Check(LMatch, 'Same input produces same output');
end;

procedure TestArgon2DifferentPasswords;
var
  LPass1, LPass2, LSalt, LHash1, LHash2: TBytes;
  I: Integer;
  LDiff: Boolean;
begin
  WriteLn('TestArgon2DifferentPasswords');
  LPass1 := TBytes.Create($61, $62, $63);
  LPass2 := TBytes.Create($64, $65, $66);
  LSalt := TBytes.Create($73, $61, $6C, $74);
  LHash1 := Argon2Hash(LPass1, LSalt, 1, 8, 1, 32, atArgon2id);
  LHash2 := Argon2Hash(LPass2, LSalt, 1, 8, 1, 32, atArgon2id);
  LDiff := False;
  for I := 0 to 31 do
    if LHash1[I] <> LHash2[I] then
    begin
      LDiff := True;
      Break;
    end;
  Check(LDiff, 'Different passwords produce different hashes');
end;

procedure TestArgon2MinParams;
var
  LPassword, LSalt, LHash: TBytes;
begin
  WriteLn('TestArgon2MinParams');
  LPassword := TBytes.Create($78);
  LSalt := TBytes.Create($79);
  LHash := Argon2Hash(LPassword, LSalt, 0, 0, 0, 32, atArgon2id);
  Check(Length(LHash) = 32, 'Min params clamped, output valid');
end;

procedure TestArgon2VerifyStub;
var
  LPassword: TBytes;
begin
  WriteLn('TestArgon2VerifyStub');
  LPassword := TBytes.Create($70, $61, $73, $73);
  Check(not Argon2Verify(LPassword, '$argon2id$v=19$m=8,t=1,p=1$salt$hash'),
    'Verify stub returns false (not yet implemented)');
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestArgon2idBasic;
  TestArgon2dBasic;
  TestArgon2iBasic;
  TestArgon2Deterministic;
  TestArgon2DifferentPasswords;
  TestArgon2MinParams;
  TestArgon2VerifyStub;

  WriteLn;
  WriteLn('Argon2 tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
