program test_critical_rtl;

{$mode objfpc}{$H+}

uses
  SysUtils, Process, Classes;

var
  TestsPassed, TestsFailed: Integer;

procedure Test(const Name: string; Condition: Boolean);
begin
  Write('  ', Name, ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(TestsFailed);
  end;
end;

procedure TestGetEnvironmentVariable;
var
  Path: string;
begin
  WriteLn('Testing GetEnvironmentVariable...');
  Path := GetEnvironmentVariable('PATH');
  Test('PATH is not empty', Path <> '');
  Test('HOME exists', GetEnvironmentVariable('HOME') <> '');
  Test('Nonexistent var is empty', GetEnvironmentVariable('NEXTPAS_NONEXISTENT_VAR_12345') = '');
end;

procedure TestForceDirectories;
var
  TestDir: string;
begin
  WriteLn('Testing ForceDirectories...');
  TestDir := '/tmp/nextpas_test_dir_' + IntToStr(Random(99999));

  Test('Create single directory', ForceDirectories(TestDir));
  Test('Directory exists after creation', DirectoryExists(TestDir));

  Test('Create nested directories', ForceDirectories(TestDir + '/a/b/c'));
  Test('Nested directory exists', DirectoryExists(TestDir + '/a/b/c'));

  Test('ForceDirectories on existing dir succeeds', ForceDirectories(TestDir));

  // Cleanup
  RmDir(TestDir + '/a/b/c');
  RmDir(TestDir + '/a/b');
  RmDir(TestDir + '/a');
  RmDir(TestDir);
end;

procedure TestDirectoryExists;
begin
  WriteLn('Testing DirectoryExists...');
  Test('/tmp exists', DirectoryExists('/tmp'));
  Test('/usr exists', DirectoryExists('/usr'));
  Test('Nonexistent dir does not exist', not DirectoryExists('/nextpas_nonexistent_dir_12345'));
  Test('File is not a directory', not DirectoryExists('/etc/passwd'));
end;

procedure TestProcessExecute;
var
  Proc: TProcess;
  TestFile: string;
begin
  WriteLn('Testing TProcess.Execute...');

  TestFile := '/tmp/nextpas_test_' + IntToStr(Random(99999)) + '.txt';

  Proc := TProcess.Create(nil);
  try
    // Test 1: Simple command
    Proc.Executable := '/bin/echo';
    Proc.Parameters.Add('hello');
    Proc.Execute;
    Test('echo command succeeds', Proc.ExitStatus = 0);

    // Test 2: Command with exit code
    Proc.Executable := '/bin/sh';
    Proc.Parameters.Clear;
    Proc.Parameters.Add('-c');
    Proc.Parameters.Add('exit 42');
    Proc.Execute;
    Test('Exit code is captured', Proc.ExitStatus = 42);

    // Test 3: Create file
    Proc.Executable := '/bin/touch';
    Proc.Parameters.Clear;
    Proc.Parameters.Add(TestFile);
    Proc.Execute;
    Test('touch creates file', FileExists(TestFile));

    // Cleanup
    DeleteFile(TestFile);
  finally
    Proc.Free;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== Critical RTL Functions Test Suite ===');
  WriteLn;

  TestGetEnvironmentVariable;
  WriteLn;

  TestDirectoryExists;
  WriteLn;

  TestForceDirectories;
  WriteLn;

  TestProcessExecute;
  WriteLn;

  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed = 0 then
  begin
    WriteLn('All tests PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('Some tests FAILED!');
    Halt(1);
  end;
end.
