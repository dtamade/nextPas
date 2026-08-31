unit nextpas.core.ini;
{**
 * @desc INI 配置文件解析模块。零 SysUtils 依赖，Go ini 风格简洁接口。
 *       支持 sections、key=value、注释(; 和 #)、空行跳过、值中空格保留。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TStringArray = array of string;

  { Structured parse diagnostic (aligned with TCsvError / TJsonError shape). }
  TIniError = record
    Message: string;
    Line: UInt32;
    Column: UInt32;
    Offset: SizeUInt;
    property Col: UInt32 read Column write Column;
  end;

  TIniEntry = record
    Key: string;
    Value: string;
  end;
  PTIniEntry = ^TIniEntry;

  TIniSection = record
    Name: string;
    Entries: PTIniEntry;
    EntryCount: Integer;
    EntryCap: Integer;
  end;
  PTIniSection = ^TIniSection;

  TIniFile = class
  private
    FSections: PTIniSection;
    FSectionCount: Integer;
    FSectionCap: Integer;
    FAllocator: TMemAllocator;
    FStrict: Boolean;
    procedure ClearSection(var ASection: TIniSection);
    procedure ClearSections;
    procedure EnsureSectionCapacity(ANeeded: Integer);
    procedure EnsureEntryCapacity(var ASection: TIniSection; ANeeded: Integer);
    procedure MoveSection(var ADest, ASrc: TIniSection);
    procedure ResetState;
    function FindSection(const ASection: string): Integer;
    function FindOrCreateSection(const ASection: string): Integer;
    function FindKey(ASectionIdx: Integer; const AKey: string): Integer;
    procedure ParseLine(const ALine: string; var ACurrentSection: Integer);
    function CaseInsensitiveEqual(const A, B: string): Boolean;
  public
    constructor Create(const AAllocator: TMemAllocator = nil);
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromString(const AContent: string);
    function TryLoadFromString(const AContent: string; out AError: string): Boolean;
      overload;
    function TryLoadFromString(const AContent: string; out AError: TIniError): Boolean;
      overload;
    function TryLoadFromFile(const APath: string; out AError: string): Boolean;
      overload;
    function TryLoadFromFile(const APath: string; out AError: TIniError): Boolean;
      overload;
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
    function Allocator: TMemAllocator;
    { When True, non-comment/non-section lines without '=' fail TryLoad. Default False. }
    property Strict: Boolean read FStrict write FStrict;
  end;

function IniParse(const AContent: string): TIniFile; overload;
function IniParse(const AReader: IReader): TIniFile; overload;
function IniParseWith(const AContent: string; const AAllocator: TMemAllocator): TIniFile;
function IniStringify(const AFile: TIniFile): string; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.format.limits,
  nextpas.core.fs,
  nextpas.core.io.util,
  nextpas.core.mem.default,
  nextpas.core.mem;

{ TIniFile }

constructor TIniFile.Create(const AAllocator: TMemAllocator);
begin
  inherited Create;
  if AAllocator = nil then
    FAllocator := DefaultAllocator
  else
    FAllocator := AAllocator;
  FSectionCount := 0;
  FSectionCap := 0;
  FSections := nil;
  FStrict := False;
  FindOrCreateSection('');
end;

destructor TIniFile.Destroy;
begin
  ClearSections;
  FAllocator := nil;
  inherited Destroy;
end;

procedure TIniFile.ClearSection(var ASection: TIniSection);
var
  I: Integer;
begin
  for I := 0 to ASection.EntryCount - 1 do
  begin
    ASection.Entries[I].Key := '';
    ASection.Entries[I].Value := '';
  end;
  if ASection.Entries <> nil then
    FreeMemOf(FAllocator, Pointer(ASection.Entries),
      SizeUInt(ASection.EntryCap) * SizeOf(TIniEntry));
  ASection.Entries := nil;
  ASection.EntryCount := 0;
  ASection.EntryCap := 0;
  ASection.Name := '';
end;

procedure TIniFile.ClearSections;
var
  I: Integer;
begin
  for I := 0 to FSectionCount - 1 do
    ClearSection(FSections[I]);
  if FSections <> nil then
    FreeMemOf(FAllocator, Pointer(FSections),
      SizeUInt(FSectionCap) * SizeOf(TIniSection));
  FSections := nil;
  FSectionCount := 0;
  FSectionCap := 0;
end;

procedure TIniFile.EnsureSectionCapacity(ANeeded: Integer);
var
  LNewCap: Integer;
  LNewPtr: Pointer;
  LOldCap: Integer;
begin
  if ANeeded <= FSectionCap then
    Exit;
  LOldCap := FSectionCap;
  if FSectionCap = 0 then
    LNewCap := 8
  else
    LNewCap := FSectionCap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := ReallocMemOf(FAllocator, Pointer(FSections),
    SizeUInt(LOldCap) * SizeOf(TIniSection), SizeUInt(LNewCap) * SizeOf(TIniSection));
  if LNewPtr = nil then
    raise EResourceExhaustedError.Create('TIniFile: out of memory');
  FSections := PTIniSection(LNewPtr);
  FillChar(FSections[LOldCap], (LNewCap - LOldCap) * SizeOf(TIniSection), 0);
  FSectionCap := LNewCap;
end;

procedure TIniFile.EnsureEntryCapacity(var ASection: TIniSection; ANeeded: Integer);
var
  LNewCap: Integer;
  LNewPtr: Pointer;
  LOldCap: Integer;
begin
  if ANeeded <= ASection.EntryCap then
    Exit;
  LOldCap := ASection.EntryCap;
  if ASection.EntryCap = 0 then
    LNewCap := 8
  else
    LNewCap := ASection.EntryCap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := ReallocMemOf(FAllocator, Pointer(ASection.Entries),
    SizeUInt(LOldCap) * SizeOf(TIniEntry), SizeUInt(LNewCap) * SizeOf(TIniEntry));
  if LNewPtr = nil then
    raise EResourceExhaustedError.Create('TIniFile: out of memory');
  ASection.Entries := PTIniEntry(LNewPtr);
  FillChar(ASection.Entries[LOldCap], (LNewCap - LOldCap) * SizeOf(TIniEntry), 0);
  ASection.EntryCap := LNewCap;
end;

procedure TIniFile.MoveSection(var ADest, ASrc: TIniSection);
begin
  ADest.Name := ASrc.Name;
  ASrc.Name := '';
  ADest.Entries := ASrc.Entries;
  ASrc.Entries := nil;
  ADest.EntryCount := ASrc.EntryCount;
  ASrc.EntryCount := 0;
  ADest.EntryCap := ASrc.EntryCap;
  ASrc.EntryCap := 0;
end;

procedure TIniFile.ResetState;
begin
  ClearSections;
  FindOrCreateSection('');
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
  EnsureSectionCapacity(FSectionCount + 1);
  FSections[FSectionCount].Name := ASection;
  FSections[FSectionCount].EntryCount := 0;
  FSections[FSectionCount].Entries := nil;
  FSections[FSectionCount].EntryCap := 0;
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
          EnsureEntryCapacity(FSections[ACurrentSection], EntryCount + 1);
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
  ResetState;
  LCurrentSection := 0;

  LLen := Length(AContent);
  LStart := 1;
  LPos := 1;
  while LPos <= LLen do
  begin
    if (AContent[LPos] = #10) or (AContent[LPos] = #13) then
    begin
      LLine := Copy(AContent, LStart, LPos - LStart);
      if (AContent[LPos] = #13) and (LPos < LLen) and (AContent[LPos + 1] = #10) then
        Inc(LPos);
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

function FormatIniErrorMessage(const AError: TIniError): string;
begin
  if (AError.Line = 0) and (AError.Column = 0) then
    Exit(AError.Message);
  Result := 'line ' + IntToStr(AError.Line) +
    ', column ' + IntToStr(AError.Column) + ': ' + AError.Message;
end;

function TIniFile.TryLoadFromString(const AContent: string;
  out AError: TIniError): Boolean;
var
  LStart, LPos, LLen, LLineNo: Integer;
  LLine, LTrimmed: string;

  function ValidateLine(const ALine: string; ALineNo: Integer;
    ALineStartOffset: SizeUInt): Boolean;
  begin
    LTrimmed := TrimLeft(ALine);
    if LTrimmed = '' then
      Exit(True);
    if (LTrimmed[1] = ';') or (LTrimmed[1] = '#') then
      Exit(True);
    if (LTrimmed[1] = '[') and (Pos(']', LTrimmed) = 0) then
    begin
      AError.Message := 'missing closing ] in section header';
      AError.Line := ALineNo;
      AError.Column := 1;
      AError.Offset := ALineStartOffset;
      Exit(False);
    end;
    if FStrict and (LTrimmed[1] <> '[') and (Pos('=', LTrimmed) = 0) then
    begin
      AError.Message := 'strict mode: expected key=value or section header';
      AError.Line := ALineNo;
      AError.Column := 1;
      AError.Offset := ALineStartOffset;
      Exit(False);
    end;
    Result := True;
  end;

begin
  AError.Message := '';
  AError.Line := 0;
  AError.Column := 0;
  AError.Offset := 0;

  LLen := Length(AContent);
  LStart := 1;
  LPos := 1;
  LLineNo := 1;
  while LPos <= LLen do
  begin
    if (AContent[LPos] = #10) or (AContent[LPos] = #13) then
    begin
      LLine := Copy(AContent, LStart, LPos - LStart);
      if (AContent[LPos] = #13) and (LPos < LLen) and (AContent[LPos + 1] = #10) then
        Inc(LPos);
      if not ValidateLine(LLine, LLineNo, SizeUInt(LStart - 1)) then
        Exit(False);
      Inc(LLineNo);
      LStart := LPos + 1;
    end;
    Inc(LPos);
  end;
  if LStart <= LLen then
  begin
    LLine := Copy(AContent, LStart, LLen - LStart + 1);
    if not ValidateLine(LLine, LLineNo, SizeUInt(LStart - 1)) then
      Exit(False);
  end;

  try
    LoadFromString(AContent);
    Result := True;
    AError.Message := '';
    AError.Line := 0;
    AError.Column := 0;
    AError.Offset := 0;
  except
    on E: Exception do
    begin
      AError.Message := E.Message;
      AError.Line := 0;
      AError.Column := 0;
      AError.Offset := 0;
      Result := False;
    end;
  end;
end;

function TIniFile.TryLoadFromString(const AContent: string; out AError: string): Boolean;
var
  LErr: TIniError;
begin
  Result := TryLoadFromString(AContent, LErr);
  if Result then
    AError := ''
  else
    AError := FormatIniErrorMessage(LErr);
end;

function TIniFile.TryLoadFromFile(const APath: string; out AError: TIniError): Boolean;
var
  LContent: string;

  procedure SetIoError(const AMessage: string);
  begin
    AError.Message := AMessage;
    AError.Line := 0;
    AError.Column := 0;
    AError.Offset := 0;
  end;

begin
  AError.Message := '';
  AError.Line := 0;
  AError.Column := 0;
  AError.Offset := 0;
  try
    LContent := ReadFileText(APath);
  except
    on E: Exception do
    begin
      SetIoError('Cannot read file "' + APath + '": ' + E.Message);
      Exit(False);
    end;
  end;

  Result := TryLoadFromString(LContent, AError);
  if not Result and (AError.Message <> '') and (AError.Line > 0) then
    AError.Message := 'Cannot parse file "' + APath + '": ' +
      FormatIniErrorMessage(AError);
end;

function TIniFile.TryLoadFromFile(const APath: string; out AError: string): Boolean;
var
  LErr: TIniError;
begin
  Result := TryLoadFromFile(APath, LErr);
  if Result then
    AError := ''
  else if LErr.Line > 0 then
    AError := LErr.Message  { already includes path + FormatIniErrorMessage }
  else
    AError := LErr.Message;
end;

procedure TIniFile.LoadFromFile(const AFileName: string);
var
  LContent: string;
begin
  try
    LContent := ReadFileText(AFileName);
  except
    on E: Exception do
      raise ENextPasError.Create('Cannot open file: ' + AFileName + ': ' +
        E.Message, ecIO);
  end;
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
    Move(PAnsiChar(AText)^, Result[LPos], LTextLen);
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
  LContent: string;
  LData: TBytes;
begin
  LContent := ToString;
  try
    if Length(LContent) > 0 then
    begin
      SetLength(LData, Length(LContent));
      Move(PAnsiChar(LContent)^, LData[0], Length(LContent));
      WriteAtomic(AFileName, LData);
    end
    else
      WriteAtomic(AFileName, nil);
  except
    on E: Exception do
      raise ENextPasError.Create('Cannot write file: ' + AFileName + ': ' +
        E.Message, ecIO);
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
      EnsureEntryCapacity(FSections[LSIdx], EntryCount + 1);
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
  ClearSection(FSections[LSIdx]);
  for I := LSIdx to FSectionCount - 2 do
    MoveSection(FSections[I], FSections[I + 1]);
  Dec(FSectionCount);
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

function TIniFile.Allocator: TMemAllocator;
begin
  if FAllocator = nil then
    Result := DefaultAllocator
  else
    Result := FAllocator;
end;

function IniParse(const AContent: string): TIniFile;
begin
  Result := IniParseWith(AContent, DefaultAllocator);
end;

function IniParse(const AReader: IReader): TIniFile;
var
  LBytes: TBytes;
begin
  if AReader = nil then
    raise EArgumentError.Create('IniParse: reader must not be nil');
  LBytes := IoReadAll(AReader);
  RequireFormatBulkByteCount(SizeUInt(Length(LBytes)), 'IniParse');
  Result := IniParse(BytesToString(LBytes));
end;

function IniParseWith(const AContent: string; const AAllocator: TMemAllocator): TIniFile;
begin
  Result := TIniFile.Create(AAllocator);
  try
    Result.LoadFromString(AContent);
  except
    Result.Free;
    raise;
  end;
end;

function IniStringify(const AFile: TIniFile): string;
begin
  Result := AFile.ToString;
end;

end.
