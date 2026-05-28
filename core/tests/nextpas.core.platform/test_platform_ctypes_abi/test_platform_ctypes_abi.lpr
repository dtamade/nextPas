program test_platform_ctypes_abi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCintSize;
begin
  Check(SizeOf(cint) = 4, 'cint = 4');
  Check(SizeOf(cuint) = 4, 'cuint = 4');
end;

procedure TestClongSize;
begin
{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64) or defined(NEXTPAS_RISCV64)}
  Check(SizeOf(clong) = 8, 'clong = 8 on LP64');
  Check(SizeOf(culong) = 8, 'culong = 8 on LP64');
{$ELSE}
  Check(SizeOf(clong) = 4, 'clong = 4 on ILP32');
  Check(SizeOf(culong) = 4, 'culong = 4 on ILP32');
{$ENDIF}
end;

procedure TestClonglongSize;
begin
  Check(SizeOf(clonglong) = 8, 'clonglong = 8');
  Check(SizeOf(culonglong) = 8, 'culonglong = 8');
end;

procedure TestCsizeT;
begin
  Check(SizeOf(csize_t) = SizeOf(PtrUInt), 'csize_t = PtrUInt');
  Check(SizeOf(csize_t) = SizeOf(Pointer), 'csize_t = Pointer');
end;

procedure TestCfloatDouble;
begin
  Check(SizeOf(cfloat) = 4, 'cfloat = 4');
  Check(SizeOf(cdouble) = 8, 'cdouble = 8');
end;

procedure TestFixedWidth;
begin
  Check(SizeOf(cint8) = 1, 'cint8 = 1');
  Check(SizeOf(cuint8) = 1, 'cuint8 = 1');
  Check(SizeOf(cint16) = 2, 'cint16 = 2');
  Check(SizeOf(cuint16) = 2, 'cuint16 = 2');
  Check(SizeOf(cint32) = 4, 'cint32 = 4');
  Check(SizeOf(cuint32) = 4, 'cuint32 = 4');
  Check(SizeOf(cint64) = 8, 'cint64 = 8');
  Check(SizeOf(cuint64) = 8, 'cuint64 = 8');
end;

procedure TestCharTypes;
begin
  Check(SizeOf(cchar) = 1, 'cchar = 1');
  Check(SizeOf(cuchar) = 1, 'cuchar = 1');
  Check(SizeOf(cshort) = 2, 'cshort = 2');
  Check(SizeOf(cushort) = 2, 'cushort = 2');
end;

procedure TestPointerSizedTypes;
begin
  Check(SizeOf(size_t) = SizeOf(Pointer), 'size_t = Pointer');
  Check(SizeOf(ssize_t) = SizeOf(Pointer), 'ssize_t = Pointer');
  Check(SizeOf(off_t) = 8, 'off_t = 8 (64-bit file offsets)');
end;

procedure TestPidUidGid;
begin
  Check(SizeOf(pid_t) = 4, 'pid_t = 4');
  Check(SizeOf(uid_t) = 4, 'uid_t = 4');
  Check(SizeOf(gid_t) = 4, 'gid_t = 4');
  Check(SizeOf(mode_t) = 4, 'mode_t = 4');
end;

procedure TestPthreadTypes;
begin
{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
  Check(SizeOf(pthread_t) = 8, 'pthread_t = 8 on 64-bit');
  Check(SizeOf(pthread_key_t) = 4, 'pthread_key_t = 4');
{$ENDIF}
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ctypes_abi');
  T.Run('cint/cuint = 4 bytes', @TestCintSize);
  T.Run('clong/culong LP64 vs ILP32', @TestClongSize);
  T.Run('clonglong/culonglong = 8', @TestClonglongSize);
  T.Run('csize_t = pointer size', @TestCsizeT);
  T.Run('cfloat=4, cdouble=8', @TestCfloatDouble);
  T.Run('fixed-width int types', @TestFixedWidth);
  T.Run('char/short types', @TestCharTypes);
  T.Run('pointer-sized POSIX types', @TestPointerSizedTypes);
  T.Run('pid_t/uid_t/gid_t/mode_t', @TestPidUidGid);
  T.Run('pthread types', @TestPthreadTypes);
  T.Summary;
end.
