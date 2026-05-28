program test_platform_error;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.error,
  nextpas.core.testing;

var
  T: TTestRunner;

function StrContains(const AHaystack, ANeedle: PAnsiChar): Boolean;
var
  I, J, HLen, NLen: Int32;
begin
  HLen := 0;
  while AHaystack[HLen] <> #0 do Inc(HLen);
  NLen := 0;
  while ANeedle[NLen] <> #0 do Inc(NLen);
  if NLen = 0 then Exit(True);
  if NLen > HLen then Exit(False);
  for I := 0 to HLen - NLen do
  begin
    J := 0;
    while (J < NLen) and (AHaystack[I + J] = ANeedle[J]) do
      Inc(J);
    if J = NLen then Exit(True);
  end;
  Result := False;
end;

procedure TestENOENT;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 256);
  Check(R > 0, 'ENOENT returns length > 0');
  Check(StrContains(@Buf[0], 'o such file'), 'contains "o such file"');
end;

procedure TestEACCES;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(13, @Buf[0], 256);
  Check(R > 0, 'EACCES returns length > 0');
  Check(StrContains(@Buf[0], 'ermission'), 'contains "ermission"');
end;

procedure TestZero;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(0, @Buf[0], 256);
  Check(R >= 0, 'code 0 returns >= 0');
  Check(Buf[0] <> #0, 'non-empty string');
end;

procedure TestUnknown;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(9999, @Buf[0], 256);
  Check(R > 0, 'unknown code returns > 0');
  Check(Buf[0] <> #0, 'non-empty');
end;

procedure TestSmallBuffer;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 4);
  Check(R >= 0, 'small buffer does not crash');
  Check(Buf[3] = #0, 'null terminated');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.error');
  T.Run('ENOENT message', @TestENOENT);
  T.Run('EACCES message', @TestEACCES);
  T.Run('code 0 (Success)', @TestZero);
  T.Run('unknown error code', @TestUnknown);
  T.Run('small buffer truncation', @TestSmallBuffer);
  T.Summary;
end.
