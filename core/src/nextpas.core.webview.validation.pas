unit nextpas.core.webview.validation;

{** @desc webview 家族校验实现（base 纯度收敛）：
       base 仅承载纯数据类型（record/enum/const/error 族 + Default 无重依赖
       载体），本单元承载 IsValidWebviewSchemeToken + 所有 Check* 不变量校验
       实现；四件套 base←intf←impl←facade 纯度恢复，依赖 L1 text.char
       表驱动 IsLower/IsDigit + L1 text.view.TStringView.Trim 单源
       零拷贝 view + L2 validation.URL 单源校验 DevServerUrl；L3→L1/L2 复用允许；
       bytes.ops 生长/快照仍由 live 单源承载，本单元不重复；稳定性资源释放
       不丢（无堆资源，仅抛异常）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base;

{ scheme token 校验：纯谓词，规则非空且全小写 [a-z][a-z0-9+.-]*，空串返回
  False（由 CheckWebviewOptions 视为用默认）；单源复用 L1 text.char 表驱动
  IsLower/IsDigit 零拷贝，零重复分支；剩余 '+','-','.' 为符号单点；
  perf: 表驱动 CharClassTable 零分支 + 零拷贝 Byte 视图（无 string 分配），
  含扫描循环依 design-conventions 红线二去 inline 避免 I-Cache 膨胀，无堆资源、释放不丢。 }
function IsValidWebviewSchemeToken(const AScheme: string): Boolean;

{ 选项校验：违反不变量抛 EWebviewInvalidState。
  规则：
  - EphemeralSession 与 DataDirectory 互斥（CONTRACT §2.2）
  - 尺寸字段一律 >= 0（负值非法；<=0 的 Width/Height 表示引擎默认）
  - MaxWidth/MaxHeight 与 MinWidth/MinHeight 同时为正时必须满足 max >= min
  - SchemeName 允许为空串（由后端落 DEFAULT_WEBVIEW_SCHEME），
    非空时必须是合法 scheme token：[a-z][a-z0-9+.-]* 且全小写 }
procedure CheckWebviewOptions(const AOptions: TWebviewOptions);

{ invoke 命名空间校验（registry 注册与桥分发共用同一权威规则）：
  ACmd 为空、或以 'npw.'（协议错误码词汇前缀）或 '_' 开头时抛
  EWebviewInvalidState，其余一律接受（CONTRACT §3.3）。 }
procedure CheckInvokeCmd(const ACmd: string); inline;

{ 几何校验公共抽取（S39）：builder 链式早期 Fail-Fast 与 CheckWebviewOptions 同源复用，零重复。 }
procedure CheckWebviewSize(AWidth, AHeight: Integer); inline;
procedure CheckWebviewMinSize(AMinWidth, AMinHeight: Integer; AMaxWidth, AMaxHeight: Integer); inline;
procedure CheckWebviewMaxSize(AMaxWidth, AMaxHeight: Integer; AMinWidth, AMinHeight: Integer); inline;

{ 会话互斥校验（S40）：EphemeralSession 与 DataDirectory 互斥，builder 早期 Fail-Fast 与 CheckWebviewOptions 同源，零重复。 }
procedure CheckWebviewSession(AEphemeral: Boolean; const ADataDirectory: string); inline;

{ 注入脚本命名空间守卫（S40）：单条脚本不得触 __npw，builder 与 CheckWebviewOptions 同源，零重复。 }
procedure CheckWebviewInitScript(const AScript: string); inline;
procedure CheckWebviewEventName(const AEvent: string); inline;
{ 开发模式 URL 校验（S95）：非空时必须是 http/https 绝对 URL，与 CheckWebviewOptions 同源复用。
  perf: out-of-line 零 I-Cache 膨胀（真实循环体禁 inline 红线二）+ TStringView 零拷贝 view 零分配快路径单源复用 + L2 validation.URL 单源 http(s) 语义。 }
procedure CheckWebviewDevServerUrl(const AUrl: string);

implementation

uses
  nextpas.core.text.char,
  nextpas.core.text.view,
  nextpas.core.validation;

function IsValidWebviewSchemeToken(const AScheme: string): Boolean;
var
  I: Integer;
  B: Byte;
begin
  // perf: 表驱动 CharClassTable 零分支 + 零拷贝 Byte 视图（无 string 分配），单源 text.char IsLower/IsDigit，无手写区间漂移，零重复分支；去 inline（真实循环体禁 inline 红线二）
  Result := False;
  if AScheme = '' then
    Exit;
  if not IsLower(Byte(AScheme[1])) then
    Exit;
  for I := 1 to Length(AScheme) do
  begin
    B := Byte(AScheme[I]);
    if IsLower(B) or IsDigit(B) or (B = Byte('+')) or (B = Byte('.')) or (B = Byte('-')) then
      Continue
    else
      Exit;
  end;
  Result := True;
end;

procedure CheckWebviewSize(AWidth, AHeight: Integer); inline;
begin
  if (AWidth < 0) or (AHeight < 0) then
    raise EWebviewInvalidState.Create('Width/Height must be >= 0');
end;

procedure CheckWebviewMinSize(AMinWidth, AMinHeight: Integer; AMaxWidth, AMaxHeight: Integer); inline;
begin
  if (AMinWidth < 0) or (AMinHeight < 0) then
    raise EWebviewInvalidState.Create('MinWidth/MinHeight must be >= 0');
  if (AMinWidth > 0) and (AMaxWidth > 0) and (AMinWidth > AMaxWidth) then
    raise EWebviewInvalidState.Create('MaxWidth must be >= MinWidth');
  if (AMinHeight > 0) and (AMaxHeight > 0) and (AMinHeight > AMaxHeight) then
    raise EWebviewInvalidState.Create('MaxHeight must be >= MinHeight');
end;

procedure CheckWebviewMaxSize(AMaxWidth, AMaxHeight: Integer; AMinWidth, AMinHeight: Integer); inline;
begin
  if (AMaxWidth < 0) or (AMaxHeight < 0) then
    raise EWebviewInvalidState.Create('MaxWidth/MaxHeight must be >= 0');
  if (AMinWidth > 0) and (AMaxWidth > 0) and (AMaxWidth < AMinWidth) then
    raise EWebviewInvalidState.Create('MaxWidth must be >= MinWidth');
  if (AMinHeight > 0) and (AMaxHeight > 0) and (AMaxHeight < AMinHeight) then
    raise EWebviewInvalidState.Create('MaxHeight must be >= MinHeight');
end;

procedure CheckWebviewSession(AEphemeral: Boolean; const ADataDirectory: string); inline;
begin
  if AEphemeral and (ADataDirectory <> '') then
    raise EWebviewInvalidState.Create(
      'EphemeralSession and DataDirectory are mutually exclusive');
end;

procedure CheckWebviewInitScript(const AScript: string); inline;
begin
  if Pos('__npw', AScript) > 0 then
    raise EWebviewInvalidState.Create(
      'InitScripts must not touch __npw (bridge owns that namespace)');
end;

procedure CheckWebviewEventName(const AEvent: string); inline;
begin
  if AEvent = '' then
    raise EWebviewInvalidState.Create('webview event name must not be empty');
end;

procedure CheckWebviewDevServerUrl(const AUrl: string);
var
  LView: TStringView;
  LTrimmed: string;
begin
  // perf: out-of-line（真实循环体禁 inline 红线二零 I-Cache 膨胀）+ TStringView zero-copy view (L1 text.view single source, VecWidth SIMD scan, zero alloc fast path) + validation.URL L2 single source http(s) scheme, single allocation only when trimmed
  LView := TStringView.FromStr(AUrl).Trim;
  if LView.IsEmpty then Exit;
  if LView.Contains(' ') then
    raise EWebviewInvalidState.CreateFmt('DevServerUrl "%s" must be an http(s) URL', [AUrl]);
  if LView.Len = SizeUInt(Length(AUrl)) then
    LTrimmed := AUrl
  else
    LTrimmed := LView.ToString; // single SetString+Move when trimmed, zero extra copy
  // reuse L2 validation owner single source for http(s) URL semantics (http:// / https:// + non-empty rest), avoids Pos/Copy hand prefix drift, keeps net/uri owner single source
  if not TValidator.Create('DevServerUrl').URL(LTrimmed).IsValid then
    raise EWebviewInvalidState.CreateFmt('DevServerUrl "%s" must be an http(s) URL', [AUrl]);
end;

procedure CheckWebviewOptions(const AOptions: TWebviewOptions);
var
  LIdx: Integer;
  LToken: string;
begin
  CheckWebviewSession(AOptions.EphemeralSession, AOptions.DataDirectory);

  CheckWebviewSize(AOptions.Width, AOptions.Height);
  CheckWebviewMinSize(AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight);
  CheckWebviewMaxSize(AOptions.MaxWidth, AOptions.MaxHeight, AOptions.MinWidth, AOptions.MinHeight);

  if AOptions.SchemeName <> '' then
  begin
    LToken := AOptions.SchemeName;
    if not IsValidWebviewSchemeToken(LToken) then
      raise EWebviewInvalidState.CreateFmt(
        'SchemeName "%s" is not a valid lowercase scheme token', [LToken]);
  end;

  for LIdx := 0 to High(AOptions.InitScripts) do
    CheckWebviewInitScript(AOptions.InitScripts[LIdx]);

  CheckWebviewDevServerUrl(AOptions.DevServerUrl);
end;

procedure CheckInvokeCmd(const ACmd: string); inline;
begin
  if ACmd = '' then
    raise EWebviewInvalidState.Create('invoke cmd must not be empty');
  // perf: inline + TStringView zero-copy view (L1 text.view single source, VecWidth SIMD, zero alloc) 代替 Copy 临时串分配，高频注册路径零拷贝
  if (TStringView.FromStr(ACmd).StartsWith(TStringView.FromStr('npw.'))) or (ACmd[1] = '_') then
    raise EWebviewInvalidState.CreateFmt(
      'invoke cmd "%s" collides with the protocol namespace', [ACmd]);
end;

end.
