program test_platform_facade_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  PLATFORM_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.pas';
  PLATFORM_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.pas';
  PLATFORM_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.base.pas';
  PLATFORM_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.base.pas';
  PLATFORM_INFO_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.info.pas';
  PLATFORM_INFO_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.info.pas';
  PLATFORM_INFO_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.info.base.pas';
  PLATFORM_INFO_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.info.base.pas';
  PLATFORM_INFO_INTF_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.info.intf.pas';
  PLATFORM_INFO_INTF_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.info.intf.pas';
  PLATFORM_INFO_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.info.ffi.pas';
  PLATFORM_INFO_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.info.ffi.pas';

var
  T: TTestRunner;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function SourceExists(const APathFromTest, APathFromRoot: string): Boolean;
begin
  Result := FileExists(APathFromTest) or FileExists(APathFromRoot);
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckNoFpcPlatformTokens(const ASource, ALabel: string);
begin
  CheckTokenAbsent(ASource, 'BaseUnix', ALabel + ' must not reference FPC platform unit');
  CheckTokenAbsent(ASource, 'UnixType', ALabel + ' must not reference FPC platform unit');
  CheckTokenAbsent(ASource, 'PThreads', ALabel + ' must not reference FPC platform unit');
  CheckTokenAbsent(ASource, 'Syscall', ALabel + ' must not reference FPC platform unit');
  CheckTokenAbsent(ASource, '  Linux;', ALabel + ' must not reference FPC Linux unit');
  CheckTokenAbsent(ASource, '  Linux,', ALabel + ' must not reference FPC Linux unit');
  CheckTokenAbsent(ASource, '  Windows;', ALabel + ' must not reference FPC Windows unit');
  CheckTokenAbsent(ASource, '  Windows,', ALabel + ' must not reference FPC Windows unit');
end;

procedure TestPlatformInfoOwnsInfoLogic;
var
  LInfoPath: string;
  LInfoSource: string;
begin
  LInfoPath := ResolveSourcePath(PLATFORM_INFO_SOURCE_PATH_FROM_TEST, PLATFORM_INFO_SOURCE_PATH_FROM_ROOT);
  Check(FileExists(LInfoPath), 'platform.info source must exist: ' + LInfoPath);

  LInfoSource := ReadSourceFile(LInfoPath);
  CheckTokenPresent(LInfoSource, 'unit nextpas.core.platform.info;',
    'platform.info must be the top-level info implementation unit');
  CheckTokenPresent(LInfoSource, 'nextpas.core.platform.base',
    'platform.info must depend on platform.base for public enum/constant truth');
  CheckTokenPresent(LInfoSource, 'function currentos: toskind;',
    'platform.info must own CurrentOS implementation');
  CheckTokenPresent(LInfoSource, 'result := current_os;',
    'platform.info CurrentOS must read platform.base CURRENT_OS');
  CheckTokenPresent(LInfoSource, 'function currentcpu: tcpuarch;',
    'platform.info must own CurrentCPU implementation');
  CheckTokenPresent(LInfoSource, 'result := current_cpu;',
    'platform.info CurrentCPU must read platform.base CURRENT_CPU');
  CheckTokenPresent(LInfoSource, 'function currentendian: tendianness;',
    'platform.info must own CurrentEndian implementation');
  CheckTokenPresent(LInfoSource, 'result := current_endian;',
    'platform.info CurrentEndian must read platform.base CURRENT_ENDIAN');
  CheckTokenPresent(LInfoSource, 'function osname: string;',
    'platform.info must own OSName implementation');
  CheckTokenPresent(LInfoSource, 'case currentos of',
    'platform.info must own OS name mapping');
  CheckTokenPresent(LInfoSource, 'function cpuname: string;',
    'platform.info must own CPUName implementation');
  CheckTokenPresent(LInfoSource, 'case currentcpu of',
    'platform.info must own CPU name mapping');
  CheckNoFpcPlatformTokens(LInfoSource, 'platform.info');
  CheckTokenAbsent(LInfoSource, 'external ''',
    'platform.info is not an ffi owner');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.time',
    'platform.info must not depend on platform.time');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.thread',
    'platform.info must not depend on platform.thread');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.sync',
    'platform.info must not depend on platform.sync');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.posix.ffi',
    'platform.info must not bind shared POSIX ffi');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.linux.ffi',
    'platform.info must not bind Linux ffi');
  CheckTokenAbsent(LInfoSource, 'nextpas.core.platform.windows.ffi',
    'platform.info must not bind Windows ffi');

  Check(not SourceExists(PLATFORM_INFO_BASE_SOURCE_PATH_FROM_TEST, PLATFORM_INFO_BASE_SOURCE_PATH_FROM_ROOT),
    'platform.info must not create a duplicate base unit');
  Check(not SourceExists(PLATFORM_INFO_INTF_SOURCE_PATH_FROM_TEST, PLATFORM_INFO_INTF_SOURCE_PATH_FROM_ROOT),
    'platform.info must not create an intf unit without a Pascal interface contract');
  Check(not SourceExists(PLATFORM_INFO_FFI_SOURCE_PATH_FROM_TEST, PLATFORM_INFO_FFI_SOURCE_PATH_FROM_ROOT),
    'platform.info must not create an ffi unit because it owns no foreign ABI');
end;

procedure TestPlatformFacadeIsThin;
var
  LPlatformSource: string;
begin
  LPlatformSource := ReadSourceFile(ResolveSourcePath(PLATFORM_SOURCE_PATH_FROM_TEST, PLATFORM_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPlatformSource, 'nextpas.core.platform.base',
    'platform facade must re-export platform.base');
  CheckTokenPresent(LPlatformSource, 'nextpas.core.platform.info',
    'platform facade must re-export platform.info');
  CheckTokenPresent(LPlatformSource, 'nextpas.core.platform.time',
    'platform facade must continue re-exporting platform.time');
  CheckTokenPresent(LPlatformSource, 'toskind = nextpas.core.platform.base.toskind',
    'platform facade must re-export TOSKind');
  CheckTokenPresent(LPlatformSource, 'tcpuarch = nextpas.core.platform.base.tcpuarch',
    'platform facade must re-export TCPUArch');
  CheckTokenPresent(LPlatformSource, 'tendianness = nextpas.core.platform.base.tendianness',
    'platform facade must re-export TEndianness');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.info.currentos;',
    'platform facade CurrentOS must forward to platform.info');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.info.currentcpu;',
    'platform facade CurrentCPU must forward to platform.info');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.info.currentendian;',
    'platform facade CurrentEndian must forward to platform.info');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.info.osname;',
    'platform facade OSName must forward to platform.info');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.info.cpuname;',
    'platform facade CPUName must forward to platform.info');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.time.platform_monotonic_ns;',
    'platform facade must continue forwarding monotonic time API to platform.time');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.time.platform_realtime_ns;',
    'platform facade must continue forwarding realtime time API to platform.time');
  CheckTokenPresent(LPlatformSource, 'result := nextpas.core.platform.time.platform_monotonic_resolution_ns;',
    'platform facade must continue forwarding resolution time API to platform.time');
  CheckTokenAbsent(LPlatformSource, 'case currentos of',
    'platform facade must not keep OS name mapping logic');
  CheckTokenAbsent(LPlatformSource, 'case currentcpu of',
    'platform facade must not keep CPU name mapping logic');
  CheckTokenAbsent(LPlatformSource, 'result := current_os;',
    'platform facade must not read CURRENT_OS directly');
  CheckTokenAbsent(LPlatformSource, 'result := current_cpu;',
    'platform facade must not read CURRENT_CPU directly');
  CheckTokenAbsent(LPlatformSource, 'result := current_endian;',
    'platform facade must not read CURRENT_ENDIAN directly');
  CheckNoFpcPlatformTokens(LPlatformSource, 'platform facade');
  CheckTokenAbsent(LPlatformSource, 'external ''',
    'platform facade must not declare external ABI directly');
end;

procedure TestPlatformBaseStaysPure;
var
  LBaseSource: string;
begin
  LBaseSource := ReadSourceFile(ResolveSourcePath(PLATFORM_BASE_SOURCE_PATH_FROM_TEST, PLATFORM_BASE_SOURCE_PATH_FROM_ROOT));
  CheckTokenPresent(LBaseSource, 'toskind =',
    'platform.base must own OS enum');
  CheckTokenPresent(LBaseSource, 'tcpuarch =',
    'platform.base must own CPU enum');
  CheckTokenPresent(LBaseSource, 'tendianness =',
    'platform.base must own endian enum');
  CheckTokenPresent(LBaseSource, 'current_os:',
    'platform.base must own CURRENT_OS');
  CheckTokenPresent(LBaseSource, 'current_cpu:',
    'platform.base must own CURRENT_CPU');
  CheckTokenPresent(LBaseSource, 'current_endian:',
    'platform.base must own CURRENT_ENDIAN');
  CheckTokenAbsent(LBaseSource, 'function currentos',
    'platform.base must not implement CurrentOS');
  CheckTokenAbsent(LBaseSource, 'function osname',
    'platform.base must not implement OSName');
  CheckNoFpcPlatformTokens(LBaseSource, 'platform.base');
  CheckTokenAbsent(LBaseSource, 'external ''',
    'platform.base must not declare external ABI directly');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.facade_surface');
  T.Run('platform.info owns info logic', @TestPlatformInfoOwnsInfoLogic);
  T.Run('platform facade is thin', @TestPlatformFacadeIsThin);
  T.Run('platform.base stays pure', @TestPlatformBaseStaysPure);
  T.Summary;
end.
