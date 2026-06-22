unit nextpas.core.thread.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.thread.base;

type
  TThreadProc = procedure(AData: Pointer);

  IThreadPool = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000001}']
    procedure Submit(const ATask: TThreadTask);
    { SubmitDirect: zero-closure submission. Caller ensures AData outlives the task. }
    procedure SubmitDirect(AData: Pointer; AProc: TThreadProc);
    procedure Shutdown;
    procedure WaitAll;
    function GetWorkerCount: Integer;
    property WorkerCount: Integer read GetWorkerCount;
  end;

  generic IChannel<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000002}']
    procedure Send(const AValue: T);
    function Receive(out AValue: T): Boolean;
    function TrySend(const AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;

  generic IFuture<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000010}']
    function Wait: T;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function State: TFutureState;
    function IsDone: Boolean;
    function Get: T;
  end;

  generic IPromise<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000011}']
    procedure Complete(const AValue: T);
    procedure Fail(const AError: Exception);
    procedure Cancel;
    function GetFuture: specialize IFuture<T>;
  end;

  ICancellationToken = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000020}']
    function IsCancelled: Boolean;
    procedure ThrowIfCancelled;
    function WaitCancellation(const ATimeoutNs: Int64): Boolean;
  end;

  ICancellationSource = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000021}']
    function Token: ICancellationToken;
    procedure Cancel;
  end;

  IFutureVoid = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000030}']
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function IsDone: Boolean;
  end;

implementation

end.
