unit nextpas.core.tls.aesgcm.pool;

{$mode objfpc}{$H+}{$J-}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses SyncObjs, nextpas.core.time, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.rand, nextpas.core.tls.exceptions; const // GCM 标准 IV 长度：12 字节（96 位） GCM_IV_LENGTH = 12;

  // IV 结构：[8字节随机基础] + [4字节计数器]
  GCM_IV_BASE_LENGTH = 8;
  GCM_IV_COUNTER_LENGTH = 4;

  // 默认池大小
  DEFAULT_POOL_SIZE = 16;

  // 计数器溢出阈值（接近 2^32 时重新生成基础值）
  IV_COUNTER_MAX = $FFFFFFFE;

type
  { AES-GCM 上下文条目 }
  TAESGCMContextEntry = record
    Ctx: PEVP_CIPHER_CTX;      // OpenSSL 上下文
    KeyHash: TBytes;            // 密钥的 SHA-256 哈希（用于匹配）
    IsEncrypt: Boolean;         // 加密还是解密
    IVBase: TBytes;             // IV 基础值（8字节随机）
    IVCounter: UInt32;          // IV 计数器（4字节）
    LastUsed: TDateTime;        // 最后使用时间（LRU）
    InUse: Boolean;             // 是否正在使用
    Initialized: Boolean;       // 是否已初始化
  end;

  { AES-GCM 上下文池统计信息 }
  TAESGCMPoolStats = record
    TotalRequests: Int64;       // 总请求数
    CacheHits: Int64;           // 缓存命中数
    CacheMisses: Int64;         // 缓存未命中数
    ContextResets: Int64;       // 上下文重置次数
    IVBaseRegens: Int64;        // IV 基础值重新生成次数
    HitRate: Double;            // 命中率（百分比）
  end;

  { AES-GCM 上下文池配置 }
  TAESGCMPoolConfig = record
    Enabled: Boolean;           // 是否启用上下文池
    PoolSize: Integer;          // 池大小
  end;

  { AES-GCM 上下文池 }
  TAESGCMContextPool = class
  private
    FEntries: array of TAESGCMContextEntry;
    FLock: TCriticalSection;
    FPoolSize: Integer;
    FEnabled: Boolean;

    // 统计信息
    FTotalRequests: Int64;
    FCacheHits: Int64;
    FCacheMisses: Int64;
    FContextResets: Int64;
    FIVBaseRegens: Int64;

    { 计算密钥的 SHA-256 哈希 }
    function ComputeKeyHash(const AKey: TBytes): TBytes;

    { 查找或创建上下文条目 }
    function FindOrCreateEntry(const AKey: TBytes; AIsEncrypt: Boolean): Integer;

    { 生成唯一的 IV }
    function GenerateUniqueIV(AEntryIndex: Integer): TBytes;

    { 重新生成 IV 基础值 }
    procedure RegenerateIVBase(AEntryIndex: Integer);

    { 初始化上下文条目 }
    procedure InitializeEntry(AEntryIndex: Integer; const AKey: TBytes; AIsEncrypt: Boolean);

    { 重置上下文条目 }
    procedure ResetEntry(AEntryIndex: Integer; const AKey: TBytes; AIsEncrypt: Boolean);

    { 查找最旧的未使用条目（LRU） }
    function FindLRUEntry: Integer;

  public
    constructor Create(const AConfig: TAESGCMPoolConfig);
    destructor Destroy; override;

    { 获取上下文并生成唯一 IV }
    function AcquireContextWithIV(
      const AKey: TBytes;
      AIsEncrypt: Boolean;
      out AIV: TBytes
    ): PEVP_CIPHER_CTX;

    { 归还上下文到池中 }
    procedure ReleaseContext(ACtx: PEVP_CIPHER_CTX);

    { 获取统计信息 }
    function GetStats: TAESGCMPoolStats;

    { 重置统计信息 }
    procedure ResetStats;

    property Enabled: Boolean read FEnabled;
    property PoolSize: Integer read FPoolSize;
  end;

{ 全局上下文池实例 }
function GetGlobalAESGCMPool: TAESGCMContextPool;

{ 使用全局池获取上下文（便捷函数） }
function PooledAESGCMContext(
  const AKey: TBytes;
  AIsEncrypt: Boolean;
  out AIV: TBytes
): PEVP_CIPHER_CTX;

{ 创建默认配置 }
function DefaultAESGCMPoolConfig: TAESGCMPoolConfig;

implementation

var
  GlobalAESGCMPool: TAESGCMContextPool = nil;

{ 配置函数 }

function DefaultAESGCMPoolConfig: TAESGCMPoolConfig;
begin
  Result.Enabled := True;
  Result.PoolSize := DEFAULT_POOL_SIZE;
end;

{ TAESGCMContextPool }

constructor TAESGCMContextPool.Create(const AConfig: TAESGCMPoolConfig);
var
  I: Integer;
begin
  inherited Create;

  FEnabled := AConfig.Enabled;
  FPoolSize := AConfig.PoolSize;
  FLock := TCriticalSection.Create;

  // 预分配上下文条目
  SetLength(FEntries, FPoolSize);

  // 初始化所有条目
  for I := 0 to FPoolSize - 1 do
  begin
    FEntries[I].Ctx := nil;
    FEntries[I].KeyHash := nil;
    FEntries[I].IsEncrypt := False;
    FEntries[I].IVBase := nil;
    FEntries[I].IVCounter := 0;
    FEntries[I].LastUsed := 0;
    FEntries[I].InUse := False;
    FEntries[I].Initialized := False;
  end;

  // 初始化统计信息
  FTotalRequests := 0;
  FCacheHits := 0;
  FCacheMisses := 0;
  FContextResets := 0;
  FIVBaseRegens := 0;
end;

destructor TAESGCMContextPool.Destroy;
var
  I: Integer;
begin
  // 释放所有上下文
  for I := 0 to FPoolSize - 1 do
  begin
    if FEntries[I].Ctx <> nil then
      EVP_CIPHER_CTX_free(FEntries[I].Ctx);
  end;

  FLock.Free;
  inherited Destroy;
end;

function TAESGCMContextPool.ComputeKeyHash(const AKey: TBytes): TBytes;
var
  LCtx: PEVP_MD_CTX;
  LMD: PEVP_MD;
  LOutLen: Cardinal;
begin
  // 使用 OpenSSL EVP 直接计算 SHA-256 哈希
  SetLength(Result, 32); // SHA-256 输出 32 字节

  // 检查 EVP 函数是否已加载
  if not Assigned(EVP_sha256) then
    raise ESSLCryptoError.Create('EVP_sha256 function not loaded - OpenSSL EVP module not initialized');

  if not Assigned(EVP_MD_CTX_new) then
    raise ESSLCryptoError.Create('EVP_MD_CTX_new function not loaded - OpenSSL EVP module not initialized');

  LMD := EVP_sha256();
  if LMD = nil then
    raise ESSLCryptoError.Create('Failed to get SHA-256 digest');

  LCtx := EVP_MD_CTX_new();
  if LCtx = nil then
    raise ESSLCryptoError.Create('Failed to create digest context');

  try
    if EVP_DigestInit_ex(LCtx, LMD, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize SHA-256 digest');

    if Length(AKey) > 0 then
      if EVP_DigestUpdate(LCtx, @AKey[0], Length(AKey)) <> 1 then
        raise ESSLCryptoError.Create('Failed to update SHA-256 digest');

    LOutLen := 32;
    if EVP_DigestFinal_ex(LCtx, @Result[0], LOutLen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize SHA-256 digest');
  finally
    EVP_MD_CTX_free(LCtx);
  end;
end;

function TAESGCMContextPool.FindOrCreateEntry(const AKey: TBytes; AIsEncrypt: Boolean): Integer;
var
  I: Integer;
  LKeyHash: TBytes;
  LFound: Boolean;
begin
  LKeyHash := ComputeKeyHash(AKey);
  LFound := False;
  Result := -1;

  // 1. 查找匹配的现有条目（相同密钥哈希 + 加密模式）
  for I := 0 to FPoolSize - 1 do
  begin
    if FEntries[I].Initialized and
      (not FEntries[I].InUse) and
      (FEntries[I].IsEncrypt = AIsEncrypt) and
      (Length(FEntries[I].KeyHash) = Length(LKeyHash)) then
    begin
      // 比较密钥哈希
      if CompareMem(@FEntries[I].KeyHash[0], @LKeyHash[0], Length(LKeyHash)) then
      begin
        Result := I;
        LFound := True;
        Inc(FCacheHits);
        Break;
      end;
    end;
  end;

  // 2. 如果未找到，使用 LRU 策略选择一个条目
  if not LFound then
  begin
    Result := FindLRUEntry;
    Inc(FCacheMisses);

    // 重置或初始化条目
    if FEntries[Result].Initialized then
      ResetEntry(Result, AKey, AIsEncrypt)
    else
      InitializeEntry(Result, AKey, AIsEncrypt);
  end;
end;

function TAESGCMContextPool.FindLRUEntry: Integer;
var
  I: Integer;
  LOldestTime: TDateTime;
begin
  Result := 0;
  LOldestTime := DateTimeNow;

  // 查找最旧的未使用条目
  for I := 0 to FPoolSize - 1 do
  begin
    if not FEntries[I].InUse then
    begin
      if (not FEntries[I].Initialized) or (FEntries[I].LastUsed < LOldestTime) then
      begin
        LOldestTime := FEntries[I].LastUsed;
        Result := I;
      end;
    end;
  end;
end;

procedure TAESGCMContextPool.InitializeEntry(AEntryIndex: Integer; const AKey: TBytes; AIsEncrypt: Boolean);
begin
  // 检查 EVP_CIPHER_CTX_new 函数指针是否已加载
  if not Assigned(EVP_CIPHER_CTX_new) then
    raise ESSLCryptoError.Create('EVP_CIPHER_CTX_new function not loaded');

  // 创建新的 OpenSSL 上下文
  FEntries[AEntryIndex].Ctx := EVP_CIPHER_CTX_new();
  if FEntries[AEntryIndex].Ctx = nil then
    raise ESSLCryptoError.Create('Failed to create AES-GCM context');

  // 保存密钥哈希和加密模式
  FEntries[AEntryIndex].KeyHash := ComputeKeyHash(AKey);
  FEntries[AEntryIndex].IsEncrypt := AIsEncrypt;

  // 生成初始 IV 基础值
  SetLength(FEntries[AEntryIndex].IVBase, GCM_IV_BASE_LENGTH);
  if RAND_bytes(@FEntries[AEntryIndex].IVBase[0], GCM_IV_BASE_LENGTH) <> 1 then
    raise ESSLCryptoError.Create('Failed to generate IV base');

  // 初始化计数器
  FEntries[AEntryIndex].IVCounter := 0;

  // 标记为已初始化
  FEntries[AEntryIndex].Initialized := True;
  FEntries[AEntryIndex].LastUsed := DateTimeNow;
end;

procedure TAESGCMContextPool.ResetEntry(AEntryIndex: Integer; const AKey: TBytes; AIsEncrypt: Boolean);
begin
  // 重置 OpenSSL 上下文（比 free + new 更快）
  if EVP_CIPHER_CTX_reset(FEntries[AEntryIndex].Ctx) <> 1 then
    raise ESSLCryptoError.Create('Failed to reset AES-GCM context');

  // 更新密钥哈希和加密模式
  FEntries[AEntryIndex].KeyHash := ComputeKeyHash(AKey);
  FEntries[AEntryIndex].IsEncrypt := AIsEncrypt;

  // 重新生成 IV 基础值
  RegenerateIVBase(AEntryIndex);

  // 更新统计
  Inc(FContextResets);
  FEntries[AEntryIndex].LastUsed := DateTimeNow;
end;

procedure TAESGCMContextPool.RegenerateIVBase(AEntryIndex: Integer);
begin
  // 生成新的 IV 基础值
  SetLength(FEntries[AEntryIndex].IVBase, GCM_IV_BASE_LENGTH);
  if RAND_bytes(@FEntries[AEntryIndex].IVBase[0], GCM_IV_BASE_LENGTH) <> 1 then
    raise ESSLCryptoError.Create('Failed to regenerate IV base');

  // 重置计数器
  FEntries[AEntryIndex].IVCounter := 0;

  // 更新统计
  Inc(FIVBaseRegens);
end;

function TAESGCMContextPool.GenerateUniqueIV(AEntryIndex: Integer): TBytes;
var
  LCounter: UInt32;
begin
  // 检查计数器是否溢出
  if FEntries[AEntryIndex].IVCounter >= IV_COUNTER_MAX then
    RegenerateIVBase(AEntryIndex);

  // 递增计数器
  LCounter := FEntries[AEntryIndex].IVCounter;
  Inc(FEntries[AEntryIndex].IVCounter);

  // 构造 IV：[8字节基础] + [4字节计数器]
  SetLength(Result, GCM_IV_LENGTH);
  Move(FEntries[AEntryIndex].IVBase[0], Result[0], GCM_IV_BASE_LENGTH);

  // 将计数器转换为大端字节序（网络字节序）
  Result[8] := Byte((LCounter shr 24) and $FF);
  Result[9] := Byte((LCounter shr 16) and $FF);
  Result[10] := Byte((LCounter shr 8) and $FF);
  Result[11] := Byte(LCounter and $FF);
end;

function TAESGCMContextPool.AcquireContextWithIV(
  const AKey: TBytes;
  AIsEncrypt: Boolean;
  out AIV: TBytes
): PEVP_CIPHER_CTX;
var
  LEntryIndex: Integer;
begin
  if not FEnabled then
  begin
    // 如果未启用池，返回 nil（调用者应使用传统方式）
    Result := nil;
    AIV := nil;
    Exit;
  end;

  FLock.Enter;
  try
    Inc(FTotalRequests);

    // 查找或创建上下文条目
    LEntryIndex := FindOrCreateEntry(AKey, AIsEncrypt);

    // 标记为正在使用
    FEntries[LEntryIndex].InUse := True;
    FEntries[LEntryIndex].LastUsed := DateTimeNow;

    // 生成唯一 IV
    AIV := GenerateUniqueIV(LEntryIndex);

    // 返回上下文
    Result := FEntries[LEntryIndex].Ctx;
  finally
    FLock.Leave;
  end;
end;

procedure TAESGCMContextPool.ReleaseContext(ACtx: PEVP_CIPHER_CTX);
var
  I: Integer;
begin
  if not FEnabled then
    Exit;

  FLock.Enter;
  try
    // 查找对应的条目并标记为未使用
    for I := 0 to FPoolSize - 1 do
    begin
      if FEntries[I].Ctx = ACtx then
      begin
        FEntries[I].InUse := False;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TAESGCMContextPool.GetStats: TAESGCMPoolStats;
begin
  FLock.Enter;
  try
    Result.TotalRequests := FTotalRequests;
    Result.CacheHits := FCacheHits;
    Result.CacheMisses := FCacheMisses;
    Result.ContextResets := FContextResets;
    Result.IVBaseRegens := FIVBaseRegens;

    if FTotalRequests > 0 then
      Result.HitRate := (FCacheHits / FTotalRequests) * 100.0
    else
      Result.HitRate := 0.0;
  finally
    FLock.Leave;
  end;
end;

procedure TAESGCMContextPool.ResetStats;
begin
  FLock.Enter;
  try
    FTotalRequests := 0;
    FCacheHits := 0;
    FCacheMisses := 0;
    FContextResets := 0;
    FIVBaseRegens := 0;
  finally
    FLock.Leave;
  end;
end;

{ 全局函数 }

function GetGlobalAESGCMPool: TAESGCMContextPool;
begin
  if GlobalAESGCMPool = nil then
    GlobalAESGCMPool := TAESGCMContextPool.Create(DefaultAESGCMPoolConfig);
  Result := GlobalAESGCMPool;
end;

function PooledAESGCMContext(
  const AKey: TBytes;
  AIsEncrypt: Boolean;
  out AIV: TBytes
): PEVP_CIPHER_CTX;
begin
  Result := GetGlobalAESGCMPool.AcquireContextWithIV(AKey, AIsEncrypt, AIV);
end;

initialization
  GlobalAESGCMPool := nil;

finalization
  if GlobalAESGCMPool <> nil then
    GlobalAESGCMPool.Free;

end.
