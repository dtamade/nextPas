program test_platform_random_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.platform.random;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. 16-byte buffer: platform_random_bytes returns 0 (success) }
procedure TestReturnsZeroFor16Bytes;
var
  LBuf: array[0..15] of Byte;
  LRet: Int32;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRet := platform_random_bytes(@LBuf, SizeOf(LBuf));
  Check(LRet = 0, 'platform_random_bytes should return 0 for 16-byte buffer, got ' + IntToStr(LRet));
end;

{ 2. Two calls produce different values (non-deterministic) }
procedure TestTwoCallsDiffer;
var
  LBufA: array[0..15] of Byte;
  LBufB: array[0..15] of Byte;
begin
  FillChar(LBufA, SizeOf(LBufA), 0);
  FillChar(LBufB, SizeOf(LBufB), 0);
  platform_random_bytes(@LBufA, SizeOf(LBufA));
  platform_random_bytes(@LBufB, SizeOf(LBufB));
  Check(not CompareMem(@LBufA, @LBufB, SizeOf(LBufA)),
    'Two consecutive platform_random_bytes calls should produce different values');
end;

{ 3. Buffer is actually written (not all zeros after call) }
procedure TestBufferIsWritten;
var
  LBuf: array[0..15] of Byte;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  platform_random_bytes(@LBuf, SizeOf(LBuf));
  Check(not (LBuf[0] = 0) and not (LBuf[1] = 0) and not (LBuf[2] = 0) and
    not (LBuf[3] = 0) and not (LBuf[4] = 0) and not (LBuf[5] = 0) and
    not (LBuf[6] = 0) and not (LBuf[7] = 0) and not (LBuf[8] = 0) and
    not (LBuf[9] = 0) and not (LBuf[10] = 0) and not (LBuf[11] = 0) and
    not (LBuf[12] = 0) and not (LBuf[13] = 0) and not (LBuf[14] = 0) and
    not (LBuf[15] = 0),
    'Buffer should not be all zeros after platform_random_bytes');
end;

{ 4. Large buffer (4096 bytes) is filled normally }
procedure TestLargeBuffer;
var
  LBuf: array[0..4095] of Byte;
  LRet: Int32;
  LIdx: Integer;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRet := platform_random_bytes(@LBuf, SizeOf(LBuf));
  Check(LRet = 0, 'platform_random_bytes should return 0 for 4096-byte buffer, got ' + IntToStr(LRet));
  { Verify at least some bytes are non-zero }
  LIdx := 0;
  while (LIdx < SizeOf(LBuf)) and (LBuf[LIdx] = 0) do
    Inc(LIdx);
  Check(LIdx < SizeOf(LBuf), 'At least some bytes in the 4096-byte buffer should be non-zero');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.random.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('16-byte buffer returns 0', @TestReturnsZeroFor16Bytes);
  T.Test('two consecutive calls differ', @TestTwoCallsDiffer);
  T.Test('buffer is written (not all zeros)', @TestBufferIsWritten);
  T.Test('4096-byte buffer filled normally', @TestLargeBuffer);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.