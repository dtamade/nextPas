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
begin
  LLen := Length(A);
  if LLen <> Length(B) then
    Exit(Length(A) < Length(B));
  LBorrow := 0;
  for I := 0 to LLen - 1 do
  begin
    LBorrow := Integer(A[I]) - Integer(B[I]) - LBorrow;
    if LBorrow < 0 then
      LBorrow := 1
    else
      LBorrow := 0;
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
  if ACondition then
    LMask := $FF
  else
    LMask := $00;
  for I := 0 to LLen - 1 do
    Result[I] := (AIfTrue[I] and LMask) or (AIfFalse[I] and (not LMask));
end;

procedure CTBigIntConditionalSwap(ACondition: Boolean; var A, B: TBytes);
var
  I, LLen: Integer;
  LMask, LT: Byte;
begin
  LLen := Length(A);
  if ACondition then
    LMask := $FF
  else
    LMask := $00;
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
