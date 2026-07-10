unit nextpas.core.lockfree.flatcombining;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  FC_PUBLICATION_ARRAY_SIZE = 256;

type
  TFCOpType = (fcopNop, fcopIncr, fcopDecr, fcopAdd, fcopSub, fcopRead);

  PFCPublication = ^TFCPublication;
  TFCPublication = record
    OwnerThreadId: Int32;  { 0 = free, >0 = owned by thread }
    OpType: TFCOpType;
    Operand: Int64;
    Result: Int64;
    Completed: Int32;
  end;

  {** @desc Flat Combining 同步原语 }
  TFlatCombiningLock = class
  private
    FLock: Int32;
    FTargetValue: PInt64;
    FClosed: Int32;
    FPublications: array[0..FC_PUBLICATION_ARRAY_SIZE - 1] of TFCPublication;
    FNextThreadId: Int32;
    function TryAcquire: Boolean;
    procedure Release;
    procedure Combine;
    function GetPublication: PFCPublication;
    function GetThreadId: Int32;
  public
    constructor Create(ATarget: PInt64);
    destructor Destroy; override;
    function Apply(AOp: TFCOpType; AOperand: Int64): Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc 基于 Flat Combining 的并发计数器 }
  TFlatCombiningCounter = class
  private
    FLock: TFlatCombiningLock;
    FValue: Int64;
    FClosed: Int32;
  public
    constructor Create(const AInitialValue: Int64 = 0);
    destructor Destroy; override;
    function Increment: Int64;
    function Decrement: Int64;
    function Add(const AValue: Int64): Int64;
    function Sub(const AValue: Int64): Int64;
    function GetValue: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

{ Per-thread unique ID, 0 = not assigned }
threadvar
  GMyThreadId: Int32;

var
  GThreadIdCounter: Int32;

function TFlatCombiningLock.GetThreadId: Int32;
begin
  if GMyThreadId = 0 then
    GMyThreadId := AtomicFetchAdd32(GThreadIdCounter, 1, moRelaxed) + 1;
  Result := GMyThreadId;
end;

function TFlatCombiningLock.GetPublication: PFCPublication;
var
  LThreadId, LI: Int32;
begin
  LThreadId := GetThreadId;
  { Find existing slot owned by this thread }
  for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
  begin
    if AtomicLoad32(FPublications[LI].OwnerThreadId, moAcquire) = LThreadId then
      Exit(@FPublications[LI]);
  end;
  { Claim a free slot (OwnerThreadId = 0) }
  for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
  begin
    if AtomicCompareExchange32(FPublications[LI].OwnerThreadId, 0, LThreadId) = 0 then
    begin
      FPublications[LI].Completed := 1; { initially idle }
      Exit(@FPublications[LI]);
    end;
  end;
  { Fallback: should not happen with 256 slots }
  Result := @FPublications[AtomicFetchAdd32(FNextThreadId, 1, moRelaxed) mod FC_PUBLICATION_ARRAY_SIZE];
end;

constructor TFlatCombiningLock.Create(ATarget: PInt64);
var
  LI: Integer;
begin
  inherited Create;
  FLock := 0;
  FTargetValue := ATarget;
  FClosed := 0;
  FNextThreadId := 0;
  for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
  begin
    FPublications[LI].OwnerThreadId := 0;
    FPublications[LI].Completed := 1;
  end;
end;

destructor TFlatCombiningLock.Destroy;
begin
  inherited Destroy;
end;

function TFlatCombiningLock.TryAcquire: Boolean;
begin
  Result := AtomicCompareExchange32(FLock, 0, 1) = 0;
end;

procedure TFlatCombiningLock.Release;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TFlatCombiningLock.Combine;
var
  LI: Integer;
begin
  for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
  begin
    if (AtomicLoad32(FPublications[LI].OwnerThreadId, moAcquire) <> 0) and
       (AtomicLoad32(FPublications[LI].Completed, moAcquire) = 0) then
    begin
      case FPublications[LI].OpType of
        fcopIncr:
          FPublications[LI].Result := AtomicFetchAdd64(FTargetValue^, 1, moRelaxed) + 1;
        fcopDecr:
          FPublications[LI].Result := AtomicFetchSub64(FTargetValue^, 1, moRelaxed) - 1;
        fcopAdd:
          FPublications[LI].Result := AtomicFetchAdd64(FTargetValue^, FPublications[LI].Operand, moRelaxed) + FPublications[LI].Operand;
        fcopSub:
          FPublications[LI].Result := AtomicFetchSub64(FTargetValue^, FPublications[LI].Operand, moRelaxed) - FPublications[LI].Operand;
        fcopRead:
          FPublications[LI].Result := AtomicLoad64(FTargetValue^, moRelaxed);
      else
        FPublications[LI].Result := 0;
      end;
      AtomicStore32(FPublications[LI].Completed, 1, moRelease);
    end;
  end;
end;

function TFlatCombiningLock.Apply(AOp: TFCOpType; AOperand: Int64): Int64;
var
  LPub: PFCPublication;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(0);
  LPub := GetPublication;
  { Wait for any previous operation to complete }
  while AtomicLoad32(LPub^.Completed, moAcquire) = 0 do
    ThreadSwitch;
  { Write new operation, then signal }
  LPub^.OpType := AOp;
  LPub^.Operand := AOperand;
  AtomicStore32(LPub^.Completed, 0, moRelease);
  if TryAcquire then
  begin
    Combine;
    Result := LPub^.Result;
    Release;
  end
  else
  begin
    while AtomicLoad32(LPub^.Completed, moAcquire) = 0 do
    begin
      if TryAcquire then
      begin
        Combine;
        Release;
      end
      else
        ThreadSwitch;
    end;
    Result := LPub^.Result;
  end;
end;

procedure TFlatCombiningLock.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TFlatCombiningLock.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

{ TFlatCombiningCounter }

constructor TFlatCombiningCounter.Create(const AInitialValue: Int64);
begin
  inherited Create;
  FValue := AInitialValue;
  FClosed := 0;
  FLock := TFlatCombiningLock.Create(@FValue);
end;

destructor TFlatCombiningCounter.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TFlatCombiningCounter.Increment: Int64;
begin
  Result := FLock.Apply(fcopIncr, 1);
end;

function TFlatCombiningCounter.Decrement: Int64;
begin
  Result := FLock.Apply(fcopDecr, 1);
end;

function TFlatCombiningCounter.Add(const AValue: Int64): Int64;
begin
  Result := FLock.Apply(fcopAdd, AValue);
end;

function TFlatCombiningCounter.Sub(const AValue: Int64): Int64;
begin
  Result := FLock.Apply(fcopSub, AValue);
end;

function TFlatCombiningCounter.GetValue: Int64;
begin
  Result := AtomicLoad64(FValue, moRelaxed);
end;

procedure TFlatCombiningCounter.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  FLock.Close;
end;

function TFlatCombiningCounter.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
