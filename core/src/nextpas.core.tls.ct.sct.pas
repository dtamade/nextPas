{
  OpenSSL CT (证书透明度) SCT 验证模块
  实现 RFC 6962 SCT 验证功能
}
unit nextpas.core.tls.ct.sct;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.ct,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.stack;

type
  // SCT 来源类型
  TSCTSource = (
    sctSourceUnknown,
    sctSourceTLSExtension,
    sctSourceX509Extension,
    sctSourceOCSPStapled
  );
  
  // SCT 验证结果
  TSCTValidationResult = record
    IsValid: Boolean;
    Status: Integer;  // SCT_VALIDATION_STATUS_*
    ErrorMessage: string;
    LogName: string;
    Timestamp: UInt64;
  end;
  
  // SCT 验证结果数组
  TSCTValidationResultArray = array of TSCTValidationResult;
  
  // SCT 验证选项
  TSCTValidationOptions = record
    RequireValidSCTs: Boolean;      // 是否要求至少一个有效 SCT
    MinimumSCTCount: Integer;       // 最少 SCT 数量（默认 2）
    AllowUnknownLogs: Boolean;      // 是否允许未知日志
    ClockDriftTolerance: Integer;   // 时钟漂移容差（毫秒，默认 300000 = 5分钟）
    LogStoreFile: string;           // CT 日志存储文件路径
  end;
  
  // SCT 验证器类
  TSCTValidator = class
  private
    FLogStore: PCTLOG_STORE;
    FOptions: TSCTValidationOptions;
    
    function CreateEvalContext(Cert: PX509; Issuer: PX509): PCT_POLICY_EVAL_CTX;
    function ValidateSingleSCT(SCT: PSCT; EvalCtx: PCT_POLICY_EVAL_CTX): TSCTValidationResult;
    function GetSCTSourceType(Source: Integer): TSCTSource;
  public
    constructor Create(const Options: TSCTValidationOptions);
    destructor Destroy; override;
    
    // 从 TLS 连接提取并验证 SCT
    function ValidateFromTLS(SSL: PSSL; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
    
    // 从 X.509 证书扩展提取并验证 SCT
    function ValidateFromX509(Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
    
    // 从 OCSP 响应提取并验证 SCT
    function ValidateFromOCSP(OCSPResp: Pointer; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
    
    // 验证 SCT 列表
    function ValidateSCTList(SCTs: PSCT_LIST; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
    
    // 检查验证结果是否满足策略要求
    function CheckPolicy(const Results: TSCTValidationResultArray): Boolean;
    
    // 加载 CT 日志存储
    function LoadLogStore(const FileName: string = ''): Boolean;
    
    property Options: TSCTValidationOptions read FOptions write FOptions;
  end;

// 辅助函数
function CreateDefaultValidationOptions: TSCTValidationOptions;
function GetSCTValidationStatusName(Status: Integer): string;
function FormatSCTTimestamp(Timestamp: UInt64): string;

implementation

uses
  DateUtils,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader;

{ TSCTValidator }

constructor TSCTValidator.Create(const Options: TSCTValidationOptions);
begin
  inherited Create;
  FOptions := Options;
  FLogStore := nil;
  
  // 加载 CT 日志存储
  if FOptions.LogStoreFile <> '' then
    LoadLogStore(FOptions.LogStoreFile)
  else
    LoadLogStore();  // 使用默认文件
end;

destructor TSCTValidator.Destroy;
begin
  if (FLogStore <> nil) and Assigned(CTLOG_STORE_free) then
    CTLOG_STORE_free(FLogStore);
  inherited;
end;

function TSCTValidator.CreateEvalContext(Cert: PX509; Issuer: PX509): PCT_POLICY_EVAL_CTX;
var
  CurrentTime: UInt64;
begin
  Result := nil;
  
  if not Assigned(CT_POLICY_EVAL_CTX_new) then Exit;
  
  Result := CT_POLICY_EVAL_CTX_new();
  if Result = nil then Exit;
  
  try
    // 设置证书
    if Assigned(CT_POLICY_EVAL_CTX_set1_cert) then
      CT_POLICY_EVAL_CTX_set1_cert(Result, Cert);
    
    // 设置颁发者（对于预证书验证必需）
    if (Issuer <> nil) and Assigned(CT_POLICY_EVAL_CTX_set1_issuer) then
      CT_POLICY_EVAL_CTX_set1_issuer(Result, Issuer);
    
    // 设置日志存储
    if (FLogStore <> nil) and Assigned(CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE) then
      CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE(Result, FLogStore);
    
    // 设置时间（当前时间 + 容差）
    if Assigned(CT_POLICY_EVAL_CTX_set_time) then
    begin
      CurrentTime := UInt64(DateTimeToUnix(Now) * 1000);  // 转换为毫秒
      CurrentTime := CurrentTime + UInt64(FOptions.ClockDriftTolerance);
      CT_POLICY_EVAL_CTX_set_time(Result, CurrentTime);
    end;
  except
    if Assigned(CT_POLICY_EVAL_CTX_free) then
      CT_POLICY_EVAL_CTX_free(Result);
    Result := nil;
    raise;
  end;
end;

function TSCTValidator.ValidateSingleSCT(SCT: PSCT; EvalCtx: PCT_POLICY_EVAL_CTX): TSCTValidationResult;
var
  LogId: PByte;
  LogIdLen: NativeUInt;
  Log: PCTLOG;
begin
  Result.IsValid := False;
  Result.Status := SCT_VALIDATION_STATUS_NOT_SET;
  Result.ErrorMessage := '';
  Result.LogName := '';
  Result.Timestamp := 0;
  
  if (SCT = nil) or (EvalCtx = nil) then
  begin
    Result.ErrorMessage := 'Invalid SCT or evaluation context';
    Exit;
  end;
  
  // 获取时间戳
  if Assigned(SCT_get_timestamp) then
    Result.Timestamp := SCT_get_timestamp(SCT);
  
  // 验证 SCT
  if Assigned(SCT_validate) then
    SCT_validate(SCT, EvalCtx);
  
  // 获取验证状态
  if Assigned(SCT_get_validation_status) then
    Result.Status := SCT_get_validation_status(SCT);
  
  // 获取日志名称
  if Assigned(SCT_get0_log_id) and (FLogStore <> nil) then
  begin
    LogIdLen := SCT_get0_log_id(SCT, @LogId);
    if (LogIdLen > 0) and Assigned(CTLOG_STORE_get0_log_by_id) then
    begin
      Log := CTLOG_STORE_get0_log_by_id(FLogStore, LogId, LogIdLen);
      if (Log <> nil) and Assigned(CTLOG_get0_name) then
        Result.LogName := string(CTLOG_get0_name(Log));
    end;
  end;
  
  // 判断是否有效
  case Result.Status of
    SCT_VALIDATION_STATUS_VALID:
      Result.IsValid := True;
    SCT_VALIDATION_STATUS_UNKNOWN_LOG:
      begin
        Result.ErrorMessage := 'Unknown CT log';
        Result.IsValid := FOptions.AllowUnknownLogs;
      end;
    SCT_VALIDATION_STATUS_INVALID:
      Result.ErrorMessage := 'Invalid SCT signature';
    SCT_VALIDATION_STATUS_UNVERIFIED:
      Result.ErrorMessage := 'SCT could not be verified (missing issuer?)';
    SCT_VALIDATION_STATUS_UNKNOWN_VERSION:
      Result.ErrorMessage := 'Unknown SCT version';
  else
    Result.ErrorMessage := 'Unknown validation status';
  end;
end;

function TSCTValidator.GetSCTSourceType(Source: Integer): TSCTSource;
begin
  case Source of
    SCT_SOURCE_TLS_EXTENSION: Result := sctSourceTLSExtension;
    SCT_SOURCE_X509V3_EXTENSION: Result := sctSourceX509Extension;
    SCT_SOURCE_OCSP_STAPLED_RESPONSE: Result := sctSourceOCSPStapled;
  else
    Result := sctSourceUnknown;
  end;
end;

function TSCTValidator.ValidateFromTLS(SSL: PSSL; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
var
  SCTs: PSCT_LIST;
begin
  SetLength(Result, 0);
  
  if (SSL = nil) or (Cert = nil) then Exit;
  
  // 从 TLS 连接获取 SCT 列表
  if not Assigned(SSL_get0_peer_scts) then Exit;
  
  SCTs := SSL_get0_peer_scts(SSL);
  if SCTs = nil then Exit;
  
  Result := ValidateSCTList(SCTs, Cert, Issuer);
end;

function TSCTValidator.ValidateFromX509(Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
var
  SCTs: PSCT_LIST;
begin
  SetLength(Result, 0);
  
  if Cert = nil then Exit;
  
  // 从 X.509 证书扩展获取 SCT 列表
  if not Assigned(X509_get_ext_d2i) then Exit;
  
  SCTs := PSCT_LIST(X509_get_ext_d2i(Cert, NID_ct_precert_scts, nil, nil));
  if SCTs = nil then Exit;
  
  try
    Result := ValidateSCTList(SCTs, Cert, Issuer);
  finally
    if Assigned(SCT_LIST_free) then
      SCT_LIST_free(SCTs);
  end;
end;

function TSCTValidator.ValidateFromOCSP(OCSPResp: Pointer; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
var
  LOCSPResponse: TOCSPResponse;
  LSignedCertificateTimestampList: TBytes;
  LSignedCertificateTimestampCount: Integer;
  LSCTs: PSCT_LIST;
  LCursor: PByte;
begin
  SetLength(Result, 0);

  if (OCSPResp = nil) or (Cert = nil) then
    Exit;
  if not Assigned(o2i_SCT_LIST) or not Assigned(SCT_LIST_free) then
    Exit;

  LOCSPResponse := TOCSPResponse(OCSPResp);
  if not LOCSPResponse.TryGetSignedCertificateTimestampList(
    LSignedCertificateTimestampList,
    LSignedCertificateTimestampCount
  ) then
    Exit;
  if (Length(LSignedCertificateTimestampList) = 0) or (LSignedCertificateTimestampCount <= 0) then
    Exit;

  LSCTs := nil;
  LCursor := @LSignedCertificateTimestampList[0];
  if o2i_SCT_LIST(@LSCTs, @LCursor, NativeUInt(Length(LSignedCertificateTimestampList))) = nil then
    Exit;

  try
    Result := ValidateSCTList(LSCTs, Cert, Issuer);
  finally
    SCT_LIST_free(LSCTs);
  end;
end;

function TSCTValidator.ValidateSCTList(SCTs: PSCT_LIST; Cert: PX509; Issuer: PX509): TSCTValidationResultArray;
var
  EvalCtx: PCT_POLICY_EVAL_CTX;
  Count, I: Integer;
  SCT: PSCT;
begin
  SetLength(Result, 0);

  if (SCTs = nil) or (Cert = nil) then Exit;

  // 创建评估上下文
  EvalCtx := CreateEvalContext(Cert, Issuer);
  if EvalCtx = nil then Exit;

  try
    // 使用 OpenSSL 的 SCT_LIST_validate 函数验证整个列表
    if Assigned(SCT_LIST_validate) then
      SCT_LIST_validate(SCTs, EvalCtx);

    // 遍历 SCT 列表并收集每个 SCT 的验证结果
    // 使用 OPENSSL_sk_num 获取 SCT 数量
    if not Assigned(OPENSSL_sk_num) then Exit;
    if not Assigned(OPENSSL_sk_value) then Exit;

    Count := OPENSSL_sk_num(POPENSSL_STACK(SCTs));
    if Count <= 0 then Exit;

    SetLength(Result, Count);

    for I := 0 to Count - 1 do
    begin
      // 获取单个 SCT
      SCT := PSCT(OPENSSL_sk_value(POPENSSL_STACK(SCTs), I));
      if SCT <> nil then
        Result[I] := ValidateSingleSCT(SCT, EvalCtx)
      else
      begin
        // SCT 为空，标记为无效
        Result[I].IsValid := False;
        Result[I].Status := SCT_VALIDATION_STATUS_NOT_SET;
        Result[I].ErrorMessage := 'Null SCT at index ' + IntToStr(I);
        Result[I].LogName := '';
        Result[I].Timestamp := 0;
      end;
    end;
  finally
    if Assigned(CT_POLICY_EVAL_CTX_free) then
      CT_POLICY_EVAL_CTX_free(EvalCtx);
  end;
end;

function TSCTValidator.CheckPolicy(const Results: TSCTValidationResultArray): Boolean;
var
  ValidCount: Integer;
  I: Integer;
begin
  Result := False;
  
  // 检查是否有足够的 SCT
  if Length(Results) < FOptions.MinimumSCTCount then
    Exit;
  
  // 统计有效的 SCT 数量
  ValidCount := 0;
  for I := 0 to High(Results) do
  begin
    if Results[I].IsValid then
      Inc(ValidCount);
  end;
  
  // 检查是否满足策略要求
  if FOptions.RequireValidSCTs then
    Result := ValidCount >= FOptions.MinimumSCTCount
  else
    Result := Length(Results) >= FOptions.MinimumSCTCount;
end;

function TSCTValidator.LoadLogStore(const FileName: string): Boolean;
var
  FileNameAnsi: AnsiString;
begin
  Result := False;
  
  // 释放旧的日志存储
  if (FLogStore <> nil) and Assigned(CTLOG_STORE_free) then
  begin
    CTLOG_STORE_free(FLogStore);
    FLogStore := nil;
  end;
  
  if not Assigned(CTLOG_STORE_new) then Exit;
  
  FLogStore := CTLOG_STORE_new();
  if FLogStore = nil then Exit;
  
  if FileName <> '' then
  begin
    // 加载指定文件
    if Assigned(CTLOG_STORE_load_file) then
    begin
      FileNameAnsi := AnsiString(FileName);
      Result := CTLOG_STORE_load_file(FLogStore, PAnsiChar(FileNameAnsi)) = 1;
    end;
  end
  else
  begin
    // 加载默认文件
    if Assigned(CTLOG_STORE_load_default_file) then
      Result := CTLOG_STORE_load_default_file(FLogStore) = 1;
  end;
  
  if not Result then
  begin
    if Assigned(CTLOG_STORE_free) then
      CTLOG_STORE_free(FLogStore);
    FLogStore := nil;
  end;
end;

{ 辅助函数 }

function CreateDefaultValidationOptions: TSCTValidationOptions;
begin
  Result.RequireValidSCTs := True;
  Result.MinimumSCTCount := 2;
  Result.AllowUnknownLogs := False;
  Result.ClockDriftTolerance := 300000;  // 5 分钟
  Result.LogStoreFile := '';
end;

function GetSCTValidationStatusName(Status: Integer): string;
begin
  case Status of
    SCT_VALIDATION_STATUS_NOT_SET: Result := 'Not Set';
    SCT_VALIDATION_STATUS_UNKNOWN_LOG: Result := 'Unknown Log';
    SCT_VALIDATION_STATUS_VALID: Result := 'Valid';
    SCT_VALIDATION_STATUS_INVALID: Result := 'Invalid';
    SCT_VALIDATION_STATUS_UNVERIFIED: Result := 'Unverified';
    SCT_VALIDATION_STATUS_UNKNOWN_VERSION: Result := 'Unknown Version';
  else
    Result := 'Unknown Status';
  end;
end;

function FormatSCTTimestamp(Timestamp: UInt64): string;
var
  UnixTime: Int64;
  DateTime: TDateTime;
begin
  UnixTime := Int64(Timestamp div 1000);  // 转换为秒
  DateTime := UnixToDateTime(UnixTime);
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime);
end;

end.
