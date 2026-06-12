function Format(const Fmt: String; const Args: array of String): String;
var
  i, argIndex, digit, start: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(Fmt) do
  begin
    if (Fmt[i] = '{') and (i < Length(Fmt)) then
    begin
      start := i;
      Inc(i);
      // double {{ means literal {
      if (i <= Length(Fmt)) and (Fmt[i] = '{') then
      begin
        Result := Result + '{';
        Inc(i);
        continue;
      end;
      // parse argument index
      argIndex := 0;
      while (i <= Length(Fmt)) and (Fmt[i] >= '0') and (Fmt[i] <= '9') do
      begin
        digit := Ord(Fmt[i]) - Ord('0');
        argIndex := argIndex * 10 + digit;
        Inc(i);
      end;
      // must be followed by }
      if (i <= Length(Fmt)) and (Fmt[i] = '}') and (start + 1 < i) then
      begin
        if argIndex < Length(Args) then
          Result := Result + Args[argIndex];
        Inc(i);
        continue;
      end;
      // invalid placeholder, output literally
      while start < i do
      begin
        Result := Result + Fmt[start];
        Inc(start);
      end;
    end
    else if (Fmt[i] = '}') and (i < Length(Fmt)) and (Fmt[i + 1] = '}') then
    begin
      // double }} means literal }
      Result := Result + '}';
      Inc(i, 2);
    end
    else
    begin
      Result := Result + Fmt[i];
      Inc(i);
    end;
  end;
end;