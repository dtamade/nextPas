unit nextpas.core.webview.base;

{** @desc nextpas.core.webview L3 家族：公共类型根（纯数据类型边界）。
       后端种类、窗口选项、事件 record、原生句柄别名与错误族。
       仅依赖 L0 errors owner；工具能力（容量生长/路径归一/哈希）由各 owner 单源承载，
       base 不承载校验实现职责（四件套纯度 base←intf←impl←facade；校验见
       nextpas.core.webview.validation 实现层，复用 L1 text.view + L2
       validation 单源 inline 零拷贝）；禁止 uses 本家族任何后端/bridge/factory
       单元（INV-4，source-contract 门禁冻结）。

       错误类目定值表（逐类测试冻结，见 test_webview_base）：
       - EWebviewBackendUnavailable = ecNotFound   （引擎库探测不到）
       - EWebviewEvalFailed         = ecIO        （引擎侧执行失败）
       - EWebviewBadFrame           = ecParse     （帧解析失败；生产路径静默忽略，
                                                    本类供 fake 驱动面校验测试入参）
       - 其余（NotInitialized/InvalidState/Closed/Timeout/InvokeError）= ecInternal *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

const
  { 桥协议版本常量：base 持有一份，bridge 为唯一权威实现（S2 落地时
    bridge 复用此处常量，避免双处定义漂移）。 }
  NPW_BRIDGE_VERSION = 1;

  { 默认资源 scheme 名 }
  DEFAULT_WEBVIEW_SCHEME = 'npres';

  { 资产 404 语义单源：GError code/message 与 TryResolve 404 统一，
    复用 http.mime 回退同源思想，消除各处硬编码 404/'resource not found' 漂移 }
  WEBVIEW_ASSET_NOT_FOUND_CODE = 404;
  WEBVIEW_ASSET_NOT_FOUND_MSG = 'resource not found';

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

{ scheme token 校验：纯谓词无重依赖，保留在 base 供 validation 复用；
  规则：非空且全小写 [a-z][a-z0-9+.-]*，空串返回 False（由 CheckWebviewOptions 视为用默认）。 }
function IsValidWebviewSchemeToken(const AScheme: string): Boolean;

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

function IsValidWebviewSchemeToken(const AScheme: string): Boolean;
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
