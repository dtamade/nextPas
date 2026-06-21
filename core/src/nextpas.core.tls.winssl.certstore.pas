{
  nextpas.core.tls.winssl.certstore - WinSSL 证书存储实现

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-09

  描述:
    实现 ISSLCertificateStore 接口的 WinSSL 后端。
    封装 Windows 证书存储（ROOT, MY, CA, TRUST 等）操作。
}

unit nextpas.core.tls.winssl.certstore;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  Windows, SysUtils, nextpas.core.system.classes, nextpas.core.fs, nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.native_handle,
  nextpas.core.tls.winssl.certificate;

type
  { TWinSSLCertificateStore - Windows 证书存储类 }
  TWinSSLCertificateStore = class(TInterfacedObject, ISSLCertificateStore, ISSLNativeHandleAccess)
  private
    FStoreHandle: HCERTSTORE;
    FStoreName: string;
    FOwnsHandle: Boolean;
    FCertificates: TList;  // 缓存的证书列表

    procedure ClearCache;
    procedure LoadCertificates;

  public
    constructor Create(const AStoreName: string); overload;
    constructor Create(AStoreHandle: HCERTSTORE; AOwnsHandle: Boolean = False); overload;
    destructor Destroy; override;

    { ISSLCertificateStore - 存储管理 }
    function Open(const AName: string; AWritable: Boolean = False): Boolean;
    procedure Close;
    function IsOpen: Boolean;

    { ISSLCertificateStore - 证书操作 }
    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;

    { ISSLCertificateStore - 证书查询 }
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;
    function GetAllCertificates: TSSLCertificateArray;

    { ISSLCertificateStore - 证书加载 }
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean;

    { ISSLCertificateStore - 证书搜索 }
    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;

    { ISSLCertificateStore - 证书验证 }
    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { 额外的辅助方法（不在接口中） }
    function OpenSystemStore(const AStoreName: string): Boolean;
    function GetSystemStoreNames: TStringArray;
  end;

{ 工厂函数 }
function CreateWinSSLCertificateStore(const AStoreName: string): ISSLCertificateStore;
function OpenSystemStore(const AStoreName: string): ISSLCertificateStore;

{ 常见系统存储名称 }
const
  SSL_STORE_ROOT = 'ROOT';          // 受信任根证书
  SSL_STORE_MY = 'MY';              // 个人证书
  SSL_STORE_CA = 'CA';              // 中间证书颁发机构
  SSL_STORE_TRUST = 'Trust';        // 企业信任
  SSL_STORE_DISALLOWED = 'Disallowed'; // 不受信任的证书

implementation

uses
  nextpas.core.text.strings,
    nextpas.core.tls.secure.compare;  // Phase 3.3 P1: 使用独立的常量时间比较模块
                               // 修复: 原来使用 nextpas.core.tls.secure 导致间接依赖 OpenSSL
                               // 现在使用不依赖 OpenSSL 的独立模块

// ============================================================================
// 工厂函数
// ============================================================================

function CreateWinSSLCertificateStore(const AStoreName: string): ISSLCertificateStore;
begin
  Result := TWinSSLCertificateStore.Create(AStoreName);
end;

function OpenSystemStore(const AStoreName: string): ISSLCertificateStore;
var
  Store: TWinSSLCertificateStore;
begin
  Store := TWinSSLCertificateStore.Create('');
  if Store.OpenSystemStore(AStoreName) then
    Result := Store
  else
  begin
    Result := nil;
  end;
end;

// ============================================================================
// TWinSSLCertificateStore - 构造和析构
// ============================================================================

constructor TWinSSLCertificateStore.Create(const AStoreName: string);
begin
  inherited Create;
  FStoreHandle := nil;
  FStoreName := AStoreName;
  FOwnsHandle := True;
  FCertificates := TList.Create;

  if AStoreName <> '' then
    OpenSystemStore(AStoreName);
end;

constructor TWinSSLCertificateStore.Create(AStoreHandle: HCERTSTORE; AOwnsHandle: Boolean = False);
begin
  inherited Create;
  FStoreHandle := AStoreHandle;
  FStoreName := '';
  FOwnsHandle := AOwnsHandle;
  FCertificates := TList.Create;

  if AStoreHandle <> nil then
    LoadCertificates;
end;

destructor TWinSSLCertificateStore.Destroy;
begin
  ClearCache;

  if FOwnsHandle and (FStoreHandle <> nil) then
    CertCloseStore(FStoreHandle, 0);

  inherited Destroy;
end;

// ============================================================================
// 内部辅助方法
// ============================================================================

procedure TWinSSLCertificateStore.ClearCache;
var
  i: Integer;
begin
  for i := 0 to Length(FCertificates) - 1 do
    ISSLCertificate(FCertificates[i])._Release;
  FCertificates.Clear;
end;

procedure TWinSSLCertificateStore.LoadCertificates;
var
  CertContext: PCCERT_CONTEXT;
  Cert: ISSLCertificate;
begin
  ClearCache;

  if FStoreHandle = nil then
    Exit;

  // 枚举存储中的所有证书
  CertContext := nil;
  repeat
    CertContext := CertEnumCertificatesInStore(FStoreHandle, CertContext);
    if CertContext <> nil then
    begin
      // 创建证书对象（不拥有上下文，因为它由枚举器管理）
      Cert := CreateWinSSLCertificateFromContext(
        CertDuplicateCertificateContext(CertContext),
        True
      );
      Cert._AddRef;
      FCertificates.Add(Pointer(Cert));
    end;
  until CertContext = nil;
end;

function NormalizeCertificateStoreDN(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
  Result := StringReplace(Result, ' , ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ', ', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' ,', ',', [rfReplaceAll]);
  Result := StringReplace(Result, ' = ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, '= ', '=', [rfReplaceAll]);
  Result := StringReplace(Result, ' =', '=', [rfReplaceAll]);
end;

function NormalizeCertificateStoreHex(const AValue: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    LChar := UpCase(AValue[I]);
    if LChar in ['0'..'9', 'A'..'F'] then
      Result := Result + LChar;
  end;
end;

function CertNameBlobToX500String(AName: PCERT_NAME_BLOB): string;
var
  LSize: DWORD;
  LWritten: DWORD;
  LBuffer: UnicodeString;
begin
  Result := '';
  if (AName = nil) or (AName^.cbData = 0) or (AName^.pbData = nil) then
    Exit;

  LSize := CertNameToStrW(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    AName,
    CERT_X500_NAME_STR or CERT_NAME_STR_COMMA_FLAG,
    nil,
    0
  );
  if LSize <= 1 then
    Exit;

  SetLength(LBuffer, LSize);
  LWritten := CertNameToStrW(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    AName,
    CERT_X500_NAME_STR or CERT_NAME_STR_COMMA_FLAG,
    PWideChar(LBuffer),
    LSize
  );
  if LWritten <= 1 then
    Exit;

  SetLength(LBuffer, LWritten - 1);
  Result := UTF8Encode(WideString(LBuffer));
end;

function GetCertificateStoreDNText(ACert: ISSLCertificate; AUseIssuer: Boolean): string;
var
  LContext: PCCERT_CONTEXT;
  LCertInfo: PCERT_INFO;
begin
  Result := '';
  if ACert = nil then
    Exit;

  LContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLCertificateStore'));
  if (LContext <> nil) and (LContext^.pCertInfo <> nil) then
  begin
    LCertInfo := PCERT_INFO(LContext^.pCertInfo);
    if AUseIssuer then
      Result := CertNameBlobToX500String(@LCertInfo^.Issuer)
    else
      Result := CertNameBlobToX500String(@LCertInfo^.Subject);
  end;

  if Result <> '' then
    Exit;

  if AUseIssuer then
    Result := ACert.GetIssuer
  else
    Result := ACert.GetSubject;
end;

function CandidateHasDNComponent(const ACandidate, AComponent: string): Boolean;
begin
  Result := False;
  if (ACandidate = '') or (AComponent = '') then
    Exit;

  if ACandidate = AComponent then
    Exit(True);

  Result := Pos(',' + AComponent + ',', ',' + ACandidate + ',') > 0;
end;

function CandidateContainsAllDNComponents(const ACandidate, ATarget: string): Boolean;
var
  LStart: Integer;
  LStop: Integer;
  LComponent: string;
begin
  Result := False;
  if (ACandidate = '') or (ATarget = '') or (Pos('=', ATarget) = 0) then
    Exit;

  LStart := 1;
  while LStart <= Length(ATarget) do
  begin
    LStop := LStart;
    while (LStop <= Length(ATarget)) and (ATarget[LStop] <> ',') do
      Inc(LStop);

    LComponent := Copy(ATarget, LStart, LStop - LStart);
    if (LComponent = '') or (not CandidateHasDNComponent(ACandidate, LComponent)) then
      Exit(False);

    LStart := LStop + 1;
  end;

  Result := True;
end;

function CertificateStoreDNMatches(const ACandidate, ATarget: string): Boolean;
begin
  Result := False;
  if (ACandidate = '') or (ATarget = '') then
    Exit;

  if ACandidate = ATarget then
    Exit(True);

  if CandidateContainsAllDNComponents(ACandidate, ATarget) then
    Exit(True);

  Result := Pos(ATarget, ACandidate) > 0;
end;

// ============================================================================
// ISSLCertificateStore - 存储管理
// ============================================================================

function TWinSSLCertificateStore.Open(const AName: string; AWritable: Boolean = False): Boolean;
var
  Flags: DWORD;
begin
  Result := False;

  // 关闭现有存储
  Close;

  // 设置打开标志
  Flags := CERT_STORE_OPEN_EXISTING_FLAG;
  if not AWritable then
    Flags := Flags or CERT_STORE_READONLY_FLAG;

  // 打开系统存储
  FStoreHandle := CertOpenSystemStoreW(0, PWideChar(WideString(AName)));

  if FStoreHandle <> nil then
  begin
    FStoreName := AName;
    FOwnsHandle := True;
    LoadCertificates;
    Result := True;
  end;
end;

procedure TWinSSLCertificateStore.Close;
begin
  ClearCache;

  if FOwnsHandle and (FStoreHandle <> nil) then
  begin
    CertCloseStore(FStoreHandle, 0);
    FStoreHandle := nil;
  end;

  FStoreName := '';
end;

function TWinSSLCertificateStore.IsOpen: Boolean;
begin
  Result := (FStoreHandle <> nil);
end;

// ============================================================================
// ISSLCertificateStore - 证书操作
// ============================================================================

function TWinSSLCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
var
  CertContext: PCCERT_CONTEXT;
begin
  Result := False;

  if (FStoreHandle = nil) or (ACert = nil) then
    Exit;

  // 获取证书的原生上下文
  CertContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLCertificateStore'));
  if CertContext = nil then
    Exit;

  // 添加证书到存储
  Result := CertAddCertificateContextToStore(
    FStoreHandle,
    CertContext,
    CERT_STORE_ADD_REPLACE_EXISTING,
    nil
  );

  if Result then
  begin
    // 重新加载证书列表
    LoadCertificates;
  end;
end;

function TWinSSLCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
var
  CertContext, FoundContext: PCCERT_CONTEXT;
begin
  Result := False;

  if (FStoreHandle = nil) or (ACert = nil) then
    Exit;

  // 获取证书的原生上下文
  CertContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLCertificateStore'));
  if CertContext = nil then
    Exit;

  // 在存储中查找证书
  FoundContext := CertFindCertificateInStore(
    FStoreHandle,
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    0,
    CERT_FIND_EXISTING,
    CertContext,
    nil
  );

  if FoundContext <> nil then
  begin
    // 删除证书
    Result := CertDeleteCertificateFromStore(FoundContext);

    if Result then
    begin
      // 重新加载证书列表
      LoadCertificates;
    end;
  end;
end;

function TWinSSLCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
var
  CertContext, FoundContext: PCCERT_CONTEXT;
begin
  Result := False;

  if (FStoreHandle = nil) or (ACert = nil) then
    Exit;

  // 获取证书的原生上下文
  CertContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLCertificateStore'));
  if CertContext = nil then
    Exit;

  // 在存储中查找证书
  FoundContext := CertFindCertificateInStore(
    FStoreHandle,
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    0,
    CERT_FIND_EXISTING,
    CertContext,
    nil
  );

  Result := (FoundContext <> nil);

  if FoundContext <> nil then
    CertFreeCertificateContext(FoundContext);
end;

procedure TWinSSLCertificateStore.Clear;
begin
  ClearCache;

  // 注意：这不会清除 Windows 系统存储中的证书
  // 只清除我们的内存缓存
end;

// ============================================================================
// ISSLCertificateStore - 证书加载
// ============================================================================

function TWinSSLCertificateStore.LoadFromFile(const AFileName: string): Boolean;
var
  Cert: ISSLCertificate;
  CertImpl: TWinSSLCertificate;
begin
  Result := False;

  if not nextpas.core.fs.IsFile(AFileName) then
    Exit;

  // 创建证书对象并加载文件
  CertImpl := TWinSSLCertificate.Create(nil, False);
  Cert := CertImpl;

  if Cert.LoadFromFile(AFileName) then
  begin
    Result := AddCertificate(Cert);
  end;
end;

function TWinSSLCertificateStore.LoadFromPath(const APath: string): Boolean;
var
  SearchRec: TSearchRec;
  FilePath: string;
  LoadedCount: Integer;
begin
  Result := False;
  LoadedCount := 0;

  if not nextpas.core.fs.IsDir(APath) then
    Exit;

  // 搜索路径中的证书文件
  if FindFirst(nextpas.core.fs.PathEnsureSep(APath) + '*.cer', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FilePath := nextpas.core.fs.PathEnsureSep(APath) + SearchRec.Name;
        if LoadFromFile(FilePath) then
          Inc(LoadedCount);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  // 也搜索 .pem 和 .crt 文件
  if FindFirst(nextpas.core.fs.PathEnsureSep(APath) + '*.pem', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FilePath := nextpas.core.fs.PathEnsureSep(APath) + SearchRec.Name;
        if LoadFromFile(FilePath) then
          Inc(LoadedCount);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  if FindFirst(nextpas.core.fs.PathEnsureSep(APath) + '*.crt', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FilePath := nextpas.core.fs.PathEnsureSep(APath) + SearchRec.Name;
        if LoadFromFile(FilePath) then
          Inc(LoadedCount);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  Result := (LoadedCount > 0);
end;

function TWinSSLCertificateStore.LoadSystemStore: Boolean;
begin
  // 默认加载 ROOT 系统存储（受信任根证书）
  Result := OpenSystemStore(SSL_STORE_ROOT);
end;

// ============================================================================
// ISSLCertificateStore - 证书查询
// ============================================================================

function TWinSSLCertificateStore.GetCount: Integer;
begin
  Result := Length(FCertificates);
end;

function TWinSSLCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
begin
  if (AIndex >= 0) and (AIndex < Length(FCertificates)) then
    Result := ISSLCertificate(FCertificates[AIndex])
  else
    Result := nil;
end;

function TWinSSLCertificateStore.GetAllCertificates: TSSLCertificateArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FCertificates));
  for i := 0 to Length(FCertificates) - 1 do
    Result[i] := ISSLCertificate(FCertificates[i]);
end;

// ============================================================================
// ISSLCertificateStore - 证书搜索
// ============================================================================

function TWinSSLCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
var
  I: Integer;
  Cert: ISSLCertificate;
  LTarget: string;
  LCandidate: string;
begin
  Result := nil;

  if FStoreHandle = nil then
    Exit;

  LTarget := NormalizeCertificateStoreDN(ASubject);
  if LTarget = '' then
    Exit;

  // 基于缓存证书对象做归一化匹配，避免 WinSSL lane
  // 继续停留在 backend-native 的未归一化字符串搜索语义上。
  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    LCandidate := NormalizeCertificateStoreDN(GetCertificateStoreDNText(Cert, False));
    if LCandidate = LTarget then
      Exit(Cert);
  end;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    LCandidate := NormalizeCertificateStoreDN(GetCertificateStoreDNText(Cert, False));
    if CertificateStoreDNMatches(LCandidate, LTarget) then
      Exit(Cert);
  end;
end;

function TWinSSLCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
var
  I: Integer;
  Cert: ISSLCertificate;
  LTarget: string;
  LCandidate: string;
begin
  Result := nil;

  if FStoreHandle = nil then
    Exit;

  LTarget := NormalizeCertificateStoreDN(AIssuer);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    LCandidate := NormalizeCertificateStoreDN(GetCertificateStoreDNText(Cert, True));
    if LCandidate = LTarget then
      Exit(Cert);
  end;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    LCandidate := NormalizeCertificateStoreDN(GetCertificateStoreDNText(Cert, True));
    if CertificateStoreDNMatches(LCandidate, LTarget) then
      Exit(Cert);
  end;
end;

function TWinSSLCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
var
  I: Integer;
  Cert: ISSLCertificate;
  LTarget: string;
begin
  Result := nil;
  LTarget := NormalizeCertificateStoreHex(ASerialNumber);
  if LTarget = '' then
    Exit;

  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    if NormalizeCertificateStoreHex(Cert.GetSerialNumber) = LTarget then
    begin
      Result := Cert;
      Exit;
    end;
  end;
end;

function TWinSSLCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
var
  I: Integer;
  Cert: ISSLCertificate;
  FP_SHA1, FP_SHA256: string;
  SearchFP: string;
begin
  Result := nil;
  SearchFP := NormalizeCertificateStoreHex(AFingerprint);
  if SearchFP = '' then
    Exit;
  
  for I := 0 to Length(FCertificates) - 1 do
  begin
    Cert := ISSLCertificate(FCertificates[I]);
    
    // Try SHA256 fingerprint (constant-time comparison)
    FP_SHA256 := NormalizeCertificateStoreHex(Cert.GetFingerprintSHA256);
    if (FP_SHA256 <> '') and SecureCompareStrings(FP_SHA256, SearchFP) then
    begin
      Result := Cert;
      Exit;
    end;
    
    // Try SHA1 fingerprint (constant-time comparison)
    FP_SHA1 := NormalizeCertificateStoreHex(Cert.GetFingerprintSHA1);
    if (FP_SHA1 <> '') and SecureCompareStrings(FP_SHA1, SearchFP) then
    begin
      Result := Cert;
      Exit;
    end;
  end;
end;

// ============================================================================
// ISSLCertificateStore - 证书验证
// ============================================================================

function TWinSSLCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
begin
  if ACert = nil then
  begin
    Result := False;
    Exit;
  end;

  // 使用证书自身的 Verify 方法，传入当前存储作为 CA 存储
  Result := ACert.Verify(Self);
end;

function TWinSSLCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
var
  ChainPara: CERT_CHAIN_PARA;
  ChainContext: PCCERT_CHAIN_CONTEXT;
  CertContext: PCCERT_CONTEXT;
  i, j: Integer;
  SimpleChain: PCERT_SIMPLE_CHAIN;
  ChainCert: ISSLCertificate;
begin
  SetLength(Result, 0);

  if (ACert = nil) then
    Exit;

  CertContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLCertificateStore'));
  if CertContext = nil then
    Exit;

  // 初始化证书链参数
  FillChar(ChainPara, SizeOf(ChainPara), 0);
  ChainPara.cbSize := SizeOf(ChainPara);

  // 构建证书链
  if not CertGetCertificateChain(
    nil,                  // 使用默认链引擎
    CertContext,        // 要验证的证书
    nil,                // 使用当前时间
    FStoreHandle,       // 附加证书存储
    @ChainPara,         // 链参数
    0,                  // 标志
    nil,                // 保留
    @ChainContext       // 输出链上下文
  ) then
    Exit;

  try
    // 直接写入结果数组，保持 interface 引用计数，
    // 避免把接口对象作为裸指针塞进 TList 造成悬空引用。
    for i := 0 to ChainContext^.cChain - 1 do
    begin
      SimpleChain := ChainContext^.rgpChain[i];

      for j := 0 to SimpleChain^.cElement - 1 do
      begin
        ChainCert := CreateWinSSLCertificateFromContext(
          CertDuplicateCertificateContext(SimpleChain^.rgpElement[j]^.pCertContext),
          True
        );
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := ChainCert;
      end;
    end;

  finally
    CertFreeCertificateChain(ChainContext);
  end;
end;

// ============================================================================
// 额外的辅助方法
// ============================================================================

function TWinSSLCertificateStore.OpenSystemStore(const AStoreName: string): Boolean;
begin
  Result := Open(AStoreName, False);
end;

function TWinSSLCertificateStore.GetSystemStoreNames: TStringArray;
begin

  // 添加常见的系统存储
  Result.Add(SSL_STORE_ROOT);
  Result.Add(SSL_STORE_MY);
  Result.Add(SSL_STORE_CA);
  Result.Add(SSL_STORE_TRUST);
  Result.Add(SSL_STORE_DISALLOWED);

  // 可以通过 CertEnumSystemStore 枚举所有系统存储
  // 这里简化处理，只返回常见的存储
end;

// ============================================================================
// ISSLNativeHandleAccess implementation
// ============================================================================

function TWinSSLCertificateStore.GetNativeHandle: Pointer;
begin
  Result := Pointer(FStoreHandle);
end;

function TWinSSLCertificateStore.GetBackendType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TWinSSLCertificateStore.IsNativeHandleValid: Boolean;
begin
  Result := (FStoreHandle <> nil);
end;

end.
