unit nextpas.core.ini;
{**
 * @desc INI 配置文件解析模块。零 SysUtils 依赖，Go ini 风格简洁接口。
 *       支持 sections、key=value、注释(; 和 #)、空行跳过、值中空格保留。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.errors;

type
  TStringArray = array of string;

  TIniEntry = record
    Key: string;
    Value: string;
  end;

  TIniSection = record
    Name: string;
    Entries: array of TIniEntry;
    EntryCount: Integer;
  end;

  TIniFile = class
  private
    FSections: array of TIniSection;
    FSectionCount: Integer;
    function FindSection(const ASection: string): Integer;
    function FindOrCreateSection(const ASection: string): Integer;
    function FindKey(ASectionIdx: Integer; const AKey: string): Integer;
    procedure ParseLine(const ALine: string; var ACurrentSection: Integer);
    function CaseInsensitiveEqual(const A, B: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromString(const AContent: string);
    procedure SaveToFile(const AFileName: string);
    function ToString: string; override;

    function ReadString(const ASection, AKey, ADefault: string): string;
    function ReadInteger(const ASection, AKey: string; ADefault: Int64): Int64;
    function ReadBool(const ASection, AKey: string; ADefault: Boolean): Boolean;
    procedure WriteString(const ASection, AKey, AValue: string);
    procedure WriteInteger(const ASection, AKey: string; AValue: Int64);
    procedure WriteBool(const ASection, AKey: string; AValue: Boolean);

    function SectionExists(const ASection: string): Boolean;
    function KeyExists(const ASection, AKey: string): Boolean;
    procedure DeleteKey(const ASection, AKey: string);
    procedure DeleteSection(const ASection: string);
    function GetSections: TStringArray;
    function GetKeys(const ASection: string): TStringArray;
  end;

implementation

{ TIniFile }

constructor TIniFile.Create;
begin
  inherited Create;
  FSectionCount := 0;
  SetLength(FSections, 0);
  FindOrCreateSection('');
end;

destructor TIniFile.Destroy;
begin
  FSections := nil;
  inherited Destroy;
end;

function TIniFile.CaseInsensitiveEqual(const A, B: string): Boolean;
begin
  Result := LowerCase(A) = LowerCase(B);
end;

function TIniFile.FindSection(const ASection: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FSectionCount - 1 do
    if CaseInsensitiveEqual(FSections[I].Name, ASection) then
      Exit(I);
  Result := -1;
end;

function TIniFile.FindOrCreateSection(const ASection: string): Integer;
begin
  Result := FindSection(ASection);
  if Result >= 0 then
    Exit;
  if FSectionCount >= Length(FSections) then
    SetLength(FSections, FSectionCount + 8);
  FSections[FSectionCount].Name := ASection;
  FSections[FSectionCount].EntryCount := 0;
  SetLength(FSections[FSectionCount].Entries, 0);
  Result := FSectionCount;
  Inc(FSectionCount);
end;

function TIniFile.FindKey(ASectionIdx: Integer; const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FSections[ASectionIdx].EntryCount - 1 do
    if CaseInsensitiveEqual(FSections[ASectionIdx].Entries[I].Key, AKey) then
      Exit(I);
  Result := -1;
end;

procedure TIniFile.ParseLine(const ALine: string; var ACurrentSection: Integer);
var
  LTrimmed: string;
  LEqPos, LClose, LKeyIdx: Integer;
  LKey, LValue, LSectionName: string;
begin
  LTrimmed := TrimLeft(ALine);
  if LTrimmed = '' then
    Exit;
  { Comment lines }
  if (LTrimmed[1] = ';') or (LTrimmed[1] = '#') then
    Exit;
  { Section header }
  if LTrimmed[1] = '[' then
  begin
    LClose := Pos(']', LTrimmed);
    if LClose > 2 then
    begin
      LSectionName := Trim(Copy(LTrimmed, 2, LClose - 2));
      ACurrentSection := FindOrCreateSection(LSectionName);
    end;
    Exit;
  end;
  { Key=Value — use TrimLeft'd line to preserve trailing spaces in value }
  LEqPos := Pos('=', LTrimmed);
  if LEqPos > 0 then
  begin
    LKey := Trim(Copy(LTrimmed, 1, LEqPos - 1));
    LValue := Copy(LTrimmed, LEqPos + 1, Length(LTrimmed) - LEqPos);
    { Trim leading whitespace from value, but preserve trailing }
    LValue := TrimLeft(LValue);
    if LKey <> '' then
    begin
      with FSections[ACurrentSection] do
      begin
        LKeyIdx := FindKey(ACurrentSection, LKey);
        if LKeyIdx >= 0 then
          Entries[LKeyIdx].Value := LValue
        else
        begin
          if EntryCount >= Length(Entries) then
            SetLength(Entries, EntryCount + 8);
          Entries[EntryCount].Key := LKey;
          Entries[EntryCount].Value := LValue;
          Inc(EntryCount);
        end;
      end;
    end;
  end;
end;

procedure TIniFile.LoadFromString(const AContent: string);
var
  LCurrentSection: Integer;
  LStart, LPos, LLen: Integer;
  LLine: string;
begin
  { Reset state }
  FSectionCount := 0;
  SetLength(FSections, 0);
  FindOrCreateSection('');
  LCurrentSection := 0;

  LLen := Length(AContent);
  LStart := 1;
  LPos := 1;
  while LPos <= LLen do
  begin
    if AContent[LPos] = #10 then
    begin
      if (LPos > LStart) and (AContent[LPos - 1] = #13) then
        LLine := Copy(AContent, LStart, LPos - LStart - 1)
      else
        LLine := Copy(AContent, LStart, LPos - LStart);
      ParseLine(LLine, LCurrentSection);
      LStart := LPos + 1;
    end;
    Inc(LPos);
  end;
  { Last line without trailing newline }
  if LStart <= LLen then
  begin
    LLine := Copy(AContent, LStart, LLen - LStart + 1);
    ParseLine(LLine, LCurrentSection);
  end;
end;

procedure TIniFile.LoadFromFile(const AFileName: string);
var
  LFile: TextFile;
  LContent, LLine: string;
  LLen, LCapacity: Integer;

  procedure EnsureContentCapacity(AAdditional: Integer);
  var
    LRequired: Integer;
  begin
    LRequired := LLen + AAdditional;
    if LRequired <= LCapacity then
      Exit;
    if LCapacity = 0 then
      LCapacity := 1024;
    while LCapacity < LRequired do
      LCapacity := LCapacity * 2;
    SetLength(LContent, LCapacity);
  end;

  procedure AppendToContent(const AText: string);
  var
    LTextLen: Integer;
  begin
    LTextLen := Length(AText);
    if LTextLen = 0 then
      Exit;
    EnsureContentCapacity(LTextLen);
    Move(AText[1], LContent[LLen + 1], LTextLen);
    Inc(LLen, LTextLen);
  end;

  procedure AppendContentChar(ACh: AnsiChar);
  begin
    EnsureContentCapacity(1);
    LContent[LLen + 1] := ACh;
    Inc(LLen);
  end;

begin
  LContent := '';
  LLen := 0;
  LCapacity := 0;
  AssignFile(LFile, AFileName);
  {$I-}
  Reset(LFile);
  {$I+}
  if IOResult <> 0 then
    raise ENextPasError.Create('Cannot open file: ' + AFileName, ecIO);
  try
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      AppendToContent(LLine);
      AppendContentChar(#10);
    end;
  finally
    CloseFile(LFile);
  end;
  SetLength(LContent, LLen);
  LoadFromString(LContent);
end;

function TIniFile.ToString: string;
var
  I, J, LTotalLen, LPos: Integer;

  procedure AppendChar(ACh: AnsiChar);
  begin
    Result[LPos] := ACh;
    Inc(LPos);
  end;

  procedure AppendString(const AText: string);
  var
    LTextLen: Integer;
  begin
    LTextLen := Length(AText);
    if LTextLen = 0 then
      Exit;
    Move(AText[1], Result[LPos], LTextLen);
    Inc(LPos, LTextLen);
  end;

begin
  LTotalLen := 0;
  for I := 0 to FSectionCount - 1 do
  begin
    if FSections[I].Name <> '' then
    begin
      if LTotalLen <> 0 then
        Inc(LTotalLen);
      Inc(LTotalLen, Length(FSections[I].Name) + 3);
    end;
    for J := 0 to FSections[I].EntryCount - 1 do
      Inc(LTotalLen,
        Length(FSections[I].Entries[J].Key) + 1 +
        Length(FSections[I].Entries[J].Value) + 1);
  end;

  SetLength(Result, LTotalLen);
  if LTotalLen = 0 then
    Exit;

  LPos := 1;
  for I := 0 to FSectionCount - 1 do
  begin
    if FSections[I].Name <> '' then
    begin
      if LPos > 1 then
        AppendChar(#10);
      AppendChar('[');
      AppendString(FSections[I].Name);
      AppendChar(']');
      AppendChar(#10);
    end;
    for J := 0 to FSections[I].EntryCount - 1 do
    begin
      AppendString(FSections[I].Entries[J].Key);
      AppendChar('=');
      AppendString(FSections[I].Entries[J].Value);
      AppendChar(#10);
    end;
  end;
end;

procedure TIniFile.SaveToFile(const AFileName: string);
var
  LFile: TextFile;
  LContent: string;
begin
  LContent := ToString;
  AssignFile(LFile, AFileName);
  {$I-}
  Rewrite(LFile);
  {$I+}
  if IOResult <> 0 then
    raise ENextPasError.Create('Cannot write file: ' + AFileName, ecIO);
  try
    Write(LFile, LContent);
  finally
    CloseFile(LFile);
  end;
end;

function TIniFile.ReadString(const ASection, AKey, ADefault: string): string;
var
  LSIdx, LKIdx: Integer;
begin
  LSIdx := FindSection(ASection);
  if LSIdx < 0 then
    Exit(ADefault);
  LKIdx := FindKey(LSIdx, AKey);
  if LKIdx < 0 then
    Exit(ADefault);
  Result := FSections[LSIdx].Entries[LKIdx].Value;
end;

function TIniFile.ReadInteger(const ASection, AKey: string; ADefault: Int64): Int64;
var
  LStr: string;
  LVal: Int64;
begin
  LStr := ReadString(ASection, AKey, '');
  if LStr = '' then
    Exit(ADefault);
  if TryStrToInt64(LStr, LVal) then
    Result := LVal
  else
    Result := ADefault;
end;

function TIniFile.ReadBool(const ASection, AKey: string; ADefault: Boolean): Boolean;
var
  LStr: string;
begin
  LStr := LowerCase(Trim(ReadString(ASection, AKey, '')));
  if (LStr = 'true') or (LStr = '1') or (LStr = 'yes') or (LStr = 'on') then
    Result := True
  else if (LStr = 'false') or (LStr = '0') or (LStr = 'no') or (LStr = 'off') then
    Result := False
  else
    Result := ADefault;
end;

procedure TIniFile.WriteString(const ASection, AKey, AValue: string);
var
  LSIdx, LKIdx: Integer;
begin
  LSIdx := FindOrCreateSection(ASection);
  LKIdx := FindKey(LSIdx, AKey);
  if LKIdx >= 0 then
    FSections[LSIdx].Entries[LKIdx].Value := AValue
  else
  begin
    with FSections[LSIdx] do
    begin
      if EntryCount >= Length(Entries) then
        SetLength(Entries, EntryCount + 8);
      Entries[EntryCount].Key := AKey;
      Entries[EntryCount].Value := AValue;
      Inc(EntryCount);
    end;
  end;
end;

procedure TIniFile.WriteInteger(const ASection, AKey: string; AValue: Int64);
begin
  WriteString(ASection, AKey, IntToStr(AValue));
end;

procedure TIniFile.WriteBool(const ASection, AKey: string; AValue: Boolean);
begin
  if AValue then
    WriteString(ASection, AKey, 'true')
  else
    WriteString(ASection, AKey, 'false');
end;

function TIniFile.SectionExists(const ASection: string): Boolean;
begin
  Result := FindSection(ASection) >= 0;
end;

function TIniFile.KeyExists(const ASection, AKey: string): Boolean;
var
  LSIdx: Integer;
begin
  LSIdx := FindSection(ASection);
  if LSIdx < 0 then
    Exit(False);
  Result := FindKey(LSIdx, AKey) >= 0;
end;

procedure TIniFile.DeleteKey(const ASection, AKey: string);
var
  LSIdx, LKIdx, I: Integer;
begin
  LSIdx := FindSection(ASection);
  if LSIdx < 0 then
    Exit;
  LKIdx := FindKey(LSIdx, AKey);
  if LKIdx < 0 then
    Exit;
  with FSections[LSIdx] do
  begin
    for I := LKIdx to EntryCount - 2 do
      Entries[I] := Entries[I + 1];
    Dec(EntryCount);
    Entries[EntryCount].Key := '';
    Entries[EntryCount].Value := '';
  end;
end;

procedure TIniFile.DeleteSection(const ASection: string);
var
  LSIdx, I: Integer;
begin
  LSIdx := FindSection(ASection);
  if LSIdx < 0 then
    Exit;
  for I := LSIdx to FSectionCount - 2 do
    FSections[I] := FSections[I + 1];
  Dec(FSectionCount);
  FSections[FSectionCount].Name := '';
  FSections[FSectionCount].EntryCount := 0;
  FSections[FSectionCount].Entries := nil;
end;

function TIniFile.GetSections: TStringArray;
var
  I, LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  SetLength(Result, FSectionCount);
  for I := 0 to FSectionCount - 1 do
  begin
    if FSections[I].Name <> '' then
    begin
      Result[LCount] := FSections[I].Name;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function TIniFile.GetKeys(const ASection: string): TStringArray;
var
  LSIdx, I: Integer;
begin
  Result := nil;
  LSIdx := FindSection(ASection);
  if LSIdx < 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, FSections[LSIdx].EntryCount);
  for I := 0 to FSections[LSIdx].EntryCount - 1 do
    Result[I] := FSections[LSIdx].Entries[I].Key;
end;

end.
