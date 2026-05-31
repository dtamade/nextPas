unit nextpas.core.crypto.ct.bigint;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

function CTBigIntEqual(const A, B: TBytes): Boolean;
function CTBigIntLessThan(const A, B: TBytes): Boolean;
function CTBigIntSelect(ACondition: Boolean; const AIfTrue, AIfFalse: TBytes): TBytes;
procedure CTBigIntConditionalSwap(ACondition: Boolean; var A, B: TBytes);
function CTBigIntModMul(const A, B, M: TBytes): TBytes;
function CTBigIntModExp(const ABase, AExp, AMod: TBytes): TBytes;

implementation

uses
  nextpas.core.crypto.bigint;

function CTBigIntEqual(const A, B: TBytes): Boolean;
var
  I, LLen: Integer;
  D: Byte;
begin
  LLen := Length(A);
  if LLen <> Length(B) then
    Exit(False);
  D := 0;
  for I := 0 to LLen - 1 do
    D := D or (A[I] xor B[I]);
  Result := (D = 0);
end;

function CTBigIntLessThan(const A, B: TBytes): Boolean;
var
  I, LLen: Integer;
  LBorrow: Integer;
  LDiff: Integer;
begin
  LLen := Length(A);
  if LLen <> Length(B) then
    Exit(Length(A) < Length(B));
  LBorrow := 0;
  for I := LLen - 1 downto 0 do
  begin
    LDiff := Integer(A[I]) - Integer(B[I]) - LBorrow;
    LBorrow := (LDiff shr 31) and 1;
  end;
  Result := (LBorrow = 1);
end;

function CTBigIntSelect(ACondition: Boolean; const AIfTrue, AIfFalse: TBytes): TBytes;
var
  I, LLen: Integer;
  LMask: Byte;
begin
  LLen := Length(AIfTrue);
  SetLength(Result, LLen);
  LMask := Byte(0) - Byte(Ord(ACondition));
  for I := 0 to LLen - 1 do
    Result[I] := (AIfTrue[I] and LMask) or (AIfFalse[I] and (not LMask));
end;

procedure CTBigIntConditionalSwap(ACondition: Boolean; var A, B: TBytes);
var
  I, LLen: Integer;
  LMask, LT: Byte;
begin
  LLen := Length(A);
  LMask := Byte(0) - Byte(Ord(ACondition));
  for I := 0 to LLen - 1 do
  begin
    LT := (A[I] xor B[I]) and LMask;
    A[I] := A[I] xor LT;
    B[I] := B[I] xor LT;
  end;
end;

function CTBigIntModMul(const A, B, M: TBytes): TBytes;
var
  LError: string;
begin
  if not TryBigIntModMulFromUnsignedBytes(A, B, M, Result, LError) then
    SetLength(Result, Length(M));
end;

function CTBigIntModExp(const ABase, AExp, AMod: TBytes): TBytes;
var
  LError: string;
begin
  if not TryBigIntModExpFromUnsignedBytes(ABase, AExp, AMod, Result, LError) then
    SetLength(Result, Length(AMod));
end;

end.
