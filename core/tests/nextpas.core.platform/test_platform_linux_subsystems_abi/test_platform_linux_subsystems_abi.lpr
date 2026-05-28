program test_platform_linux_subsystems_abi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEpollEventSize;
begin
  CheckEqual(12, SizeOf(epoll_event), 'SizeOf(epoll_event) = 12 (packed)');
end;

procedure TestEpollConstants;
begin
  CheckEqual($01, EPOLLIN, 'EPOLLIN');
  CheckEqual($04, EPOLLOUT, 'EPOLLOUT');
  CheckEqual($10, EPOLLHUP, 'EPOLLHUP');
  CheckEqual(1, EPOLL_CTL_ADD, 'EPOLL_CTL_ADD');
  CheckEqual(2, EPOLL_CTL_DEL, 'EPOLL_CTL_DEL');
  CheckEqual(3, EPOLL_CTL_MOD, 'EPOLL_CTL_MOD');
end;

procedure TestInotifyEventSize;
begin
  CheckEqual(16, SizeOf(inotify_event), 'SizeOf(inotify_event) = 16');
end;

procedure TestInotifyConstants;
begin
  CheckEqual($00000001, IN_ACCESS, 'IN_ACCESS');
  CheckEqual($00000002, IN_MODIFY, 'IN_MODIFY');
  CheckEqual($00000100, IN_CREATE, 'IN_CREATE');
  CheckEqual($00000200, IN_DELETE, 'IN_DELETE');
end;

procedure TestSignalNumbers;
begin
  CheckEqual(1, SIGHUP, 'SIGHUP');
  CheckEqual(9, SIGKILL, 'SIGKILL');
  CheckEqual(10, SIGUSR1, 'SIGUSR1');
  CheckEqual(12, SIGUSR2, 'SIGUSR2');
  CheckEqual(15, SIGTERM, 'SIGTERM');
  CheckEqual(17, SIGCHLD, 'SIGCHLD');
  CheckEqual(11, SIGSEGV, 'SIGSEGV');
  CheckEqual(13, SIGPIPE, 'SIGPIPE');
end;

procedure TestSignalActionFlags;
begin
  CheckEqual($00000004, SA_SIGINFO, 'SA_SIGINFO');
  CheckEqual($10000000, SA_RESTART, 'SA_RESTART');
  CheckEqual($00000001, SA_NOCLDSTOP, 'SA_NOCLDSTOP');
end;

procedure TestSysInfoSize;
begin
{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
  CheckEqual(112, SizeOf(TSysInfo), 'SizeOf(TSysInfo) = 112 on 64-bit');
{$ENDIF}
end;

procedure TestCloneConstants;
begin
  CheckEqual($00000100, CLONE_VM, 'CLONE_VM');
  CheckEqual($00010000, CLONE_THREAD, 'CLONE_THREAD');
  CheckEqual($00000400, CLONE_FILES, 'CLONE_FILES');
  CheckEqual($00000800, CLONE_SIGHAND, 'CLONE_SIGHAND');
end;

procedure TestStatxConstants;
begin
  CheckEqual($00000001, STATX_TYPE, 'STATX_TYPE');
  CheckEqual($00000200, STATX_SIZE, 'STATX_SIZE');
  CheckEqual($00000fff, STATX_ALL, 'STATX_ALL');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.linux.subsystems_abi');
  T.Run('epoll_event size', @TestEpollEventSize);
  T.Run('epoll constants', @TestEpollConstants);
  T.Run('inotify_event size', @TestInotifyEventSize);
  T.Run('inotify constants', @TestInotifyConstants);
  T.Run('signal numbers', @TestSignalNumbers);
  T.Run('signal action flags', @TestSignalActionFlags);
  T.Run('TSysInfo size', @TestSysInfoSize);
  T.Run('clone constants', @TestCloneConstants);
  T.Run('statx constants', @TestStatxConstants);
  T.Summary;
end.
