unit nextpas.core.lockfree.treap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TTreapResult = (trInserted, trUpdated, trRemoved, trNotFound, trExists, trClosed);
  TTreapForEachCallback = procedure(AKey, AValue: Int64);

  PTreapNode = ^TTreapNode;
  TTreapNode = record
    Key: Int64;
    Value: Int64;
    Priority: UInt64;
    Left, Right: PTreapNode;
    Size: Int32;
  end;

  {** @desc 并发 Treap (随机化 BST)
    @details 期望 O(log n) 查找/插入/删除。
      使用随机优先级维护堆性质，同时保持 BST 性质。
  }
  TConcurrentTreap = class
  private
    FRoot: PTreapNode;
    FCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    FSeed: UInt64;
    procedure Lock;
    procedure Unlock;
    function NextRandom: UInt64;
    function CreateNode(AKey, AValue: Int64): PTreapNode;
    procedure FreeNode(ANode: PTreapNode);
    function RotateRight(ANode: PTreapNode): PTreapNode;
    function RotateLeft(ANode: PTreapNode): PTreapNode;
    function InsertNode(ANode: PTreapNode; AKey, AValue: Int64): PTreapNode;
    function DeleteNode(ANode: PTreapNode; AKey: Int64): PTreapNode;
    function FindNode(ANode: PTreapNode; AKey: Int64): PTreapNode;
    procedure ClearSubtree(ANode: PTreapNode);
    procedure ForEachSubtree(ANode: PTreapNode; ACallback: TTreapForEachCallback);
    procedure UpdateSize(ANode: PTreapNode);
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(AKey, AValue: Int64): TTreapResult;
    function Remove(AKey: Int64): TTreapResult;
    function Find(AKey: Int64; out AValue: Int64): Boolean;
    function Contains(AKey: Int64): Boolean;
    function GetCount: Int64;
    procedure ForEach(ACallback: TTreapForEachCallback);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentTreap.Create;
begin
  inherited Create;
  FRoot := nil;
  FCount := 0;
  FLock := 0;
  FClosed := 0;
  FSeed := 123456789;
end;

destructor TConcurrentTreap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TConcurrentTreap.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 1, 0) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TConcurrentTreap.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentTreap.NextRandom: UInt64;
begin
  FSeed := FSeed xor (FSeed shl 13);
  FSeed := FSeed xor (FSeed shr 7);
  FSeed := FSeed xor (FSeed shl 17);
  Result := FSeed;
end;

function TConcurrentTreap.CreateNode(AKey, AValue: Int64): PTreapNode;
begin
  Result := AllocMem(SizeOf(TTreapNode));
  Result^.Key := AKey;
  Result^.Value := AValue;
  Result^.Priority := NextRandom;
  Result^.Left := nil;
  Result^.Right := nil;
  Result^.Size := 1;
end;

procedure TConcurrentTreap.FreeNode(ANode: PTreapNode);
begin
  if ANode <> nil then
    FreeMem(ANode);
end;

procedure TConcurrentTreap.UpdateSize(ANode: PTreapNode);
var
  LLeftSize, LRightSize: Int32;
begin
  if ANode = nil then
    Exit;
  LLeftSize := 0;
  LRightSize := 0;
  if ANode^.Left <> nil then
    LLeftSize := ANode^.Left^.Size;
  if ANode^.Right <> nil then
    LRightSize := ANode^.Right^.Size;
  ANode^.Size := 1 + LLeftSize + LRightSize;
end;

function TConcurrentTreap.RotateRight(ANode: PTreapNode): PTreapNode;
var
  LLeft: PTreapNode;
begin
  LLeft := ANode^.Left;
  ANode^.Left := LLeft^.Right;
  LLeft^.Right := ANode;
  UpdateSize(ANode);
  UpdateSize(LLeft);
  Result := LLeft;
end;

function TConcurrentTreap.RotateLeft(ANode: PTreapNode): PTreapNode;
var
  LRight: PTreapNode;
begin
  LRight := ANode^.Right;
  ANode^.Right := LRight^.Left;
  LRight^.Left := ANode;
  UpdateSize(ANode);
  UpdateSize(LRight);
  Result := LRight;
end;

function TConcurrentTreap.InsertNode(ANode: PTreapNode; AKey, AValue: Int64): PTreapNode;
begin
  if ANode = nil then
  begin
    AtomicFetchAdd64(FCount, 1, moRelaxed);
    Exit(CreateNode(AKey, AValue));
  end;
  if AKey = ANode^.Key then
  begin
    ANode^.Value := AValue;
    Exit(ANode);
  end;
  if AKey < ANode^.Key then
  begin
    ANode^.Left := InsertNode(ANode^.Left, AKey, AValue);
    if ANode^.Left^.Priority > ANode^.Priority then
      ANode := RotateRight(ANode);
  end
  else
  begin
    ANode^.Right := InsertNode(ANode^.Right, AKey, AValue);
    if ANode^.Right^.Priority > ANode^.Priority then
      ANode := RotateLeft(ANode);
  end;
  UpdateSize(ANode);
  Result := ANode;
end;

function TConcurrentTreap.DeleteNode(ANode: PTreapNode; AKey: Int64): PTreapNode;
begin
  if ANode = nil then
    Exit(nil);
  if AKey < ANode^.Key then
    ANode^.Left := DeleteNode(ANode^.Left, AKey)
  else if AKey > ANode^.Key then
    ANode^.Right := DeleteNode(ANode^.Right, AKey)
  else
  begin
    if (ANode^.Left = nil) and (ANode^.Right = nil) then
    begin
      FreeNode(ANode);
      AtomicFetchSub64(FCount, 1, moRelaxed);
      Exit(nil);
    end
    else if (ANode^.Left = nil) then
    begin
      Result := ANode^.Right;
      FreeNode(ANode);
      AtomicFetchSub64(FCount, 1, moRelaxed);
      Exit(Result);
    end
    else if (ANode^.Right = nil) then
    begin
      Result := ANode^.Left;
      FreeNode(ANode);
      AtomicFetchSub64(FCount, 1, moRelaxed);
      Exit(Result);
    end
    else
    begin
      if ANode^.Left^.Priority > ANode^.Right^.Priority then
      begin
        ANode := RotateRight(ANode);
        ANode^.Right := DeleteNode(ANode^.Right, AKey);
      end
      else
      begin
        ANode := RotateLeft(ANode);
        ANode^.Left := DeleteNode(ANode^.Left, AKey);
      end;
    end;
  end;
  UpdateSize(ANode);
  Result := ANode;
end;

function TConcurrentTreap.FindNode(ANode: PTreapNode; AKey: Int64): PTreapNode;
begin
  while ANode <> nil do
  begin
    if AKey = ANode^.Key then
      Exit(ANode)
    else if AKey < ANode^.Key then
      ANode := ANode^.Left
    else
      ANode := ANode^.Right;
  end;
  Result := nil;
end;

function TConcurrentTreap.Insert(AKey, AValue: Int64): TTreapResult;
var
  LOldCount: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(trClosed);
  Lock;
  LOldCount := FCount;
  FRoot := InsertNode(FRoot, AKey, AValue);
  if FCount > LOldCount then
  begin
    Unlock;
    Exit(trInserted);
  end;
  Unlock;
  Result := trUpdated;
end;

function TConcurrentTreap.Remove(AKey: Int64): TTreapResult;
var
  LOldCount: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(trClosed);
  Lock;
  LOldCount := FCount;
  FRoot := DeleteNode(FRoot, AKey);
  if FCount < LOldCount then
  begin
    Unlock;
    Exit(trRemoved);
  end;
  Unlock;
  Result := trNotFound;
end;

function TConcurrentTreap.Find(AKey: Int64; out AValue: Int64): Boolean;
var
  LNode: PTreapNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := 0;
    Exit(False);
  end;
  Lock;
  LNode := FindNode(FRoot, AKey);
  if LNode <> nil then
  begin
    AValue := LNode^.Value;
    Unlock;
    Exit(True);
  end;
  Unlock;
  AValue := 0;
  Result := False;
end;

function TConcurrentTreap.Contains(AKey: Int64): Boolean;
var
  LNode: PTreapNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  Lock;
  LNode := FindNode(FRoot, AKey);
  Unlock;
  Result := LNode <> nil;
end;

function TConcurrentTreap.GetCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

procedure TConcurrentTreap.ForEachSubtree(ANode: PTreapNode; ACallback: TTreapForEachCallback);
begin
  if ANode = nil then
    Exit;
  ForEachSubtree(ANode^.Left, ACallback);
  ACallback(ANode^.Key, ANode^.Value);
  ForEachSubtree(ANode^.Right, ACallback);
end;

procedure TConcurrentTreap.ForEach(ACallback: TTreapForEachCallback);
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  Lock;
  ForEachSubtree(FRoot, ACallback);
  Unlock;
end;

procedure TConcurrentTreap.ClearSubtree(ANode: PTreapNode);
begin
  if ANode = nil then
    Exit;
  ClearSubtree(ANode^.Left);
  ClearSubtree(ANode^.Right);
  FreeNode(ANode);
end;

procedure TConcurrentTreap.Clear;
begin
  Lock;
  ClearSubtree(FRoot);
  FRoot := nil;
  FCount := 0;
  Unlock;
end;

procedure TConcurrentTreap.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentTreap.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
