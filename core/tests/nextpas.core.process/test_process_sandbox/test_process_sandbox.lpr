program test_process_sandbox;

{ D29 门测：nextpas.core.process.sandbox
  - 纯函数（DefaultSandboxSpec / IsEmptySandboxSpec / BuildBwrapCommand）全平台必跑；
  - 探测（BwrapAvailable / BwrapVersion）与集成断言在 bwrap 不可用环境 skip。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.command,
  nextpas.core.process.sandbox;

{ --- 纯函数测试（无 IO，全平台） --- }

procedure TestDefaultSpec;
var
  LSpec: TSandboxSpec;
begin
  LSpec := DefaultSandboxSpec;
  CheckEqual(True, LSpec.DevNull, 'default: DevNull');
  CheckEqual(False, LSpec.Proc, 'default: Proc off（规避嵌套容器 mount proc 失败）');
  CheckEqual(True, LSpec.TempTmp, 'default: TempTmp');
  CheckEqual(False, LSpec.Network, 'default: Network off（禁网）');
  CheckEqual(True, LSpec.ReadOnlyRoot, 'default: ReadOnlyRoot');
  CheckEqual(Int64(0), Int64(Length(LSpec.RoBinds)), 'default: no ro binds');
  CheckEqual(Int64(0), Int64(Length(LSpec.Writable)), 'default: no writable');
end;

procedure TestIsEmptySpec;
var
  LSpec: TSandboxSpec;
begin
  LSpec := DefaultSandboxSpec;
  CheckEqual(False, IsEmptySandboxSpec(LSpec), 'default spec is not empty');
  { 零值 record（未配置）= 空 → 跳过包装（Network 零值=False 同样算空） }
  LSpec.RoBinds := nil;
  LSpec.Writable := nil;
  LSpec.DevNull := False;
  LSpec.Proc := False;
  LSpec.TempTmp := False;
  LSpec.Network := False;
  LSpec.ReadOnlyRoot := False;
  CheckEqual(True, IsEmptySandboxSpec(LSpec), 'zero spec is empty');
end;

procedure TestBuildDefault;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
begin
  LSpec := DefaultSandboxSpec;
  LArgs := BuildBwrapCommand(LSpec, '/bin/echo', ['hi']);
  CheckEqual(Int64(11), Int64(Length(LArgs)), 'default argv length');
  CheckEqual('--ro-bind', LArgs[0], 'argv[0]: ro-bind root');
  CheckEqual('/', LArgs[1], 'argv[1]: src /');
  CheckEqual('/', LArgs[2], 'argv[2]: dst /');
  CheckEqual('--dev', LArgs[3], 'argv[3]: dev');
  CheckEqual('/dev', LArgs[4], 'argv[4]: /dev');
  CheckEqual('--tmpfs', LArgs[5], 'argv[5]: tmpfs');
  CheckEqual('/tmp', LArgs[6], 'argv[6]: /tmp');
  CheckEqual('--unshare-net', LArgs[7], 'argv[7]: unshare-net');
  CheckEqual('--', LArgs[8], 'argv[8]: separator');
  CheckEqual('/bin/echo', LArgs[9], 'argv[9]: wrapped path');
  CheckEqual('hi', LArgs[10], 'argv[10]: wrapped arg');
end;

procedure TestBuildMounts;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
begin
  LSpec := DefaultSandboxSpec;
  SetLength(LSpec.Writable, 2);
  LSpec.Writable[0] := '/ws';
  LSpec.Writable[1] := '/host/data=/srv/data';
  SetLength(LSpec.RoBinds, 2);
  LSpec.RoBinds[0] := '/ws/.git';
  LSpec.RoBinds[1] := '/etc/passwd=/host-passwd';
  LArgs := BuildBwrapCommand(LSpec, '/bin/true', []);
  CheckEqual('--unshare-net', LArgs[7], 'unshare-net');
  CheckEqual('--bind', LArgs[8], 'writable[0] flag');
  CheckEqual('/ws', LArgs[9], 'writable[0] src');
  CheckEqual('/ws', LArgs[10], 'writable[0] dst=src 缺省');
  CheckEqual('--bind', LArgs[11], 'writable[1] flag');
  CheckEqual('/host/data', LArgs[12], 'writable[1] src');
  CheckEqual('/srv/data', LArgs[13], 'writable[1] dst');
  CheckEqual('--ro-bind', LArgs[14], 'ro[0] flag');
  CheckEqual('/ws/.git', LArgs[15], 'ro[0] src');
  CheckEqual('/ws/.git', LArgs[16], 'ro[0] dst');
  CheckEqual('--ro-bind', LArgs[17], 'ro[1] flag');
  CheckEqual('/etc/passwd', LArgs[18], 'ro[1] src');
  CheckEqual('/host-passwd', LArgs[19], 'ro[1] dst');
  CheckEqual('--', LArgs[20], 'separator after mounts');
  CheckEqual('/bin/true', LArgs[21], 'wrapped path');
end;

procedure TestBuildNoRoot;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
begin
  LSpec := DefaultSandboxSpec;
  LSpec.ReadOnlyRoot := False;
  LArgs := BuildBwrapCommand(LSpec, '/bin/true', []);
  CheckEqual('--tmpfs', LArgs[0], 'no-root: tmpfs root');
  CheckEqual('/', LArgs[1], 'no-root: tmpfs at /');
end;

procedure TestBuildFlagsOff;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
begin
  LSpec := DefaultSandboxSpec;
  LSpec.DevNull := False;
  LSpec.TempTmp := False;
  LSpec.Network := True;
  LSpec.Proc := True;
  LArgs := BuildBwrapCommand(LSpec, '/bin/true', []);
  CheckEqual('--ro-bind', LArgs[0], 'flags-off: ro-bind root');
  CheckEqual('/', LArgs[1], 'flags-off: root src');
  CheckEqual('/', LArgs[2], 'flags-off: root dst');
  CheckEqual('--proc', LArgs[3], 'flags-off: proc flag');
  CheckEqual('/proc', LArgs[4], 'flags-off: proc target');
  { 无 --dev、--tmpfs /tmp、--unshare-net }
  CheckEqual('--', LArgs[5], 'flags-off: separator directly');
end;

{ --- 探测测试（bwrap 不可用环境 skip） --- }

procedure TestProbe;
begin
  if not BwrapAvailable then
  begin
    WriteLn('SKIP: bwrap 不可用（无二进制或环境无 userns），跳过探测断言');
    Exit;
  end;
  CheckNotEqual('', BwrapVersion, 'available 时 version 非空');
end;

{ --- 集成测试（bwrap 可用时） --- }

procedure TestSandboxedEcho;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
  LPath: string;
  LOut: TProcessOutput;
begin
  if not BwrapAvailable then
  begin
    WriteLn('SKIP: bwrap 不可用，跳过集成断言');
    Exit;
  end;
  if not TryLookPath('bwrap', LPath) then
  begin
    WriteLn('SKIP: bwrap 不在 PATH，跳过集成断言');
    Exit;
  end;
  LSpec := DefaultSandboxSpec;
  LArgs := BuildBwrapCommand(LSpec, '/bin/echo', ['sandboxed']);
  LOut := TCommand.New(LPath).Args(LArgs).Stdout(stPiped).Stderr(stPiped)
    .MaxOutput(4096).Spawn.WaitWithOutput;
  Check(ProcessSucceeded(LOut), 'sandboxed echo: exit 0');
  Check(Pos('sandboxed', LOut.StdOut) > 0, 'sandboxed echo: stdout captured');
end;

procedure TestReadOnlyRootRejectsWrite;
var
  LSpec: TSandboxSpec;
  LArgs: TStringArray;
  LPath: string;
  LOut: TProcessOutput;
begin
  if not BwrapAvailable then
  begin
    WriteLn('SKIP: bwrap 不可用，跳过只读根断言');
    Exit;
  end;
  if not TryLookPath('bwrap', LPath) then
  begin
    WriteLn('SKIP: bwrap 不在 PATH，跳过只读根断言');
    Exit;
  end;
  LSpec := DefaultSandboxSpec;
  LArgs := BuildBwrapCommand(LSpec, '/bin/sh',
    ['-c', 'touch /code888-sandbox-write-probe >/dev/null 2>&1']);
  LOut := TCommand.New(LPath).Args(LArgs).Stdout(stPiped).Stderr(stPiped)
    .MaxOutput(4096).Spawn.WaitWithOutput;
  Check(not ProcessSucceeded(LOut), '只读根下写 / 被拒');
end;

begin
  TestDefaultSpec;
  TestIsEmptySpec;
  TestBuildDefault;
  TestBuildMounts;
  TestBuildNoRoot;
  TestBuildFlagsOff;
  TestProbe;
  TestSandboxedEcho;
  TestReadOnlyRootRejectsWrite;
  WriteLn('test_process_sandbox: ALL PASS');
end.
