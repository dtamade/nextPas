unit nextpas.core.platform;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.base,
  nextpas.core.platform.info,
  nextpas.core.platform.time;

type
  TOSKind = nextpas.core.platform.base.TOSKind;
  TCPUArch = nextpas.core.platform.base.TCPUArch;
  TEndianness = nextpas.core.platform.base.TEndianness;

{** @desc 获取当前操作系统类型
    @return TOSKind 枚举值 *}
function CurrentOS: TOSKind;

{** @desc 获取当前 CPU 架构
    @return TCPUArch 枚举值 *}
function CurrentCPU: TCPUArch;

{** @desc 获取当前字节序
    @return TEndianness 枚举值 *}
function CurrentEndian: TEndianness;

{** @desc 获取操作系统名称字符串
    @return 操作系统名称 *}
function OSName: string;

{** @desc 获取 CPU 架构名称字符串
    @return CPU 架构名称 *}
function CPUName: string;

{ Time }

{** @desc 获取单调时钟时间（纳秒）
    @return 纳秒时间戳 *}
function platform_monotonic_ns: UInt64;

{** @desc 获取实时时钟时间（纳秒）
    @return 纳秒时间戳 *}
function platform_realtime_ns: UInt64;

{** @desc 获取单调时钟分辨率（纳秒）
    @return 分辨率纳秒数 *}
function platform_monotonic_resolution_ns: UInt64;

implementation

function CurrentOS: TOSKind;
begin
  Result := nextpas.core.platform.info.CurrentOS;
end;

function CurrentCPU: TCPUArch;
begin
  Result := nextpas.core.platform.info.CurrentCPU;
end;

function CurrentEndian: TEndianness;
begin
  Result := nextpas.core.platform.info.CurrentEndian;
end;

function OSName: string;
begin
  Result := nextpas.core.platform.info.OSName;
end;

function CPUName: string;
begin
  Result := nextpas.core.platform.info.CPUName;
end;

function platform_monotonic_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_monotonic_ns;
end;

function platform_realtime_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_realtime_ns;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_monotonic_resolution_ns;
end;

end.
