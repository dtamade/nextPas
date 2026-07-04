program test_platform_struct_sizes;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestLinuxStat;
begin
  Check(SizeOf(TPlatformLinuxStat) = 144, 'TPlatformLinuxStat = 144');
end;

procedure TestEpollEvent;
begin
  Check(SizeOf(epoll_event) = 12, 'epoll_event = 12');
end;

procedure TestInotifyEvent;
begin
  Check(SizeOf(inotify_event) = 16, 'inotify_event = 16');
end;

procedure TestSockaddrIn;
begin
  Check(SizeOf(sockaddr_in) = 16, 'sockaddr_in = 16');
end;

procedure TestSockaddrIn6;
begin
  Check(SizeOf(sockaddr_in6) = 28, 'sockaddr_in6 = 28');
end;

procedure TestSockaddrStorage;
begin
  Check(SizeOf(sockaddr_storage) = 128, 'sockaddr_storage = 128');
end;

procedure TestAddrInfo;
begin
  Check(SizeOf(TAddrInfo) = 48, 'TAddrInfo = 48');
end;

procedure TestIovec;
begin
  Check(SizeOf(iovec) = 16, 'iovec = 16');
end;

procedure TestPollfd;
begin
  Check(SizeOf(pollfd) = 8, 'pollfd = 8');
end;

procedure TestPthreadTypes;
begin
  Check(SizeOf(pthread_mutex_t) = 40, 'pthread_mutex_t = 40');
  Check(SizeOf(pthread_rwlock_t) = 56, 'pthread_rwlock_t = 56');
  Check(SizeOf(pthread_cond_t) = 48, 'pthread_cond_t = 48');
  Check(SizeOf(pthread_t) = 8, 'pthread_t = 8');
  Check(SizeOf(pthread_key_t) = 4, 'pthread_key_t = 4');
end;

procedure TestFLock;
begin
  Check(SizeOf(FLock) = 32, 'FLock = 32');
end;

procedure TestMsghdr;
begin
  Check(SizeOf(msghdr) = 56, 'msghdr = 56');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.struct_sizes');
  T.Test('TPlatformLinuxStat = 144', @TestLinuxStat);
  T.Test('epoll_event = 12', @TestEpollEvent);
  T.Test('inotify_event = 16', @TestInotifyEvent);
  T.Test('sockaddr_in = 16', @TestSockaddrIn);
  T.Test('sockaddr_in6 = 28', @TestSockaddrIn6);
  T.Test('sockaddr_storage = 128', @TestSockaddrStorage);
  T.Test('TAddrInfo = 48', @TestAddrInfo);
  T.Test('iovec = 16', @TestIovec);
  T.Test('pollfd = 8', @TestPollfd);
  T.Test('pthread types', @TestPthreadTypes);
  T.Test('FLock = 32', @TestFLock);
  T.Test('msghdr = 56', @TestMsghdr);
  if not T.Run then Halt(1);
end.
