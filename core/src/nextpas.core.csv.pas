unit nextpas.core.csv;
{**
 * @desc RFC 4180 compliant CSV parser and writer.
 *       Zero SysUtils dependency. Go encoding/csv compatible API.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.mem.intf;

type
  TStringArray = array of string;
  TStringMatrix = array of TStringArray;

  TCsvError = record
    Message: string;
    Offset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;

  { TCsvReader — streaming CSV parser with RFC 4180 support }
  TCsvReader = record
  private
    FInput: string;       { holds string reference to prevent dangling pointer }
    FData: PAnsiChar;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FDelimiter: AnsiChar;
    FFieldsPerRecord: Integer;
    FTrimSpace: Boolean;
    FComment: AnsiChar;
    FHasError: Boolean;
    FError: TCsvError;
    FAllocator: IAllocator;
    procedure SetError(const AMessage: string);
    procedure SetErrorAt(const AMessage: string; AOffset: SizeUInt);
    procedure SetErrorPosition(var AError: TCsvError; AOffset: SizeUInt);
    procedure SetDelimiter(AValue: AnsiChar);
    function PeekChar: AnsiChar; inline;
    function AtEnd: Boolean; inline;
    procedure SkipLineEnding;
    procedure SkipIgnoredLines;
    function ReadQuotedField: string;
    function ReadUnquotedField: string;
    function TrimStr(const S: string): string;
  public
    procedure Init(const AInput: string; ADelimiter: AnsiChar = ',';
      AFieldsPerRecord: Integer = 0; ATrimSpace: Boolean = False;
      AComment: AnsiChar = #0; const AAllocator: IAllocator = nil);
    procedure Done;
    class function Create(const AInput: string; ADelimiter: AnsiChar = ',';
      AFieldsPerRecord: Integer = 0; ATrimSpace: Boolean = False;
      AComment: AnsiChar = #0; const AAllocator: IAllocator = nil): TCsvReader; static;
    function ReadRow(out AFields: TStringArray): Boolean;
    function ReadAll: TStringMatrix;
    function HasError: Boolean;
    function GetError: string;
    function Error: TCsvError;
    function Allocator: IAllocator;
    property Delimiter: AnsiChar read FDelimiter write SetDelimiter;
  end;

  { TCsvWriter — builds CSV output with proper quoting }
  TCsvWriter = record
  private
    FResult: string;
    FDelimiter: AnsiChar;
    FUseCRLF: Boolean;
    FComment: AnsiChar;
    FFieldCount: Integer;
  public
    class function Create(ADelimiter: AnsiChar = ',';
      AUseCRLF: Boolean = False; AComment: AnsiChar = #0): TCsvWriter; static;
    procedure WriteRow(const AFields: array of string);
    procedure WriteField(const AField: string);
    procedure EndRow;
    function ToString: string;
  end;

function CsvParse(const AInput: string; ADelimiter: AnsiChar = ','): TStringMatrix;
function CsvParseWith(const AInput: string; const AAllocator: IAllocator;
  ADelimiter: AnsiChar = ','): TStringMatrix;

implementation

uses
  nextpas.core.mem.default;

type
  PStringSlot = ^string;
  TStringArraySlot = TStringArray;
  PStringArraySlot = ^TStringArraySlot;

function GrowStringSlots(const AAllocator: IAllocator; var ASlots: PStringSlot;
  var ACap: Integer; ANeeded: Integer): Boolean;
var
  LNewCap: Integer;
  LNewPtr: Pointer;
  LOldCap: Integer;
begin
  if ANeeded <= ACap then
    Exit(True);
  LOldCap := ACap;
  if ACap = 0 then
    LNewCap := 8
  else
    LNewCap := ACap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := AAllocator.ReallocMem(Pointer(ASlots),
    SizeUInt(LNewCap) * SizeOf(string));
  if LNewPtr = nil then
    Exit(False);
  ASlots := PStringSlot(LNewPtr);
  FillChar(ASlots[LOldCap], (LNewCap - LOldCap) * SizeOf(string), 0);
  ACap := LNewCap;
  Result := True;
end;

procedure ReleaseStringSlots(const AAllocator: IAllocator; var ASlots: PStringSlot;
  ACount: Integer);
var
  LI: Integer;
begin
  if ASlots = nil then
    Exit;
  for LI := 0 to ACount - 1 do
    ASlots[LI] := '';
  AAllocator.FreeMem(Pointer(ASlots));
  ASlots := nil;
end;

function GrowRowSlots(const AAllocator: IAllocator; var ASlots: PStringArraySlot;
  var ACap: Integer; ANeeded: Integer): Boolean;
var
  LNewCap: Integer;
  LNewPtr: Pointer;
  LOldCap: Integer;
begin
  if ANeeded <= ACap then
    Exit(True);
  LOldCap := ACap;
  if ACap = 0 then
    LNewCap := 8
  else
    LNewCap := ACap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := AAllocator.ReallocMem(Pointer(ASlots),
    SizeUInt(LNewCap) * SizeOf(TStringArray));
  if LNewPtr = nil then
    Exit(False);
  ASlots := PStringArraySlot(LNewPtr);
  FillChar(ASlots[LOldCap], (LNewCap - LOldCap) * SizeOf(TStringArray), 0);
  ACap := LNewCap;
  Result := True;
end;

procedure ReleaseRowSlots(const AAllocator: IAllocator; var ASlots: PStringArraySlot;
  ACount: Integer);
var
  LI: Integer;
begin
  if ASlots = nil then
    Exit;
  for LI := 0 to ACount - 1 do
    SetLength(ASlots[LI], 0);
  AAllocator.FreeMem(Pointer(ASlots));
  ASlots := nil;
end;

procedure ValidateCsvDelimiter(ADelimiter: AnsiChar; const AContext: string);
begin
  if (ADelimiter = #0) or (ADelimiter = '"') or
    (ADelimiter = #10) or (ADelimiter = #13) then
    raise EArgumentError.Create(AContext +
      ': delimiter must not be NUL, quote, CR, or LF');
end;

procedure ValidateCsvCommentMarker(AComment, ADelimiter: AnsiChar;
  const AContext: string);
begin
  if AComment = #0 then
    Exit;
  if AComment = ADelimiter then
    raise EArgumentError.Create(AContext +
      ': comment marker must not equal delimiter');
  if (AComment = '"') or (AComment = #10) or (AComment = #13) then
    raise EArgumentError.Create(AContext +
      ': comment marker must not be quote, CR, or LF');
end;

{ ===== TCsvReader ===== }

procedure TCsvReader.Init(const AInput: string; ADelimiter: AnsiChar;
  AFieldsPerRecord: Integer; ATrimSpace: Boolean; AComment: AnsiChar;
  const AAllocator: IAllocator);
begin
  ValidateCsvDelimiter(ADelimiter, 'TCsvReader.Create');
  ValidateCsvCommentMarker(AComment, ADelimiter, 'TCsvReader.Create');
  if AAllocator = nil then
    FAllocator := DefaultAllocator
  else
    FAllocator := AAllocator;
  FInput := AInput;
  FData := PAnsiChar(FInput);
  FLen := Length(AInput);
  FPos := 0;
  FDelimiter := ADelimiter;
  FFieldsPerRecord := AFieldsPerRecord;
  FTrimSpace := ATrimSpace;
  FComment := AComment;
  FHasError := False;
  FError.Message := '';
  FError.Offset := 0;
  FError.Line := 1;
  FError.Column := 1;
end;

procedure TCsvReader.Done;
begin
  FInput := '';
  FData := nil;
  FLen := 0;
  FPos := 0;
  FDelimiter := ',';
  FFieldsPerRecord := 0;
  FTrimSpace := False;
  FComment := #0;
  FHasError := False;
  FError.Message := '';
  FError.Offset := 0;
  FError.Line := 1;
  FError.Column := 1;
  FAllocator := nil;
end;

class function TCsvReader.Create(const AInput: string; ADelimiter: AnsiChar;
  AFieldsPerRecord: Integer; ATrimSpace: Boolean; AComment: AnsiChar;
  const AAllocator: IAllocator): TCsvReader;
begin
  Result.Init(AInput, ADelimiter, AFieldsPerRecord, ATrimSpace, AComment,
    AAllocator);
end;

function TCsvReader.PeekChar: AnsiChar;
begin
  Result := FData[FPos];
end;

function TCsvReader.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

procedure TCsvReader.SkipLineEnding;
begin
  if (not AtEnd) and (FData[FPos] = #13) then
    Inc(FPos);
  if (not AtEnd) and (FData[FPos] = #10) then
    Inc(FPos);
end;

procedure TCsvReader.SkipIgnoredLines;
var
  LStart: SizeUInt;
begin
  repeat
    LStart := FPos;
    while (not AtEnd) and ((FData[FPos] = #13) or (FData[FPos] = #10)) do
      SkipLineEnding;

    if (FComment <> #0) and (not AtEnd) and (FData[FPos] = FComment) then
    begin
      while (not AtEnd) and (FData[FPos] <> #13) and (FData[FPos] <> #10) do
        Inc(FPos);
      SkipLineEnding;
    end;
  until FPos = LStart;
end;

procedure TCsvReader.SetError(const AMessage: string);
begin
  SetErrorAt(AMessage, FPos);
end;

procedure TCsvReader.SetErrorAt(const AMessage: string; AOffset: SizeUInt);
begin
  if FHasError then
    Exit;
  FHasError := True;
  FError.Message := AMessage;
  FError.Offset := AOffset;
  SetErrorPosition(FError, AOffset);
end;

procedure TCsvReader.SetErrorPosition(var AError: TCsvError; AOffset: SizeUInt);
var
  LIdx, LStop: SizeUInt;
  LLine, LColumn: UInt32;
begin
  if AOffset > FLen then
    LStop := FLen
  else
    LStop := AOffset;

  LIdx := 0;
  LLine := 1;
  LColumn := 1;
  while LIdx < LStop do
  begin
    case FData[LIdx] of
      #10:
      begin
        Inc(LLine);
        LColumn := 1;
      end;
      #13:
      begin
        Inc(LLine);
        LColumn := 1;
        if (LIdx + 1 < LStop) and (FData[LIdx + 1] = #10) then
          Inc(LIdx);
      end;
    else
      Inc(LColumn);
    end;
    Inc(LIdx);
  end;

  AError.Line := LLine;
  AError.Column := LColumn;
end;

procedure TCsvReader.SetDelimiter(AValue: AnsiChar);
begin
  ValidateCsvDelimiter(AValue, 'TCsvReader.Delimiter');
  ValidateCsvCommentMarker(FComment, AValue, 'TCsvReader.Delimiter');
  FDelimiter := AValue;
end;

function TCsvReader.TrimStr(const S: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and ((S[LStart] = ' ') or (S[LStart] = #9)) do
    Inc(LStart);
  while (LEnd >= LStart) and ((S[LEnd] = ' ') or (S[LEnd] = #9)) do
    Dec(LEnd);
  if LStart > LEnd then
    Result := ''
  else
    Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function TCsvReader.ReadQuotedField: string;
var
  LStart, LQuoteOffset: SizeUInt;
  LBuf, LPart: string;
begin
  LQuoteOffset := FPos;
  Inc(FPos);
  LBuf := '';
  while not AtEnd do
  begin
    LStart := FPos;
    { Scan until quote }
    while (FPos < FLen) and (FData[FPos] <> '"') do
      Inc(FPos);
    if FPos > LStart then
    begin
      SetString(LPart, @FData[LStart], FPos - LStart);
      LBuf := LBuf + LPart;
    end;
    if AtEnd then
    begin
      SetErrorAt('Unclosed quoted field', LQuoteOffset);
      Break;
    end;
    { We hit a quote }
    Inc(FPos); { consume the quote }
    { Check for escaped quote (doubled) }
    if (not AtEnd) and (FData[FPos] = '"') then
    begin
      LBuf := LBuf + '"';
      Inc(FPos);
    end
    else
      Break; { end of quoted field }
  end;
  Result := LBuf;
end;

function TCsvReader.ReadUnquotedField: string;
var
  LStart: SizeUInt;
begin
  LStart := FPos;
  while (not AtEnd) and (FData[FPos] <> FDelimiter) and
        (FData[FPos] <> #13) and (FData[FPos] <> #10) do
  begin
    if FData[FPos] = '"' then
      SetError('Bare quote in unquoted field');
    Inc(FPos);
  end;
  SetString(Result, @FData[LStart], FPos - LStart);
end;

function TCsvReader.ReadRow(out AFields: TStringArray): Boolean;
var
  LCount: Integer;
  LCap: Integer;
  LField: string;
  LWasQuoted: Boolean;
  LRecordEndOffset: SizeUInt;
  LFieldsBuf: PStringSlot;
  LI: Integer;
begin
  Result := False;
  SetLength(AFields, 0);
  LFieldsBuf := nil;
  LCount := 0;
  LCap := 0;
  try
    if FHasError then
      Exit;

    SkipIgnoredLines;
    if AtEnd then
      Exit;

    repeat
    { Parse one field }
    LWasQuoted := False;
    { TrimSpace also permits leading spaces or tabs before an opening quote. }
    if FTrimSpace then
      while (not AtEnd) and
        (((PeekChar = ' ') and (FDelimiter <> ' ')) or
         ((PeekChar = #9) and (FDelimiter <> #9))) do
        Inc(FPos);
    if (not AtEnd) and (PeekChar = '"') then
    begin
      LWasQuoted := True;
      LField := ReadQuotedField
    end
    else
      LField := ReadUnquotedField;

    if FTrimSpace and LWasQuoted then
      while (not AtEnd) and (PeekChar <> FDelimiter) and
        ((PeekChar = ' ') or (PeekChar = #9)) do
        Inc(FPos);

    if LWasQuoted and (not AtEnd) and
      (PeekChar <> FDelimiter) and (PeekChar <> #13) and (PeekChar <> #10) then
    begin
      SetError('Unexpected character after closing quote');
      while (not AtEnd) and (FData[FPos] <> FDelimiter) and
            (FData[FPos] <> #13) and (FData[FPos] <> #10) do
        Inc(FPos);
    end;

    { Trim only unquoted fields; quoted payload is data, not surrounding space. }
    if FTrimSpace and (not LWasQuoted) then
      LField := TrimStr(LField);

    { Append to result }
    if not GrowStringSlots(FAllocator, LFieldsBuf, LCap, LCount + 1) then
    begin
      SetError('out of memory');
      Exit(False);
    end;
    LFieldsBuf[LCount] := LField;
    Inc(LCount);

    { Check what follows }
    if AtEnd then
      Break;

    if PeekChar = FDelimiter then
    begin
      Inc(FPos); { consume delimiter }
      { If delimiter is at end of input, add empty trailing field and stop }
      if AtEnd then
      begin
        if not GrowStringSlots(FAllocator, LFieldsBuf, LCap, LCount + 1) then
        begin
          SetError('out of memory');
          Exit(False);
        end;
        LFieldsBuf[LCount] := '';
        Inc(LCount);
        Break;
      end;
      { If delimiter is followed by newline, add empty trailing field and stop }
      if (PeekChar = #13) or (PeekChar = #10) then
      begin
        if not GrowStringSlots(FAllocator, LFieldsBuf, LCap, LCount + 1) then
        begin
          SetError('out of memory');
          Exit(False);
        end;
        LFieldsBuf[LCount] := '';
        Inc(LCount);
        Break;
      end;
    end
    else
      Break; { end of row (newline or end) }
    until False;

    LRecordEndOffset := FPos;

    { Consume line ending }
    if (not AtEnd) and (PeekChar = #13) then
      Inc(FPos);
    if (not AtEnd) and (PeekChar = #10) then
      Inc(FPos);

    { FieldsPerRecord check }
    if FFieldsPerRecord = 0 then
      FFieldsPerRecord := LCount
    else if (FFieldsPerRecord > 0) and (LCount <> FFieldsPerRecord) then
      SetErrorAt('Wrong number of fields', LRecordEndOffset);

    SetLength(AFields, LCount);
    for LI := 0 to LCount - 1 do
    begin
      AFields[LI] := LFieldsBuf[LI];
      LFieldsBuf[LI] := '';
    end;
    Result := True;
  finally
    ReleaseStringSlots(FAllocator, LFieldsBuf, LCount);
  end;
end;

function TCsvReader.ReadAll: TStringMatrix;
var
  LRow: TStringArray;
  LCount: Integer;
  LCap: Integer;
  LI: Integer;
  LRows: PStringArraySlot;
begin
  Result := nil;
  LRows := nil;
  LCount := 0;
  LCap := 0;
  try
    while ReadRow(LRow) do
    begin
      if FHasError then
        Break;
      if not GrowRowSlots(FAllocator, LRows, LCap, LCount + 1) then
      begin
        SetLength(LRow, 0);
        SetError('out of memory');
        Break;
      end;
      LRows[LCount] := LRow;
      SetLength(LRow, 0);
      Inc(LCount);
    end;
    SetLength(Result, LCount);
    for LI := 0 to LCount - 1 do
    begin
      Result[LI] := LRows[LI];
      SetLength(LRows[LI], 0);
    end;
  finally
    ReleaseRowSlots(FAllocator, LRows, LCount);
  end;
end;

function TCsvReader.HasError: Boolean;
begin
  Result := FHasError;
end;

function TCsvReader.GetError: string;
begin
  Result := FError.Message;
end;

function TCsvReader.Error: TCsvError;
begin
  Result := FError;
end;

function TCsvReader.Allocator: IAllocator;
begin
  if FAllocator = nil then
    Result := DefaultAllocator
  else
    Result := FAllocator;
end;

{ ===== TCsvWriter ===== }

class function TCsvWriter.Create(ADelimiter: AnsiChar; AUseCRLF: Boolean;
  AComment: AnsiChar): TCsvWriter;
begin
  ValidateCsvDelimiter(ADelimiter, 'TCsvWriter.Create');
  ValidateCsvCommentMarker(AComment, ADelimiter, 'TCsvWriter.Create');
  Result.FResult := '';
  Result.FDelimiter := ADelimiter;
  Result.FUseCRLF := AUseCRLF;
  Result.FComment := AComment;
  Result.FFieldCount := 0;
end;

function NeedsQuoting(const AField: string; ADelimiter, AComment: AnsiChar;
  AIsFirstField: Boolean): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AField) = 0 then
  begin
    Result := True;
    Exit;
  end;
  if AIsFirstField and (AComment <> #0) and (AField[1] = AComment) then
  begin
    Result := True;
    Exit;
  end;
  if (AField[1] = ' ') or (AField[1] = #9) or
    (AField[Length(AField)] = ' ') or (AField[Length(AField)] = #9) then
  begin
    Result := True;
    Exit;
  end;
  for I := 1 to Length(AField) do
    case AField[I] of
      '"', #10, #13: begin Result := True; Exit; end;
    else
      if AField[I] = ADelimiter then
      begin
        Result := True;
        Exit;
      end;
    end;
end;

function QuoteField(const AField: string): string;
var
  I: Integer;
begin
  Result := '"';
  for I := 1 to Length(AField) do
  begin
    if AField[I] = '"' then
      Result := Result + '""'
    else
      Result := Result + AField[I];
  end;
  Result := Result + '"';
end;

procedure TCsvWriter.WriteRow(const AFields: array of string);
var
  I: Integer;
begin
  for I := 0 to High(AFields) do
    WriteField(AFields[I]);
  EndRow;
end;

procedure TCsvWriter.WriteField(const AField: string);
begin
  if FFieldCount > 0 then
    FResult := FResult + FDelimiter;
  if NeedsQuoting(AField, FDelimiter, FComment, FFieldCount = 0) then
    FResult := FResult + QuoteField(AField)
  else
    FResult := FResult + AField;
  Inc(FFieldCount);
end;

procedure TCsvWriter.EndRow;
begin
  if FFieldCount = 0 then
    raise EInvalidOperationError.Create(
      'TCsvWriter.EndRow: zero-field rows are not supported');
  if FUseCRLF then
    FResult := FResult + #13#10
  else
    FResult := FResult + #10;
  FFieldCount := 0;
end;

function CsvParse(const AInput: string; ADelimiter: AnsiChar): TStringMatrix;
begin
  Result := CsvParseWith(AInput, DefaultAllocator, ADelimiter);
end;

function CsvParseWith(const AInput: string; const AAllocator: IAllocator;
  ADelimiter: AnsiChar): TStringMatrix;
var
  LReader: TCsvReader;
  LError: TCsvError;
begin
  LReader := TCsvReader.Create(AInput, ADelimiter, 0, False, #0, AAllocator);
  Result := LReader.ReadAll;
  if LReader.HasError then
  begin
    LError := LReader.Error;
    raise EParseError.Create('CSV parse error: ' + LError.Message);
  end;
end;

function TCsvWriter.ToString: string;
begin
  if FFieldCount > 0 then
    raise EInvalidOperationError.Create(
      'TCsvWriter.ToString: unfinished row must be ended with EndRow');
  Result := FResult;
end;

end.
