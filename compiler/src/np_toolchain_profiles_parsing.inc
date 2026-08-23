function TrimQuotes(const Value: string): string;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function ParseBooleanLiteral(
  const Value: string;
  const FieldName: string
): Boolean;
var
  NormalizedValue: string;
begin
  NormalizedValue := LowerCase(Trim(Value));
  if NormalizedValue = 'true' then
    Exit(True);
  if NormalizedValue = 'false' then
    Exit(False);

  raise EToolProfileError.Create(
    'tool-profile-invalid-boolean: ' + FieldName + '=' + Value
  );
end;

function ParseStringArrayLiteral(const Value: string): TStringArray;
var
  Buffer: string;
  Index: SizeInt;
  InQuotes: Boolean;
  InnerValue: string;
  NextIndex: SizeInt;
begin
  SetLength(Result, 0);
  InnerValue := Trim(Value);
  if (InnerValue = '[]') or (InnerValue = '') then
    Exit;

  if (InnerValue[1] <> '[') or (InnerValue[Length(InnerValue)] <> ']') then
    raise EToolProfileError.Create('tool-profile-invalid-array: ' + Value);

  InnerValue := Copy(InnerValue, 2, Length(InnerValue) - 2);
  Buffer := '';
  InQuotes := False;
  for Index := 1 to Length(InnerValue) do
  begin
    if InnerValue[Index] = '"' then
    begin
      InQuotes := not InQuotes;
      Buffer := Buffer + InnerValue[Index];
      Continue;
    end;

    if (InnerValue[Index] = ',') and not InQuotes then
    begin
      NextIndex := Length(Result);
      SetLength(Result, NextIndex + 1);
      Result[NextIndex] := TrimQuotes(Buffer);
      Buffer := '';
      Continue;
    end;

    Buffer := Buffer + InnerValue[Index];
  end;

  if Trim(Buffer) <> '' then
  begin
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := TrimQuotes(Buffer);
  end;
end;

function ResolveToolProfileRoot(const AConfigPath: string): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(AConfigPath)) + '..' +
    DirectorySeparator + 'tool-profiles'
  );
end;

function FirstStringOrDefault(
  const AValues: TStringArray;
  const ADefault: string
): string;
begin
  if Length(AValues) = 0 then
    Exit(ADefault);

  Result := AValues[0];
end;

procedure RequireField(const Value: string; const FieldName: string);
begin
  if Trim(Value) = '' then
    raise EToolProfileError.Create('tool-profile-missing-field: ' + FieldName);
end;

procedure RequireFlag(const AssignedValue: Boolean; const FieldName: string);
begin
  if not AssignedValue then
    raise EToolProfileError.Create('tool-profile-missing-field: ' + FieldName);
end;

function ProfilePath(
  const ARootPath: string;
  const ACategory: string;
  const AProfileId: string
): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ARootPath) + ACategory + DirectorySeparator +
    AProfileId + '.toml'
  );
end;

procedure NextKeyValue(
  const ALine: string;
  var ASection: string;
  out AKey: string;
  out AValue: string
);
var
  SeparatorIndex: SizeInt;
  TrimmedLine: string;
begin
  AKey := '';
  AValue := '';
  TrimmedLine := Trim(ALine);
  if TrimmedLine = '' then
    Exit;
  if TrimmedLine[1] = '#' then
    Exit;

  if (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
  begin
    ASection := LowerCase(
      Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2))
    );
    Exit;
  end;

  SeparatorIndex := Pos('=', TrimmedLine);
  if SeparatorIndex = 0 then
    Exit;

  AKey := LowerCase(Trim(Copy(TrimmedLine, 1, SeparatorIndex - 1)));
  AValue := Trim(Copy(TrimmedLine, SeparatorIndex + 1, MaxInt));
end;

