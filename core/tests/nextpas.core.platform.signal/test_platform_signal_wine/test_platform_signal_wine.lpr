program test_platform_signal_wine;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.signal;

var
  LPassed, LFailed: Int32;

procedure Check(ACond: Boolean; const AName: string);
begin
  if ACond then
  begin
    Inc(LPassed);
    WriteLn('  ✓ ', AName);
  end
  else
  begin
    Inc(LFailed);
    WriteLn('  ✗ ', AName);
  end;
end;

var
  LRet: Int32;
begin
  WriteLn('=== platform.signal Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: signal constants exist
  WriteLn('Test 1: signal constants exist');
  Check(PLATFORM_SIGINT = 2, 'PLATFORM_SIGINT = 2');
  Check(PLATFORM_SIGTERM = 15, 'PLATFORM_SIGTERM = 15');
  {$IFDEF NEXTPAS_WINDOWS}
  Check(PLATFORM_SIGBREAK = 21, 'PLATFORM_SIGBREAK = 21 (Windows)');
  {$ENDIF}

  // Test 2: nil handler is invalid (Windows and POSIX)
  WriteLn('Test 2: signal set rejects nil handler');
  LRet := platform_signal_set(PLATFORM_SIGINT, nil);
  Check(LRet <> 0, 'signal_set(nil) returns error');

  // Test 3: signal ignore returns ok (Windows console path installs handler)
  WriteLn('Test 3: signal ignore returns ok');
  LRet := platform_signal_ignore(PLATFORM_SIGINT);
  Check(LRet = 0, 'signal_ignore returns ok');

  // Test 4: signal reset returns ok
  WriteLn('Test 4: signal reset returns ok');
  LRet := platform_signal_reset(PLATFORM_SIGINT);
  Check(LRet = 0, 'signal_reset returns ok');

  // Test 5: block is unsupported on Windows; POSIX may succeed
  WriteLn('Test 5: signal block behavior');
  LRet := platform_signal_block(PLATFORM_SIGINT);
{$IFDEF NEXTPAS_WINDOWS}
  Check(LRet <> 0, 'signal_block unsupported on Windows');
{$ELSE}
  Check(LRet = 0, 'signal_block returns ok on POSIX');
{$ENDIF}
  WriteLn('    signal_block returned: ', LRet);

  // Test 6: unblock is unsupported on Windows; POSIX may succeed
  WriteLn('Test 6: signal unblock behavior');
  LRet := platform_signal_unblock(PLATFORM_SIGINT);
{$IFDEF NEXTPAS_WINDOWS}
  Check(LRet <> 0, 'signal_unblock unsupported on Windows');
{$ELSE}
  Check(LRet = 0, 'signal_unblock returns ok on POSIX');
{$ENDIF}
  WriteLn('    signal_unblock returned: ', LRet);

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
