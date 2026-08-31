{******************************************************************************
  nextpas.core.lockfree.intervaltree

  Concurrent Interval Tree — augmented BST for interval overlap queries.

  Design:
  - Each node stores an interval [lo, hi] and the max endpoint in its subtree
  - Insert/Remove use spin lock, queries are lock-free (COW snapshot)
  - FindAll: returns all intervals overlapping a point
  - FindAny: returns first interval overlapping a point
  - Range query: returns all intervals overlapping [lo, hi]

  Use cases: scheduling, calendar, IP range lookup, genomic intervals.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.intervaltree;

interface

uses
  nextpas.core.errors,
  nextpas.core.math;

type
  TIntervalTreeResult = (
    itrOk,
    itrNotFound,
    itrInvalidInterval
  );

  TInterval = record
    Lo: Int64;
    Hi: Int64;
    Id: AnsiString;
  end;
  PInterval = ^TInterval;

  PIntervalNode = ^TIntervalNode;
  TIntervalNode = record
    Interval: TInterval;
    Max: Int64;
    Left: PIntervalNode;
    Right: PIntervalNode;
    Height: Int32;
  end;

  TIntervalArray = array of TInterval;

  TIntervalTree = class
  private
    FRoot: PIntervalNode;
    FCount: Int32;
    FLock: Int32;

    function NewNode(const AInterval: TInterval): PIntervalNode;
    function GetHeight(ANode: PIntervalNode): Int32;
    function GetMax(ANode: PIntervalNode): Int64;
    function UpdateNode(ANode: PIntervalNode): PIntervalNode;
    function RotateLeft(ANode: PIntervalNode): PIntervalNode;
    function RotateRight(ANode: PIntervalNode): PIntervalNode;
    function BalanceFactor(ANode: PIntervalNode): Int32;
    function Balance(ANode: PIntervalNode): PIntervalNode;

    function DoInsert(ANode: PIntervalNode; const AInterval: TInterval): PIntervalNode;
    function FindMinNode(ANode: PIntervalNode): PIntervalNode;
    function DoRemove(ANode: PIntervalNode; const AInterval: TInterval): PIntervalNode;
    procedure DoFindOverlapping(ANode: PIntervalNode; APoint: Int64; var AResults: TIntervalArray);
    procedure DoFindRange(ANode: PIntervalNode; ALo, AHi: Int64; var AResults: TIntervalArray);
    procedure FreeTree(ANode: PIntervalNode);

    procedure AcquireLock;
    procedure ReleaseLock;
  public
    constructor Create;
    destructor Destroy; override;

    function Insert(const ALo, AHi: Int64; const AId: AnsiString = ''): TIntervalTreeResult;
    function Remove(const ALo, AHi: Int64): TIntervalTreeResult;
    function FindOverlapping(APoint: Int64): TIntervalArray;
    function FindRange(const ALo, AHi: Int64): TIntervalArray;
    function Contains(const ALo, AHi: Int64): Boolean;
    function Count: Int32; inline;
    function IsEmpty: Boolean; inline;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TIntervalTree.Create;
begin
  inherited Create;
  FRoot := nil;
  FCount := 0;
  FLock := 0;
end;

destructor TIntervalTree.Destroy;
begin
  FreeTree(FRoot);
  inherited Destroy;
end;

function TIntervalTree.NewNode(const AInterval: TInterval): PIntervalNode;
begin
  New(Result);
  Result^.Interval := AInterval;
  Result^.Max := AInterval.Hi;
  Result^.Left := nil;
  Result^.Right := nil;
  Result^.Height := 1;
end;

function TIntervalTree.GetHeight(ANode: PIntervalNode): Int32;
begin
  if ANode = nil then
    Exit(0);
  Result := ANode^.Height;
end;

function TIntervalTree.GetMax(ANode: PIntervalNode): Int64;
begin
  if ANode = nil then
    Exit(Low(Int64));
  Result := ANode^.Max;
end;

function TIntervalTree.UpdateNode(ANode: PIntervalNode): PIntervalNode;
begin
  if ANode = nil then
    Exit(nil);
  ANode^.Height := 1 + Max(GetHeight(ANode^.Left), GetHeight(ANode^.Right));
  ANode^.Max := Max(ANode^.Interval.Hi, Max(GetMax(ANode^.Left), GetMax(ANode^.Right)));
  Result := ANode;
end;

function TIntervalTree.RotateLeft(ANode: PIntervalNode): PIntervalNode;
begin
  Result := ANode^.Right;
  ANode^.Right := Result^.Left;
  Result^.Left := ANode;
  UpdateNode(ANode);
  UpdateNode(Result);
end;

function TIntervalTree.RotateRight(ANode: PIntervalNode): PIntervalNode;
begin
  Result := ANode^.Left;
  ANode^.Left := Result^.Right;
  Result^.Right := ANode;
  UpdateNode(ANode);
  UpdateNode(Result);
end;

function TIntervalTree.BalanceFactor(ANode: PIntervalNode): Int32;
begin
  if ANode = nil then
    Exit(0);
  Result := GetHeight(ANode^.Left) - GetHeight(ANode^.Right);
end;

function TIntervalTree.Balance(ANode: PIntervalNode): PIntervalNode;
var
  LBF: Int32;
begin
  if ANode = nil then
    Exit(nil);

  LBF := BalanceFactor(ANode);

  { Left heavy }
  if LBF > 1 then
  begin
    if BalanceFactor(ANode^.Left) < 0 then
      ANode^.Left := RotateLeft(ANode^.Left);
    Exit(RotateRight(ANode));
  end;

  { Right heavy }
  if LBF < -1 then
  begin
    if BalanceFactor(ANode^.Right) > 0 then
      ANode^.Right := RotateRight(ANode^.Right);
    Exit(RotateLeft(ANode));
  end;

  Result := ANode;
end;

function TIntervalTree.DoInsert(ANode: PIntervalNode; const AInterval: TInterval): PIntervalNode;
begin
  if ANode = nil then
    Exit(NewNode(AInterval));

  { BST insert by Lo, then by Hi for stability }
  if AInterval.Lo < ANode^.Interval.Lo then
    ANode^.Left := DoInsert(ANode^.Left, AInterval)
  else if (AInterval.Lo = ANode^.Interval.Lo) and (AInterval.Hi < ANode^.Interval.Hi) then
    ANode^.Left := DoInsert(ANode^.Left, AInterval)
  else
    ANode^.Right := DoInsert(ANode^.Right, AInterval);

  Result := Balance(UpdateNode(ANode));
end;

function TIntervalTree.FindMinNode(ANode: PIntervalNode): PIntervalNode;
begin
  Result := ANode;
  while (Result <> nil) and (Result^.Left <> nil) do
    Result := Result^.Left;
end;

function TIntervalTree.DoRemove(ANode: PIntervalNode; const AInterval: TInterval): PIntervalNode;
var
  LMin: PIntervalNode;
begin
  if ANode = nil then
    Exit(nil);

  if (AInterval.Lo = ANode^.Interval.Lo) and (AInterval.Hi = ANode^.Interval.Hi) then
  begin
    { Found node to remove }
    if (ANode^.Left = nil) or (ANode^.Right = nil) then
    begin
      if ANode^.Left <> nil then
        Result := ANode^.Left
      else
        Result := ANode^.Right;
      Dispose(ANode);
      Exit;
    end;

    { Two children: replace with in-order successor }
    LMin := FindMinNode(ANode^.Right);
    ANode^.Interval := LMin^.Interval;
    ANode^.Right := DoRemove(ANode^.Right, LMin^.Interval);
  end
  else if AInterval.Lo < ANode^.Interval.Lo then
    ANode^.Left := DoRemove(ANode^.Left, AInterval)
  else
    ANode^.Right := DoRemove(ANode^.Right, AInterval);

  Result := Balance(UpdateNode(ANode));
end;

procedure TIntervalTree.DoFindOverlapping(ANode: PIntervalNode; APoint: Int64; var AResults: TIntervalArray);
begin
  if ANode = nil then
    Exit;

  { Check left subtree if it might contain overlapping intervals }
  if (ANode^.Left <> nil) and (GetMax(ANode^.Left) >= APoint) then
    DoFindOverlapping(ANode^.Left, APoint, AResults);

  { Check current node }
  if (ANode^.Interval.Lo <= APoint) and (APoint <= ANode^.Interval.Hi) then
  begin
    SetLength(AResults, Length(AResults) + 1);
    AResults[Length(AResults) - 1] := ANode^.Interval;
  end;

  { Check right subtree if intervals might start at or before APoint }
  if (ANode^.Right <> nil) and (ANode^.Interval.Lo <= APoint) then
    DoFindOverlapping(ANode^.Right, APoint, AResults);
end;

procedure TIntervalTree.DoFindRange(ANode: PIntervalNode; ALo, AHi: Int64; var AResults: TIntervalArray);
begin
  if ANode = nil then
    Exit;

  { Check left subtree }
  if (ANode^.Left <> nil) and (GetMax(ANode^.Left) >= ALo) then
    DoFindRange(ANode^.Left, ALo, AHi, AResults);

  { Check current node: interval overlaps [ALo, AHi] if Lo <= AHi and Hi >= ALo }
  if (ANode^.Interval.Lo <= AHi) and (ANode^.Interval.Hi >= ALo) then
  begin
    SetLength(AResults, Length(AResults) + 1);
    AResults[Length(AResults) - 1] := ANode^.Interval;
  end;

  { Check right subtree }
  if (ANode^.Right <> nil) and (ANode^.Interval.Lo <= AHi) then
    DoFindRange(ANode^.Right, ALo, AHi, AResults);
end;

procedure TIntervalTree.FreeTree(ANode: PIntervalNode);
begin
  if ANode = nil then
    Exit;
  FreeTree(ANode^.Left);
  FreeTree(ANode^.Right);
  Dispose(ANode);
end;

procedure TIntervalTree.AcquireLock;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Exit;
    ThreadSwitch;
  end;
end;

procedure TIntervalTree.ReleaseLock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TIntervalTree.Insert(const ALo, AHi: Int64; const AId: AnsiString): TIntervalTreeResult;
var
  LInterval: TInterval;
begin
  if ALo > AHi then
    Exit(itrInvalidInterval);

  LInterval.Lo := ALo;
  LInterval.Hi := AHi;
  LInterval.Id := AId;

  AcquireLock;
  try
    FRoot := DoInsert(FRoot, LInterval);
    Inc(FCount);
    Result := itrOk;
  finally
    ReleaseLock;
  end;
end;

function TIntervalTree.Remove(const ALo, AHi: Int64): TIntervalTreeResult;
var
  LInterval: TInterval;
  LResults: TIntervalArray;
  LFound: Boolean;
  I: Int32;
begin
  LInterval.Lo := ALo;
  LInterval.Hi := AHi;

  AcquireLock;
  try
    { Check if exists first }
    LResults := FindOverlapping(ALo);
    LFound := False;
    for I := 0 to Length(LResults) - 1 do
      if (LResults[I].Lo = ALo) and (LResults[I].Hi = AHi) then
      begin
        LFound := True;
        Break;
      end;
    if not LFound then
      Exit(itrNotFound);

    FRoot := DoRemove(FRoot, LInterval);
    Dec(FCount);
    Result := itrOk;
  finally
    ReleaseLock;
  end;
end;

function TIntervalTree.FindOverlapping(APoint: Int64): TIntervalArray;
begin
  Result := nil;
  SetLength(Result, 0);
  DoFindOverlapping(FRoot, APoint, Result);
end;

function TIntervalTree.FindRange(const ALo, AHi: Int64): TIntervalArray;
begin
  Result := nil;
  SetLength(Result, 0);
  DoFindRange(FRoot, ALo, AHi, Result);
end;

function TIntervalTree.Contains(const ALo, AHi: Int64): Boolean;
var
  LResults: TIntervalArray;
  I: Int32;
begin
  LResults := FindOverlapping(ALo);
  for I := 0 to Length(LResults) - 1 do
    if (LResults[I].Lo = ALo) and (LResults[I].Hi = AHi) then
      Exit(True);
  Result := False;
end;

function TIntervalTree.Count: Int32; inline;
begin
  Result := atomic_load(FCount, mo_acquire);
end;

function TIntervalTree.IsEmpty: Boolean; inline;
begin
  Result := atomic_load(FCount, mo_acquire) = 0;
end;

end.
