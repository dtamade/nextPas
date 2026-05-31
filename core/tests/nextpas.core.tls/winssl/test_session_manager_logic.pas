program test_session_manager_logic;

{$mode objfpc}{$H+}{$J-}

{ 
  任务 10.1: 会话管理器测试
  
  测试内容:
  - AddSession 方法(线程安全)
  - GetSession 方法(线程安全)
  - RemoveSession 方法(线程安全)
  - CleanupExpired 方法
  - 最大会话数限制
  
  验证需求: 4.4, 4.5, 4.6, 4.7
}

uses
  SysUtils, DateUtils, Classes, SyncObjs;

type
  TSSLProtocolVersion = (
    sslProtocolSSL3,
    sslProtocolTLS10,
    sslProtocolTLS11,
    sslProtocolTLS12,
    sslProtocolTLS13
  );

  { 模拟的会话接口 }
  ISSLSession = interface
    ['{12345678-1234-1234-1234-123456789012}']
    function GetID: string;
    function IsValid: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
  end;

  { 模拟的会话类 }
  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
  public
    constructor Create(const AID: string; ATimeout: Integer);
    function GetID: string;
    function IsValid: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
  end;

  { 会话管理器 }
  TSessionManager = class
  private
    FSessions: TStringList;
    FLock: TCriticalSection;
    FMaxSessions: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddSession(const AID: string; ASession: ISSLSession);
    function GetSession(const AID: string): ISSLSession;
    procedure RemoveSession(const AID: string);
    procedure CleanupExpired;
    procedure SetMaxSessions(AMax: Integer);
    function GetSessionCount: Integer;
  end;

var
  Total, Passed, Failed: Integer;

{ TMockSession 实现 }

constructor TMockSession.Create(const AID: string; ATimeout: Integer);
begin
  inherited Create;
  FID := AID;
  FCreationTime := Now;
  FTimeout := ATimeout;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := 'TLS_AES_128_GCM_SHA256';
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

{ TSessionManager 实现 }

constructor TSessionManager.Create;
begin
  inherited Create;
  FSessions := TStringList.Create;
  FSessions.Duplicates := dupIgnore;
  FSessions.Sorted := False;  // 不排序,保持插入顺序以实现 FIFO
  FLock := TCriticalSection.Create;
  FMaxSessions := 100;
end;

destructor TSessionManager.Destroy;
var
  i: Integer;
begin
  // 释放所有会话的引用
  for i := 0 to FSessions.Count - 1 do
  begin
    if FSessions.Objects[i] <> nil then
      ISSLSession(Pointer(FSessions.Objects[i]))._Release;
  end;
  FSessions.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TSessionManager.AddSession(const AID: string; ASession: ISSLSession);
var
  LIndex: Integer;
begin
  FLock.Enter;
  try
    // 检查是否已存在,如果存在则更新
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
      FSessions.Delete(LIndex);
    
    // 增加引用计数
    if ASession <> nil then
      ASession._AddRef;
    
    FSessions.AddObject(AID, TObject(Pointer(ASession)));
    
    // 限制最大会话数
    while FSessions.Count > FMaxSessions do
    begin
      // 释放被删除会话的引用
      if FSessions.Objects[0] <> nil then
        ISSLSession(Pointer(FSessions.Objects[0]))._Release;
      FSessions.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.GetSession(const AID: string): ISSLSession;
var
  LIndex: Integer;
begin
  FLock.Enter;
  try
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
    begin
      Result := ISSLSession(Pointer(FSessions.Objects[LIndex]));
      // 检查会话是否仍然有效
      if not Result.IsValid then
      begin
        // 释放引用
        if FSessions.Objects[LIndex] <> nil then
          ISSLSession(Pointer(FSessions.Objects[LIndex]))._Release;
        FSessions.Delete(LIndex);
        Result := nil;
      end;
    end
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TSessionManager.RemoveSession(const AID: string);
var
  LIndex: Integer;
begin
  FLock.Enter;
  try
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
    begin
      // 释放引用
      if FSessions.Objects[LIndex] <> nil then
        ISSLSession(Pointer(FSessions.Objects[LIndex]))._Release;
      FSessions.Delete(LIndex);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSessionManager.CleanupExpired;
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := FSessions.Count - 1 downto 0 do
    begin
      if not ISSLSession(Pointer(FSessions.Objects[i])).IsValid then
      begin
        // 释放引用
        if FSessions.Objects[i] <> nil then
          ISSLSession(Pointer(FSessions.Objects[i]))._Release;
        FSessions.Delete(i);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSessionManager.SetMaxSessions(AMax: Integer);
begin
  if AMax > 0 then
    FMaxSessions := AMax;
end;

function TSessionManager.GetSessionCount: Integer;
begin
  FLock.Enter;
  try
    Result := FSessions.Count;
  finally
    FLock.Leave;
  end;
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

{ 测试 1: 添加和获取会话 }
procedure TestAddAndGetSession;
var
  LManager: TSessionManager;
  LSession1, LSession2: ISSLSession;
begin
  BeginSection('测试 1: 添加和获取会话');
  
  LManager := TSessionManager.Create;
  try
    // 创建会话
    LSession1 := TMockSession.Create('session1', 3600);
    
    // 添加会话
    LManager.AddSession('session1', LSession1);
    Check('添加会话成功', LManager.GetSessionCount = 1);
    
    // 获取会话
    LSession2 := LManager.GetSession('session1');
    Check('获取会话成功', LSession2 <> nil);
    Check('获取的会话 ID 正确', LSession2.GetID = 'session1');
    
    // 获取不存在的会话
    LSession2 := LManager.GetSession('nonexistent');
    Check('获取不存在的会话返回 nil', LSession2 = nil);
  finally
    LManager.Free;
  end;
end;

{ 测试 2: 删除会话 }
procedure TestRemoveSession;
var
  LManager: TSessionManager;
  LSession: ISSLSession;
begin
  BeginSection('测试 2: 删除会话');
  
  LManager := TSessionManager.Create;
  try
    // 添加会话
    LSession := TMockSession.Create('session1', 3600);
    LManager.AddSession('session1', LSession);
    Check('添加会话', LManager.GetSessionCount = 1);
    
    // 删除会话
    LManager.RemoveSession('session1');
    Check('删除会话后计数为 0', LManager.GetSessionCount = 0);
    
    // 获取已删除的会话
    LSession := LManager.GetSession('session1');
    Check('获取已删除的会话返回 nil', LSession = nil);
    
    // 删除不存在的会话(不应该崩溃)
    LManager.RemoveSession('nonexistent');
    Check('删除不存在的会话不崩溃', True);
  finally
    LManager.Free;
  end;
end;

{ 测试 3: 清理过期会话 }
procedure TestCleanupExpired;
var
  LManager: TSessionManager;
  LSession1, LSession2, LSession3: ISSLSession;
begin
  BeginSection('测试 3: 清理过期会话');
  
  LManager := TSessionManager.Create;
  try
    // 添加有效会话(超时 3600 秒)
    LSession1 := TMockSession.Create('session1', 3600);
    LManager.AddSession('session1', LSession1);
    
    // 添加即将过期的会话(超时 1 秒)
    LSession2 := TMockSession.Create('session2', 1);
    LManager.AddSession('session2', LSession2);
    
    // 添加另一个有效会话
    LSession3 := TMockSession.Create('session3', 3600);
    LManager.AddSession('session3', LSession3);
    
    Check('添加 3 个会话', LManager.GetSessionCount = 3);
    
    // 等待 2 秒让 session2 过期
    WriteLn('    等待 2 秒让会话过期...');
    Sleep(2000);
    
    // 清理过期会话
    LManager.CleanupExpired;
    Check('清理后剩余 2 个会话', LManager.GetSessionCount = 2);
    
    // 验证过期的会话被删除
    LSession2 := LManager.GetSession('session2');
    Check('过期会话被删除', LSession2 = nil);
    
    // 验证有效会话仍然存在
    LSession1 := LManager.GetSession('session1');
    Check('有效会话 1 仍存在', LSession1 <> nil);
    
    LSession3 := LManager.GetSession('session3');
    Check('有效会话 3 仍存在', LSession3 <> nil);
  finally
    LManager.Free;
  end;
end;

{ 测试 4: 最大会话数限制 }
procedure TestMaxSessionsLimit;
var
  LManager: TSessionManager;
  LSession: ISSLSession;
  i: Integer;
begin
  BeginSection('测试 4: 最大会话数限制');
  
  LManager := TSessionManager.Create;
  try
    // 设置最大会话数为 5
    LManager.SetMaxSessions(5);
    
    // 添加 10 个会话
    for i := 1 to 10 do
    begin
      LSession := TMockSession.Create('session' + IntToStr(i), 3600);
      LManager.AddSession('session' + IntToStr(i), LSession);
    end;
    
    // 验证只保留最后 5 个会话
    Check('会话数限制为 5', LManager.GetSessionCount = 5);
    
    // 验证最早的会话被删除
    LSession := LManager.GetSession('session1');
    Check('最早的会话被删除', LSession = nil);
    
    // 验证最新的会话仍然存在
    LSession := LManager.GetSession('session10');
    Check('最新的会话仍存在', LSession <> nil);
  finally
    LManager.Free;
  end;
end;

{ 测试 5: 多个会话管理 }
procedure TestMultipleSessions;
var
  LManager: TSessionManager;
  LSession: ISSLSession;
  i: Integer;
begin
  BeginSection('测试 5: 多个会话管理');
  
  LManager := TSessionManager.Create;
  try
    // 添加多个会话
    for i := 1 to 10 do
    begin
      LSession := TMockSession.Create('session' + IntToStr(i), 3600);
      LManager.AddSession('session' + IntToStr(i), LSession);
    end;
    
    Check('添加 10 个会话', LManager.GetSessionCount = 10);
    
    // 获取所有会话
    for i := 1 to 10 do
    begin
      LSession := LManager.GetSession('session' + IntToStr(i));
      if LSession = nil then
      begin
        Check('获取会话 ' + IntToStr(i), False, '会话不存在');
        Exit;
      end;
    end;
    Check('所有会话都可获取', True);
    
    // 删除部分会话
    for i := 1 to 5 do
      LManager.RemoveSession('session' + IntToStr(i));
    
    Check('删除 5 个会话后剩余 5 个', LManager.GetSessionCount = 5);
  finally
    LManager.Free;
  end;
end;

{ 测试 6: 获取过期会话自动清理 }
procedure TestGetExpiredSessionAutoCleanup;
var
  LManager: TSessionManager;
  LSession: ISSLSession;
begin
  BeginSection('测试 6: 获取过期会话自动清理');
  
  LManager := TSessionManager.Create;
  try
    // 添加即将过期的会话(超时 1 秒)
    LSession := TMockSession.Create('session1', 1);
    LManager.AddSession('session1', LSession);
    Check('添加会话', LManager.GetSessionCount = 1);
    
    // 等待 2 秒让会话过期
    WriteLn('    等待 2 秒让会话过期...');
    Sleep(2000);
    
    // 尝试获取过期会话(应该自动清理)
    LSession := LManager.GetSession('session1');
    Check('获取过期会话返回 nil', LSession = nil);
    Check('过期会话被自动清理', LManager.GetSessionCount = 0);
  finally
    LManager.Free;
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
  WriteLn('WinSSL 会话管理器逻辑测试');
  WriteLn('================================================================');
  WriteLn('任务 10.1: 会话管理器测试');
  WriteLn('验证需求: 4.4, 4.5, 4.6, 4.7');
  WriteLn;
  WriteLn('注意: 这是逻辑测试,模拟会话管理器的行为');
  WriteLn;
  
  TestAddAndGetSession;
  TestRemoveSession;
  TestCleanupExpired;
  TestMaxSessionsLimit;
  TestMultipleSessions;
  TestGetExpiredSessionAutoCleanup;
  
  PrintSummary;
  
  if Failed > 0 then
    Halt(1);
end.
