unit nextpas.core.csv;
{**
 * @desc RFC 4180 compliant CSV parser and writer.
 *       Zero SysUtils dependency. Go encoding/csv compatible API.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

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
    class function Create(const AInput: string; ADelimiter: AnsiChar = ',';
      AFieldsPerRecord: Integer = 0; ATrimSpace: Boolean = False;
      AComment: AnsiChar = #0): TCsvReader; static;
    function ReadRow(out AFields: TStringArray): Boolean;
    function ReadAll: TStringMatrix;
    function HasError: Boolean;
    function GetError: string;
    function Error: TCsvError;
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

implementation

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

class function TCsvReader.Create(const AInput: string; ADelimiter: AnsiChar;
  AFieldsPerRecord: Integer; ATrimSpace: Boolean; AComment: AnsiChar): TCsvReader;
begin
  ValidateCsvDelimiter(ADelimiter, 'TCsvReader.Create');
  ValidateCsvCommentMarker(AComment, ADelimiter, 'TCsvReader.Create');
  Result.FInput := AInput;
  Result.FData := PAnsiChar(Result.FInput);
  Result.FLen := Length(AInput);
  Result.FPos := 0;
  Result.FDelimiter := ADelimiter;
  Result.FFieldsPerRecord := AFieldsPerRecord;
  Result.FTrimSpace := ATrimSpace;
  Result.FComment := AComment;
  Result.FHasError := False;
  Result.FError.Message := '';
  Result.FError.Offset := 0;
  Result.FError.Line := 1;
  Result.FError.Column := 1;
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
  LField: string;
  LWasQuoted: Boolean;
  LRecordEndOffset: SizeUInt;
begin
  Result := False;
  SetLength(AFields, 0);
  if FHasError then
    Exit;

  SkipIgnoredLines;
  if AtEnd then
    Exit;

  LCount := 0;

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
    Inc(LCount);
    SetLength(AFields, LCount);
    AFields[LCount - 1] := LField;

    { Check what follows }
    if AtEnd then
      Break;

    if PeekChar = FDelimiter then
    begin
      Inc(FPos); { consume delimiter }
      { If delimiter is at end of input, add empty trailing field and stop }
      if AtEnd then
      begin
        Inc(LCount);
        SetLength(AFields, LCount);
        if FTrimSpace then
          AFields[LCount - 1] := ''
        else
          AFields[LCount - 1] := '';
        Break;
      end;
      { If delimiter is followed by newline, add empty trailing field and stop }
      if (PeekChar = #13) or (PeekChar = #10) then
      begin
        Inc(LCount);
        SetLength(AFields, LCount);
        AFields[LCount - 1] := '';
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

  Result := True;
end;

function TCsvReader.ReadAll: TStringMatrix;
var
  LRow: TStringArray;
  LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  while ReadRow(LRow) do
  begin
    if FHasError then
      Break;
    Inc(LCount);
    SetLength(Result, LCount);
    Result[LCount - 1] := LRow;
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

function TCsvWriter.ToString: string;
begin
  if FFieldCount > 0 then
    raise EInvalidOperationError.Create(
      'TCsvWriter.ToString: unfinished row must be ended with EndRow');
  Result := FResult;
end;

end.
