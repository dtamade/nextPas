program test_platform_simulated_host_compile_matrix;

{$I nextpas.core.settings.inc}

{$IFDEF SIM_EXPECT_DARWIN}
  {$IFNDEF NEXTPAS_MACOS}
    {$fatal simulated darwin compile must select NEXTPAS_MACOS}
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
    {$fatal simulated darwin compile must not keep NEXTPAS_LINUX}
  {$ENDIF}
{$ENDIF}

{$IFDEF SIM_EXPECT_ANDROID}
  {$IFNDEF NEXTPAS_ANDROID}
    {$fatal simulated android compile must select NEXTPAS_ANDROID}
  {$ENDIF}
  {$IFNDEF NEXTPAS_POSIX_CLOCK}
    {$fatal simulated android compile must enable NEXTPAS_POSIX_CLOCK}
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
    {$fatal simulated android compile must not keep NEXTPAS_LINUX}
  {$ENDIF}
{$ENDIF}

{$IFDEF SIM_EXPECT_FREEBSD}
  {$IFNDEF NEXTPAS_FREEBSD}
    {$fatal simulated freebsd compile must select NEXTPAS_FREEBSD}
  {$ENDIF}
  {$IFNDEF NEXTPAS_POSIX_CLOCK}
    {$fatal simulated freebsd compile must enable NEXTPAS_POSIX_CLOCK}
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
    {$fatal simulated freebsd compile must not keep NEXTPAS_LINUX}
  {$ENDIF}
{$ENDIF}

{$IFDEF SIM_EXPECT_UNIX}
  {$IFNDEF NEXTPAS_UNIX}
    {$fatal simulated unix compile must select NEXTPAS_UNIX}
  {$ENDIF}
  {$IFNDEF NEXTPAS_POSIX_CLOCK}
    {$fatal simulated unix compile must enable NEXTPAS_POSIX_CLOCK}
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
    {$fatal simulated unix compile must not keep NEXTPAS_LINUX}
  {$ENDIF}
  {$IFDEF NEXTPAS_MACOS}
    {$fatal simulated unix compile must not keep NEXTPAS_MACOS}
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
    {$fatal simulated unix compile must not keep NEXTPAS_ANDROID}
  {$ENDIF}
  {$IFDEF NEXTPAS_FREEBSD}
    {$fatal simulated unix compile must not keep NEXTPAS_FREEBSD}
  {$ENDIF}
{$ENDIF}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.thread,
  nextpas.core.platform.sync
  {$IFDEF SIM_EXPECT_DARWIN}, nextpas.core.platform.darwin.ffi{$ENDIF}
  {$IFDEF SIM_EXPECT_ANDROID}, nextpas.core.platform.android.ffi{$ENDIF}
  {$IFDEF SIM_EXPECT_FREEBSD}, nextpas.core.platform.freebsd.ffi{$ENDIF}
  {$IFDEF SIM_EXPECT_UNIX}, nextpas.core.platform.unix.ffi{$ENDIF}
  ;

var
  LMonotonicNs: UInt64;
  LRealtimeNs: UInt64;
  LResolutionNs: UInt64;
  LThreadHandle: TPlatformThreadHandle;
  LTlsKey: TPlatformTLSKey;
  LThreadProc: TPlatformThreadProc;
  LMutex: TPlatformMutex;
  LRwLock: TPlatformRwLock;
  LCondVar: TPlatformCondVar;
  LThreadResult: Pointer;
  LError: Int32;
  LThreadId: UInt64;
  LCpuCount: Int32;
{$IFDEF SIM_EXPECT_DARWIN}
  LDarwinTokenAlign: TPlatformPThreadTokenAlign;
{$ENDIF}
{$IFDEF SIM_EXPECT_ANDROID}
  LAndroidTokenAlign: TPlatformPThreadTokenAlign;
{$ENDIF}
{$IFDEF SIM_EXPECT_FREEBSD}
  LFreeBSDTokenAlign: TPlatformPThreadTokenAlign;
{$ENDIF}
{$IFDEF SIM_EXPECT_UNIX}
  LUnixTokenAlign: TPlatformPThreadTokenAlign;
{$ENDIF}

begin
  LMonotonicNs := platform_monotonic_ns;
  LRealtimeNs := platform_realtime_ns;
  LResolutionNs := platform_monotonic_resolution_ns;
  LThreadHandle := nil;
  LTlsKey := 0;
  LThreadProc := nil;
  LThreadResult := nil;
  LError := platform_thread_create(LThreadHandle, LThreadProc, nil);
  LError := LError + platform_thread_join(LThreadHandle, LThreadResult);
  LError := LError + platform_thread_detach(LThreadHandle);
  LError := LError + platform_tls_create(LTlsKey);
  LError := LError + platform_tls_destroy(LTlsKey);
  LError := LError + platform_tls_set(LTlsKey, nil);
  LThreadResult := platform_tls_get(LTlsKey);
  LThreadId := platform_thread_id + platform_thread_self;
  platform_thread_yield;
  platform_thread_sleep_ns(1);
  LCpuCount := platform_cpu_count;

  LError := LError + platform_mutex_init(LMutex);
  LError := LError + platform_mutex_destroy(LMutex);
  LError := LError + platform_rwlock_init(LRwLock);
  LError := LError + platform_rwlock_destroy(LRwLock);
  LError := LError + platform_condvar_init(LCondVar);
  LError := LError + platform_condvar_destroy(LCondVar);

{$IFDEF SIM_EXPECT_DARWIN}
  LThreadId := LThreadId + SizeOf(LDarwinTokenAlign);
{$ENDIF}
{$IFDEF SIM_EXPECT_ANDROID}
  LThreadId := LThreadId + SizeOf(LAndroidTokenAlign);
{$ENDIF}
{$IFDEF SIM_EXPECT_FREEBSD}
  LThreadId := LThreadId + SizeOf(LFreeBSDTokenAlign);
{$ENDIF}
{$IFDEF SIM_EXPECT_UNIX}
  LThreadId := LThreadId + SizeOf(LUnixTokenAlign);
{$ENDIF}

  if (LError <> High(Int32)) and (LCpuCount = High(Int32)) and
     (LMonotonicNs = High(UInt64)) and (LRealtimeNs = High(UInt64)) and
     (LResolutionNs = High(UInt64)) and (LThreadId = High(UInt64)) then
    Halt(1);
end.
