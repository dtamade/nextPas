unit nextpas.core.tls.winssl.enterprise;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.exception, nextpas.core.text.conv, Windows, Registry,
  nextpas.core.tls.logging,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api;

type
  { 企业配置类 - 集成 Windows 企业功能 }
  TSSLEnterpriseConfig = class
  private
    FFIPSEnabled: Boolean;
    FPolicyLoaded: Boolean;
    FTrustedRoots: TStringArray;
    FGroupPolicies: TStringArray;
    
    function DetectFIPSMode: Boolean;
    function LoadGroupPolicies: Boolean;
    function LoadTrustedRoots: Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    { 从系统加载企业配置 }
    function LoadFromSystem: Boolean;
    
    { FIPS 模式检测 }
    function IsFIPSEnabled: Boolean;
    
    { 获取受信任的根证书列表 }
    function GetTrustedRoots: TStringArray;
    
    { 读取特定组策略 }
    function ReadGroupPolicy(const APolicyName: string): string;
    
    { 检查企业 CA 是否自动信任 }
    function IsEnterpriseCATrusted: Boolean;
    
    { 获取所有组策略键值对 }
    function GetAllPolicies: TStringArray;
    
    { 重新加载配置 }
    procedure Reload;
  end;

{ 全局辅助函数 }

{ 读取组策略值 }
function ReadGroupPolicy(const APolicyName: string): string;

{ 检查 FIPS 模式是否启用 }
function IsFIPSModeEnabled: Boolean;

{ 获取企业信任的根证书 }
function GetEnterpriseTrustedRoots: TStringArray;

implementation

uses
  nextpas.core.text.strings;


const
  // FIPS 注册表路径
  FIPS_REG_PATH = 'System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy';
  FIPS_REG_VALUE = 'Enabled';
  
  // 组策略注册表路径
  GP_BASE_PATH = 'Software\Policies';
  GP_CRYPTO_PATH = 'Software\Policies\Microsoft\Cryptography';
  
  // 证书存储路径
  CERT_STORE_ENTERPRISE_ROOT = 'Enterprise';

{ TSSLEnterpriseConfig }

constructor TSSLEnterpriseConfig.Create;
begin
  inherited Create;
  FFIPSEnabled := False;
  FPolicyLoaded := False;
end;

destructor TSSLEnterpriseConfig.Destroy;
begin
  inherited Destroy;
end;

function TSSLEnterpriseConfig.DetectFIPSMode: Boolean;
var
  LReg: TRegistry;
  LValue: Integer;
begin
  Result := False;
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    
    if LReg.OpenKeyReadOnly(FIPS_REG_PATH) then
    begin
      try
        if LReg.ValueExists(FIPS_REG_VALUE) then
        begin
          LValue := LReg.ReadInteger(FIPS_REG_VALUE);
          Result := (LValue = 1);
        end;
      finally
        LReg.CloseKey;
      end;
    end;
  finally
  end;
  
  FFIPSEnabled := Result;
end;

function TSSLEnterpriseConfig.LoadGroupPolicies: Boolean;
var
  LReg: TRegistry;
  LKeys: TStringArray;
  i: Integer;
  LValue: string;
begin
  Result := False;
  FGroupPolicies.Clear;
  
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    
    // 读取加密相关的组策略
    if LReg.OpenKeyReadOnly(GP_CRYPTO_PATH) then
    begin
      try
        LReg.GetValueNames(LKeys);
        for i := 0 to Length(LKeys) - 1 do
        begin
          try
            LValue := LReg.ReadString(LKeys[i]);
            FGroupPolicies.Values[LKeys[i]] := LValue;
          except
            on E: Exception do
              TSecurityLog.Debug('Enterprise', Format('Failed to read group policy value %s: %s', [LKeys[i], E.Message]));
          end;
        end;
        Result := True;
      finally
        LReg.CloseKey;
      end;
    end;
    
    FPolicyLoaded := Result;
  finally
  end;
end;

function TSSLEnterpriseConfig.LoadTrustedRoots: Boolean;
var
  LStoreHandle: HCERTSTORE;
  LCertContext: PCCERT_CONTEXT;
  LSubject: string;
  LBuffer: array[0..1023] of Char;
  LSize: DWORD;
begin
  Result := False;
  FTrustedRoots.Clear;
  
  // 打开企业根证书存储
  LStoreHandle := CertOpenSystemStoreW(0, PWideChar('ROOT'));
  if LStoreHandle = nil then
    Exit;
  
  try
    LCertContext := nil;
    
    // 枚举所有证书
    while True do
    begin
      LCertContext := CertEnumCertificatesInStore(LStoreHandle, LCertContext);
      if LCertContext = nil then
        Break;
      
      // 获取证书主题
      LSize := CertGetNameStringW(
        LCertContext,
        CERT_NAME_SIMPLE_DISPLAY_TYPE,
        0,
        nil,
        @LBuffer[0],
        SizeOf(LBuffer)
      );
      
      if LSize > 1 then
      begin
        SetString(LSubject, PChar(@LBuffer[0]), LSize - 1);
        FTrustedRoots.Add(LSubject);
      end;
    end;
    
    Result := Length(FTrustedRoots) > 0;
  finally
    CertCloseStore(LStoreHandle, 0);
  end;
end;

function TSSLEnterpriseConfig.LoadFromSystem: Boolean;
begin
  Result := True;
  
  // 检测 FIPS 模式
  try
    DetectFIPSMode;
  except
    Result := False;
  end;
  
  // 加载组策略
  try
    LoadGroupPolicies;
  except
    Result := False;
  end;
  
  // 加载受信任的根证书
  try
    LoadTrustedRoots;
  except
    Result := False;
  end;
end;

function TSSLEnterpriseConfig.IsFIPSEnabled: Boolean;
begin
  Result := FFIPSEnabled;
end;

function TSSLEnterpriseConfig.GetTrustedRoots: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FTrustedRoots));
  for i := 0 to Length(FTrustedRoots) - 1 do
    Result[i] := FTrustedRoots[i];
end;

function TSSLEnterpriseConfig.ReadGroupPolicy(const APolicyName: string): string;
begin
  Result := FGroupPolicies.Values[APolicyName];
end;

function TSSLEnterpriseConfig.IsEnterpriseCATrusted: Boolean;
var
  LReg: TRegistry;
begin
  Result := False;
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    
    // 检查企业 CA 是否配置为自动信任
    if LReg.OpenKeyReadOnly(GP_CRYPTO_PATH) then
    begin
      try
        if LReg.ValueExists('EnterpriseRootCA') then
          Result := LReg.ReadBool('EnterpriseRootCA')
        else
          Result := True; // 默认信任
      finally
        LReg.CloseKey;
      end;
    end
    else
      Result := True; // 如果没有策略，默认信任
  finally
  end;
end;

function TSSLEnterpriseConfig.GetAllPolicies: TStringArray;
begin
  Result.Assign(FGroupPolicies);
end;

procedure TSSLEnterpriseConfig.Reload;
begin
  LoadFromSystem;
end;

{ 全局辅助函数实现 }

function ReadGroupPolicy(const APolicyName: string): string;
var
  LReg: TRegistry;
begin
  Result := '';
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    
    if LReg.OpenKeyReadOnly(GP_CRYPTO_PATH) then
    begin
      try
        if LReg.ValueExists(APolicyName) then
          Result := LReg.ReadString(APolicyName);
      finally
        LReg.CloseKey;
      end;
    end;
  finally
  end;
end;

function IsFIPSModeEnabled: Boolean;
var
  LReg: TRegistry;
  LValue: Integer;
begin
  Result := False;
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    
    if LReg.OpenKeyReadOnly(FIPS_REG_PATH) then
    begin
      try
        if LReg.ValueExists(FIPS_REG_VALUE) then
        begin
          LValue := LReg.ReadInteger(FIPS_REG_VALUE);
          Result := (LValue = 1);
        end;
      finally
        LReg.CloseKey;
      end;
    end;
  finally
  end;
end;

function GetEnterpriseTrustedRoots: TStringArray;
var
  LStoreHandle: HCERTSTORE;
  LCertContext: PCCERT_CONTEXT;
  LSubject: string;
  LBuffer: array[0..1023] of Char;
  LSize: DWORD;
  LList: TStringArray;
  i: Integer;
begin
  SetLength(Result, 0);
  try
    LStoreHandle := CertOpenSystemStoreW(0, PWideChar('ROOT'));
    if LStoreHandle = nil then
      Exit;
    
    try
      LCertContext := nil;
      
      while True do
      begin
        LCertContext := CertEnumCertificatesInStore(LStoreHandle, LCertContext);
        if LCertContext = nil then
          Break;
        
        LSize := CertGetNameStringW(
          LCertContext,
          CERT_NAME_SIMPLE_DISPLAY_TYPE,
          0,
          nil,
          @LBuffer[0],
          SizeOf(LBuffer)
        );
        
        if LSize > 1 then
        begin
          SetString(LSubject, PChar(@LBuffer[0]), LSize - 1);
          LList.Add(LSubject);
        end;
      end;
      
      SetLength(Result, Length(LList));
      for i := 0 to Length(LList) - 1 do
        Result[i] := LList[i];
    finally
      CertCloseStore(LStoreHandle, 0);
    end;
  finally
  end;
end;

end.

