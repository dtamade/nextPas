unit nextpas.core.props;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.text.view,
  nextpas.core.io.intf,
  nextpas.core.io.scanner;

type
  TPropsEntry = record
    Key: string;
    Value: string;
  end;
  TPropsArray = array of TPropsEntry;

function ParseKeyValueText(const AText: string; ASep: Char = '='): TPropsArray;
function ParseKeyValueLines(const ALines: array of string; ASep: Char = '='): TPropsArray;
function ParseKeyValueReader(const AReader: IReader; ASep: Char = '='): TPropsArray;
function ReadKeyValueFile(const APath: string; ASep: Char = '='): TPropsArray;
procedure WriteKeyValueFile(const APath: string; const AEntries: TPropsArray; ASep: Char = '=');

function PropsGet(const AEntries: TPropsArray; const AKey: string; const ADefault: string = ''): string;
function PropsHas(const AEntries: TPropsArray; const AKey: string): Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text,
  nextpas.core.fs;

function TrimStr(const S: string): string;
var
  LStart, LEnd: Int32;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] <= ' ') do Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] <= ' ') do Dec(LEnd);
  if LStart > LEnd then
    Result := ''
  else
    Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function ParseLine(const ALine: string; ASep: Char; out AKey, AValue: string): Boolean;
var
  LPos: Int32;
  LTrimmed: string;
begin
  LTrimmed := TrimStr(ALine);
  if (Length(LTrimmed) = 0) or (LTrimmed[1] = '#') or (LTrimmed[1] = ';') then
  begin
    Result := False;
    Exit;
  end;
  LPos := Pos(ASep, LTrimmed);
  if LPos = 0 then
  begin
    AKey := LTrimmed;
    AValue := '';
  end
  else
  begin
    AKey := TrimStr(Copy(LTrimmed, 1, LPos - 1));
    AValue := TrimStr(Copy(LTrimmed, LPos + 1, Length(LTrimmed)));
  end;
  Result := Length(AKey) > 0;
end;

function ParseKeyValueLines(const ALines: array of string; ASep: Char): TPropsArray;
var
  LI, LCount: Int32;
  LKey, LValue: string;
begin
  Result := nil;
  LCount := 0;
  SetLength(Result, Length(ALines));
  for LI := 0 to Length(ALines) - 1 do
  begin
    if ParseLine(ALines[LI], ASep, LKey, LValue) then
    begin
      Result[LCount].Key := LKey;
      Result[LCount].Value := LValue;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function ParseKeyValueText(const AText: string; ASep: Char): TPropsArray;
var
  LLines: TStringArray;
  LI: Int32;
begin
  if Length(AText) = 0 then begin Result := nil; Exit; end;
  LLines := TextSplit(AText, #10);
  for LI := 0 to Length(LLines) - 1 do
    if (Length(LLines[LI]) > 0) and (LLines[LI][Length(LLines[LI])] = #13) then
      LLines[LI] := Copy(LLines[LI], 1, Length(LLines[LI]) - 1);
  Result := ParseKeyValueLines(LLines, ASep);
end;

function ParseKeyValueReader(const AReader: IReader; ASep: Char): TPropsArray;
var
  LScanner: IScanner;
  LCount, LCap: Int32;
  LKey, LValue: string;
begin
  Result := nil;
  LScanner := CreateScanner(AReader);
  LCount := 0;
  LCap := 32;
  SetLength(Result, LCap);
  while LScanner.Scan do
  begin
    if ParseLine(LScanner.Text, ASep, LKey, LValue) then
    begin
      if LCount >= LCap then
      begin
        LCap := LCap * 2;
        SetLength(Result, LCap);
      end;
      Result[LCount].Key := LKey;
      Result[LCount].Value := LValue;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function ReadKeyValueFile(const APath: string; ASep: Char): TPropsArray;
var
  LText: string;
begin
  LText := ReadFileText(APath);
  Result := ParseKeyValueText(LText, ASep);
end;

procedure WriteKeyValueFile(const APath: string; const AEntries: TPropsArray; ASep: Char);
var
  LLines: TStringArray;
  LI: Int32;
begin
  SetLength(LLines, Length(AEntries));
  for LI := 0 to Length(AEntries) - 1 do
    LLines[LI] := AEntries[LI].Key + ASep + AEntries[LI].Value;
  WriteFileLines(APath, LLines);
end;

function PropsGet(const AEntries: TPropsArray; const AKey: string; const ADefault: string): string;
var
  LI: Int32;
begin
  for LI := 0 to Length(AEntries) - 1 do
    if AEntries[LI].Key = AKey then
    begin
      Result := AEntries[LI].Value;
      Exit;
    end;
  Result := ADefault;
end;

function PropsHas(const AEntries: TPropsArray; const AKey: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to Length(AEntries) - 1 do
    if AEntries[LI].Key = AKey then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

end.
