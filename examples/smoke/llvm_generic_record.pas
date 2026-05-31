program llvm_generic_record;
type
  TPair = record
    First, Second: Integer;
  end;

function MakePair(A, B: Integer): TPair;
begin
  Result.First := A;
  Result.Second := B;
end;

generic function Apply<T>(P: TPair; Op: T): Integer;
begin
  Result := P.First + P.Second + Op;
end;

var P: TPair;
begin
  P := MakePair(10, 20);
  Halt(specialize Apply<Integer>(P, 12));
end.
