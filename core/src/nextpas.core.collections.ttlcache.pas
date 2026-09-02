unit nextpas.core.collections.ttlcache;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.lrucache,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.time;

type
  generic TTtlLruCache<K, V> = class
  private
    type
      TCacheValue = record
        Value: V;
        ExpiresAt: UInt64;
      end;
      TInnerCache = specialize TLruCache<K, TCacheValue>;
    var
      FInner: TInnerCache;
      FRw: TRWLock;
      FTTLMs: UInt64;
    function IsExpired(const AEntry: TCacheValue): Boolean; inline;
  public
    constructor Create(AMaxEntries: Integer; ATTLMs: UInt64);
    destructor Destroy; override;
    function TryGet(const AKey: K; out AValue: V): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    procedure PutWithTTL(const AKey: K; const AValue: V; ATTLMs: UInt64);
    function Remove(const AKey: K): Boolean;
    procedure Clear;
    function Size: Integer;
  end;

implementation

constructor TTtlLruCache.Create(AMaxEntries: Integer; ATTLMs: UInt64);
begin
  inherited Create;
  FInner := TInnerCache.Create(AMaxEntries);
  FRw := TRWLock.Create;
  FTTLMs := ATTLMs;
end;

destructor TTtlLruCache.Destroy;
begin
  FInner.Free;
  FRw.Free;
  inherited Destroy;
end;

function TTtlLruCache.IsExpired(const AEntry: TCacheValue): Boolean;
begin
  Result := GetTickCount64 >= AEntry.ExpiresAt;
end;

function TTtlLruCache.TryGet(const AKey: K; out AValue: V): Boolean;
var
  Entry: TCacheValue;
begin
  Result := False;
  FRw.AcquireRead;
  try
    if not FInner.Get(AKey, Entry) then Exit;
    if IsExpired(Entry) then Exit;
    AValue := Entry.Value;
    Result := True;
  finally
    FRw.ReleaseRead;
  end;
  if not Result then
  begin
    FRw.AcquireWrite;
    try
      if FInner.Get(AKey, Entry) and IsExpired(Entry) then
        FInner.Remove(AKey);
    finally
      FRw.ReleaseWrite;
    end;
  end;
end;

procedure TTtlLruCache.Put(const AKey: K; const AValue: V);
begin
  PutWithTTL(AKey, AValue, FTTLMs);
end;

procedure TTtlLruCache.PutWithTTL(const AKey: K; const AValue: V; ATTLMs: UInt64);
var
  Entry: TCacheValue;
begin
  Entry.Value := AValue;
  Entry.ExpiresAt := GetTickCount64 + ATTLMs;
  FRw.AcquireWrite;
  try
    FInner.Put(AKey, Entry);
  finally
    FRw.ReleaseWrite;
  end;
end;

function TTtlLruCache.Remove(const AKey: K): Boolean;
begin
  FRw.AcquireWrite;
  try
    Result := FInner.Remove(AKey);
  finally
    FRw.ReleaseWrite;
  end;
end;

procedure TTtlLruCache.Clear;
begin
  FRw.AcquireWrite;
  try
    FInner.Clear;
  finally
    FRw.ReleaseWrite;
  end;
end;

function TTtlLruCache.Size: Integer;
begin
  FRw.AcquireRead;
  try
    Result := FInner.GetSize;
  finally
    FRw.ReleaseRead;
  end;
end;

end.
