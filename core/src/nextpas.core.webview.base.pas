unit nextpas.core.webview.base;

{** @desc nextpas.core.webview L3 家族：公共类型根。
       后端种类、窗口选项、事件 record、原生句柄别名与错误族。
       只依赖 errors owner；禁止 uses 本家族任何后端/bridge/factory 单元
       （INV-4，source-contract 门禁冻结）。

       错误类目定值表（逐类测试冻结，见 test_webview_base）：
       - EWebviewBackendUnavailable = ecNotFound   （引擎库探测不到）
       - EWebviewEvalFailed         = ecIO        （引擎侧执行失败）
       - EWebviewBadFrame           = ecParse     （帧解析失败；生产路径静默忽略，
                                                    本类供 fake 驱动面校验测试入参）
       - 其余（NotInitialized/InvalidState/Closed/Timeout/InvokeError）= ecInternal *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  { 桥协议版本常量：base 持有一份，bridge 为唯一权威实现（S2 落地时
    bridge 复用此处常量，避免双处定义漂移）。 }
  NPW_BRIDGE_VERSION = 1;

  { 默认资源 scheme 名 }
  DEFAULT_WEBVIEW_SCHEME = 'npres';

type
  { 后端种类。wvGtk=Wave 1 Linux；wvWebview2=Wave 2 Windows；
    wvWk=Wave 3 macOS；wvFake=无头测试后端（全平台）。 }
  TWebviewKind = (wvGtk, wvWebview2, wvWk, wvFake);

  { 平台原生窗口句柄（X11 下为 XID，Wayland 为 nil——诚实差异见
    BACKENDS.md §8）。仅供嵌入场景，本家族不解释其内容。 }
  TWebviewNativeHandle = type Pointer;

  { 追加注入脚本列表（document-start、主帧 only；顺序=数组序）。
    自有别名避免对 TArray<T> 可用性的宿主差异。 }
  TWebviewInitScripts = array of string;

  {** 窗口选项。语义诚实表见 docs/webview/CONTRACT.md §2.2。 *}
  TWebviewOptions = record
    Title: string;             // 默认 ''
    Width: Integer;            // 默认 1024；<=0 时用引擎默认
    Height: Integer;           // 默认 768
    MinWidth: Integer;         // 0 = 不设限制
    MinHeight: Integer;
    MaxWidth: Integer;         // 0 = 不设限制
    MaxHeight: Integer;
    Resizable: Boolean;        // 默认 True
    Maximized: Boolean;        // 默认 False；启动即最大化
    DebugTools: Boolean;       // 默认 False；True 打开 inspector/devtools
    SchemeName: string;        // 默认 'npres'；资源 scheme 名
    InitialHtml: string;       // 非空则启动加载该 HTML（优先级低于 InitialUrl）
    InitialUrl: string;        // 非空则启动导航；DevServerUrl 存在时通常填它
    DevServerUrl: string;      // 非空 = 开发模式：资源服务整体让位给该 http 地址
    DataDirectory: string;     // ''= 引擎默认持久化位置；非空= 自定义 profile 目录
    EphemeralSession: Boolean; // 默认 False；True= 内存会话（与 DataDirectory 互斥）
    InitScripts: TWebviewInitScripts; // 追加注入脚本；不得调用 __npw（桥外层）
  end;

  {** 导航事件。Failed 事件使用 IsError/ErrorCode/ErrorMessage 三字段。 *}
  TWebviewNavigationEvent = record
    Url: string;          // UTF-8 绝对地址
    IsError: Boolean;     // Failed 事件专用
    ErrorCode: Integer;   // 引擎原生码；未知为 0
    ErrorMessage: string; // 引擎原文或 ''
  end;

{ 默认选项：字段缺省值唯一权威（CONTRACT §2.2） }
function DefaultWebviewOptions: TWebviewOptions;

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

{ scheme token 校验：复用度 — builder 早期 Fail-Fast 与 CheckWebviewOptions 共用同一权威。
  规则：非空且全小写 [a-z][a-z0-9+.-]*，空串返回 False（由 CheckWebviewOptions 视为用默认）。 }
function IsValidWebviewSchemeToken(const AScheme: string): Boolean; inline;

{ 几何校验公共抽取（S39）：builder 链式早期 Fail-Fast 与 CheckWebviewOptions 同源复用，零重复。 }
procedure CheckWebviewSize(AWidth, AHeight: Integer); inline;
procedure CheckWebviewMinSize(AMinWidth, AMinHeight: Integer; AMaxWidth, AMaxHeight: Integer); inline;
procedure CheckWebviewMaxSize(AMaxWidth, AMaxHeight: Integer; AMinWidth, AMinHeight: Integer); inline;

{ 会话互斥校验（S40）：EphemeralSession 与 DataDirectory 互斥，builder 早期 Fail-Fast 与 CheckWebviewOptions 同源，零重复。 }
procedure CheckWebviewSession(AEphemeral: Boolean; const ADataDirectory: string); inline;

{ 注入脚本命名空间守卫（S40）：单条脚本不得触 __npw，builder 与 CheckWebviewOptions 同源，零重复。 }
procedure CheckWebviewInitScript(const AScript: string); inline;
procedure CheckWebviewEventName(const AEvent: string); inline;
function WebviewGrowCapacity(ACurrent: Integer): Integer; inline;

{ 资产路径归一：剥离前导 '/'，空串保持空（S52 复用抽取，bridge TryResolve 与 gtk scheme 回调同源，零重复 Delete 扫描）。 }
function NormalizeWebviewAssetPath(const APath: string): string; inline;

{ EWebviewError 族 —— 派生自框架根异常，类目定值见单元头注释表 }
type
  EWebviewError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewBackendUnavailable = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewNotInitialized = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewInvalidState = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewClosed = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewEvalFailed = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewTimeout = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWebviewBadFrame = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  { handler 内抛出的业务错误包装；Code 走 BRIDGE_PROTOCOL §5 稳定词汇表
    （自定义业务码须以 app. 开头；空 Code 由桥补 npw.bad_request）。 }
  EWebviewInvokeError = class(EWebviewError)
  private
    FCode: string;
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string; const ACode: string); overload;
    constructor CreateFmt(const AMessage: string; const ACode: string;
      const AArgs: array of const); overload;
    property Code: string read FCode;
  end;

implementation

function DefaultWebviewOptions: TWebviewOptions;
begin
  Result.Title := '';
  Result.Width := 1024;
  Result.Height := 768;
  Result.MinWidth := 0;
  Result.MinHeight := 0;
  Result.MaxWidth := 0;
  Result.MaxHeight := 0;
  Result.Resizable := True;
  Result.Maximized := False;
  Result.DebugTools := False;
  Result.SchemeName := DEFAULT_WEBVIEW_SCHEME;
  Result.InitialHtml := '';
  Result.InitialUrl := '';
  Result.DevServerUrl := '';
  Result.DataDirectory := '';
  Result.EphemeralSession := False;
  Result.InitScripts := nil;
end;

function IsValidWebviewSchemeToken(const AScheme: string): Boolean; inline;
var
  I: Integer;
begin
  Result := False;
  if AScheme = '' then
    Exit;
  if not ((AScheme[1] >= 'a') and (AScheme[1] <= 'z')) then
    Exit;
  for I := 1 to Length(AScheme) do
  begin
    case AScheme[I] of
      'a'..'z', '0'..'9', '+', '.', '-': ;
    else
      Exit;
    end;
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

function NormalizeWebviewAssetPath(const APath: string): string; inline;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(APath)) and (APath[I] = '/') do
    Inc(I);
  if I > 1 then
    Result := Copy(APath, I, MaxInt)
  else
    Result := APath;
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

function WebviewGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  if ACurrent = 0 then
    Result := 4
  else
    Result := ACurrent * 2;
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
end;

procedure CheckInvokeCmd(const ACmd: string); inline;
begin
  if ACmd = '' then
    raise EWebviewInvalidState.Create('invoke cmd must not be empty');
  if (Copy(ACmd, 1, 4) = 'npw.') or (ACmd[1] = '_') then
    raise EWebviewInvalidState.CreateFmt(
      'invoke cmd "%s" collides with the protocol namespace', [ACmd]);
end;

{ EWebviewError 族 }

class function EWebviewError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWebviewBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EWebviewNotInitialized.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWebviewInvalidState.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWebviewClosed.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWebviewEvalFailed.DefaultCategory: TErrorCategory;
begin
  Result := ecIO;
end;

class function EWebviewTimeout.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWebviewBadFrame.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;

constructor EWebviewInvokeError.Create(const AMessage: string;
  const ACode: string);
begin
  inherited Create(AMessage);
  FCode := ACode;
end;

constructor EWebviewInvokeError.CreateFmt(const AMessage: string;
  const ACode: string; const AArgs: array of const);
begin
  inherited CreateFmt(AMessage, AArgs);
  FCode := ACode;
end;

class function EWebviewInvokeError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
