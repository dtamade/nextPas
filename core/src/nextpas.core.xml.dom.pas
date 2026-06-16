unit nextpas.core.xml.dom;
{**
 * @desc XML DOM tree backed by allocator-owned flat node and attribute pools.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.xml.base,
  nextpas.core.xml.reader;

type
  TXmlNodeKind = (xnkElement, xnkText, xnkCData, xnkComment, xnkPI, xnkDocument);

  TXmlNode = record
  private
    FState: IInterface;
    FIndex: UInt32;
    function GetKind: TXmlNodeKind;
    function GetName: TXmlName;
    function GetValue: string;
    function GetParent: TXmlNode;
  public
    class function None: TXmlNode; static;
    function IsAssigned: Boolean;
    function Child(AIndex: Integer): TXmlNode;
    function FindChild(const AName: string): TXmlNode;
    function GetAttr(const AName: string; const ADefault: string = ''): string;
    function Text: string;
    function ChildCount: Integer;
    property Kind: TXmlNodeKind read GetKind;
    property Name: TXmlName read GetName;
    property Value: string read GetValue;
    property Parent: TXmlNode read GetParent;
  end;

  TXmlNodeArray = array of TXmlNode;

  TXmlDocument = record
  private
    FState: IInterface;
    function GetChildren: TXmlNodeArray;
    procedure ParseInput(const AInput: string);
  public
    class function None: TXmlDocument; static;
    procedure Init(const AAllocator: IAllocator);
    procedure Done;
    procedure Free;
    class function Parse(const AInput: string): TXmlDocument; static; overload;
    class function ParseWith(const AInput: string;
      const AAllocator: IAllocator): TXmlDocument; static;
    function IsAssigned: Boolean;
    function Kind: TXmlNodeKind;
    function Root: TXmlNode;
    function Child(AIndex: Integer): TXmlNode;
    function SelectPath(const APath: string): TXmlNodeArray;
    function ChildCount: Integer;
    function Allocator: IAllocator;
    property Children: TXmlNodeArray read GetChildren;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.mem.default;

const
  XML_NODE_NONE = High(UInt32);

type
  PXmlNodeData = ^TXmlNodeData;
  PXmlAttribute = ^TXmlAttribute;
  TXmlNodeData = record
    Kind: TXmlNodeKind;
    Name: TXmlName;
    Value: string;
    FirstChild: UInt32;
    Next: UInt32;
    AttrStart: UInt32;
    AttrCount: UInt32;
    Parent: UInt32;
  end;

  IXmlDocumentStateAccessor = interface(IInterface)
    ['{07CE1301-C45E-4D40-96A3-D3F1A0E8E9C1}']
    procedure Reset;
    function HasNode(AIdx: UInt32): Boolean;
    function NodePtr(AIdx: UInt32): PXmlNodeData;
    function RootIndex: UInt32;
    procedure SetRootIndex(AIdx: UInt32);
    function AddNode(AKind: TXmlNodeKind): UInt32;
    procedure LinkChild(AParentIdx, AChildIdx: UInt32);
    procedure SetAttributes(ANodeIdx: UInt32;
      const AAttributes: TXmlAttributeArray);
    function AttributePtr(AIdx: UInt32): PXmlAttribute;
    function Allocator: IAllocator;
  end;

  TXmlDocumentState = class(TInterfacedObject, IXmlDocumentStateAccessor)
  private
    FNodes: PXmlNodeData;
    FNodeCount: UInt32;
    FNodeCap: UInt32;
    FRootIdx: UInt32;
    FAttributes: PXmlAttribute;
    FAttrCount: UInt32;
    FAttrCap: UInt32;
    FAllocator: IAllocator;
    procedure ClearBuffers;
    procedure EnsureNodeCapacity(ANeeded: UInt32);
    procedure EnsureAttrCapacity(ANeeded: UInt32);
  public
    constructor Create(const AAllocator: IAllocator);
    destructor Destroy; override;
    procedure Reset;
    function HasNode(AIdx: UInt32): Boolean;
    function NodePtr(AIdx: UInt32): PXmlNodeData;
    function RootIndex: UInt32;
    procedure SetRootIndex(AIdx: UInt32);
    function AddNode(AKind: TXmlNodeKind): UInt32;
    procedure LinkChild(AParentIdx, AChildIdx: UInt32);
    procedure SetAttributes(ANodeIdx: UInt32;
      const AAttributes: TXmlAttributeArray);
    function AttributePtr(AIdx: UInt32): PXmlAttribute;
    function Allocator: IAllocator;
  end;

function NodeState(const ANode: TXmlNode): IXmlDocumentStateAccessor;
begin
  if ANode.FState = nil then
    Exit(nil);
  Result := ANode.FState as IXmlDocumentStateAccessor;
end;

function DocumentState(const ADoc: TXmlDocument): IXmlDocumentStateAccessor;
begin
  if ADoc.FState = nil then
    Exit(nil);
  Result := ADoc.FState as IXmlDocumentStateAccessor;
end;

function MakeNode(const AState: IInterface; AIndex: UInt32): TXmlNode;
begin
  if (AState = nil) or (AIndex = XML_NODE_NONE) then
    Exit(TXmlNode.None);
  Result.FState := AState;
  Result.FIndex := AIndex;
end;

function IsDocumentWhitespaceOnly(const AValue: string): Boolean;
var
  LI: Integer;
begin
  for LI := 1 to Length(AValue) do
    case AValue[LI] of
      ' ', #9, #10, #13:
        ;
    else
      Exit(False);
    end;
  Result := True;
end;

{ TXmlDocumentState }

constructor TXmlDocumentState.Create(const AAllocator: IAllocator);
begin
  inherited Create;
  if AAllocator = nil then
    FAllocator := DefaultAllocator
  else
    FAllocator := AAllocator;
  FNodes := nil;
  FNodeCount := 0;
  FNodeCap := 0;
  FRootIdx := XML_NODE_NONE;
  FAttributes := nil;
  FAttrCount := 0;
  FAttrCap := 0;
  Reset;
end;

destructor TXmlDocumentState.Destroy;
begin
  ClearBuffers;
  inherited Destroy;
end;

procedure TXmlDocumentState.ClearBuffers;
var
  LI: UInt32;
begin
  if FNodes <> nil then
  begin
    if FNodeCount > 0 then
      for LI := 0 to FNodeCount - 1 do
        Finalize(FNodes[LI]);
    FAllocator.Deallocate(Pointer(FNodes));
    FNodes := nil;
  end;
  if FAttributes <> nil then
  begin
    if FAttrCount > 0 then
      for LI := 0 to FAttrCount - 1 do
        Finalize(FAttributes[LI]);
    FAllocator.Deallocate(Pointer(FAttributes));
    FAttributes := nil;
  end;
  FNodeCount := 0;
  FNodeCap := 0;
  FAttrCount := 0;
  FAttrCap := 0;
  FRootIdx := XML_NODE_NONE;
end;

procedure TXmlDocumentState.EnsureNodeCapacity(ANeeded: UInt32);
var
  LNewCap: UInt32;
  LNewPtr: Pointer;
  LOldCap: UInt32;
begin
  if ANeeded <= FNodeCap then
    Exit;
  LOldCap := FNodeCap;
  if FNodeCap = 0 then
    LNewCap := 32
  else
    LNewCap := FNodeCap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := FAllocator.Reallocate(Pointer(FNodes),
    LNewCap * SizeOf(TXmlNodeData));
  if LNewPtr = nil then
    raise EResourceExhaustedError.Create('TXmlDocument: out of memory');
  FNodes := PXmlNodeData(LNewPtr);
  if LNewCap > LOldCap then
    FillChar(FNodes[LOldCap], (LNewCap - LOldCap) * SizeOf(TXmlNodeData), 0);
  FNodeCap := LNewCap;
end;

procedure TXmlDocumentState.EnsureAttrCapacity(ANeeded: UInt32);
var
  LNewCap: UInt32;
  LNewPtr: Pointer;
  LOldCap: UInt32;
begin
  if ANeeded <= FAttrCap then
    Exit;
  LOldCap := FAttrCap;
  if FAttrCap = 0 then
    LNewCap := 32
  else
    LNewCap := FAttrCap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := FAllocator.Reallocate(Pointer(FAttributes),
    LNewCap * SizeOf(TXmlAttribute));
  if LNewPtr = nil then
    raise EResourceExhaustedError.Create('TXmlDocument: out of memory');
  FAttributes := PXmlAttribute(LNewPtr);
  if LNewCap > LOldCap then
    FillChar(FAttributes[LOldCap], (LNewCap - LOldCap) * SizeOf(TXmlAttribute), 0);
  FAttrCap := LNewCap;
end;

procedure TXmlDocumentState.Reset;
begin
  ClearBuffers;
  AddNode(xnkDocument);
end;

function TXmlDocumentState.HasNode(AIdx: UInt32): Boolean;
begin
  Result := AIdx < FNodeCount;
end;

function TXmlDocumentState.NodePtr(AIdx: UInt32): PXmlNodeData;
begin
  if not HasNode(AIdx) then
    Exit(nil);
  Result := @FNodes[AIdx];
end;

function TXmlDocumentState.RootIndex: UInt32;
begin
  Result := FRootIdx;
end;

procedure TXmlDocumentState.SetRootIndex(AIdx: UInt32);
begin
  FRootIdx := AIdx;
end;

function TXmlDocumentState.AddNode(AKind: TXmlNodeKind): UInt32;
begin
  EnsureNodeCapacity(FNodeCount + 1);
  Result := FNodeCount;
  FillChar(FNodes[Result], SizeOf(TXmlNodeData), 0);
  FNodes[Result].Kind := AKind;
  FNodes[Result].FirstChild := XML_NODE_NONE;
  FNodes[Result].Next := XML_NODE_NONE;
  FNodes[Result].Parent := XML_NODE_NONE;
  Inc(FNodeCount);
end;

procedure TXmlDocumentState.LinkChild(AParentIdx, AChildIdx: UInt32);
var
  LCur: UInt32;
begin
  FNodes[AChildIdx].Parent := AParentIdx;
  if FNodes[AParentIdx].FirstChild = XML_NODE_NONE then
  begin
    FNodes[AParentIdx].FirstChild := AChildIdx;
    Exit;
  end;
  LCur := FNodes[AParentIdx].FirstChild;
  while FNodes[LCur].Next <> XML_NODE_NONE do
    LCur := FNodes[LCur].Next;
  FNodes[LCur].Next := AChildIdx;
end;

procedure TXmlDocumentState.SetAttributes(ANodeIdx: UInt32;
  const AAttributes: TXmlAttributeArray);
var
  LI: Integer;
  LStart: UInt32;
begin
  if Length(AAttributes) = 0 then
  begin
    FNodes[ANodeIdx].AttrStart := 0;
    FNodes[ANodeIdx].AttrCount := 0;
    Exit;
  end;
  EnsureAttrCapacity(FAttrCount + UInt32(Length(AAttributes)));
  LStart := FAttrCount;
  for LI := 0 to High(AAttributes) do
  begin
    FAttributes[FAttrCount] := AAttributes[LI];
    Inc(FAttrCount);
  end;
  FNodes[ANodeIdx].AttrStart := LStart;
  FNodes[ANodeIdx].AttrCount := Length(AAttributes);
end;

function TXmlDocumentState.AttributePtr(AIdx: UInt32): PXmlAttribute;
begin
  if AIdx >= FAttrCount then
    Exit(nil);
  Result := @FAttributes[AIdx];
end;

function TXmlDocumentState.Allocator: IAllocator;
begin
  Result := FAllocator;
end;

{ TXmlNode }

class function TXmlNode.None: TXmlNode;
begin
  Result.FState := nil;
  Result.FIndex := XML_NODE_NONE;
end;

function TXmlNode.IsAssigned: Boolean;
var
  LState: IXmlDocumentStateAccessor;
begin
  if FIndex = XML_NODE_NONE then
    Exit(False);
  LState := NodeState(Self);
  Result := (LState <> nil) and LState.HasNode(FIndex);
end;

function TXmlNode.GetKind: TXmlNodeKind;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
begin
  LState := NodeState(Self);
  if LState = nil then
    Exit(xnkDocument);
  LNode := LState.NodePtr(FIndex);
  if LNode = nil then
    Exit(xnkDocument);
  Result := LNode^.Kind;
end;

function TXmlNode.GetName: TXmlName;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
begin
  Result.Prefix := '';
  Result.Local := '';
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode <> nil then
    Result := LNode^.Name;
end;

function TXmlNode.GetValue: string;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
begin
  Result := '';
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode <> nil then
    Result := LNode^.Value;
end;

function TXmlNode.GetParent: TXmlNode;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
begin
  LState := NodeState(Self);
  if LState = nil then
    Exit(TXmlNode.None);
  LNode := LState.NodePtr(FIndex);
  if (LNode = nil) or (LNode^.Parent = XML_NODE_NONE) then
    Exit(TXmlNode.None);
  Result := MakeNode(FState, LNode^.Parent);
end;

function TXmlNode.ChildCount: Integer;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
  LCur: UInt32;
  LChild: PXmlNodeData;
begin
  Result := 0;
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode = nil then
    Exit;
  LCur := LNode^.FirstChild;
  while LCur <> XML_NODE_NONE do
  begin
    Inc(Result);
    LChild := LState.NodePtr(LCur);
    if LChild = nil then
      Break;
    LCur := LChild^.Next;
  end;
end;

function TXmlNode.Child(AIndex: Integer): TXmlNode;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
  LCur: UInt32;
  LIndex: Integer;
  LChild: PXmlNodeData;
begin
  Result := TXmlNode.None;
  if AIndex < 0 then
    Exit;
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode = nil then
    Exit;
  LCur := LNode^.FirstChild;
  LIndex := 0;
  while LCur <> XML_NODE_NONE do
  begin
    LChild := LState.NodePtr(LCur);
    if LChild = nil then
      Break;
    if LIndex = AIndex then
      Exit(MakeNode(FState, LCur));
    Inc(LIndex);
    LCur := LChild^.Next;
  end;
end;

function TXmlNode.FindChild(const AName: string): TXmlNode;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
  LCur: UInt32;
  LChild: PXmlNodeData;
begin
  Result := TXmlNode.None;
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode = nil then
    Exit;
  LCur := LNode^.FirstChild;
  while LCur <> XML_NODE_NONE do
  begin
    LChild := LState.NodePtr(LCur);
    if LChild = nil then
      Break;
    if (LChild^.Kind = xnkElement) and (LChild^.Name.Local = AName) then
      Exit(MakeNode(FState, LCur));
    LCur := LChild^.Next;
  end;
end;

function TXmlNode.GetAttr(const AName: string; const ADefault: string): string;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
  LI: UInt32;
  LAttr: PXmlAttribute;
begin
  Result := ADefault;
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if (LNode = nil) or (LNode^.AttrCount = 0) then
    Exit;
  for LI := 0 to LNode^.AttrCount - 1 do
  begin
    LAttr := LState.AttributePtr(LNode^.AttrStart + LI);
    if (LAttr <> nil) and (LAttr^.Name.Local = AName) then
      Exit(LAttr^.Value);
  end;
end;

function TXmlNode.Text: string;
var
  LState: IXmlDocumentStateAccessor;
  LNode: PXmlNodeData;
  LCur: UInt32;
  LChild: TXmlNode;
  LChildData: PXmlNodeData;
begin
  Result := '';
  LState := NodeState(Self);
  if LState = nil then
    Exit;
  LNode := LState.NodePtr(FIndex);
  if LNode = nil then
    Exit;
  if (LNode^.Kind = xnkText) or (LNode^.Kind = xnkCData) then
    Exit(LNode^.Value);
  LCur := LNode^.FirstChild;
  while LCur <> XML_NODE_NONE do
  begin
    LChild := MakeNode(FState, LCur);
    case LChild.Kind of
      xnkText, xnkCData:
        Result := Result + LChild.Value;
      xnkElement:
        Result := Result + LChild.Text;
    else
      ;
    end;
    LChildData := LState.NodePtr(LCur);
    if LChildData = nil then
      Break;
    LCur := LChildData^.Next;
  end;
end;

{ TXmlDocument }

class function TXmlDocument.None: TXmlDocument;
begin
  Result.FState := nil;
end;

procedure TXmlDocument.Init(const AAllocator: IAllocator);
begin
  FState := TXmlDocumentState.Create(AAllocator) as IXmlDocumentStateAccessor;
end;

procedure TXmlDocument.Done;
begin
  FState := nil;
end;

procedure TXmlDocument.Free;
begin
  Done;
end;

function TXmlDocument.IsAssigned: Boolean;
begin
  Result := FState <> nil;
end;

function TXmlDocument.Kind: TXmlNodeKind;
begin
  Result := xnkDocument;
end;

function TXmlDocument.Allocator: IAllocator;
var
  LState: IXmlDocumentStateAccessor;
begin
  LState := DocumentState(Self);
  if LState = nil then
    Result := DefaultAllocator
  else
    Result := LState.Allocator;
end;

procedure TXmlDocument.ParseInput(const AInput: string);
var
  LReader: TXmlReader;
  LToken: TXmlToken;
  LState: IXmlDocumentStateAccessor;
  LCurrent: UInt32;
  LChildIdx: UInt32;
  LRootCount: Integer;
  LSeenDoctype: Boolean;
  LRequiresRoot: Boolean;
  LNode: PXmlNodeData;
begin
  if FState = nil then
    Init(DefaultAllocator);
  LState := DocumentState(Self);
  LState.Reset;
  LCurrent := 0;
  LRootCount := 0;
  LSeenDoctype := False;
  LRequiresRoot := False;
  LReader := TXmlReader.Create(AInput);
  try
    try
      while LReader.Next(LToken) do
      begin
        case LToken.Kind of
          xtkStartElement:
          begin
            if LCurrent = 0 then
            begin
              Inc(LRootCount);
              if LRootCount > 1 then
                raise EXmlError.Create('Multiple root elements', LToken.Position);
            end;
            LChildIdx := LState.AddNode(xnkElement);
            LNode := LState.NodePtr(LChildIdx);
            LNode^.Name := LToken.Name;
            LState.SetAttributes(LChildIdx, LToken.Attributes);
            LState.LinkChild(LCurrent, LChildIdx);
            if (LCurrent = 0) and (LState.RootIndex = XML_NODE_NONE) then
              LState.SetRootIndex(LChildIdx);
            LCurrent := LChildIdx;
          end;
          xtkEndElement:
          begin
            LNode := LState.NodePtr(LCurrent);
            if (LNode <> nil) and (LNode^.Parent <> XML_NODE_NONE) then
              LCurrent := LNode^.Parent;
          end;
          xtkEmptyElement:
          begin
            if LCurrent = 0 then
            begin
              Inc(LRootCount);
              if LRootCount > 1 then
                raise EXmlError.Create('Multiple root elements', LToken.Position);
            end;
            LChildIdx := LState.AddNode(xnkElement);
            LNode := LState.NodePtr(LChildIdx);
            LNode^.Name := LToken.Name;
            LState.SetAttributes(LChildIdx, LToken.Attributes);
            LState.LinkChild(LCurrent, LChildIdx);
            if (LCurrent = 0) and (LState.RootIndex = XML_NODE_NONE) then
              LState.SetRootIndex(LChildIdx);
          end;
          xtkText:
          begin
            if (LCurrent = 0) and (not IsDocumentWhitespaceOnly(LToken.Value)) then
              raise EXmlError.Create(
                'Document text outside root element must be whitespace only',
                LToken.Position);
            LChildIdx := LState.AddNode(xnkText);
            LState.NodePtr(LChildIdx)^.Value := LToken.Value;
            LState.LinkChild(LCurrent, LChildIdx);
          end;
          xtkCData:
          begin
            if LCurrent = 0 then
              raise EXmlError.Create(
                'Document text outside root element must be whitespace only',
                LToken.Position);
            LChildIdx := LState.AddNode(xnkCData);
            LState.NodePtr(LChildIdx)^.Value := LToken.Value;
            LState.LinkChild(LCurrent, LChildIdx);
          end;
          xtkComment:
          begin
            if LCurrent = 0 then
              LRequiresRoot := True;
            LChildIdx := LState.AddNode(xnkComment);
            LState.NodePtr(LChildIdx)^.Value := LToken.Value;
            LState.LinkChild(LCurrent, LChildIdx);
          end;
          xtkProcessingInstr:
          begin
            if LCurrent = 0 then
              LRequiresRoot := True;
            LChildIdx := LState.AddNode(xnkPI);
            LState.NodePtr(LChildIdx)^.Name := LToken.Name;
            LState.NodePtr(LChildIdx)^.Value := LToken.Value;
            LState.LinkChild(LCurrent, LChildIdx);
          end;
          xtkDoctype:
          begin
            if (LCurrent <> 0) or (LRootCount > 0) then
              raise EXmlError.Create(
                'DOCTYPE must appear before the root element',
                LToken.Position);
            if LSeenDoctype then
              raise EXmlError.Create(
                'DOCTYPE must not appear more than once',
                LToken.Position);
            LSeenDoctype := True;
            LRequiresRoot := True;
          end;
          xtkXmlDecl:
            LRequiresRoot := True;
          xtkNone:
            ;
        end;
      end;
      if LReader.HasError then
        raise EXmlError.Create(LReader.GetError, LReader.Position);
      if (LRootCount = 0) and LRequiresRoot then
        raise EXmlError.Create('Document must contain a root element',
          LReader.Position);
    except
      LState.Reset;
      raise;
    end;
  finally
    LReader.Free;
  end;
end;

class function TXmlDocument.Parse(const AInput: string): TXmlDocument;
begin
  Result := TXmlDocument.ParseWith(AInput, DefaultAllocator);
end;

class function TXmlDocument.ParseWith(const AInput: string;
  const AAllocator: IAllocator): TXmlDocument;
begin
  Result.Init(AAllocator);
  try
    Result.ParseInput(AInput);
  except
    Result.Done;
    raise;
  end;
end;

function TXmlDocument.Root: TXmlNode;
var
  LState: IXmlDocumentStateAccessor;
begin
  LState := DocumentState(Self);
  if (LState = nil) or (LState.RootIndex = XML_NODE_NONE) then
    Exit(TXmlNode.None);
  Result := MakeNode(FState, LState.RootIndex);
end;

function TXmlDocument.ChildCount: Integer;
begin
  Result := MakeNode(FState, 0).ChildCount;
end;

function TXmlDocument.Child(AIndex: Integer): TXmlNode;
begin
  Result := MakeNode(FState, 0).Child(AIndex);
end;

function TXmlDocument.GetChildren: TXmlNodeArray;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, ChildCount);
  for LI := 0 to High(Result) do
    Result[LI] := Child(LI);
end;

function TXmlDocument.SelectPath(const APath: string): TXmlNodeArray;
var
  LParts: array of string;
  LPartCount: Integer;
  LI, LJ, LStart: Integer;
  LCurrent: TXmlNodeArray;
  LNext: TXmlNodeArray;
  LNextCount: Integer;
  LChild: TXmlNode;
  LRoot: TXmlNode;
begin
  Result := nil;
  LPartCount := 0;
  SetLength(LParts, 16);
  LStart := 1;
  if (Length(APath) > 0) and (APath[1] = '/') then
    LStart := 2;
  LI := LStart;
  while LI <= Length(APath) do
  begin
    if APath[LI] = '/' then
    begin
      if LI > LStart then
      begin
        if LPartCount >= Length(LParts) then
          SetLength(LParts, Length(LParts) * 2);
        LParts[LPartCount] := Copy(APath, LStart, LI - LStart);
        Inc(LPartCount);
      end;
      LStart := LI + 1;
    end;
    Inc(LI);
  end;
  if LStart <= Length(APath) then
  begin
    if LPartCount >= Length(LParts) then
      SetLength(LParts, Length(LParts) * 2);
    LParts[LPartCount] := Copy(APath, LStart, Length(APath) - LStart + 1);
    Inc(LPartCount);
  end;

  if LPartCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LRoot := Root;
  if not LRoot.IsAssigned then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if LRoot.Name.Local <> LParts[0] then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LCurrent, 1);
  LCurrent[0] := LRoot;

  for LI := 1 to LPartCount - 1 do
  begin
    LNextCount := 0;
    SetLength(LNext, Length(LCurrent) * 4);
    for LJ := 0 to High(LCurrent) do
      for LStart := 0 to LCurrent[LJ].ChildCount - 1 do
      begin
        LChild := LCurrent[LJ].Child(LStart);
        if (LChild.Kind = xnkElement) and
           (LChild.Name.Local = LParts[LI]) then
        begin
          if LNextCount >= Length(LNext) then
            SetLength(LNext, Length(LNext) * 2);
          LNext[LNextCount] := LChild;
          Inc(LNextCount);
        end;
      end;
    SetLength(LNext, LNextCount);
    LCurrent := LNext;
    if Length(LCurrent) = 0 then
      Break;
  end;

  Result := LCurrent;
end;

end.
