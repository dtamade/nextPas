program test_tui_text_format;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.text.format,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBytes;
begin
  CheckEqual('0 B', FormatBytes(0), '0 bytes');
  CheckEqual('512 B', FormatBytes(512), '512 bytes');
  CheckEqual('1023 B', FormatBytes(1023), '1023 bytes');
end;

procedure TestKB;
begin
  CheckEqual('1 KB', FormatBytes(1024), '1 KB exact');
  CheckEqual('1.5 KB', FormatBytes(1536), '1.5 KB');
  CheckEqual('2 KB', FormatBytes(2048), '2 KB exact');
end;

procedure TestMB;
begin
  CheckEqual('1 MB', FormatBytes(1024 * 1024), '1 MB exact');
  CheckEqual('1.5 MB', FormatBytes(1024 * 1024 + 512 * 1024), '1.5 MB');
end;

procedure TestGB;
begin
  CheckEqual('1 GB', FormatBytes(Int64(1024) * 1024 * 1024), '1 GB exact');
  CheckEqual('2 GB', FormatBytes(Int64(2) * 1024 * 1024 * 1024), '2 GB exact');
end;

procedure TestFromKB;
begin
  CheckEqual('1 MB', FormatBytesKB(1024), '1024 KB = 1 MB');
  CheckEqual('1 KB', FormatBytesKB(1), '1 KB');
end;

procedure TestFractionalKB;
begin
  { 1536 bytes = 1.5 KB }
  CheckEqual('1.5 KB', FormatBytes(1536), '1.5 KB');
  { 2048 bytes = 2 KB (exact) }
  CheckEqual('2 KB', FormatBytes(2048), '2 KB exact');
end;

procedure TestFractionalMB;
begin
  { 1.5 MB = 1572864 bytes }
  CheckEqual('1.5 MB', FormatBytes(1572864), '1.5 MB');
end;

procedure TestFractionalGB;
begin
  { 1.5 GB = 1610612736 bytes }
  CheckEqual('1.5 GB', FormatBytes(Int64(1610612736)), '1.5 GB');
end;

procedure TestBoundaryKB;
begin
  { 1023 bytes = 1023 B (still in bytes range) }
  CheckEqual('1023 B', FormatBytes(1023), '1023 B');
  { 1024 bytes = 1 KB }
  CheckEqual('1 KB', FormatBytes(1024), '1024 = 1 KB');
end;

procedure TestBoundaryMB;
begin
  { 1048575 bytes = 1023.9 KB ~ 1024 KB }
  Check(Pos('KB', FormatBytes(1048575)) > 0, '1048575 is KB');
  { 1048576 bytes = 1 MB }
  CheckEqual('1 MB', FormatBytes(1048576), '1048576 = 1 MB');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.text.format');
  T.Test('bytes', @TestBytes);
  T.Test('KB', @TestKB);
  T.Test('MB', @TestMB);
  T.Test('GB', @TestGB);
  T.Test('from KB', @TestFromKB);
  T.Test('fractional KB', @TestFractionalKB);
  T.Test('fractional MB', @TestFractionalMB);
  T.Test('fractional GB', @TestFractionalGB);
  T.Test('boundary KB', @TestBoundaryKB);
  T.Test('boundary MB', @TestBoundaryMB);
  if not T.Run then Halt(1);
end.
