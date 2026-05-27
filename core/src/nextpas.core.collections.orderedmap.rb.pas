unit nextpas.core.collections.orderedmap.rb;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - RB tree map uses node-based storage
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.orderedmap.rb.base,
  nextpas.core.collections.orderedmap.rb.intf,
  nextpas.core.collections.element_manager,
  nextpas.core.mem.allocator,
  nextpas.core.collections.tree.rb;

type
  // 红黑树 OrderedMap（薄适配 TRBTreeCore + 集成 TGenericCollection 以复用迭代框架）。
  generic TRBTreeMap<K,V> = class(specialize TGenericCollection<specialize TRBMapEntry<K,V>>, specialize IRBTreeMap<K,V>)
  public
    type
      TEntry = specialize TRBMapEntry<K,V>;
      TRBCore  = specialize TRBTreeCore<TEntry>;
      TRBNode  = TRBCore.PNode;
      TKeyCmp  = specialize TCompareFunc<K>;
      PEntry   = ^TEntry;
  private
    FTree: TRBCore;
    FKeyCmp: TKeyCmp;
    // range state（非重入临时字段）
    FRangeActive: Boolean;
    FRangeInclusiveRight: Boolean;
    FRangeL: K;
    FRangeR: K;
    function IterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function IterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function IterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    // keys/values iterator callbacks
    function KeyIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function KeyIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function KeyIterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function ValIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function ValIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function ValIterMovePrev(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}

    function CompareAdapter(const L, R: TEntry; aData: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    procedure FinalizeAdapter(var E: TEntry); {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
    function MakeEntry(const AKey: K): TEntry; {$IFDEF FAFAFA_CORE_INLINE} inline; {$ENDIF}
  public
    constructor Create(aKeyComparer: TKeyCmp); reintroduce; overload;
    constructor Create(aKeyComparer: TKeyCmp; aAllocator: IAllocator); reintroduce; overload;
    destructor Destroy; override;

    // 基本操作
    function InsertOrAssign(const AKey: K; const AValue: V): Boolean; // True=插入，False=更新
    function TryAdd(const AKey: K; const AValue: V): Boolean;       // 仅在不存在时插入
    function TryUpdate(const AKey: K; const AValue: V): Boolean;    // 仅在存在时更新
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Remove(const AKey: K): Boolean;
    function Extract(const AKey: K; out OutEntry: TEntry): Boolean; // 移除并返回条目

    // 边界查询（基于 key）
    function LowerBoundKey(const AKey: K; out OutEntry: TEntry): Boolean;
    function UpperBoundKey(const AKey: K; out OutEntry: TEntry): Boolean;

    // 覆写抽象方法（最小实现）
    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;
    procedure DoReverse; override;
    function  IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override;

    // Keys/Values 视图（投影迭代）
    function Keys: specialize TIter<K>;
    function Values: specialize TIter<V>;

    // 最小范围遍历（key 区间）
    function IterateRange(const L, R: K; InclusiveRight: Boolean = False): TPtrIter;
  end;

implementation

{ TRBTreeMap<K,V> }

function TRBTreeMap.CompareAdapter(const L, R: TEntry; aData: Pointer): SizeInt;
begin
  if not Assigned(FKeyCmp) then
    raise EInvalidOperation.Create('TRBTreeMap: key comparer is nil');
  Result := FKeyCmp(L.Key, R.Key, aData);
  if Result < 0 then Exit(-1) else if Result > 0 then Exit(1) else Exit(0);
end;

procedure TRBTreeMap.FinalizeAdapter(var E: TEntry);
begin
  // 直接对记录进行 Finalize，托管类型自动处理；非托管类型为 no-op
  Finalize(E);
end;

function TRBTreeMap.MakeEntry(const AKey: K): TEntry;
begin
  Result.Key := AKey;
  {$IFDEF VER3_2}FillChar(Result.Value, SizeOf(Result.Value), 0);{$ENDIF}
end;

constructor TRBTreeMap.Create(aKeyComparer: TKeyCmp);
begin
  inherited Create(GetRtlAllocator(), nil);
  FKeyCmp := aKeyComparer;
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

constructor TRBTreeMap.Create(aKeyComparer: TKeyCmp; aAllocator: IAllocator);
begin
  inherited Create(aAllocator, nil);
  FKeyCmp := aKeyComparer;
  FTree := TRBCore.Create(@CompareAdapter, nil, @FinalizeAdapter);
end;

destructor TRBTreeMap.Destroy;
begin
  FTree.Free;
  inherited Destroy;
end;

function TRBTreeMap.InsertOrAssign(const AKey: K; const AValue: V): Boolean;
var
  E: TEntry; N: TRBNode; C: SizeInt;
begin
  E.Key := AKey; E.Value := AValue;
  // 先定位节点，看是否存在相同 key
  N := FTree.LowerBoundNode(E);
  if N <> nil then
  begin
    C := FKeyCmp(N^.Data.Key, AKey, nil);
    if C = 0 then
    begin
      N^.Data.Value := AValue; // 更新
      Exit(False); // 返回 False 表示是更新
    end;
  end;
  // 不存在则插入
  Result := FTree.InsertUnique(E);
end;

function TRBTreeMap.TryAdd(const AKey: K; const AValue: V): Boolean;
var E: TEntry; N: TRBNode; C: SizeInt;
begin
  E.Key := AKey; E.Value := AValue;
  N := FTree.LowerBoundNode(E);
  if N <> nil then
  begin
    C := FKeyCmp(N^.Data.Key, AKey, nil);
    if C = 0 then Exit(False);
  end;
  Result := FTree.InsertUnique(E);
end;

function TRBTreeMap.TryUpdate(const AKey: K; const AValue: V): Boolean;
var N: TRBNode; E: TEntry; C: SizeInt;
begin
  E := MakeEntry(AKey);
  N := FTree.LowerBoundNode(E);
  if N = nil then Exit(False);
  C := FKeyCmp(N^.Data.Key, AKey, nil);
  if C = 0 then begin N^.Data.Value := AValue; Exit(True); end;
  Result := False;
end;

function TRBTreeMap.Extract(const AKey: K; out OutEntry: TEntry): Boolean;
var N: TRBNode; E: TEntry; C: SizeInt;
begin
  E := MakeEntry(AKey);
  N := FTree.LowerBoundNode(E);
  if N = nil then Exit(False);
  C := FKeyCmp(N^.Data.Key, AKey, nil);
  if C <> 0 then Exit(False);
  OutEntry := N^.Data;
  Result := FTree.Remove(N^.Data);
end;

function TRBTreeMap.LowerBoundKey(const AKey: K; out OutEntry: TEntry): Boolean;
var E: TEntry;
begin
  E := MakeEntry(AKey);
  Result := FTree.LowerBound(E, OutEntry);
end;

function TRBTreeMap.UpperBoundKey(const AKey: K; out OutEntry: TEntry): Boolean;
var E: TEntry;
begin
  E := MakeEntry(AKey);
  Result := FTree.UpperBound(E, OutEntry);
end;


function TRBTreeMap.TryGetValue(const AKey: K; out AValue: V): Boolean;
var N: TRBNode; E: TEntry; C: SizeInt;
begin
  E := MakeEntry(AKey);
  N := FTree.LowerBoundNode(E);
  if N = nil then Exit(False);
  C := FKeyCmp(N^.Data.Key, AKey, nil);
  if C = 0 then begin AValue := N^.Data.Value; Exit(True); end;
  Result := False;
end;

function TRBTreeMap.ContainsKey(const AKey: K): Boolean;
var tmp: V; begin Exit(TryGetValue(AKey, tmp)); end;

function TRBTreeMap.Remove(const AKey: K): Boolean;
var E: TEntry;
begin
  E := MakeEntry(AKey);
  Result := FTree.Remove(E);
end;

procedure TRBTreeMap.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var LIter: TPtrIter; P: PEntry; PE: PEntry;
begin
  if aDst = nil then Exit;
  PE := aDst;
  LIter := PtrIter;
  while (aCount > 0) and LIter.MoveNext do
  begin
    P := LIter.GetCurrent;
    PE^ := P^;
    Inc(PE);
    Dec(aCount);
  end;
end;

procedure TRBTreeMap.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var I: SizeUInt; P: PEntry;
begin
  if (aSrc = nil) or (aElementCount = 0) then Exit;
  P := aSrc;
  for I := 0 to aElementCount - 1 do
  begin
    InsertOrAssign(P^.Key, P^.Value);
    Inc(P);
  end;
end;

procedure TRBTreeMap.AppendToUnChecked(const aDst: TCollection);
var LIter: TPtrIter; PElem: PEntry;
begin
  if FTree.GetCount = 0 then Exit;
  LIter := PtrIter;
  while LIter.MoveNext do
  begin
    PElem := LIter.GetCurrent;
    aDst.AppendUnChecked(PElem, 1);
  end;
end;

procedure TRBTreeMap.DoReverse;
begin
  // Map 的 Reverse 为 no-op（顺序由迭代器控制）
end;

function TRBTreeMap.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // 树结构不使用连续外部缓冲区
  Result := False;
end;

procedure TRBTreeMap.DoZero;
begin
  Clear;
end;

function TRBTreeMap.KeyIterGetCurrent(aIter: PPtrIter): Pointer;
var N: TRBNode;
begin
  N := TRBNode(aIter^.Data);
  if N = nil then Exit(nil);
  Exit(@N^.Data.Key);
end;

function TRBTreeMap.KeyIterMoveNext(aIter: PPtrIter): Boolean;
var N: TRBNode;
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
  Exit(N <> nil);
end;

function TRBTreeMap.KeyIterMovePrev(aIter: PPtrIter): Boolean;
var N: TRBNode;
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
  Exit(N <> nil);
end;

function TRBTreeMap.ValIterGetCurrent(aIter: PPtrIter): Pointer;
var N: TRBNode;
begin
  N := TRBNode(aIter^.Data);
  if N = nil then Exit(nil);
  Exit(@N^.Data.Value);
end;

function TRBTreeMap.ValIterMoveNext(aIter: PPtrIter): Boolean;
begin
  Result := KeyIterMoveNext(aIter);
end;

function TRBTreeMap.ValIterMovePrev(aIter: PPtrIter): Boolean;
begin
  Result := KeyIterMovePrev(aIter);
end;

function TRBTreeMap.Keys: specialize TIter<K>;
var P: TPtrIter;
begin
  P.Init(Self, @KeyIterGetCurrent, @KeyIterMoveNext, @KeyIterMovePrev, nil);
  Result.Init(P);
end;

function TRBTreeMap.Values: specialize TIter<V>;
var P: TPtrIter;
begin
  P.Init(Self, @ValIterGetCurrent, @ValIterMoveNext, @ValIterMovePrev, nil);
  Result.Init(P);
end;
function TRBTreeMap.GetCount: SizeUInt;
begin
  Result := FTree.GetCount;
end;

procedure TRBTreeMap.Clear;
begin
  FTree.Clear;
end;

function TRBTreeMap.IterGetCurrent(aIter: PPtrIter): Pointer;
var N: TRBNode;
begin
  N := TRBNode(aIter^.Data);
  if N = nil then Exit(nil);
  Exit(@N^.Data);
end;

function TRBTreeMap.IterMoveNext(aIter: PPtrIter): Boolean;
var N: TRBNode;
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
  Exit(N <> nil);
end;

function TRBTreeMap.IterMovePrev(aIter: PPtrIter): Boolean;
var N: TRBNode;
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
  Exit(N <> nil);
end;

function TRBTreeMap.PtrIter: TPtrIter;
begin
  Result.Init(Self, @IterGetCurrent, @IterMoveNext, @IterMovePrev, nil);
end;

function TRBTreeMap.IterateRange(const L, R: K; InclusiveRight: Boolean): TPtrIter;
begin
  FRangeActive := True;
  FRangeInclusiveRight := InclusiveRight;
  FRangeL := L; FRangeR := R;
  Result.Init(Self,
    function(aIter: PPtrIter): Pointer
    var N: TRBNode;
    begin
      if not FRangeActive then Exit(nil);
      N := TRBNode(aIter^.Data);
      if N = nil then Exit(nil);
      Exit(@N^.Data);
    end,
    function(aIter: PPtrIter): Boolean
    var N: TRBNode; C: SizeInt; E: TEntry;
    begin
      if not FRangeActive then Exit(False);
      if not aIter^.Started then
      begin
        aIter^.Started := True;
        // empty when L > R
        if FKeyCmp(FRangeL, FRangeR, nil) > 0 then begin aIter^.Data := nil; Exit(False); end;
        E := MakeEntry(FRangeL);
        N := FTree.LowerBoundNode(E);
        aIter^.Data := N;
        if N <> nil then
        begin
          C := FKeyCmp(N^.Data.Key, FRangeR, nil);
          if (C > 0) or ((C = 0) and (not FRangeInclusiveRight)) then
          begin aIter^.Data := nil; Exit(False); end;
        end;
        Exit(N <> nil);
      end;
      N := TRBNode(aIter^.Data);
      if N = nil then Exit(False);
      N := FTree.Successor(N);
      if N <> nil then
      begin
        C := FKeyCmp(N^.Data.Key, FRangeR, nil);
        if (C > 0) or ((C = 0) and (not FRangeInclusiveRight)) then
        begin aIter^.Data := nil; Exit(False); end;
      end;
      aIter^.Data := N;
      Exit(N <> nil);
    end,
    function(aIter: PPtrIter): Boolean
    var N: TRBNode; C: SizeInt; E: TEntry;
    begin
      if not FRangeActive then Exit(False);
      if not aIter^.Started then
      begin
        aIter^.Started := True;
        E := MakeEntry(FRangeR);
        N := FTree.LowerBoundNode(E);
        if (N = nil) or ((N <> nil) and (FKeyCmp(N^.Data.Key, FRangeR, nil) > 0)) then
          N := FTree.Predecessor(N);
        aIter^.Data := N;
        if N <> nil then
        begin
          C := FKeyCmp(N^.Data.Key, FRangeL, nil);
          if C < 0 then begin aIter^.Data := nil; Exit(False); end;
        end;
        Exit(N <> nil);
      end;
      N := TRBNode(aIter^.Data);
      if N = nil then Exit(False);
      N := FTree.Predecessor(N);
      if N <> nil then
      begin
        C := FKeyCmp(N^.Data.Key, FRangeL, nil);
        if C < 0 then begin aIter^.Data := nil; Exit(False); end;
      end;
      aIter^.Data := N;
      Exit(N <> nil);
    end,
    nil);
end;

end.
