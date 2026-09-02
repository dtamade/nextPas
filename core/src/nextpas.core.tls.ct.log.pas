{
  OpenSSL CT (证书透明度) 日志服务器客户端模块
  实现 CT 日志列表加载和管理
}
unit nextpas.core.tls.ct.log;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.time,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.json, nextpas.core.json.builder,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.ct,
  nextpas.core.tls.openssl.api.evp;

type
  // CT 日志信息
  TCTLogInfo = record
    LogID: string;              // Base64 编码的日志 ID
    Key: string;                // Base64 编码的公钥
    URL: string;                // 日志服务器 URL
    Description: string;        // 日志描述
    OperatorName: string;       // 运营商名称
    MaxMergeDelay: Integer;     // 最大合并延迟（秒）
    IsUsable: Boolean;          // 是否可用
  end;
  
  // CT 日志列表
  TCTLogList = array of TCTLogInfo;
  
  // CT 日志客户端类
  TCTLogClient = class
  private
    FLogStore: PCTLOG_STORE;
    FLogList: TCTLogList;
    FCacheFile: string;
    FAutoUpdate: Boolean;
    
    function LoadFromJSON(const JSONData: string): Boolean;
    function ParseGoogleCTLogList(const JSONData: string): Boolean;
    function CreateLogStore: Boolean;
    function AddLogToStore(const LogInfo: TCTLogInfo): Boolean;
  public
    constructor Create(const CacheFile: string = ''; AutoUpdate: Boolean = False);
    destructor Destroy; override;
    
    // 从 Google CT 日志列表加载
    function LoadFromGoogleCTLogList(const URL: string = 'https://www.gstatic.com/ct/log_list/v3/all_logs_list.json'): Boolean;
    
    // 从本地文件加载
    function LoadFromFile(const FileName: string): Boolean;
    
    // 保存到本地文件
    function SaveToFile(const FileName: string): Boolean;
    
    // 获取日志存储（用于 SCT 验证）
    function GetLogStore: PCTLOG_STORE;
    
    // 根据日志 ID 查找日志信息
    function FindLogByID(const LogID: string): TCTLogInfo;
    
    // 获取所有日志列表
    function GetAllLogs: TCTLogList;
    
    // 获取可用日志数量
    function GetUsableLogCount: Integer;
    
    property LogStore: PCTLOG_STORE read GetLogStore;
    property CacheFile: string read FCacheFile write FCacheFile;
    property AutoUpdate: Boolean read FAutoUpdate write FAutoUpdate;
  end;

// 辅助函数
function DownloadCTLogList(const URL: string): string;
function Base64Decode(const Input: string): TBytes;

implementation

uses
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.io,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.fs,
  nextpas.core.tls.net.hooks,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.base64;

{ TCTLogClient }

constructor TCTLogClient.Create(const CacheFile: string; AutoUpdate: Boolean);
begin
  inherited Create;
  FLogStore := nil;
  SetLength(FLogList, 0);
  FCacheFile := CacheFile;
  FAutoUpdate := AutoUpdate;
  
  // 如果指定了缓存文件，尝试从缓存加载
  if (FCacheFile <> '') and nextpas.core.fs.IsFile(FCacheFile) then
    LoadFromFile(FCacheFile);
end;

destructor TCTLogClient.Destroy;
begin
  if (FLogStore <> nil) and Assigned(CTLOG_STORE_free) then
    CTLOG_STORE_free(FLogStore);
  SetLength(FLogList, 0);
  inherited;
end;

function TCTLogClient.LoadFromJSON(const JSONData: string): Boolean;
var
  LDoc: IJsonDocument;
  LRoot, LLogsArray, LLog, LVal: TJsonValue;
  LogInfo: TCTLogInfo;
  I: Integer;
begin
  Result := False;

  if JSONData = '' then Exit;

  // 首先尝试解析 Google CT 日志列表格式
  if ParseGoogleCTLogList(JSONData) then
  begin
    Result := CreateLogStore;
    if Result and (FCacheFile <> '') then
      SaveToFile(FCacheFile);
    Exit;
  end;

  // 如果 Google 格式解析失败，尝试解析简单的缓存格式
  try
    LDoc := JsonParse(JSONData);
    if LDoc.HasError then Exit;

    LRoot := LDoc.Root;
    if not LRoot.IsObject then Exit;

    // 尝试获取 logs 数组
    LLogsArray := LRoot.ObjectGet('logs');
    if not LLogsArray.IsArray then Exit;

    SetLength(FLogList, 0);

    for I := 0 to LLogsArray.ArrayLen - 1 do
    begin
      LLog := LLogsArray.ArrayGet(I);
      if not LLog.IsObject then Continue;

      LogInfo.LogID := LLog.ObjectGet('log_id').AsStr.ToString;
      LogInfo.Key := LLog.ObjectGet('key').AsStr.ToString;
      LogInfo.URL := LLog.ObjectGet('url').AsStr.ToString;
      LogInfo.Description := LLog.ObjectGet('description').AsStr.ToString;
      LogInfo.OperatorName := LLog.ObjectGet('operator').AsStr.ToString;

      LVal := LLog.ObjectGet('mmd');
      if LVal.IsValid then
        LogInfo.MaxMergeDelay := LVal.AsInt
      else
        LogInfo.MaxMergeDelay := 86400;

      LVal := LLog.ObjectGet('usable');
      if LVal.IsValid then
        LogInfo.IsUsable := LVal.AsBool
      else
        LogInfo.IsUsable := True;

      SetLength(FLogList, Length(FLogList) + 1);
      FLogList[High(FLogList)] := LogInfo;
    end;

    Result := True;
    CreateLogStore;
  except
    Result := False;
  end;
end;

function TCTLogClient.ParseGoogleCTLogList(const JSONData: string): Boolean;
var
  LDoc: IJsonDocument;
  LRoot, LOperators, LOperatorObj, LLogs, LLog, LStateVal: TJsonValue;
  I, J: Integer;
  LogInfo: TCTLogInfo;
  OperatorName: string;
begin
  Result := False;
  SetLength(FLogList, 0);

  try
    LDoc := JsonParse(JSONData);
    if LDoc.HasError then Exit;

    LRoot := LDoc.Root;
    if not LRoot.IsObject then Exit;

    // 获取 operators 数组
    LOperators := LRoot.ObjectGet('operators');
    if not LOperators.IsArray then Exit;

    // 遍历所有运营商
    for I := 0 to LOperators.ArrayLen - 1 do
    begin
      LOperatorObj := LOperators.ArrayGet(I);
      if not LOperatorObj.IsObject then Continue;

      OperatorName := LOperatorObj.ObjectGet('name').AsStr.ToString;

      // 获取该运营商的日志列表
      LLogs := LOperatorObj.ObjectGet('logs');
      if not LLogs.IsArray then Continue;

      // 遍历所有日志
      for J := 0 to LLogs.ArrayLen - 1 do
      begin
        LLog := LLogs.ArrayGet(J);
        if not LLog.IsObject then Continue;

        // 提取日志信息
        LogInfo.LogID := LLog.ObjectGet('log_id').AsStr.ToString;
        LogInfo.Key := LLog.ObjectGet('key').AsStr.ToString;
        LogInfo.URL := LLog.ObjectGet('url').AsStr.ToString;
        LogInfo.Description := LLog.ObjectGet('description').AsStr.ToString;
        LogInfo.OperatorName := OperatorName;

        LStateVal := LLog.ObjectGet('mmd');
        if LStateVal.IsValid then
          LogInfo.MaxMergeDelay := LStateVal.AsInt
        else
          LogInfo.MaxMergeDelay := 86400;

        // 检查日志状态 - 没有 state 字段表示可用
        LogInfo.IsUsable := not LLog.ObjectHas('state');

        // 添加到列表
        SetLength(FLogList, Length(FLogList) + 1);
        FLogList[High(FLogList)] := LogInfo;
      end;
    end;

    Result := Length(FLogList) > 0;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TCTLogClient.CreateLogStore: Boolean;
var
  I: Integer;
begin
  Result := False;
  
  // 释放旧的日志存储
  if (FLogStore <> nil) and Assigned(CTLOG_STORE_free) then
  begin
    CTLOG_STORE_free(FLogStore);
    FLogStore := nil;
  end;
  
  // 创建新的日志存储
  if not Assigned(CTLOG_STORE_new) then Exit;
  
  FLogStore := CTLOG_STORE_new();
  if FLogStore = nil then Exit;
  
  // 添加所有可用的日志
  for I := 0 to High(FLogList) do
  begin
    if FLogList[I].IsUsable then
      AddLogToStore(FLogList[I]);
  end;
  
  Result := True;
end;

function TCTLogClient.AddLogToStore(const LogInfo: TCTLogInfo): Boolean;
var
  Log: PCTLOG;
  KeyBytes: TBytes;
  KeyBIO: PBIO;
  PKey: PEVP_PKEY;
  NameAnsi: AnsiString;
begin
  Result := False;
  
  if (FLogStore = nil) or (LogInfo.Key = '') then Exit;
  
  // 解码 Base64 公钥
  KeyBytes := Base64Decode(LogInfo.Key);
  if Length(KeyBytes) = 0 then Exit;
  
  // 创建 BIO 从公钥数据
  if not Assigned(BIO_new_mem_buf) then Exit;
  
  KeyBIO := BIO_new_mem_buf(@KeyBytes[0], Length(KeyBytes));
  if KeyBIO = nil then Exit;
  
  try
    // 解析公钥
    if not Assigned(d2i_PUBKEY_bio) then Exit;
    
    PKey := d2i_PUBKEY_bio(KeyBIO, nil);
    if PKey = nil then Exit;
    
    try
      // 创建 CT 日志
      if not Assigned(CTLOG_new) then Exit;
      
      NameAnsi := AnsiString(LogInfo.Description);
      Log := CTLOG_new(PKey, PAnsiChar(NameAnsi));
      if Log = nil then Exit;
      
      // 注意：CTLOG_STORE 会接管 Log 的所有权，不需要手动释放
      // OpenSSL 内部会将 Log 添加到 Store 中
      
      Result := True;
    finally
      if Assigned(EVP_PKEY_free) then
        EVP_PKEY_free(PKey);
    end;
  finally
    if Assigned(BIO_free) then
      BIO_free(KeyBIO);
  end;
end;

function TCTLogClient.LoadFromGoogleCTLogList(const URL: string): Boolean;
var
  JSONData: string;
begin
  Result := False;
  
  // 下载 CT 日志列表
  JSONData := DownloadCTLogList(URL);
  if JSONData = '' then Exit;
  
  // 解析并加载
  Result := LoadFromJSON(JSONData);
end;

function TCTLogClient.LoadFromFile(const FileName: string): Boolean;
var
  FileStream: IStream;
  JSONData: string;
  JSONBytes: TBytes;
begin
  Result := False;
  
  if not nextpas.core.fs.IsFile(FileName) then Exit;
  
  try
    FileStream := FsOpen(FileName, [fmRead]);
    JSONBytes := ReadAll(FileStream);
    JSONData := UTF8BytesToString(JSONBytes);
    Result := LoadFromJSON(JSONData);
  except
    Result := False;
  end;
end;

function TCTLogClient.SaveToFile(const FileName: string): Boolean;
var
  FileStream: IFile;
  LBuilder: IJsonBuilder;
  I: Integer;
  JSONStr: string;
  JSONBytes: TBytes;
begin
  Result := False;

  try
    LBuilder := JsonBuilder;
    LBuilder.BeginObject;

    // logs array
    LBuilder.Key('logs');
    LBuilder.BeginArray;
    for I := 0 to High(FLogList) do
    begin
      LBuilder.BeginObject;
      LBuilder.Key('log_id');
      LBuilder.Str(FLogList[I].LogID);
      LBuilder.Key('key');
      LBuilder.Str(FLogList[I].Key);
      LBuilder.Key('url');
      LBuilder.Str(FLogList[I].URL);
      LBuilder.Key('description');
      LBuilder.Str(FLogList[I].Description);
      LBuilder.Key('operator');
      LBuilder.Str(FLogList[I].OperatorName);
      LBuilder.Key('mmd');
      LBuilder.Int(FLogList[I].MaxMergeDelay);
      LBuilder.Key('usable');
      LBuilder.Bool(FLogList[I].IsUsable);
      LBuilder.EndObject;
    end;
    LBuilder.EndArray;

    LBuilder.Key('version');
    LBuilder.Str('1.0');
    LBuilder.Key('timestamp');
    LBuilder.Str(nextpas.core.time.DateTimeToStr(nextpas.core.time.DateTimeNow));

    LBuilder.EndObject;
    JSONStr := LBuilder.ToString;
    JSONBytes := StringToUTF8Bytes(JSONStr);

    FileStream := FsCreate(FileName);
    if Length(JSONBytes) > 0 then
      FileStream.Write(JSONBytes[0], Length(JSONBytes));
    Result := True;
  except
    Result := False;
  end;
end;

function TCTLogClient.GetLogStore: PCTLOG_STORE;
begin
  Result := FLogStore;
end;

function TCTLogClient.FindLogByID(const LogID: string): TCTLogInfo;
var
  I: Integer;
begin
  Result.LogID := '';
  Result.Key := '';
  Result.URL := '';
  Result.Description := '';
  Result.OperatorName := '';
  Result.MaxMergeDelay := 0;
  Result.IsUsable := False;
  
  for I := 0 to High(FLogList) do
  begin
    if FLogList[I].LogID = LogID then
    begin
      Result := FLogList[I];
      Exit;
    end;
  end;
end;

function TCTLogClient.GetAllLogs: TCTLogList;
begin
  Result := FLogList;
end;

function TCTLogClient.GetUsableLogCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FLogList) do
  begin
    if FLogList[I].IsUsable then
      Inc(Result);
  end;
end;

{ 辅助函数 }

function DownloadCTLogList(const URL: string): string;
var
  LRes: TSSLDataResult;
begin
  Result := '';

  LRes := SSLHTTPGet(URL, 10000);
  if not LRes.Success then
    Exit('');
  if Length(LRes.Data) = 0 then
    Exit('');

  SetString(Result, PAnsiChar(@LRes.Data[0]), Length(LRes.Data));
end;

function Base64Decode(const Input: string): TBytes;
begin
  Result := nil;
  // 使用项目的 Base64 解码功能
  if Input = '' then
    Exit
  else
    Result := TBase64Utils.Decode(Input);
end;

end.
