program bench_compare;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.platform.time, nextpas.core.platform.path,
  nextpas.core.platform.fs, nextpas.core.platform.mmap,
  nextpas.core.platform.random, nextpas.core.platform.files.base, nextpas.core.platform.files;
const TEST_FILE = '/tmp/bench_exists_test.txt'; MMAP_FILE = '/tmp/bench_mmap_1mb.dat';
var GSink: UInt64;
procedure Setup;
var H: TPlatformFileHandle; Buf: array[0..4095] of Byte; W: PtrUInt; I: Int32;
begin
  platform_file_open(TEST_FILE, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W); platform_file_close(H);
  FillChar(Buf, 4096, $AA);
  platform_file_open(MMAP_FILE, fomWriteOnly, fcmCreateAlways, H);
  for I := 1 to 256 do platform_file_write(H, @Buf[0], 4096, W);
  platform_file_close(H);
end;
procedure Teardown;
begin platform_file_unlink(TEST_FILE); platform_file_unlink(MMAP_FILE); end;
procedure BenchPathJoin(const ACtx: IBenchContext);
var Buf: array[0..255] of AnsiChar;
begin platform_path_join('/home/user/projects', 'nextpas/core/src/file.pas', @Buf[0], 256); GSink := GSink xor UInt64(Length(Buf)); end;
procedure BenchPathBasename(const ACtx: IBenchContext);
var Buf: array[0..255] of AnsiChar;
begin platform_path_basename('/home/user/projects/nextpas/core/src/file.pas', @Buf[0], 256); GSink := GSink xor UInt64(Length(Buf)); end;
procedure BenchFileExists(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := platform_file_exists(TEST_FILE); GSink := GSink xor Byte(LB); end;
procedure BenchMmapView(const ACtx: IBenchContext);
var LH: TPlatformFileHandle; LView: TPlatformMmapView; LByte: Byte;
begin
  if platform_file_open(MMAP_FILE, fomReadOnly, fcmOpenExisting, LH) <> 0 then begin ACtx.Skip; Exit; end;
  if platform_mmap_view(LH, 0, 4096, LView) then begin LByte := PByte(LView.Data)^; GSink := GSink xor LByte; platform_mmap_unview(LView); end;
  platform_file_close(LH);
end;
procedure BenchRandomU32(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(platform_random_u32); end;
var LSuite: IBenchSuite;
begin
  Setup; GSink := 0;
  LSuite := TBenchSuite.Create('platform-comparison-nextpas');
  LSuite.Add('PathJoin', @BenchPathJoin).Add('PathBasename', @BenchPathBasename)
    .Add('FileExists', @BenchFileExists).Add('MmapView', @BenchMmapView).Add('RandomU32', @BenchRandomU32);
  WriteLn(LSuite.Run.PrintToConsole);
  Teardown;
end.
