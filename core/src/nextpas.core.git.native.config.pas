unit nextpas.core.git.native.config;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base;

{ Minimal git-config reader for the native subfamily.

  Parses the INI dialect used by `.git/config` (and any file passed via
  `--file`). Sections are `[name]` or `[name "subsection"]`; subsection
  case is preserved while section and key names are case-folded. Values
  may be quoted and carry `\"`, `\\`, `\n`, `\t`, `\b` escapes. Comments
  introduced by `#` or `;` outside quotes are stripped after the value.
  Duplicate keys are preserved in insertion order; `Get` returns the
  last value (matching `git config --get`), `GetAll` returns all.

  Corrupt headers raise EGitError; missing file yields empty config. }

type
  TGitConfigEntry = record
    Key: string;
    Value: string;
  end;
  TGitConfig = record
    Entries: array of TGitConfigEntry;
  end;

function GitConfigPath(const AGitDir: string): string; inline;
function GitConfigExists(const AGitDir: string): Boolean; inline;
function GitParseConfig(const AData: TBytes): TGitConfig;
function GitReadConfig(const AGitDir: string): TGitConfig;
function GitConfigHas(const AConfig: TGitConfig; const AKey: string): Boolean;
function GitConfigGet(const AConfig: TGitConfig; const AKey: string): string;
function GitConfigGetAll(const AConfig: TGitConfig; const AKey: string): TStringArray;
function GitConfigGetBool(const AConfig: TGitConfig; const AKey: string; out AValue: Boolean): Boolean;

implementation

function GitConfigPath(const AGitDir: string): string;
begin
  Result := PathJoin2(AGitDir, 'config');
end;

function GitConfigExists(const AGitDir: string): Boolean;
begin
  Result := FileExists(GitConfigPath(AGitDir));
end;

function ToLowerAscii(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

function TrimSpaces(const S: string): string;
var
  L, R: Integer;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if R < L then Exit('');
  Result := Copy(S, L, R - L + 1);
end;

function StripInlineComment(const S: string): string;
var
  I: Integer;
  InQuote: Boolean;
  Esc: Boolean;
begin
  InQuote := False;
  Esc := False;
  for I := 1 to Length(S) do
  begin
    if Esc then
    begin
      Esc := False;
      Continue;
    end;
    if S[I] = '\' then
    begin
      if InQuote then Esc := True;
      Continue;
    end;
    if S[I] = '"' then
    begin
      InQuote := not InQuote;
      Continue;
    end;
    if not InQuote and ((S[I] = '#') or (S[I] = ';')) then
      Exit(TrimSpaces(Copy(S, 1, I - 1)));
  end;
  Result := S;
end;

function UnescapeValue(const S: string): string;
var
  I: Integer;
  Res: string;
  Ch: Char;
  IsQuoted: Boolean;
  Inner: string;
begin
  IsQuoted := (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"');
  if IsQuoted then
    Inner := Copy(S, 2, Length(S) - 2)
  else
    Inner := S;
  Res := '';
  I := 1;
  while I <= Length(Inner) do
  begin
    Ch := Inner[I];
    if Ch = '\' then
    begin
      Inc(I);
      if I > Length(Inner) then Break;
      case Inner[I] of
        'n': Res := Res + #10;
        't': Res := Res + #9;
        'b': Res := Res + #8;
        '\': Res := Res + '\';
        '"': Res := Res + '"';
      else
        Res := Res + Inner[I];
      end;
    end
    else
      Res := Res + Ch;
    Inc(I);
  end;
  Result := Res;
end;

function UnescapeSubsection(const S: string): string;
var
  J: Integer;
begin
  Result := '';
  J := 1;
  while J <= Length(S) do
  begin
    if (S[J] = '\') and (J < Length(S)) then
    begin
      if S[J+1] = '"' then Result := Result + '"'
      else if S[J+1] = '\' then Result := Result + '\'
      else Result := Result + S[J+1];
      Inc(J, 2);
    end
    else
    begin
      Result := Result + S[J];
      Inc(J);
    end;
  end;
end;

function NormalizeKey(const AKey: string): string;
begin
  Result := ToLowerAscii(TrimSpaces(AKey));
end;

function FullKey(const ASection, ASub, AKey: string): string;
var
  Sec, K: string;
begin
  Sec := ToLowerAscii(ASection);
  K := ToLowerAscii(AKey);
  if ASub <> '' then
    Result := Sec + '.' + ASub + '.' + K
  else
    Result := Sec + '.' + K;
end;

function NormalizeLookupKey(const AKey: string): string;
var
  Parts: TStringArray;
  I, DotCount: Integer;
  Sec, Sub, Key: string;
  LastDot, FirstDot: Integer;
begin
  Result := AKey;
  DotCount := 0;
  for I := 1 to Length(AKey) do
    if AKey[I] = '.' then Inc(DotCount);
  if DotCount = 1 then
  begin
    FirstDot := Pos('.', AKey);
    Sec := Copy(AKey, 1, FirstDot - 1);
    Key := Copy(AKey, FirstDot + 1, MaxInt);
    Result := ToLowerAscii(Sec) + '.' + ToLowerAscii(Key);
    Exit;
  end;
  if DotCount >= 2 then
  begin
    FirstDot := Pos('.', AKey);
    LastDot := 0;
    for I := Length(AKey) downto 1 do
      if AKey[I] = '.' then
      begin
        LastDot := I;
        Break;
      end;
    Sec := Copy(AKey, 1, FirstDot - 1);
    Sub := Copy(AKey, FirstDot + 1, LastDot - FirstDot - 1);
    Key := Copy(AKey, LastDot + 1, MaxInt);
    Result := ToLowerAscii(Sec) + '.' + Sub + '.' + ToLowerAscii(Key);
    Exit;
  end;
  Result := ToLowerAscii(AKey);
end;

function GitParseConfig(const AData: TBytes): TGitConfig;
var
  Text: string;
  Lines: TStringArray;
  I: Integer;
  Line, Trimmed: string;
  CurSec, CurSub: string;
  EqPos: Integer;
  K, V, FKey: string;
  Start, P, Count: Integer;
  NeedPush: Boolean;
begin
  Result.Entries := nil;
  if Length(AData) = 0 then
    Exit;
  Text := GitBytesToString(AData);
  Count := 0;
  for I := 1 to Length(Text) do
    if Text[I] = #10 then Inc(Count);
  SetLength(Lines, 0);
  Start := 1;
  for I := 1 to Length(Text) do
    if Text[I] = #10 then
    begin
      Line := Copy(Text, Start, I - Start);
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line) - 1);
      SetLength(Lines, Length(Lines) + 1);
      Lines[High(Lines)] := Line;
      Start := I + 1;
    end;
  if Start <= Length(Text) then
  begin
    Line := Copy(Text, Start, MaxInt);
    if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
      SetLength(Line, Length(Line) - 1);
    SetLength(Lines, Length(Lines) + 1);
    Lines[High(Lines)] := Line;
  end;

  CurSec := '';
  CurSub := '';
  for I := 0 to High(Lines) do
  begin
    Line := Lines[I];
    Trimmed := TrimSpaces(Line);
    if Trimmed = '' then Continue;
    if (Trimmed[1] = '#') or (Trimmed[1] = ';') then Continue;
    if (Trimmed[1] = '[') then
    begin
      P := Pos(']', Trimmed);
      if P = 0 then
        raise EGitError.CreateFmt('config bad section header "%s"', [Line]);
      Line := Copy(Trimmed, 2, P - 2);
      Line := TrimSpaces(Line);
      if Line = '' then
        raise EGitError.CreateFmt('config empty section "%s"', [Trimmed]);
      if (Pos('"', Line) > 0) then
      begin
        EqPos := Pos('"', Line);
        CurSec := TrimSpaces(Copy(Line, 1, EqPos - 1));
        CurSub := Copy(Line, EqPos + 1, MaxInt);
        EqPos := Pos('"', CurSub);
        if EqPos = 0 then
          raise EGitError.CreateFmt('config bad subsection "%s"', [Trimmed]);
        CurSub := Copy(CurSub, 1, EqPos - 1);
        CurSub := UnescapeSubsection(CurSub);
      end
      else if Pos('.', Line) > 0 then
      begin
        EqPos := Pos('.', Line);
        CurSec := Copy(Line, 1, EqPos - 1);
        CurSub := Copy(Line, EqPos + 1, MaxInt);
        CurSec := TrimSpaces(CurSec);
      end
      else
      begin
        CurSec := Line;
        CurSub := '';
      end;
      Continue;
    end;
    EqPos := Pos('=', Line);
    if EqPos = 0 then
    begin
      K := TrimSpaces(Line);
      V := '';
    end
    else
    begin
      K := TrimSpaces(Copy(Line, 1, EqPos - 1));
      V := Copy(Line, EqPos + 1, MaxInt);
      V := TrimSpaces(V);
      V := StripInlineComment(V);
      V := UnescapeValue(V);
    end;
    if K = '' then Continue;
    if CurSec = '' then
      raise EGitError.CreateFmt('config key outside section "%s"', [Line]);
    FKey := FullKey(CurSec, CurSub, K);
    SetLength(Result.Entries, Length(Result.Entries) + 1);
    Result.Entries[High(Result.Entries)].Key := FKey;
    Result.Entries[High(Result.Entries)].Value := V;
  end;
end;

function GitReadConfig(const AGitDir: string): TGitConfig;
var
  Path: string;
  Data: TBytes;
begin
  Result.Entries := nil;
  Path := GitConfigPath(AGitDir);
  if not FileExists(Path) then
    Exit;
  Data := ReadFile(Path);
  Result := GitParseConfig(Data);
end;

function GitConfigHas(const AConfig: TGitConfig; const AKey: string): Boolean;
var
  NKey: string;
  I: Integer;
begin
  NKey := NormalizeLookupKey(AKey);
  for I := 0 to High(AConfig.Entries) do
    if NormalizeLookupKey(AConfig.Entries[I].Key) = NKey then
      Exit(True);
  Result := False;
end;

function GitConfigGet(const AConfig: TGitConfig; const AKey: string): string;
var
  NKey: string;
  I: Integer;
  Found: Boolean;
begin
  NKey := NormalizeLookupKey(AKey);
  Found := False;
  Result := '';
  for I := 0 to High(AConfig.Entries) do
    if NormalizeLookupKey(AConfig.Entries[I].Key) = NKey then
    begin
      Result := AConfig.Entries[I].Value;
      Found := True;
    end;
  if not Found then
    raise EGitError.CreateFmt('config key not found "%s"', [AKey]);
end;

function GitConfigGetAll(const AConfig: TGitConfig; const AKey: string): TStringArray;
var
  NKey: string;
  I, C: Integer;
begin
  Result := nil;
  NKey := NormalizeLookupKey(AKey);
  C := 0;
  for I := 0 to High(AConfig.Entries) do
    if NormalizeLookupKey(AConfig.Entries[I].Key) = NKey then
    begin
      SetLength(Result, C + 1);
      Result[C] := AConfig.Entries[I].Value;
      Inc(C);
    end;
end;

function GitConfigGetBool(const AConfig: TGitConfig; const AKey: string; out AValue: Boolean): Boolean;
var
  V: string;
begin
  try
    V := GitConfigGet(AConfig, AKey);
  except
    Result := False;
    Exit;
  end;
  V := ToLowerAscii(TrimSpaces(V));
  if (V = 'true') or (V = 'yes') or (V = 'on') or (V = '1') then
  begin
    AValue := True;
    Result := True;
  end
  else if (V = 'false') or (V = 'no') or (V = 'off') or (V = '0') or (V = '') then
  begin
    AValue := False;
    Result := True;
  end
  else
    Result := False;
end;

end.
