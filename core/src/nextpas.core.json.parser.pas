unit nextpas.core.json.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.json.types;

type
  TJsonObjectIndex = record
    Slots: PUInt32;
    Mask: UInt32;
  end;
  PJsonObjectIndex = ^TJsonObjectIndex;

  TJsonDocument = record
  private
    FNodes: PJsonNode;
    FNodeCount: UInt32;
    FNodeCap: UInt32;
    FAllocator: IAllocator;
    FStrArena: PAnsiChar;
    FStrArenaUsed: UInt32;
    FStrArenaCap: UInt32;
    FStrOverflow: PPointer;
    FStrOverflowCount: UInt32;
    FStrOverflowCap: UInt32;
    FInput: TStringView;
    FError: TJsonError;
    FHasError: Boolean;
    FIndices: PJsonObjectIndex;
    FIndexCap: UInt32;
    FCombinedAlloc: Boolean;
    function AddNode: UInt32;
    function AllocStrBuf(ASize: SizeUInt): PAnsiChar;
  public
    procedure Init(const AAllocator: IAllocator);
    procedure Done;
    function Parse(const AInput: TStringView): Boolean;
    function Root: UInt32; inline;
    function Node(const AIdx: UInt32): PJsonNode; inline;
    function NodeCount: UInt32; inline;
    function HasError: Boolean; inline;
    function Error: TJsonError; inline;
    function Input: TStringView; inline;
    procedure EnsureObjectIndex(AObjectIdx: UInt32);
    function LookupObjectIndex(AObjectIdx: UInt32; const AKey: TStringView): UInt32;
  end;

function JsonParseDoc(const AInput: TStringView;
  const AAllocator: IAllocator): TJsonDocument;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec,
  nextpas.core.text.scan,
  nextpas.core.text.escape,
  nextpas.core.text.number,
  nextpas.core.hash.wyhash,
  nextpas.core.json.scanner,
  nextpas.core.mem.default;

const
  INITIAL_NODE_CAP = 32;
  INITIAL_ARENA_CAP = 1024;
  POS_NONE = UInt32($FFFFFFFF);

procedure TJsonDocument.Init(const AAllocator: IAllocator);
var
  LNodeSize, LTotalSize: SizeUInt;
  LBase: PAnsiChar;
begin
  if AAllocator <> nil then
    FAllocator := AAllocator
  else
    FAllocator := DefaultAllocator;
  FNodeCap := INITIAL_NODE_CAP;
  LNodeSize := FNodeCap * SizeOf(TJsonNode);
  FStrArenaCap := INITIAL_ARENA_CAP;
  LTotalSize := LNodeSize + FStrArenaCap;
  LBase := FAllocator.Allocate(LTotalSize);
  FNodes := PJsonNode(LBase);
  FStrArena := LBase + LNodeSize;
  FNodeCount := 0;
  FStrArenaUsed := 0;
  FStrOverflowCap := 0;
  FStrOverflow := nil;
  FStrOverflowCount := 0;
  FHasError := False;
  FIndices := nil;
  FIndexCap := 0;
  FCombinedAlloc := True;
end;

procedure TJsonDocument.Done;
var
  I: UInt32;
begin
  if FIndices <> nil then
  begin
    for I := 0 to FIndexCap - 1 do
      if FIndices[I].Slots <> nil then
        FAllocator.Deallocate(FIndices[I].Slots);
    FAllocator.Deallocate(FIndices);
    FIndices := nil;
    FIndexCap := 0;
  end;
  if (FStrOverflow <> nil) and (FStrOverflowCount > 0) then
  begin
    for I := 0 to FStrOverflowCount - 1 do
      FAllocator.Deallocate(PPointer(PByte(FStrOverflow) + I * SizeOf(Pointer))^);
  end;
  if FStrOverflow <> nil then
  begin
    FAllocator.Deallocate(FStrOverflow);
    FStrOverflow := nil;
  end;
  if FCombinedAlloc then
  begin
    if FNodes <> nil then
      FAllocator.Deallocate(FNodes);
    FNodes := nil;
    FStrArena := nil;
  end
  else
  begin
    if FStrArena <> nil then
    begin
      FAllocator.Deallocate(FStrArena);
      FStrArena := nil;
    end;
    if FNodes <> nil then
    begin
      FAllocator.Deallocate(FNodes);
      FNodes := nil;
    end;
  end;
  FNodeCount := 0;
  FNodeCap := 0;
  FStrArenaUsed := 0;
  FStrArenaCap := 0;
  FStrOverflowCount := 0;
end;

function TJsonDocument.AddNode: UInt32;
var
  LNewCap: UInt32;
  LNewNodes: PJsonNode;
  LNewArena: PAnsiChar;
begin
  if FNodeCount >= FNodeCap then
  begin
    LNewCap := FNodeCap * 2;
    if FCombinedAlloc then
    begin
      LNewNodes := FAllocator.Allocate(LNewCap * SizeOf(TJsonNode));
      Move(FNodes^, LNewNodes^, FNodeCap * SizeOf(TJsonNode));
      LNewArena := FAllocator.Allocate(FStrArenaCap);
      if FStrArenaUsed > 0 then
        Move(FStrArena^, LNewArena^, FStrArenaUsed);
      FAllocator.Deallocate(FNodes);
      FNodes := LNewNodes;
      FStrArena := LNewArena;
      FCombinedAlloc := False;
    end
    else
    begin
      FNodes := FAllocator.Reallocate(FNodes, LNewCap * SizeOf(TJsonNode));
    end;
    FNodeCap := LNewCap;
  end;
  Result := FNodeCount;
  FNodes[FNodeCount].Next := JSON_NODE_NONE;
  FNodes[FNodeCount].Flags := 0;
  Inc(FNodeCount);
end;

function TJsonDocument.AllocStrBuf(ASize: SizeUInt): PAnsiChar;
var
  LNewCap: UInt32;
begin
  if FStrArenaUsed + UInt32(ASize) <= FStrArenaCap then
  begin
    Result := FStrArena + FStrArenaUsed;
    Inc(FStrArenaUsed, UInt32(ASize));
    Exit;
  end;
  Result := FAllocator.Allocate(ASize);
  if FStrOverflowCount >= FStrOverflowCap then
  begin
    if FStrOverflowCap = 0 then
      LNewCap := 8
    else
      LNewCap := FStrOverflowCap * 2;
    FStrOverflow := FAllocator.Reallocate(FStrOverflow, LNewCap * SizeOf(Pointer));
    FStrOverflowCap := LNewCap;
  end;
  PPointer(PByte(FStrOverflow) + FStrOverflowCount * SizeOf(Pointer))^ := Result;
  Inc(FStrOverflowCount);
end;

function TJsonDocument.Root: UInt32;
begin
  if FNodeCount > 0 then Result := 0 else Result := JSON_NODE_NONE;
end;

function TJsonDocument.Node(const AIdx: UInt32): PJsonNode;
begin
  Result := @FNodes[AIdx];
end;

function TJsonDocument.NodeCount: UInt32;
begin
  Result := FNodeCount;
end;

function TJsonDocument.HasError: Boolean;
begin
  Result := FHasError;
end;

function TJsonDocument.Error: TJsonError;
begin
  Result := FError;
end;

function TJsonDocument.Input: TStringView;
begin
  Result := FInput;
end;

{ Parser implementation }

type
  TParserState = record
    Doc: ^TJsonDocument;
    Input: PAnsiChar;
    InputLen: SizeUInt;
    Scanner: TJsonStructScanner;
    LastPos: UInt32;
    Depth: Int32;
    function PeekCh: Byte; inline;
    function ConsumeStruct: UInt32; inline;
    function GetValueSlice(out AStart: PAnsiChar; out ALen: SizeUInt): Boolean;
    function SetError(const AMsg: PAnsiChar; ALen: Int32): Boolean;
    function SetErrorAtOffset(const AMsg: PAnsiChar; ALen: Int32;
      AOffset: SizeUInt): Boolean;
    function ParseValue: UInt32;
    function ParseObject: UInt32;
    function ParseArray: UInt32;
    function ParseString: UInt32;
    function ParseNumber(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
    function ParseLiteral(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
    function ParseMatchedLiteral(const AData: PAnsiChar;
      const ALen, AExpectedLen: SizeUInt; const AKind: TJsonNodeKind;
      const ABoolVal: Boolean): UInt32;
  end;

function TParserState.PeekCh: Byte;
begin
  Result := Scanner.PeekChar;
end;

function TParserState.ConsumeStruct: UInt32;
begin
  Result := Scanner.Next;
  if Result <> POS_NONE then
    LastPos := Result;
end;

function TParserState.GetValueSlice(out AStart: PAnsiChar; out ALen: SizeUInt): Boolean;
var
  LNextPos: UInt32;
  LBegin: SizeUInt;
begin
  LNextPos := Scanner.Peek;
  if LNextPos = POS_NONE then
    LNextPos := UInt32(InputLen);
  if LastPos = POS_NONE then
    LBegin := 0
  else
    LBegin := SizeUInt(LastPos + 1);
  while (LBegin < LNextPos) and (Byte(Input[LBegin]) <= 32) do
    Inc(LBegin);
  AStart := Input + LBegin;
  ALen := SizeUInt(LNextPos) - LBegin;
  while (ALen > 0) and (Byte(AStart[ALen - 1]) <= 32) do
    Dec(ALen);
  Result := ALen > 0;
end;

function TParserState.SetError(const AMsg: PAnsiChar; ALen: Int32): Boolean;
var
  LOffset: SizeUInt;
begin
  Doc^.FError.Message := TStringView.Create(AMsg, SizeUInt(ALen));
  if LastPos <> POS_NONE then
    LOffset := SizeUInt(LastPos)
  else
    LOffset := 0;
  JsonErrorSetPosition(Doc^.FError, Doc^.FInput, LOffset);
  Doc^.FHasError := True;
  Result := False;
end;

function TParserState.SetErrorAtOffset(const AMsg: PAnsiChar; ALen: Int32;
  AOffset: SizeUInt): Boolean;
begin
  Doc^.FError.Message := TStringView.Create(AMsg, SizeUInt(ALen));
  JsonErrorSetPosition(Doc^.FError, Doc^.FInput, AOffset);
  Doc^.FHasError := True;
  Result := False;
end;

function SetErrorAtCurrentOffset(var AState: TParserState; const AMsg: PAnsiChar;
  ALen: Int32): Boolean;
var
  LOffset: SizeUInt;
  LNextPos: UInt32;
begin
  LNextPos := AState.Scanner.Peek;
  if LNextPos = POS_NONE then
    LOffset := AState.InputLen
  else
    LOffset := SizeUInt(LNextPos);
  AState.Doc^.FError.Message := TStringView.Create(AMsg, SizeUInt(ALen));
  JsonErrorSetPosition(AState.Doc^.FError, AState.Doc^.FInput, LOffset);
  AState.Doc^.FHasError := True;
  Result := False;
end;

function IsJsonWhitespace(const ACh: Byte): Boolean; inline;
begin
  Result := (ACh = 32) or (ACh = 9) or (ACh = 10) or (ACh = 13);
end;

function TParserState.ParseMatchedLiteral(const AData: PAnsiChar;
  const ALen, AExpectedLen: SizeUInt; const AKind: TJsonNodeKind;
  const ABoolVal: Boolean): UInt32;
var
  LIdx: UInt32;
begin
  if (ALen > AExpectedLen) and
    (not IsJsonWhitespace(Byte(AData[AExpectedLen]))) then
    Exit(JSON_NODE_NONE);

  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := AKind;
  if AKind = jnkBool then
    Doc^.FNodes[LIdx].BoolVal := ABoolVal;
  LastPos := UInt32((AData - Input) + AExpectedLen - 1);
  Result := LIdx;
end;

function ValidateJsonParserEscapes(var AState: TParserState;
  const AStr: TStringView; const AContentOffset, AStart: SizeUInt): Boolean;
var
  LError: TJsonStringValidationError;
  LErrorOffset: SizeUInt;
begin
  if JsonValidateStringToken(AStr.Data + AStart, AStr.Len - AStart, LError,
    LErrorOffset) then
    Exit(True);
  case LError of
    jsveControlChar:
      AState.SetErrorAtOffset('control char in string', 22,
        AContentOffset + AStart + LErrorOffset);
  else
    AState.SetErrorAtOffset('invalid escape sequence', 23,
      AContentOffset + AStart + LErrorOffset);
  end;
  Result := False;
end;

function TParserState.ParseString: UInt32;
var
  LStartPos, LEndPos: UInt32;
  LIdx: UInt32;
  LRaw: TStringView;
  LHasEscape: Boolean;
  LBuf: PAnsiChar;
  LDecLen: SizeUInt;
  LErr: TUnescapeError;
  I: SizeUInt;
  LMask, LControlMask, LEscapeMask: TVecMask;
  LFirst: Int32;
begin
  LStartPos := ConsumeStruct;
  LEndPos := ConsumeStruct;
  if (LEndPos = POS_NONE) or (Input[LEndPos] <> '"') then
  begin
    SetError('unterminated string', 19);
    Exit(JSON_NODE_NONE);
  end;
  if LEndPos <= LStartPos then
  begin
    SetError('invalid string bounds', 21);
    Exit(JSON_NODE_NONE);
  end;
  LRaw := TStringView.Create(Input + LStartPos + 1, LEndPos - LStartPos - 1);
  LHasEscape := False;
  I := 0;
  while I + VecWidth <= LRaw.Len do
  begin
    LControlMask := VecCmpLtU(@LRaw.Data[I], $20);
    LEscapeMask := VecCmpEq(@LRaw.Data[I], Ord('\'));
    LMask := LControlMask or LEscapeMask;
    if LMask <> TVecMask(0) then
    begin
      LFirst := VecCtz(LMask);
      Inc(I, SizeUInt(LFirst));
      if (LControlMask and (TVecMask(1) shl LFirst)) <> TVecMask(0) then
      begin
        SetErrorAtOffset('control char in string', 22,
          SizeUInt(LStartPos) + 1 + I);
        Exit(JSON_NODE_NONE);
      end;
      LHasEscape := True;
      Break;
    end;
    Inc(I, VecWidth);
  end;
  if not LHasEscape then
    while I < LRaw.Len do
  begin
    if Byte(LRaw.Data[I]) < $20 then
    begin
      SetErrorAtOffset('control char in string', 22,
        SizeUInt(LStartPos) + 1 + I);
      Exit(JSON_NODE_NONE);
    end;
    if LRaw.Data[I] = '\' then
      begin
        LHasEscape := True;
        Break;
    end;
    Inc(I);
  end;
  if LHasEscape and
    (not ValidateJsonParserEscapes(Self, LRaw, SizeUInt(LStartPos) + 1, I)) then
    Exit(JSON_NODE_NONE);
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkString;
  if LHasEscape then
  begin
    LBuf := Doc^.AllocStrBuf(LRaw.Len);
    LDecLen := JsonUnescapeToBuffer(LRaw.Data, LRaw.Len, LBuf, LErr);
    if LErr <> ueNone then
    begin
      SetError('invalid escape sequence', 23);
      Exit(JSON_NODE_NONE);
    end;
    Doc^.FNodes[LIdx].Str := TStringView.Create(LBuf, LDecLen);
  end
  else
  begin
    Doc^.FNodes[LIdx].Str := LRaw;
    Doc^.FNodes[LIdx].Flags := JNF_CLEAN_STR;
  end;
  Result := LIdx;
end;

function TParserState.ParseNumber(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
var
  LNumLen: SizeUInt;
  LNumberOffset: SizeUInt;
  LIdx: UInt32;
  LHasDot, LHasExp: Boolean;
  I: SizeUInt;
  LInt: Int64;
  LFloat: Double;
begin
  LNumLen := ALen;
  LNumberOffset := SizeUInt(AData - Input);
  if LNumLen = 0 then
  begin
    SetErrorAtOffset('invalid number', 14, LNumberOffset);
    Exit(JSON_NODE_NONE);
  end;
  if (ScanJsonNumber(AData, LNumLen) <> LNumLen) or
     (not ScanIsJsonNumberToken(AData, LNumLen)) then
  begin
    if ScanJsonNumberHasIncompleteExponent(AData, LNumLen) then
      SetErrorAtOffset('invalid number', 14, LNumberOffset + LNumLen)
    else
      SetErrorAtOffset('invalid number', 14, LNumberOffset);
    Exit(JSON_NODE_NONE);
  end;
  LHasDot := False;
  LHasExp := False;
  for I := 0 to LNumLen - 1 do
  begin
    if AData[I] = '.' then begin LHasDot := True; Break; end;
    if (AData[I] = 'e') or (AData[I] = 'E') then begin LHasExp := True; Break; end;
  end;
  if LHasDot or LHasExp then
  begin
    if not ParseDouble(AData, LNumLen, LFloat) then
    begin
      SetErrorAtOffset('number overflow', 15, LNumberOffset);
      Exit(JSON_NODE_NONE);
    end;
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkReal;
    Doc^.FNodes[LIdx].RealVal := LFloat;
  end
  else
  begin
    if not ParseInt64(AData, LNumLen, LInt) then
    begin
      SetErrorAtOffset('number overflow', 15, LNumberOffset);
      Exit(JSON_NODE_NONE);
    end;
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkInt;
    Doc^.FNodes[LIdx].IntVal := LInt;
  end;
  LastPos := UInt32((AData - Input) + LNumLen - 1);
  Result := LIdx;
end;

function TParserState.ParseLiteral(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
begin
  if (ALen >= 4) and (AData[0] = 't') and (AData[1] = 'r') and
    (AData[2] = 'u') and (AData[3] = 'e') then
  begin
    Result := ParseMatchedLiteral(AData, ALen, 4, jnkBool, True);
    if Result <> JSON_NODE_NONE then
      Exit;
  end
  else if (ALen >= 5) and (AData[0] = 'f') and (AData[1] = 'a') and
    (AData[2] = 'l') and (AData[3] = 's') and (AData[4] = 'e') then
  begin
    Result := ParseMatchedLiteral(AData, ALen, 5, jnkBool, False);
    if Result <> JSON_NODE_NONE then
      Exit;
  end
  else if (ALen >= 4) and (AData[0] = 'n') and (AData[1] = 'u') and
    (AData[2] = 'l') and (AData[3] = 'l') then
  begin
    Result := ParseMatchedLiteral(AData, ALen, 4, jnkNull, False);
    if Result <> JSON_NODE_NONE then
      Exit;
  end;
  SetErrorAtOffset('invalid literal', 15, SizeUInt(AData - Input));
  Result := JSON_NODE_NONE;
end;

function TParserState.ParseArray: UInt32;
var
  LIdx, LChild, LPrev: UInt32;
  LCount: UInt32;
  LCh: Byte;
  LGapData: PAnsiChar;
  LGapLen: SizeUInt;
begin
  Inc(Depth);
  if Depth > 512 then
  begin
    SetError('max depth exceeded', 18);
    Exit(JSON_NODE_NONE);
  end;
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkArray;
  ConsumeStruct;
  LCount := 0;
  LPrev := JSON_NODE_NONE;
  LCh := PeekCh;
  if LCh = Ord(']') then
  begin
    if not GetValueSlice(LGapData, LGapLen) then
    begin
      ConsumeStruct;
      Doc^.FNodes[LIdx].Container.FirstChild := JSON_NODE_NONE;
      Doc^.FNodes[LIdx].Container.Count := 0;
      Dec(Depth);
      Exit(LIdx);
    end;
  end;
  while True do
  begin
    LChild := ParseValue;
    if LChild = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    if GetValueSlice(LGapData, LGapLen) then
    begin
      SetErrorAtOffset('expected , or ]', 15, SizeUInt(LGapData - Input));
      Exit(JSON_NODE_NONE);
    end;
    if LCount = 0 then
      Doc^.FNodes[LIdx].Container.FirstChild := LChild
    else
      Doc^.FNodes[LPrev].Next := LChild;
    LPrev := LChild;
    Inc(LCount);
    LCh := PeekCh;
    if LCh = Ord(',') then
      ConsumeStruct
    else if LCh = Ord(']') then
    begin
      ConsumeStruct;
      Break;
    end
    else
    begin
      SetErrorAtCurrentOffset(Self, 'expected , or ]', 15);
      Exit(JSON_NODE_NONE);
    end;
  end;
  Doc^.FNodes[LIdx].Container.Count := LCount;
  Dec(Depth);
  Result := LIdx;
end;

function TParserState.ParseObject: UInt32;
var
  LIdx, LKeyIdx, LValIdx, LPrev: UInt32;
  LCount: UInt32;
  LCh: Byte;
  LGapData: PAnsiChar;
  LGapLen: SizeUInt;
begin
  Inc(Depth);
  if Depth > 512 then
  begin
    SetError('max depth exceeded', 18);
    Exit(JSON_NODE_NONE);
  end;
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkObject;
  ConsumeStruct;
  LCount := 0;
  LPrev := JSON_NODE_NONE;
  LCh := PeekCh;
  if LCh = Ord('}') then
  begin
    if GetValueSlice(LGapData, LGapLen) then
    begin
      SetError('unexpected content in object', 28);
      Exit(JSON_NODE_NONE);
    end;
    ConsumeStruct;
    Doc^.FNodes[LIdx].Container.FirstChild := JSON_NODE_NONE;
    Doc^.FNodes[LIdx].Container.Count := 0;
    Dec(Depth);
    Exit(LIdx);
  end;
  while True do
  begin
    if GetValueSlice(LGapData, LGapLen) then
    begin
      SetErrorAtOffset('expected string key', 19, SizeUInt(LGapData - Input));
      Exit(JSON_NODE_NONE);
    end;
    if PeekCh <> Ord('"') then
    begin
      SetErrorAtCurrentOffset(Self, 'expected string key', 19);
      Exit(JSON_NODE_NONE);
    end;
    LKeyIdx := ParseString;
    if LKeyIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    if GetValueSlice(LGapData, LGapLen) then
    begin
      SetErrorAtOffset('expected :', 10, SizeUInt(LGapData - Input));
      Exit(JSON_NODE_NONE);
    end;
    if PeekCh <> Ord(':') then
    begin
      SetErrorAtCurrentOffset(Self, 'expected :', 10);
      Exit(JSON_NODE_NONE);
    end;
    ConsumeStruct;
    LValIdx := ParseValue;
    if LValIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    if GetValueSlice(LGapData, LGapLen) then
    begin
      SetErrorAtOffset('expected , or }', 15, SizeUInt(LGapData - Input));
      Exit(JSON_NODE_NONE);
    end;
    Doc^.FNodes[LKeyIdx].Next := LValIdx;
    if LCount = 0 then
      Doc^.FNodes[LIdx].Container.FirstChild := LKeyIdx
    else
      Doc^.FNodes[LPrev].Next := LKeyIdx;
    LPrev := LValIdx;
    Inc(LCount);
    LCh := PeekCh;
    if LCh = Ord(',') then
      ConsumeStruct
    else if LCh = Ord('}') then
    begin
      ConsumeStruct;
      Break;
    end
    else
    begin
      SetErrorAtCurrentOffset(Self, 'expected , or }', 15);
      Exit(JSON_NODE_NONE);
    end;
  end;
  Doc^.FNodes[LIdx].Container.Count := LCount;
  Dec(Depth);
  Result := LIdx;
end;

function TParserState.ParseValue: UInt32;
var
  LCh: Byte;
  LData: PAnsiChar;
  LLen: SizeUInt;
begin
  if GetValueSlice(LData, LLen) then
  begin
    case LData[0] of
      '-', '0'..'9': Exit(ParseNumber(LData, LLen));
      't', 'f', 'n': Exit(ParseLiteral(LData, LLen));
    else
      SetError('unexpected character', 20);
      Exit(JSON_NODE_NONE);
    end;
  end;
  LCh := PeekCh;
  case LCh of
    Ord('{'): Result := ParseObject;
    Ord('['): Result := ParseArray;
    Ord('"'): Result := ParseString;
  else
    if LCh = 0 then
      SetErrorAtCurrentOffset(Self, 'unexpected end of input', 23)
    else
      SetError('unexpected character', 20);
    Result := JSON_NODE_NONE;
  end;
end;

function TJsonDocument.Parse(const AInput: TStringView): Boolean;
var
  LState: TParserState;
  LEstimate: UInt32;
  I: UInt32;
  LBase: PAnsiChar;
  LTrailingOffset: SizeUInt;
begin
  FInput := AInput;
  FNodeCount := 0;
  FHasError := False;
  FError.Message := TStringView.Create(nil, 0);
  JsonErrorSetPosition(FError, AInput, 0);
  { Clear cached object indices from previous parse }
  if FIndices <> nil then
  begin
    for I := 0 to FIndexCap - 1 do
      if FIndices[I].Slots <> nil then
      begin
        FAllocator.Deallocate(FIndices[I].Slots);
        FIndices[I].Slots := nil;
      end;
    FAllocator.Deallocate(FIndices);
    FIndices := nil;
    FIndexCap := 0;
  end;
  { Free overflow string buffers from previous parse }
  if (FStrOverflow <> nil) and (FStrOverflowCount > 0) then
  begin
    for I := 0 to FStrOverflowCount - 1 do
      FAllocator.Deallocate(PPointer(PByte(FStrOverflow) + I * SizeOf(Pointer))^);
    FStrOverflowCount := 0;
  end;
  FStrArenaUsed := 0;
  LEstimate := UInt32(AInput.Len div 4);
  if LEstimate > FNodeCap then
  begin
    if FCombinedAlloc then
    begin
      LBase := PAnsiChar(FNodes);
      FNodes := FAllocator.Allocate(LEstimate * SizeOf(TJsonNode));
      FStrArena := FAllocator.Allocate(FStrArenaCap);
      FAllocator.Deallocate(LBase);
      FCombinedAlloc := False;
    end
    else
      FNodes := FAllocator.Reallocate(FNodes, LEstimate * SizeOf(TJsonNode));
    FNodeCap := LEstimate;
  end;
  LState.Doc := @Self;
  LState.Input := AInput.Data;
  LState.InputLen := AInput.Len;
  LState.Scanner.Init(AInput.Data, AInput.Len);
  LState.LastPos := POS_NONE;
  LState.Depth := 0;
  if LState.ParseValue = JSON_NODE_NONE then
    Exit(False);
  if not LState.Scanner.IsEmpty then
  begin
    FError.Message := TStringView.Create(PAnsiChar('trailing content'), 16);
    if LState.LastPos = POS_NONE then
      LTrailingOffset := 0
    else
      LTrailingOffset := SizeUInt(LState.LastPos) + 1;
    while (LTrailingOffset < AInput.Len) and (Byte(AInput.Data[LTrailingOffset]) <= 32) do
      Inc(LTrailingOffset);
    JsonErrorSetPosition(FError, AInput, LTrailingOffset);
    FHasError := True;
    Exit(False);
  end;
  if LState.LastPos <> POS_NONE then
  begin
    LState.LastPos := LState.LastPos + 1;
    while (LState.LastPos < UInt32(AInput.Len)) and (Byte(AInput.Data[LState.LastPos]) <= 32) do
      Inc(LState.LastPos);
    if LState.LastPos < UInt32(AInput.Len) then
    begin
      FError.Message := TStringView.Create(PAnsiChar('trailing content'), 16);
      JsonErrorSetPosition(FError, AInput, SizeUInt(LState.LastPos));
      FHasError := True;
      Exit(False);
    end;
  end;
  Result := True;
end;

function JsonParseDoc(const AInput: TStringView;
  const AAllocator: IAllocator): TJsonDocument;
begin
  Result.Init(AAllocator);
  if not Result.Parse(AInput) then
    ;
end;

function NextPow2(V: UInt32): UInt32; inline;
begin
  Dec(V);
  V := V or (V shr 1);
  V := V or (V shr 2);
  V := V or (V shr 4);
  V := V or (V shr 8);
  V := V or (V shr 16);
  Result := V + 1;
end;

procedure TJsonDocument.EnsureObjectIndex(AObjectIdx: UInt32);
var
  LNode: PJsonNode;
  LCap, LSlot: UInt32;
  LCur: UInt32;
  LKeyNode: PJsonNode;
  LExistingKeyIdx: UInt32;
  LH: UInt32;
  LIdx: PJsonObjectIndex;
begin
  if FIndices = nil then
  begin
    FIndexCap := FNodeCount;
    FIndices := FAllocator.Allocate(FIndexCap * SizeOf(TJsonObjectIndex));
    FillChar(FIndices^, FIndexCap * SizeOf(TJsonObjectIndex), 0);
  end;
  if AObjectIdx >= FIndexCap then Exit;
  LIdx := @FIndices[AObjectIdx];
  if LIdx^.Slots <> nil then Exit;

  LNode := @FNodes[AObjectIdx];
  LCap := NextPow2(LNode^.Container.Count * 2);
  if LCap < 8 then LCap := 8;
  LIdx^.Mask := LCap - 1;
  LIdx^.Slots := FAllocator.Allocate(LCap * SizeOf(UInt32));
  FillChar(LIdx^.Slots^, LCap * SizeOf(UInt32), $FF);

  LCur := LNode^.Container.FirstChild;
  while LCur <> JSON_NODE_NONE do
  begin
    LKeyNode := @FNodes[LCur];
    LH := WyHash32(LKeyNode^.Str.Data, LKeyNode^.Str.Len);
    LSlot := LH and LIdx^.Mask;
    while LIdx^.Slots[LSlot] <> JSON_NODE_NONE do
    begin
      LExistingKeyIdx := LIdx^.Slots[LSlot];
      if LKeyNode^.Str.Equals(FNodes[LExistingKeyIdx].Str) then
        Break;
      LSlot := (LSlot + 1) and LIdx^.Mask;
    end;
    LIdx^.Slots[LSlot] := LCur;
    if LKeyNode^.Next <> JSON_NODE_NONE then
      LCur := FNodes[LKeyNode^.Next].Next
    else
      LCur := JSON_NODE_NONE;
  end;
end;

function TJsonDocument.LookupObjectIndex(AObjectIdx: UInt32; const AKey: TStringView): UInt32;
var
  LIdx: PJsonObjectIndex;
  LH, LSlot, LKeyIdx: UInt32;
begin
  if (FIndices = nil) or (AObjectIdx >= FIndexCap) then Exit(JSON_NODE_NONE);
  LIdx := @FIndices[AObjectIdx];
  if LIdx^.Slots = nil then Exit(JSON_NODE_NONE);
  LH := WyHash32(AKey.Data, AKey.Len);
  LSlot := LH and LIdx^.Mask;
  while True do
  begin
    LKeyIdx := LIdx^.Slots[LSlot];
    if LKeyIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    if AKey.Equals(FNodes[LKeyIdx].Str) then Exit(LKeyIdx);
    LSlot := (LSlot + 1) and LIdx^.Mask;
  end;
end;

end.
