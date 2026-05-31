unit nextpas.core.csv;
{**
 * @desc RFC 4180 compliant CSV parser and writer.
 *       Zero SysUtils dependency. Go encoding/csv compatible API.
 *}

{$I nextpas.core.settings.inc}

interface

type
  TStringArray = array of string;
  TStringMatrix = array of TStringArray;

  { TCsvReader — streaming CSV parser with RFC 4180 support }
  TCsvReader = record
  private
    FData: PAnsiChar;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FDelimiter: AnsiChar;
    function PeekChar: AnsiChar; inline;
    function AtEnd: Boolean; inline;
    function ReadQuotedField: string;
    function ReadUnquotedField: string;
  public
    class function Create(const AInput: string; ADelimiter: AnsiChar = ','): TCsvReader; static;
    function ReadRow(out AFields: TStringArray): Boolean;
    function ReadAll: TStringMatrix;
    property Delimiter: AnsiChar read FDelimiter write FDelimiter;
  end;

  { TCsvWriter — builds CSV output with proper quoting }
  TCsvWriter = record
  private
    FResult: string;
    FDelimiter: AnsiChar;
    FUseCRLF: Boolean;
    FFieldCount: Integer;
  public
    class function Create(ADelimiter: AnsiChar = ','; AUseCRLF: Boolean = False): TCsvWriter; static;
    procedure WriteRow(const AFields: array of string);
    procedure WriteField(const AField: string);
    procedure EndRow;
    function ToString: string;
  end;

implementation

{ ===== TCsvReader ===== }

class function TCsvReader.Create(const AInput: string; ADelimiter: AnsiChar): TCsvReader;
begin
  Result.FData := PAnsiChar(AInput);
  Result.FLen := Length(AInput);
  Result.FPos := 0;
  Result.FDelimiter := ADelimiter;
end;

function TCsvReader.PeekChar: AnsiChar;
begin
  Result := FData[FPos];
end;

function TCsvReader.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

function TCsvReader.ReadQuotedField: string;
var
  LStart: SizeUInt;
  LBuf: string;
begin
  { Skip opening quote }
  Inc(FPos);
  LBuf := '';
  while not AtEnd do
  begin
    LStart := FPos;
    { Scan until quote }
    while (FPos < FLen) and (FData[FPos] <> '"') do
      Inc(FPos);
    if FPos > LStart then
      LBuf := LBuf + Copy(string(FData), LStart + 1, FPos - LStart);
    if AtEnd then
      Break;
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
    Inc(FPos);
  Result := Copy(string(FData), LStart + 1, FPos - LStart);
end;

function TCsvReader.ReadRow(out AFields: TStringArray): Boolean;
var
  LCount: Integer;
  LField: string;
begin
  Result := False;
  if AtEnd then
    Exit;

  SetLength(AFields, 0);
  LCount := 0;

  repeat
    { Parse one field }
    if (not AtEnd) and (PeekChar = '"') then
      LField := ReadQuotedField
    else
      LField := ReadUnquotedField;

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

  { Consume line ending }
  if (not AtEnd) and (PeekChar = #13) then
    Inc(FPos);
  if (not AtEnd) and (PeekChar = #10) then
    Inc(FPos);

  Result := True;
end;

function TCsvReader.ReadAll: TStringMatrix;
var
  LRow: TStringArray;
  LCount: Integer;
begin
  SetLength(Result, 0);
  LCount := 0;
  while ReadRow(LRow) do
  begin
    Inc(LCount);
    SetLength(Result, LCount);
    Result[LCount - 1] := LRow;
  end;
end;

{ ===== TCsvWriter ===== }

class function TCsvWriter.Create(ADelimiter: AnsiChar; AUseCRLF: Boolean): TCsvWriter;
begin
  Result.FResult := '';
  Result.FDelimiter := ADelimiter;
  Result.FUseCRLF := AUseCRLF;
  Result.FFieldCount := 0;
end;

function NeedsQuoting(const AField: string; ADelimiter: AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := False;
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
  if NeedsQuoting(AField, FDelimiter) then
    FResult := FResult + QuoteField(AField)
  else
    FResult := FResult + AField;
  Inc(FFieldCount);
end;

procedure TCsvWriter.EndRow;
begin
  if FUseCRLF then
    FResult := FResult + #13#10
  else
    FResult := FResult + #10;
  FFieldCount := 0;
end;

function TCsvWriter.ToString: string;
begin
  Result := FResult;
end;

end.
