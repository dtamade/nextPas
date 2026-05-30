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
    FInput: TStringView;
    FError: TJsonError;
    FHasError: Boolean;
    function AddNode: UInt32;
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
  GetMem(FNodes, FNodeCap * SizeOf(TJsonNode));
  FNodeCount := 0;
  FHasError := False;
end;

procedure TJsonDocument.Done;
begin
  if FNodes <> nil then
  begin
    FreeMem(FNodes);
    FNodes := nil;
  end;
  FNodeCount := 0;
  FNodeCap := 0;
end;

function TJsonDocument.AddNode: UInt32;
var
  LNewCap: UInt32;
begin
  if FNodeCount >= FNodeCap then
  begin
    LNewCap := FNodeCap * 2;
    ReallocMem(FNodes, LNewCap * SizeOf(TJsonNode));
    FNodeCap := LNewCap;
  end;
  Result := FNodeCount;
  FNodes[FNodeCount].Next := JSON_NODE_NONE;
  Inc(FNodeCount);
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
    function ParseNumber: UInt32;
    function ParseLiteral: UInt32;
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
  for I := 0 to LRaw.Len - 1 do
    if LRaw.Data[I] = '\' then
    begin
      LHasEscape := True;
      Break;
    end;
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkString;
  if LHasEscape then
  begin
    LBuf := Doc^.FAllocator.Allocate(LRaw.Len);
    LDecLen := JsonUnescapeToBuffer(LRaw.Data, LRaw.Len, LBuf, LErr);
    Doc^.FNodes[LIdx].Str := TStringView.Create(LBuf, LDecLen);
  end
  else
    Doc^.FNodes[LIdx].Str := LRaw;
  Result := LIdx;
end;

function TParserState.ParseNumber: UInt32;
var
  LData: PAnsiChar;
  LNumLen, LActual: SizeUInt;
  LIdx: UInt32;
  LHasDot, LHasExp: Boolean;
  I: SizeUInt;
  LInt: Int64;
  LFloat: Double;
begin
  if not GetValueSlice(LData, LNumLen) then
  begin
    SetError('invalid number', 14);
    Exit(JSON_NODE_NONE);
  end;
  LActual := ScanJsonNumber(LData, LNumLen);
  if (LActual = 0) or (LActual <> LNumLen) then
  begin
    SetError('invalid number', 14);
    Exit(JSON_NODE_NONE);
  end;
  I := 0;
  if LData[0] = '-' then I := 1;
  if (I < LNumLen - 1) and (LData[I] = '0') and (LData[I+1] >= '0') and (LData[I+1] <= '9') then
  begin
    SetError('leading zero', 12);
    Exit(JSON_NODE_NONE);
  end;
  if LData[LNumLen - 1] = '.' then
  begin
    SetError('trailing dot', 12);
    Exit(JSON_NODE_NONE);
  end;
  if (LData[LNumLen - 1] = 'e') or (LData[LNumLen - 1] = 'E') or
     (LData[LNumLen - 1] = '+') or (LData[LNumLen - 1] = '-') then
  begin
    SetError('truncated exponent', 18);
    Exit(JSON_NODE_NONE);
  end;
  LHasDot := False;
  LHasExp := False;
  for I := 0 to LNumLen - 1 do
  begin
    if LData[I] = '.' then LHasDot := True;
    if (LData[I] = 'e') or (LData[I] = 'E') then LHasExp := True;
  end;
  LIdx := Doc^.AddNode;
  if LHasDot or LHasExp then
  begin
    ParseDouble(LData, LNumLen, LFloat);
    Doc^.FNodes[LIdx].Kind := jnkReal;
    Doc^.FNodes[LIdx].RealVal := LFloat;
  end
  else
  begin
    if ParseInt64(LData, LNumLen, LInt) then
    begin
      Doc^.FNodes[LIdx].Kind := jnkInt;
      Doc^.FNodes[LIdx].IntVal := LInt;
    end
    else
    begin
      ParseDouble(LData, LNumLen, LFloat);
      Doc^.FNodes[LIdx].Kind := jnkReal;
      Doc^.FNodes[LIdx].RealVal := LFloat;
    end;
  end;
  Result := LIdx;
end;

function TParserState.ParseLiteral: UInt32;
var
  LData: PAnsiChar;
  LLen: SizeUInt;
  LIdx: UInt32;
begin
  if not GetValueSlice(LData, LLen) then
  begin
    SetError('invalid literal', 15);
    Exit(JSON_NODE_NONE);
  end;
  if (LLen = 4) and (LData[0] = 't') and (LData[1] = 'r') and (LData[2] = 'u') and (LData[3] = 'e') then
  begin
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkBool;
    Doc^.FNodes[LIdx].BoolVal := True;
    Exit(LIdx);
  end;
  if (LLen = 5) and (LData[0] = 'f') and (LData[1] = 'a') and (LData[2] = 'l') and (LData[3] = 's') and (LData[4] = 'e') then
  begin
    LIdx := Doc^.AddNode;
    Doc^.FNodes[LIdx].Kind := jnkBool;
    Doc^.FNodes[LIdx].BoolVal := False;
    Exit(LIdx);
  end;
  if (LLen = 4) and (LData[0] = 'n') and (LData[1] = 'u') and (LData[2] = 'l') and (LData[3] = 'l') then
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
    if PeekCh <> Ord(':') then
    begin
      SetError('expected :', 10);
      Exit(JSON_NODE_NONE);
    end;
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
    Ord(','), Ord(']'), Ord('}'), Ord(':'), 0:
    begin
      if GetValueSlice(LData, LLen) then
      begin
        case LData[0] of
          '-', '0'..'9': Result := ParseNumber;
          't', 'f', 'n': Result := ParseLiteral;
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
  else
    if GetValueSlice(LData, LLen) then
    begin
      case LData[0] of
        '-', '0'..'9': Result := ParseNumber;
        't', 'f', 'n': Result := ParseLiteral;
      else
        SetError('unexpected character', 20);
        Result := JSON_NODE_NONE;
      end;
    end
    else
    begin
      SetError('unexpected character', 20);
      Result := JSON_NODE_NONE;
    end;
  end;
end;

function TJsonDocument.Parse(const AInput: TStringView): Boolean;
var
  LState: TParserState;
begin
  FInput := AInput;
  FNodeCount := 0;
  FHasError := False;
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
