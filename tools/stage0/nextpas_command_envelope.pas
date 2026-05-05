unit nextpas_command_envelope;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_projection_json,
  nextpas_projection_text;

const
  ExitSuccessCode = 0;
  ExitFailureCode = 1;

function EnvelopeCommandName(const AState: TNextPasState): string;
function EnvelopeSelectorName(const AState: TNextPasState): string;
function FailureKindFromMessage(const Message: string): string;
procedure WriteUsageLine(const UseStdErr: Boolean; const Value: string);
procedure PrintBuildUsage(const UseStdErr: Boolean);
procedure PrintTestUsage(const UseStdErr: Boolean);
procedure PrintEnvUsage(const UseStdErr: Boolean);
procedure PrintDoctorUsage(const UseStdErr: Boolean);
procedure PrintQueryUsage(const UseStdErr: Boolean);
procedure PrintPkgUsage(const UseStdErr: Boolean);
procedure PrintUsage(const ACommandName: string);
procedure PrintUsageError(const ACommandName: string);
procedure Fail(
  const AState: TNextPasState;
  const Message: string;
  ShowUsage: Boolean = False
);

implementation

function EnvelopeCommandName(const AState: TNextPasState): string;
begin
  if AState.CommandName <> '' then
    Exit(AState.CommandName);

  Result := 'cli';
end;

function EnvelopeSelectorName(const AState: TNextPasState): string;
begin
  if AState.SelectorName <> '' then
    Exit(AState.SelectorName);
  if AState.CommandName = 'build' then
    Exit('build');
  if AState.CommandName = 'test' then
    Exit('test');
  if AState.CommandName = 'env' then
    Exit('env');
  if AState.CommandName = 'doctor' then
    Exit('doctor');
  if AState.CommandName = 'query' then
    Exit('query');
  if AState.CommandName = 'pkg' then
    Exit('pkg');

  Result := 'cli';
end;

function FailureKindFromMessage(const Message: string): string;
var
  SeparatorPosition: SizeInt;
begin
  SeparatorPosition := Pos(':', Message);
  if SeparatorPosition > 1 then
    Exit(Copy(Message, 1, SeparatorPosition - 1));

  Result := Message;
end;

procedure WriteUsageLine(const UseStdErr: Boolean; const Value: string);
begin
  if UseStdErr then
    WriteLn(ErrOutput, Value)
  else
    WriteLn(Value);
end;

procedure PrintBuildUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
end;

procedure PrintTestUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    UseStdErr,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
end;

procedure PrintEnvUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
end;

procedure PrintDoctorUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
end;

procedure PrintQueryUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
end;

procedure PrintPkgUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
end;

procedure PrintUsage(const ACommandName: string);
begin
  if ACommandName = 'build' then
  begin
    PrintBuildUsage(False);
    Exit;
  end;

  if ACommandName = 'test' then
  begin
    PrintTestUsage(False);
    Exit;
  end;

  if ACommandName = 'env' then
  begin
    PrintEnvUsage(False);
    Exit;
  end;

  if ACommandName = 'doctor' then
  begin
    PrintDoctorUsage(False);
    Exit;
  end;

  if ACommandName = 'query' then
  begin
    PrintQueryUsage(False);
    Exit;
  end;

  if ACommandName = 'pkg' then
  begin
    PrintPkgUsage(False);
    Exit;
  end;

  WriteUsageLine(False, 'Usage:');
  WriteUsageLine(
    False,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
  WriteUsageLine(
    False,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
  WriteUsageLine(
    False,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
end;

procedure PrintUsageError(const ACommandName: string);
begin
  if ACommandName = 'build' then
  begin
    PrintBuildUsage(True);
    Exit;
  end;

  if ACommandName = 'test' then
  begin
    PrintTestUsage(True);
    Exit;
  end;

  if ACommandName = 'env' then
  begin
    PrintEnvUsage(True);
    Exit;
  end;

  if ACommandName = 'doctor' then
  begin
    PrintDoctorUsage(True);
    Exit;
  end;

  if ACommandName = 'query' then
  begin
    PrintQueryUsage(True);
    Exit;
  end;

  if ACommandName = 'pkg' then
  begin
    PrintPkgUsage(True);
    Exit;
  end;

  WriteUsageLine(True, 'Usage:');
  WriteUsageLine(
    True,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
  WriteUsageLine(
    True,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
  WriteUsageLine(
    True,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
end;

procedure Fail(
  const AState: TNextPasState;
  const Message: string;
  ShowUsage: Boolean = False
);
var
  FailureKind: string;
begin
  FailureKind := FailureKindFromMessage(Message);
  if AState.CommandName <> '' then
    WriteLn(ErrOutput, 'command=', AState.CommandName);
  WriteLn(ErrOutput, 'selector=', EnvelopeSelectorName(AState));
  if AState.BuildContext.TargetName <> '' then
    WriteLn(ErrOutput, 'target=', AState.BuildContext.TargetName);
  PrintSessionProjection(True, AState);
  WriteLn(ErrOutput, 'status=failure');
  WriteLn(ErrOutput, 'result=failure');
  WriteLn(ErrOutput, 'failure-kind=', FailureKind);
  WriteLn(ErrOutput, 'command-outcome=failure');
  PrintCommandEnvelope(
    AState,
    ExitFailureCode,
    EnvelopeSelectorName(AState),
    'failure',
    'failure',
    FailureKind,
    Message,
    True
  );
  WriteLn(ErrOutput, 'human-summary=', Message);
  WriteLn(ErrOutput, Message);
  if ShowUsage then
    PrintUsageError(AState.CommandName);
  Halt(ExitFailureCode);
end;

end.
