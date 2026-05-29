program test_fpc_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fpc.process,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCreateFree;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  Check(P.ExitStatus = -1, 'initial exit -1');
  Check(not P.Running, 'not running');
  P.Free;
end;

procedure TestExecuteTrue;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  P.Executable := '/bin/true';
  P.Options := [poWaitOnExit];
  P.Execute;
  Check(P.ExitStatus = 0, 'true exits 0');
  Check(not P.Running, 'not running after wait');
  P.Free;
end;

procedure TestExecuteFalse;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  P.Executable := '/bin/false';
  P.Options := [poWaitOnExit];
  P.Execute;
  Check(P.ExitStatus = 1, 'false exits 1');
  P.Free;
end;

procedure TestParameters;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  P.Executable := '/bin/test';
  P.Parameters.Add('-d');
  P.Parameters.Add('/tmp');
  P.Options := [poWaitOnExit];
  P.Execute;
  Check(P.ExitStatus = 0, 'test -d /tmp exits 0');
  P.Free;
end;

procedure TestCurrentDirectory;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  P.Executable := '/bin/test';
  P.Parameters.Add('-f');
  P.Parameters.Add('nextpas.core.settings.inc');
  P.CurrentDirectory := '/home/dtamade/projects/nextPas/core/src';
  P.Options := [poWaitOnExit];
  P.Execute;
  Check(P.ExitStatus = 0, 'file exists in cwd');
  P.Free;
end;

procedure TestNonExistent;
var P: TProcess;
begin
  P := TProcess.Create(nil);
  P.Executable := '/nonexistent_binary_xyz';
  P.Options := [poWaitOnExit];
  P.Execute;
  Check(P.ExitStatus = 127, 'non-existent exits 127');
  P.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.fpc.process');
  T.Run('Create/Free', @TestCreateFree);
  T.Run('Execute /bin/true', @TestExecuteTrue);
  T.Run('Execute /bin/false', @TestExecuteFalse);
  T.Run('Parameters', @TestParameters);
  T.Run('CurrentDirectory', @TestCurrentDirectory);
  T.Run('Non-existent binary', @TestNonExistent);
  T.Summary;
end.
