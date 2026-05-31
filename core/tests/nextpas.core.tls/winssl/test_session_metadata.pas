program test_session_metadata;

{$mode objfpc}{$H+}{$J-}

{ 
  任务 9.2: 会话元数据设置和读取测试
  
  测试内容:
  - 会话 ID 设置和读取
  - 协议版本和密码套件设置
  - 会话有效性检查
  
  验证需求: 4.1
}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.connection;

var
  Total, Passed, Failed: Integer;

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

{ 测试会话 ID 设置和读取 }
procedure TestSessionIDSetAndGet;
var
  LSession: TWinSSLSession;
  LID: string;
begin
  BeginSection('测试会话 ID 设置和读取');
  
  LSession := TWinSSLSession.Create;
  try
    // 设置会话 ID
    LID := 'test-session-12345';
    LSession.SetSessionMetadata(LID, sslProtocolTLS12, 'TLS_AES_128_GCM_SHA256', False);
    
    // 读取会话 ID
    Check('会话 ID 设置和读取', LSession.GetID = LID);
  finally
    LSession.Free;
  end;
end;

{ 测试协议版本设置和读取 }
procedure TestProtocolVersionSetAndGet;
var
  LSession: TWinSSLSession;
begin
  BeginSection('测试协议版本设置和读取');
  
  LSession := TWinSSLSession.Create;
  try
    // 测试 TLS 1.2
    LSession.SetSessionMetadata('session1', sslProtocolTLS12, 'cipher1', False);
    Check('TLS 1.2 协议版本', LSession.GetProtocolVersion = sslProtocolTLS12);
    
    // 测试 TLS 1.3
    LSession.SetSessionMetadata('session2', sslProtocolTLS13, 'cipher2', False);
    Check('TLS 1.3 协议版本', LSession.GetProtocolVersion = sslProtocolTLS13);
  finally
    LSession.Free;
  end;
end;

{ 测试密码套件设置和读取 }
procedure TestCipherNameSetAndGet;
var
  LSession: TWinSSLSession;
  LCipher: string;
begin
  BeginSection('测试密码套件设置和读取');
  
  LSession := TWinSSLSession.Create;
  try
    // 设置密码套件
    LCipher := 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384';
    LSession.SetSessionMetadata('session1', sslProtocolTLS12, LCipher, False);
    
    // 读取密码套件
    Check('密码套件设置和读取', LSession.GetCipherName = LCipher);
  finally
    LSession.Free;
  end;
end;

{ 测试会话有效性检查 }
procedure TestSessionValidity;
var
  LSession: TWinSSLSession;
begin
  BeginSection('测试会话有效性检查');
  
  LSession := TWinSSLSession.Create;
  try
    // 新创建的会话应该无效(没有 ID)
    Check('新会话无效', not LSession.IsValid);
    
    // 设置会话元数据后应该有效
    LSession.SetSessionMetadata('session1', sslProtocolTLS12, 'cipher1', False);
    Check('设置元数据后有效', LSession.IsValid);
    
    // 设置超时为 1 秒
    LSession.SetTimeout(1);
    Check('设置超时后仍有效', LSession.IsValid);
    
    // 等待 2 秒后应该过期
    Sleep(2000);
    Check('超时后无效', not LSession.IsValid);
  finally
    LSession.Free;
  end;
end;

{ 测试会话可复用性 }
procedure TestSessionResumability;
var
  LSession: TWinSSLSession;
begin
  BeginSection('测试会话可复用性');
  
  LSession := TWinSSLSession.Create;
  try
    // 无效会话不可复用
    Check('无效会话不可复用', not LSession.IsResumable);
    
    // 有效会话可复用
    LSession.SetSessionMetadata('session1', sslProtocolTLS12, 'cipher1', False);
    Check('有效会话可复用', LSession.IsResumable);
    
    // 过期会话不可复用
    LSession.SetTimeout(1);
    Sleep(2000);
    Check('过期会话不可复用', not LSession.IsResumable);
  finally
    LSession.Free;
  end;
end;

{ 测试会话克隆 }
procedure TestSessionClone;
var
  LSession1, LSession2: TWinSSLSession;
  LCloned: ISSLSession;
begin
  BeginSection('测试会话克隆');
  
  LSession1 := TWinSSLSession.Create;
  try
    // 设置会话元数据
    LSession1.SetSessionMetadata('session1', sslProtocolTLS12, 
      'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384', False);
    LSession1.SetTimeout(3600);
    
    // 克隆会话
    LCloned := LSession1.Clone;
    Check('克隆成功', LCloned <> nil);
    
    if LCloned <> nil then
    begin
      // 验证克隆的会话具有相同的属性
      Check('克隆的会话 ID 一致', LCloned.GetID = LSession1.GetID);
      Check('克隆的协议版本一致', LCloned.GetProtocolVersion = LSession1.GetProtocolVersion);
      Check('克隆的密码套件一致', LCloned.GetCipherName = LSession1.GetCipherName);
      Check('克隆的超时时间一致', LCloned.GetTimeout = LSession1.GetTimeout);
      Check('克隆的会话有效性一致', LCloned.IsValid = LSession1.IsValid);
    end;
  finally
    LSession1.Free;
  end;
end;

{ 测试会话恢复标记 }
procedure TestSessionResumedFlag;
var
  LSession: TWinSSLSession;
begin
  BeginSection('测试会话恢复标记');
  
  LSession := TWinSSLSession.Create;
  try
    // 新会话不是恢复的
    Check('新会话未恢复', not LSession.WasResumed);
    
    // 设置为恢复的会话
    LSession.SetSessionMetadata('session1', sslProtocolTLS12, 'cipher1', True);
    Check('恢复的会话标记正确', LSession.WasResumed);
    
    // 设置为新会话
    LSession.SetSessionMetadata('session2', sslProtocolTLS12, 'cipher2', False);
    Check('新会话标记正确', not LSession.WasResumed);
  finally
    LSession.Free;
  end;
end;

{ 测试会话创建时间 }
procedure TestSessionCreationTime;
var
  LSession: TWinSSLSession;
  LCreationTime: TDateTime;
begin
  BeginSection('测试会话创建时间');
  
  LSession := TWinSSLSession.Create;
  try
    LCreationTime := LSession.GetCreationTime;
    
    // 创建时间应该接近当前时间(误差小于 1 秒)
    Check('创建时间正确', Abs(Now - LCreationTime) < 1.0 / 86400);
  finally
    LSession.Free;
  end;
end;

{ 测试序列化 round-trip }
procedure TestSessionSerializationRoundTrip;
var
  LSession1, LSession2: TWinSSLSession;
  LData: TBytes;
begin
  BeginSection('测试序列化 round-trip');

  LSession1 := TWinSSLSession.Create;
  LSession2 := TWinSSLSession.Create;
  try
    LSession1.SetSessionMetadata('roundtrip-session', sslProtocolTLS13,
      'TLS_AES_256_GCM_SHA384', True);
    LSession1.SetTimeout(7200);

    LData := LSession1.Serialize;
    Check('序列化后的 payload 非空', Length(LData) > 0);
    Check('反序列化成功', LSession2.Deserialize(LData));

    Check('round-trip 后 ID 一致', LSession2.GetID = LSession1.GetID);
    Check('round-trip 后协议版本一致',
      LSession2.GetProtocolVersion = LSession1.GetProtocolVersion);
    Check('round-trip 后密码套件一致',
      LSession2.GetCipherName = LSession1.GetCipherName);
    Check('round-trip 后超时时间一致',
      LSession2.GetTimeout = LSession1.GetTimeout);
    Check('round-trip 后 resumed 标记一致',
      LSession2.WasResumed = LSession1.WasResumed);
    Check('round-trip 后会话仍有效', LSession2.IsValid);
  finally
    LSession1.Free;
    LSession2.Free;
  end;
end;

{ 测试无效序列化数据 }
procedure TestSessionDeserializeRejectsInvalidPayload;
var
  LSession: TWinSSLSession;
begin
  BeginSection('测试无效序列化数据');

  LSession := TWinSSLSession.Create;
  try
    Check('空 payload 拒绝', not LSession.Deserialize(nil));
    Check('垃圾 payload 拒绝',
      not LSession.Deserialize(TBytes.Create($FF, $00, $AA, $55)));
  finally
    LSession.Free;
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
  WriteLn('成功率: ', Format('%.1f%%', [Passed * 100.0 / Total]));
  WriteLn('================================================================');
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;
  
  WriteLn('================================================================');
  WriteLn('WinSSL 会话元数据测试');
  WriteLn('================================================================');
  WriteLn('任务 9.2: 会话元数据设置和读取测试');
  WriteLn('验证需求: 4.1');
  WriteLn;
  
  TestSessionIDSetAndGet;
  TestProtocolVersionSetAndGet;
  TestCipherNameSetAndGet;
  TestSessionValidity;
  TestSessionResumability;
  TestSessionClone;
  TestSessionResumedFlag;
  TestSessionCreationTime;
  TestSessionSerializationRoundTrip;
  TestSessionDeserializeRejectsInvalidPayload;
  
  PrintSummary;
  
  if Failed > 0 then
    Halt(1);
end.
