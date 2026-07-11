unit nextpas.core.lockfree.radix;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TRadixResult = (rdInserted, rdUpdated, rdRemoved, rdNotFound, rdExists, rdClosed);
  TRadixForEachCallback = procedure(const AKey: AnsiString; AValue: Int64);

  PRadixPair = ^TRadixPair;
  TRadixPair = record
    Key: AnsiString;
    Value: Int64;
  end;

  PRadixNode = ^TRadixNode;
  TRadixNode = record
    Prefix: AnsiString;
    Value: Int64;
    IsLeaf: Boolean;
    Children: array of PRadixNode;
    ChildCount: Int32;
  end;

  {** @desc 并发 Radix Tree (压缩前缀树)
    @details O(k) 字符串查找/插入/删除，k 为键长度。
      适用于路由表、IP 查找、自动补全等场景。
  }
  TConcurrentRadixTree = class
  private
    FRoot: PRadixNode;
    FCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    function CreateNode(const APrefix: AnsiString): PRadixNode;
    procedure FreeNode(ANode: PRadixNode);
    function CommonPrefixLen(const A, B: AnsiString): Integer;
    procedure AddChild(AParent: PRadixNode; AChild: PRadixNode);
    procedure RemoveChild(AParent: PRadixNode; AIdx: Integer);
    function FindChild(ANode: PRadixNode; AChar: AnsiChar): Integer;
    procedure ClearSubtree(ANode: PRadixNode);
    procedure ForEachSubtree(ANode: PRadixNode; const APath: AnsiString; ACallback: TRadixForEachCallback);
    procedure CollectSubtree(ANode: PRadixNode; const APath: AnsiString; var APairs: array of TRadixPair; var ACount: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(const AKey: AnsiString; AValue: Int64): TRadixResult;
    function Remove(const AKey: AnsiString): TRadixResult;
    function Find(const AKey: AnsiString; out AValue: Int64): Boolean;
    function Contains(const AKey: AnsiString): Boolean;
    function GetCount: Int64;
    procedure ForEach(ACallback: TRadixForEachCallback);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentRadixTree.Create;
begin
  inherited Create;
  FRoot := CreateNode('');
  FCount := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TConcurrentRadixTree.Destroy;
begin
  Clear;
  FreeNode(FRoot);
  inherited Destroy;
end;

procedure TConcurrentRadixTree.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
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

procedure TConcurrentRadixTree.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentRadixTree.CreateNode(const APrefix: AnsiString): PRadixNode;
begin
  Result := AllocMem(SizeOf(TRadixNode));
  Result^.Prefix := APrefix;
  Result^.Value := 0;
  Result^.IsLeaf := False;
  Result^.ChildCount := 0;
end;

procedure TConcurrentRadixTree.FreeNode(ANode: PRadixNode);
begin
  if ANode <> nil then
  begin
    ANode^.Prefix := '';
    ANode^.Children := nil;
    FreeMem(ANode);
  end;
end;

function TConcurrentRadixTree.CommonPrefixLen(const A, B: AnsiString): Integer;
var
  LLen, LI: Integer;
begin
  LLen := System.Length(A);
  if System.Length(B) < LLen then
    LLen := System.Length(B);
  Result := 0;
  for LI := 1 to LLen do
  begin
    if A[LI] = B[LI] then
      Inc(Result)
    else
      Break;
  end;
end;

procedure TConcurrentRadixTree.AddChild(AParent: PRadixNode; AChild: PRadixNode);
var
  LCap: Integer;
begin
  LCap := System.Length(AParent^.Children);
  if AParent^.ChildCount >= LCap then
  begin
    if LCap = 0 then
      SetLength(AParent^.Children, 4)
    else
      SetLength(AParent^.Children, LCap * 2);
  end;
  AParent^.Children[AParent^.ChildCount] := AChild;
  Inc(AParent^.ChildCount);
end;

procedure TConcurrentRadixTree.RemoveChild(AParent: PRadixNode; AIdx: Integer);
var
  LI: Integer;
begin
  for LI := AIdx to AParent^.ChildCount - 2 do
    AParent^.Children[LI] := AParent^.Children[LI + 1];
  Dec(AParent^.ChildCount);
end;

function TConcurrentRadixTree.FindChild(ANode: PRadixNode; AChar: AnsiChar): Integer;
var
  LI: Integer;
begin
  for LI := 0 to ANode^.ChildCount - 1 do
  begin
    if (ANode^.Children[LI] <> nil) and (System.Length(ANode^.Children[LI]^.Prefix) > 0) and
       (ANode^.Children[LI]^.Prefix[1] = AChar) then
      Exit(LI);
  end;
  Result := -1;
end;

function TConcurrentRadixTree.Insert(const AKey: AnsiString; AValue: Int64): TRadixResult;
var
  LNode: PRadixNode;
  LRemain: AnsiString;
  LIdx, LPrefixLen: Integer;
  LChild, LNew: PRadixNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rdClosed);
  Lock;
  try
    LNode := FRoot;
    LRemain := AKey;
    while System.Length(LRemain) > 0 do
    begin
      LIdx := FindChild(LNode, LRemain[1]);
      if LIdx < 0 then
      begin
        LNew := CreateNode(LRemain);
        LNew^.Value := AValue;
        LNew^.IsLeaf := True;
        AddChild(LNode, LNew);
        AtomicFetchAdd64(FCount, 1, moRelaxed);
        Exit(rdInserted);
      end;
      LChild := LNode^.Children[LIdx];
      LPrefixLen := CommonPrefixLen(LRemain, LChild^.Prefix);
      if LPrefixLen = System.Length(LChild^.Prefix) then
      begin
        LNode := LChild;
        LRemain := Copy(LRemain, LPrefixLen + 1, MaxInt);
      end
      else
      begin
        LNew := CreateNode(Copy(LChild^.Prefix, 1, LPrefixLen));
        LChild^.Prefix := Copy(LChild^.Prefix, LPrefixLen + 1, MaxInt);
        AddChild(LNew, LChild);
        LNode^.Children[LIdx] := LNew;
        if LPrefixLen = System.Length(LRemain) then
        begin
          LNew^.Value := AValue;
          LNew^.IsLeaf := True;
          AtomicFetchAdd64(FCount, 1, moRelaxed);
          Exit(rdInserted);
        end
        else
        begin
          LRemain := Copy(LRemain, LPrefixLen + 1, MaxInt);
          LChild := CreateNode(LRemain);
          LChild^.Value := AValue;
          LChild^.IsLeaf := True;
          AddChild(LNew, LChild);
          AtomicFetchAdd64(FCount, 1, moRelaxed);
          Exit(rdInserted);
        end;
      end;
    end;
    if LNode^.IsLeaf then
    begin
      LNode^.Value := AValue;
      Exit(rdUpdated);
    end;
    LNode^.Value := AValue;
    LNode^.IsLeaf := True;
    AtomicFetchAdd64(FCount, 1, moRelaxed);
    Result := rdInserted;
  finally
    Unlock;
  end;
end;

function TConcurrentRadixTree.Remove(const AKey: AnsiString): TRadixResult;
var
  LNode: PRadixNode;
  LRemain: AnsiString;
  LIdx: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rdClosed);
  Lock;
  try
    LNode := FRoot;
    LRemain := AKey;
    while System.Length(LRemain) > 0 do
    begin
      LIdx := FindChild(LNode, LRemain[1]);
      if LIdx < 0 then
        Exit(rdNotFound);
      if Copy(LRemain, 1, System.Length(LNode^.Children[LIdx]^.Prefix)) <> LNode^.Children[LIdx]^.Prefix then
        Exit(rdNotFound);
      LNode := LNode^.Children[LIdx];
      LRemain := Copy(LRemain, System.Length(LNode^.Prefix) + 1, MaxInt);
    end;
    if not LNode^.IsLeaf then
      Exit(rdNotFound);
    LNode^.IsLeaf := False;
    AtomicFetchSub64(FCount, 1, moRelaxed);
    Result := rdRemoved;
  finally
    Unlock;
  end;
end;

function TConcurrentRadixTree.Find(const AKey: AnsiString; out AValue: Int64): Boolean;
var
  LNode: PRadixNode;
  LRemain: AnsiString;
  LIdx: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := 0;
    Exit(False);
  end;
  Lock;
  try
    LNode := FRoot;
    LRemain := AKey;
    while System.Length(LRemain) > 0 do
    begin
      LIdx := FindChild(LNode, LRemain[1]);
      if LIdx < 0 then
      begin
        AValue := 0;
        Exit(False);
      end;
      if Copy(LRemain, 1, System.Length(LNode^.Children[LIdx]^.Prefix)) <> LNode^.Children[LIdx]^.Prefix then
      begin
        AValue := 0;
        Exit(False);
      end;
      LNode := LNode^.Children[LIdx];
      LRemain := Copy(LRemain, System.Length(LNode^.Prefix) + 1, MaxInt);
    end;
    if LNode^.IsLeaf then
    begin
      AValue := LNode^.Value;
      Exit(True);
    end;
    AValue := 0;
    Result := False;
  finally
    Unlock;
  end;
end;

function TConcurrentRadixTree.Contains(const AKey: AnsiString): Boolean;
var
  LValue: Int64;
begin
  Result := Find(AKey, LValue);
end;

function TConcurrentRadixTree.GetCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

procedure TConcurrentRadixTree.ForEachSubtree(ANode: PRadixNode; const APath: AnsiString; ACallback: TRadixForEachCallback);
var
  LI: Integer;
  LFullPath: AnsiString;
begin
  if ANode = nil then
    Exit;
  LFullPath := APath + ANode^.Prefix;
  if ANode^.IsLeaf then
    ACallback(LFullPath, ANode^.Value);
  for LI := 0 to ANode^.ChildCount - 1 do
    ForEachSubtree(ANode^.Children[LI], LFullPath, ACallback);
end;

procedure TConcurrentRadixTree.CollectSubtree(ANode: PRadixNode; const APath: AnsiString; var APairs: array of TRadixPair; var ACount: Integer);
var
  LI: Integer;
  LFullPath: AnsiString;
begin
  if ANode = nil then
    Exit;
  LFullPath := APath + ANode^.Prefix;
  if ANode^.IsLeaf then
  begin
    APairs[ACount].Key := LFullPath;
    APairs[ACount].Value := ANode^.Value;
    Inc(ACount);
  end;
  for LI := 0 to ANode^.ChildCount - 1 do
    CollectSubtree(ANode^.Children[LI], LFullPath, APairs, ACount);
end;

procedure TConcurrentRadixTree.ForEach(ACallback: TRadixForEachCallback);
var
  LPairs: array of TRadixPair;
  LCount, LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  LCount := GetCount;
  if LCount = 0 then
    Exit;
  SetLength(LPairs, LCount);
  LCount := 0;
  Lock;
  CollectSubtree(FRoot, '', LPairs, LCount);
  Unlock;
  for LI := 0 to LCount - 1 do
    ACallback(LPairs[LI].Key, LPairs[LI].Value);
end;

procedure TConcurrentRadixTree.ClearSubtree(ANode: PRadixNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to ANode^.ChildCount - 1 do
    ClearSubtree(ANode^.Children[LI]);
  FreeNode(ANode);
end;

procedure TConcurrentRadixTree.Clear;
begin
  Lock;
  ClearSubtree(FRoot);
  FRoot := CreateNode('');
  FCount := 0;
  Unlock;
end;

procedure TConcurrentRadixTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentRadixTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
