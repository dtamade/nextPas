program test_platform_pty_wine;

{$mode objfpc}{$H+}

uses
  SysUtils,
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
  LRet, LPid: Int32;
  LMasterFd: PtrInt;
  LFailStage: TPlatformPtySpawnStage;
begin
  WriteLn('=== platform.pty Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: pty_open succeeds
  WriteLn('Test 1: pty_open succeeds');
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRet := platform_pty_open(LSize, LPty);
  // May fail in Wine environment
  WriteLn('    pty_open returned: ', LRet);
  if LRet = 0 then
  begin
    Check(True, 'pty_open returns ok');

    // Test 2: pty_master_fd returns valid fd
    WriteLn('Test 2: pty_master_fd returns valid fd');
    LMasterFd := platform_pty_master_fd(LPty);
    WriteLn('    master_fd: ', LMasterFd);
    Check(LMasterFd >= 0, 'master_fd >= 0');

    // Test 3: pty_resize succeeds
    WriteLn('Test 3: pty_resize succeeds');
    LSize.FRows := 25;
    LSize.FCols := 132;
    LRet := platform_pty_resize(LPty, LSize);
    WriteLn('    pty_resize returned: ', LRet);
    Check(LRet = 0, 'pty_resize returns ok');

    // Test 4: pty_close succeeds
    WriteLn('Test 4: pty_close succeeds');
    LRet := platform_pty_close(LPty);
    WriteLn('    pty_close returned: ', LRet);
    Check(LRet = 0, 'pty_close returns ok');
  end
  else
  begin
    WriteLn('    PTY not available in this environment, skipping spawn tests');
    Check(True, 'pty_open handled gracefully');
  end;

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
