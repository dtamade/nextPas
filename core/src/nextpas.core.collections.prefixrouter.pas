unit nextpas.core.collections.prefixrouter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.collections.prefixrouter.base,
  nextpas.core.collections.prefixrouter.intf;

type
  generic TPrefixRouter<V> = class(TInterfacedObject, specialize IPrefixRouter<V>)
  private type
    PNode = ^TNode;
    TChild = record
      Key: Byte;
      Node: PNode;
    end;
    TNode = record
      Children: array of TChild;
      ChildCount: Integer;
      HasValue: Boolean;
      Value: V;
    end;
  private
    FRoot: PNode;
    FCount: SizeUInt;
    function NewNode: PNode; inline;
    procedure FreeNodeRecursive(ANode: PNode);
    procedure ClearNodeValue(ANode: PNode); inline;
    function FindChild(ANode: PNode; AKey: Byte): PNode; inline;
    function GetOrCreateChild(ANode: PNode; AKey: Byte): PNode; inline;
    function FindNode(const AKey: string): PNode;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AKey: string; const AValue: V): Boolean;
    function TryGet(const AKey: string; out AValue: V): Boolean;
    function TryGetLongestPrefix(const AKey: string; out AValue: V): Boolean; inline;
    function TryGetLongestPrefixView(const AView: TStringView; out AValue: V): Boolean; inline;
    procedure Clear;
    function GetCount: SizeUInt; inline;
    function IsEmpty: Boolean; inline;
  end;

implementation

uses
  nextpas.core.bytes.ops;

constructor TPrefixRouter.Create;
begin
  inherited Create;
  FRoot := NewNode;
  FCount := 0;
end;

destructor TPrefixRouter.Destroy;
begin
  FreeNodeRecursive(FRoot);
  inherited Destroy;
end;

function TPrefixRouter.NewNode: PNode; inline;
begin
  New(Result);
  Result^.Children := nil;
  Result^.ChildCount := 0;
  Result^.HasValue := False;
end;

procedure TPrefixRouter.ClearNodeValue(ANode: PNode); inline;
begin
  if (ANode = nil) or (not ANode^.HasValue) then Exit;
  if IsManagedType(V) then
  begin
    Finalize(ANode^.Value);
    Initialize(ANode^.Value);
  end;
  ANode^.HasValue := False;
end;

procedure TPrefixRouter.FreeNodeRecursive(ANode: PNode);
var
  I: Integer;
begin
  if ANode = nil then Exit;
  for I := 0 to ANode^.ChildCount - 1 do
    FreeNodeRecursive(ANode^.Children[I].Node);
  if ANode^.HasValue then
    Finalize(ANode^.Value);
  ANode^.Children := nil;
  Dispose(ANode);
end;

function TPrefixRouter.FindChild(ANode: PNode; AKey: Byte): PNode; inline;
var
  I: Integer;
begin
  for I := 0 to ANode^.ChildCount - 1 do
    if ANode^.Children[I].Key = AKey then
      Exit(ANode^.Children[I].Node);
  Result := nil;
end;

function TPrefixRouter.GetOrCreateChild(ANode: PNode; AKey: Byte): PNode; inline;
var
  LFound: PNode;
begin
  LFound := FindChild(ANode, AKey);
  if LFound <> nil then Exit(LFound);
  Result := NewNode;
  if ANode^.ChildCount = Length(ANode^.Children) then
    specialize VecGrow<TChild>(ANode^.Children, ANode^.ChildCount);
  ANode^.Children[ANode^.ChildCount].Key := AKey;
  ANode^.Children[ANode^.ChildCount].Node := Result;
  Inc(ANode^.ChildCount);
end;

function TPrefixRouter.FindNode(const AKey: string): PNode;
var
  I: Integer;
  C: Byte;
begin
  Result := FRoot;
  for I := 1 to Length(AKey) do
  begin
    C := Byte(AKey[I]);
    Result := FindChild(Result, C);
    if Result = nil then Exit(nil);
  end;
end;

function TPrefixRouter.Add(const AKey: string; const AValue: V): Boolean;
var
  LNode: PNode;
  I: Integer;
  C: Byte;
begin
  LNode := FRoot;
  for I := 1 to Length(AKey) do
  begin
    C := Byte(AKey[I]);
    LNode := GetOrCreateChild(LNode, C);
  end;
  if LNode^.HasValue then Exit(False);
  LNode^.HasValue := True;
  LNode^.Value := AValue;
  Inc(FCount);
  Result := True;
end;

function TPrefixRouter.TryGet(const AKey: string; out AValue: V): Boolean;
var
  LNode: PNode;
begin
  LNode := FindNode(AKey);
  if (LNode <> nil) and LNode^.HasValue then
  begin
    AValue := LNode^.Value;
    Exit(True);
  end;
  Result := False;
end;

function TPrefixRouter.TryGetLongestPrefix(const AKey: string; out AValue: V): Boolean; inline;
var
  Vv: TStringView;
begin
  Vv := TStringView.FromStr(AKey);
  Result := TryGetLongestPrefixView(Vv, AValue);
end;

function TPrefixRouter.TryGetLongestPrefixView(const AView: TStringView; out AValue: V): Boolean; inline;
var
  LNode, LBest: PNode;
  I: SizeUInt;
  C: Byte;
  LChild: PNode;
begin
  LNode := FRoot;
  LBest := nil;
  if LNode^.HasValue then LBest := LNode;
  for I := 0 to AView.Len - 1 do
  begin
    C := AView.Data[I];
    LChild := FindChild(LNode, C);
    if LChild = nil then Break;
    LNode := LChild;
    if LNode^.HasValue then LBest := LNode;
  end;
  if LBest <> nil then
  begin
    AValue := LBest^.Value;
    Exit(True);
  end;
  Result := False;
end;

procedure TPrefixRouter.Clear;
var
  I: Integer;
begin
  for I := 0 to FRoot^.ChildCount - 1 do
    FreeNodeRecursive(FRoot^.Children[I].Node);
  FRoot^.Children := nil;
  FRoot^.ChildCount := 0;
  ClearNodeValue(FRoot);
  FCount := 0;
end;

function TPrefixRouter.GetCount: SizeUInt; inline;
begin
  Result := FCount;
end;

function TPrefixRouter.IsEmpty: Boolean; inline;
begin
  Result := FCount = 0;
end;

end.
