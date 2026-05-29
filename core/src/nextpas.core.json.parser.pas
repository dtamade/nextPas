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
  nextpas.core.text.char;

const
  INITIAL_NODE_CAP = 64;

procedure TJsonDocument.Init(const AAllocator: IAllocator);
begin
  FAllocator := AAllocator;
  FNodeCap := INITIAL_NODE_CAP;
  FNodes := FAllocator.Allocate(FNodeCap * SizeOf(TJsonNode));
  FNodeCount := 0;
  FHasError := False;
end;

procedure TJsonDocument.Done;
begin
  if FNodes <> nil then
  begin
    FAllocator.Deallocate(FNodes);
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
    FNodes := FAllocator.Reallocate(FNodes, LNewCap * SizeOf(TJsonNode));
    FNodeCap := LNewCap;
  end;
  Result := FNodeCount;
  FillChar(FNodes[FNodeCount], SizeOf(TJsonNode), 0);
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
    Cur: TStringView;
    Depth: Int32;
    procedure SkipWS; inline;
    function Peek: Byte; inline;
    procedure Advance(N: SizeUInt); inline;
    function SetError(const AMsg: PAnsiChar; ALen: Int32): Boolean;
    function ParseValue: UInt32;
    function ParseObject: UInt32;
    function ParseArray: UInt32;
    function ParseString: UInt32;
    function ParseNumber: UInt32;
  end;

procedure TParserState.SkipWS;
var L: SizeUInt;
begin
  L := ScanSkipWhitespace(Cur.Data, Cur.Len);
  if L > 0 then Cur.Advance(L);
end;

function TParserState.Peek: Byte;
begin
  if Cur.IsEmpty then Result := 0 else Result := Cur.PeekByte;
end;

procedure TParserState.Advance(N: SizeUInt);
begin
  Cur.Advance(N);
end;

function TParserState.SetError(const AMsg: PAnsiChar; ALen: Int32): Boolean;
begin
  Doc^.FError.Message := TStringView.Create(AMsg, SizeUInt(ALen));
  Doc^.FHasError := True;
  Result := False;
end;

function TParserState.ParseString: UInt32;
var
  LEnd: PtrInt;
  LIdx: UInt32;
  LRaw: TStringView;
  LHasEscape: Boolean;
  LBuf: PAnsiChar;
  LDecLen: SizeUInt;
  LErr: TUnescapeError;
  I: SizeUInt;
begin
  LEnd := JsonFindStringEnd(Cur.Data + 1, Cur.Len - 1);
  if LEnd < 0 then
  begin
    SetError('unterminated string', 19);
    Exit(JSON_NODE_NONE);
  end;
  LRaw := TStringView.Create(Cur.Data + 1, SizeUInt(LEnd));
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
  Advance(SizeUInt(LEnd) + 2);
  Result := LIdx;
end;

function TParserState.ParseNumber: UInt32;
var
  LNumLen: SizeUInt;
  LIdx: UInt32;
  LHasDot, LHasExp: Boolean;
  I: SizeUInt;
  LInt: Int64;
  LFloat: Double;
begin
  LNumLen := ScanJsonNumber(Cur.Data, Cur.Len);
  if LNumLen = 0 then
  begin
    SetError('invalid number', 14);
    Exit(JSON_NODE_NONE);
  end;
  { RFC 8259 validation: no leading zeros, no trailing dot }
  I := 0;
  if Cur.Data[0] = '-' then I := 1;
  if (I < LNumLen - 1) and (Cur.Data[I] = '0') and (Cur.Data[I+1] >= '0') and (Cur.Data[I+1] <= '9') then
  begin
    SetError('leading zero', 12);
    Exit(JSON_NODE_NONE);
  end;
  if Cur.Data[LNumLen - 1] = '.' then
  begin
    SetError('trailing dot', 12);
    Exit(JSON_NODE_NONE);
  end;
  if (Cur.Data[LNumLen - 1] = 'e') or (Cur.Data[LNumLen - 1] = 'E') or
     (Cur.Data[LNumLen - 1] = '+') or (Cur.Data[LNumLen - 1] = '-') then
  begin
    SetError('truncated exponent', 18);
    Exit(JSON_NODE_NONE);
  end;
  LHasDot := False;
  LHasExp := False;
  for I := 0 to LNumLen - 1 do
  begin
    if Cur.Data[I] = '.' then LHasDot := True;
    if (Cur.Data[I] = 'e') or (Cur.Data[I] = 'E') then LHasExp := True;
  end;
  LIdx := Doc^.AddNode;
  if LHasDot or LHasExp then
  begin
    ParseDouble(Cur.Data, LNumLen, LFloat);
    Doc^.FNodes[LIdx].Kind := jnkReal;
    Doc^.FNodes[LIdx].RealVal := LFloat;
  end
  else
  begin
    if ParseInt64(Cur.Data, LNumLen, LInt) then
    begin
      Doc^.FNodes[LIdx].Kind := jnkInt;
      Doc^.FNodes[LIdx].IntVal := LInt;
    end
    else
    begin
      ParseDouble(Cur.Data, LNumLen, LFloat);
      Doc^.FNodes[LIdx].Kind := jnkReal;
      Doc^.FNodes[LIdx].RealVal := LFloat;
    end;
  end;
  Advance(LNumLen);
  Result := LIdx;
end;

function TParserState.ParseArray: UInt32;
var
  LIdx, LChild, LPrev: UInt32;
  LCount: UInt32;
begin
  Inc(Depth);
  if Depth > 512 then
  begin
    SetError('max depth exceeded', 18);
    Exit(JSON_NODE_NONE);
  end;
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkArray;
  Advance(1);
  SkipWS;
  LCount := 0;
  LPrev := JSON_NODE_NONE;
  if Peek = Ord(']') then
  begin
    Advance(1);
    Doc^.FNodes[LIdx].Container.FirstChild := JSON_NODE_NONE;
    Doc^.FNodes[LIdx].Container.Count := 0;
    Exit(LIdx);
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
    SkipWS;
    if Peek = Ord(',') then
    begin
      Advance(1);
      SkipWS;
    end
    else if Peek = Ord(']') then
    begin
      Advance(1);
      Break;
    end
    else
    begin
      SetError('expected , or ]', 15);
      Exit(JSON_NODE_NONE);
    end;
  end;
  Doc^.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function TParserState.ParseObject: UInt32;
var
  LIdx, LKeyIdx, LValIdx, LPrev: UInt32;
  LCount: UInt32;
begin
  Inc(Depth);
  if Depth > 512 then
  begin
    SetError('max depth exceeded', 18);
    Exit(JSON_NODE_NONE);
  end;
  LIdx := Doc^.AddNode;
  Doc^.FNodes[LIdx].Kind := jnkObject;
  Advance(1);
  SkipWS;
  LCount := 0;
  LPrev := JSON_NODE_NONE;
  if Peek = Ord('}') then
  begin
    Advance(1);
    Doc^.FNodes[LIdx].Container.FirstChild := JSON_NODE_NONE;
    Doc^.FNodes[LIdx].Container.Count := 0;
    Exit(LIdx);
  end;
  while True do
  begin
    if Peek <> Ord('"') then
    begin
      SetError('expected string key', 19);
      Exit(JSON_NODE_NONE);
    end;
    LKeyIdx := ParseString;
    if LKeyIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    SkipWS;
    if Peek <> Ord(':') then
    begin
      SetError('expected :', 10);
      Exit(JSON_NODE_NONE);
    end;
    Advance(1);
    SkipWS;
    LValIdx := ParseValue;
    if LValIdx = JSON_NODE_NONE then Exit(JSON_NODE_NONE);
    Doc^.FNodes[LKeyIdx].Next := LValIdx;
    if LCount = 0 then
      Doc^.FNodes[LIdx].Container.FirstChild := LKeyIdx
    else
      Doc^.FNodes[LPrev].Next := LKeyIdx;
    LPrev := LValIdx;
    Inc(LCount);
    SkipWS;
    if Peek = Ord(',') then
    begin
      Advance(1);
      SkipWS;
    end
    else if Peek = Ord('}') then
    begin
      Advance(1);
      Break;
    end
    else
    begin
      SetError('expected , or }', 15);
      Exit(JSON_NODE_NONE);
    end;
  end;
  Doc^.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function TParserState.ParseValue: UInt32;
var
  LIdx: UInt32;
begin
  SkipWS;
  case Peek of
    Ord('{'):
      Result := ParseObject;
    Ord('['):
      Result := ParseArray;
    Ord('"'):
      Result := ParseString;
    Ord('-'), Ord('0')..Ord('9'):
      Result := ParseNumber;
    Ord('t'):
    begin
      if ScanMatchLiteral(Cur.Data, Cur.Len, PAnsiChar('true'), 4) then
      begin
        LIdx := Doc^.AddNode;
        Doc^.FNodes[LIdx].Kind := jnkBool;
        Doc^.FNodes[LIdx].BoolVal := True;
        Advance(4);
        Result := LIdx;
      end
      else
      begin
        SetError('invalid literal', 15);
        Result := JSON_NODE_NONE;
      end;
    end;
    Ord('f'):
    begin
      if ScanMatchLiteral(Cur.Data, Cur.Len, PAnsiChar('false'), 5) then
      begin
        LIdx := Doc^.AddNode;
        Doc^.FNodes[LIdx].Kind := jnkBool;
        Doc^.FNodes[LIdx].BoolVal := False;
        Advance(5);
        Result := LIdx;
      end
      else
      begin
        SetError('invalid literal', 15);
        Result := JSON_NODE_NONE;
      end;
    end;
    Ord('n'):
    begin
      if ScanMatchLiteral(Cur.Data, Cur.Len, PAnsiChar('null'), 4) then
      begin
        LIdx := Doc^.AddNode;
        Doc^.FNodes[LIdx].Kind := jnkNull;
        Advance(4);
        Result := LIdx;
      end
      else
      begin
        SetError('invalid literal', 15);
        Result := JSON_NODE_NONE;
      end;
    end;
  else
    SetError('unexpected character', 20);
    Result := JSON_NODE_NONE;
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
  LState.Cur := AInput;
  LState.Depth := 0;
  if LState.ParseValue = JSON_NODE_NONE then
    Exit(False);
  LState.SkipWS;
  if not LState.Cur.IsEmpty then
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
