unit nextpas.core.lockfree.flatcombining;
{**
 * @desc Flat Combining synchronization primitive.
 *
 * @details Lock-free synchronization using publication arrays:
 *   - Threads publish operations in a shared publication array
 *   - One thread combines and executes all pending operations
 *   - Reduces cache contention compared to traditional locks
 *   - Supports Incr/Decr/Add/Sub/Read operations
 *
 * @concurrency Thread-safe for multiple threads:
 *   - Incr/Decr/Add/Sub/Read: publish and wait for completion
 *   - Close: safe to call from any thread
 *
 * @see Flat Combining — Hendler et al., 2010
 * @see Lock-free synchronization — publication array pattern
 *}

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
    function TryAcquire: Boolean;
    procedure Release;
    procedure Combine;
    function GetPublication: PFCPublication;
  public
    constructor Create(ATarget: PInt64);
    destructor Destroy; override;
    function Apply(AOp: TFCOpType; AOperand: Int64): Int64;
    procedure Close;
    function IsClosed: Boolean; inline;
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
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function TFlatCombiningLock.GetPublication: PFCPublication;
var
  LI: Int32;
  LCasExpected: Int32;
begin
  while atomic_load(FClosed, mo_acquire) = 0 do
  begin
    for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
    begin
      LCasExpected := 0;
      if atomic_compare_exchange_strong(FPublications[LI].OwnerThreadId, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      begin
        atomic_store(FPublications[LI].Completed, 1, mo_relaxed);
        Exit(@FPublications[LI]);
      end;
    end;
    ThreadSwitch;
  end;
  Result := nil;
end;

constructor TFlatCombiningLock.Create(ATarget: PInt64);
var
  LI: Integer;
begin
  if ATarget = nil then
    raise EArgumentError.Create('TFlatCombiningLock: target must not be nil');
  inherited Create;
  FLock := 0;
  FTargetValue := ATarget;
  FClosed := 0;
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
var
  LCasExpected: Int32;
begin
  LCasExpected := 0;
  Result := atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire);
end;

procedure TFlatCombiningLock.Release;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TFlatCombiningLock.Combine;
var
  LI: Integer;
begin
  for LI := 0 to FC_PUBLICATION_ARRAY_SIZE - 1 do
  begin
    if (atomic_load(FPublications[LI].OwnerThreadId, mo_acquire) <> 0) and
       (atomic_load(FPublications[LI].Completed, mo_acquire) = 0) then
    begin
      case FPublications[LI].OpType of
        fcopIncr:
          FPublications[LI].Result := atomic_fetch_add_64(FTargetValue^, 1, mo_relaxed) + 1;
        fcopDecr:
          FPublications[LI].Result := atomic_fetch_sub_64(FTargetValue^, 1, mo_relaxed) - 1;
        fcopAdd:
          FPublications[LI].Result := atomic_fetch_add_64(FTargetValue^, FPublications[LI].Operand, mo_relaxed) + FPublications[LI].Operand;
        fcopSub:
          FPublications[LI].Result := atomic_fetch_sub_64(FTargetValue^, FPublications[LI].Operand, mo_relaxed) - FPublications[LI].Operand;
        fcopRead:
          FPublications[LI].Result := atomic_load_64(FTargetValue^, mo_relaxed);
      else
        FPublications[LI].Result := 0;
      end;
      atomic_store(FPublications[LI].Completed, 1, mo_release);
    end;
  end;
end;

function TFlatCombiningLock.Apply(AOp: TFCOpType; AOperand: Int64): Int64;
var
  LPub: PFCPublication;
  LSpinCount: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(0);
  LPub := GetPublication;
  if LPub = nil then
    Exit(0);
  try
    LPub^.OpType := AOp;
    LPub^.Operand := AOperand;
    atomic_store(LPub^.Completed, 0, mo_release);
    if TryAcquire then
    begin
      Combine;
      Result := LPub^.Result;
      Release;
    end
    else
    begin
      LSpinCount := 0;
      while atomic_load(LPub^.Completed, mo_acquire) = 0 do
      begin
        if TryAcquire then
        begin
          Combine;
          Release;
        end
        else
        begin
          Inc(LSpinCount);
          if LSpinCount <= 64 then
            CpuPause
          else
            ThreadSwitch;
        end;
      end;
      Result := LPub^.Result;
    end;
  finally
    atomic_store(LPub^.OwnerThreadId, 0, mo_release);
  end;
end;

procedure TFlatCombiningLock.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TFlatCombiningLock.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
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
  Result := atomic_load_64(FValue, mo_relaxed);
end;

procedure TFlatCombiningCounter.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  FLock.Close;
end;

function TFlatCombiningCounter.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
