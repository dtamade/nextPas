unit nextpas.core.json.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.json.types;

type
  TJsonDocument = record
  private
    FNodes: PJsonNode;
    FNodeCount: UInt32;
    FNodeCap: UInt32;
    FAllocator: IAllocator;
    FStrBufs: PPointer;
    FStrBufCount: UInt32;
    FStrBufCap: UInt32;
    FInput: TStringView;
    FError: TJsonError;
    FHasError: Boolean;
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
  nextpas.core.text.char,
  nextpas.core.json.scanner;

const
  INITIAL_NODE_CAP = 64;
  POS_NONE = UInt32($FFFFFFFF);

procedure TJsonDocument.Init(const AAllocator: IAllocator);
begin
  FAllocator := AAllocator;
  FNodeCap := INITIAL_NODE_CAP;
  FNodes := FAllocator.Allocate(FNodeCap * SizeOf(TJsonNode));
  FNodeCount := 0;
  FStrBufCap := 16;
  FStrBufs := FAllocator.Allocate(FStrBufCap * SizeOf(PAnsiChar));
  FStrBufCount := 0;
  FHasError := False;
end;

procedure TJsonDocument.Done;
var
  I: UInt32;
begin
  if (FStrBufs <> nil) and (FStrBufCount > 0) then
  begin
    for I := 0 to FStrBufCount - 1 do
      FAllocator.Deallocate(PPointer(PByte(FStrBufs) + I * SizeOf(Pointer))^);
  end;
  if FStrBufs <> nil then
  begin
    FAllocator.Deallocate(FStrBufs);
    FStrBufs := nil;
  end;
  if FNodes <> nil then
  begin
    FAllocator.Deallocate(FNodes);
    FNodes := nil;
  end;
  FNodeCount := 0;
  FNodeCap := 0;
  FStrBufCount := 0;
end;

function TJsonDocument.AddNode: UInt32;
var
  LNewCap: UInt32;
begin
  if FNodeCount >= FNodeCap then
  begin
    LNewCap := FNodeCap * 2;
    FNodes := FAllocator.Reallocate(FNodes, LNewCap * SizeOf(TJsonNode));
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
  Result := FAllocator.Allocate(ASize);
  if FStrBufCount >= FStrBufCap then
  begin
    LNewCap := FStrBufCap * 2;
    FStrBufs := FAllocator.Reallocate(FStrBufs, LNewCap * SizeOf(Pointer));
    FStrBufCap := LNewCap;
  end;
  PPointer(PByte(FStrBufs) + FStrBufCount * SizeOf(Pointer))^ := Result;
  Inc(FStrBufCount);
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
    function ParseValue: UInt32;
    function ParseObject: UInt32;
    function ParseArray: UInt32;
    function ParseString: UInt32;
    function ParseNumber(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
    function ParseLiteral(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
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
begin
  Doc^.FError.Message := TStringView.Create(AMsg, SizeUInt(ALen));
  Doc^.FHasError := True;
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
    if VecCmpLtU(@LRaw.Data[I], $20) <> TVecMask(0) then
    begin
      SetError('control char in string', 22);
      Exit(JSON_NODE_NONE);
    end;
    if VecCmpEq(@LRaw.Data[I], Ord('\')) <> TVecMask(0) then
    begin
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
        SetError('control char in string', 22);
        Exit(JSON_NODE_NONE);
      end;
      if LRaw.Data[I] = '\' then
      begin
        LHasEscape := True;
        Break;
      end;
      Inc(I);
    end;
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
  LIdx: UInt32;
  LHasDot, LHasExp: Boolean;
  I: SizeUInt;
  LInt: Int64;
  LFloat: Double;
  LStart: SizeUInt;
begin
  LNumLen := ALen;
  if LNumLen = 0 then
  begin
    SetError('invalid number', 14);
    Exit(JSON_NODE_NONE);
  end;
  if ScanJsonNumber(AData, LNumLen) <> LNumLen then
  begin
    SetError('invalid number', 14);
    Exit(JSON_NODE_NONE);
  end;
  LStart := 0;
  if AData[0] = '-' then LStart := 1;
  if (LStart < LNumLen - 1) and (AData[LStart] = '0') and (AData[LStart+1] >= '0') and (AData[LStart+1] <= '9') then
  begin
    SetError('leading zero', 12);
    Exit(JSON_NODE_NONE);
  end;
  if AData[LNumLen - 1] = '.' then
  begin
    SetError('trailing dot', 12);
    Exit(JSON_NODE_NONE);
  end;
  if (AData[LNumLen - 1] = 'e') or (AData[LNumLen - 1] = 'E') or
     (AData[LNumLen - 1] = '+') or (AData[LNumLen - 1] = '-') then
  begin
    SetError('truncated exponent', 18);
    Exit(JSON_NODE_NONE);
  end;
  LHasDot := False;
  LHasExp := False;
  for I := LStart to LNumLen - 1 do
  begin
    if AData[I] = '.' then begin LHasDot := True; Break; end;
    if (AData[I] = 'e') or (AData[I] = 'E') then begin LHasExp := True; Break; end;
  end;
  LIdx := Doc^.AddNode;
  if LHasDot or LHasExp then
  begin
    ParseDouble(AData, LNumLen, LFloat);
    Doc^.FNodes[LIdx].Kind := jnkReal;
    Doc^.FNodes[LIdx].RealVal := LFloat;
  end
  else
  begin
    if ParseInt64(AData, LNumLen, LInt) then
    begin
      Doc^.FNodes[LIdx].Kind := jnkInt;
      Doc^.FNodes[LIdx].IntVal := LInt;
    end
    else
    begin
      ParseDouble(AData, LNumLen, LFloat);
      Doc^.FNodes[LIdx].Kind := jnkReal;
      Doc^.FNodes[LIdx].RealVal := LFloat;
    end;
  end;
  Result := LIdx;
end;

function TParserState.ParseLiteral(const AData: PAnsiChar; const ALen: SizeUInt): UInt32;
var
  LIdx: UInt32;
begin
  if (ALen = 4) and (AData[0] = 't') and (AData[1] = 'r') and (AData[2] = 'u') and (AData[3] = 'e') then
  begin
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkBool;
    Doc^.FNodes[LIdx].BoolVal := True;
    Exit(LIdx);
  end;
  if (ALen = 5) and (AData[0] = 'f') and (AData[1] = 'a') and (AData[2] = 'l') and (AData[3] = 's') and (AData[4] = 'e') then
  begin
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkBool;
    Doc^.FNodes[LIdx].BoolVal := False;
    Exit(LIdx);
  end;
  if (ALen = 4) and (AData[0] = 'n') and (AData[1] = 'u') and (AData[2] = 'l') and (AData[3] = 'l') then
  begin
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkNull;
    Exit(LIdx);
  end;
  SetError('invalid literal', 15);
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
      SetError('expected , or ]', 15);
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
    if PeekCh <> Ord('"') then
    begin
      SetError('expected string key', 19);
      Exit(JSON_NODE_NONE);
    end;
    LKeyIdx := ParseString;
    if LKeyIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    ConsumeStruct;
    LValIdx := ParseValue;
    if LValIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
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
      SetError('expected , or }', 15);
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
  LCh := PeekCh;
  case LCh of
    Ord('{'): Result := ParseObject;
    Ord('['): Result := ParseArray;
    Ord('"'): Result := ParseString;
  else
    if GetValueSlice(LData, LLen) then
    begin
      case LData[0] of
        '-', '0'..'9': Result := ParseNumber(LData, LLen);
        't', 'f', 'n': Result := ParseLiteral(LData, LLen);
      else
        SetError('unexpected character', 20);
        Result := JSON_NODE_NONE;
      end;
    end
    else
    begin
      if LCh = 0 then
        SetError('unexpected end of input', 22)
      else
        SetError('unexpected character', 20);
      Result := JSON_NODE_NONE;
    end;
  end;
end;

function TJsonDocument.Parse(const AInput: TStringView): Boolean;
var
  LState: TParserState;
  LEstimate: UInt32;
begin
  FInput := AInput;
  FNodeCount := 0;
  FHasError := False;
  LEstimate := UInt32(AInput.Len div 4);
  if LEstimate > FNodeCap then
  begin
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

end.
