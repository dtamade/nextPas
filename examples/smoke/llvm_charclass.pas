program Llvm_charclass;

function IsDigit(Ch: Integer): Integer;
begin
  if (Ch >= 48) and (Ch <= 57) then
    IsDigit := 1
  else
    IsDigit := 0;
end;

function IsAlpha(Ch: Integer): Integer;
begin
  if ((Ch >= 65) and (Ch <= 90)) or ((Ch >= 97) and (Ch <= 122)) then
    IsAlpha := 1
  else
    IsAlpha := 0;
end;

function Classify(Ch: Integer): Integer;
begin
  if IsDigit(Ch) = 1 then
    Classify := 1
  else if IsAlpha(Ch) = 1 then
    Classify := 2
  else
    Classify := 0;
end;

var
  Score: Integer;
begin
  Score := Classify(48) + Classify(65) + Classify(97) + Classify(32);
  Halt(Score);
end.
