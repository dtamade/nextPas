{ Shared bare-FPC-RTL uses-clause scanner for source contract tests.
  Only nextpas.core.system may uses FPC RTL; dotted nextpas.core.platform.windows.* is OK.
  Include after settings; pure functions only (no Check dependency). }

function FpcRtlScan_IsIdentStart(C: Char): Boolean;
begin
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or (C = '_');
end;

function FpcRtlScan_IsIdentChar(C: Char): Boolean;
begin
  Result := FpcRtlScan_IsIdentStart(C) or ((C >= '0') and (C <= '9'));
end;

function FpcRtlScan_LowerChar(C: Char): Char;
begin
  if (C >= 'A') and (C <= 'Z') then
    Result := Char(Ord(C) + 32)
  else
    Result := C;
end;

function FpcRtlScan_LowerStr(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    Result[I] := FpcRtlScan_LowerChar(Result[I]);
end;

function FpcRtlScan_StripNoise(const ASource: string): string;
var
  I, N: Integer;
  C: Char;
begin
  N := Length(ASource);
  I := 1;
  Result := '';
  while I <= N do
  begin
    C := ASource[I];
    if C = '''' then
    begin
      Inc(I);
      while I <= N do
      begin
        if ASource[I] = '''' then
        begin
          if (I < N) and (ASource[I + 1] = '''') then
            Inc(I, 2)
          else
          begin
            Inc(I);
            Break;
          end;
        end
        else
          Inc(I);
      end;
      Result := Result + ' ';
    end
    else if (C = '/') and (I < N) and (ASource[I + 1] = '/') then
    begin
      Inc(I, 2);
      while (I <= N) and (ASource[I] <> #10) and (ASource[I] <> #13) do
        Inc(I);
    end
    else if (C = '(') and (I < N) and (ASource[I + 1] = '*') then
    begin
      Inc(I, 2);
      while I < N do
      begin
        if (ASource[I] = '*') and (ASource[I + 1] = ')') then
        begin
          Inc(I, 2);
          Break;
        end;
        Inc(I);
      end;
      Result := Result + ' ';
    end
    else if C = '{' then
    begin
      Inc(I);
      while (I <= N) and (ASource[I] <> '}') do
        Inc(I);
      if I <= N then
        Inc(I);
      Result := Result + ' ';
    end
    else
    begin
      Result := Result + C;
      Inc(I);
    end;
  end;
end;

function FpcRtlScan_IsWordAt(const S: string; APos: Integer; const AWord: string): Boolean;
var
  I, WLen: Integer;
begin
  WLen := Length(AWord);
  if (APos < 1) or (APos + WLen - 1 > Length(S)) then
    Exit(False);
  if (APos > 1) and FpcRtlScan_IsIdentChar(S[APos - 1]) then
    Exit(False);
  if (APos + WLen <= Length(S)) and FpcRtlScan_IsIdentChar(S[APos + WLen]) then
    Exit(False);
  for I := 1 to WLen do
    if FpcRtlScan_LowerChar(S[APos + I - 1]) <> FpcRtlScan_LowerChar(AWord[I]) then
      Exit(False);
  Result := True;
end;

function FpcRtlScan_IsBannedUnit(const AUnitLower: string): Boolean;
begin
  Result :=
    (AUnitLower = 'sysutils') or
    (AUnitLower = 'classes') or
    (AUnitLower = 'baseunix') or
    (AUnitLower = 'unix') or
    (AUnitLower = 'windows') or
    (AUnitLower = 'dos') or
    (AUnitLower = 'objects') or
    (AUnitLower = 'variants') or
    (AUnitLower = 'typinfo') or
    (AUnitLower = 'ctypes');
end;

{ True if any uses-clause lists a bare FPC RTL unit name. }
function FindBareFpcRtlInUses(const ASource: string; out AUnitName: string): Boolean;
var
  LClean: string;
  I, N, Start: Integer;
  UnitName: string;
  Dotted: Boolean;
begin
  Result := False;
  AUnitName := '';
  LClean := FpcRtlScan_StripNoise(ASource);
  N := Length(LClean);
  I := 1;
  while I <= N do
  begin
    if FpcRtlScan_IsWordAt(LClean, I, 'uses') then
    begin
      I := I + 4;
      while (I <= N) and (LClean[I] <> ';') do
      begin
        while (I <= N) and (LClean[I] <= ' ') do
          Inc(I);
        if (I > N) or (LClean[I] = ';') then
          Break;
        if not FpcRtlScan_IsIdentStart(LClean[I]) then
        begin
          Inc(I);
          Continue;
        end;
        Start := I;
        Dotted := False;
        while (I <= N) and (FpcRtlScan_IsIdentChar(LClean[I]) or (LClean[I] = '.')) do
        begin
          if LClean[I] = '.' then
            Dotted := True;
          Inc(I);
        end;
        UnitName := FpcRtlScan_LowerStr(Copy(LClean, Start, I - Start));
        if (not Dotted) and FpcRtlScan_IsBannedUnit(UnitName) then
        begin
          AUnitName := UnitName;
          Exit(True);
        end;
        while (I <= N) and (LClean[I] <> ',') and (LClean[I] <> ';') do
          Inc(I);
        if (I <= N) and (LClean[I] = ',') then
          Inc(I);
      end;
      if (I <= N) and (LClean[I] = ';') then
        Inc(I);
    end
    else
      Inc(I);
  end;
end;
