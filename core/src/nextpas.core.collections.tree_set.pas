unit nextpas.core.collections.tree_set;

{$I nextpas.core.settings.inc}
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.tree.rb,
  nextpas.core.mem.allocator;

type
  generic TTreeSet<T> = class(specialize TGenericCollection<T>, specialize ITreeSet<T>)
  private
    type
      TRBCore = specialize TRBTreeCore<T>;
      TRBNode = TRBCore.PNode;
  private
    FTree: TRBCore;

    function IterGetCurrent(aIter: PPtrIter): Pointer;
    function IterMoveNext(aIter: PPtrIter): Boolean;
    function IterMovePrev(aIter: PPtrIter): Boolean;

    function CompareAdapter(const L, R: T; aData: Pointer): SizeInt;
    procedure FinalizeAdapter(var V: T);
  protected
    function PtrIter: TPtrIter; override;
    function GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;
    procedure DoReverse; override;
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override;
  public
    constructor Create; reintroduce; overload;
    constructor Create(aAllocator: IAllocator); reintroduce; overload;
    constructor Create(aAllocator: IAllocator; aData: Pointer); override;
    destructor Destroy; override;

    function Add(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;
    function Contains(const AValue: T): Boolean; overload;

    function LowerBound(const AValue: T; out OutValue: T): Boolean;
    function UpperBound(const AValue: T; out OutValue: T): Boolean;
    function Min(out OutValue: T): Boolean;
    function Max(out OutValue: T): Boolean;

    function Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
  end;

implementation

{ TTreeSet<T> }

function TTreeSet.IterGetCurrent(aIter: PPtrIter): Pointer;
var
  N: TRBNode;
begin
  N := TRBNode(aIter^.Data);
  if N = nil then Exit(nil);
  Result := @N^.Data;
end;

function TTreeSet.IterMoveNext(aIter: PPtrIter): Boolean;
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
  if N = nil then Exit(False);
  N := FTree.Successor(N);
  aIter^.Data := N;
  Result := N <> nil;
end;

function TTreeSet.IterMovePrev(aIter: PPtrIter): Boolean;
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
  if N = nil then Exit(False);
  N := FTree.Predecessor(N);
  aIter^.Data := N;
  Result := N <> nil;
end;

function TTreeSet.CompareAdapter(const L, R: T; aData: Pointer): SizeInt;
begin
  Result := FInternalComparer(L, R);
  if Result < 0 then Exit(-1)
  else if Result > 0 then Exit(1)
  else Exit(0);
end;

procedure TTreeSet.FinalizeAdapter(var V: T);
begin
  GetElementManager.FinalizeManagedElementsUnchecked(@V, 1);
end;

{ TGenericCollection overrides }

function TTreeSet.PtrIter: TPtrIter;
begin
  Result.Init(Self, @IterGetCurrent, @IterMoveNext, @IterMovePrev, nil);
end;

function TTreeSet.GetCount: SizeUInt;
begin
  Result := FTree.GetCount;
end;

procedure TTreeSet.Clear;
begin
  FTree.Clear;
end;

procedure TTreeSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LIter: TPtrIter;
  PE, P: ^T;
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

procedure TTreeSet.AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LIdx: SizeUInt;
  P: ^T;
begin
  if (aSrc = nil) or (aElementCount = 0) then Exit;
  P := aSrc;
  for LIdx := 1 to aElementCount do
  begin
    FTree.InsertUnique(P^);
    Inc(P);
  end;
end;

procedure TTreeSet.AppendToUnchecked(const aDst: TCollection);
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

function TTreeSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := False;
end;

procedure TTreeSet.DoZero;
begin
  Clear;
end;

procedure TTreeSet.DoReverse;
begin
  // no-op: iteration order is determined by comparator
end;

{ Constructors / Destructor }

constructor TTreeSet.Create;
begin
  Create(GetRtlAllocator(), nil);
end;

constructor TTreeSet.Create(aAllocator: IAllocator);
begin
  Create(aAllocator, nil);
end;

constructor TTreeSet.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

destructor TTreeSet.Destroy;
begin
  FTree.Free;
  inherited Destroy;
end;

{ ITreeSet<T> }

function TTreeSet.Add(const AValue: T): Boolean;
begin
  Result := FTree.InsertUnique(AValue);
end;

function TTreeSet.Remove(const AValue: T): Boolean;
begin
  Result := FTree.Remove(AValue);
end;

function TTreeSet.Contains(const AValue: T): Boolean;
begin
  Result := FTree.Contains(AValue);
end;

function TTreeSet.LowerBound(const AValue: T; out OutValue: T): Boolean;
begin
  Result := FTree.LowerBound(AValue, OutValue);
end;

function TTreeSet.UpperBound(const AValue: T; out OutValue: T): Boolean;
begin
  Result := FTree.UpperBound(AValue, OutValue);
end;

function TTreeSet.Min(out OutValue: T): Boolean;
begin
  Result := FTree.Min(OutValue);
end;

function TTreeSet.Max(out OutValue: T): Boolean;
begin
  Result := FTree.Max(OutValue);
end;

function TTreeSet.Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  LResult: specialize TTreeSet<T>;
  LElement: T;
begin
  LResult := specialize TTreeSet<T>.Create;
  for LElement in Self do
    LResult.Add(LElement);
  for LElement in Other do
    LResult.Add(LElement);
  Result := LResult;
end;

function TTreeSet.Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  LResult: specialize TTreeSet<T>;
  LElement: T;
begin
  LResult := specialize TTreeSet<T>.Create;
  for LElement in Self do
    if Other.Contains(LElement) then
      LResult.Add(LElement);
  Result := LResult;
end;

function TTreeSet.Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  LResult: specialize TTreeSet<T>;
  LElement: T;
begin
  LResult := specialize TTreeSet<T>.Create;
  for LElement in Self do
    if not Other.Contains(LElement) then
      LResult.Add(LElement);
  Result := LResult;
end;

end.
