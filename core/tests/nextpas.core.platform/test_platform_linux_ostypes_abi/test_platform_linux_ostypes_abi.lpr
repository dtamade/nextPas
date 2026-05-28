program test_platform_linux_ostypes_abi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestPollfdSize;
begin
  CheckEqual(8, SizeOf(pollfd), 'SizeOf(pollfd) = 8');
end;

procedure TestIovecSize;
begin
  CheckEqual(16, SizeOf(iovec), 'SizeOf(iovec) = 16');
end;

procedure TestTRLimitSize;
begin
  CheckEqual(16, SizeOf(TRLimit), 'SizeOf(TRLimit) = 16');
end;

procedure TestTmsSize;
begin
  CheckEqual(32, SizeOf(tms), 'SizeOf(tms) = 32');
end;

procedure TestTimezoneSize;
begin
  CheckEqual(8, SizeOf(timezone), 'SizeOf(timezone) = 8');
end;

procedure TestCpuSetSize;
begin
  CheckEqual(128, SizeOf(cpu_set_t), 'SizeOf(cpu_set_t) = 128');
end;

procedure TestUtsNameSize;
begin
  CheckEqual(390, SizeOf(UtsName), 'SizeOf(UtsName) = 390');
end;

procedure TestStatfsSize;
begin
  CheckEqual(120, SizeOf(TStatfs), 'SizeOf(TStatfs) = 120');
end;

procedure TestFDSetSize;
begin
  CheckEqual(128, SizeOf(TFDSet), 'SizeOf(TFDSet) = 128');
end;

procedure TestPollConstants;
begin
  CheckEqual($0001, POLLIN, 'POLLIN');
  CheckEqual($0004, POLLOUT, 'POLLOUT');
  CheckEqual($0010, POLLHUP, 'POLLHUP');
  CheckEqual($0020, POLLNVAL, 'POLLNVAL');
end;

procedure TestSystemLimits;
begin
  CheckEqual(4095, PATH_MAX, 'PATH_MAX');
  CheckEqual(255, NAME_MAX, 'NAME_MAX');
  CheckEqual(131072, ARG_MAX, 'ARG_MAX');
  CheckEqual(65, SYS_NMLN, 'SYS_NMLN');
end;

procedure TestRLimitConstants;
begin
  CheckEqual(7, RLIMIT_NOFILE, 'RLIMIT_NOFILE');
  CheckEqual(0, RLIMIT_CPU, 'RLIMIT_CPU');
  CheckEqual(9, RLIMIT_AS, 'RLIMIT_AS');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.linux.ostypes_abi');
  T.Run('pollfd size', @TestPollfdSize);
  T.Run('iovec size', @TestIovecSize);
  T.Run('TRLimit size', @TestTRLimitSize);
  T.Run('tms size', @TestTmsSize);
  T.Run('timezone size', @TestTimezoneSize);
  T.Run('cpu_set_t size', @TestCpuSetSize);
  T.Run('UtsName size', @TestUtsNameSize);
  T.Run('TStatfs size', @TestStatfsSize);
  T.Run('TFDSet size', @TestFDSetSize);
  T.Run('poll constants', @TestPollConstants);
  T.Run('system limits', @TestSystemLimits);
  T.Run('rlimit constants', @TestRLimitConstants);
  T.Summary;
end.
