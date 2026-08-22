unit nextpas.core.os.procinfo;

{**
 * nextpas.core.os.procinfo — 当前进程自身信息（OS 级诊断查询）
 *
 * Linux：读 /proc/self/status 带标签字段（VmRSS / VmHWM，内核 ABI 稳定，
 * 每次查询一次文件读）。其他平台返回 cProcessMemUnknown（Windows
 * GetProcessMemoryInfo / macOS mach_task_basic_info 为规划后端位）。
 *
 * 典型用途：内存验收 harness（如 proxy888 S2-DEN 密度门禁）、基准测试
 * RSS 采样、运行时内存水位观测。
 *
 * @note Thread safety: 只读 OS 查询，任意线程可调。
 *}

{$I nextpas.core.settings.inc}

interface

const
  { 平台无后端 / 字段缺失 / 读取失败时的哨兵值（调用方降级跳过预算
    断言，而非把诊断查询变成故障点） }
  cProcessMemUnknown = Int64(-1);

{** @desc 当前进程常驻集大小（字节）；不可用返回 cProcessMemUnknown，不抛异常 *}
function ProcessRssBytes: Int64;

{** @desc 当前进程常驻集峰值（字节，Linux VmHWM）；不可用返回 cProcessMemUnknown，不抛异常 *}
function ProcessPeakRssBytes: Int64;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.fs;

{ 从 /proc/self/status 文本中解析 "AKey:\t <n> kB" 形态的带标签字段，
  kB -> 字节。键缺失/值畸形返回 cProcessMemUnknown（防御性：内核 ABI
  稳定，但诊断查询永不 raise）。 }
function StatusKbFieldToBytes(const AStatusText, AKey: string): Int64;
var
  LI, LLineBeg, LValBeg, LValEnd, LVal: Integer;
  LPrefix: string;
begin
  Result := cProcessMemUnknown;
  LPrefix := AKey + ':';
  LLineBeg := -1;
  LI := 1;
  while LI <= Length(AStatusText) do
  begin
    if AStatusText[LI] = #10 then
    begin
      LLineBeg := -1;   { 下一字符是新行首 }
      Inc(LI);
      Continue;
    end;
    if (LLineBeg < 0) and (Copy(AStatusText, LI, Length(LPrefix)) = LPrefix) then
    begin
      { 行首命中键前缀：冒号后取十进制整数 }
      LValBeg := LI + Length(LPrefix);
      while (LValBeg <= Length(AStatusText)) and
            ((AStatusText[LValBeg] = ' ') or (AStatusText[LValBeg] = #9)) do
        Inc(LValBeg);
      LValEnd := LValBeg;
      while (LValEnd <= Length(AStatusText)) and
            (AStatusText[LValEnd] >= '0') and (AStatusText[LValEnd] <= '9') do
        Inc(LValEnd);
      if LValEnd > LValBeg then
      begin
        LVal := StrToInt(Copy(AStatusText, LValBeg, LValEnd - LValBeg));
        Exit(LVal * 1024);   { status 数值单位恒 kB }
      end;
      Exit(cProcessMemUnknown);   { 键在值畸形：不继续扫 }
    end;
    if LLineBeg < 0 then
      LLineBeg := LI;
    Inc(LI);
  end;
end;

function ProcessRssBytes: Int64;
{$IFDEF LINUX}
var
  LText: string;
begin
  try
    LText := ReadFileText('/proc/self/status');
  except
    on E: ENextPasError do
      Exit(cProcessMemUnknown);
  end;
  Result := StatusKbFieldToBytes(LText, 'VmRSS');
end;
{$ELSE}
begin
  Result := cProcessMemUnknown;   { 平台后端待落地（见单元头注释） }
end;
{$ENDIF}

function ProcessPeakRssBytes: Int64;
{$IFDEF LINUX}
var
  LText: string;
begin
  try
    LText := ReadFileText('/proc/self/status');
  except
    on E: ENextPasError do
      Exit(cProcessMemUnknown);
  end;
  Result := StatusKbFieldToBytes(LText, 'VmHWM');
end;
{$ELSE}
begin
  Result := cProcessMemUnknown;   { 平台后端待落地（见单元头注释） }
end;
{$ENDIF}

end.
