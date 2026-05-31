unit nextpas.core.tls.cert.verify.cache;

{$mode ObjFPC}{$H+}

{
  证书验证结果缓存

  特性：
  - 基于证书指纹（SHA-256）的缓存
  - 线程安全（使用临界区）
  - LRU 驱逐策略
  - 可配置缓存大小和 TTL
  - 原子操作，零拷贝

  性能目标：
  - 缓存命中：<0.1 ms
  - 缓存未命中：正常验证（10-50 ms）
  - 10x 握手性能提升（重复证书场景）

  设计原则：
  - 简洁 API（Get/Set）
  - 线程安全
  - 内存高效
}

interface

uses
  SysUtils, Classes, SyncObjs, DateUtils,
  nextpas.core.tls.openssl.base;

type
  { 验证结果 }
  TCertVerifyResult = record
    Valid: Boolean;
    ErrorCode: Integer;
    ErrorMessage: string;
    VerifiedAt: TDateTime;
  end;

  { 缓存条目 }
  TCacheEntry = record
    Fingerprint: array[0..31] of Byte;  // SHA-256 (32 bytes)
    Result: TCertVerifyResult;
    LastAccess: TDateTime;
    HitCount: Integer;
  end;

  { 证书验证缓存（线程安全，LRU）}
  TCertVerifyCache = class
  private
    FLock: TCriticalSection;
    FEntries: array of TCacheEntry;
    FCapacity: Integer;
    FCount: Integer;
    FTTL: Integer;  // 秒

    FHits: Int64;
    FMisses: Int64;

    function ComputeFingerprint(ACert: PX509): TBytes;
    function FindEntry(const AFingerprint: TBytes): Integer;
    procedure EvictOldest;
    function IsExpired(const AEntry: TCacheEntry): Boolean;

  public
    constructor Create(ACapacity: Integer = 1000; ATTL: Integer = 3600);
    destructor Destroy; override;

    { 缓存操作 }
    function TryGet(ACert: PX509; out AResult: TCertVerifyResult): Boolean;
    procedure Put(ACert: PX509; const AResult: TCertVerifyResult);
    procedure Clear;

    { 统计 }
    function GetHitRate: Double;
    function GetSize: Integer;
    procedure GetStats(out AHits, AMisses, ASize: Int64);

    { 属性 }
    property Capacity: Integer read FCapacity;
    property TTL: Integer read FTTL write FTTL;
  end;

  { 全局缓存实例 }
function GetGlobalCertVerifyCache: TCertVerifyCache;

implementation

uses
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.loader;

var
  GlobalCache: TCertVerifyCache = nil;
  GlobalCacheLock: TCriticalSection = nil;

function GetGlobalCertVerifyCache: TCertVerifyCache;
begin
  if GlobalCacheLock = nil then
    GlobalCacheLock := TCriticalSection.Create;

  GlobalCacheLock.Enter;
  try
    if GlobalCache = nil then
      GlobalCache := TCertVerifyCache.Create;
    Result := GlobalCache;
  finally
    GlobalCacheLock.Leave;
  end;
end;

{ TCertVerifyCache }

constructor TCertVerifyCache.Create(ACapacity: Integer; ATTL: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FCapacity := ACapacity;
  FTTL := ATTL;
  FCount := 0;
  FHits := 0;
  FMisses := 0;
  SetLength(FEntries, FCapacity);
end;

destructor TCertVerifyCache.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TCertVerifyCache.ComputeFingerprint(ACert: PX509): TBytes;
var
  LCtx: PEVP_MD_CTX;
  LDigest: array[0..31] of Byte;
  LLen: Cardinal;
  LDer: TBytes;
  LDerLen: Integer;
  LDerPtr: PByte;
begin
  Result := nil;

  if ACert = nil then
    Exit;

  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;

  if not TOpenSSLLoader.IsModuleLoaded(osmEVP) then
    LoadEVP(GetCryptoLibHandle);

  if not TOpenSSLLoader.IsModuleLoaded(osmX509) then
    LoadOpenSSLX509;

  // Prefer OpenSSL built-in X509_digest when available (no BIO, avoids DER buffer limits).
  if not Assigned(X509_digest) then
    LoadOpenSSLX509;

  if (Assigned(X509_digest)) and (Assigned(EVP_sha256)) then
  begin
    SetLength(Result, 32);
    LLen := 0;
    if X509_digest(ACert, EVP_sha256(), @Result[0], @LLen) <> 1 then
    begin
      SetLength(Result, 0);
      Exit;
    end;
    if LLen <> 32 then
      SetLength(Result, 0);
    Exit;
  end;

  // Fallback: compute digest from DER encoding.
  if not Assigned(i2d_X509) then
    LoadOpenSSLX509;

  if not Assigned(i2d_X509) then
    Exit;

  LDerLen := i2d_X509(ACert, nil);
  if LDerLen <= 0 then
    Exit;

  SetLength(LDer, LDerLen);
  if Length(LDer) <> LDerLen then
    Exit;

  LDerPtr := @LDer[0];
  if i2d_X509(ACert, @LDerPtr) <> LDerLen then
    Exit;

  if (not Assigned(EVP_MD_CTX_new)) or (not Assigned(EVP_MD_CTX_free)) or
    (not Assigned(EVP_DigestInit_ex)) or (not Assigned(EVP_DigestUpdate)) or
    (not Assigned(EVP_DigestFinal_ex)) or (not Assigned(EVP_sha256)) then
    Exit;

  LCtx := EVP_MD_CTX_new();
  if LCtx = nil then
    Exit;

  try
    if EVP_DigestInit_ex(LCtx, EVP_sha256(), nil) <> 1 then
      Exit;
    if EVP_DigestUpdate(LCtx, @LDer[0], Cardinal(Length(LDer))) <> 1 then
      Exit;

    LLen := 32;
    if EVP_DigestFinal_ex(LCtx, @LDigest[0], LLen) <> 1 then
      Exit;

    if LLen <> 32 then
      Exit;

    SetLength(Result, 32);
    Move(LDigest[0], Result[0], 32);
  finally
    EVP_MD_CTX_free(LCtx);
  end;
end;

function TCertVerifyCache.FindEntry(const AFingerprint: TBytes): Integer;
var
  i: Integer;
begin
  Result := -1;
  if Length(AFingerprint) <> 32 then
    Exit;

  for i := 0 to FCount - 1 do
  begin
    if CompareMem(@FEntries[i].Fingerprint[0], @AFingerprint[0], 32) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function TCertVerifyCache.IsExpired(const AEntry: TCacheEntry): Boolean;
begin
  Result := SecondsBetween(Now, AEntry.Result.VerifiedAt) > FTTL;
end;

procedure TCertVerifyCache.EvictOldest;
var
  OldestIdx: Integer;
  OldestTime: TDateTime;
  i: Integer;
begin
  if FCount = 0 then
    Exit;

  OldestIdx := 0;
  OldestTime := FEntries[0].LastAccess;

  for i := 1 to FCount - 1 do
  begin
    if FEntries[i].LastAccess < OldestTime then
    begin
      OldestIdx := i;
      OldestTime := FEntries[i].LastAccess;
    end;
  end;

  // 移除最旧的条目
  if OldestIdx < FCount - 1 then
    Move(FEntries[OldestIdx + 1], FEntries[OldestIdx],
      (FCount - OldestIdx - 1) * SizeOf(TCacheEntry));

  Dec(FCount);
end;

function TCertVerifyCache.TryGet(ACert: PX509; out AResult: TCertVerifyResult): Boolean;
var
  LFingerprint: TBytes;
  LIdx: Integer;
begin
  Result := False;

  FLock.Enter;
  try
    LFingerprint := ComputeFingerprint(ACert);
    if Length(LFingerprint) <> 32 then
    begin
      Inc(FMisses);
      Exit;
    end;

    LIdx := FindEntry(LFingerprint);
    if LIdx < 0 then
    begin
      Inc(FMisses);
      Exit;
    end;

    // 检查是否过期
    if IsExpired(FEntries[LIdx]) then
    begin
      // 删除过期条目
      if LIdx < FCount - 1 then
        Move(FEntries[LIdx + 1], FEntries[LIdx],
          (FCount - LIdx - 1) * SizeOf(TCacheEntry));
      Dec(FCount);
      Inc(FMisses);
      Exit;
    end;

    // 缓存命中
    AResult := FEntries[LIdx].Result;
    FEntries[LIdx].LastAccess := Now;
    Inc(FEntries[LIdx].HitCount);
    Inc(FHits);
    Result := True;

  finally
    FLock.Leave;
  end;
end;

procedure TCertVerifyCache.Put(ACert: PX509; const AResult: TCertVerifyResult);
var
  LFingerprint: TBytes;
  LIdx: Integer;
begin
  FLock.Enter;
  try
    LFingerprint := ComputeFingerprint(ACert);
    if Length(LFingerprint) <> 32 then
      Exit;

    // 检查是否已存在
    LIdx := FindEntry(LFingerprint);
    if LIdx >= 0 then
    begin
      // 更新现有条目
      FEntries[LIdx].Result := AResult;
      FEntries[LIdx].LastAccess := Now;
      Exit;
    end;

    // 添加新条目
    if FCount >= FCapacity then
      EvictOldest;

    LIdx := FCount;
    Inc(FCount);

    Move(LFingerprint[0], FEntries[LIdx].Fingerprint[0], 32);
    FEntries[LIdx].Result := AResult;
    FEntries[LIdx].LastAccess := Now;
    FEntries[LIdx].HitCount := 0;

  finally
    FLock.Leave;
  end;
end;

procedure TCertVerifyCache.Clear;
begin
  FLock.Enter;
  try
    FCount := 0;
    FHits := 0;
    FMisses := 0;
  finally
    FLock.Leave;
  end;
end;

function TCertVerifyCache.GetHitRate: Double;
var
  LTotal: Int64;
begin
  FLock.Enter;
  try
    LTotal := FHits + FMisses;
    if LTotal = 0 then
      Result := 0.0
    else
      Result := (FHits * 100.0) / LTotal;
  finally
    FLock.Leave;
  end;
end;

function TCertVerifyCache.GetSize: Integer;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Leave;
  end;
end;

procedure TCertVerifyCache.GetStats(out AHits, AMisses, ASize: Int64);
begin
  FLock.Enter;
  try
    AHits := FHits;
    AMisses := FMisses;
    ASize := FCount;
  finally
    FLock.Leave;
  end;
end;

initialization

finalization
  if GlobalCache <> nil then
  begin
    GlobalCache.Free;
    GlobalCache := nil;
  end;
  if GlobalCacheLock <> nil then
  begin
    GlobalCacheLock.Free;
    GlobalCacheLock := nil;
  end;

end.
