unit nextpas.core.toml.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.toml.base;

type
  TTomlDocument = record
  private
    FNodes: PTomlNode;
    FNodeCount: UInt32;
    FNodeCap: UInt32;
    FAllocator: IAllocator;
    FInput: TStringView;
    FError: TTomlError;
    FHasError: Boolean;
    FOwnedBufs: PPointer;
    FOwnedCount: UInt32;
    FOwnedCap: UInt32;
    FCurrentTable: UInt32;
    function AddNode: UInt32;
    procedure AddOwnedBuf(ABuf: Pointer);
  public
    procedure Init(const AAllocator: IAllocator);
    procedure Done;
    function Parse(const AInput: TStringView): Boolean;
    function Root: UInt32; inline;
    function Node(const AIdx: UInt32): PTomlNode; inline;
    function NodeCount: UInt32; inline;
    function HasError: Boolean; inline;
    function Error: TTomlError; inline;
    function Input: TStringView; inline;
  end;

implementation

uses
  nextpas.core.text.scan,
  nextpas.core.text.char,
  nextpas.core.text.number,
  nextpas.core.text.escape,
  nextpas.core.text.utf8;

const
  INITIAL_NODE_CAP = 64;
  INITIAL_OWNED_CAP = 16;
  MAX_NESTING_DEPTH = 128;
  NAN_BITS: QWord = QWord($7FF8000000000000);

var
  TOML_NAN: Double absolute NAN_BITS;

function HexDigitVal(ACh: Byte): Int32; inline;
begin
  if (ACh >= Ord('0')) and (ACh <= Ord('9')) then Exit(ACh - Ord('0'));
  if (ACh >= Ord('a')) and (ACh <= Ord('f')) then Exit(ACh - Ord('a') + 10);
  if (ACh >= Ord('A')) and (ACh <= Ord('F')) then Exit(ACh - Ord('A') + 10);
  Result := -1;
end;

function TomlUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt;
var
  LPos, LOut: SizeUInt;
  LCh: Byte;
  LCP: UInt32;
  LI: Int32;
  LHexLen: Int32;
  LEncLen: Byte;
begin
  AError := ueNone;
  LPos := 0;
  LOut := 0;
  while LPos < ALen do
  begin
    LCh := Byte(ASrc[LPos]);
    if LCh <> Ord('\') then
    begin
      ADst[LOut] := AnsiChar(LCh);
      Inc(LOut);
      Inc(LPos);
      Continue;
    end;
    Inc(LPos);
    if LPos >= ALen then
    begin
      AError := ueTruncated;
      Exit(LOut);
    end;
    LCh := Byte(ASrc[LPos]);
    Inc(LPos);
    case LCh of
      Ord('"'):  begin ADst[LOut] := '"'; Inc(LOut); end;
      Ord('\'): begin ADst[LOut] := '\'; Inc(LOut); end;
      Ord('b'):  begin ADst[LOut] := #8; Inc(LOut); end;
      Ord('f'):  begin ADst[LOut] := #12; Inc(LOut); end;
      Ord('n'):  begin ADst[LOut] := #10; Inc(LOut); end;
      Ord('r'):  begin ADst[LOut] := #13; Inc(LOut); end;
      Ord('t'):  begin ADst[LOut] := #9; Inc(LOut); end;
      Ord('u'), Ord('U'):
      begin
        if LCh = Ord('u') then LHexLen := 4 else LHexLen := 8;
        if LPos + SizeUInt(LHexLen) > ALen then
        begin
          AError := ueTruncated;
          Exit(LOut);
        end;
        LCP := 0;
        for LI := 0 to LHexLen - 1 do
        begin
          if HexDigitVal(Byte(ASrc[LPos + SizeUInt(LI)])) < 0 then
          begin
            AError := ueInvalidUnicode;
            Exit(LOut);
          end;
          LCP := (LCP shl 4) or UInt32(HexDigitVal(Byte(ASrc[LPos + SizeUInt(LI)])));
        end;
        Inc(LPos, SizeUInt(LHexLen));
        if LCP > $10FFFF then
        begin
          AError := ueInvalidUnicode;
          Exit(LOut);
        end;
        if (LCP >= $D800) and (LCP <= $DFFF) then
        begin
          AError := ueInvalidUnicode;
          Exit(LOut);
        end;
        LEncLen := UTF8Encode(LCP, PByte(@ADst[LOut]));
        Inc(LOut, LEncLen);
      end;
    else
      AError := ueInvalidEscape;
      Exit(LOut);
    end;
  end;
  Result := LOut;
end;

{ TTomlDocument }

procedure TTomlDocument.Init(const AAllocator: IAllocator);
begin
  FAllocator := AAllocator;
  FNodeCap := INITIAL_NODE_CAP;
  FNodes := FAllocator.Allocate(FNodeCap * SizeOf(TTomlNode));
  FNodeCount := 0;
  FHasError := False;
  FOwnedBufs := nil;
  FOwnedCount := 0;
  FOwnedCap := 0;
  FCurrentTable := TOML_NODE_NONE;
end;

procedure TTomlDocument.Done;
var
  LI: UInt32;
begin
  if FOwnedBufs <> nil then
  begin
    for LI := 0 to FOwnedCount - 1 do
      FAllocator.Deallocate((FOwnedBufs + LI)^);
    FAllocator.Deallocate(Pointer(FOwnedBufs));
    FOwnedBufs := nil;
  end;
  if FNodes <> nil then
  begin
    FAllocator.Deallocate(FNodes);
    FNodes := nil;
  end;
  FNodeCount := 0;
  FNodeCap := 0;
  FOwnedCount := 0;
  FOwnedCap := 0;
end;

procedure TTomlDocument.AddOwnedBuf(ABuf: Pointer);
var
  LNewCap: UInt32;
begin
  if FOwnedBufs = nil then
  begin
    FOwnedCap := INITIAL_OWNED_CAP;
    FOwnedBufs := PPointer(FAllocator.Allocate(FOwnedCap * SizeOf(Pointer)));
  end
  else if FOwnedCount >= FOwnedCap then
  begin
    LNewCap := FOwnedCap * 2;
    FOwnedBufs := PPointer(FAllocator.Reallocate(Pointer(FOwnedBufs), LNewCap * SizeOf(Pointer)));
    FOwnedCap := LNewCap;
  end;
  (FOwnedBufs + FOwnedCount)^ := ABuf;
  Inc(FOwnedCount);
end;

function TTomlDocument.AddNode: UInt32;
var
  LNewCap: UInt32;
begin
  if FNodeCount >= FNodeCap then
  begin
    LNewCap := FNodeCap * 2;
    FNodes := FAllocator.Reallocate(FNodes, LNewCap * SizeOf(TTomlNode));
    FNodeCap := LNewCap;
  end;
  Result := FNodeCount;
  FillChar(FNodes[FNodeCount], SizeOf(TTomlNode), 0);
  FNodes[FNodeCount].Next := TOML_NODE_NONE;
  Inc(FNodeCount);
end;

function TTomlDocument.Root: UInt32;
begin
  if FNodeCount > 0 then Result := 0 else Result := TOML_NODE_NONE;
end;

function TTomlDocument.Node(const AIdx: UInt32): PTomlNode;
begin
  Result := @FNodes[AIdx];
end;

function TTomlDocument.NodeCount: UInt32;
begin
  Result := FNodeCount;
end;

function TTomlDocument.HasError: Boolean;
begin
  Result := FHasError;
end;

function TTomlDocument.Error: TTomlError;
begin
  Result := FError;
end;

function TTomlDocument.Input: TStringView;
begin
  Result := FInput;
end;

{ Parser state }

type
  TTomlParser = record
    Doc: ^TTomlDocument;
    Src: PAnsiChar;
    SrcLen: SizeUInt;
    Pos: SizeUInt;
    Line: UInt32;
    Col: UInt32;
    Depth: Int32;
    function Peek: Byte; inline;
    function IsEOF: Boolean; inline;
    procedure Advance; inline;
    procedure AdvanceN(ACount: SizeUInt); inline;
    procedure SkipWhitespaceInline;
    procedure SkipWhitespaceAndNewlines;
    function SkipComment: Boolean;
    procedure SkipToNextLine;
    function SetError(const AMsg: PAnsiChar; ALen: SizeUInt): Boolean;
    function ParseBareKey(out AKey: TStringView): Boolean;
    function ParseQuotedKey(out AKey: TStringView): Boolean;
    function ParseKey(out AKey: TStringView): Boolean;
    function ParseDottedKey(out AKeys: array of TStringView; out ACount: Int32): Boolean;
    function ParseBasicString(out AStr: TStringView; out AOwned: Boolean): Boolean;
    function ParseLiteralString(out AStr: TStringView): Boolean;
    function ParseMultiLineBasicString(out AStr: TStringView; out AOwned: Boolean): Boolean;
    function ParseMultiLineLiteralString(out AStr: TStringView): Boolean;
    function ParseValue(out ANodeIdx: UInt32): Boolean;
    function ParseString(out ANodeIdx: UInt32): Boolean;
    function ParseNumber(out ANodeIdx: UInt32): Boolean;
    function ParseBool(out ANodeIdx: UInt32): Boolean;
    function ParseDateTime(out ANodeIdx: UInt32; const AStart: PAnsiChar; ALen: SizeUInt): Boolean;
    function ParseArray(out ANodeIdx: UInt32): Boolean;
    function ParseInlineTable(out ANodeIdx: UInt32): Boolean;
    function ParseKeyValue(ATableIdx: UInt32): Boolean;
    function ParseTableHeader(out AIsArray: Boolean): Boolean;
    function FindOrCreateTable(AParent: UInt32; const AKey: TStringView;
      AImplicit: Boolean): UInt32;
    function FindChild(ATableIdx: UInt32; const AKey: TStringView): UInt32;
    procedure AddChild(ATableIdx: UInt32; AChildIdx: UInt32);
  end;

function TTomlParser.Peek: Byte;
begin
  if Pos < SrcLen then
    Result := Byte(Src[Pos])
  else
    Result := 0;
end;

function TTomlParser.IsEOF: Boolean;
begin
  Result := Pos >= SrcLen;
end;

procedure TTomlParser.Advance;
begin
  if Pos < SrcLen then
  begin
    if Src[Pos] = #10 then
    begin
      Inc(Line);
      Col := 1;
    end
    else
      Inc(Col);
    Inc(Pos);
  end;
end;

procedure TTomlParser.AdvanceN(ACount: SizeUInt);
var
  I: SizeUInt;
begin
  for I := 1 to ACount do
    Advance;
end;

procedure TTomlParser.SkipWhitespaceInline;
var
  LStart: SizeUInt;
begin
  LStart := Pos;
  while (Pos < SrcLen) and ((Src[Pos] = ' ') or (Src[Pos] = #9)) do
    Inc(Pos);
  Col := Col + UInt32(Pos - LStart);
end;

procedure TTomlParser.SkipWhitespaceAndNewlines;
begin
  while Pos < SrcLen do
  begin
    case Src[Pos] of
      ' ', #9, #13: begin Inc(Pos); Inc(Col); end;
      #10: begin Inc(Pos); Inc(Line); Col := 1; end;
      '#': SkipComment;
    else
      Exit;
    end;
  end;
end;

function TTomlParser.SkipComment: Boolean;
var
  LRemaining: SizeUInt;
  LFound: PtrInt;
begin
  if (Pos < SrcLen) and (Src[Pos] = '#') then
  begin
    LRemaining := SrcLen - Pos;
    LFound := ScanFindByte(Src + Pos, LRemaining, Ord(#10));
    if LFound >= 0 then
    begin
      Col := Col + UInt32(LFound);
      Inc(Pos, SizeUInt(LFound));
    end
    else
    begin
      Col := Col + UInt32(LRemaining);
      Pos := SrcLen;
    end;
  end;
  Result := True;
end;

procedure TTomlParser.SkipToNextLine;
begin
  while (Pos < SrcLen) and (Src[Pos] <> #10) do
    Advance;
  if (Pos < SrcLen) and (Src[Pos] = #10) then
    Advance;
end;

function TTomlParser.SetError(const AMsg: PAnsiChar; ALen: SizeUInt): Boolean;
begin
  Doc^.FError.Message := TStringView.Create(AMsg, ALen);
  Doc^.FError.Line := Line;
  Doc^.FError.Col := Col;
  Doc^.FError.Offset := Pos;
  Doc^.FHasError := True;
  Result := False;
end;

function IsBareKeyChar(ACh: Byte): Boolean; inline;
begin
  Result := ((ACh >= Ord('A')) and (ACh <= Ord('Z')))
    or ((ACh >= Ord('a')) and (ACh <= Ord('z')))
    or ((ACh >= Ord('0')) and (ACh <= Ord('9')))
    or (ACh = Ord('-')) or (ACh = Ord('_'));
end;

function TTomlParser.ParseBareKey(out AKey: TStringView): Boolean;
var
  LStart: SizeUInt;
  LCh: Byte;
begin
  LStart := Pos;
  while Pos < SrcLen do
  begin
    LCh := Byte(Src[Pos]);
    if not (((LCh or 32) >= Ord('a')) and ((LCh or 32) <= Ord('z'))
      or (LCh >= Ord('0')) and (LCh <= Ord('9'))
      or (LCh = Ord('-')) or (LCh = Ord('_'))) then
      Break;
    Inc(Pos);
  end;
  if Pos = LStart then
    Exit(SetError('expected key', 12));
  AKey := TStringView.Create(Src + LStart, Pos - LStart);
  Col := Col + UInt32(Pos - LStart);
  Result := True;
end;

function TTomlParser.ParseQuotedKey(out AKey: TStringView): Boolean;
var
  LOwned: Boolean;
begin
  if Src[Pos] = '"' then
    Result := ParseBasicString(AKey, LOwned)
  else
    Result := ParseLiteralString(AKey);
end;

function TTomlParser.ParseKey(out AKey: TStringView): Boolean;
begin
  if (Pos < SrcLen) and ((Src[Pos] = '"') or (Src[Pos] = '''')) then
    Result := ParseQuotedKey(AKey)
  else
    Result := ParseBareKey(AKey);
end;

function TTomlParser.ParseDottedKey(out AKeys: array of TStringView; out ACount: Int32): Boolean;
begin
  ACount := 0;
  if not ParseKey(AKeys[ACount]) then Exit(False);
  Inc(ACount);
  SkipWhitespaceInline;
  while (Pos < SrcLen) and (Src[Pos] = '.') do
  begin
    Advance;
    SkipWhitespaceInline;
    if ACount >= Length(AKeys) then
      Exit(SetError('key too deeply nested', 21));
    if not ParseKey(AKeys[ACount]) then Exit(False);
    Inc(ACount);
    SkipWhitespaceInline;
  end;
  Result := True;
end;

function TTomlParser.ParseBasicString(out AStr: TStringView; out AOwned: Boolean): Boolean;
var
  LStart, LEnd: SizeUInt;
  LHasEscape: Boolean;
  LBuf: PAnsiChar;
  LBufLen: SizeUInt;
  LErr: TUnescapeError;
  LFound, LCtrl: PtrInt;
  LRemaining: SizeUInt;
begin
  AOwned := False;
  Advance; // skip opening "
  LStart := Pos;
  LHasEscape := False;
  while Pos < SrcLen do
  begin
    LRemaining := SrcLen - Pos;
    LFound := ScanFindByte2(Src + Pos, LRemaining, Ord('"'), Ord('\'));
    LCtrl := ScanFindInRange(Src + Pos, LRemaining, 0, 31);
    if (LCtrl >= 0) and ((LFound < 0) or (LCtrl < LFound)) then
    begin
      if Src[Pos + SizeUInt(LCtrl)] = #9 then
      begin
        if LFound < 0 then begin Pos := SrcLen; Break; end;
        Inc(Pos, SizeUInt(LFound));
        Col := Col + UInt32(LFound);
      end
      else
      begin
        Inc(Pos, SizeUInt(LCtrl));
        Col := Col + UInt32(LCtrl);
        Exit(SetError('control char in string', 22));
      end;
    end
    else if LFound < 0 then
    begin
      Pos := SrcLen;
      Break;
    end
    else
    begin
      Inc(Pos, SizeUInt(LFound));
      Col := Col + UInt32(LFound);
    end;
    if (Pos < SrcLen) and (Src[Pos] = '"') then
      Break
    else if (Pos < SrcLen) and (Src[Pos] = '\') then
    begin
      LHasEscape := True;
      Inc(Pos);
      if Pos < SrcLen then Inc(Pos);
      Col := Col + 2;
    end;
  end;
  if (Pos >= SrcLen) or (Src[Pos] <> '"') then
    Exit(SetError('unterminated string', 19));
  LEnd := Pos;
  Advance; // skip closing "
  if LHasEscape then
  begin
    LBufLen := LEnd - LStart;
    LBuf := Doc^.FAllocator.Allocate(LBufLen);
    LBufLen := TomlUnescapeToBuffer(Src + LStart, LEnd - LStart, LBuf, LErr);
    if LErr <> ueNone then
    begin
      Doc^.FAllocator.Deallocate(LBuf);
      Exit(SetError('invalid escape sequence', 22));
    end;
    AStr := TStringView.Create(LBuf, LBufLen);
    AOwned := True;
    Doc^.AddOwnedBuf(LBuf);
  end
  else
    AStr := TStringView.Create(Src + LStart, LEnd - LStart);
  Result := True;
end;

function TTomlParser.ParseLiteralString(out AStr: TStringView): Boolean;
var
  LStart: SizeUInt;
begin
  Advance; // skip opening '
  LStart := Pos;
  while (Pos < SrcLen) and (Src[Pos] <> '''') do
  begin
    if (Byte(Src[Pos]) < 32) and (Src[Pos] <> #9) then
      Exit(SetError('control char in string', 22));
    Inc(Pos);
    Inc(Col);
  end;
  if Pos >= SrcLen then
    Exit(SetError('unterminated string', 19));
  AStr := TStringView.Create(Src + LStart, Pos - LStart);
  Advance; // skip closing '
  Result := True;
end;

function TTomlParser.ParseMultiLineBasicString(out AStr: TStringView; out AOwned: Boolean): Boolean;
var
  LStart, LEnd, LBufLen: SizeUInt;
  LBuf, LDst: PAnsiChar;
  LI: SizeUInt;
  LErr: TUnescapeError;
begin
  AOwned := False;
  AdvanceN(3); // skip """
  if (Pos < SrcLen) and (Src[Pos] = #10) then Advance
  else if (Pos + 1 < SrcLen) and (Src[Pos] = #13) and (Src[Pos+1] = #10) then AdvanceN(2);
  LStart := Pos;
  while Pos < SrcLen do
  begin
    if (Pos + 2 < SrcLen) and (Src[Pos] = '"') and (Src[Pos+1] = '"') and (Src[Pos+2] = '"') then
    begin
      LEnd := Pos;
      AdvanceN(3);
      LBufLen := LEnd - LStart;
      LBuf := Doc^.FAllocator.Allocate(LBufLen + 1);
      LDst := LBuf;
      LI := LStart;
      while LI < LEnd do
      begin
        if (Src[LI] = '\') and (LI + 1 < LEnd) then
        begin
          if Src[LI+1] = #10 then
          begin
            Inc(LI, 2);
            while (LI < LEnd) and ((Src[LI] = ' ') or (Src[LI] = #9) or (Src[LI] = #10) or (Src[LI] = #13)) do
              Inc(LI);
            Continue;
          end
          else if (Src[LI+1] = #13) and (LI + 2 < LEnd) and (Src[LI+2] = #10) then
          begin
            Inc(LI, 3);
            while (LI < LEnd) and ((Src[LI] = ' ') or (Src[LI] = #9) or (Src[LI] = #10) or (Src[LI] = #13)) do
              Inc(LI);
            Continue;
          end;
        end;
        if Src[LI] = #13 then
        begin
          LDst^ := #10;
          Inc(LDst);
          Inc(LI);
          if (LI < LEnd) and (Src[LI] = #10) then Inc(LI);
        end
        else
        begin
          LDst^ := Src[LI];
          Inc(LDst);
          Inc(LI);
        end;
      end;
      LBufLen := LDst - LBuf;
      LBufLen := TomlUnescapeToBuffer(LBuf, LBufLen, LBuf, LErr);
      if LErr <> ueNone then
      begin
        Doc^.FAllocator.Deallocate(LBuf);
        Exit(SetError('invalid escape in multi-line string', 35));
      end;
      AStr := TStringView.Create(LBuf, LBufLen);
      AOwned := True;
      Doc^.AddOwnedBuf(LBuf);
      Exit(True);
    end;
    Inc(Pos);
    if Src[Pos-1] = #10 then begin Inc(Line); Col := 1; end else Inc(Col);
  end;
  Result := SetError('unterminated multi-line string', 30);
end;

function TTomlParser.ParseMultiLineLiteralString(out AStr: TStringView): Boolean;
var
  LStart, LEnd, LBufLen: SizeUInt;
  LBuf, LDst: PAnsiChar;
  LI: SizeUInt;
begin
  AdvanceN(3); // skip '''
  if (Pos < SrcLen) and (Src[Pos] = #10) then Advance
  else if (Pos + 1 < SrcLen) and (Src[Pos] = #13) and (Src[Pos+1] = #10) then AdvanceN(2);
  LStart := Pos;
  while Pos < SrcLen do
  begin
    if (Pos + 2 < SrcLen) and (Src[Pos] = '''') and (Src[Pos+1] = '''') and (Src[Pos+2] = '''') then
    begin
      LEnd := Pos;
      AdvanceN(3);
      LBufLen := LEnd - LStart;
      LBuf := Doc^.FAllocator.Allocate(LBufLen + 1);
      LDst := LBuf;
      LI := LStart;
      while LI < LEnd do
      begin
        if Src[LI] = #13 then
        begin
          LDst^ := #10;
          Inc(LDst);
          Inc(LI);
          if (LI < LEnd) and (Src[LI] = #10) then Inc(LI);
        end
        else
        begin
          LDst^ := Src[LI];
          Inc(LDst);
          Inc(LI);
        end;
      end;
      AStr := TStringView.Create(LBuf, LDst - LBuf);
      Doc^.AddOwnedBuf(LBuf);
      Exit(True);
    end;
    Inc(Pos);
    if Src[Pos-1] = #10 then begin Inc(Line); Col := 1; end else Inc(Col);
  end;
  Result := SetError('unterminated multi-line literal string', 38);
end;

function TTomlParser.ParseString(out ANodeIdx: UInt32): Boolean;
var
  LStr: TStringView;
  LOwned: Boolean;
begin
  LOwned := False;
  if (Pos + 2 < SrcLen) and (Src[Pos] = '"') and (Src[Pos+1] = '"') and (Src[Pos+2] = '"') then
  begin
    if not ParseMultiLineBasicString(LStr, LOwned) then Exit(False);
  end
  else if (Pos + 2 < SrcLen) and (Src[Pos] = '''') and (Src[Pos+1] = '''') and (Src[Pos+2] = '''') then
  begin
    if not ParseMultiLineLiteralString(LStr) then Exit(False);
  end
  else if Src[Pos] = '"' then
  begin
    if not ParseBasicString(LStr, LOwned) then Exit(False);
  end
  else
  begin
    if not ParseLiteralString(LStr) then Exit(False);
  end;
  ANodeIdx := Doc^.AddNode;
  Doc^.FNodes[ANodeIdx].Kind := tnkString;
  Doc^.FNodes[ANodeIdx].Str := LStr;
  Result := True;
end;

function IsDigitChar(ACh: Byte): Boolean; inline;
begin
  Result := (ACh >= Ord('0')) and (ACh <= Ord('9'));
end;

function TTomlParser.ParseNumber(out ANodeIdx: UInt32): Boolean;
var
  LStart: SizeUInt;
  LNeg: Boolean;
  LBase: Int32;
  LHasDot, LHasExp: Boolean;
  LBuf: array[0..127] of AnsiChar;
  LBufLen: Int32;
  LI: SizeUInt;
  LIntVal: Int64;
  LUIntVal: UInt64;
  LFloatVal: Double;
  LCh: Byte;
  LPrevUnderscore: Boolean;
  LDigitCount: Int32;
begin
  LStart := Pos;
  LNeg := False;
  LBase := 10;
  LHasDot := False;
  LHasExp := False;

  if (Src[Pos] = '+') or (Src[Pos] = '-') then
  begin
    LNeg := Src[Pos] = '-';
    Inc(Pos); Inc(Col);
  end;

  // inf / nan
  if (Pos + 3 <= SrcLen) and (Src[Pos] = 'i') and (Src[Pos+1] = 'n') and (Src[Pos+2] = 'f') then
  begin
    Inc(Pos, 3); Col := Col + 3;
    ANodeIdx := Doc^.AddNode;
    Doc^.FNodes[ANodeIdx].Kind := tnkFloat;
    if LNeg then
      Doc^.FNodes[ANodeIdx].FloatVal := -1.0/0.0
    else
      Doc^.FNodes[ANodeIdx].FloatVal := 1.0/0.0;
    Exit(True);
  end;
  if (Pos + 3 <= SrcLen) and (Src[Pos] = 'n') and (Src[Pos+1] = 'a') and (Src[Pos+2] = 'n') then
  begin
    Inc(Pos, 3); Col := Col + 3;
    ANodeIdx := Doc^.AddNode;
    Doc^.FNodes[ANodeIdx].Kind := tnkFloat;
    Doc^.FNodes[ANodeIdx].FloatVal := TOML_NAN;
    Exit(True);
  end;

  // Check base prefix (only allowed without sign)
  if (not LNeg) and (Pos + 1 < SrcLen) and (Src[Pos] = '0') then
  begin
    case Src[Pos+1] of
      'x': begin LBase := 16; Inc(Pos, 2); Col := Col + 2; end;
      'o': begin LBase := 8; Inc(Pos, 2); Col := Col + 2; end;
      'b': begin LBase := 2; Inc(Pos, 2); Col := Col + 2; end;
    end;
  end
  else if LNeg and (Pos + 1 < SrcLen) and (Src[Pos] = '0') and
    ((Src[Pos+1] = 'x') or (Src[Pos+1] = 'o') or (Src[Pos+1] = 'b')) then
    Exit(SetError('sign not allowed with base prefix', 34));

  // Collect digits into buffer (strip underscores with validation)
  LBufLen := 0;
  if LNeg then
  begin
    LBuf[0] := '-';
    LBufLen := 1;
  end;

  if LBase <> 10 then
  begin
    LPrevUnderscore := True; // treat start as "underscore" to reject leading _
    LDigitCount := 0;
    while Pos < SrcLen do
    begin
      LCh := Byte(Src[Pos]);
      if LCh = Ord('_') then
      begin
        if LPrevUnderscore then
          Exit(SetError('invalid underscore in number', 28));
        LPrevUnderscore := True;
        Inc(Pos); Inc(Col);
        Continue;
      end;
      case LBase of
        16: if not (((LCh >= Ord('0')) and (LCh <= Ord('9')))
              or ((LCh >= Ord('a')) and (LCh <= Ord('f')))
              or ((LCh >= Ord('A')) and (LCh <= Ord('F')))) then Break;
        8: if not ((LCh >= Ord('0')) and (LCh <= Ord('7'))) then Break;
        2: if not ((LCh = Ord('0')) or (LCh = Ord('1'))) then Break;
      end;
      LPrevUnderscore := False;
      if LBufLen >= 126 then
        Exit(SetError('number too long', 15));
      LBuf[LBufLen] := Src[Pos];
      Inc(LBufLen);
      Inc(LDigitCount);
      Inc(Pos); Inc(Col);
    end;
    if LPrevUnderscore and (LDigitCount > 0) then
      Exit(SetError('trailing underscore in number', 29));
    if LDigitCount = 0 then
      Exit(SetError('invalid number', 14));
    // Parse as UInt64
    LUIntVal := 0;
    LI := 0;
    if LBuf[0] = '-' then LI := 1;
    while LI < SizeUInt(LBufLen) do
    begin
      LCh := Byte(LBuf[LI]);
      case LBase of
        16:
        begin
          if LUIntVal > (High(UInt64) shr 4) then
            Exit(SetError('integer overflow', 16));
          LUIntVal := LUIntVal * 16;
          if (LCh >= Ord('0')) and (LCh <= Ord('9')) then
            LUIntVal := LUIntVal + (LCh - Ord('0'))
          else if (LCh >= Ord('a')) and (LCh <= Ord('f')) then
            LUIntVal := LUIntVal + (LCh - Ord('a') + 10)
          else
            LUIntVal := LUIntVal + (LCh - Ord('A') + 10);
        end;
        8:
        begin
          if LUIntVal > (High(UInt64) shr 3) then
            Exit(SetError('integer overflow', 16));
          LUIntVal := LUIntVal * 8 + (LCh - Ord('0'));
        end;
        2:
        begin
          if LUIntVal > (High(UInt64) shr 1) then
            Exit(SetError('integer overflow', 16));
          LUIntVal := LUIntVal * 2 + (LCh - Ord('0'));
        end;
      end;
      Inc(LI);
    end;
    ANodeIdx := Doc^.AddNode;
    Doc^.FNodes[ANodeIdx].Kind := tnkInt;
    Doc^.FNodes[ANodeIdx].IntVal := Int64(LUIntVal);
    Exit(True);
  end;

  // Decimal number — strict TOML lexical rules
  LPrevUnderscore := True; // reject leading underscore
  LDigitCount := 0;
  while Pos < SrcLen do
  begin
    LCh := Byte(Src[Pos]);
    if LCh = Ord('_') then
    begin
      if LPrevUnderscore then
        Exit(SetError('invalid underscore in number', 28));
      LPrevUnderscore := True;
      Inc(Pos); Inc(Col);
      Continue;
    end;
    LPrevUnderscore := False;
    if LCh = Ord('.') then
    begin
      if LHasDot or LHasExp then Break;
      if LDigitCount = 0 then
        Exit(SetError('no digits before dot', 20));
      LHasDot := True;
      LDigitCount := 0; // reset for post-dot digits
    end
    else if (LCh = Ord('e')) or (LCh = Ord('E')) then
    begin
      if LHasExp then Break;
      if LDigitCount = 0 then
        Exit(SetError('no digits before exponent', 25));
      LHasExp := True;
      LDigitCount := 0; // reset for exponent digits
    end
    else if (LCh = Ord('+')) or (LCh = Ord('-')) then
    begin
      if (LBufLen = 0) or ((LBuf[LBufLen-1] <> 'e') and (LBuf[LBufLen-1] <> 'E')) then
        Break;
    end
    else if not IsDigitChar(LCh) then
      Break
    else
      Inc(LDigitCount);
    if LBufLen >= 126 then
      Exit(SetError('number too long', 15));
    LBuf[LBufLen] := Src[Pos];
    Inc(LBufLen);
    Inc(Pos); Inc(Col);
  end;

  // Trailing underscore check
  if LPrevUnderscore and (LBufLen > (Ord(LNeg) and 1)) then
    Exit(SetError('trailing underscore in number', 29));

  if (LNeg and (LBufLen <= 1)) or ((not LNeg) and (LBufLen = 0)) then
    Exit(SetError('invalid number', 14));

  // Validate: no trailing dot, no trailing exponent sign, no leading zeros
  if LHasDot and (LDigitCount = 0) then
    Exit(SetError('no digits after dot', 19));
  if LHasExp and (LDigitCount = 0) then
    Exit(SetError('no digits after exponent', 24));

  // Leading zero check for integers (0 alone is fine, 01 is not)
  if (not LHasDot) and (not LHasExp) then
  begin
    LI := 0;
    if LBuf[0] = '-' then LI := 1;
    if (LI < SizeUInt(LBufLen)) and (LBuf[LI] = '0') and (SizeUInt(LBufLen) - LI > 1) then
      Exit(SetError('leading zeros not allowed', 25));
  end;

  ANodeIdx := Doc^.AddNode;
  if LHasDot or LHasExp then
  begin
    if not ParseDouble(@LBuf[0], SizeUInt(LBufLen), LFloatVal) then
      Exit(SetError('invalid float', 13));
    Doc^.FNodes[ANodeIdx].Kind := tnkFloat;
    Doc^.FNodes[ANodeIdx].FloatVal := LFloatVal;
  end
  else
  begin
    if not ParseInt64(@LBuf[0], SizeUInt(LBufLen), LIntVal) then
      Exit(SetError('invalid integer', 15));
    Doc^.FNodes[ANodeIdx].Kind := tnkInt;
    Doc^.FNodes[ANodeIdx].IntVal := LIntVal;
  end;
  Result := True;
end;

function TTomlParser.ParseBool(out ANodeIdx: UInt32): Boolean;
begin
  if (Pos + 4 <= SrcLen) and (Src[Pos] = 't') and (Src[Pos+1] = 'r')
    and (Src[Pos+2] = 'u') and (Src[Pos+3] = 'e') then
  begin
    Inc(Pos, 4); Col := Col + 4;
    ANodeIdx := Doc^.AddNode;
    Doc^.FNodes[ANodeIdx].Kind := tnkBool;
    Doc^.FNodes[ANodeIdx].BoolVal := True;
    Exit(True);
  end;
  if (Pos + 5 <= SrcLen) and (Src[Pos] = 'f') and (Src[Pos+1] = 'a')
    and (Src[Pos+2] = 'l') and (Src[Pos+3] = 's') and (Src[Pos+4] = 'e') then
  begin
    Inc(Pos, 5); Col := Col + 5;
    ANodeIdx := Doc^.AddNode;
    Doc^.FNodes[ANodeIdx].Kind := tnkBool;
    Doc^.FNodes[ANodeIdx].BoolVal := False;
    Exit(True);
  end;
  Result := SetError('invalid value', 13);
end;

function TTomlParser.ParseDateTime(out ANodeIdx: UInt32; const AStart: PAnsiChar; ALen: SizeUInt): Boolean;
var
  LDT: TTomlDateTime;
  LP: SizeUInt;
  LYear: Int64;
  LMonth, LDay, LHour, LMin, LSec: Int64;
  LNano: UInt32;
  LOffMin: Int16;
  LHasDate, LHasTime, LHasOffset: Boolean;
  LFracLen: Int32;
  LFrac: Int64;
  LOffH, LOffM: Int64;
  LOffNeg: Boolean;
begin
  FillChar(LDT, SizeOf(LDT), 0);
  LP := 0;
  LHasDate := False;
  LHasTime := False;
  LHasOffset := False;
  LNano := 0;
  LOffMin := 0;

  // Try date: YYYY-MM-DD
  if (ALen >= 10) and (AStart[4] = '-') and (AStart[7] = '-') then
  begin
    if not ParseInt64(AStart, 4, LYear) then Exit(SetError('invalid year', 12));
    if not ParseInt64(AStart + 5, 2, LMonth) then Exit(SetError('invalid month', 13));
    if not ParseInt64(AStart + 8, 2, LDay) then Exit(SetError('invalid day', 11));
    LDT.Year := UInt16(LYear);
    LDT.Month := Byte(LMonth);
    LDT.Day := Byte(LDay);
    LHasDate := True;
    LP := 10;
    // Check for T or space separator
    if (LP < ALen) and ((AStart[LP] = 'T') or (AStart[LP] = 't') or (AStart[LP] = ' ')) then
    begin
      Inc(LP);
      LHasTime := True;
    end;
  end
  else
    LHasTime := True; // time-only

  // Parse time: HH:MM:SS[.fraction]
  if LHasTime then
  begin
    if LP + 8 > ALen then Exit(SetError('invalid time', 12));
    if (AStart[LP+2] <> ':') or (AStart[LP+5] <> ':') then
      Exit(SetError('invalid time format', 19));
    if not ParseInt64(AStart + LP, 2, LHour) then Exit(SetError('invalid hour', 12));
    if not ParseInt64(AStart + LP + 3, 2, LMin) then Exit(SetError('invalid minute', 14));
    if not ParseInt64(AStart + LP + 6, 2, LSec) then Exit(SetError('invalid second', 14));
    LDT.Hour := Byte(LHour);
    LDT.Minute := Byte(LMin);
    LDT.Second := Byte(LSec);
    Inc(LP, 8);
    // Fractional seconds
    if (LP < ALen) and (AStart[LP] = '.') then
    begin
      Inc(LP);
      LFracLen := 0;
      LFrac := 0;
      while (LP < ALen) and IsDigitChar(Byte(AStart[LP])) do
      begin
        if LFracLen < 9 then
          LFrac := LFrac * 10 + (Byte(AStart[LP]) - Ord('0'));
        Inc(LFracLen);
        Inc(LP);
      end;
      while LFracLen < 9 do begin LFrac := LFrac * 10; Inc(LFracLen); end;
      LNano := UInt32(LFrac);
    end;
    LDT.Nanosecond := LNano;
    // Offset
    if LP < ALen then
    begin
      if (AStart[LP] = 'Z') or (AStart[LP] = 'z') then
      begin
        LHasOffset := True;
        LOffMin := 0;
        Inc(LP);
      end
      else if (AStart[LP] = '+') or (AStart[LP] = '-') then
      begin
        LOffNeg := AStart[LP] = '-';
        Inc(LP);
        if LP + 5 > ALen then Exit(SetError('invalid offset', 14));
        if AStart[LP+2] <> ':' then Exit(SetError('invalid offset format', 21));
        if not ParseInt64(AStart + LP, 2, LOffH) then Exit(SetError('invalid offset hour', 19));
        if not ParseInt64(AStart + LP + 3, 2, LOffM) then Exit(SetError('invalid offset minute', 21));
        LOffMin := Int16(LOffH * 60 + LOffM);
        if LOffNeg then LOffMin := -LOffMin;
        LHasOffset := True;
        Inc(LP, 5);
      end;
    end;
  end;

  LDT.OffsetMinutes := LOffMin;

  // Verify complete consumption
  if LP <> ALen then
    Exit(SetError('trailing content in datetime', 28));

  // Range validation
  if LHasDate then
  begin
    if (LDT.Month < 1) or (LDT.Month > 12) then
      Exit(SetError('month out of range', 18));
    if (LDT.Day < 1) or (LDT.Day > 31) then
      Exit(SetError('day out of range', 16));
  end;
  if LHasTime then
  begin
    if LDT.Hour > 23 then
      Exit(SetError('hour out of range', 17));
    if LDT.Minute > 59 then
      Exit(SetError('minute out of range', 19));
    if LDT.Second > 60 then
      Exit(SetError('second out of range', 19));
  end;
  if LHasOffset and (Abs(LOffMin) > 1439) then
    Exit(SetError('offset out of range', 19));

  LDT.Flags := 0;
  if LHasDate then LDT.Flags := LDT.Flags or TOML_DT_FLAG_HAS_DATE;
  if LHasTime then LDT.Flags := LDT.Flags or TOML_DT_FLAG_HAS_TIME;
  if LHasOffset then LDT.Flags := LDT.Flags or TOML_DT_FLAG_HAS_OFFSET;
  if LHasDate and LHasTime and LHasOffset then
    LDT.Flags := LDT.Flags or (Byte(Ord(tdkOffsetDateTime)) shl TOML_DT_KIND_SHIFT)
  else if LHasDate and LHasTime then
    LDT.Flags := LDT.Flags or (Byte(Ord(tdkLocalDateTime)) shl TOML_DT_KIND_SHIFT)
  else if LHasDate then
    LDT.Flags := LDT.Flags or (Byte(Ord(tdkLocalDate)) shl TOML_DT_KIND_SHIFT)
  else
    LDT.Flags := LDT.Flags or (Byte(Ord(tdkLocalTime)) shl TOML_DT_KIND_SHIFT);

  ANodeIdx := Doc^.AddNode;
  Doc^.FNodes[ANodeIdx].Kind := tnkDateTime;
  Doc^.FNodes[ANodeIdx].DT := LDT;
  Result := True;
end;

function TTomlParser.ParseArray(out ANodeIdx: UInt32): Boolean;
var
  LArrayIdx, LChildIdx, LPrevIdx: UInt32;
  LCount: UInt32;
begin
  Inc(Depth);
  if Depth > MAX_NESTING_DEPTH then
    Exit(SetError('max nesting depth exceeded', 26));
  Advance; // skip [
  ANodeIdx := Doc^.AddNode;
  Doc^.FNodes[ANodeIdx].Kind := tnkArray;
  Doc^.FNodes[ANodeIdx].Container.FirstChild := TOML_NODE_NONE;
  Doc^.FNodes[ANodeIdx].Container.LastChild := TOML_NODE_NONE;
  Doc^.FNodes[ANodeIdx].Container.Count := 0;
  LArrayIdx := ANodeIdx;
  LCount := 0;
  LPrevIdx := TOML_NODE_NONE;

  SkipWhitespaceAndNewlines;
  if (Pos < SrcLen) and (Src[Pos] = ']') then
  begin
    Advance;
    Exit(True);
  end;

  while True do
  begin
    SkipWhitespaceAndNewlines;
    if not ParseValue(LChildIdx) then Exit(False);
    if LCount = 0 then
      Doc^.FNodes[LArrayIdx].Container.FirstChild := LChildIdx
    else
      Doc^.FNodes[LPrevIdx].Next := LChildIdx;
    LPrevIdx := LChildIdx;
    Inc(LCount);
    SkipWhitespaceAndNewlines;
    if (Pos < SrcLen) and (Src[Pos] = ',') then
    begin
      Advance;
      SkipWhitespaceAndNewlines;
      if (Pos < SrcLen) and (Src[Pos] = ']') then
      begin
        Advance;
        Break;
      end;
    end
    else if (Pos < SrcLen) and (Src[Pos] = ']') then
    begin
      Advance;
      Break;
    end
    else
      Exit(SetError('expected , or ]', 15));
  end;
  Doc^.FNodes[LArrayIdx].Container.Count := LCount;
  Dec(Depth);
  Result := True;
end;

function TTomlParser.ParseInlineTable(out ANodeIdx: UInt32): Boolean;
var
  LTableIdx, LChildIdx: UInt32;
  LCount: UInt32;
  LKey: TStringView;
  LFirst: Boolean;
begin
  Inc(Depth);
  if Depth > MAX_NESTING_DEPTH then
    Exit(SetError('max nesting depth exceeded', 26));
  Advance; // skip {
  ANodeIdx := Doc^.AddNode;
  Doc^.FNodes[ANodeIdx].Kind := tnkTable;
  Doc^.FNodes[ANodeIdx].Flags := TOML_NODE_FLAG_INLINE;
  Doc^.FNodes[ANodeIdx].Container.FirstChild := TOML_NODE_NONE;
  Doc^.FNodes[ANodeIdx].Container.LastChild := TOML_NODE_NONE;
  Doc^.FNodes[ANodeIdx].Container.Count := 0;
  LTableIdx := ANodeIdx;
  LCount := 0;
  LFirst := True;

  SkipWhitespaceInline;
  if (Pos < SrcLen) and (Src[Pos] = '}') then
  begin
    Advance;
    Exit(True);
  end;

  while True do
  begin
    if not LFirst then
    begin
      if (Pos >= SrcLen) or (Src[Pos] <> ',') then
        Exit(SetError('expected , or }', 15));
      Advance;
    end;
    LFirst := False;
    SkipWhitespaceInline;
    if not ParseKey(LKey) then Exit(False);
    SkipWhitespaceInline;
    if (Pos >= SrcLen) or (Src[Pos] <> '=') then
      Exit(SetError('expected =', 10));
    Advance;
    SkipWhitespaceInline;
    if not ParseValue(LChildIdx) then Exit(False);
    Doc^.FNodes[LChildIdx].Key := LKey;
    Doc^.FNodes[LChildIdx].KeyHash := TomlKeyHash(LKey.Data, LKey.Len);
    AddChild(LTableIdx, LChildIdx);
    Inc(LCount);
    SkipWhitespaceInline;
    if (Pos < SrcLen) and (Src[Pos] = '}') then
    begin
      Advance;
      Break;
    end;
  end;
  Doc^.FNodes[LTableIdx].Container.Count := LCount;
  Dec(Depth);
  Result := True;
end;

function TTomlParser.ParseValue(out ANodeIdx: UInt32): Boolean;
var
  LCh: Byte;
  LStart: SizeUInt;
  LLen: SizeUInt;
  LIsDateTime: Boolean;
  LI: SizeUInt;
begin
  if IsEOF then
    Exit(SetError('unexpected end of input', 22));
  LCh := Peek;
  case LCh of
    Ord('"'), Ord(''''): Exit(ParseString(ANodeIdx));
    Ord('['): Exit(ParseArray(ANodeIdx));
    Ord('{'): Exit(ParseInlineTable(ANodeIdx));
    Ord('t'), Ord('f'): Exit(ParseBool(ANodeIdx));
  end;
  // Number or datetime
  // Datetime starts with digit and has pattern YYYY-MM-DD or HH:MM:SS
  LStart := Pos;
  // Scan ahead to determine if this is a datetime
  LIsDateTime := False;
  if IsDigitChar(LCh) then
  begin
    LI := Pos;
    while (LI < SrcLen) and (Byte(Src[LI]) > 32) and (Src[LI] <> ',')
      and (Src[LI] <> ']') and (Src[LI] <> '}') and (Src[LI] <> '#') do
      Inc(LI);
    LLen := LI - Pos;
    // Heuristic: contains '-' at position 4 (date) or ':' at position 2 (time)
    if (LLen >= 10) and (Src[Pos+4] = '-') then
    begin
      LIsDateTime := True;
      // Check for space-separated time (e.g. "1979-05-27 07:32:00Z")
      if (LI < SrcLen) and (Src[LI] = ' ') and (LI + 1 < SrcLen) and IsDigitChar(Byte(Src[LI+1])) then
      begin
        Inc(LI); // skip space
        while (LI < SrcLen) and (Byte(Src[LI]) > 32) and (Src[LI] <> ',')
          and (Src[LI] <> ']') and (Src[LI] <> '}') and (Src[LI] <> '#') do
          Inc(LI);
        LLen := LI - Pos;
      end;
    end
    else if (LLen >= 8) and (Src[Pos+2] = ':') then
      LIsDateTime := True;
    if LIsDateTime then
    begin
      Pos := LI;
      Col := Col + UInt32(LLen);
      Exit(ParseDateTime(ANodeIdx, Src + LStart, LLen));
    end;
  end;
  // Must be a number (or +inf/-inf/+nan/-nan/inf/nan)
  if (LCh = Ord('+')) or (LCh = Ord('-')) or IsDigitChar(LCh)
    or (LCh = Ord('i')) or (LCh = Ord('n')) then
    Exit(ParseNumber(ANodeIdx));
  Result := SetError('unexpected character', 20);
end;

function TTomlParser.FindChild(ATableIdx: UInt32; const AKey: TStringView): UInt32;
var
  LCur: UInt32;
  LHash: UInt32;
begin
  LHash := TomlKeyHash(AKey.Data, AKey.Len);
  LCur := Doc^.FNodes[ATableIdx].Container.FirstChild;
  while LCur <> TOML_NODE_NONE do
  begin
    if (Doc^.FNodes[LCur].KeyHash = LHash) and Doc^.FNodes[LCur].Key.Equals(AKey) then
      Exit(LCur);
    LCur := Doc^.FNodes[LCur].Next;
  end;
  Result := TOML_NODE_NONE;
end;

procedure TTomlParser.AddChild(ATableIdx: UInt32; AChildIdx: UInt32);
begin
  if Doc^.FNodes[ATableIdx].Container.FirstChild = TOML_NODE_NONE then
  begin
    Doc^.FNodes[ATableIdx].Container.FirstChild := AChildIdx;
    Doc^.FNodes[ATableIdx].Container.LastChild := AChildIdx;
  end
  else
  begin
    Doc^.FNodes[Doc^.FNodes[ATableIdx].Container.LastChild].Next := AChildIdx;
    Doc^.FNodes[ATableIdx].Container.LastChild := AChildIdx;
  end;
end;

function TTomlParser.FindOrCreateTable(AParent: UInt32; const AKey: TStringView;
  AImplicit: Boolean): UInt32;
var
  LExisting, LNewIdx: UInt32;
begin
  LExisting := FindChild(AParent, AKey);
  if LExisting <> TOML_NODE_NONE then
  begin
    if Doc^.FNodes[LExisting].Kind = tnkTable then
    begin
      if (Doc^.FNodes[LExisting].Flags and TOML_NODE_FLAG_INLINE) <> 0 then
        Exit(TOML_NODE_NONE); // cannot extend inline table
      if (not AImplicit) and ((Doc^.FNodes[LExisting].Flags and TOML_NODE_FLAG_EXPLICIT) <> 0) then
        Exit(TOML_NODE_NONE); // duplicate explicit table
      if not AImplicit then
        Doc^.FNodes[LExisting].Flags := Doc^.FNodes[LExisting].Flags or TOML_NODE_FLAG_EXPLICIT;
      Exit(LExisting);
    end;
    if Doc^.FNodes[LExisting].Kind = tnkArray then
    begin
      LExisting := Doc^.FNodes[LExisting].Container.LastChild;
      Exit(LExisting);
    end;
    Exit(TOML_NODE_NONE);
  end;
  LNewIdx := Doc^.AddNode;
  Doc^.FNodes[LNewIdx].Kind := tnkTable;
  if not AImplicit then
    Doc^.FNodes[LNewIdx].Flags := TOML_NODE_FLAG_EXPLICIT;
  Doc^.FNodes[LNewIdx].Key := AKey;
  Doc^.FNodes[LNewIdx].KeyHash := TomlKeyHash(AKey.Data, AKey.Len);
  Doc^.FNodes[LNewIdx].Container.FirstChild := TOML_NODE_NONE;
  Doc^.FNodes[LNewIdx].Container.LastChild := TOML_NODE_NONE;
  Doc^.FNodes[LNewIdx].Container.Count := 0;
  AddChild(AParent, LNewIdx);
  Inc(Doc^.FNodes[AParent].Container.Count);
  Result := LNewIdx;
end;

function TTomlParser.ParseKeyValue(ATableIdx: UInt32): Boolean;
var
  LKeys: array[0..31] of TStringView;
  LKeyCount: Int32;
  LValueIdx, LTargetTable: UInt32;
  LI: Int32;
  LExisting: UInt32;
begin
  if not ParseDottedKey(LKeys, LKeyCount) then Exit(False);
  SkipWhitespaceInline;
  if (Pos >= SrcLen) or (Src[Pos] <> '=') then
    Exit(SetError('expected =', 10));
  Advance;
  SkipWhitespaceInline;
  if not ParseValue(LValueIdx) then Exit(False);

  // Navigate/create intermediate tables for dotted keys
  LTargetTable := ATableIdx;
  for LI := 0 to LKeyCount - 2 do
  begin
    LTargetTable := FindOrCreateTable(LTargetTable, LKeys[LI], True);
    if LTargetTable = TOML_NODE_NONE then
      Exit(SetError('key conflict', 12));
  end;

  // Check for duplicate key
  LExisting := FindChild(LTargetTable, LKeys[LKeyCount - 1]);
  if LExisting <> TOML_NODE_NONE then
    Exit(SetError('duplicate key', 13));

  Doc^.FNodes[LValueIdx].Key := LKeys[LKeyCount - 1];
  Doc^.FNodes[LValueIdx].KeyHash := TomlKeyHash(LKeys[LKeyCount - 1].Data, LKeys[LKeyCount - 1].Len);
  AddChild(LTargetTable, LValueIdx);
  Inc(Doc^.FNodes[LTargetTable].Container.Count);
  Result := True;
end;

function TTomlParser.ParseTableHeader(out AIsArray: Boolean): Boolean;
var
  LKeys: array[0..31] of TStringView;
  LKeyCount: Int32;
  LI: Int32;
  LCurrent, LNewIdx, LArrayIdx: UInt32;
begin
  Advance; // skip first [
  AIsArray := (Pos < SrcLen) and (Src[Pos] = '[');
  if AIsArray then Advance; // skip second [

  SkipWhitespaceInline;
  if not ParseDottedKey(LKeys, LKeyCount) then Exit(False);
  SkipWhitespaceInline;

  if AIsArray then
  begin
    if (Pos + 1 >= SrcLen) or (Src[Pos] <> ']') or (Src[Pos+1] <> ']') then
      Exit(SetError('expected ]]', 11));
    AdvanceN(2);
  end
  else
  begin
    if (Pos >= SrcLen) or (Src[Pos] <> ']') then
      Exit(SetError('expected ]', 10));
    Advance;
  end;

  // Navigate to target table from root
  LCurrent := 0; // root
  for LI := 0 to LKeyCount - 2 do
  begin
    LCurrent := FindOrCreateTable(LCurrent, LKeys[LI], True);
    if LCurrent = TOML_NODE_NONE then
      Exit(SetError('table path conflict', 19));
  end;

  if AIsArray then
  begin
    // Find or create array, then append new table element
    LArrayIdx := FindChild(LCurrent, LKeys[LKeyCount - 1]);
    if LArrayIdx = TOML_NODE_NONE then
    begin
      // Create array node
      LArrayIdx := Doc^.AddNode;
      Doc^.FNodes[LArrayIdx].Kind := tnkArray;
      Doc^.FNodes[LArrayIdx].Key := LKeys[LKeyCount - 1];
      Doc^.FNodes[LArrayIdx].KeyHash := TomlKeyHash(LKeys[LKeyCount - 1].Data, LKeys[LKeyCount - 1].Len);
      Doc^.FNodes[LArrayIdx].Container.FirstChild := TOML_NODE_NONE;
      Doc^.FNodes[LArrayIdx].Container.LastChild := TOML_NODE_NONE;
      Doc^.FNodes[LArrayIdx].Container.Count := 0;
      AddChild(LCurrent, LArrayIdx);
      Inc(Doc^.FNodes[LCurrent].Container.Count);
    end
    else if Doc^.FNodes[LArrayIdx].Kind <> tnkArray then
      Exit(SetError('not an array table', 18));
    // Add new table element to array
    LNewIdx := Doc^.AddNode;
    Doc^.FNodes[LNewIdx].Kind := tnkTable;
    Doc^.FNodes[LNewIdx].Container.FirstChild := TOML_NODE_NONE;
    Doc^.FNodes[LNewIdx].Container.LastChild := TOML_NODE_NONE;
    Doc^.FNodes[LNewIdx].Container.Count := 0;
    AddChild(LArrayIdx, LNewIdx);
    Inc(Doc^.FNodes[LArrayIdx].Container.Count);
    // ParseKeyValue will target this new table — store in a way the main loop can find it
    Doc^.FCurrentTable := LNewIdx;
  end
  else
  begin
    LCurrent := FindOrCreateTable(LCurrent, LKeys[LKeyCount - 1], False);
    if LCurrent = TOML_NODE_NONE then
      Exit(SetError('table redefinition', 18));
    Doc^.FCurrentTable := LCurrent;
  end;
  Result := True;
end;

{ Main Parse }

function TTomlDocument.Parse(const AInput: TStringView): Boolean;
var
  LP: TTomlParser;
  LCurrentTable: UInt32;
  LRootIdx: UInt32;
  LIsArray: Boolean;
begin
  FInput := AInput;
  FNodeCount := 0;
  FHasError := False;
  FillChar(FError, SizeOf(FError), 0);

  LP.Doc := @Self;
  LP.Src := AInput.Data;
  LP.SrcLen := AInput.Len;
  LP.Pos := 0;
  LP.Line := 1;
  LP.Col := 1;
  LP.Depth := 0;

  // Create root table
  LRootIdx := AddNode;
  FNodes[LRootIdx].Kind := tnkTable;
  FNodes[LRootIdx].Key := TStringView.Empty;
  FNodes[LRootIdx].Container.FirstChild := TOML_NODE_NONE;
  FNodes[LRootIdx].Container.LastChild := TOML_NODE_NONE;
  FNodes[LRootIdx].Container.Count := 0;
  LCurrentTable := LRootIdx;

  LP.SkipWhitespaceAndNewlines;
  while not LP.IsEOF do
  begin
    if LP.Peek = Ord('[') then
    begin
      if not LP.ParseTableHeader(LIsArray) then
        Exit(False);
      LCurrentTable := FCurrentTable;
    end
    else if IsBareKeyChar(LP.Peek) or (LP.Peek = Ord('"')) or (LP.Peek = Ord('''')) then
    begin
      if not LP.ParseKeyValue(LCurrentTable) then
        Exit(False);
    end
    else
    begin
      LP.SetError('unexpected character', 20);
      Exit(False);
    end;
    LP.SkipWhitespaceInline;
    if (not LP.IsEOF) and (LP.Peek = Ord('#')) then
      LP.SkipComment;
    if (not LP.IsEOF) and (LP.Peek <> Ord(#10)) and (LP.Peek <> Ord(#13)) then
    begin
      LP.SetError('expected newline', 16);
      Exit(False);
    end;
    LP.SkipWhitespaceAndNewlines;
  end;
  Result := True;
end;

end.
