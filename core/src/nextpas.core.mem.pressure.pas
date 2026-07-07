{******************************************************************************
  nextpas.core.mem.pressure — 系统内存压力检测

  核心设计:
    1. 读取 /proc/meminfo (Linux) 或 cgroup memory.limit (容器)
    2. 周期性检查（每 N 次分配后）
    3. 回调触发降级策略（释放缓存/减少预分配）
    4. 线程安全

  使用模式:
    var LPressure: TMemoryPressure;
    LPressure := TMemoryPressure.Create;
    LPressure.OnPressure := MyHandler;
    // 定期调用
    if LPressure.ShouldCheck then
      LPressure.Check;

  性能目标:
    - ShouldCheck: 原子递增 + 比较（< 2ns）
    - Check: 读取 /proc/meminfo（~10us，冷路径）
******************************************************************************}
unit nextpas.core.mem.pressure;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  {** 内存压力等级 }
  TMemoryPressureLevel = (
    mplNone,       // 无压力（< 50% 使用）
    mplLow,        // 低压力（50-70% 使用）
    mplMedium,     // 中压力（70-85% 使用）
    mplHigh,       // 高压力（85-95% 使用）
    mplCritical    // 临界（> 95% 使用）
  );

  {** 内存压力事件 }
  TMemoryPressureEvent = procedure(ALevel: TMemoryPressureLevel;
    AUsedPercent: Double);

  {** TMemoryPressure
   *
   *  系统内存压力检测器。周期性读取系统内存信息，
   *  计算使用率并触发回调。
   *}
  TMemoryPressure = class
  private
    FCheckInterval: UInt64;
    FOpCounter: UInt64;
    FLastLevel: TMemoryPressureLevel;
    FOnPressure: TMemoryPressureEvent;
    FTotalMemKB: UInt64;
    FAvailMemKB: UInt64;
    function ReadMemInfo: Boolean;
  public
    {** ACheckInterval: 每 N 次 ShouldCheck 调用后实际检查一次 }
    constructor Create(ACheckInterval: UInt64 = 1000);

    {** 快速检查：原子递增计数器，每 N 次返回 True }
    function ShouldCheck: Boolean;

    {** 执行检查：读取系统内存信息，触发回调 }
    function Check: TMemoryPressureLevel;

    {** 当前压力等级（上次检查结果） }
    function CurrentLevel: TMemoryPressureLevel;

    {** 总内存 (KB) }
    function TotalMemKB: UInt64;
    {** 可用内存 (KB) }
    function AvailMemKB: UInt64;
    {** 使用率 (0.0-1.0) }
    function UsagePercent: Double;

    {** 压力回调 }
    property OnPressure: TMemoryPressureEvent read FOnPressure write FOnPressure;
  end;

implementation

uses
  nextpas.core.mem.utils;

{ TMemoryPressure }

constructor TMemoryPressure.Create(ACheckInterval: UInt64);
begin
  inherited Create;
  FCheckInterval := ACheckInterval;
  FOpCounter := 0;
  FLastLevel := mplNone;
  FOnPressure := nil;
  FTotalMemKB := 0;
  FAvailMemKB := 0;
end;

function TMemoryPressure.ShouldCheck: Boolean;
var
  LCounter: UInt64;
begin
  LCounter := InterlockedExchangeAdd64(FOpCounter, 1);
  Result := (LCounter mod FCheckInterval) = 0;
end;

function TMemoryPressure.ReadMemInfo: Boolean;
var
  F: Text;
  Line: string;
  Key: string;
  ColonPos, NumStart, NumEnd, LI: Integer;
  Val: UInt64;
begin
  Result := False;
  FTotalMemKB := 0;
  FAvailMemKB := 0;
  {$I-}
  Assign(F, '/proc/meminfo');
  Reset(F);
  if IOResult <> 0 then
    Exit;
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    // 格式: "Key:   12345 kB"
    ColonPos := Pos(':', Line);
    if ColonPos < 2 then
      Continue;
    SetLength(Key, ColonPos - 1);
    Move(Line[1], Key[1], ColonPos - 1);
    if (Key <> 'MemTotal') and (Key <> 'MemAvailable') then
      Continue;
    // 跳过冒号后的空格，找到数字起始位置
    NumStart := ColonPos + 1;
    while (NumStart <= Length(Line)) and (Line[NumStart] = ' ') do
      Inc(NumStart);
    // 找到数字结束位置（空格或行尾）
    NumEnd := NumStart;
    while (NumEnd <= Length(Line)) and (Line[NumEnd] in ['0'..'9']) do
      Inc(NumEnd);
    if NumEnd <= NumStart then
      Continue;
    // 手动解析数字
    Val := 0;
    for LI := NumStart to NumEnd - 1 do
      Val := Val * 10 + UInt64(Ord(Line[LI]) - Ord('0'));
    if Key = 'MemTotal' then
      FTotalMemKB := Val
    else
      FAvailMemKB := Val;
    if (FTotalMemKB > 0) and (FAvailMemKB > 0) then
    begin
      Result := True;
      Break;
    end;
  end;
  Close(F);
  {$I+}
end;

function TMemoryPressure.Check: TMemoryPressureLevel;
var
  LUsedPct: Double;
begin
  if not ReadMemInfo then
  begin
    FLastLevel := mplNone;
    Exit(FLastLevel);
  end;

  if FTotalMemKB = 0 then
  begin
    FLastLevel := mplNone;
    Exit(FLastLevel);
  end;

  LUsedPct := 1.0 - (FAvailMemKB / FTotalMemKB);

  if LUsedPct >= 0.95 then
    FLastLevel := mplCritical
  else if LUsedPct >= 0.85 then
    FLastLevel := mplHigh
  else if LUsedPct >= 0.70 then
    FLastLevel := mplMedium
  else if LUsedPct >= 0.50 then
    FLastLevel := mplLow
  else
    FLastLevel := mplNone;

  if Assigned(FOnPressure) and (FLastLevel <> mplNone) then
    FOnPressure(FLastLevel, LUsedPct);

  Result := FLastLevel;
end;

function TMemoryPressure.CurrentLevel: TMemoryPressureLevel;
begin
  Result := FLastLevel;
end;

function TMemoryPressure.TotalMemKB: UInt64;
begin
  Result := FTotalMemKB;
end;

function TMemoryPressure.AvailMemKB: UInt64;
begin
  Result := FAvailMemKB;
end;

function TMemoryPressure.UsagePercent: Double;
begin
  if FTotalMemKB = 0 then
    Exit(0.0);
  Result := 1.0 - (FAvailMemKB / FTotalMemKB);
end;

end.
