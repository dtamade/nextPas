unit nextpas.core.tls.ocsp.cache;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

{
  OCSP 响应缓存模块 (分片锁优化版)
  
  提供线程安全的 OCSP 响应缓存,支持:
  - 基于证书序列号的缓存键
  - 基于 nextUpdate 的自动过期
  - 缓存统计 (命中率、大小)
  - 可选的持久化存储
  - 分片锁机制提升并发性能
  
  @author fafafa.ssl team
  @version 2.0.0 (分片锁优化)
}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
   nextpas.core.sync, DateUtils, fgl;

const
  SHARD_COUNT = 16;  // 分片数量 (2的幂次方,便于位运算)

type
  // ========================================================================
  // 缓存条目
  // ========================================================================
  TOCSPCacheEntry = record
    ResponseData: TBytes;        // DER 编码的 OCSP 响应
    ThisUpdate: TDateTime;       // 响应生成时间
    NextUpdate: TDateTime;       // 响应过期时间
    CachedAt: TDateTime;         // 缓存时间
    HitCount: Integer;           // 命中次数
    
    function IsExpired: Boolean;
    function IsValid: Boolean;
  end;

  // ========================================================================
  // 缓存统计
  // ========================================================================
  TOCSPCacheStats = record
    TotalRequests: Int64;        // 总请求数
    CacheHits: Int64;            // 缓存命中数
    CacheMisses: Int64;          // 缓存未命中数
    TotalEntries: Integer;       // 当前条目数
    ExpiredEntries: Integer;     // 过期条目数
    Hits: Int64;                 // 别名 for CacheHits
    Misses: Int64;               // 别名 for CacheMisses
    
    function HitRate: Double;
    function MissRate: Double;
  end;

  // ========================================================================
  // 缓存字典类型
  // ========================================================================
  TOCSPCacheMap = specialize TFPGMap<string, TOCSPCacheEntry>;

  // ========================================================================
  // 缓存分片
  // ========================================================================
  TOCSPCacheShard = record
    Cache: TOCSPCacheMap;
    Lock: IMutex;
    PutCount: Integer;           // Put 操作计数,用于延迟清理
  end;

  // ========================================================================
  // OCSP 响应缓存 (分片锁版本)
  // ========================================================================
  TOCSPResponseCache = class
  private
    FShards: array[0..SHARD_COUNT-1] of TOCSPCacheShard;
    FStats: TOCSPCacheStats;
    FStatsLock: IMutex;  // 统计信息的独立锁
    FMaxEntries: Integer;
    FDefaultTTL: Integer;
    FCleanupThreshold: Integer;
    
    function GetShardIndex(const AKey: string): Integer;
    procedure CleanupExpiredInShard(AShardIndex: Integer);
    procedure EnforceSizeLimitInShard(AShardIndex: Integer);
    function GenerateCacheKey(const ASerialNumber: TBytes): string;
  public
    constructor Create(AMaxEntries: Integer = 1000; ADefaultTTL: Integer = 3600);
    destructor Destroy; override;
    
    // 缓存操作
    function Get(const ASerialNumber: TBytes; out AResponse: TBytes): Boolean;
    procedure Put(const ASerialNumber: TBytes; const AResponse: TBytes;
      AThisUpdate, ANextUpdate: TDateTime);
    procedure Remove(const ASerialNumber: TBytes);
    procedure Clear;
    function Contains(const ASerialNumber: TBytes): Boolean;
    function GetCount: Integer;
    
    // 统计信息
    function GetStats: TOCSPCacheStats;
    procedure ResetStats;
    
    // 持久化 (可选)
    function SaveToFile(const AFileName: string): Boolean;
    function LoadFromFile(const AFileName: string): Boolean;
    
    property MaxEntries: Integer read FMaxEntries write FMaxEntries;
    property DefaultTTL: Integer read FDefaultTTL write FDefaultTTL;
  end;

implementation

uses
  nextpas.core.crypto.hash,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.text.conv,
  nextpas.core.io.binary,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.time;

// ========================================================================
// TOCSPCacheEntry
// ========================================================================

function TOCSPCacheEntry.IsExpired: Boolean;
begin
  if NextUpdate = 0 then
    Result := False
  else
    Result := DateTimeUtcNow >= NextUpdate;
end;

function TOCSPCacheEntry.IsValid: Boolean;
begin
  Result := (Length(ResponseData) > 0) and not IsExpired;
end;

// ========================================================================
// TOCSPCacheStats
// ========================================================================

function TOCSPCacheStats.HitRate: Double;
begin
  if TotalRequests = 0 then
    Result := 0.0
  else
    Result := (CacheHits / TotalRequests) * 100.0;
end;

function TOCSPCacheStats.MissRate: Double;
begin
  if TotalRequests = 0 then
    Result := 0.0
  else
    Result := (CacheMisses / TotalRequests) * 100.0;
end;

// ========================================================================
// TOCSPResponseCache
// ========================================================================

constructor TOCSPResponseCache.Create(AMaxEntries: Integer; ADefaultTTL: Integer);
var
  I: Integer;
begin
  inherited Create;
  
  // 初始化每个分片
  for I := 0 to SHARD_COUNT - 1 do
  begin
    FShards[I].Cache := TOCSPCacheMap.Create;
    FShards[I].Lock := Mutex;
    FShards[I].PutCount := 0;
  end;
  
  FStatsLock := Mutex;
  FMaxEntries := AMaxEntries;
  FDefaultTTL := ADefaultTTL;
  FCleanupThreshold := 100;
  
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TOCSPResponseCache.Destroy;
var
  I: Integer;
begin
  for I := 0 to SHARD_COUNT - 1 do
  begin
    FShards[I].Cache.Free;
    FShards[I].Lock := nil;
  end;
  
  FStatsLock := nil;
  inherited Destroy;
end;

function TOCSPResponseCache.GetShardIndex(const AKey: string): Integer;
var
  Hash: Cardinal;
  I: Integer;
begin
  // 简单的哈希函数计算分片索引
  Hash := 0;
  for I := 1 to Length(AKey) do
    Hash := Hash * 31 + Ord(AKey[I]);
  
  // 使用位运算取模 (SHARD_COUNT 必须是 2 的幂次方)
  Result := Hash and (SHARD_COUNT - 1);
end;

function TOCSPResponseCache.GenerateCacheKey(const ASerialNumber: TBytes): string;
var
  Hash: TBytes;
  I: Integer;
begin
  Hash := SHA256(ASerialNumber);
  Result := '';
  for I := 0 to Length(Hash) - 1 do
    Result := Result + IntToHex(Hash[I], 2);
end;

function TOCSPResponseCache.Get(const ASerialNumber: TBytes; out AResponse: TBytes): Boolean;
var
  Key: string;
  ShardIdx, Idx: Integer;
  Entry: TOCSPCacheEntry;
begin
  Result := False;
  SetLength(AResponse, 0);
  
  Key := GenerateCacheKey(ASerialNumber);
  ShardIdx := GetShardIndex(Key);
  
  // 只锁定对应的分片
  FShards[ShardIdx].Lock.Acquire;
  try
    Idx := FShards[ShardIdx].Cache.IndexOf(Key);
    if Idx >= 0 then
    begin
      Entry := FShards[ShardIdx].Cache.Data[Idx];
      if Entry.IsValid then
      begin
        AResponse := Copy(Entry.ResponseData, 0, Length(Entry.ResponseData));
        Inc(Entry.HitCount);
        FShards[ShardIdx].Cache.Data[Idx] := Entry;
        
        // 更新统计 (使用独立的统计锁)
        FStatsLock.Acquire;
        try
          Inc(FStats.TotalRequests);
          Inc(FStats.CacheHits);
          FStats.Hits := FStats.CacheHits;
        finally
          FStatsLock.Release;
        end;
        
        Result := True;
      end
      else
      begin
        FShards[ShardIdx].Cache.Delete(Idx);
        
        FStatsLock.Acquire;
        try
          Inc(FStats.TotalRequests);
          Inc(FStats.CacheMisses);
          FStats.Misses := FStats.CacheMisses;
        finally
          FStatsLock.Release;
        end;
      end;
    end
    else
    begin
      FStatsLock.Acquire;
      try
        Inc(FStats.TotalRequests);
        Inc(FStats.CacheMisses);
        FStats.Misses := FStats.CacheMisses;
      finally
        FStatsLock.Release;
      end;
    end;
  finally
    FShards[ShardIdx].Lock.Release;
  end;
end;

procedure TOCSPResponseCache.Put(const ASerialNumber: TBytes; const AResponse: TBytes;
  AThisUpdate, ANextUpdate: TDateTime);
var
  Key: string;
  ShardIdx, Idx: Integer;
  Entry: TOCSPCacheEntry;
  MaxEntriesPerShard: Integer;
begin
  if Length(AResponse) = 0 then
    Exit;
  
  Key := GenerateCacheKey(ASerialNumber);
  ShardIdx := GetShardIndex(Key);
  
  FillChar(Entry, SizeOf(Entry), 0);
  Entry.ResponseData := Copy(AResponse, 0, Length(AResponse));
  Entry.ThisUpdate := AThisUpdate;
  
  if ANextUpdate = 0 then
    Entry.NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, FDefaultTTL)
  else
    Entry.NextUpdate := ANextUpdate;
  
  Entry.CachedAt := DateTimeUtcNow;
  Entry.HitCount := 0;
  
  // 只锁定对应的分片
  FShards[ShardIdx].Lock.Acquire;
  try
    Idx := FShards[ShardIdx].Cache.IndexOf(Key);
    if Idx >= 0 then
      FShards[ShardIdx].Cache.Data[Idx] := Entry
    else
      FShards[ShardIdx].Cache.Add(Key, Entry);
    
    // 延迟清理
    Inc(FShards[ShardIdx].PutCount);
    if FShards[ShardIdx].PutCount >= FCleanupThreshold then
    begin
      CleanupExpiredInShard(ShardIdx);
      FShards[ShardIdx].PutCount := 0;
    end;
    
    // 分片级别的大小限制
    MaxEntriesPerShard := FMaxEntries div SHARD_COUNT;
    if FShards[ShardIdx].Cache.Count > MaxEntriesPerShard then
      EnforceSizeLimitInShard(ShardIdx);
  finally
    FShards[ShardIdx].Lock.Release;
  end;
end;

procedure TOCSPResponseCache.Remove(const ASerialNumber: TBytes);
var
  Key: string;
  ShardIdx, Idx: Integer;
begin
  Key := GenerateCacheKey(ASerialNumber);
  ShardIdx := GetShardIndex(Key);
  
  FShards[ShardIdx].Lock.Acquire;
  try
    Idx := FShards[ShardIdx].Cache.IndexOf(Key);
    if Idx >= 0 then
      FShards[ShardIdx].Cache.Delete(Idx);
  finally
    FShards[ShardIdx].Lock.Release;
  end;
end;

procedure TOCSPResponseCache.Clear;
var
  I: Integer;
begin
  for I := 0 to SHARD_COUNT - 1 do
  begin
    FShards[I].Lock.Acquire;
    try
      FShards[I].Cache.Clear;
      FShards[I].PutCount := 0;
    finally
      FShards[I].Lock.Release;
    end;
  end;
  
  FStatsLock.Acquire;
  try
    FStats.TotalEntries := 0;
  finally
    FStatsLock.Release;
  end;
end;

function TOCSPResponseCache.Contains(const ASerialNumber: TBytes): Boolean;
var
  Key: string;
  ShardIdx: Integer;
begin
  Key := GenerateCacheKey(ASerialNumber);
  ShardIdx := GetShardIndex(Key);
  
  FShards[ShardIdx].Lock.Acquire;
  try
    Result := FShards[ShardIdx].Cache.IndexOf(Key) >= 0;
  finally
    FShards[ShardIdx].Lock.Release;
  end;
end;

function TOCSPResponseCache.GetCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to SHARD_COUNT - 1 do
  begin
    FShards[I].Lock.Acquire;
    try
      Result := Result + FShards[I].Cache.Count;
    finally
      FShards[I].Lock.Release;
    end;
  end;
end;

procedure TOCSPResponseCache.CleanupExpiredInShard(AShardIndex: Integer);
var
  I: Integer;
  Entry: TOCSPCacheEntry;
  ExpiredCount: Integer;
begin
  // 注意: 调用者必须持有分片锁
  
  ExpiredCount := 0;
  I := FShards[AShardIndex].Cache.Count - 1;
  while I >= 0 do
  begin
    Entry := FShards[AShardIndex].Cache.Data[I];
    if Entry.IsExpired then
    begin
      FShards[AShardIndex].Cache.Delete(I);
      Inc(ExpiredCount);
    end;
    Dec(I);
  end;
  
  if ExpiredCount > 0 then
  begin
    FStatsLock.Acquire;
    try
      FStats.ExpiredEntries := FStats.ExpiredEntries + ExpiredCount;
    finally
      FStatsLock.Release;
    end;
  end;
end;

procedure TOCSPResponseCache.EnforceSizeLimitInShard(AShardIndex: Integer);
var
  I, OldestIdx: Integer;
  OldestTime: TDateTime;
  Entry: TOCSPCacheEntry;
  MaxEntriesPerShard: Integer;
begin
  // 注意: 调用者必须持有分片锁
  
  MaxEntriesPerShard := FMaxEntries div SHARD_COUNT;
  
  while FShards[AShardIndex].Cache.Count > MaxEntriesPerShard do
  begin
    OldestIdx := 0;
    OldestTime := FShards[AShardIndex].Cache.Data[0].CachedAt;
    
    for I := 1 to FShards[AShardIndex].Cache.Count - 1 do
    begin
      Entry := FShards[AShardIndex].Cache.Data[I];
      if Entry.CachedAt < OldestTime then
      begin
        OldestTime := Entry.CachedAt;
        OldestIdx := I;
      end;
    end;
    
    FShards[AShardIndex].Cache.Delete(OldestIdx);
  end;
end;

function TOCSPResponseCache.GetStats: TOCSPCacheStats;
begin
  FStatsLock.Acquire;
  try
    Result := FStats;
    Result.TotalEntries := GetCount;
    Result.Hits := FStats.CacheHits;
    Result.Misses := FStats.CacheMisses;
  finally
    FStatsLock.Release;
  end;
end;

procedure TOCSPResponseCache.ResetStats;
begin
  FStatsLock.Acquire;
  try
    FStats.TotalRequests := 0;
    FStats.CacheHits := 0;
    FStats.CacheMisses := 0;
    FStats.Hits := 0;
    FStats.Misses := 0;
    FStats.ExpiredEntries := 0;
    FStats.TotalEntries := GetCount;
  finally
    FStatsLock.Release;
  end;
end;

function TOCSPResponseCache.SaveToFile(const AFileName: string): Boolean;
var
  Stream: IFile;
  WriterTarget: IWriter;
  Writer: TBinaryWriter;
  I, J, Count, DataLen: Integer;
  Key: string;
  Entry: TOCSPCacheEntry;
begin
  Result := False;
  
  try
    Stream := FsCreate(AFileName);
    if not Supports(Stream, IWriter, WriterTarget) then
      Exit(False);
    Writer.Init(WriterTarget);

    I := 2;
    Writer.WriteInt32LE(I);

    I := SHARD_COUNT;
    Writer.WriteInt32LE(I);

    for I := 0 to SHARD_COUNT - 1 do
    begin
      FShards[I].Lock.Acquire;
      try
        Count := FShards[I].Cache.Count;
        Writer.WriteInt32LE(Count);

        for J := 0 to FShards[I].Cache.Count - 1 do
        begin
          Key := FShards[I].Cache.Keys[J];
          Entry := FShards[I].Cache.Data[J];

          DataLen := Length(Key);
          Writer.WriteInt32LE(DataLen);
          if DataLen > 0 then
            Writer.WriteString(Key);

          DataLen := Length(Entry.ResponseData);
          Writer.WriteInt32LE(DataLen);
          if DataLen > 0 then
            Writer.WriteBytes(Entry.ResponseData);

          Writer.WriteFloat64LE(Entry.ThisUpdate);
          Writer.WriteFloat64LE(Entry.NextUpdate);
          Writer.WriteFloat64LE(Entry.CachedAt);
          Writer.WriteInt32LE(Entry.HitCount);
        end;
      finally
        FShards[I].Lock.Release;
      end;
    end;

    Result := True;
  except
    Result := False;
  end;
end;

function TOCSPResponseCache.LoadFromFile(const AFileName: string): Boolean;
var
  Stream: IStream;
  ReaderSource: IReader;
  Reader: TBinaryReader;
  Version, ShardCount, Count, I, J, DataLen, ShardIdx: Integer;
  Key: string;
  Entry: TOCSPCacheEntry;
begin
  Result := False;
  
  if not nextpas.core.fs.IsFile(AFileName) then
    Exit;
  
  try
    Clear;
    
    Stream := FsOpen(AFileName, [fmRead]);
    if not Supports(Stream, IReader, ReaderSource) then
      Exit(False);
    Reader.Init(ReaderSource);

    Version := Reader.ReadInt32LE;
    if (Version <> 1) and (Version <> 2) then
      Exit;

    if Version = 2 then
    begin
      ShardCount := Reader.ReadInt32LE;

      for I := 0 to ShardCount - 1 do
      begin
        Count := Reader.ReadInt32LE;

        if I < SHARD_COUNT then
        begin
          FShards[I].Lock.Acquire;
          try
            for J := 0 to Count - 1 do
            begin
              DataLen := Reader.ReadInt32LE;
              if DataLen > 0 then
                Key := Reader.ReadString(DataLen)
              else
                Key := '';

              FillChar(Entry, SizeOf(Entry), 0);
              DataLen := Reader.ReadInt32LE;
              if DataLen > 0 then
                Entry.ResponseData := Reader.ReadBytes(DataLen)
              else
                Entry.ResponseData := nil;

              Entry.ThisUpdate := Reader.ReadFloat64LE;
              Entry.NextUpdate := Reader.ReadFloat64LE;
              Entry.CachedAt := Reader.ReadFloat64LE;
              Entry.HitCount := Reader.ReadInt32LE;

              if Entry.IsValid then
                FShards[I].Cache.Add(Key, Entry);
            end;
          finally
            FShards[I].Lock.Release;
          end;
        end
        else
        begin
          for J := 0 to Count - 1 do
          begin
            DataLen := Reader.ReadInt32LE;
            if DataLen > 0 then
              Reader.ReadString(DataLen);
            DataLen := Reader.ReadInt32LE;
            if DataLen > 0 then
              Reader.ReadBytes(DataLen);
            Reader.ReadFloat64LE;
            Reader.ReadFloat64LE;
            Reader.ReadFloat64LE;
            Reader.ReadInt32LE;
          end;
        end;
      end;
    end
    else
    begin
      Count := Reader.ReadInt32LE;

      for I := 0 to Count - 1 do
      begin
        DataLen := Reader.ReadInt32LE;
        if DataLen > 0 then
          Key := Reader.ReadString(DataLen)
        else
          Key := '';

        FillChar(Entry, SizeOf(Entry), 0);
        DataLen := Reader.ReadInt32LE;
        if DataLen > 0 then
          Entry.ResponseData := Reader.ReadBytes(DataLen)
        else
          Entry.ResponseData := nil;

        Entry.ThisUpdate := Reader.ReadFloat64LE;
        Entry.NextUpdate := Reader.ReadFloat64LE;
        Entry.CachedAt := Reader.ReadFloat64LE;
        Entry.HitCount := Reader.ReadInt32LE;

        if Entry.IsValid then
        begin
          ShardIdx := GetShardIndex(Key);
          FShards[ShardIdx].Lock.Acquire;
          try
            FShards[ShardIdx].Cache.Add(Key, Entry);
          finally
            FShards[ShardIdx].Lock.Release;
          end;
        end;
      end;
    end;

    FStatsLock.Acquire;
    try
      FStats.TotalEntries := GetCount;
    finally
      FStatsLock.Release;
    end;

    Result := True;
  except
    Result := False;
  end;
end;

end.
