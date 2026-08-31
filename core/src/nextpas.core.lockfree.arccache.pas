{******************************************************************************
  nextpas.core.lockfree.arccache

  ARC Cache: 自适应替换缓存 (Adaptive Replacement Cache)

  算法: Megiddo & Modha, "ARC: A Self-Tuning, Low Overhead Replacement Cache" (2003)

  复杂度:
    - Get: O(n) — 链表遍历（n 为缓存大小）
    - Put: O(n)
    - 空间: O(capacity)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.arccache;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

type
  TARCCacheStatus = (
    arcOk = 0,
    arcClosed = 1,
    arcNotFound = 2
  );

  PARCNode = ^TARCNode;
  TARCNode = record
    FKey: UInt64;
    FValue: UInt64;
    FPrev: PARCNode;
    FNext: PARCNode;
  end;

  TARCCacheImpl = class
  private
    FCapacity: Integer;
    FP: Integer;
    FT1Size: Integer;
    FT2Size: Integer;
    FB1Size: Integer;
    FB2Size: Integer;
    FT1Head, FT1Tail: PARCNode;
    FT2Head, FT2Tail: PARCNode;
    FB1Head, FB1Tail: PARCNode;
    FB2Head, FB2Tail: PARCNode;
    FLock: Int32;
    FClosed: Int32;

    function FindInList(AHead, ATail: PARCNode; AKey: UInt64): PARCNode;
    procedure ListRemove(ANode: PARCNode);
    procedure ListPushFront(AHead: PARCNode; ANode: PARCNode);
    function ListPopTail(ATail: PARCNode): PARCNode;
    procedure Replace(AInB1: Boolean);
    function NewNode(AKey, AValue: UInt64): PARCNode;
    procedure DisposeList(AHead: PARCNode);
    procedure Lock;
    procedure Unlock;
  public
    constructor Create(ACapacity: UInt32 = 256);
    destructor Destroy; override;

    function Get(AKey: UInt64; out AValue: UInt64): TARCCacheStatus;
    function Put(AKey, AValue: UInt64): TARCCacheStatus;
    function GetSize: Integer;
    function GetCapacity: Integer; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors;

procedure TARCCacheImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TARCCacheImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TARCCacheImpl.NewNode(AKey, AValue: UInt64): PARCNode;
begin
  New(Result);
  Result^.FKey := AKey;
  Result^.FValue := AValue;
  Result^.FPrev := nil;
  Result^.FNext := nil;
end;

procedure TARCCacheImpl.DisposeList(AHead: PARCNode);
var
  LCur, LNext: PARCNode;
begin
  if AHead = nil then
    Exit;
  LCur := AHead^.FNext;
  while LCur <> nil do
  begin
    LNext := LCur^.FNext;
    Dispose(LCur);
    LCur := LNext;
  end;
  Dispose(AHead);
end;

constructor TARCCacheImpl.Create(ACapacity: UInt32);
begin
  inherited Create;
  if ACapacity > UInt32(High(Integer)) then
    raise EArgumentError.Create('TARCCache: capacity exceeds High(Integer)');
  if ACapacity < 4 then
    ACapacity := 4;
  FCapacity := ACapacity;
  FP := 0;
  FT1Size := 0;
  FT2Size := 0;
  FB1Size := 0;
  FB2Size := 0;

  FT1Head := NewNode(0, 0);
  FT1Tail := NewNode(0, 0);
  FT1Head^.FNext := FT1Tail;
  FT1Tail^.FPrev := FT1Head;

  FT2Head := NewNode(0, 0);
  FT2Tail := NewNode(0, 0);
  FT2Head^.FNext := FT2Tail;
  FT2Tail^.FPrev := FT2Head;

  FB1Head := NewNode(0, 0);
  FB1Tail := NewNode(0, 0);
  FB1Head^.FNext := FB1Tail;
  FB1Tail^.FPrev := FB1Head;

  FB2Head := NewNode(0, 0);
  FB2Tail := NewNode(0, 0);
  FB2Head^.FNext := FB2Tail;
  FB2Tail^.FPrev := FB2Head;

  FLock := 0;
  FClosed := 0;
end;

destructor TARCCacheImpl.Destroy;
begin
  DisposeList(FT1Head);
  DisposeList(FT2Head);
  DisposeList(FB1Head);
  DisposeList(FB2Head);
  inherited Destroy;
end;

function TARCCacheImpl.FindInList(AHead, ATail: PARCNode; AKey: UInt64): PARCNode;
var
  LCur: PARCNode;
begin
  LCur := AHead^.FNext;
  while LCur <> ATail do
  begin
    if LCur^.FKey = AKey then
      Exit(LCur);
    LCur := LCur^.FNext;
  end;
  Result := nil;
end;

procedure TARCCacheImpl.ListRemove(ANode: PARCNode);
begin
  ANode^.FPrev^.FNext := ANode^.FNext;
  ANode^.FNext^.FPrev := ANode^.FPrev;
  ANode^.FPrev := nil;
  ANode^.FNext := nil;
end;

procedure TARCCacheImpl.ListPushFront(AHead: PARCNode; ANode: PARCNode);
begin
  ANode^.FNext := AHead^.FNext;
  ANode^.FPrev := AHead;
  AHead^.FNext^.FPrev := ANode;
  AHead^.FNext := ANode;
end;

function TARCCacheImpl.ListPopTail(ATail: PARCNode): PARCNode;
begin
  Result := ATail^.FPrev;
  if (Result = nil) or (Result^.FPrev = nil) then
    Exit(nil);
  ListRemove(Result);
end;

procedure TARCCacheImpl.Replace(AInB1: Boolean);
var
  LNode: PARCNode;
begin
  if ((FT1Size > FP) or ((not AInB1) and (FT1Size = FP))) and (FT1Size > 0) then
  begin
    LNode := ListPopTail(FT1Tail);
    if LNode <> nil then
    begin
      Dec(FT1Size);
      ListPushFront(FB1Head, LNode);
      Inc(FB1Size);
    end;
  end
  else if FT2Size > 0 then
  begin
    LNode := ListPopTail(FT2Tail);
    if LNode <> nil then
    begin
      Dec(FT2Size);
      ListPushFront(FB2Head, LNode);
      Inc(FB2Size);
    end;
  end;
end;

function TARCCacheImpl.Get(AKey: UInt64; out AValue: UInt64): TARCCacheStatus;
var
  LNode, LGhost: PARCNode;
  LDelta: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(arcClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(arcClosed);

    { Check T1 }
    LNode := FindInList(FT1Head, FT1Tail, AKey);
    if LNode <> nil then
    begin
      ListRemove(LNode);
      Dec(FT1Size);
      ListPushFront(FT2Head, LNode);
      Inc(FT2Size);
      AValue := LNode^.FValue;
      Exit(arcOk);
    end;

    { Check T2 }
    LNode := FindInList(FT2Head, FT2Tail, AKey);
    if LNode <> nil then
    begin
      ListRemove(LNode);
      ListPushFront(FT2Head, LNode);
      AValue := LNode^.FValue;
      Exit(arcOk);
    end;

    { Check B1 (ghost hit → adapt) }
    LGhost := FindInList(FB1Head, FB1Tail, AKey);
    if LGhost <> nil then
    begin
      if FB2Size > 0 then
        LDelta := FB1Size div FB2Size
      else
        LDelta := FB1Size;
      if LDelta < 1 then
        LDelta := 1;
      FP := FP + LDelta;
      if FP > FCapacity then
        FP := FCapacity;
      ListRemove(LGhost);
      Dispose(LGhost);
      Dec(FB1Size);
      Result := arcNotFound;
      Exit;
    end;

    { Check B2 (ghost hit → adapt) }
    LGhost := FindInList(FB2Head, FB2Tail, AKey);
    if LGhost <> nil then
    begin
      if FB1Size > 0 then
        LDelta := FB2Size div FB1Size
      else
        LDelta := FB2Size;
      if LDelta < 1 then
        LDelta := 1;
      FP := FP - LDelta;
      if FP < 0 then
        FP := 0;
      ListRemove(LGhost);
      Dispose(LGhost);
      Dec(FB2Size);
      Result := arcNotFound;
      Exit;
    end;

    Result := arcNotFound;
  finally
    Unlock;
  end;
end;

function TARCCacheImpl.Put(AKey, AValue: UInt64): TARCCacheStatus;
var
  LNode: PARCNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(arcClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(arcClosed);

    { Check if key exists in T1 or T2 }
    LNode := FindInList(FT1Head, FT1Tail, AKey);
    if LNode <> nil then
    begin
      LNode^.FValue := AValue;
      ListRemove(LNode);
      Dec(FT1Size);
      ListPushFront(FT2Head, LNode);
      Inc(FT2Size);
      Exit(arcOk);
    end;

    LNode := FindInList(FT2Head, FT2Tail, AKey);
    if LNode <> nil then
    begin
      LNode^.FValue := AValue;
      ListRemove(LNode);
      ListPushFront(FT2Head, LNode);
      Exit(arcOk);
    end;

    { New key: need space }
    if (FT1Size + FT2Size) >= FCapacity then
      Replace(False);

    { Trim ghost lists if needed }
    while (FB1Size + FB2Size) > FCapacity do
    begin
      if FB2Size > FB1Size then
      begin
        LNode := ListPopTail(FB2Tail);
        if LNode <> nil then
        begin
          Dispose(LNode);
          Dec(FB2Size);
        end;
      end
      else
      begin
        LNode := ListPopTail(FB1Tail);
        if LNode <> nil then
        begin
          Dispose(LNode);
          Dec(FB1Size);
        end;
      end;
    end;

    { Allocate new node }
    LNode := NewNode(AKey, AValue);
    ListPushFront(FT1Head, LNode);
    Inc(FT1Size);

    Result := arcOk;
  finally
    Unlock;
  end;
end;

function TARCCacheImpl.GetSize: Integer;
begin
  Lock;
  try
    Result := FT1Size + FT2Size;
  finally
    Unlock;
  end;
end;

function TARCCacheImpl.GetCapacity: Integer; inline;
begin
  Result := FCapacity;
end;

procedure TARCCacheImpl.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

function TARCCacheImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
