{ Batch 25: const record param + string sret + post-call field read.
  Repro for Fail path: string-return helper must not clobber const record slot.
  Expected: Halt(42) = Length(GetS(R)) + GetN(R) = 5 + 37. Not M2-A. }
program rec_const_str_sret;
type
  TRec = record
    S: string;
    N: Integer;
  end;

function GetS(const A: TRec): string;
begin
  Result := A.S;
end;

function GetN(const A: TRec): Integer;
begin
  Result := A.N;
end;

var
  R: TRec;
  L: Integer;
begin
  R.S := 'Hello';
  R.N := 37;
  L := Length(GetS(R));
  Halt(L + GetN(R));
end.
