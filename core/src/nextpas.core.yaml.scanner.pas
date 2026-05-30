unit nextpas.core.yaml.scanner;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.yaml.types;

type
  TYamlScanner = record
  private
    FData: PAnsiChar;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FLine: UInt32;
    FCol: UInt32;
    FFlowLevel: Int32;
    FStreamStarted: Boolean;
    FStreamEnded: Boolean;
    FError: TYamlError;
    FHasError: Boolean;
    function Peek: Byte; inline;
    function PeekAt(AOffset: SizeUInt): Byte; inline;
    function AtEnd: Boolean; inline;
    procedure Advance; inline;
    procedure AdvanceN(ACount: SizeUInt); inline;
    procedure SkipWhitespaceAndComments;
    procedure SkipToNextToken;
    function ScanPlainScalar: TYamlToken;
    function ScanSingleQuotedScalar: TYamlToken;
    function ScanDoubleQuotedScalar: TYamlToken;
    function ScanAnchorOrAlias: TYamlToken;
    procedure SetError(const AMsg: string);
    function MakeToken(AKind: TYamlTokenKind): TYamlToken; inline;
  public
    procedure Init(const AData: PAnsiChar; const ALen: SizeUInt);
    procedure InitFromView(const AView: TStringView);
    function NextToken: TYamlToken;
    function HasError: Boolean; inline;
    function Error: TYamlError; inline;
  end;

implementation

uses
  nextpas.core.text.char;

{ TYamlScanner }

procedure TYamlScanner.Init(const AData: PAnsiChar; const ALen: SizeUInt);
begin
  FData := AData;
  FLen := ALen;
  FPos := 0;
  FLine := 1;
  FCol := 1;
  FFlowLevel := 0;
  FStreamStarted := False;
  FStreamEnded := False;
  FHasError := False;
end;

procedure TYamlScanner.InitFromView(const AView: TStringView);
begin
  Init(AView.Data, AView.Len);
end;

function TYamlScanner.Peek: Byte;
begin
  if FPos < FLen then
    Result := Byte(FData[FPos])
  else
    Result := 0;
end;

function TYamlScanner.PeekAt(AOffset: SizeUInt): Byte;
begin
  if FPos + AOffset < FLen then
    Result := Byte(FData[FPos + AOffset])
  else
    Result := 0;
end;

function TYamlScanner.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

procedure TYamlScanner.Advance;
begin
  if FPos < FLen then
  begin
    if FData[FPos] = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
    Inc(FPos);
  end;
end;

procedure TYamlScanner.AdvanceN(ACount: SizeUInt);
var
  LI: SizeUInt;
begin
  for LI := 1 to ACount do
    Advance;
end;

procedure TYamlScanner.SkipWhitespaceAndComments;
var
  LCh: Byte;
begin
  while not AtEnd do
  begin
    LCh := Peek;
    if (LCh = 32) or (LCh = 9) then
      Advance
    else if LCh = Byte('#') then
    begin
      while (not AtEnd) and (Peek <> 10) do
        Advance;
    end
    else
      Break;
  end;
end;

procedure TYamlScanner.SkipToNextToken;
var
  LCh: Byte;
begin
  while not AtEnd do
  begin
    LCh := Peek;
    if (LCh = 32) or (LCh = 9) then
      Advance
    else if LCh = 10 then
    begin
      Advance;
      if FFlowLevel = 0 then
        Break;
    end
    else if LCh = 13 then
    begin
      Advance;
      if (not AtEnd) and (Peek = 10) then
        Advance;
      if FFlowLevel = 0 then
        Break;
    end
    else if LCh = Byte('#') then
    begin
      while (not AtEnd) and (Peek <> 10) do
        Advance;
    end
    else
      Break;
  end;
end;

function TYamlScanner.MakeToken(AKind: TYamlTokenKind): TYamlToken;
begin
  Result.Kind := AKind;
  Result.Value := TStringView.Empty;
  Result.Style := yssPlain;
  Result.Line := FLine;
  Result.Col := FCol;
end;

procedure TYamlScanner.SetError(const AMsg: string);
begin
  FHasError := True;
  FError.Message := TStringView.FromStr(AMsg);
  FError.Line := FLine;
  FError.Col := FCol;
  FError.Offset := FPos;
end;

function TYamlScanner.HasError: Boolean;
begin
  Result := FHasError;
end;

function TYamlScanner.Error: TYamlError;
begin
  Result := FError;
end;

function TYamlScanner.ScanSingleQuotedScalar: TYamlToken;
var
  LStart: SizeUInt;
begin
  Result := MakeToken(ytkScalar);
  Result.Style := yssSingleQuoted;
  Advance; // skip opening '
  LStart := FPos;
  while not AtEnd do
  begin
    if Peek = Byte('''') then
    begin
      if PeekAt(1) = Byte('''') then
      begin
        AdvanceN(2); // escaped ''
      end
      else
      begin
        Result.Value := TStringView.Create(@FData[LStart], FPos - LStart);
        Advance; // skip closing '
        Exit;
      end;
    end
    else
      Advance;
  end;
  SetError('unterminated single-quoted scalar');
  Result.Kind := ytkError;
end;

function TYamlScanner.ScanDoubleQuotedScalar: TYamlToken;
var
  LStart: SizeUInt;
begin
  Result := MakeToken(ytkScalar);
  Result.Style := yssDoubleQuoted;
  Advance; // skip opening "
  LStart := FPos;
  while not AtEnd do
  begin
    if Peek = Byte('\') then
    begin
      AdvanceN(2); // skip escape sequence
    end
    else if Peek = Byte('"') then
    begin
      Result.Value := TStringView.Create(@FData[LStart], FPos - LStart);
      Advance; // skip closing "
      Exit;
    end
    else
      Advance;
  end;
  SetError('unterminated double-quoted scalar');
  Result.Kind := ytkError;
end;

function TYamlScanner.ScanPlainScalar: TYamlToken;
var
  LStart, LEnd: SizeUInt;
  LCh: Byte;
begin
  Result := MakeToken(ytkScalar);
  Result.Style := yssPlain;
  LStart := FPos;
  LEnd := FPos;
  while not AtEnd do
  begin
    LCh := Peek;
    if (LCh = 10) or (LCh = 13) then
      Break;
    if FFlowLevel > 0 then
    begin
      if (LCh = Byte(',')) or (LCh = Byte(']')) or (LCh = Byte('}')) then
        Break;
    end;
    if (LCh = Byte(':')) and
       ((PeekAt(1) = 32) or (PeekAt(1) = 9) or (PeekAt(1) = 10) or
        (PeekAt(1) = 13) or (PeekAt(1) = 0) or
        ((FFlowLevel > 0) and ((PeekAt(1) = Byte(',')) or
         (PeekAt(1) = Byte(']')) or (PeekAt(1) = Byte('}'))))) then
      Break;
    if LCh = Byte('#') then
      if (FPos > 0) and ((FData[FPos - 1] = ' ') or (FData[FPos - 1] = #9)) then
        Break;
    Advance;
    if (LCh <> 32) and (LCh <> 9) then
      LEnd := FPos;
  end;
  Result.Value := TStringView.Create(@FData[LStart], LEnd - LStart);
end;

function TYamlScanner.ScanAnchorOrAlias: TYamlToken;
var
  LIsAlias: Boolean;
  LStart: SizeUInt;
  LCh: Byte;
begin
  LIsAlias := (Peek = Byte('*'));
  if LIsAlias then
    Result := MakeToken(ytkAlias)
  else
    Result := MakeToken(ytkAnchor);
  Advance; // skip & or *
  LStart := FPos;
  while not AtEnd do
  begin
    LCh := Peek;
    if (LCh = 32) or (LCh = 9) or (LCh = 10) or (LCh = 13) or
       (LCh = Byte(',')) or (LCh = Byte(']')) or (LCh = Byte('}')) or
       (LCh = Byte(':')) or (LCh = Byte('{')) or (LCh = Byte('[')) then
      Break;
    Advance;
  end;
  Result.Value := TStringView.Create(@FData[LStart], FPos - LStart);
  if Result.Value.IsEmpty then
  begin
    SetError('empty anchor/alias name');
    Result.Kind := ytkError;
  end;
end;

function TYamlScanner.NextToken: TYamlToken;
var
  LCh: Byte;
begin
  if FHasError then
  begin
    Result := MakeToken(ytkError);
    Exit;
  end;

  if not FStreamStarted then
  begin
    FStreamStarted := True;
    Result := MakeToken(ytkStreamStart);
    Exit;
  end;

  SkipToNextToken;

  if AtEnd then
  begin
    if not FStreamEnded then
    begin
      FStreamEnded := True;
      Result := MakeToken(ytkStreamEnd);
    end
    else
      Result := MakeToken(ytkStreamEnd);
    Exit;
  end;

  LCh := Peek;

  case LCh of
    Byte('{'):
    begin
      Inc(FFlowLevel);
      Result := MakeToken(ytkFlowMapStart);
      Advance;
    end;
    Byte('}'):
    begin
      Dec(FFlowLevel);
      Result := MakeToken(ytkFlowMapEnd);
      Advance;
    end;
    Byte('['):
    begin
      Inc(FFlowLevel);
      Result := MakeToken(ytkFlowSeqStart);
      Advance;
    end;
    Byte(']'):
    begin
      Dec(FFlowLevel);
      Result := MakeToken(ytkFlowSeqEnd);
      Advance;
    end;
    Byte(','):
    begin
      Result := MakeToken(ytkFlowEntry);
      Advance;
    end;
    Byte(':'):
    begin
      Result := MakeToken(ytkValue);
      Advance;
      if (not AtEnd) and ((Peek = 32) or (Peek = 9) or (Peek = 10) or (Peek = 13)) then
        ; // value indicator followed by whitespace — valid
    end;
    Byte('?'):
    begin
      if (PeekAt(1) = 32) or (PeekAt(1) = 9) or (PeekAt(1) = 10) or (PeekAt(1) = 0) then
      begin
        Result := MakeToken(ytkKey);
        Advance;
      end
      else
        Result := ScanPlainScalar;
    end;
    Byte(''''):
      Result := ScanSingleQuotedScalar;
    Byte('"'):
      Result := ScanDoubleQuotedScalar;
    Byte('&'), Byte('*'):
      Result := ScanAnchorOrAlias;
    Byte('-'):
    begin
      if (PeekAt(1) = Byte('-')) and (PeekAt(2) = Byte('-')) then
      begin
        Result := MakeToken(ytkDocStart);
        AdvanceN(3);
      end
      else if (FFlowLevel = 0) and ((PeekAt(1) = 32) or (PeekAt(1) = 9) or (PeekAt(1) = 10) or (PeekAt(1) = 0)) then
      begin
        Result := MakeToken(ytkBlockSeqStart);
        Advance;
      end
      else
        Result := ScanPlainScalar;
    end;
    Byte('.'):
    begin
      if (PeekAt(1) = Byte('.')) and (PeekAt(2) = Byte('.')) then
      begin
        Result := MakeToken(ytkDocEnd);
        AdvanceN(3);
      end
      else
        Result := ScanPlainScalar;
    end;
  else
    Result := ScanPlainScalar;
  end;
end;

end.
