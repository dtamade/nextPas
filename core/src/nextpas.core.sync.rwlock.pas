unit nextpas.core.sync.rwlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.platform.sync;

type
  {**
   * @desc 读写锁，基于 platform pthread_rwlock / SRWLOCK
   *}
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
  SysUtils, nextpas.core.errors;

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

{ TReadGuard }

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

{ TWriteGuard }

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

{ TRWLock }

constructor TRWLock.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_rwlock_init(FHandle);
  if LRet <> 0 then
    raise ENextPasError.CreateFmt('TRWLock.Create failed: %d', [LRet]);
end;

destructor TRWLock.Destroy;
begin
  platform_rwlock_destroy(FHandle);
  inherited;
end;

procedure TRWLock.AcquireRead;
begin
  if platform_rwlock_rdlock(FHandle) <> 0 then
    raise ENextPasError.Create('TRWLock.AcquireRead failed');
end;

function TRWLock.TryAcquireRead: Boolean;
begin
  Result := platform_rwlock_tryrdlock(FHandle) = 0;
end;

procedure TRWLock.AcquireWrite;
begin
  if platform_rwlock_wrlock(FHandle) <> 0 then
    raise ENextPasError.Create('TRWLock.AcquireWrite failed');
end;

function TRWLock.TryAcquireWrite: Boolean;
begin
  Result := platform_rwlock_trywrlock(FHandle) = 0;
end;

procedure TRWLock.ReleaseRead;
begin
  platform_rwlock_unlock(FHandle);
end;

procedure TRWLock.ReleaseWrite;
begin
  platform_rwlock_unlock(FHandle);
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
