unit nextpas.core.lockfree.counter.keyed;

{** @desc 按 key 隔离的有界活跃计数表（Keyed Active Counter）
  @details 每个 string key（如客户端地址/会话标识/租户）持有独立 Int64 计数，
    典型消费：per-address 并发连接数、keep-alive 会话数、租户配额占用。
    key 惰性创建，表有界（满时驱逐计数为 0 的 key——活跃 key 不受影响，
    防 key 风暴；全活跃时返回 -1，调用侧放行优先于误伤，同
    TKeyedTokenBucketLimiter 的 FindOrCreate 约定）。
    Decrement 下限 0：防御关闭通知重复/乱序（不进入负数）。
  @concurrency Thread-safe：互斥锁保护表 + 桶内算术（μs 级临界区，
    与 TKeyedTokenBucketLimiter 同构）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync;

type
  {** @desc 按 key 隔离的有界活跃计数表（线程安全）。 }
  TKeyedCounter = class
  private
    FMaxKeys: Integer;
    FLock: INativeMutex;
    FKeys: array of string;
    FValues: array of Int64;
    { 线性查找；miss 时新建（满则驱逐任一计数为 0 的 key，活跃 key 常驻；
      全活跃返回 -1，调用侧放行优先于误伤）。 }
    function FindOrCreate(const AKey: string): Integer;
  public
    { AMaxKeys：表容量上限（防 key 风暴；计数为 0 的 key 可被驱逐重建）。 }
    constructor Create(const AMaxKeys: Integer = 4096);
    destructor Destroy; override;
    { 计数 +1 并返回新值；表满且全活跃（理论难达）返回 -1（调用侧放行）。 }
    function Increment(const AKey: string): Int64;
    { 计数 -1（下限 0）并返回新值；key 不存在返回 0（防御重复关闭）。 }
    function Decrement(const AKey: string): Int64;
    { 当前计数；key 不存在返回 0（观测/测试）。 }
    function Load(const AKey: string): Int64;
    { 清空全部 key（测试/热重载）。 }
    procedure Reset;
    { 当前 key 数（观测/测试）。 }
    function KeyCount: Integer; inline;
  end;

implementation

uses
  nextpas.core.errors;

constructor TKeyedCounter.Create(const AMaxKeys: Integer);
begin
  inherited Create;
  if AMaxKeys < 1 then
    raise EArgumentError.Create('keyed counter: max keys must be >= 1');
  FMaxKeys := AMaxKeys;
  FLock := Mutex;
end;

destructor TKeyedCounter.Destroy;
begin
  FKeys := nil;
  FValues := nil;
  FLock := nil;
  inherited Destroy;
end;

function TKeyedCounter.FindOrCreate(const AKey: string): Integer;
var
  LI, LEvict: Integer;
begin
  Result := -1;
  LEvict := -1;
  for LI := 0 to High(FKeys) do
  begin
    if FKeys[LI] = AKey then
      Exit(LI);
    { 驱逐候选：计数为 0 的 key（无活跃连接，最该淘汰） }
    if (FValues[LI] = 0) and (LEvict < 0) then
      LEvict := LI;
  end;
  if Length(FKeys) >= FMaxKeys then
  begin
    if LEvict < 0 then
      Exit;      { 全活跃：调用侧放行优先于误伤 }
    Result := LEvict;
  end
  else
  begin
    SetLength(FKeys, Length(FKeys) + 1);
    SetLength(FValues, Length(FValues) + 1);
    Result := High(FKeys);
  end;
  FKeys[Result] := AKey;
  FValues[Result] := 0;
end;

function TKeyedCounter.Increment(const AKey: string): Int64;
var
  LIdx: Integer;
begin
  Result := -1;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    LIdx := FindOrCreate(AKey);
    if LIdx < 0 then
      Exit;
    FValues[LIdx] := FValues[LIdx] + 1;
    Result := FValues[LIdx];
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.Decrement(const AKey: string): Int64;
var
  LI: Integer;
begin
  Result := 0;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    { 只读查找：key 不存在（无对应 Increment，防御重复关闭）返回 0 不创建 }
    for LI := 0 to High(FKeys) do
      if FKeys[LI] = AKey then
      begin
        if FValues[LI] > 0 then
          FValues[LI] := FValues[LI] - 1;
        Exit(FValues[LI]);
      end;
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.Load(const AKey: string): Int64;
var
  LI: Integer;
begin
  Result := 0;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    { 只读不创建：观测不得膨胀表（0 计数 key 由驱逐/Reset 回收） }
    for LI := 0 to High(FKeys) do
      if FKeys[LI] = AKey then
        Exit(FValues[LI]);
  finally
    FLock.Release;
  end;
end;

procedure TKeyedCounter.Reset;
begin
  FLock.Acquire;
  try
    FKeys := nil;
    FValues := nil;
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.KeyCount: Integer;
begin
  FLock.Acquire;
  try
    Result := Length(FKeys);
  finally
    FLock.Release;
  end;
end;

end.
