unit nextpas.core.platform.info;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.base;

{** @desc 获取当前操作系统类型
    @return TOSKind 枚举值 *}
function CurrentOS: TOSKind; inline;

{** @desc 获取当前 CPU 架构
    @return TCPUArch 枚举值 *}
function CurrentCPU: TCPUArch; inline;

{** @desc 获取当前字节序
    @return TEndianness 枚举值 *}
function CurrentEndian: TEndianness; inline;

{** @desc 获取操作系统名称字符串
    @return 如 'Linux', 'macOS', 'Windows' *}
function OSName: string; inline;

{** @desc 获取 CPU 架构名称字符串
    @return 如 'x86_64', 'aarch64' *}
function CPUName: string; inline;

implementation

function CurrentOS: TOSKind;
begin
  Result := CURRENT_OS;
end;

function CurrentCPU: TCPUArch;
begin
  Result := CURRENT_CPU;
end;

function CurrentEndian: TEndianness;
begin
  Result := CURRENT_ENDIAN;
end;

function OSName: string;
begin
  case CurrentOS of
    osLinux: Result := 'Linux';
    osMacOS: Result := 'macOS';
    osWindows: Result := 'Windows';
    osAndroid: Result := 'Android';
    osFreeBSD: Result := 'FreeBSD';
    osUnix: Result := 'Unix';
  else
    Result := 'Unknown';
  end;
end;

function CPUName: string;
begin
  case CurrentCPU of
    cpuX86_64: Result := 'x86_64';
    cpuAArch64: Result := 'aarch64';
    cpuARM32: Result := 'arm';
    cpuRISCV64: Result := 'riscv64';
  else
    Result := 'Unknown';
  end;
end;

end.
