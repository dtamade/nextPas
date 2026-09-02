function TPreprocessor.EvalSimpleCondition(const AArg: string): Boolean;
begin
  Result := EvalIfExpr(AArg);
end;

procedure TPreprocessor.EvalSkipWS;
begin
  while (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] in [' ', #9]) do
    Inc(FEvalPos);
end;

function TPreprocessor.EvalPeekChar: Char;
begin
  EvalSkipWS;
  if FEvalPos <= Length(FEvalExpr) then Result := FEvalExpr[FEvalPos]
  else Result := #0;
end;

function TPreprocessor.EvalMatchStr(const S: string): Boolean;
var
  I: LongInt;
begin
  EvalSkipWS;
  if FEvalPos + Length(S) - 1 > Length(FEvalExpr) then Exit(False);
  for I := 1 to Length(S) do
    if UpCase(FEvalExpr[FEvalPos + I - 1]) <> UpCase(S[I]) then Exit(False);
  if (FEvalPos + Length(S) <= Length(FEvalExpr)) and
    (FEvalExpr[FEvalPos + Length(S)] in ['A'..'Z','a'..'z','0'..'9','_']) then
    Exit(False);
  Inc(FEvalPos, Length(S));
  Result := True;
end;

function TPreprocessor.EvalParseInt: Int64;
var
  Start: LongInt;
  Neg: Boolean;
begin
  EvalSkipWS;
  Neg := False;
  if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '-') then
  begin Neg := True; Inc(FEvalPos); EvalSkipWS; end;
  if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '$') then
  begin
    Inc(FEvalPos); Start := FEvalPos;
    while (FEvalPos <= Length(FEvalExpr)) and
      (FEvalExpr[FEvalPos] in ['0'..'9','A'..'F','a'..'f']) do Inc(FEvalPos);
    Result := StrToInt64Def('$' + Copy(FEvalExpr, Start, FEvalPos - Start), 0);
  end
  else
  begin
    Start := FEvalPos;
    while (FEvalPos <= Length(FEvalExpr)) and
      (FEvalExpr[FEvalPos] in ['0'..'9']) do Inc(FEvalPos);
    Result := StrToInt64Def(Copy(FEvalExpr, Start, FEvalPos - Start), 0);
  end;
  if Neg then Result := -Result;
end;

function TPreprocessor.EvalParseIdent: string;
var
  Start: LongInt;
begin
  EvalSkipWS;
  Start := FEvalPos;
  while (FEvalPos <= Length(FEvalExpr)) and
    (FEvalExpr[FEvalPos] in ['A'..'Z','a'..'z','0'..'9','_']) do Inc(FEvalPos);
  Result := Copy(FEvalExpr, Start, FEvalPos - Start);
end;

function TPreprocessor.EvalAtom: Int64;
var
  Id, Inner: string;
begin
  EvalSkipWS;
  if EvalPeekChar = '(' then
  begin Inc(FEvalPos); Result := EvalOr; EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    Exit;
  end;
  if EvalMatchStr('not') then Exit(Ord(EvalAtom = 0));
  if EvalMatchStr('true') then Exit(1);
  if EvalMatchStr('false') then Exit(0);
  if (EvalPeekChar in ['0'..'9','$']) or
    ((EvalPeekChar = '-') and (FEvalPos < Length(FEvalExpr)) and
     (FEvalExpr[FEvalPos+1] in ['0'..'9','$'])) then
    Exit(EvalParseInt);
  Id := EvalParseIdent;
  if Id = '' then Exit(0);
  if LowerCase(Id) = 'defined' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    Inner := EvalParseIdent;
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    if FDefines.IsDefined(Inner) then Result := 1 else Result := 0;
  end
  else if LowerCase(Id) = 'sizeof' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    Inner := LowerCase(EvalParseIdent);
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    if (Inner = 'pointer') or (Inner = 'ptrint') or (Inner = 'ptruint') or
      (Inner = 'nativeint') or (Inner = 'nativeuint') then
      Result := {$ifdef CPU64}8{$else}4{$endif}
    else if (Inner = 'byte') or (Inner = 'shortint') or (Inner = 'boolean') or
      (Inner = 'ansichar') or (Inner = 'char') then
      Result := 1
    else if (Inner = 'word') or (Inner = 'smallint') or (Inner = 'widechar') then
      Result := 2
    else if (Inner = 'dword') or (Inner = 'longint') or (Inner = 'cardinal') or
      (Inner = 'longword') or (Inner = 'single') then
      Result := 4
    else if (Inner = 'qword') or (Inner = 'int64') or (Inner = 'double') or
      (Inner = 'comp') or (Inner = 'currency') then
      Result := 8
    else if (Inner = 'extended') then
      Result := 10
    else
      Result := 0;
  end
  else if LowerCase(Id) = 'declared' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    EvalParseIdent;
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    Result := 0;
  end
  else
  begin
    if FDefines.TryGetValue(Id, Inner) then
      Result := StrToInt64Def(Inner, Ord(FDefines.IsDefined(Id)))
    else if FDefines.IsDefined(Id) then
      Result := 1
    else
      Result := 0;
  end;
end;

function TPreprocessor.EvalMul: Int64;
var
  R: Int64;
begin
  Result := EvalAtom;
  while True do
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '*') then
    begin Inc(FEvalPos); Result := Result * EvalAtom; end
    else if EvalMatchStr('div') then
    begin R := EvalAtom; if R <> 0 then Result := Result div R; end
    else if EvalMatchStr('mod') then
    begin R := EvalAtom; if R <> 0 then Result := Result mod R; end
    else Break;
  end;
end;

function TPreprocessor.EvalAdd: Int64;
begin
  Result := EvalMul;
  while True do
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '+') then
    begin Inc(FEvalPos); Result := Result + EvalMul; end
    else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '-') then
    begin Inc(FEvalPos); Result := Result - EvalMul; end
    else Break;
  end;
end;

function TPreprocessor.EvalCmp: Int64;
var
  R: Int64;
begin
  Result := EvalAdd;
  EvalSkipWS;
  if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') and
    (FEvalExpr[FEvalPos+1] = '>') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result <> R); end
  else if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '>') and
    (FEvalExpr[FEvalPos+1] = '=') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result >= R); end
  else if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') and
    (FEvalExpr[FEvalPos+1] = '=') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result <= R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '=') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result = R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '>') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result > R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result < R); end;
end;

function TPreprocessor.EvalAnd: Int64;
begin
  Result := EvalCmp;
  while EvalMatchStr('and') do
    Result := Ord((Result <> 0) and (EvalCmp <> 0));
end;

function TPreprocessor.EvalOr: Int64;
begin
  Result := EvalAnd;
  while EvalMatchStr('or') do
    Result := Ord((Result <> 0) or (EvalAnd <> 0));
end;

function TPreprocessor.EvalIfExpr(const AExpr: string): Boolean;
begin
  FEvalExpr := AExpr;
  FEvalPos := 1;
  Result := EvalOr <> 0;
end;
