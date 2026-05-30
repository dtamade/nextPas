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
    FIndentStack: array[0..63] of Int32;
    FIndentTop: Int32;
    FPendingTokens: array[0..63] of TYamlToken;
    FPendingCount: Int32;
    FAtLineStart: Boolean;
    function Peek: Byte; inline;
    function PeekAt(AOffset: SizeUInt): Byte; inline;
    function AtEnd: Boolean; inline;
    procedure Advance; inline;
    procedure AdvanceN(ACount: SizeUInt); inline;
    procedure SkipBlanks;
    procedure SkipComment;
    function CurrentIndent: Int32; inline;
    procedure PushIndent(ACol: Int32);
    procedure PopIndent;
    procedure EnqueueToken(const ATok: TYamlToken);
    function DequeueToken: TYamlToken;
    procedure UnwindIndentsTo(ACol: Int32);
    function ScanPlainScalar: TYamlToken;
    function ScanSingleQuotedScalar: TYamlToken;
    function ScanDoubleQuotedScalar: TYamlToken;
    function ScanAnchorOrAlias: TYamlToken;
    function ScanBlockScalar: TYamlToken;
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
  FIndentStack[0] := -1;
  FIndentTop := 0;
  FPendingCount := 0;
  FAtLineStart := True;
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
      FAtLineStart := True;
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

procedure TYamlScanner.SkipBlanks;
begin
  while (not AtEnd) and ((Peek = 32) or (Peek = 9)) do
    Advance;
end;

procedure TYamlScanner.SkipComment;
begin
  if (not AtEnd) and (Peek = Byte('#')) then
    while (not AtEnd) and (Peek <> 10) do
      Advance;
end;

function TYamlScanner.CurrentIndent: Int32;
begin
  Result := FIndentStack[FIndentTop];
end;

procedure TYamlScanner.PushIndent(ACol: Int32);
begin
  if FIndentTop < 63 then
  begin
    Inc(FIndentTop);
    FIndentStack[FIndentTop] := ACol;
  end
  else
    SetError('nesting too deep');
end;

procedure TYamlScanner.PopIndent;
begin
  if FIndentTop > 0 then
    Dec(FIndentTop);
end;

procedure TYamlScanner.EnqueueToken(const ATok: TYamlToken);
begin
  if FPendingCount < 64 then
  begin
    FPendingTokens[FPendingCount] := ATok;
    Inc(FPendingCount);
  end
  else
    SetError('token queue overflow');
end;

function TYamlScanner.DequeueToken: TYamlToken;
var
  LI: Int32;
begin
  Result := FPendingTokens[0];
  Dec(FPendingCount);
  for LI := 0 to FPendingCount - 1 do
    FPendingTokens[LI] := FPendingTokens[LI + 1];
end;

procedure TYamlScanner.UnwindIndentsTo(ACol: Int32);
begin
  while (FFlowLevel = 0) and (CurrentIndent > ACol) do
  begin
    EnqueueToken(MakeToken(ytkBlockEnd));
    PopIndent;
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
  Advance;
  LStart := FPos;
  while not AtEnd do
  begin
    if Peek = Byte('''') then
    begin
      if PeekAt(1) = Byte('''') then
        AdvanceN(2)
      else
      begin
        Result.Value := TStringView.Create(@FData[LStart], FPos - LStart);
        Advance;
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
  Advance;
  LStart := FPos;
  while not AtEnd do
  begin
    if Peek = Byte('\') then
      AdvanceN(2)
    else if Peek = Byte('"') then
    begin
      Result.Value := TStringView.Create(@FData[LStart], FPos - LStart);
      Advance;
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
      if (LCh = Byte(',')) or (LCh = Byte(']')) or (LCh = Byte('}')) then
        Break;
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
  Advance;
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

function TYamlScanner.ScanBlockScalar: TYamlToken;
var
  LStyle: TYamlScalarStyle;
  LChomp: Byte;
  LStart, LEnd: SizeUInt;
  LBlockIndent, LCurIndent: Int32;
begin
  if Peek = Byte('|') then
    LStyle := yssLiteral
  else
    LStyle := yssFolded;
  Advance;
  LChomp := 0;
  if (not AtEnd) and (Peek = Byte('-')) then begin LChomp := 1; Advance; end
  else if (not AtEnd) and (Peek = Byte('+')) then begin LChomp := 2; Advance; end;
  // skip to end of indicator line
  SkipBlanks;
  SkipComment;
  if (not AtEnd) and ((Peek = 10) or (Peek = 13)) then
    Advance;
  if (not AtEnd) and (Peek = 10) then
    Advance;

  // Determine block indent from first content line
  LBlockIndent := 0;
  LStart := FPos;
  while (not AtEnd) and (Peek = 32) do
  begin
    Inc(LBlockIndent);
    Advance;
  end;
  if LBlockIndent = 0 then
    LBlockIndent := CurrentIndent + 1;

  LStart := FPos - SizeUInt(LBlockIndent);
  // Actually, let's just capture all lines with indent >= LBlockIndent
  LStart := FPos;
  LEnd := FPos;

  while not AtEnd do
  begin
    // Read content of current line
    while (not AtEnd) and (Peek <> 10) and (Peek <> 13) do
      Advance;
    LEnd := FPos;
    // Consume newline
    if (not AtEnd) and (Peek = 13) then Advance;
    if (not AtEnd) and (Peek = 10) then Advance;
    // Check next line indent
    LCurIndent := 0;
    while (not AtEnd) and (Peek = 32) do
    begin
      Inc(LCurIndent);
      Advance;
    end;
    if AtEnd then Break;
    if (Peek <> 10) and (Peek <> 13) and (LCurIndent < LBlockIndent) then
    begin
      if SizeUInt(LCurIndent) <= FPos then
        FPos := FPos - SizeUInt(LCurIndent);
      if UInt32(LCurIndent) < FCol then
        FCol := FCol - UInt32(LCurIndent);
      Break;
    end;
  end;

  Result := MakeToken(ytkScalar);
  Result.Style := LStyle;
  // Trim trailing newlines based on chomping
  if LChomp = 1 then // strip
    while (LEnd > LStart) and ((FData[LEnd - 1] = #10) or (FData[LEnd - 1] = #13)) do
      Dec(LEnd)
  else if LChomp = 0 then // clip: keep one newline
  begin
    while (LEnd > LStart) and ((FData[LEnd - 1] = #10) or (FData[LEnd - 1] = #13)) do
      Dec(LEnd);
    if LEnd < FPos then Inc(LEnd); // keep one
  end;
  Result.Value := TStringView.Create(@FData[LStart], LEnd - LStart);
end;

function TYamlScanner.NextToken: TYamlToken;
var
  LCh: Byte;
  LCol: Int32;
begin
  if FHasError then
  begin
    Result := MakeToken(ytkError);
    Exit;
  end;

  if FPendingCount > 0 then
  begin
    Result := DequeueToken;
    Exit;
  end;

  if not FStreamStarted then
  begin
    FStreamStarted := True;
    Result := MakeToken(ytkStreamStart);
    Exit;
  end;

  // Skip whitespace and newlines
  while not AtEnd do
  begin
    LCh := Peek;
    if (LCh = 32) or (LCh = 9) then
    begin
      Advance;
      FAtLineStart := False;
    end
    else if (LCh = 10) then
    begin
      Advance;
      FAtLineStart := True;
    end
    else if (LCh = 13) then
    begin
      Advance;
      if (not AtEnd) and (Peek = 10) then Advance;
      FAtLineStart := True;
    end
    else if LCh = Byte('#') then
    begin
      while (not AtEnd) and (Peek <> 10) do Advance;
    end
    else
      Break;
  end;

  if AtEnd then
  begin
    if not FStreamEnded then
    begin
      FStreamEnded := True;
      UnwindIndentsTo(0);
      if FPendingCount > 0 then
      begin
        EnqueueToken(MakeToken(ytkStreamEnd));
        Result := DequeueToken;
        Exit;
      end;
      Result := MakeToken(ytkStreamEnd);
    end
    else
      Result := MakeToken(ytkStreamEnd);
    Exit;
  end;

  LCh := Peek;
  LCol := Int32(FCol) - 1; // 0-based column

  // Block context: check indentation
  if (FFlowLevel = 0) and FAtLineStart then
  begin
    UnwindIndentsTo(LCol);
    if FPendingCount > 0 then
    begin
      // Return pending BlockEnd tokens first, re-process current char next time
      Result := DequeueToken;
      Exit;
    end;
  end;
  FAtLineStart := False;

  case LCh of
    Byte('{'):
    begin
      Inc(FFlowLevel);
      Result := MakeToken(ytkFlowMapStart);
      Advance;
    end;
    Byte('}'):
    begin
      if FFlowLevel > 0 then Dec(FFlowLevel);
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
      if FFlowLevel > 0 then Dec(FFlowLevel);
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
      if (FFlowLevel > 0) or (PeekAt(1) = 32) or (PeekAt(1) = 9) or
         (PeekAt(1) = 10) or (PeekAt(1) = 13) or (PeekAt(1) = 0) then
      begin
        Result := MakeToken(ytkValue);
        Advance;
      end
      else
        Result := ScanPlainScalar;
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
    Byte('|'), Byte('>'):
      Result := ScanBlockScalar;
    Byte('&'), Byte('*'):
      Result := ScanAnchorOrAlias;
    Byte('-'):
    begin
      if (PeekAt(1) = Byte('-')) and (PeekAt(2) = Byte('-')) and
         ((PeekAt(3) = 0) or (PeekAt(3) = 32) or (PeekAt(3) = 9) or
          (PeekAt(3) = 10) or (PeekAt(3) = 13)) then
      begin
        UnwindIndentsTo(0);
        if FPendingCount > 0 then
          EnqueueToken(MakeToken(ytkDocStart))
        else
        begin
          Result := MakeToken(ytkDocStart);
          AdvanceN(3);
          Exit;
        end;
        AdvanceN(3);
        Result := DequeueToken;
      end
      else if (FFlowLevel = 0) and ((PeekAt(1) = 32) or (PeekAt(1) = 9)) then
      begin
        if LCol > CurrentIndent then
          PushIndent(LCol);
        Result := MakeToken(ytkBlockSeqStart);
        Advance; // consume -
      end
      else
        Result := ScanPlainScalar;
    end;
    Byte('.'):
    begin
      if (PeekAt(1) = Byte('.')) and (PeekAt(2) = Byte('.')) and
         ((PeekAt(3) = 0) or (PeekAt(3) = 32) or (PeekAt(3) = 9) or
          (PeekAt(3) = 10) or (PeekAt(3) = 13)) then
      begin
        UnwindIndentsTo(0);
        if FPendingCount > 0 then
          EnqueueToken(MakeToken(ytkDocEnd))
        else
        begin
          Result := MakeToken(ytkDocEnd);
          AdvanceN(3);
          Exit;
        end;
        AdvanceN(3);
        Result := DequeueToken;
      end
      else
        Result := ScanPlainScalar;
    end;
  else
    Result := ScanPlainScalar;
  end;
end;

end.
