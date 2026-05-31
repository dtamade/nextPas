program test_session_save_logic;

{$mode objfpc}{$H+}{$J-}

{ 
  任务 11.2: 会话保存逻辑测试
  
  测试内容:
  - 握手完成后保存会话信息
  - 提取会话 ID、协议版本、密码套件
  - 创建 TWinSSLSession 对象
  - 设置会话元数据
  
  验证需求: 4.4
}

uses
  SysUtils, DateUtils;

type
  TSSLProtocolVersion = (
    sslProtocolSSL3,
    sslProtocolTLS10,
    sslProtocolTLS11,
    sslProtocolTLS12,
    sslProtocolTLS13
  );

  { 模拟的证书接口 }
  ISSLCertificate = interface
    ['{12345678-1234-1234-1234-123456789ABC}']
    function GetSubject: string;
  end;

  { 模拟的会话接口 }
  ISSLSession = interface
    ['{12345678-1234-1234-1234-123456789012}']
    function GetID: string;
    function IsValid: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
  end;

  { 模拟的证书类 }
  TMockCertificate = class(TInterfacedObject, ISSLCertificate)
  private
    FSubject: string;
  public
    constructor Create(const ASubject: string);
    function GetSubject: string;
  end;

  { 模拟的会话类 }
  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FPeerCertificate: ISSLCertificate;
    FIsResumed: Boolean;
  public
    constructor Create;
    
    procedure SetSessionMetadata(const AID: string; 
      AProtocol: TSSLProtocolVersion; const ACipher: string; AResumed: Boolean);
    procedure SetPeerCertificate(ACert: ISSLCertificate);
    
    function GetID: string;
    function IsValid: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
  end;

  { 模拟的连接类 }
  TMockConnection = class
  private
    FCurrentSession: ISSLSession;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FPeerCertificate: ISSLCertificate;
    
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
  public
    constructor Create;
    
    procedure SetConnectionInfo(AProtocol: TSSLProtocolVersion; 
      const ACipher: string; ACert: ISSLCertificate);
    procedure SaveSessionAfterHandshake;
    
    function GetSavedSession: ISSLSession;
  end;

var
  Total, Passed, Failed: Integer;

{ TMockCertificate 实现 }

constructor TMockCertificate.Create(const ASubject: string);
begin
  inherited Create;
  FSubject := ASubject;
end;

function TMockCertificate.GetSubject: string;
begin
  Result := FSubject;
end;

{ TMockSession 实现 }

constructor TMockSession.Create;
begin
  inherited Create;
  FID := '';
  FCreationTime := Now;
  FTimeout := 3600;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := '';
  FPeerCertificate := nil;
  FIsResumed := False;
end;

procedure TMockSession.SetSessionMetadata(const AID: string; 
  AProtocol: TSSLProtocolVersion; const ACipher: string; AResumed: Boolean);
begin
  FID := AID;
  FProtocolVersion := AProtocol;
  FCipherName := ACipher;
  FIsResumed := AResumed;
end;

procedure TMockSession.SetPeerCertificate(ACert: ISSLCertificate);
begin
  FPeerCertificate := ACert;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.IsValid: Boolean;
begin
  Result := (FID <> '') and ((Now - FCreationTime) * 86400 < FTimeout);
end;

function TMockSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TMockSession.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TMockSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := FPeerCertificate;
end;

{ TMockConnection 实现 }

constructor TMockConnection.Create;
begin
  inherited Create;
  FCurrentSession := nil;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := 'TLS_AES_128_GCM_SHA256';
  FPeerCertificate := nil;
end;

procedure TMockConnection.SetConnectionInfo(AProtocol: TSSLProtocolVersion; 
  const ACipher: string; ACert: ISSLCertificate);
begin
  FProtocolVersion := AProtocol;
  FCipherName := ACipher;
  FPeerCertificate := ACert;
end;

function TMockConnection.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TMockConnection.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TMockConnection.GetPeerCertificate: ISSLCertificate;
begin
  Result := FPeerCertificate;
end;

procedure TMockConnection.SaveSessionAfterHandshake;
var
  LSession: TMockSession;
  LSessionID: string;
  LProtocol: TSSLProtocolVersion;
  LCipher: string;
  LPeerCert: ISSLCertificate;
begin
  // 任务 11.2: 提取会话信息
  LSessionID := Format('winssl-session-%p', [Pointer(Self)]);
  LProtocol := GetProtocolVersion;
  LCipher := GetCipherName;
  LPeerCert := GetPeerCertificate;
  
  // 任务 11.2: 创建 TWinSSLSession 对象
  LSession := TMockSession.Create;
  try
    // 设置会话元数据
    LSession.SetSessionMetadata(LSessionID, LProtocol, LCipher, False);
    
    // 设置对端证书
    if LPeerCert <> nil then
      LSession.SetPeerCertificate(LPeerCert);
    
    // 保存当前会话引用
    FCurrentSession := LSession;
  except
    // 如果保存会话失败,不影响连接的正常使用
  end;
end;

function TMockConnection.GetSavedSession: ISSLSession;
begin
  Result := FCurrentSession;
end;

{ 测试辅助函数 }

procedure Check(const AName: string; ACondition: Boolean; const AMessage: string = '');
begin
  Inc(Total);
  Write('  ', AName, ' ... ');
  if ACondition then
  begin
    WriteLn('✓ 通过');
    Inc(Passed);
  end
  else
  begin
    WriteLn('✗ 失败');
    if AMessage <> '' then
      WriteLn('    原因: ', AMessage);
    Inc(Failed);
  end;
end;

procedure BeginSection(const ATitle: string);
begin
  WriteLn;
  WriteLn('=== ', ATitle, ' ===');
end;

{ 测试用例 }

{ 测试 1: 保存会话基本信息 }
procedure TestSaveSessionBasicInfo;
var
  LConn: TMockConnection;
  LSession: ISSLSession;
begin
  BeginSection('测试 1: 保存会话基本信息');
  
  LConn := TMockConnection.Create;
  try
    // 设置连接信息
    LConn.SetConnectionInfo(sslProtocolTLS12, 'TLS_AES_128_GCM_SHA256', nil);
    
    // 保存会话
    LConn.SaveSessionAfterHandshake;
    
    // 获取会话
    LSession := LConn.GetSavedSession;
    Check('会话已创建', LSession <> nil);
    
    if LSession <> nil then
    begin
      Check('会话 ID 不为空', LSession.GetID <> '');
      Check('协议版本正确', LSession.GetProtocolVersion = sslProtocolTLS12);
      Check('密码套件正确', LSession.GetCipherName = 'TLS_AES_128_GCM_SHA256');
      Check('会话有效', LSession.IsValid);
    end;
  finally
    LConn.Free;
  end;
end;

{ 测试 2: 保存会话包含对端证书 }
procedure TestSaveSessionWithPeerCert;
var
  LConn: TMockConnection;
  LSession: ISSLSession;
  LCert: ISSLCertificate;
begin
  BeginSection('测试 2: 保存会话包含对端证书');
  
  LConn := TMockConnection.Create;
  try
    // 创建对端证书
    LCert := TMockCertificate.Create('CN=client.example.com');
    
    // 设置连接信息
    LConn.SetConnectionInfo(sslProtocolTLS13, 'TLS_AES_256_GCM_SHA384', LCert);
    
    // 保存会话
    LConn.SaveSessionAfterHandshake;
    
    // 获取会话
    LSession := LConn.GetSavedSession;
    Check('会话已创建', LSession <> nil);
    
    if LSession <> nil then
    begin
      Check('会话包含对端证书', LSession.GetPeerCertificate <> nil);
      if LSession.GetPeerCertificate <> nil then
        Check('对端证书主题正确', 
          LSession.GetPeerCertificate.GetSubject = 'CN=client.example.com');
    end;
  finally
    LConn.Free;
  end;
end;

{ 测试 3: 多次保存会话 }
procedure TestMultipleSaveSession;
var
  LConn: TMockConnection;
  LSession1, LSession2: ISSLSession;
begin
  BeginSection('测试 3: 多次保存会话');
  
  LConn := TMockConnection.Create;
  try
    // 第一次保存
    LConn.SetConnectionInfo(sslProtocolTLS12, 'TLS_AES_128_GCM_SHA256', nil);
    LConn.SaveSessionAfterHandshake;
    LSession1 := LConn.GetSavedSession;
    
    // 第二次保存(模拟重新连接)
    LConn.SetConnectionInfo(sslProtocolTLS13, 'TLS_AES_256_GCM_SHA384', nil);
    LConn.SaveSessionAfterHandshake;
    LSession2 := LConn.GetSavedSession;
    
    Check('第一个会话已创建', LSession1 <> nil);
    Check('第二个会话已创建', LSession2 <> nil);
    Check('两个会话不同', LSession1 <> LSession2);
    
    if LSession2 <> nil then
      Check('第二个会话协议版本正确', LSession2.GetProtocolVersion = sslProtocolTLS13);
  finally
    LConn.Free;
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('测试总结');
  WriteLn('================================================================');
  WriteLn('总计: ', Total);
  WriteLn('通过: ', Passed);
  WriteLn('失败: ', Failed);
  if Total > 0 then
    WriteLn('成功率: ', Format('%.1f%%', [Passed * 100.0 / Total]));
  WriteLn('================================================================');
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;
  
  WriteLn('================================================================');
  WriteLn('WinSSL 会话保存逻辑测试');
  WriteLn('================================================================');
  WriteLn('任务 11.2: 会话保存逻辑测试');
  WriteLn('验证需求: 4.4');
  WriteLn;
  WriteLn('注意: 这是逻辑测试,模拟会话保存的行为');
  WriteLn;
  
  TestSaveSessionBasicInfo;
  TestSaveSessionWithPeerCert;
  TestMultipleSaveSession;
  
  PrintSummary;
  
  if Failed > 0 then
    Halt(1);
end.
