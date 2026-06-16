function ScalarNormalizeSignedZeroSingle(const aInput, aOutput: Single): Single; inline;
var
  LBits: DWord;
  LInput: Single;
begin
  Result := aOutput;
  if aOutput = 0.0 then
  begin
    LBits := 0;
    LInput := aInput;
    Move(LInput, LBits, SizeOf(LBits));
    if (LBits and DWord($80000000)) <> 0 then
      Result := -0.0;
  end;
end;

function ScalarNormalizeSignedZeroDouble(const aInput, aOutput: Double): Double; inline;
var
  LBits: QWord;
  LInput: Double;
begin
  Result := aOutput;
  if aOutput = 0.0 then
  begin
    LBits := 0;
    LInput := aInput;
    Move(LInput, LBits, SizeOf(LBits));
    if (LBits and QWord($8000000000000000)) <> 0 then
      Result := -0.0;
  end;
end;
