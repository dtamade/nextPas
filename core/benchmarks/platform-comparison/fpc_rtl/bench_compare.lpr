program bench_compare;
{$mode objfpc}{$H+}
uses nextpas.core.bench, nextpas.core.bench.intf, SysUtils, Linux, UnixType;
const TEST_FILE = '/tmp/bench_exists_test.txt'; MMAP_FILE = '/tmp/bench_mmap_1mb.dat';
var GSink: UInt64;
procedure Setup;
var F: file; Buf: array[0..4095] of Byte; I: Int32;
begin
  Assign(F, TEST_FILE); Rewrite(F, 1); BlockWrite(F, Byte(120), 1); Close(F);
  FillChar(Buf, 4096, $AA);
  Assign(F, MMAP_FILE); Rewrite(F, 1);
  for I := 1 to 256 do BlockWrite(F, Buf, 4096);
  Close(F);
end;
procedure Teardown;
begin DeleteFile(TEST_FILE); DeleteFile(MMAP_FILE); end;
procedure BenchPathJoin(const ACtx: IBenchContext);
var S: string;
begin S := ConcatPaths(['/home/user/projects', 'nextpas/core/src/file.pas']); GSink := GSink xor UInt64(Length(S)); end;
procedure BenchPathBasename(const ACtx: IBenchContext);
var S: string;
begin S := ExtractFileName('/home/user/projects/nextpas/core/src/file.pas'); GSink := GSink xor UInt64(Length(S)); end;
procedure BenchFileExists(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := FileExists(TEST_FILE); GSink := GSink xor Byte(LB); end;
var LSuite: IBenchSuite;
begin
  Setup; GSink := 0;
  LSuite := TBenchSuite.Create('platform-comparison-fpc-rtl');
  LSuite.Add('PathJoin', @BenchPathJoin).Add('PathBasename', @BenchPathBasename).Add('FileExists', @BenchFileExists);
  WriteLn(LSuite.Run.PrintToConsole);
  Teardown;
end.
