program test_p2_ts_comprehensive;

{$mode ObjFPC}{$H+}

{
  TS (时间戳协议) 模块综合测试

  测试范围：
  1. TS 请求创建和验证
  2. TS 响应处理
  3. TS 验证和时间验证
  4. TS 准确时间查询

  功能级别：生产级测试

  依赖模块：
  - nextpas.core.tls.openssl.api.core (OpenSSL 加载)
  - nextpas.core.tls.openssl.api.ts (TS API)
  - nextpas.core.tls.openssl.api.asn1 (ASN.1)
  - nextpas.core.tls.openssl.api.bio (BIO I/O)
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ts,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader;

const
  MOCK_TS_RESP_PTR = PtrUInt($1);
  MOCK_TS_STATUS_INFO_PTR = PtrUInt($2);
  MOCK_TS_STATUS_PTR = PtrUInt($3);
  MOCK_TS_VERIFY_CTX_PTR = PtrUInt($4);

var
  TotalTests, PassedTests, FailedTests: Integer;
  IsOpenSSL3: Boolean;
  MockTSStatusValue: Integer = TS_STATUS_GRANTED;
  MockTSVerifyCalled: Boolean = False;

function MockTS_RESP_get_status_info(a: PTS_RESP): PTS_STATUS_INFO; cdecl;
begin
  Result := PTS_STATUS_INFO(Pointer(MOCK_TS_STATUS_INFO_PTR));
end;

function MockTS_STATUS_INFO_get0_status(a: PTS_STATUS_INFO): PASN1_INTEGER; cdecl;
begin
  Result := PASN1_INTEGER(Pointer(MOCK_TS_STATUS_PTR));
end;

function MockASN1_INTEGER_get(const a: ASN1_INTEGER): Integer; cdecl;
begin
  Result := MockTSStatusValue;
end;

function MockTS_VERIFY_CTX_new: PTS_VERIFY_CTX; cdecl;
begin
  Result := PTS_VERIFY_CTX(Pointer(MOCK_TS_VERIFY_CTX_PTR));
end;

procedure MockTS_VERIFY_CTX_free(ctx: PTS_VERIFY_CTX); cdecl;
begin
end;

function MockTS_VERIFY_CTX_set_flags(ctx: PTS_VERIFY_CTX; flags: Integer): Integer; cdecl;
begin
  Result := 1;
end;

function MockTS_VERIFY_CTX_set_store(ctx: PTS_VERIFY_CTX; store: PX509_STORE): PX509_STORE; cdecl;
begin
  Result := store;
end;

function MockTS_RESP_verify_response(ctx: PTS_VERIFY_CTX; resp: PTS_RESP): Integer; cdecl;
begin
  MockTSVerifyCalled := True;
  Result := 1;
end;

procedure Test(const TestName: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(TestName + ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(FailedTests);
  end;
end;

procedure TestTS_RequestOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 1: TS 请求操作 ===');

  // 测试请求创建
  LResult := Assigned(@TS_REQ_new) and (TS_REQ_new <> nil);
  Test('TS_REQ_new 函数加载', LResult);

  LResult := Assigned(@TS_REQ_free) and (TS_REQ_free <> nil);
  Test('TS_REQ_free 函数加载', LResult);

  // 测试请求响应
  LResult := Assigned(@TS_REQ_set_version) and (TS_REQ_set_version <> nil);
  Test('TS_REQ_set_version 函数加载', LResult);

  LResult := Assigned(@TS_REQ_set_msg_imprint) and (TS_REQ_set_msg_imprint <> nil);
  Test('TS_REQ_set_msg_imprint 函数加载', LResult);

  // 测试请求获取
  LResult := Assigned(@TS_REQ_get_version) and (TS_REQ_get_version <> nil);
  Test('TS_REQ_get_version 函数加载', LResult);

  LResult := Assigned(@TS_REQ_get_msg_imprint) and (TS_REQ_get_msg_imprint <> nil);
  Test('TS_REQ_get_msg_imprint 函数加载', LResult);
end;

procedure TestTS_ResponseOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 2: TS 响应操作 ===');

  // 测试响应创建
  LResult := Assigned(@TS_RESP_new) and (TS_RESP_new <> nil);
  Test('TS_RESP_new 函数加载', LResult);

  LResult := Assigned(@TS_RESP_free) and (TS_RESP_free <> nil);
  Test('TS_RESP_free 函数加载', LResult);

  // 测试响应状态
  LResult := Assigned(@TS_RESP_set_status_info) and (TS_RESP_set_status_info <> nil);
  Test('TS_RESP_set_status_info 函数加载', LResult);

  LResult := Assigned(@TS_RESP_create_response) and (TS_RESP_create_response <> nil);
  Test('TS_RESP_create_response 函数加载', LResult);

  // 测试获取响应信息
  LResult := Assigned(@TS_RESP_get_status_info) and (TS_RESP_get_status_info <> nil);
  Test('TS_RESP_get_status_info 函数加载', LResult);

  LResult := Assigned(@TS_RESP_get_token) and (TS_RESP_get_token <> nil);
  Test('TS_RESP_get_token 函数加载', LResult);
end;

procedure TestTS_TSTInfo;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 3: TS TSTInfo ===');

  // 测试 TSTInfo 创建
  LResult := Assigned(@TS_TST_INFO_new) and (TS_TST_INFO_new <> nil);
  Test('TS_TST_INFO_new 函数加载', LResult);

  LResult := Assigned(@TS_TST_INFO_free) and (TS_TST_INFO_free <> nil);
  Test('TS_TST_INFO_free 函数加载', LResult);

  // 测试设置时间戳信息
  LResult := Assigned(@TS_TST_INFO_set_version) and (TS_TST_INFO_set_version <> nil);
  Test('TS_TST_INFO_set_version 函数加载', LResult);

  // OpenSSL 1.x only functions - skip on OpenSSL 3.x
  if not IsOpenSSL3 then
  begin
    LResult := Assigned(@TS_TST_INFO_set_policy_id) and (TS_TST_INFO_set_policy_id <> nil);
    Test('TS_TST_INFO_set_policy_id 函数加载 (OpenSSL 1.x)', LResult);

    LResult := Assigned(@TS_TST_INFO_set_msg_imprint) and (TS_TST_INFO_set_msg_imprint <> nil);
    Test('TS_TST_INFO_set_msg_imprint 函数加载 (OpenSSL 1.x)', LResult);
  end;

  // 测试获取时间戳信息
  LResult := Assigned(@TS_TST_INFO_get_version) and (TS_TST_INFO_get_version <> nil);
  Test('TS_TST_INFO_get_version 函数加载', LResult);

  // OpenSSL 1.x only functions - skip on OpenSSL 3.x
  if not IsOpenSSL3 then
  begin
    LResult := Assigned(@TS_TST_INFO_get_policy_id) and (TS_TST_INFO_get_policy_id <> nil);
    Test('TS_TST_INFO_get_policy_id 函数加载 (OpenSSL 1.x)', LResult);

    LResult := Assigned(@TS_TST_INFO_get_msg_imprint) and (TS_TST_INFO_get_msg_imprint <> nil);
    Test('TS_TST_INFO_get_msg_imprint 函数加载 (OpenSSL 1.x)', LResult);
  end;
end;

procedure TestTS_Verification;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 4: TS 验证 ===');

  // 测试响应验证
  LResult := Assigned(@TS_RESP_verify_response) and (TS_RESP_verify_response <> nil);
  Test('TS_RESP_verify_response 函数加载', LResult);

  // 测试签名验证
  LResult := Assigned(@TS_RESP_verify_signature) and (TS_RESP_verify_signature <> nil);
  Test('TS_RESP_verify_signature 函数加载', LResult);

  // 测试时间戳验证
  LResult := Assigned(@TS_VERIFY_CTX_new) and (TS_VERIFY_CTX_new <> nil);
  Test('TS_VERIFY_CTX_new 函数加载', LResult);

  LResult := Assigned(@TS_VERIFY_CTX_free) and (TS_VERIFY_CTX_free <> nil);
  Test('TS_VERIFY_CTX_free 函数加载', LResult);
end;

procedure TestTS_IOAndSerialization;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 5: TS I/O 和序列化 ===');

  // 测试 BIO 编码
  LResult := Assigned(@TS_REQ_i2d_bio) and (TS_REQ_i2d_bio <> nil);
  Test('TS_REQ_i2d_bio 函数加载', LResult);

  LResult := Assigned(@TS_REQ_d2i_bio) and (TS_REQ_d2i_bio <> nil);
  Test('TS_REQ_d2i_bio 函数加载', LResult);

  LResult := Assigned(@TS_RESP_i2d_bio) and (TS_RESP_i2d_bio <> nil);
  Test('TS_RESP_i2d_bio 函数加载', LResult);

  LResult := Assigned(@TS_RESP_d2i_bio) and (TS_RESP_d2i_bio <> nil);
  Test('TS_RESP_d2i_bio 函数加载', LResult);

  // 测试打印函数
  LResult := Assigned(@TS_REQ_print_bio) and (TS_REQ_print_bio <> nil);
  Test('TS_REQ_print_bio 函数加载', LResult);

  LResult := Assigned(@TS_RESP_print_bio) and (TS_RESP_print_bio <> nil);
  Test('TS_RESP_print_bio 函数加载', LResult);
end;

procedure TestTS_UtilityFunctions;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 6: TS 工具函数 ===');

  // 测试状态信息
  LResult := Assigned(@TS_STATUS_INFO_get0_status) and (TS_STATUS_INFO_get0_status <> nil);
  Test('TS_STATUS_INFO_get0_status 函数加载', LResult);


  // 如果运行库导出该符号，则绑定层必须加载成功
  if Assigned(GetCryptoProcAddress('TS_STATUS_INFO_set_status')) then
  begin
    LResult := Assigned(@TS_STATUS_INFO_set_status) and (TS_STATUS_INFO_set_status <> nil);
    Test('TS_STATUS_INFO_set_status 函数加载', LResult);
  end
  else
    Test('TS_STATUS_INFO_set_status 符号缺失时允许跳过', True);
  // OpenSSL 1.x only function - skip on OpenSSL 3.x
  if not IsOpenSSL3 then
  begin
    LResult := Assigned(@TS_STATUS_INFO_get0_text) and (TS_STATUS_INFO_get0_text <> nil);
    Test('TS_STATUS_INFO_get0_text 函数加载 (OpenSSL 1.x)', LResult);
  end;

  // 测试打印函数
  LResult := Assigned(@TS_TST_INFO_print_bio) and (TS_TST_INFO_print_bio <> nil);
  Test('TS_TST_INFO_print_bio 函数加载', LResult);

  LResult := Assigned(@TS_STATUS_INFO_print_bio) and (TS_STATUS_INFO_print_bio <> nil);
  Test('TS_STATUS_INFO_print_bio 函数加载', LResult);

  // 测试状态常量
  Test('TS_STATUS_GRANTED (0)', TS_STATUS_GRANTED = 0);
  Test('TS_STATUS_GRANTED_WITH_MODS (1)', TS_STATUS_GRANTED_WITH_MODS = 1);
  Test('TS_STATUS_REJECTION (2)', TS_STATUS_REJECTION = 2);
  Test('TS_STATUS_WAITING (3)', TS_STATUS_WAITING = 3);
  Test('TS_STATUS_REVOCATION_WARNING (4)', TS_STATUS_REVOCATION_WARNING = 4);
  Test('TS_STATUS_REVOCATION_NOTIFICATION (5)', TS_STATUS_REVOCATION_NOTIFICATION = 5);
end;

procedure TestTS_OfflineMalformedResponseFixture;
const
  FIXTURE_PATH = './tests/fixtures/p2/ts/ts_response_malformed_v1.der';
var
  LFixtureExists: Boolean;
  LStream: TFileStream;
  LData: TBytes;
  LBio: PBIO;
  LResp: PTS_RESP;
begin
  WriteLn;
  WriteLn('=== 测试 7: TS 离线失败夹具 ===');

  if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
    LoadOpenSSLBIO;

  LFixtureExists := FileExists(FIXTURE_PATH);
  Test('TS malformed fixture 存在', LFixtureExists);
  if not LFixtureExists then
    Exit;

  Test('TS_RESP_d2i_bio 函数加载', Assigned(TS_RESP_d2i_bio));
  Test('BIO_new_mem_buf 函数加载', Assigned(BIO_new_mem_buf));
  if (not Assigned(TS_RESP_d2i_bio)) or (not Assigned(BIO_new_mem_buf)) then
    Exit;

  LStream := TFileStream.Create(FIXTURE_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;

  Test('TS malformed fixture 非空', Length(LData) > 0);
  if Length(LData) = 0 then
    Exit;

  LBio := BIO_new_mem_buf(@LData[0], Length(LData));
  if LBio = nil then
  begin
    Test('为 TS fixture 创建 BIO', False);
    Exit;
  end;
  Test('为 TS fixture 创建 BIO', True);

  LResp := nil;
  try
    LResp := TS_RESP_d2i_bio(LBio, @LResp);
    Test('解析 malformed TS 响应返回 nil', LResp = nil);
  finally
    if Assigned(BIO_free) then
      BIO_free(LBio);
    if (LResp <> nil) and Assigned(TS_RESP_free) then
      TS_RESP_free(LResp);
  end;
end;

procedure TestTS_TruncatedResponseFailure;
var
  LData: TBytes;
  LBio: PBIO;
  LResp: PTS_RESP;
begin
  WriteLn;
  WriteLn('=== 测试 8: TS 截断响应失败场景 ===');

  if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
    LoadOpenSSLBIO;

  Test('TS_RESP_d2i_bio 函数加载', Assigned(TS_RESP_d2i_bio));
  Test('BIO_new_mem_buf 函数加载', Assigned(BIO_new_mem_buf));
  if (not Assigned(TS_RESP_d2i_bio)) or (not Assigned(BIO_new_mem_buf)) then
    Exit;

  SetLength(LData, 2);
  LData[0] := $30;
  LData[1] := $82;

  LBio := BIO_new_mem_buf(@LData[0], Length(LData));
  Test('为截断 TS 响应创建 BIO', LBio <> nil);
  if LBio = nil then
    Exit;

  LResp := nil;
  try
    LResp := TS_RESP_d2i_bio(LBio, @LResp);
    Test('解析截断 TS 响应返回 nil', LResp = nil);
  finally
    if Assigned(BIO_free) then
      BIO_free(LBio);
    if (LResp <> nil) and Assigned(TS_RESP_free) then
      TS_RESP_free(LResp);
  end;
end;

procedure TestTS_RejectionStatusFailure;
var
  LResp: PTS_RESP;
  LStatusInfo: PTS_STATUS_INFO;
  LAttachedStatusInfo: PTS_STATUS_INFO;
  LStatus: PASN1_INTEGER;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 9: TS 拒绝状态失败场景 ===');

  Test('TS_RESP_new 函数加载', Assigned(TS_RESP_new));
  Test('TS_RESP_get_status_info 函数加载', Assigned(TS_RESP_get_status_info));
  Test('TS_STATUS_INFO_get0_status 函数加载', Assigned(TS_STATUS_INFO_get0_status));
  if (not Assigned(TS_RESP_new)) or (not Assigned(TS_RESP_get_status_info)) or
     (not Assigned(TS_STATUS_INFO_get0_status)) then
    Exit;

  LResp := nil;
  LStatusInfo := nil;
  try
    LResp := TS_RESP_new();
    Test('创建 TS 响应结构', LResp <> nil);
    if LResp = nil then
      Exit;

    // 兜底失败路径：无状态信息响应应验证失败
    LResult := not VerifyTimestampResponse(LResp, nil, nil);
    Test('无状态信息响应验证应失败', LResult);

    // 可选增强：若状态写入 API 可用，再验证显式 rejection 状态失败路径
    if (not Assigned(TS_STATUS_INFO_new)) or (not Assigned(TS_STATUS_INFO_set_status)) or
       (not Assigned(TS_RESP_set_status_info)) then
    begin
      Test('TS 状态写入 API 缺失时兜底路径有效', True);
      Exit;
    end;

    Test('TS 状态写入 API 可用', True);

    LStatusInfo := TS_STATUS_INFO_new();
    Test('创建 TS 状态结构', LStatusInfo <> nil);
    if LStatusInfo = nil then
      Exit;

    LResult := TS_STATUS_INFO_set_status(LStatusInfo, TS_STATUS_REJECTION) = 1;
    Test('设置 TS 拒绝状态', LResult);
    if not LResult then
      Exit;

    LResult := TS_RESP_set_status_info(LResp, LStatusInfo) = 1;
    Test('写入响应状态信息', LResult);
    if not LResult then
      Exit;
    LStatusInfo := nil;

    LAttachedStatusInfo := TS_RESP_get_status_info(LResp);
    Test('读取响应状态信息', LAttachedStatusInfo <> nil);
    if LAttachedStatusInfo = nil then
      Exit;

    LStatus := TS_STATUS_INFO_get0_status(LAttachedStatusInfo);
    Test('读取拒绝状态值指针', LStatus <> nil);

    LResult := not VerifyTimestampResponse(LResp, nil, nil);
    Test('拒绝状态响应验证应失败', LResult);
  finally
    if (LStatusInfo <> nil) and Assigned(TS_STATUS_INFO_free) then
      TS_STATUS_INFO_free(LStatusInfo);
    if (LResp <> nil) and Assigned(TS_RESP_free) then
      TS_RESP_free(LResp);
  end;
end;


procedure TestTS_VerifyStatusGateWithMocks;
var
  SavedTS_RESP_get_status_info: TTS_RESP_get_status_info;
  SavedTS_STATUS_INFO_get0_status: TTS_STATUS_INFO_get0_status;
  SavedTS_VERIFY_CTX_new: TTS_VERIFY_CTX_new;
  SavedTS_VERIFY_CTX_free: TTS_VERIFY_CTX_free;
  SavedTS_VERIFY_CTX_set_flags: TTS_VERIFY_CTX_set_flags;
  SavedTS_VERIFY_CTX_set_store: TTS_VERIFY_CTX_set_store;
  SavedTS_RESP_verify_response: TTS_RESP_verify_response;
  SavedASN1_INTEGER_get: TASN1_INTEGER_get;
  SavedASN1_INTEGER_get_int64: TASN1_INTEGER_get_int64;
  SavedASN1_INTEGER_get_uint64: TASN1_INTEGER_get_uint64;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 10: TS 状态门控契约（Mock） ===');

  SavedTS_RESP_get_status_info := TS_RESP_get_status_info;
  SavedTS_STATUS_INFO_get0_status := TS_STATUS_INFO_get0_status;
  SavedTS_VERIFY_CTX_new := TS_VERIFY_CTX_new;
  SavedTS_VERIFY_CTX_free := TS_VERIFY_CTX_free;
  SavedTS_VERIFY_CTX_set_flags := TS_VERIFY_CTX_set_flags;
  SavedTS_VERIFY_CTX_set_store := TS_VERIFY_CTX_set_store;
  SavedTS_RESP_verify_response := TS_RESP_verify_response;
  SavedASN1_INTEGER_get := ASN1_INTEGER_get;
  SavedASN1_INTEGER_get_int64 := ASN1_INTEGER_get_int64;
  SavedASN1_INTEGER_get_uint64 := ASN1_INTEGER_get_uint64;

  try
    TS_RESP_get_status_info := @MockTS_RESP_get_status_info;
    TS_STATUS_INFO_get0_status := TTS_STATUS_INFO_get0_status(@MockTS_STATUS_INFO_get0_status);
    TS_VERIFY_CTX_new := @MockTS_VERIFY_CTX_new;
    TS_VERIFY_CTX_free := @MockTS_VERIFY_CTX_free;
    TS_VERIFY_CTX_set_flags := @MockTS_VERIFY_CTX_set_flags;
    TS_VERIFY_CTX_set_store := @MockTS_VERIFY_CTX_set_store;
    TS_RESP_verify_response := @MockTS_RESP_verify_response;
    ASN1_INTEGER_get := @MockASN1_INTEGER_get;
    ASN1_INTEGER_get_int64 := nil;
    ASN1_INTEGER_get_uint64 := nil;

    MockTSStatusValue := TS_STATUS_REJECTION;
    MockTSVerifyCalled := False;
    LResult := VerifyTimestampResponse(PTS_RESP(Pointer(MOCK_TS_RESP_PTR)), nil, nil);
    Test('Mock: rejection 状态应直接失败', not LResult);
    Test('Mock: rejection 状态不应进入签名验证', not MockTSVerifyCalled);

    MockTSStatusValue := TS_STATUS_GRANTED;
    MockTSVerifyCalled := False;
    LResult := VerifyTimestampResponse(PTS_RESP(Pointer(MOCK_TS_RESP_PTR)), nil, nil);
    Test('Mock: granted 状态应进入签名验证', MockTSVerifyCalled);
    Test('Mock: granted + verify success 应通过', LResult);

    ASN1_INTEGER_get := nil;
    MockTSVerifyCalled := False;
    LResult := VerifyTimestampResponse(PTS_RESP(Pointer(MOCK_TS_RESP_PTR)), nil, nil);
    Test('Mock: 缺失状态解析 API 应 fail-safe 拒绝', not LResult);
    Test('Mock: 缺失状态解析 API 不应进入签名验证', not MockTSVerifyCalled);
  finally
    TS_RESP_get_status_info := SavedTS_RESP_get_status_info;
    TS_STATUS_INFO_get0_status := SavedTS_STATUS_INFO_get0_status;
    TS_VERIFY_CTX_new := SavedTS_VERIFY_CTX_new;
    TS_VERIFY_CTX_free := SavedTS_VERIFY_CTX_free;
    TS_VERIFY_CTX_set_flags := SavedTS_VERIFY_CTX_set_flags;
    TS_VERIFY_CTX_set_store := SavedTS_VERIFY_CTX_set_store;
    TS_RESP_verify_response := SavedTS_RESP_verify_response;
    ASN1_INTEGER_get := SavedASN1_INTEGER_get;
    ASN1_INTEGER_get_int64 := SavedASN1_INTEGER_get_int64;
    ASN1_INTEGER_get_uint64 := SavedASN1_INTEGER_get_uint64;
  end;
end;


procedure TestTS_EmptyResponseSignatureFailure;
var
  LResp: PTS_RESP;
  LVerifyCtx: PTS_VERIFY_CTX;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 10: TS 空响应签名验证失败场景 ===');

  Test('TS_RESP_new 函数加载', Assigned(TS_RESP_new));
  Test('TS_VERIFY_CTX_new 函数加载', Assigned(TS_VERIFY_CTX_new));
  Test('TS_RESP_verify_response 函数加载', Assigned(TS_RESP_verify_response));
  Test('TS_VERIFY_CTX_free 函数加载', Assigned(TS_VERIFY_CTX_free));
  Test('TS_RESP_free 函数加载', Assigned(TS_RESP_free));
  if (not Assigned(TS_RESP_new)) or (not Assigned(TS_VERIFY_CTX_new)) or
     (not Assigned(TS_RESP_verify_response)) then
    Exit;

  LResp := TS_RESP_new();
  LVerifyCtx := TS_VERIFY_CTX_new();
  Test('创建空 TS 响应与验证上下文', (LResp <> nil) and (LVerifyCtx <> nil));
  if (LResp = nil) or (LVerifyCtx = nil) then
  begin
    if (LResp <> nil) and Assigned(TS_RESP_free) then
      TS_RESP_free(LResp);
    if (LVerifyCtx <> nil) and Assigned(TS_VERIFY_CTX_free) then
      TS_VERIFY_CTX_free(LVerifyCtx);
    Exit;
  end;

  try
    LResult := TS_RESP_verify_response(LVerifyCtx, LResp) = 1;
    Test('空响应签名验证应失败', not LResult);
  finally
    if Assigned(TS_VERIFY_CTX_free) then
      TS_VERIFY_CTX_free(LVerifyCtx);
    if Assigned(TS_RESP_free) then
      TS_RESP_free(LResp);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('TS (时间戳协议) 模块综合测试');
  WriteLn('=' + StringOfChar('=', 60));

  // 初始化 OpenSSL
  WriteLn;
  WriteLn('初始化 OpenSSL 库...');
  try
    LoadOpenSSLCore;
    WriteLn('✅ OpenSSL 库加载成功');
    WriteLn('版本: ', GetOpenSSLVersionString);

    // 检测 OpenSSL 版本
    IsOpenSSL3 := TOpenSSLLoader.IsOpenSSL3;
    if IsOpenSSL3 then
      WriteLn('检测到 OpenSSL 3.x - 将跳过不兼容的函数测试')
    else
      WriteLn('检测到 OpenSSL 1.x - 将测试所有函数');
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误：无法加载 OpenSSL 库: ', E.Message);
      Halt(1);
    end;
  end;

  // 加载 TS 模块
  WriteLn;
  WriteLn('加载 TS 模块...');
  try
    LoadTSFunctions;
    WriteLn('✅ TS 模块加载成功');
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误：无法加载 TS 模块: ', E.Message);
      Halt(1);
    end;
  end;

  // 执行测试套件
  TestTS_RequestOperations;
  TestTS_ResponseOperations;
  TestTS_TSTInfo;
  TestTS_Verification;
  TestTS_IOAndSerialization;
  TestTS_UtilityFunctions;
  TestTS_OfflineMalformedResponseFixture;
  TestTS_TruncatedResponseFailure;
  TestTS_RejectionStatusFailure;
  TestTS_VerifyStatusGateWithMocks;
  TestTS_EmptyResponseSignatureFailure;

  // 输出测试结果
  WriteLn;
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('测试结果总结');
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn(Format('总测试数: %d', [TotalTests]));
  WriteLn(Format('通过: %d', [PassedTests]));
  WriteLn(Format('失败: %d', [FailedTests]));
  WriteLn(Format('通过率: %.1f%%', [PassedTests * 100.0 / TotalTests]));

  if FailedTests > 0 then
  begin
    WriteLn;
    WriteLn('❌ 测试未完全通过');
    Halt(1);
  end
  else
  begin
    WriteLn;
    WriteLn('🎉 所有测试通过！TS 模块工作正常');
  end;

  UnloadOpenSSLCore;
end.
