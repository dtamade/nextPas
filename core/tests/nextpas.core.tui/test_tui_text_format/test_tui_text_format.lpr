program test_tui_text_format;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.text.format,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.tui.text.format');
  T.Run('bytes', @TestBytes);
  T.Run('KB', @TestKB);
  T.Run('MB', @TestMB);
  T.Run('GB', @TestGB);
  T.Run('from KB', @TestFromKB);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
