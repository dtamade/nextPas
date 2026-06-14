unit nextpas.core.tls.pkcs11.engine;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 ENGINE Backend (OpenSSL 1.1.1)                        }
{                                                                              }
{  Purpose: Load PKCS#11 keys using OpenSSL 1.1.1 ENGINE API                  }
{                                                                              }
{  Architecture:                                                               }
{    - Uses ENGINE API for PKCS#11 integration                                }
{    - Loads pkcs11 engine dynamically                                        }
{    - Supports RFC 7512 pkcs11: URIs                                         }
{    - Fallback backend for OpenSSL 1.1.1                                     }
{    - Supports PIN callback via UI_METHOD                                    }
{                                                                              }
{  Requirements:                                                               }
{    - OpenSSL 1.1.1 or later (but < 3.0)                                     }
{    - pkcs11 engine (libp11)                                                 }
{    - PKCS#11 module (.so, .dll, .dylib)                                     }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses nextpas.core.tls.pkcs11.types, nextpas.core.tls.pkcs11.api, nextpas.core.tls.pkcs11.backend, nextpas.core.tls.pkcs11.uri, nextpas.core.tls.openssl.api.types, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.engine, nextpas.core.tls.openssl.api.ui, nextpas.core.text.conv; type PPKCS11PINCallbackData = ^TPKCS11PINCallbackData;
  TPKCS11PINCallbackData = record
    PIN: AnsiString;          // 预先提供的 PIN
    PINCallback: TPKCS11PINCallback;  // PIN 回调函数
    TokenLabel: string;       // 令牌标签（用于回调提示）
    PINProvided: Boolean;     // PIN 是否已预先提供
  end;

  { TEngineBackend - OpenSSL 1.1.1 ENGINE-based PKCS#11 backend }
  TEngineBackend = class(TBasePKCS11Backend)
  private
    FEngine: PENGINE;
    FEngineLoaded: Boolean;
    FUIMethod: nextpas.core.tls.openssl.api.ui.PUI_METHOD;  // 用于 PIN 回调的 UI 方法
    FCallbackData: TPKCS11PINCallbackData;

    { Load pkcs11 engine }
    procedure LoadEngine(const AModulePath: string);

    { Unload pkcs11 engine }
    procedure UnloadEngine;

    { Build ENGINE key ID from config }
    function BuildEngineKeyID(const AConfig: TPKCS11Config): string;

    { Load key using ENGINE API }
    function LoadKeyFromEngine(const AKeyID: string; const APIN: string;
      APINCallback: TPKCS11PINCallback; const ATokenLabel: string): PEVP_PKEY;

    { Create UI_METHOD for PIN callback }
    function CreatePINUIMethod: nextpas.core.tls.openssl.api.ui.PUI_METHOD;

    { Free UI_METHOD }
    procedure FreePINUIMethod;
  protected
    function FindToken(const AConfig: TPKCS11Config): CK_SLOT_ID; override;
    function FindKey(ASession: CK_SESSION_HANDLE; const AConfig: TPKCS11Config): CK_OBJECT_HANDLE; override;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IPKCS11Backend interface }
    function LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY; override;
    function LoadCertificate(const AConfig: TPKCS11Config): PX509; override;
    function IsAvailable: Boolean; override;
    function GetName: string; override;
    function GetVersion: string; override;
  end;

implementation

uses nextpas.core.tls.openssl.api.x509, nextpas.core.text.conv; var GlobalPINCallbackData: PPKCS11PINCallbackData = nil;

{ UI_METHOD 回调函数 - 处理 PIN 输入请求 }
function PKCS11_UI_reader(ui: nextpas.core.tls.openssl.api.ui.PUI;
  uis: nextpas.core.tls.openssl.api.ui.PUI_STRING): Integer; cdecl;
var
  StrType: Integer;
  CallbackPIN: string;
  MinSize, MaxSize: Integer;
begin
  Result := UI_OK;

  // 检查是否有有效的回调数据
  if GlobalPINCallbackData = nil then
  begin
    Result := UI_ERR;
    Exit;
  end;

  // 检查 UI API 是否可用
  if not Assigned(UI_get_string_type) or not Assigned(UI_set_result) then
  begin
    Result := UI_ERR;
    Exit;
  end;

  StrType := UI_get_string_type(uis);

  // 只处理提示类型的输入
  if (StrType <> UIT_PROMPT) and (StrType <> UIT_VERIFY) then
    Exit;

  // 检查 PIN 是否已预先提供
  if GlobalPINCallbackData^.PINProvided and (GlobalPINCallbackData^.PIN <> '') then
  begin
    // 使用预先提供的 PIN
    if UI_set_result(ui, uis, PAnsiChar(GlobalPINCallbackData^.PIN)) <> 0 then
      Result := UI_ERR;
    Exit;
  end;

  // 尝试使用回调函数获取 PIN
  if Assigned(GlobalPINCallbackData^.PINCallback) then
  begin
    if GlobalPINCallbackData^.PINCallback(GlobalPINCallbackData^.TokenLabel, CallbackPIN) then
    begin
      // 检查 PIN 长度限制
      if Assigned(UI_get_result_min_size) and Assigned(UI_get_result_max_size) then
      begin
        MinSize := UI_get_result_min_size(uis);
        MaxSize := UI_get_result_max_size(uis);
        if (Length(CallbackPIN) < MinSize) or (Length(CallbackPIN) > MaxSize) then
        begin
          Result := UI_ERR;
          Exit;
        end;
      end;

      // 设置回调返回的 PIN
      if UI_set_result(ui, uis, PAnsiChar(AnsiString(CallbackPIN))) <> 0 then
        Result := UI_ERR;
      Exit;
    end;
  end;

  // 如果没有预先提供 PIN 也没有回调，则失败
  Result := UI_ERR;
end;

{ UI_METHOD 回调函数 - 输出提示信息 }
function PKCS11_UI_writer(ui: nextpas.core.tls.openssl.api.ui.PUI;
  uis: nextpas.core.tls.openssl.api.ui.PUI_STRING): Integer; cdecl;
var
  StrType: Integer;
begin
  Result := UI_OK;

  if not Assigned(UI_get_string_type) then
  begin
    Result := UI_ERR;
    Exit;
  end;

  StrType := UI_get_string_type(uis);

  // 对于 PKCS#11，我们通常静默处理，不显示提示
  // 除非需要调试
  case StrType of
    UIT_INFO, UIT_ERROR:
    begin
      // 可以在这里记录日志
      // if Assigned(UI_get0_output_string) then
      //   WriteLn('PKCS#11: ', string(UI_get0_output_string(uis)));
    end;
  end;
end;

{ TEngineBackend }

constructor TEngineBackend.Create;
begin
  inherited Create;
  FEngine := nil;
  FEngineLoaded := False;
  FUIMethod := nil;
  FillChar(FCallbackData, SizeOf(FCallbackData), 0);
end;

destructor TEngineBackend.Destroy;
begin
  FreePINUIMethod;
  UnloadEngine;
  inherited Destroy;
end;

function TEngineBackend.CreatePINUIMethod: nextpas.core.tls.openssl.api.ui.PUI_METHOD;
begin
  Result := nil;

  // 检查 UI API 是否可用
  if not Assigned(UI_METHOD_new) then
    Exit;

  Result := UI_METHOD_new();
  if Result = nil then
    Exit;

  // 设置读取器回调（用于获取 PIN）
  if Assigned(UI_METHOD_set_reader) then
    UI_METHOD_set_reader(Result, @PKCS11_UI_reader);

  // 设置写入器回调（用于显示提示）
  if Assigned(UI_METHOD_set_writer) then
    UI_METHOD_set_writer(Result, @PKCS11_UI_writer);
end;

procedure TEngineBackend.FreePINUIMethod;
begin
  if FUIMethod <> nil then
  begin
    if Assigned(UI_METHOD_free) then
      UI_METHOD_free(FUIMethod);
    FUIMethod := nil;
  end;
end;

procedure TEngineBackend.LoadEngine(const AModulePath: string);
var
  EngineID: AnsiString;
begin
  if FEngineLoaded then
    Exit;

  // Load dynamic engine
  EngineID := 'pkcs11';
  FEngine := ENGINE_by_id(PAnsiChar(EngineID));

  if FEngine = nil then
  begin
    // Try to load dynamic engine
    FEngine := ENGINE_by_id('dynamic');
    if FEngine = nil then
      raise EPKCS11Exception.Create(
        'Failed to load dynamic ENGINE',
        CKR_GENERAL_ERROR);

    // Set engine parameters
    if ENGINE_ctrl_cmd_string(FEngine, 'SO_PATH', PAnsiChar(AnsiString('/usr/lib/engines-1.1/pkcs11.so')), 0) = 0 then
      raise EPKCS11Exception.Create(
        'Failed to set ENGINE SO_PATH',
        CKR_GENERAL_ERROR);

    if ENGINE_ctrl_cmd_string(FEngine, 'ID', PAnsiChar(EngineID), 0) = 0 then
      raise EPKCS11Exception.Create(
        'Failed to set ENGINE ID',
        CKR_GENERAL_ERROR);

    if ENGINE_ctrl_cmd_string(FEngine, 'LOAD', nil, 0) = 0 then
      raise EPKCS11Exception.Create(
        'Failed to LOAD ENGINE',
        CKR_GENERAL_ERROR);
  end;

  // Set PKCS#11 module path
  if ENGINE_ctrl_cmd_string(FEngine, 'MODULE_PATH', PAnsiChar(AnsiString(AModulePath)), 0) = 0 then
    raise EPKCS11Exception.Create(
      'Failed to set ENGINE MODULE_PATH: ' + AModulePath,
      CKR_GENERAL_ERROR);

  // Initialize engine
  if ENGINE_init(FEngine) = 0 then
  begin
    ENGINE_free(FEngine);
    FEngine := nil;
    raise EPKCS11Exception.Create(
      'Failed to initialize ENGINE',
      CKR_GENERAL_ERROR);
  end;

  FEngineLoaded := True;
end;

procedure TEngineBackend.UnloadEngine;
begin
  if FEngineLoaded and (FEngine <> nil) then
  begin
    ENGINE_finish(FEngine);
    ENGINE_free(FEngine);
    FEngine := nil;
    FEngineLoaded := False;
  end;
end;

function TEngineBackend.BuildEngineKeyID(const AConfig: TPKCS11Config): string;
var
  URI: TPKCS11URI;
begin
  // Build RFC 7512 URI from config
  // ENGINE expects URI format for key identification
  FillChar(URI, SizeOf(URI), 0);

  URI.Token := AConfig.TokenLabel;
  URI.ObjectLabel := AConfig.KeyLabel;

  if AConfig.SlotID >= 0 then
    URI.SlotID := IntToStr(AConfig.SlotID);

  // Don't include module path in URI (already set in ENGINE)
  // Don't include PIN in URI (will be provided separately via UI callback)

  Result := TPKCS11URIParser.Generate(URI);
end;

function TEngineBackend.LoadKeyFromEngine(const AKeyID: string; const APIN: string;
  APINCallback: TPKCS11PINCallback; const ATokenLabel: string): PEVP_PKEY;
var
  KeyIDAnsi: AnsiString;
  PINAnsi: AnsiString;
  UIMethod: nextpas.core.tls.openssl.api.ui.PUI_METHOD;
begin
  Result := nil;

  KeyIDAnsi := AnsiString(AKeyID);

  // 如果已提供 PIN，首先尝试通过 ENGINE 控制命令设置
  if APIN <> '' then
  begin
    PINAnsi := AnsiString(APIN);
    // Set PIN via ENGINE control command
    if ENGINE_ctrl_cmd_string(FEngine, 'PIN', PAnsiChar(PINAnsi), 0) = 0 then
      raise EPKCS11Exception.Create(
        'Failed to set ENGINE PIN',
        CKR_PIN_INCORRECT);
  end;

  // 创建或使用现有的 UI 方法
  if FUIMethod = nil then
    FUIMethod := CreatePINUIMethod;

  UIMethod := nextpas.core.tls.openssl.api.ui.PUI_METHOD(FUIMethod);

  // 设置回调数据
  FCallbackData.PIN := AnsiString(APIN);
  FCallbackData.PINCallback := APINCallback;
  FCallbackData.TokenLabel := ATokenLabel;
  FCallbackData.PINProvided := (APIN <> '');

  // 设置全局回调数据指针（用于 cdecl 回调）
  GlobalPINCallbackData := @FCallbackData;
  try
    // Load private key from engine with UI method for PIN callback
    Result := ENGINE_load_private_key(FEngine, PAnsiChar(KeyIDAnsi),
      nextpas.core.tls.openssl.api.engine.PUI_METHOD(UIMethod), @FCallbackData);

    if Result = nil then
      raise EPKCS11Exception.Create(
        'Failed to load private key from ENGINE with ID: ' + AKeyID,
        CKR_KEY_HANDLE_INVALID);
  finally
    GlobalPINCallbackData := nil;
  end;
end;

function TEngineBackend.FindToken(const AConfig: TPKCS11Config): CK_SLOT_ID;
begin
  // Not used in ENGINE backend (ENGINE handles token selection)
  Result := 0;
end;

function TEngineBackend.FindKey(ASession: CK_SESSION_HANDLE; const AConfig: TPKCS11Config): CK_OBJECT_HANDLE;
begin
  // Not used in ENGINE backend (ENGINE handles key selection)
  Result := 0;
end;

function TEngineBackend.LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY;
var
  KeyID: string;
  PIN: string;
begin
  // Validate configuration
  ValidateConfig(AConfig);

  // Load engine if not already loaded
  LoadEngine(AConfig.ModulePath);

  // Resolve PIN
  PIN := ResolvePIN(AConfig);

  // Build ENGINE key ID
  KeyID := BuildEngineKeyID(AConfig);

  // Load key from engine with PIN callback support
  Result := LoadKeyFromEngine(KeyID, PIN, AConfig.PINCallback, AConfig.TokenLabel);
end;

function TEngineBackend.LoadCertificate(const AConfig: TPKCS11Config): PX509;
begin
  Result := nil;

  // Validate configuration first so caller still gets deterministic input errors.
  ValidateConfig(AConfig);

  // ENGINE backend does not provide a portable certificate retrieval API.
  // Keep this path explicit to avoid ambiguous runtime failures/access violations.
  raise EPKCS11Exception.Create(
    'Certificate loading is unsupported by ENGINE backend; use provider backend for certificate retrieval',
    CKR_FUNCTION_NOT_SUPPORTED);
end;

function TEngineBackend.IsAvailable: Boolean;
begin
  // Check if OpenSSL 1.1.1 ENGINE API is available
  Result := Assigned(ENGINE_by_id) and
            Assigned(ENGINE_init) and
            Assigned(ENGINE_finish) and
            Assigned(ENGINE_free) and
            Assigned(ENGINE_ctrl_cmd_string) and
            Assigned(ENGINE_load_private_key) and
            Assigned(ENGINE_load_public_key);
end;

function TEngineBackend.GetName: string;
begin
  Result := 'ENGINE (OpenSSL 1.1.1)';
end;

function TEngineBackend.GetVersion: string;
begin
  Result := '1.1.1+';
end;

end.
