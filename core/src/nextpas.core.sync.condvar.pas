unit nextpas.core.sync.condvar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.platform.sync,
  nextpas.core.time.base;

type
  TCondVar = class(TInterfacedObject, ICondVar)
  private
    FHandle: TPlatformCondVar;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Wait(const AMutex: INativeMutex);
    function WaitTimeout(const AMutex: INativeMutex; const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const AMutex: INativeMutex; const ATimeout: TDuration): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.platform.error;

constructor TCondVar.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_condvar_init(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TCondVar', 'Create', LRet);
end;

destructor TCondVar.Destroy;
var
  LRet: Int32;
begin
  LRet := platform_condvar_destroy(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TCondVar', 'Destroy', LRet);
  inherited;
end;

procedure TCondVar.Wait(const AMutex: INativeMutex);
var
  LRet: Int32;
begin
  LRet := platform_condvar_wait(FHandle, TPlatformMutex(AMutex.NativeHandle^));
  if LRet <> 0 then
    SyncRaiseOpFailed('TCondVar', 'Wait', LRet);
end;

function TCondVar.WaitTimeout(const AMutex: INativeMutex; const ATimeoutNs: Int64): Boolean;
var
  LRet: Int32;
begin
  LRet := platform_condvar_timedwait(FHandle, TPlatformMutex(AMutex.NativeHandle^), ATimeoutNs);
  if LRet = 0 then
    Exit(True);
  if LRet = PLATFORM_ERR_TIMEDOUT then
    Exit(False);
  SyncRaiseOpFailed('TCondVar', 'WaitTimeout', LRet);
end;

function TCondVar.WaitTimeout(const AMutex: INativeMutex; const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(AMutex, ATimeout.AsNanoseconds);
end;

procedure TCondVar.Signal;
begin
  platform_condvar_signal(FHandle);
end;

procedure TCondVar.Broadcast;
begin
  platform_condvar_broadcast(FHandle);
end;

end.
