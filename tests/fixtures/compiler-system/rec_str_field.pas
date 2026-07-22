{ Batch 25: local record with string field store/load + Length.
  Expected: Halt(42) = Length('Hello') + 37. Not M2-A. }
program rec_str_field;
type
  TRec = record
    S: string;
    N: Integer;
  end;
var
  R: TRec;
begin
  R.S := 'Hello';
  R.N := 37;
  Halt(Length(R.S) + R.N);
end.
