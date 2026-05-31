{
  nextpas.core.tls.result.utils - Result 类型转换工具

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-12-27

  描述:
    提供 Result 类型转换工具，用于统一返回类型风格。
    由于核心接口已锁定（@locked 2025-12-24），此模块提供：
    - Boolean -> TSSLOperationResult 转换
    - 异常 -> TSSLOperationResult 转换
    - 链式操作支持
    - 错误上下文增强

  使用示例:
    // 将 Boolean 返回值转换为 Result
    Result := TryOperation(
      function: Boolean begin Result := Cert.LoadFromFile('cert.pem'); end,
      'LoadCertificate'
    );

    // 链式操作
    Result := TryOperation(...)
      .AndThen(function: TSSLOperationResult begin ... end)
      .MapErr(function(E: TSSLErrorCode): TSSLErrorCode begin ... end);
}

unit nextpas.core.tls.result.utils;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base;

type
  { 操作函数类型 }
  TBooleanFunc = function: Boolean;
  TBooleanFuncOfObject = function: Boolean of object;
  TOperationResultFunc = function: TSSLOperationResult;
  TOperationResultFuncOfObject = function: TSSLOperationResult of object;
  TDataResultFunc = function: TSSLDataResult;
  TStringResultFunc = function: TSSLStringResult;
  TErrorMapper = function(ACode: TSSLErrorCode): TSSLErrorCode;
  TBytesMapper = function(const AData: TBytes): TBytes;
  TStringMapper = function(const AValue: string): string;

  { TResultUtils - Result 类型转换工具类 }
  TResultUtils = class
  public
    { Boolean -> TSSLOperationResult 转换 }
    class function FromBool(ASuccess: Boolean;
      const AContext: string = ''): TSSLOperationResult; static;

    { Boolean -> TSSLOperationResult 转换（带自定义错误码）}
    class function FromBoolWithCode(ASuccess: Boolean;
      AErrorCode: TSSLErrorCode;
      const AErrorMsg: string = ''): TSSLOperationResult; static;

    { 执行操作并转换为 Result }
    class function TryOperation(AFunc: TBooleanFunc;
      const AContext: string = ''): TSSLOperationResult; static; overload;
    class function TryOperation(AFunc: TBooleanFuncOfObject;
      const AContext: string = ''): TSSLOperationResult; static; overload;

    { 执行操作并捕获异常 }
    class function TryCatch(AFunc: TBooleanFunc;
      const AContext: string = ''): TSSLOperationResult; static; overload;
    class function TryCatch(AFunc: TBooleanFuncOfObject;
      const AContext: string = ''): TSSLOperationResult; static; overload;

    { 从异常创建错误 Result }
    class function FromException(E: Exception;
      const AContext: string = ''): TSSLOperationResult; static;

    { 合并多个 Result（全部成功才成功）}
    class function All(const AResults: array of TSSLOperationResult): TSSLOperationResult; static;

    { 合并多个 Result（任一成功即成功）}
    class function Any(const AResults: array of TSSLOperationResult): TSSLOperationResult; static;
  end;

  { TSSLOperationResultHelper - TSSLOperationResult 扩展方法 }
  TSSLOperationResultHelper = record helper for TSSLOperationResult
    { 链式操作：成功时执行下一个操作 }
    function AndThen(AFunc: TOperationResultFunc): TSSLOperationResult; overload;
    function AndThen(AFunc: TOperationResultFuncOfObject): TSSLOperationResult; overload;
    function AndThen(AFunc: TBooleanFunc; const AContext: string = ''): TSSLOperationResult; overload;
    function AndThen(AFunc: TBooleanFuncOfObject; const AContext: string = ''): TSSLOperationResult; overload;

    { 错误映射：转换错误码 }
    function MapErr(AMapper: TErrorMapper): TSSLOperationResult;

    { 添加上下文信息 }
    function WithContext(const AContext: string): TSSLOperationResult;

    { 转换为字符串（用于日志）}
    function ToString: string;

    { 忽略错误，返回默认成功 }
    function OrElse(ADefault: TSSLOperationResult): TSSLOperationResult;
  end;

  { TSSLDataResultHelper - TSSLDataResult 扩展方法 }
  TSSLDataResultHelper = record helper for TSSLDataResult
    { 链式操作 }
    function AndThen(AFunc: TDataResultFunc): TSSLDataResult;

    { 映射数据 }
    function Map(AMapper: TBytesMapper): TSSLDataResult;

    { 添加上下文 }
    function WithContext(const AContext: string): TSSLDataResult;

    { 转换为字符串 }
    function ToString: string;
  end;

  { TSSLStringResultHelper - TSSLStringResult 扩展方法 }
  TSSLStringResultHelper = record helper for TSSLStringResult
    { 链式操作 }
    function AndThen(AFunc: TStringResultFunc): TSSLStringResult;

    { 映射值 }
    function Map(AMapper: TStringMapper): TSSLStringResult;

    { 添加上下文 }
    function WithContext(const AContext: string): TSSLStringResult;

    { 转换为字符串 }
    function ToString: string;
  end;

{ 便捷函数 }

{ 快速创建成功 Result }
function Ok: TSSLOperationResult; inline;
function OkData(const AData: TBytes): TSSLDataResult; inline;
function OkString(const AValue: string): TSSLStringResult; inline;

{ 快速创建错误 Result }
function Err(ACode: TSSLErrorCode; const AMsg: string = ''): TSSLOperationResult; inline;
function ErrData(ACode: TSSLErrorCode; const AMsg: string = ''): TSSLDataResult; inline;
function ErrString(ACode: TSSLErrorCode; const AMsg: string = ''): TSSLStringResult; inline;

{ 从 Boolean 转换 }
function ToResult(ASuccess: Boolean; const AContext: string = ''): TSSLOperationResult; inline;

implementation

uses
  nextpas.core.tls.exceptions;

{ TResultUtils }

class function TResultUtils.FromBool(ASuccess: Boolean;
  const AContext: string): TSSLOperationResult;
begin
  if ASuccess then
    Result := TSSLOperationResult.Ok
  else
  begin
    if AContext <> '' then
      Result := TSSLOperationResult.Err(sslErrGeneral, AContext + ' failed')
    else
      Result := TSSLOperationResult.Err(sslErrGeneral, 'Operation failed');
  end;
end;

class function TResultUtils.FromBoolWithCode(ASuccess: Boolean;
  AErrorCode: TSSLErrorCode; const AErrorMsg: string): TSSLOperationResult;
begin
  if ASuccess then
    Result := TSSLOperationResult.Ok
  else
    Result := TSSLOperationResult.Err(AErrorCode, AErrorMsg);
end;

class function TResultUtils.TryOperation(AFunc: TBooleanFunc;
  const AContext: string): TSSLOperationResult;
begin
  Result := FromBool(AFunc(), AContext);
end;

class function TResultUtils.TryOperation(AFunc: TBooleanFuncOfObject;
  const AContext: string): TSSLOperationResult;
begin
  Result := FromBool(AFunc(), AContext);
end;

class function TResultUtils.TryCatch(AFunc: TBooleanFunc;
  const AContext: string): TSSLOperationResult;
begin
  try
    Result := FromBool(AFunc(), AContext);
  except
    on E: Exception do
      Result := FromException(E, AContext);
  end;
end;

class function TResultUtils.TryCatch(AFunc: TBooleanFuncOfObject;
  const AContext: string): TSSLOperationResult;
begin
  try
    Result := FromBool(AFunc(), AContext);
  except
    on E: Exception do
      Result := FromException(E, AContext);
  end;
end;

class function TResultUtils.FromException(E: Exception;
  const AContext: string): TSSLOperationResult;
var
  LCode: TSSLErrorCode;
  LMsg: string;
begin
  // 根据异常类型确定错误码
  if E is ESSLCertError then
    LCode := sslErrCertificate
  else if E is ESSLHandshakeException then
    LCode := sslErrHandshake
  else if E is ESSLConnectionException then
    LCode := sslErrConnection
  else if E is ESSLProtocolException then
    LCode := sslErrProtocol
  else if E is ESSLConfigurationException then
    LCode := sslErrConfiguration
  else if E is ESSLInitError then
    LCode := sslErrLibraryNotFound
  else if E is EOutOfMemory then
    LCode := sslErrMemory
  else
    LCode := sslErrGeneral;

  if AContext <> '' then
    LMsg := Format('%s: %s', [AContext, E.Message])
  else
    LMsg := E.Message;

  Result := TSSLOperationResult.Err(LCode, LMsg);
end;

class function TResultUtils.All(const AResults: array of TSSLOperationResult): TSSLOperationResult;
var
  I: Integer;
begin
  for I := Low(AResults) to High(AResults) do
  begin
    if AResults[I].IsErr then
      Exit(AResults[I]);
  end;
  Result := TSSLOperationResult.Ok;
end;

class function TResultUtils.Any(const AResults: array of TSSLOperationResult): TSSLOperationResult;
var
  I: Integer;
  LLastErr: TSSLOperationResult;
begin
  LLastErr := TSSLOperationResult.Err(sslErrGeneral, 'No operations provided');

  for I := Low(AResults) to High(AResults) do
  begin
    if AResults[I].IsOk then
      Exit(AResults[I]);
    LLastErr := AResults[I];
  end;

  Result := LLastErr;
end;

{ TSSLOperationResultHelper }

function TSSLOperationResultHelper.AndThen(AFunc: TOperationResultFunc): TSSLOperationResult;
begin
  if Self.IsOk then
    Result := AFunc()
  else
    Result := Self;
end;

function TSSLOperationResultHelper.AndThen(AFunc: TOperationResultFuncOfObject): TSSLOperationResult;
begin
  if Self.IsOk then
    Result := AFunc()
  else
    Result := Self;
end;

function TSSLOperationResultHelper.AndThen(AFunc: TBooleanFunc;
  const AContext: string): TSSLOperationResult;
begin
  if Self.IsOk then
    Result := TResultUtils.FromBool(AFunc(), AContext)
  else
    Result := Self;
end;

function TSSLOperationResultHelper.AndThen(AFunc: TBooleanFuncOfObject;
  const AContext: string): TSSLOperationResult;
begin
  if Self.IsOk then
    Result := TResultUtils.FromBool(AFunc(), AContext)
  else
    Result := Self;
end;

function TSSLOperationResultHelper.MapErr(AMapper: TErrorMapper): TSSLOperationResult;
begin
  if Self.IsErr then
  begin
    Result := Self;
    Result.ErrorCode := AMapper(Self.ErrorCode);
  end
  else
    Result := Self;
end;

function TSSLOperationResultHelper.WithContext(const AContext: string): TSSLOperationResult;
begin
  Result := Self;
  if Self.IsErr and (AContext <> '') then
  begin
    if Self.ErrorMessage <> '' then
      Result.ErrorMessage := AContext + ': ' + Self.ErrorMessage
    else
      Result.ErrorMessage := AContext;
  end;
end;

function TSSLOperationResultHelper.ToString: string;
begin
  if Self.IsOk then
    Result := 'Ok'
  else
    Result := Format('Err(%d: %s)', [Ord(Self.ErrorCode), Self.ErrorMessage]);
end;

function TSSLOperationResultHelper.OrElse(ADefault: TSSLOperationResult): TSSLOperationResult;
begin
  if Self.IsOk then
    Result := Self
  else
    Result := ADefault;
end;

{ TSSLDataResultHelper }

function TSSLDataResultHelper.AndThen(AFunc: TDataResultFunc): TSSLDataResult;
begin
  if Self.IsOk then
    Result := AFunc()
  else
    Result := Self;
end;

function TSSLDataResultHelper.Map(AMapper: TBytesMapper): TSSLDataResult;
begin
  if Self.IsOk then
    Result := TSSLDataResult.Ok(AMapper(Self.Data))
  else
    Result := Self;
end;

function TSSLDataResultHelper.WithContext(const AContext: string): TSSLDataResult;
begin
  Result := Self;
  if Self.IsErr and (AContext <> '') then
  begin
    if Self.ErrorMessage <> '' then
      Result.ErrorMessage := AContext + ': ' + Self.ErrorMessage
    else
      Result.ErrorMessage := AContext;
  end;
end;

function TSSLDataResultHelper.ToString: string;
begin
  if Self.IsOk then
    Result := Format('Ok(%d bytes)', [Length(Self.Data)])
  else
    Result := Format('Err(%d: %s)', [Ord(Self.ErrorCode), Self.ErrorMessage]);
end;

{ TSSLStringResultHelper }

function TSSLStringResultHelper.AndThen(AFunc: TStringResultFunc): TSSLStringResult;
begin
  if Self.IsOk then
    Result := AFunc()
  else
    Result := Self;
end;

function TSSLStringResultHelper.Map(AMapper: TStringMapper): TSSLStringResult;
begin
  if Self.IsOk then
    Result := TSSLStringResult.Ok(AMapper(Self.Value))
  else
    Result := Self;
end;

function TSSLStringResultHelper.WithContext(const AContext: string): TSSLStringResult;
begin
  Result := Self;
  if Self.IsErr and (AContext <> '') then
  begin
    if Self.ErrorMessage <> '' then
      Result.ErrorMessage := AContext + ': ' + Self.ErrorMessage
    else
      Result.ErrorMessage := AContext;
  end;
end;

function TSSLStringResultHelper.ToString: string;
begin
  if Self.IsOk then
    Result := Format('Ok("%s")', [Self.Value])
  else
    Result := Format('Err(%d: %s)', [Ord(Self.ErrorCode), Self.ErrorMessage]);
end;

{ 便捷函数 }

function Ok: TSSLOperationResult;
begin
  Result := TSSLOperationResult.Ok;
end;

function OkData(const AData: TBytes): TSSLDataResult;
begin
  Result := TSSLDataResult.Ok(AData);
end;

function OkString(const AValue: string): TSSLStringResult;
begin
  Result := TSSLStringResult.Ok(AValue);
end;

function Err(ACode: TSSLErrorCode; const AMsg: string): TSSLOperationResult;
begin
  Result := TSSLOperationResult.Err(ACode, AMsg);
end;

function ErrData(ACode: TSSLErrorCode; const AMsg: string): TSSLDataResult;
begin
  Result := TSSLDataResult.Err(ACode, AMsg);
end;

function ErrString(ACode: TSSLErrorCode; const AMsg: string): TSSLStringResult;
begin
  Result := TSSLStringResult.Err(ACode, AMsg);
end;

function ToResult(ASuccess: Boolean; const AContext: string): TSSLOperationResult;
begin
  Result := TResultUtils.FromBool(ASuccess, AContext);
end;

end.
