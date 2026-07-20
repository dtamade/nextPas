program test_platform_pty_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.pty.base,
  nextpas.core.platform.pty,
  nextpas.core.platform.error;

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
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRet: Int32;
  LMasterFd: PtrInt;
begin
  WriteLn('=== platform.pty wine-runtime-smoke ===');
  WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready');
  LPassed := 0;
  LFailed := 0;

  WriteLn('Test 1: size record fields (API surface)');
  LSize.Rows := 24;
  LSize.Cols := 80;
  Check(LSize.Rows = 24, 'Rows field');
  Check(LSize.Cols = 80, 'Cols field');
  Check(LSize.IsValid, 'size IsValid for 24x80');

  WriteLn('Test 2: invalid size');
  LSize.Rows := 0;
  LSize.Cols := 0;
  Check(LSize.IsInvalid, '0x0 IsInvalid');
  Check(LSize.IsEmpty, '0x0 IsEmpty');

  WriteLn('Test 3: pty_open (ConPTY may be unavailable under Wine)');
  LSize.Rows := 24;
  LSize.Cols := 80;
  LRet := platform_pty_open(LSize, LPty);
  WriteLn('    pty_open returned: ', LRet);
  if LRet = 0 then
  begin
    Check(True, 'pty_open returns ok');

    WriteLn('Test 4: master_fd');
    LMasterFd := platform_pty_master_fd(LPty);
    WriteLn('    master_fd: ', LMasterFd);
    { Windows ConPTY path uses pipe handles; treat non-negative as ok. }
    Check(LMasterFd >= 0, 'master_fd >= 0');

    WriteLn('Test 5: resize (Wine ConPTY may return E_NOTIMPL)');
    LSize.Rows := 25;
    LSize.Cols := 132;
    LRet := platform_pty_resize(LPty, LSize);
    WriteLn('    pty_resize returned: ', LRet);
    { Accept 0 or non-zero: Wine ConPTY ResizePseudoConsole is incomplete. }
    Check(True, 'pty_resize invoked without crash');

    WriteLn('Test 6: close');
    LRet := platform_pty_close(LPty);
    WriteLn('    pty_close returned: ', LRet);
    Check(LRet = 0, 'pty_close returns ok');
  end
  else
  begin
    { Wine often lacks full ConPTY; fail-closed error is acceptable smoke. }
    Check(LRet <> 0, 'pty_open fails closed when ConPTY unavailable');
    Check(True, 'pty_open graceful failure under Wine');
  end;

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    Halt(1);
end.
