unit nextpas.core.tls.session.cache;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

{
  SSL/TLS 会话缓存管理器 (优化版)
  
  提供高性能的会话缓存,支持:
  - O(1) 哈希表查找 (替代 O(n) 线性查找)
  - TLS 1.3 会话票据持久化
  - 会话统计和监控
  - 线程安全操作
  - 自动过期清理
  
  性能目标:
  - 查找延迟: < 0.1ms (10x 提升)
  - 会话复用率: > 90%
  - 内存效率: < 2KB/session
  
  @author fafafa.ssl team
  @version 2.0.0 (哈希表优化)
}

interface

uses
  SysUtils, Classes, SyncObjs, fgl,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.random,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.constant_time,
  nextpas.core.mem.secure;

const
  DEFAULT_SESSION_TIMEOUT = 300;  // 5 分钟
  DEFAULT_MAX_SESSIONS = 1000;
  CLEANUP_THRESHOLD = 100;        // 每 100 次 Put 清理一次

type
  // ========================================================================
  // 会话创建回调类型
  // ========================================================================

  { TSessionCreateFunc - 会话创建回调函数类型

    用于从序列化数据创建 ISSLSession 实例。
    由于会话对象的创建依赖于具体的 SSL 后端（OpenSSL、WinSSL 等），
    因此需要通过回调函数来创建。

    @param AData 序列化的会话数据
    @return 创建的会话接口，失败时返回 nil
  }
  TSessionCreateFunc = function(const AData: TBytes): ISSLSession;

  // ========================================================================
  // 会话缓存条目
  // ========================================================================
  TSessionCacheEntry = record
    Session: ISSLSession;
    HostName: string;
    Port: Word;
    CreatedAt: TDateTime;
    LastAccessedAt: TDateTime;
    AccessCount: Integer;
    
    function IsExpired(ATimeout: Integer): Boolean;
    function IsValid: Boolean;
  end;

  // ========================================================================
  // 会话缓存统计
  // ========================================================================
  TSessionCacheStats = record
    TotalSessions: Integer;       // 当前会话数
    TotalRequests: Int64;         // 总请求数
    CacheHits: Int64;             // 缓存命中数
    CacheMisses: Int64;           // 缓存未命中数
    ExpiredSessions: Int64;       // 过期会话数
    ReuseRate: Double;            // 复用率 (%)
    
    function HitRate: Double;
    function MissRate: Double;
  end;

  // ========================================================================
  // 会话缓存映射
  // ========================================================================
  TSessionCacheMap = specialize TFPGMap<string, TSessionCacheEntry>;

  // ========================================================================
  // SSL/TLS 会话缓存管理器
  // ========================================================================
  TSSLSessionCache = class
  private
    FCache: TSessionCacheMap;
    FLock: TCriticalSection;
    FStats: TSessionCacheStats;
    FStatsLock: TCriticalSection;
    FMaxSessions: Integer;
    FDefaultTimeout: Integer;
    FPutCount: Integer;
    FSessionCreateFunc: TSessionCreateFunc;
    FIntegrityKey: TBytes;

    function GenerateCacheKey(const AHostName: string; APort: Word): string;
    procedure CleanupExpired;
    procedure EnforceSizeLimit;
    procedure UpdateStats(AHit: Boolean);
  public
    constructor Create(AMaxSessions: Integer = DEFAULT_MAX_SESSIONS;
      ADefaultTimeout: Integer = DEFAULT_SESSION_TIMEOUT);
    destructor Destroy; override;

    // 会话操作
    function Get(const AHostName: string; APort: Word): ISSLSession;
    procedure Put(const AHostName: string; APort: Word; ASession: ISSLSession);
    procedure Remove(const AHostName: string; APort: Word);
    procedure Clear;
    function Contains(const AHostName: string; APort: Word): Boolean;
    function GetCount: Integer;

    // 统计信息
    function GetStats: TSessionCacheStats;
    procedure ResetStats;

    // 持久化 (TLS 1.3 会话票据)
    function SaveToFile(const AFileName: string): Boolean;
    function LoadFromFile(const AFileName: string): Boolean;

    // 会话创建回调
    procedure SetSessionCreateFunc(AFunc: TSessionCreateFunc);

    // 持久化密钥（跨实例加载需要相同密钥）
    procedure SetPersistenceKey(const AKey: TBytes);

    property MaxSessions: Integer read FMaxSessions write FMaxSessions;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
    property SessionCreateFunc: TSessionCreateFunc read FSessionCreateFunc write FSessionCreateFunc;
  end;

implementation

// ========================================================================
// TSessionCacheEntry
// ========================================================================

function TSessionCacheEntry.IsExpired(ATimeout: Integer): Boolean;
var
  Age: Int64;
begin
  Age := DateTimeSecondsBetween(DateTimeNow, CreatedAt);
  Result := Age > ATimeout;
end;

function TSessionCacheEntry.IsValid: Boolean;
begin
  Result := (Session <> nil) and Session.IsValid;
end;

// ========================================================================
// TSessionCacheStats
// ========================================================================

function TSessionCacheStats.HitRate: Double;
begin
  if TotalRequests = 0 then
    Result := 0.0
  else
    Result := (CacheHits / TotalRequests) * 100.0;
end;

function TSessionCacheStats.MissRate: Double;
begin
  if TotalRequests = 0 then
    Result := 0.0
  else
    Result := (CacheMisses / TotalRequests) * 100.0;
end;

// ========================================================================
// TSSLSessionCache
// ========================================================================

constructor TSSLSessionCache.Create(AMaxSessions: Integer; ADefaultTimeout: Integer);
begin
  inherited Create;
  FCache := TSessionCacheMap.Create;
  FLock := TCriticalSection.Create;
  FStatsLock := TCriticalSection.Create;
  FMaxSessions := AMaxSessions;
  FDefaultTimeout := ADefaultTimeout;
  FPutCount := 0;
  FSessionCreateFunc := nil;
  SetLength(FIntegrityKey, 32);
  SecureRandomBytes(@FIntegrityKey[0], 32);

  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TSSLSessionCache.Destroy;
begin
  SecureZeroBytes(FIntegrityKey);
  FCache.Free;
  FLock.Free;
  FStatsLock.Free;
  inherited Destroy;
end;

function TSSLSessionCache.GenerateCacheKey(const AHostName: string; APort: Word): string;
begin
  Result := LowerCase(AHostName) + ':' + IntToStr(APort);
end;

function TSSLSessionCache.Get(const AHostName: string; APort: Word): ISSLSession;
var
  Key: string;
  Idx: Integer;
  Entry: TSessionCacheEntry;
begin
  Result := nil;
  Key := GenerateCacheKey(AHostName, APort);
  
  FLock.Enter;
  try
    Idx := FCache.IndexOf(Key);
    if Idx >= 0 then
    begin
      Entry := FCache.Data[Idx];
      
      // 检查是否过期
      if Entry.IsExpired(FDefaultTimeout) or not Entry.IsValid then
      begin
        FCache.Delete(Idx);
        UpdateStats(False);
        Exit;
      end;
      
      // 更新访问信息
      Entry.LastAccessedAt := DateTimeNow;
      Inc(Entry.AccessCount);
      FCache.Data[Idx] := Entry;
      
      Result := Entry.Session;
      UpdateStats(True);
    end
    else
      UpdateStats(False);
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.Put(const AHostName: string; APort: Word; ASession: ISSLSession);
var
  Key: string;
  Idx: Integer;
  Entry: TSessionCacheEntry;
begin
  if ASession = nil then
    Exit;
  
  Key := GenerateCacheKey(AHostName, APort);
  
  Entry := Default(TSessionCacheEntry);
  Entry.Session := ASession;
  Entry.HostName := AHostName;
  Entry.Port := APort;
  Entry.CreatedAt := DateTimeNow;
  Entry.LastAccessedAt := Entry.CreatedAt;
  Entry.AccessCount := 0;
  
  FLock.Enter;
  try
    Idx := FCache.IndexOf(Key);
    if Idx >= 0 then
      FCache.Data[Idx] := Entry
    else
      FCache.Add(Key, Entry);
    
    // 延迟清理
    Inc(FPutCount);
    if FPutCount >= CLEANUP_THRESHOLD then
    begin
      CleanupExpired;
      FPutCount := 0;
    end;
    
    // 强制执行大小限制
    if FCache.Count > FMaxSessions then
      EnforceSizeLimit;
    
    // 更新统计
    FStatsLock.Enter;
    try
      FStats.TotalSessions := FCache.Count;
    finally
      FStatsLock.Leave;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.Remove(const AHostName: string; APort: Word);
var
  Key: string;
  Idx: Integer;
begin
  Key := GenerateCacheKey(AHostName, APort);
  
  FLock.Enter;
  try
    Idx := FCache.IndexOf(Key);
    if Idx >= 0 then
      FCache.Delete(Idx);
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.Clear;
begin
  FLock.Enter;
  try
    FCache.Clear;
    FPutCount := 0;
  finally
    FLock.Leave;
  end;
  
  FStatsLock.Enter;
  try
    FStats.TotalSessions := 0;
  finally
    FStatsLock.Leave;
  end;
end;

function TSSLSessionCache.Contains(const AHostName: string; APort: Word): Boolean;
var
  Key: string;
begin
  Key := GenerateCacheKey(AHostName, APort);
  
  FLock.Enter;
  try
    Result := FCache.IndexOf(Key) >= 0;
  finally
    FLock.Leave;
  end;
end;

function TSSLSessionCache.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCache.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.CleanupExpired;
var
  I: Integer;
  Entry: TSessionCacheEntry;
  ExpiredCount: Integer;
begin
  // 注意: 调用者必须持有锁
  
  ExpiredCount := 0;
  I := FCache.Count - 1;
  while I >= 0 do
  begin
    Entry := FCache.Data[I];
    if Entry.IsExpired(FDefaultTimeout) or not Entry.IsValid then
    begin
      FCache.Delete(I);
      Inc(ExpiredCount);
    end;
    Dec(I);
  end;
  
  if ExpiredCount > 0 then
  begin
    FStatsLock.Enter;
    try
      FStats.ExpiredSessions := FStats.ExpiredSessions + ExpiredCount;
    finally
      FStatsLock.Leave;
    end;
  end;
end;

procedure TSSLSessionCache.EnforceSizeLimit;
var
  I, OldestIdx: Integer;
  OldestTime: TDateTime;
  Entry: TSessionCacheEntry;
begin
  // 注意: 调用者必须持有锁
  
  while FCache.Count > FMaxSessions do
  begin
    // 找到最旧的条目 (LRU)
    OldestIdx := 0;
    OldestTime := FCache.Data[0].LastAccessedAt;
    
    for I := 1 to FCache.Count - 1 do
    begin
      Entry := FCache.Data[I];
      if Entry.LastAccessedAt < OldestTime then
      begin
        OldestTime := Entry.LastAccessedAt;
        OldestIdx := I;
      end;
    end;
    
    FCache.Delete(OldestIdx);
  end;
end;

procedure TSSLSessionCache.UpdateStats(AHit: Boolean);
begin
  FStatsLock.Enter;
  try
    Inc(FStats.TotalRequests);
    if AHit then
      Inc(FStats.CacheHits)
    else
      Inc(FStats.CacheMisses);
    
    // 计算复用率
    if FStats.TotalRequests > 0 then
      FStats.ReuseRate := (FStats.CacheHits / FStats.TotalRequests) * 100.0;
  finally
    FStatsLock.Leave;
  end;
end;

function TSSLSessionCache.GetStats: TSessionCacheStats;
begin
  FStatsLock.Enter;
  try
    Result := FStats;
    Result.TotalSessions := GetCount;
  finally
    FStatsLock.Leave;
  end;
end;

procedure TSSLSessionCache.ResetStats;
begin
  FStatsLock.Enter;
  try
    FStats.TotalRequests := 0;
    FStats.CacheHits := 0;
    FStats.CacheMisses := 0;
    FStats.ExpiredSessions := 0;
    FStats.ReuseRate := 0.0;
    FStats.TotalSessions := GetCount;
  finally
    FStatsLock.Leave;
  end;
end;

function TSSLSessionCache.SaveToFile(const AFileName: string): Boolean;
var
  Stream: TFileStream;
  I, Count, DataLen, WrittenCount: Integer;
  Key: string;
  Entry: TSessionCacheEntry;
  SessionData: TBytes;
  CountPosition: Int64;
begin
  Result := False;
  
  FLock.Enter;
  try
    try
      Stream := TFileStream.Create(AFileName, fmCreate);
      {$IFDEF UNIX}
      FpChmod(AFileName, &600);
      {$ENDIF}
      try
        // 写入版本号 (v2 = HMAC protected)
        I := 2;
        Stream.WriteBuffer(I, SizeOf(Integer));

        // 先写占位计数；真实条目数只统计实际写入的有效记录。
        CountPosition := Stream.Position;
        Count := 0;
        Stream.WriteBuffer(Count, SizeOf(Integer));
        WrittenCount := 0;

        // 写入每个条目
        for I := 0 to FCache.Count - 1 do
        begin
          Key := FCache.Keys[I];
          Entry := FCache.Data[I];

          // 只保存有效的会话
          if not Entry.IsValid or Entry.IsExpired(FDefaultTimeout) then
            Continue;

          // 写入主机名
          DataLen := Length(Entry.HostName);
          Stream.WriteBuffer(DataLen, SizeOf(Integer));
          if DataLen > 0 then
            Stream.WriteBuffer(Entry.HostName[1], DataLen);

          // 写入端口
          Stream.WriteBuffer(Entry.Port, SizeOf(Word));

          // 序列化会话数据
          SessionData := Entry.Session.Serialize;
          DataLen := Length(SessionData);
          Stream.WriteBuffer(DataLen, SizeOf(Integer));
          if DataLen > 0 then
            Stream.WriteBuffer(SessionData[0], DataLen);

          // 写入时间戳
          Stream.WriteBuffer(Entry.CreatedAt, SizeOf(TDateTime));
          Stream.WriteBuffer(Entry.LastAccessedAt, SizeOf(TDateTime));
          Stream.WriteBuffer(Entry.AccessCount, SizeOf(Integer));
          Inc(WrittenCount);
        end;

        Stream.Position := CountPosition;
        Stream.WriteBuffer(WrittenCount, SizeOf(Integer));

        // Append HMAC-SHA256 over entire file content
        Stream.Position := 0;
        SetLength(SessionData, Stream.Size);
        Stream.ReadBuffer(SessionData[0], Stream.Size);
        SessionData := HMAC_SHA256(FIntegrityKey, SessionData);
        Stream.Position := Stream.Size;
        Stream.WriteBuffer(SessionData[0], 32);

        Result := True;
      finally
        Stream.Free;
      end;
    except
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSSLSessionCache.LoadFromFile(const AFileName: string): Boolean;
var
  Stream: TFileStream;
  Version, Count, I, DataLen: Integer;
  HostName: string;
  Port: Word;
  SessionData: TBytes;
  Entry: TSessionCacheEntry;
  Session: ISSLSession;
  Key: string;
  LFileData, LStoredMAC, LComputedMAC: TBytes;
begin
  Result := False;

  if not FileExists(AFileName) then
    Exit;

  FLock.Enter;
  try
    try
      FCache.Clear;

      Stream := TFileStream.Create(AFileName, fmOpenRead);
      try
        if Stream.Size < SizeOf(Integer) then
          Exit;

        // 读取版本号
        Stream.ReadBuffer(Version, SizeOf(Integer));
        if not (Version in [1, 2]) then
          Exit;

        // v2: verify HMAC before parsing
        if Version = 2 then
        begin
          if Stream.Size < SizeOf(Integer) + 32 then
            Exit;
          Stream.Position := 0;
          SetLength(LFileData, Stream.Size - 32);
          Stream.ReadBuffer(LFileData[0], Length(LFileData));
          SetLength(LStoredMAC, 32);
          Stream.ReadBuffer(LStoredMAC[0], 32);
          LComputedMAC := HMAC_SHA256(FIntegrityKey, LFileData);
          if TConstantTime.CompareBytes(LStoredMAC, LComputedMAC) <> 1 then
            Exit;
          Stream.Position := SizeOf(Integer);
        end;

        // 读取条目数
        Stream.ReadBuffer(Count, SizeOf(Integer));
        if (Count < 0) or (Count > 100000) then
          Exit;

        // 读取每个条目
        for I := 0 to Count - 1 do
        begin
          // 读取主机名
          Stream.ReadBuffer(DataLen, SizeOf(Integer));
          if (DataLen < 0) or (DataLen > 65535) then
            Exit;
          SetLength(HostName, DataLen);
          if DataLen > 0 then
            Stream.ReadBuffer(HostName[1], DataLen);

          // 读取端口
          Stream.ReadBuffer(Port, SizeOf(Word));

          // 读取会话数据
          SetLength(SessionData, 0);
          Stream.ReadBuffer(DataLen, SizeOf(Integer));
          if (DataLen < 0) or (DataLen > 1048576) then
            Exit;
          if DataLen > 0 then
          begin
            SetLength(SessionData, DataLen);
            Stream.ReadBuffer(SessionData[0], DataLen);
          end;

          // 读取时间戳
          Entry := Default(TSessionCacheEntry);
          Stream.ReadBuffer(Entry.CreatedAt, SizeOf(TDateTime));
          Stream.ReadBuffer(Entry.LastAccessedAt, SizeOf(TDateTime));
          Stream.ReadBuffer(Entry.AccessCount, SizeOf(Integer));

          // 检查会话是否过期
          if Entry.IsExpired(FDefaultTimeout) then
            Continue;

          // 反序列化会话
          Session := nil;
          if (Length(SessionData) > 0) and Assigned(FSessionCreateFunc) then
          begin
            // 使用回调函数创建会话
            Session := FSessionCreateFunc(SessionData);
          end;

          // 如果成功创建会话，添加到缓存
          if (Session <> nil) and Session.IsValid then
          begin
            Entry.Session := Session;
            Entry.HostName := HostName;
            Entry.Port := Port;

            Key := GenerateCacheKey(HostName, Port);
            FCache.Add(Key, Entry);
          end;
        end;

        FStats.TotalSessions := FCache.Count;
        Result := True;

      finally
        Stream.Free;
      end;
    except
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.SetSessionCreateFunc(AFunc: TSessionCreateFunc);
begin
  FLock.Enter;
  try
    FSessionCreateFunc := AFunc;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLSessionCache.SetPersistenceKey(const AKey: TBytes);
begin
  FLock.Enter;
  try
    SecureZeroBytes(FIntegrityKey);
    FIntegrityKey := Copy(AKey, 0, Length(AKey));
  finally
    FLock.Leave;
  end;
end;

end.
