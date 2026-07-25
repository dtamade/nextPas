unit nextpas.core.sync.rwlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.platform.sync;

type
  TRWLock = class(TInterfacedObject, IRWLock)
  private
    FHandle: TPlatformRwLock;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AcquireRead;
    function TryAcquireRead: Boolean;
    procedure AcquireWrite;
    function TryAcquireWrite: Boolean;
    procedure ReleaseRead;
    procedure ReleaseWrite;
    function ReadLock: ILockGuard;
    function WriteLock: ILockGuard;
  end;

implementation

uses
  nextpas.core.sync.errors;

type
  TReadGuard = class(TInterfacedObject, ILockGuard)
  private
    FRwLock: IRWLock;
  public
    constructor Create(const ARwLock: IRWLock);
    destructor Destroy; override;
  end;

  TWriteGuard = class(TInterfacedObject, ILockGuard)
  private
    FRwLock: IRWLock;
  public
    constructor Create(const ARwLock: IRWLock);
    destructor Destroy; override;
  end;

constructor TReadGuard.Create(const ARwLock: IRWLock);
begin
  inherited Create;
  FRwLock := ARwLock;
end;

destructor TReadGuard.Destroy;
begin
  if FRwLock <> nil then
    FRwLock.ReleaseRead;
  inherited;
end;

constructor TWriteGuard.Create(const ARwLock: IRWLock);
begin
  inherited Create;
  FRwLock := ARwLock;
end;

destructor TWriteGuard.Destroy;
begin
  if FRwLock <> nil then
    FRwLock.ReleaseWrite;
  inherited;
end;

constructor TRWLock.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_rwlock_init(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRWLock', 'Create', LRet);
end;

destructor TRWLock.Destroy;
var
  LRet: Int32;
begin
  LRet := platform_rwlock_destroy(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRWLock', 'Destroy', LRet);
  inherited;
end;

procedure TRWLock.AcquireRead;
var
  LRet: Int32;
begin
  LRet := platform_rwlock_rdlock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRWLock', 'AcquireRead', LRet);
end;

function TRWLock.TryAcquireRead: Boolean;
begin
  Result := platform_rwlock_tryrdlock(FHandle) = 0;
end;

procedure TRWLock.AcquireWrite;
var
  LRet: Int32;
begin
  LRet := platform_rwlock_wrlock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRWLock', 'AcquireWrite', LRet);
end;

function TRWLock.TryAcquireWrite: Boolean;
begin
  Result := platform_rwlock_trywrlock(FHandle) = 0;
end;

procedure TRWLock.ReleaseRead;
begin
  platform_rwlock_rdunlock(FHandle);
end;

procedure TRWLock.ReleaseWrite;
begin
  platform_rwlock_wrunlock(FHandle);
end;

function TRWLock.ReadLock: ILockGuard;
begin
  AcquireRead;
  Result := TReadGuard.Create(Self);
end;

function TRWLock.WriteLock: ILockGuard;
begin
  AcquireWrite;
  Result := TWriteGuard.Create(Self);
end;

end.
