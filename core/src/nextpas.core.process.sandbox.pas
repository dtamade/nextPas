unit nextpas.core.process.sandbox;

{**
 * @desc 沙箱门面：把任意命令包装进 bubblewrap（bwrap）OS 隔离。
 *
 *   - TSandboxSpec 为纯数据规格，无 IO（对照 permission Profile「只加数据」纪律）；
 *   - BuildBwrapCommand 为无 IO 纯字符串组装，spawn/超时/输出上限复用 ICommand
 *     （bwrap 本身作为 APath 交给 TCommand.New(bwrap).Args(Result)）；
 *   - BwrapAvailable/BwrapVersion 为能力探测，供调用方 fail-closed
 *     （不可用即拒绝沙箱档位请求，不做静默降级直跑）。
 *
 * @note 对照 codex（linux-sandbox/bwrap.rs：--unshare-user/--unshare-pid/--dev /dev/
 *       mount 顺序「可写在前、只读覆盖在后」）与 grok-build（bwrap_reexec_for_profile：
 *       构造命令交 spawn + 可用性探测）。否决 grok 探测失败落 off 的 fail-open。
 * @note Proc 默认 False：规避嵌套容器 mount proc 失败主因（codex run_bwrap_with_proc_fallback）。
 * @note 平台：仅 Linux（bwrap 依赖 user namespace）；Windows/macOS BwrapAvailable=False，
 *       调用方 fail-closed。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.process.base;

type
  {**
   * TSandboxSpec
   *
   * @desc 沙箱规格：纯数据，无 IO。消费方是 BuildBwrapCommand。
   *
   * @note Pascal record 无字段默认值——初始化必须走 DefaultSandboxSpec，
   *       再按需覆盖字段（安全默认：只读根 + 禁网 + 私有 /tmp + 最小 /dev）。
   * @note RoBinds/Writable 条目格式：'宿主路径[=沙箱路径]'；缺省 dst=src。
   *}
  TSandboxSpec = record
    RoBinds: TStringArray;   { 只读挂载（同名路径下覆盖可写挂载） }
    Writable: TStringArray;  { 可写挂载（通常仅 workspace 逻辑根） }
    DevNull: Boolean;        { 默认 True：挂最小可写 /dev（/dev/null、/dev/urandom） }
    Proc: Boolean;           { 默认 False：挂 /proc（off 规避嵌套容器 mount proc 失败主因） }
    TempTmp: Boolean;        { 默认 True：私有可写 /tmp }
    Network: Boolean;        { 默认 False：--unshare-net 禁网 }
    ReadOnlyRoot: Boolean;   { 默认 True：--ro-bind / /；False 时退为 --tmpfs /（仅挂声明的路径） }
  end;

  {** bwrap 沙箱能力不可用（BwrapAvailable=False）时由调用方抛出的错误；fail-closed 语义 *}
  ESandboxError = class(EProcessError);

{** 带安全默认值的沙箱规格（record 无字段默认值，初始化入口） *}
function DefaultSandboxSpec: TSandboxSpec;
{** 规格是否无需包装（无挂载且所有布尔为「不隔离」零值）→ 调用方跳过包装 *}
function IsEmptySandboxSpec(const ASpec: TSandboxSpec): Boolean;
{** 把 APath/AArgs 包装为 bwrap argv（不含 bwrap 自身；无 IO 纯组装） *}
function BuildBwrapCommand(const ASpec: TSandboxSpec; const APath: string;
  const AArgs: array of string): TStringArray;
{** 沙箱能力探测：bwrap 二进制存在 + 最小命名空间/mount 冒烟通过 *}
function BwrapAvailable: Boolean;
{** bwrap 版本字符串（如 'bubblewrap 0.11.0'；不可用返回 ''） *}
function BwrapVersion: string;

implementation

uses
  nextpas.core.process,        { TryLookPath / ProcessSucceeded / stPiped }
  nextpas.core.process.command; { TCommand }

function DefaultSandboxSpec: TSandboxSpec;
begin
  Result.RoBinds := nil;
  Result.Writable := nil;
  Result.DevNull := True;
  Result.Proc := False;
  Result.TempTmp := True;
  Result.Network := False;
  Result.ReadOnlyRoot := True;
end;

function IsEmptySandboxSpec(const ASpec: TSandboxSpec): Boolean;
begin
  { 空 = 全字段零值（record 未配置/Default 初始化）→ 调用方跳过包装。
    注意 Network 零值=False（禁网）也算空：record 零值即「未配置」，
    不应因零值禁网把未配置规格误判为需要包装。 }
  Result := (Length(ASpec.RoBinds) = 0) and (Length(ASpec.Writable) = 0)
    and (not ASpec.DevNull) and (not ASpec.Proc)
    and (not ASpec.TempTmp) and (not ASpec.Network) and (not ASpec.ReadOnlyRoot);
end;

{ 找 '=' 分隔符位置（'src[=dst]' 挂载条目）；无 '=' 返回 0 }
function FindEq(const AStr: string): SizeInt;
var
  I: SizeInt;
begin
  for I := 1 to Length(AStr) do
    if AStr[I] = '=' then
      Exit(I);
  Result := 0;
end;

function TrimStr(const AStr: string): string;
var
  L, R: SizeInt;
begin
  L := 1;
  R := Length(AStr);
  while (L <= R) and (AStr[L] <= ' ') do
    Inc(L);
  while (R >= L) and (AStr[R] <= ' ') do
    Dec(R);
  Result := Copy(AStr, L, R - L + 1);
end;

function BuildBwrapCommand(const ASpec: TSandboxSpec; const APath: string;
  const AArgs: array of string): TStringArray;
var
  LSep: SizeInt;
  LSrc, LDst: string;
  LEntry: string;

  procedure Add(const AValue: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AValue;
  end;

  procedure AddMountPair(const AFlag: string; const APair: string);
  begin
    LSep := FindEq(APair);
    if LSep > 0 then
    begin
      LSrc := Copy(APair, 1, LSep - 1);
      LDst := Copy(APair, LSep + 1, Length(APair) - LSep);
    end
    else
    begin
      LSrc := APair;
      LDst := APair;
    end;
    Add(AFlag);
    Add(LSrc);
    Add(LDst);
  end;

begin
  Result := nil;
  { 根基线：只读整根；或空 tmpfs 根、仅挂声明的路径（对照 codex 受限策略） }
  if ASpec.ReadOnlyRoot then
  begin
    Add('--ro-bind');
    Add('/');
    Add('/');
  end
  else
  begin
    Add('--tmpfs');
    Add('/');
  end;
  if ASpec.DevNull then
  begin
    Add('--dev');
    Add('/dev');
  end;
  if ASpec.TempTmp then
  begin
    Add('--tmpfs');
    Add('/tmp');
  end;
  if not ASpec.Network then
    Add('--unshare-net');
  if ASpec.Proc then
  begin
    Add('--proc');
    Add('/proc');
  end;
  { 可写挂载在前、只读覆盖在后：同名路径下只读子集胜出（codex mount 顺序第 4/5 条） }
  for LEntry in ASpec.Writable do
    AddMountPair('--bind', LEntry);
  for LEntry in ASpec.RoBinds do
    AddMountPair('--ro-bind', LEntry);
  Add('--');
  Add(APath);
  for LEntry in AArgs do
    Add(LEntry);
end;

function BwrapAvailable: Boolean;
var
  LPath: string;
  LOut: TProcessOutput;
begin
  if not TryLookPath('bwrap', LPath) then
    Exit(False);
  { 最小冒烟：user+pid namespace + 只读根挂载 + 真命令。
    失败即判定不可用（嵌套容器/无 userns 权限），调用方 fail-closed。 }
  LOut := TCommand.New(LPath)
    .Args(['--unshare-user', '--unshare-pid', '--ro-bind', '/', '/', '--', '/bin/true'])
    .Stdout(stPiped).Stderr(stNull).MaxOutput(4096)
    .Spawn.WaitWithOutput;
  Result := ProcessSucceeded(LOut);
end;

function BwrapVersion: string;
var
  LPath: string;
  LOut: TProcessOutput;
begin
  if not TryLookPath('bwrap', LPath) then
    Exit('');
  LOut := TCommand.New(LPath)
    .Args(['--version'])
    .Stdout(stPiped).Stderr(stNull).MaxOutput(4096)
    .Spawn.WaitWithOutput;
  if not ProcessSucceeded(LOut) then
    Exit('');
  Result := TrimStr(LOut.StdOut);
end;

end.
