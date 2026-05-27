unit nextpas.core.collections.tree.rb;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base;

// Red-Black Tree core (engine) for ordered containers.
// This unit provides a reusable RB-tree implementation without exposing
// container semantics. It is designed to be adapted by orderedset/orderedmap.

type
  generic TRBTreeCore<T> = class
  public
    type
      PNode = ^TNode;
      TColor = (Red, Black);
      TNode = record
        Left, Right, Parent: PNode;
        Color: TColor;
        Data: T;
      end;

      TCompareMethod = specialize TCompareMethod<T>;
      TFinalizeMethod = procedure (var AValue: T) of object;
  private
    FRoot: PNode;
    FCount: SizeUInt;
    FSentinel: TNode; // black leaf sentinel
    FCompare: TCompareMethod;
    FCompareData: Pointer;
    FFinalize: TFinalizeMethod;
  private
    procedure InitTree; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  Cmp(const L, R: T): SizeInt; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

    function  NewNode(const AValue: T): PNode;
    procedure FreeNode(ANode: PNode);

    procedure RotateLeft(X: PNode);
    procedure RotateRight(X: PNode);

    procedure InsertFixup(Z: PNode);
    procedure DeleteFixup(X: PNode; XParent: PNode);
    procedure Transplant(U, V: PNode);

    function  MinNode(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  MaxNode(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  SuccessorNode(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  PredecessorNode(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
  public
    constructor Create(aCompare: TCompareMethod; aCompareData: Pointer; aFinalize: TFinalizeMethod);
    destructor Destroy; override;

    procedure Clear;
    function  GetCount: SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

    // Basic ops
    function  InsertUnique(const AValue: T): Boolean;
    function  Remove(const AValue: T): Boolean;
    function  Contains(const AValue: T): Boolean;

    // Ordered queries
    function  LowerBound(const AValue: T; out OutValue: T): Boolean;
    function  UpperBound(const AValue: T; out OutValue: T): Boolean;
    function  LowerBoundNode(const AValue: T): PNode;

    function  Min(out OutValue: T): Boolean;
    function  Max(out OutValue: T): Boolean;

    // Iteration helpers
    function  FirstNode: PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  LastNode:  PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  Successor(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function  Predecessor(N: PNode): PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

    function  Sentinel: PNode; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
  end;

implementation

{ TRBTreeCore<T> }

procedure TRBTreeCore.InitTree;
begin
  FSentinel.Left := @FSentinel;
  FSentinel.Right := @FSentinel;
  FSentinel.Parent := @FSentinel;
  FSentinel.Color := Black;
  FRoot := @FSentinel;
  FCount := 0;
end;

constructor TRBTreeCore.Create(aCompare: TCompareMethod; aCompareData: Pointer; aFinalize: TFinalizeMethod);
begin
  inherited Create;
  FCompare := aCompare;
  FCompareData := aCompareData;
  FFinalize := aFinalize;
  InitTree;
end;

destructor TRBTreeCore.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TRBTreeCore.Cmp(const L, R: T): SizeInt;
var C: SizeInt;
begin
  if not Assigned(FCompare) then raise EInvalidOperation.Create('RBTreeCore: comparer is nil');
  C := FCompare(L, R, FCompareData);
  if C < 0 then Exit(-1) else if C > 0 then Exit(1) else Exit(0);
end;

function TRBTreeCore.NewNode(const AValue: T): PNode;
begin
  New(Result);
  Result^.Left := @FSentinel;
  Result^.Right := @FSentinel;
  Result^.Parent := @FSentinel;
  Result^.Color := Red;
  Result^.Data := AValue;
end;

procedure TRBTreeCore.FreeNode(ANode: PNode);
begin
  if (ANode = nil) or (ANode = @FSentinel) then Exit;
  if Assigned(FFinalize) then FFinalize(ANode^.Data);
  Dispose(ANode);
end;

function TRBTreeCore.MinNode(N: PNode): PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  while N^.Left <> @FSentinel do N := N^.Left;
  Result := N;
end;

function TRBTreeCore.MaxNode(N: PNode): PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  while N^.Right <> @FSentinel do N := N^.Right;
  Result := N;
end;

function TRBTreeCore.SuccessorNode(N: PNode): PNode;
var P: PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  if N^.Right <> @FSentinel then Exit(MinNode(N^.Right));
  P := N^.Parent;
  while (P <> @FSentinel) and (N = P^.Right) do begin N := P; P := P^.Parent; end;
  Result := P;
end;

function TRBTreeCore.PredecessorNode(N: PNode): PNode;
var P: PNode;
begin
  if (N = nil) or (N = @FSentinel) then Exit(@FSentinel);
  if N^.Left <> @FSentinel then Exit(MaxNode(N^.Left));
  P := N^.Parent;
  while (P <> @FSentinel) and (N = P^.Left) do begin N := P; P := P^.Parent; end;
  Result := P;
end;

procedure TRBTreeCore.RotateLeft(X: PNode);
var Y: PNode;
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

procedure TRBTreeCore.RotateRight(X: PNode);
var Y: PNode;
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

procedure TRBTreeCore.Transplant(U, V: PNode);
begin
  if U^.Parent = @FSentinel then FRoot := V
  else if U = U^.Parent^.Left then U^.Parent^.Left := V
  else U^.Parent^.Right := V;
  if V <> @FSentinel then V^.Parent := U^.Parent;
end;

procedure TRBTreeCore.InsertFixup(Z: PNode);
var Y: PNode;
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

procedure TRBTreeCore.DeleteFixup(X: PNode; XParent: PNode);
var W: PNode;
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

procedure TRBTreeCore.Clear;
var Cur, Next: PNode;
begin
  // 先断开根，保证异常情况下不会二次释放或访问
  if FRoot = @FSentinel then exit;
  Cur := FRoot;
  FRoot := @FSentinel;
  FCount := 0;
  // 从最小节点开始依次释放
  Cur := MinNode(Cur);
  while (Cur <> @FSentinel) do
  begin
    Next := SuccessorNode(Cur);
    FreeNode(Cur);
    Cur := Next;
  end;
end;

function TRBTreeCore.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TRBTreeCore.InsertUnique(const AValue: T): Boolean;
var Y, X, Z: PNode; C: SizeInt;
begin
  Y := @FSentinel; X := FRoot;
  while (X <> @FSentinel) do
  begin
    Y := X;
    C := Cmp(AValue, X^.Data);
    if C = 0 then Exit(False)
    else if C < 0 then X := X^.Left
    else X := X^.Right;
  end;
  Z := NewNode(AValue);
  Z^.Parent := Y;
  if Y = @FSentinel then
    FRoot := Z
  else if C < 0 then
    Y^.Left := Z
  else
    Y^.Right := Z;
  InsertFixup(Z);
  Inc(FCount);
  Result := True;
end;

function TRBTreeCore.Contains(const AValue: T): Boolean;
var N: PNode; C: SizeInt;
begin
  N := FRoot;
  while N <> @FSentinel do
  begin
    C := Cmp(AValue, N^.Data);
    if C = 0 then Exit(True)
    else if C < 0 then N := N^.Left
    else N := N^.Right;
  end;
  Result := False;
end;

function TRBTreeCore.Remove(const AValue: T): Boolean;
var Z, X, Y: PNode; YOriginalColor: TColor;
begin
  // Find Z
  Z := FRoot;
  while (Z <> @FSentinel) and (Cmp(AValue, Z^.Data) <> 0) do
  begin
    if Cmp(AValue, Z^.Data) < 0 then Z := Z^.Left else Z := Z^.Right;
  end;
  if (Z = @FSentinel) then Exit(False);

  Y := Z;
  YOriginalColor := Y^.Color;
  if Z^.Left = @FSentinel then
  begin
    X := Z^.Right;
    Transplant(Z, Z^.Right);
  end
  else if Z^.Right = @FSentinel then
  begin
    X := Z^.Left;
    Transplant(Z, Z^.Left);
  end
  else
  begin
    Y := MinNode(Z^.Right);
    YOriginalColor := Y^.Color;
    X := Y^.Right;
    if Y^.Parent = Z then
    begin
      if X <> @FSentinel then X^.Parent := Y;
    end
    else
    begin
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
  begin
    // X may be sentinel; ensure parent is valid (sentinel has self-parent)
    if X = @FSentinel then
      DeleteFixup(X, Z^.Parent) // when X is sentinel, Z's original parent is the correct reference
    else
      DeleteFixup(X, X^.Parent);
  end;
  Result := True;
end;

function TRBTreeCore.LowerBoundNode(const AValue: T): PNode;
var N, Cand: PNode; C: SizeInt;
begin
  Cand := nil; N := FRoot;
  while (N <> @FSentinel) do
  begin
    C := Cmp(N^.Data, AValue);
    if C < 0 then N := N^.Right
    else begin Cand := N; N := N^.Left; end;
  end;
  Result := Cand;
end;

function TRBTreeCore.LowerBound(const AValue: T; out OutValue: T): Boolean;
var N: PNode;
begin
  N := LowerBoundNode(AValue);
  if (N <> nil) and (N <> @FSentinel) then begin OutValue := N^.Data; Exit(True); end;
  Result := False;
end;

function TRBTreeCore.UpperBound(const AValue: T; out OutValue: T): Boolean;
var N, Cand: PNode; C: SizeInt;
begin
  Result := False; Cand := @FSentinel; N := FRoot;
  while (N <> @FSentinel) do
  begin
    C := Cmp(N^.Data, AValue);
    if C <= 0 then N := N^.Right
    else begin Cand := N; N := N^.Left; end;
  end;
  if (Cand <> @FSentinel) then begin OutValue := Cand^.Data; Exit(True); end;
end;

function TRBTreeCore.Min(out OutValue: T): Boolean;
var N: PNode;
begin
  N := MinNode(FRoot);
  if (N <> nil) and (N <> @FSentinel) then begin OutValue := N^.Data; Exit(True); end;
  Result := False;
end;

function TRBTreeCore.Max(out OutValue: T): Boolean;
var N: PNode;
begin
  N := MaxNode(FRoot);
  if (N <> nil) and (N <> @FSentinel) then begin OutValue := N^.Data; Exit(True); end;
  Result := False;
end;

function TRBTreeCore.FirstNode: PNode;
begin
  Result := MinNode(FRoot);
  if Result = @FSentinel then Result := nil;
end;

function TRBTreeCore.LastNode: PNode;
begin
  Result := MaxNode(FRoot);
  if Result = @FSentinel then Result := nil;
end;

function TRBTreeCore.Successor(N: PNode): PNode;
begin
  Result := SuccessorNode(N);
  if Result = @FSentinel then Result := nil;
end;

function TRBTreeCore.Predecessor(N: PNode): PNode;
begin
  Result := PredecessorNode(N);
  if Result = @FSentinel then Result := nil;
end;

function TRBTreeCore.Sentinel: PNode;
begin
  Result := @FSentinel;
end;

end.
