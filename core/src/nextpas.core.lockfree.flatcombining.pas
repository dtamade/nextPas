unit nextpas.core.lockfree.flatcombining;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  FC_PUBLICATION_ARRAY_SIZE = 64;

type
  TFCOpType = (fcopNop, fcopIncr, fcopDecr, fcopAdd, fcopSub, fcopRead);

  PFCPublication = ^TFCPublication;
  TFCPublication = record
    Active: Int32;
    OpType: TFCOpType;
    Operand: Int64;
    Result: Int64;
    Completed: Int32;
    Next: PFCPublication;
  end;

  {** @desc Flat Combining 同步原语
    @details 高竞争下吞吐量远优于传统锁。
      每个线程持有 publication record，acquire lock 的线程成为 combiner，
      批量执行所有 pending 操作。
  }
  TFlatCombiningLock = class
  private
    FLock: Int32;
    FTargetValue: PInt64;
    FClosed: Int32;
    function TryAcquire: Boolean;
    procedure Release;
    procedure Combine;
  public
    constructor Create(ATarget: PInt64);
    destructor Destroy; override;
    function Apply(AOp: TFCOpType; AOperand: Int64): Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc 基于 Flat Combining 的并发计数器
    @details 利用 Flat Combining 机制实现高吞吐量计数。
      适用于高竞争场景下的统计计数。
  }
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

var
  GPublicationPool: array[0..FC_PUBLICATION_ARRAY_SIZE - 1] of TFCPublication;
  GPoolIndex: Int32;

function GetPublication: PFCPublication;
var
  LIdx: Int32;
begin
  LIdx := AtomicFetchAdd32(GPoolIndex, 1, moRelaxed) mod FC_PUBLICATION_ARRAY_SIZE;
  Result := @GPublicationPool[LIdx];
  AtomicStore32(Result^.Active, 1, moRelease);
  Result^.Completed := 1;
end;

constructor TFlatCombiningLock.Create(ATarget: PInt64);
begin
  inherited Create;
  FLock := 0;
  FTargetValue := ATarget;
  FClosed := 0;
end;

destructor TFlatCombiningLock.Destroy;
begin
  inherited Destroy;
end;

function TFlatCombiningLock.TryAcquire: Boolean;
begin
  Result := AtomicCompareExchange32(FLock, 1, 0) = 0;
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
    if (AtomicLoad32(GPublicationPool[LI].Active, moAcquire) <> 0) and
       (AtomicLoad32(GPublicationPool[LI].Completed, moAcquire) = 0) then
    begin
      case GPublicationPool[LI].OpType of
        fcopIncr:
          GPublicationPool[LI].Result := AtomicFetchAdd64(FTargetValue^, 1, moRelaxed) + 1;
        fcopDecr:
          GPublicationPool[LI].Result := AtomicFetchSub64(FTargetValue^, 1, moRelaxed) - 1;
        fcopAdd:
          GPublicationPool[LI].Result := AtomicFetchAdd64(FTargetValue^, GPublicationPool[LI].Operand, moRelaxed) + GPublicationPool[LI].Operand;
        fcopSub:
          GPublicationPool[LI].Result := AtomicFetchSub64(FTargetValue^, GPublicationPool[LI].Operand, moRelaxed) - GPublicationPool[LI].Operand;
        fcopRead:
          GPublicationPool[LI].Result := AtomicLoad64(FTargetValue^, moRelaxed);
      else
        GPublicationPool[LI].Result := 0;
      end;
      AtomicStore32(GPublicationPool[LI].Completed, 1, moRelease);
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
  LPub^.OpType := AOp;
  LPub^.Operand := AOperand;
  LPub^.Completed := 0;
  if TryAcquire then
  begin
    Combine;
    Result := LPub^.Result;
    Release;
  end
  else
  begin
    while AtomicLoad32(LPub^.Completed, moAcquire) = 0 do
      ThreadSwitch;
    Result := LPub^.Result;
  end;
  AtomicStore32(LPub^.Active, 0, moRelease);
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
