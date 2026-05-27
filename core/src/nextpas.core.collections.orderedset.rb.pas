unit nextpas.core.collections.orderedset.rb;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.orderedset.rb.intf,
  nextpas.core.mem.allocator,
  nextpas.core.collections.tree.rb;

type
  generic TRBTreeSet<T> = class(specialize TGenericCollection<T>, specialize IRBOrderedSet<T>)
  private
    type
      TRBCore = specialize TRBTreeCore<T>;
      TRBNode = TRBCore.PNode;
  private
    FTree: TRBCore;
    // Range state (非重入临时字段)
    FRangeActive: Boolean;
    FRangeInclusiveRight: Boolean;
    FRangeLeftValue: T;
    FRangeRightValue: T;
    FRangeStartNode: TRBNode;

  private
    // iterator callbacks (adapt FTree nodes)
    function IterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function IterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function IterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

    // range iterator callbacks
    function RangeIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function RangeIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function RangeIterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

    function CompareAdapter(const L, R: T; aData: Pointer): SizeInt; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    procedure FinalizeAdapter(var V: T); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
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
    function Remove(const AValue: T): Boolean; // true if removed
    function ContainsKey(const AValue: T): Boolean;

    // Order queries
    function LowerBound(const AValue: T; out OutValue: T): Boolean;
    function UpperBound(const AValue: T; out OutValue: T): Boolean;

    // Min/Max
    function Min(out OutValue: T): Boolean;
    function Max(out OutValue: T): Boolean;

    // Range iteration [L, R) or [L, R]
    function IterateRange(const L, R: T; InclusiveRight: Boolean = False): specialize TIter<T>;
  end;

implementation

{ TRBTreeSet<T> }

function TRBTreeSet.IterGetCurrent(aIter: PPtrIter): Pointer;
var
  N: TRBNode;
begin
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(nil);
  Result := @N^.Data;
end;

function TRBTreeSet.IterMoveNext(aIter: PPtrIter): Boolean;
var
  N: TRBNode;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    N := FTree.FirstNode;
    aIter^.Data := N;
    Exit(N <> nil);
  end;
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(False);
  N := FTree.Successor(N);
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.IterMovePrev(aIter: PPtrIter): Boolean;
var
  N: TRBNode;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    N := FTree.LastNode;
    aIter^.Data := N;
    Exit(N <> nil);
  end;
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(False);
  N := FTree.Predecessor(N);
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.RangeIterGetCurrent(aIter: PPtrIter): Pointer;
var
  N: TRBNode;
begin
  if not FRangeActive then Exit(nil);
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(nil);
  Result := @N^.Data;
end;

function TRBTreeSet.RangeIterMoveNext(aIter: PPtrIter): Boolean;
var
  N: TRBNode; C: SizeInt;
begin
  if not FRangeActive then Exit(False);
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    N := FTree.LowerBoundNode(FRangeLeftValue);
    aIter^.Data := N;
    // check right bound
    if N <> nil then
    begin
      C := FInternalComparer(N^.Data, FRangeRightValue);
      if (C > 0) or ((C = 0) and (not FRangeInclusiveRight)) then
      begin
        aIter^.Data := nil;
        Exit(False);
      end;
    end;
    Exit(N <> nil);
  end;
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(False);
  N := FTree.Successor(N);
  // check right bound
  if N <> nil then
  begin
    C := FInternalComparer(N^.Data, FRangeRightValue);
    if (C > 0) or ((C = 0) and (not FRangeInclusiveRight)) then
    begin
      aIter^.Data := nil;
      Exit(False);
    end;
  end;
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.RangeIterMovePrev(aIter: PPtrIter): Boolean;
var
  N: TRBNode; C: SizeInt;
begin
  if not FRangeActive then Exit(False);
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    // start at <= right bound
    N := FTree.LowerBoundNode(FRangeRightValue);
    if (N = nil) or ((N <> nil) and (FInternalComparer(N^.Data, FRangeRightValue) > 0)) then
      N := FTree.Predecessor(N);
    aIter^.Data := N;
    // check left bound (must be >= left)
    if N <> nil then
    begin
      C := FInternalComparer(N^.Data, FRangeLeftValue);
      if C < 0 then
      begin
        aIter^.Data := nil;
        Exit(False);
      end;
    end;
    Exit(N <> nil);
  end;
  N := TRBNode(aIter^.Data);
  if (N = nil) then Exit(False);
  N := FTree.Predecessor(N);
  // check left bound
  if N <> nil then
  begin
    C := FInternalComparer(N^.Data, FRangeLeftValue);
    if C < 0 then
    begin
      aIter^.Data := nil;
      Exit(False);
    end;
  end;
  aIter^.Data := N;
  Result := N <> nil;
end;

function TRBTreeSet.CompareAdapter(const L, R: T; aData: Pointer): SizeInt;
begin
  Result := FInternalComparer(L, R);
  if Result < 0 then Exit(-1) else if Result > 0 then Exit(1) else Exit(0);
end;

procedure TRBTreeSet.FinalizeAdapter(var V: T);
begin
  GetElementManager.FinalizeManagedElementsUnchecked(@V, 1);
end;

function TRBTreeSet.PtrIter: TPtrIter;
begin
  Result.Init(Self, @IterGetCurrent, @IterMoveNext, @IterMovePrev, nil);
end;

function TRBTreeSet.GetCount: SizeUInt;
begin
  Result := FTree.GetCount;
end;

procedure TRBTreeSet.Clear;
begin
  FTree.Clear;
end;

procedure TRBTreeSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LIter: TPtrIter;
  PE: ^T;
  P: ^T;
begin
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
  if FTree.GetCount = 0 then Exit;
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

constructor TRBTreeSet.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  // init range state
  FRangeActive := False;
  FRangeStartNode := nil;
  FillChar(FRangeLeftValue, SizeOf(FRangeLeftValue), 0);
  FillChar(FRangeRightValue, SizeOf(FRangeRightValue), 0);
  FRangeInclusiveRight := False;
  // create engine with adapters
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

constructor TRBTreeSet.Create;
begin
  inherited Create(GetRtlAllocator(), nil);
  // init range state
  FRangeActive := False;
  FRangeStartNode := nil;
  FillChar(FRangeLeftValue, SizeOf(FRangeLeftValue), 0);
  FillChar(FRangeRightValue, SizeOf(FRangeRightValue), 0);
  FRangeInclusiveRight := False;
  // create engine with adapters
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

constructor TRBTreeSet.Create(aAllocator: IAllocator);
begin
  inherited Create(aAllocator, nil);
  // init range state
  FRangeActive := False;
  FRangeStartNode := nil;
  FillChar(FRangeLeftValue, SizeOf(FRangeLeftValue), 0);
  FillChar(FRangeRightValue, SizeOf(FRangeRightValue), 0);
  FRangeInclusiveRight := False;
  // create engine with adapters
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

destructor TRBTreeSet.Destroy;
begin
  FTree.Free;
  inherited Destroy;
end;

function TRBTreeSet.Insert(const AValue: T): Boolean;
begin
  Result := FTree.InsertUnique(AValue);
end;

function TRBTreeSet.ContainsKey(const AValue: T): Boolean;
begin
  Result := FTree.Contains(AValue);
end;

function TRBTreeSet.Remove(const AValue: T): Boolean;
begin
  Result := FTree.Remove(AValue);
end;

function TRBTreeSet.LowerBound(const AValue: T; out OutValue: T): Boolean;
begin
  Result := FTree.LowerBound(AValue, OutValue);
end;

function TRBTreeSet.UpperBound(const AValue: T; out OutValue: T): Boolean;
begin
  Result := FTree.UpperBound(AValue, OutValue);
end;

function TRBTreeSet.Min(out OutValue: T): Boolean;
begin
  Result := FTree.Min(OutValue);
end;

function TRBTreeSet.Max(out OutValue: T): Boolean;
begin
  Result := FTree.Max(OutValue);
end;

function TRBTreeSet.IterateRange(const L, R: T; InclusiveRight: Boolean): specialize TIter<T>;
var
  LPtr: TPtrIter;
begin
  FRangeActive := True;
  FRangeInclusiveRight := InclusiveRight;
  FRangeLeftValue := L;
  FRangeRightValue := R;
  FRangeStartNode := nil;
  LPtr.Init(Self, @RangeIterGetCurrent, @RangeIterMoveNext, @RangeIterMovePrev, nil);
  Result.Init(LPtr);
end;

end.
