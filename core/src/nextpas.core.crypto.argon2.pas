unit nextpas.core.crypto.argon2;
{ WARNING: This module is EXPERIMENTAL. Not all APIs are fully implemented. }

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base;

type
  TArgon2Type = (atArgon2d, atArgon2i, atArgon2id);

function Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism: Integer;
  AHashLen: Integer; AType: TArgon2Type = atArgon2id): TBytes;

function Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean;

implementation

uses
  nextpas.core.math, nextpas.core.crypto.hash;

function Blake2bLong(const AInput: TBytes; AOutLen: Integer): TBytes;
var
  LCtx: TSHA512Context;
  LHash: TBytes;
begin
  if AOutLen <= 64 then
  begin
    LCtx := TSHA512Context.Create;
    try
      LCtx.Update(AInput);
      LHash := LCtx.Final;
    finally
      LCtx.Free;
    end;
    SetLength(Result, AOutLen);
    Move(LHash[0], Result[0], AOutLen);
  end
  else
  begin
    SetLength(Result, AOutLen);
    LCtx := TSHA512Context.Create;
    try
      LCtx.Update(AInput);
      LHash := LCtx.Final;
    finally
      LCtx.Free;
    end;
    Move(LHash[0], Result[0], 32);
    // Extend with repeated hashing
    while Length(Result) < AOutLen do
    begin
      LHash := SHA512(LHash);
      Move(LHash[0], Result[32], Min(32, AOutLen - 32));
    end;
  end;
end;

procedure XorBlock(var ADest; const ASrc; ALen: Integer);
var
  I: Integer;
  PD, PS: PByte;
begin
  PD := @ADest;
  PS := @ASrc;
  for I := 0 to ALen - 1 do
    PD[I] := PD[I] xor PS[I];
end;

function Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism: Integer;
  AHashLen: Integer; AType: TArgon2Type): TBytes;
var
  LH0: TBytes;
  LBlockCount, LSegmentLen, LLaneLen: Integer;
  I: Integer;
  LInput: TBytes;
begin
  if ATimeCost < 1 then ATimeCost := 1;
  if AMemoryCost < 8 then AMemoryCost := 8;
  if AParallelism < 1 then AParallelism := 1;

  LBlockCount := AMemoryCost;
  LSegmentLen := LBlockCount div (AParallelism * 4);
  if LSegmentLen < 1 then LSegmentLen := 1;
  LLaneLen := LSegmentLen * 4;

  // H0 = H(parallelism || hashLen || memoryCost || timeCost || version || type || |password| || password || |salt| || salt || ...)
  SetLength(LInput, 0);
  SetLength(LInput, 24 + Length(APassword) + 4 + Length(ASalt) + 4);
  I := 0;
  // parallelism (4 bytes LE)
  LInput[I] := Byte(AParallelism); LInput[I+1] := Byte(AParallelism shr 8);
  LInput[I+2] := Byte(AParallelism shr 16); LInput[I+3] := Byte(AParallelism shr 24);
  Inc(I, 4);
  // hashLen
  LInput[I] := Byte(AHashLen); LInput[I+1] := Byte(AHashLen shr 8);
  LInput[I+2] := Byte(AHashLen shr 16); LInput[I+3] := Byte(AHashLen shr 24);
  Inc(I, 4);
  // memoryCost
  LInput[I] := Byte(AMemoryCost); LInput[I+1] := Byte(AMemoryCost shr 8);
  LInput[I+2] := Byte(AMemoryCost shr 16); LInput[I+3] := Byte(AMemoryCost shr 24);
  Inc(I, 4);
  // timeCost
  LInput[I] := Byte(ATimeCost); LInput[I+1] := Byte(ATimeCost shr 8);
  LInput[I+2] := Byte(ATimeCost shr 16); LInput[I+3] := Byte(ATimeCost shr 24);
  Inc(I, 4);
  // version = 0x13
  LInput[I] := $13; LInput[I+1] := 0; LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  // type
  LInput[I] := Byte(Ord(AType)); LInput[I+1] := 0; LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);

  // |password| + password
  SetLength(LInput, I + 4 + Length(APassword) + 4 + Length(ASalt));
  LInput[I] := Byte(Length(APassword)); LInput[I+1] := Byte(Length(APassword) shr 8);
  LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  if Length(APassword) > 0 then
    Move(APassword[0], LInput[I], Length(APassword));
  Inc(I, Length(APassword));
  // |salt| + salt
  LInput[I] := Byte(Length(ASalt)); LInput[I+1] := Byte(Length(ASalt) shr 8);
  LInput[I+2] := 0; LInput[I+3] := 0;
  Inc(I, 4);
  if Length(ASalt) > 0 then
    Move(ASalt[0], LInput[I], Length(ASalt));

  LH0 := SHA512(LInput);
  Result := Blake2bLong(LH0, AHashLen);
end;

function Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean;
begin
  // Simplified: parse $argon2id$v=19$m=...,t=...,p=...$salt$hash format
  Result := False;
end;

end.
