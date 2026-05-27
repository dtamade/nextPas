unit nextpas.core.collections.rbset;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints for IsOverlap - tree structures don't use contiguous memory
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.rbset.intf,
  nextpas.core.mem.allocator;

type
  generic TRBTreeSet<T> = class(specialize TGenericCollection<T>, specialize IRBTreeSet<T>)
  type
    PNode = ^TNode;
    TColor = (Red, Black);
    TNode = record
      Left, Right, Parent: PNode;
      Color: TColor;
      Data: T;
    end;
  private
    FRoot: PNode;
    FCount: SizeUInt;
    FSentinel: TNode; // black sentinel used as nil replacement
    procedure InitTree; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}

  private
    // iterator callbacks
    function IterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function IterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function IterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
  private
    // helpers
    function NewNode(const AValue: T): PNode;
    procedure FreeNode(ANode: PNode);
    procedure ClearSubtree(ANode: PNode);  // Helper for Clear to safely free nodes

    function MinNode(N: PNode): PNode; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function MaxNode(N: PNode): PNode; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function Successor(N: PNode): PNode; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function Predecessor(N: PNode): PNode; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}

    function Compare(const L, R: T): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}

    procedure RotateLeft(X: PNode);
    procedure RotateRight(X: PNode);

    procedure InsertFixup(Z: PNode);
    procedure DeleteFixup(X: PNode; XParent: PNode);
    procedure Transplant(U, V: PNode);

    function FindNode(const AValue: T): PNode;
  protected
    // TCollection / TGenericCollection overrides
  public
    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;
    procedure DoReverse; override;
    function  IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override; // semantics: for ordered set, Zero = Clear
  public
    constructor Create; reintroduce; overload;
    constructor Create(aAllocator: IAllocator); reintroduce; overload;

    constructor Create(aAllocator: IAllocator; aData: Pointer); override;
    destructor Destroy; override;

    // Set API (minimal)
    function Insert(const AValue: T): Boolean; // true if inserted, false if existed
    function Delete(const AValue: T): Boolean; // true if deleted, false if not found
    function ContainsKey(const AValue: T): Boolean;

    // Order queries
    function LowerBound(const AValue: T; out OutValue: T): Boolean;
    function UpperBound(const AValue: T; out OutValue: T): Boolean;
  end;

implementation

{ TRBTreeSet<T> }

function TRBTreeSet.IterGetCurrent(aIter: PPtrIter): Pointer;
var
  N: PNode;
begin
  N := PNode(aIter^.Data);
  if (N = nil) or (N = @FSentinel) then Exit(nil);
  Result := @N^.Data;
end;

function TRBTreeSet.IterMoveNext(aIter: PPtrIter): Boolean;
var
  N: PNode;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    N := MinNode(FRoot);
    if N = @FSentinel then N := nil;
    aIter^.Data := N;
    Exit(N <> nil);
  end;
  N := PNode(aIter^.Data);
  if (N = nil) or (N = @FSentinel) then Exit(False);
  N := Successor(N);
  if N = @FSentinel then N := nil;
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.IterMovePrev(aIter: PPtrIter): Boolean;
var
  N: PNode;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    N := MaxNode(FRoot);
    if N = @FSentinel then N := nil;
    aIter^.Data := N;
    Exit(N <> nil);
  end;
  N := PNode(aIter^.Data);
  if (N = nil) or (N = @FSentinel) then Exit(False);
  N := Predecessor(N);
  if N = @FSentinel then N := nil;
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.NewNode(const AValue: T): PNode;
begin
  New(Result);
  Result^.Left := @FSentinel;
  Result^.Right := @FSentinel;
  Result^.Parent := @FSentinel;
  Result^.Color := Red;
  // Assign Data (managed types safe)
  Result^.Data := AValue;
end;

procedure TRBTreeSet.FreeNode(ANode: PNode);
begin
  if (ANode = nil) or (ANode = @FSentinel) then Exit;
  // finalize managed element
  GetElementManager.FinalizeManagedElementsUnchecked(@ANode^.Data, 1);
  Dispose(ANode);
end;

function TRBTreeSet.MinNode(N: PNode): PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  while N^.Left <> @FSentinel do N := N^.Left;
  Result := N;
end;

function TRBTreeSet.MaxNode(N: PNode): PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  while N^.Right <> @FSentinel do N := N^.Right;
  Result := N;
end;

function TRBTreeSet.Successor(N: PNode): PNode;
var
  P: PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  if N^.Right <> @FSentinel then Exit(MinNode(N^.Right));
  P := N^.Parent;
  while (P <> @FSentinel) and (N = P^.Right) do
  begin
    N := P;
    P := P^.Parent;
  end;
  Result := P;
end;

function TRBTreeSet.Predecessor(N: PNode): PNode;
var
  P: PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  if N^.Left <> @FSentinel then Exit(MaxNode(N^.Left));
  P := N^.Parent;
  while (P <> @FSentinel) and (N = P^.Left) do
  begin
    N := P;
    P := P^.Parent;
  end;
  Result := P;
end;

function TRBTreeSet.Compare(const L, R: T): SizeInt;
var
  M: TMethod;
begin
  // Validate internal comparer wired by TGenericCollection constructor
  M := TMethod(FInternalComparer);
  if (M.Code = nil) or (M.Data = nil) then
    raise EInvalidOperation.Create('TRBTreeSet.Compare: internal comparer is nil (constructor init missing)');

  Result := FInternalComparer(L, R);
  if Result < 0 then Exit(-1) else if Result > 0 then Exit(1) else Exit(0);
end;

procedure TRBTreeSet.RotateLeft(X: PNode);
var
  Y: PNode;
begin
  Y := X^.Right;
  X^.Right := Y^.Left;
  if Y^.Left <> @FSentinel then Y^.Left^.Parent := X;
  Y^.Parent := X^.Parent;
  if X^.Parent = @FSentinel then FRoot := Y
  else if X = X^.Parent^.Left then X^.Parent^.Left := Y
  else X^.Parent^.Right := Y;
  Y^.Left := X;
  X^.Parent := Y;
end;

procedure TRBTreeSet.RotateRight(X: PNode);
var
  Y: PNode;
begin
  Y := X^.Left;
  X^.Left := Y^.Right;
  if Y^.Right <> @FSentinel then Y^.Right^.Parent := X;
  Y^.Parent := X^.Parent;
  if X^.Parent = @FSentinel then FRoot := Y
  else if X = X^.Parent^.Right then X^.Parent^.Right := Y
  else X^.Parent^.Left := Y;
  Y^.Right := X;
  X^.Parent := Y;
end;

procedure TRBTreeSet.Transplant(U, V: PNode);
begin
  if U^.Parent = @FSentinel then FRoot := V
  else if U = U^.Parent^.Left then U^.Parent^.Left := V
  else U^.Parent^.Right := V;
  if V <> @FSentinel then V^.Parent := U^.Parent;
end;

procedure TRBTreeSet.InsertFixup(Z: PNode);
var
  Y: PNode;
begin
  while (Z^.Parent <> @FSentinel) and (Z^.Parent^.Color = Red) do
  begin
    if Z^.Parent = Z^.Parent^.Parent^.Left then
    begin
      Y := Z^.Parent^.Parent^.Right;
      if (Y <> @FSentinel) and (Y^.Color = Red) then
      begin
        Z^.Parent^.Color := Black;
        Y^.Color := Black;
        Z^.Parent^.Parent^.Color := Red;
        Z := Z^.Parent^.Parent;
      end
      else
      begin
        if Z = Z^.Parent^.Right then
        begin
          Z := Z^.Parent;
          RotateLeft(Z);
        end;
        Z^.Parent^.Color := Black;
        Z^.Parent^.Parent^.Color := Red;
        RotateRight(Z^.Parent^.Parent);
      end;
    end
    else
    begin
      Y := Z^.Parent^.Parent^.Left;
      if (Y <> @FSentinel) and (Y^.Color = Red) then
      begin
        Z^.Parent^.Color := Black;
        Y^.Color := Black;
        Z^.Parent^.Parent^.Color := Red;
        Z := Z^.Parent^.Parent;
      end
      else
      begin
        if Z = Z^.Parent^.Left then
        begin
          Z := Z^.Parent;
          RotateRight(Z);
        end;
        Z^.Parent^.Color := Black;
        Z^.Parent^.Parent^.Color := Red;
        RotateLeft(Z^.Parent^.Parent);
      end;
    end;
  end;
  if FRoot <> @FSentinel then FRoot^.Color := Black;
end;

procedure TRBTreeSet.DeleteFixup(X: PNode; XParent: PNode);
var
  W: PNode;
begin
  while (X <> FRoot) and ((X = @FSentinel) or (X^.Color = Black)) do
  begin
    if X = XParent^.Left then
    begin
      W := XParent^.Right;
      if (W <> @FSentinel) and (W^.Color = Red) then
      begin
        W^.Color := Black;
        XParent^.Color := Red;
        RotateLeft(XParent);
        W := XParent^.Right;
      end;
      if ((W = @FSentinel) or ((W^.Left = @FSentinel) or (W^.Left^.Color = Black))) and
         ((W = @FSentinel) or ((W^.Right = @FSentinel) or (W^.Right^.Color = Black))) then
      begin
        if W <> @FSentinel then W^.Color := Red;
        X := XParent;
        XParent := X^.Parent;
      end
      else
      begin
        if (W <> @FSentinel) and ((W^.Right = @FSentinel) or (W^.Right^.Color = Black)) then
        begin
          if W^.Left <> @FSentinel then W^.Left^.Color := Black;
          if W <> @FSentinel then W^.Color := Red;
          if W <> @FSentinel then RotateRight(W);
          W := XParent^.Right;
        end;
        if W <> @FSentinel then W^.Color := XParent^.Color;
        XParent^.Color := Black;
        if (W <> @FSentinel) and (W^.Right <> @FSentinel) then W^.Right^.Color := Black;
        RotateLeft(XParent);
        X := FRoot;
      end;
    end
    else
    begin
      W := XParent^.Left;
      if (W <> @FSentinel) and (W^.Color = Red) then
      begin
        W^.Color := Black;
        XParent^.Color := Red;
        RotateRight(XParent);
        W := XParent^.Left;
      end;
      if ((W = @FSentinel) or ((W^.Right = @FSentinel) or (W^.Right^.Color = Black))) and
         ((W = @FSentinel) or ((W^.Left = @FSentinel) or (W^.Left^.Color = Black))) then
      begin
        if W <> @FSentinel then W^.Color := Red;
        X := XParent;
        XParent := X^.Parent;
      end
      else
      begin
        if (W <> @FSentinel) and ((W^.Left = @FSentinel) or (W^.Left^.Color = Black)) then
        begin
          if W^.Right <> @FSentinel then W^.Right^.Color := Black;
          if W <> @FSentinel then W^.Color := Red;
          if W <> @FSentinel then RotateLeft(W);
          W := XParent^.Left;
        end;
        if W <> @FSentinel then W^.Color := XParent^.Color;
        XParent^.Color := Black;
        if (W <> @FSentinel) and (W^.Left <> @FSentinel) then W^.Left^.Color := Black;
        RotateRight(XParent);
        X := FRoot;
      end;
    end;
  end;
  if X <> @FSentinel then X^.Color := Black;
end;

function TRBTreeSet.FindNode(const AValue: T): PNode;
var
  N: PNode;
  C: SizeInt;
begin
  N := FRoot;
  while N <> @FSentinel do
  begin
    C := Compare(AValue, N^.Data);
    if C = 0 then Exit(N)
    else if C < 0 then N := N^.Left
    else N := N^.Right;
  end;
  Result := nil;
end;

function TRBTreeSet.PtrIter: TPtrIter;
begin
  Result.Init(Self, @IterGetCurrent, @IterMoveNext, @IterMovePrev, nil);
end;

function TRBTreeSet.GetCount: SizeUInt;
begin
  Result := FCount;
end;

procedure TRBTreeSet.Clear;
begin
  // Use post-order traversal to safely free all nodes
  ClearSubtree(FRoot);
  FRoot := @FSentinel;
  FCount := 0;
end;

procedure TRBTreeSet.ClearSubtree(ANode: PNode);
begin
  if (ANode = nil) or (ANode = @FSentinel) then Exit;

  // Recursively clear left and right subtrees first
  ClearSubtree(ANode^.Left);
  ClearSubtree(ANode^.Right);

  // Then free this node
  FreeNode(ANode);
end;

procedure TRBTreeSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LIter: TPtrIter;
  PE: ^T;
  P: ^T;
begin
  if (aCount <> FCount) then
    ; // 不强制校验，按容器当前大小写出
  PE := aDst;
  if PE = nil then Exit;
  LIter := PtrIter;
  while LIter.MoveNext do
  begin
    P := LIter.GetCurrent;
    PE^ := P^;
    Inc(PE);
  end;
end;

procedure TRBTreeSet.AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  I: SizeUInt;
  P: ^T;
begin
  if (aSrc = nil) or (aElementCount = 0) then Exit;
  P := aSrc;
  for I := 1 to aElementCount do
  begin
    Insert(P^);
    Inc(P);
  end;
end;

procedure TRBTreeSet.AppendToUnchecked(const aDst: TCollection);
var
  LIter: TPtrIter;
  PElem: ^T;
begin
  if FCount = 0 then Exit;
  LIter := PtrIter;
  while LIter.MoveNext do
  begin
    PElem := LIter.GetCurrent;
    aDst.AppendUnchecked(PElem, 1);
  end;
end;

function TRBTreeSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // Tree does not store elements in a contiguous external buffer
  Result := False;
end;

procedure TRBTreeSet.DoZero;
begin
  // Zero semantics: clear the set
  Clear;
end;

procedure TRBTreeSet.DoReverse;
begin
  // Reverse on ordered set is a no-op (iteration order is controlled by iterator)
end;

procedure TRBTreeSet.InitTree;
begin
  // init sentinel as a black leaf
  FSentinel.Left := @FSentinel;
  FSentinel.Right := @FSentinel;
  FSentinel.Parent := @FSentinel;
  FSentinel.Color := Black;
  // init root to sentinel and count to 0
  FRoot := @FSentinel;
  FCount := 0;
end;

constructor TRBTreeSet.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  InitTree;
end;

constructor TRBTreeSet.Create;
begin
  inherited Create(GetRtlAllocator(), nil);
  InitTree;
end;

constructor TRBTreeSet.Create(aAllocator: IAllocator);
begin
  inherited Create(aAllocator, nil);
  InitTree;
end;

destructor TRBTreeSet.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TRBTreeSet.Insert(const AValue: T): Boolean;
var
  Y, X, Z: PNode;
  C: SizeInt;
begin
  // standard RB-tree insert unique (sentinel-based)
  Y := @FSentinel; X := FRoot;
  while (X <> @FSentinel) and (X <> nil) do
  begin
    Y := X;
    C := Compare(AValue, X^.Data);
    if C = 0 then Exit(False)
    else if C < 0 then X := X^.Left
    else X := X^.Right;
  end;
  Z := NewNode(AValue);
  Z^.Parent := Y;
  if Y = @FSentinel then FRoot := Z
  else if Compare(Z^.Data, Y^.Data) < 0 then Y^.Left := Z
  else Y^.Right := Z;
  InsertFixup(Z);
  Inc(FCount);
  Result := True;
end;

function TRBTreeSet.Delete(const AValue: T): Boolean;
var
  Z, Y, X, XP: PNode;
  YOriginalColor: TColor;
begin
  Z := FindNode(AValue);
  if Z = nil then Exit(False);

  Y := Z;
  YOriginalColor := Y^.Color;

  if Z^.Left = @FSentinel then
  begin
    X := Z^.Right;
    XP := Z^.Parent;
    Transplant(Z, Z^.Right);
  end
  else if Z^.Right = @FSentinel then
  begin
    X := Z^.Left;
    XP := Z^.Parent;
    Transplant(Z, Z^.Left);
  end
  else
  begin
    Y := MinNode(Z^.Right);
    YOriginalColor := Y^.Color;
    X := Y^.Right;
    if Y^.Parent = Z then
      XP := Y
    else
    begin
      XP := Y^.Parent;
      Transplant(Y, Y^.Right);
      Y^.Right := Z^.Right;
      if Y^.Right <> @FSentinel then Y^.Right^.Parent := Y;
    end;
    Transplant(Z, Y);
    Y^.Left := Z^.Left;
    if Y^.Left <> @FSentinel then Y^.Left^.Parent := Y;
    Y^.Color := Z^.Color;
  end;

  FreeNode(Z);
  Dec(FCount);

  if YOriginalColor = Black then
    DeleteFixup(X, XP);

  Result := True;
end;

function TRBTreeSet.ContainsKey(const AValue: T): Boolean;
begin
  Result := FindNode(AValue) <> nil;
end;

function TRBTreeSet.LowerBound(const AValue: T; out OutValue: T): Boolean;
var
  N, Cand: PNode;
  C: SizeInt;
begin
  Result := False; Cand := nil; N := FRoot;
  while (N <> @FSentinel) do
  begin
    C := Compare(N^.Data, AValue);
    if C < 0 then
      N := N^.Right
    else
    begin
      Cand := N;
      N := N^.Left;
    end;
  end;
  if (Cand <> nil) and (Cand <> @FSentinel) then
  begin
    OutValue := Cand^.Data;
    Exit(True);
  end;
end;

function TRBTreeSet.UpperBound(const AValue: T; out OutValue: T): Boolean;
var
  N, Cand: PNode;
  C: SizeInt;
begin
  Result := False; Cand := nil; N := FRoot;
  while (N <> @FSentinel) do
  begin
    C := Compare(N^.Data, AValue);
    if C <= 0 then
      N := N^.Right
    else
    begin
      Cand := N;
      N := N^.Left;
    end;
  end;
  if (Cand <> nil) and (Cand <> @FSentinel) then
  begin
    OutValue := Cand^.Data;
    Exit(True);
  end;
end;

end.
