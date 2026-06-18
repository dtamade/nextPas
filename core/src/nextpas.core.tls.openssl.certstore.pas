{
  nextpas.core.tls.openssl.certstore - OpenSSL 证书存储实现
  版本: 1.0 (简化版)
}

unit nextpas.core.tls.openssl.certstore;

{$mode ObjFPC}{$H+}
{.$DEFINE DEBUG_CERTSTORE}

interface

uses
  SysUtils, Classes, nextpas.core.fs,
  nextpas.core.tls.base,
  nextpas.core.tls.logging,  // P3-8: 添加日志支持
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.certificate;

type
  TOpenSSLCertificateStore = class(TInterfacedObject, ISSLCertificateStore, ISSLNativeHandleAccess)
  private
    FStore: PX509_STORE;
    FOwnsHandle: Boolean;
    FCertificates: TList;  // 缓存证书列表用于枚举

    // Phase 2.5: 索引查找表 - O(log n) 替代 O(n) 线性搜索
    // 使用 TStringList (Sorted=True) 实现有序字典
    FIndexByFingerprint: TStringList;   // SHA256指纹 -> 索引
    FIndexBySerialNumber: TStringList;  // 序列号 -> 索引
    // 缓存提取的属性值，避免重复 X509 解析
    FSubjectCache: TStringList;  // 与 FCertificates 并行，缓存 Subject
    FIssuerCache: TStringList;   // 与 FCertificates 并行，缓存 Issuer

    procedure BuildIndexForCertificate(AIndex: Integer; AX509: PX509);
    procedure ClearIndexes;
  public
    constructor Create;
    destructor Destroy; override;
    
    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean;
    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;
    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;

    // ISSLNativeHandleAccess implementation
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.strings,
    nextpas.core.tls.certchain,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.secure;

function IsDuplicateStoreCertError: Boolean;
var
  LErrCode: Cardinal;
  LReason: PAnsiChar;
  LReasonStr: string;
begin
  Result := False;
  LErrCode := 0;

  if Assigned(ERR_peek_last_error) then
    LErrCode := ERR_peek_last_error()
  else if Assigned(ERR_peek_error) then
    LErrCode := ERR_peek_error();

  if LErrCode = 0 then
    Exit;

  if not Assigned(ERR_reason_error_string) then
    Exit;

  LReason := ERR_reason_error_string(LErrCode);
  if LReason = nil then
    Exit;

  LReasonStr := LowerCase(string(LReason));
  // OpenSSL 常见重复证书错误："cert already in hash table"
  Result := (Pos('already', LReasonStr) > 0) and
            ((Pos('hash', LReasonStr) > 0) or (Pos('already in store', LReasonStr) > 0));
end;

procedure FreeCertificateListRefs(ACerts: TList);
var
  I: Integer;
  LCert: PX509;
begin
  if (ACerts = nil) or (ACerts.Count = 0) then
    Exit;

  if OpenSSLX509_Finalizing or (not Assigned(X509_free)) then
    Exit;

  for I := 0 to ACerts.Count - 1 do
  begin
    LCert := PX509(ACerts[I]);
    if LCert = nil then
      Continue;

    try
      X509_free(LCert);
    except
      on E: Exception do
        TSecurityLog.Warning('OpenSSL',
          nextpas.core.text.conv.Format('Exception freeing X509 in cert store list: %s', [E.Message]));
    end;
  end;
end;

function NormalizeCertificateStoreDN(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
  Result := SysUtils.StringReplace(Result, ' , ', ',', [rfReplaceAll]);
  Result := SysUtils.StringReplace(Result, ', ', ',', [rfReplaceAll]);
  Result := SysUtils.StringReplace(Result, ' ,', ',', [rfReplaceAll]);
  Result := SysUtils.StringReplace(Result, ' = ', '=', [rfReplaceAll]);
  Result := SysUtils.StringReplace(Result, '= ', '=', [rfReplaceAll]);
  Result := SysUtils.StringReplace(Result, ' =', '=', [rfReplaceAll]);
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

constructor TOpenSSLCertificateStore.Create;
begin
  inherited Create;

  // Ensure required OpenSSL APIs are available before calling into them.
  FStore := nil;
  try
    LoadOpenSSLCore;
  except
    // Ignore here; callers will observe nil store handle.
  end;

  if not Assigned(X509_STORE_new) then
    LoadOpenSSLX509;

  if Assigned(X509_STORE_new) then
    FStore := X509_STORE_new();

  FOwnsHandle := True;
  FCertificates := TList.Create;

  // Phase 2.5: 初始化索引查找表
  FIndexByFingerprint := TStringList.Create;
  FIndexByFingerprint.Sorted := True;
  FIndexByFingerprint.Duplicates := dupIgnore;
  FIndexByFingerprint.CaseSensitive := False;
  FIndexBySerialNumber := TStringList.Create;
  FIndexBySerialNumber.Sorted := True;
  FIndexBySerialNumber.Duplicates := dupIgnore;
  FIndexBySerialNumber.CaseSensitive := False;

  // 属性缓存（与 FCertificates 并行）
  FSubjectCache := TStringList.Create;
  FIssuerCache := TStringList.Create;
end;

destructor TOpenSSLCertificateStore.Destroy;
begin
  // 释放证书列表持有的引用（与 X509_STORE 的引用分离）
  FreeCertificateListRefs(FCertificates);

  // 清空证书列表
  FCertificates.Clear;

  // Phase 2.5: 释放索引查找表
  FIndexByFingerprint.Free;
  FIndexBySerialNumber.Free;
  FSubjectCache.Free;
  FIssuerCache.Free;

  // 释放 X509_STORE（只释放一次！）
  // 注意：如果 OpenSSL 正在卸载，跳过清理以避免崩溃
  if FOwnsHandle and (FStore <> nil) and not OpenSSLX509_Finalizing then
  begin
    if Assigned(X509_STORE_free) then
    begin
      try
        X509_STORE_free(FStore);
      except
        // P3-8: 记录异常而不是静默忽略
        on E: Exception do
          TSecurityLog.Warning('OpenSSL', nextpas.core.text.conv.Format('Exception in TOpenSSLCertificateStore.Destroy: %s', [E.Message]));
      end;
    end;
  end;
  
  inherited;
end;

{ Phase 2.5: 索引构建和清理 }

procedure TOpenSSLCertificateStore.BuildIndexForCertificate(AIndex: Integer; AX509: PX509);
var
  Cert: ISSLCertificate;
  FP, Serial, Subject, Issuer: string;
begin
  if AX509 = nil then Exit;

  // 创建临时证书包装器提取属性
  X509_up_ref(AX509);
  Cert := TOpenSSLCertificate.Create(AX509, True);
  try
    // 提取并索引指纹 (SHA256优先)
    FP := Cert.GetFingerprintSHA256;
    if FP = '' then
      FP := Cert.GetFingerprintSHA1;
    if FP <> '' then
    begin
      FP := NormalizeCertificateStoreHex(FP);
      FIndexByFingerprint.AddObject(FP, TObject(PtrInt(AIndex)));
    end;

    // 提取并索引序列号
    Serial := Cert.GetSerialNumber;
    if Serial <> '' then
    begin
      Serial := NormalizeCertificateStoreHex(Serial);
      if Serial <> '' then
        FIndexBySerialNumber.AddObject(Serial, TObject(PtrInt(AIndex)));
    end;

    // 缓存 Subject 和 Issuer 用于部分匹配
    Subject := Cert.GetSubject;
    Issuer := Cert.GetIssuer;
    FSubjectCache.Add(NormalizeCertificateStoreDN(Subject));
    FIssuerCache.Add(NormalizeCertificateStoreDN(Issuer));
  except
    // 索引构建失败不应阻止证书添加
    on E: Exception do
      TSecurityLog.Warning('OpenSSL', nextpas.core.text.conv.Format('Failed to build index for certificate: %s', [E.Message]));
  end;
end;

procedure TOpenSSLCertificateStore.ClearIndexes;
begin
  FIndexByFingerprint.Clear;
  FIndexBySerialNumber.Clear;
  FSubjectCache.Clear;
  FIssuerCache.Clear;
end;

function TOpenSSLCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
var
  X509: PX509;
  CertIndex: Integer;
  AddRet: Integer;
  LErrCode: Cardinal;
begin
  Result := False;
  if (FStore = nil) or (ACert = nil) then
    Exit;

  if not Assigned(X509_STORE_add_cert) then
    Exit;

  X509 := PX509(GetNativeHandleSafe(ACert, 'TOpenSSLCertificateStore.AddCertificate'));
  if X509 = nil then
    Exit;

  // 清理旧错误，避免误判
  if Assigned(ERR_clear_error) then
    ERR_clear_error();

  AddRet := X509_STORE_add_cert(FStore, X509);
  if AddRet = 1 then
  begin
    // cert store 会 up_ref；这里为枚举缓存再持有一份引用
    if Assigned(X509_up_ref) then
      X509_up_ref(X509);

    CertIndex := FCertificates.Count;
    FCertificates.Add(X509);
    BuildIndexForCertificate(CertIndex, X509);
    Result := True;
  end
  else
  begin
    // 重复证书：按幂等语义视为成功，但不重复写入缓存
    if IsDuplicateStoreCertError then
    begin
      Result := True;
      if not Contains(ACert) then
      begin
        if Assigned(X509_up_ref) then
          X509_up_ref(X509);

        CertIndex := FCertificates.Count;
        FCertificates.Add(X509);
        BuildIndexForCertificate(CertIndex, X509);
      end;
    end
    else
    begin
      LErrCode := 0;
      if Assigned(ERR_peek_last_error) then
        LErrCode := ERR_peek_last_error();

      TSecurityLog.Warning('CertStore',
        nextpas.core.text.conv.Format('X509_STORE_add_cert failed: %s', [GetFriendlyErrorMessage(LErrCode)]));
    end;
  end;

  if Assigned(ERR_clear_error) then
    ERR_clear_error();
end;

function TOpenSSLCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
begin
  // Note: OpenSSL X509_STORE design does not support certificate removal.
  // This is a limitation of OpenSSL's architecture, not a missing feature.
  // Workaround: Create a new store or reload certificates selectively.
  Result := False;
end;

function TOpenSSLCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
var
  FP: string;
begin
  Result := False;
  if (ACert = nil) or (FCertificates.Count = 0) then
    Exit;
  
  // 使用指纹进行匹配，避免依赖底层句柄是否复用
  FP := ACert.GetFingerprintSHA256;
  if FP = '' then
    FP := ACert.GetFingerprint(sslHashSHA256);
  if FP = '' then
    FP := ACert.GetFingerprintSHA1;
  if FP = '' then
    Exit;
  
  Result := FindByFingerprint(FP) <> nil;
end;

procedure TOpenSSLCertificateStore.Clear;
begin
  // 先释放枚举缓存持有的证书引用
  FreeCertificateListRefs(FCertificates);

  // 清空证书缓存列表
  FCertificates.Clear;

  // Phase 2.5: 清空索引
  ClearIndexes;

  // 重新创建 store
  if FOwnsHandle and (FStore <> nil) and not OpenSSLX509_Finalizing then
  begin
    if Assigned(X509_STORE_free) then
    begin
      try
        X509_STORE_free(FStore);
      except
        on E: Exception do
          // Rust-quality: 记录错误而非静默忽略
          TSecurityLog.Warning('OpenSSL', nextpas.core.text.conv.Format('X509_STORE_free failed in Clear: %s', [E.Message]));
      end;
    end;
  end;
  
  if not Assigned(X509_STORE_new) then
    LoadOpenSSLX509;

  if Assigned(X509_STORE_new) then
    FStore := X509_STORE_new()
  else
    FStore := nil;

  FOwnsHandle := True;
end;

function TOpenSSLCertificateStore.GetCount: Integer;
begin
  Result := FCertificates.Count;
end;

function TOpenSSLCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
var
  X509Cert: PX509;
begin
  Result := nil;
  
  if (AIndex < 0) or (AIndex >= FCertificates.Count) then
    Exit;
  
  X509Cert := PX509(FCertificates[AIndex]);
  if X509Cert = nil then
    Exit;
  
  X509_up_ref(X509Cert);
  Result := TOpenSSLCertificate.Create(X509Cert, True);
end;

function TOpenSSLCertificateStore.LoadFromFile(const AFileName: string): Boolean;
var
  FileNameA: AnsiString;
  BIO: PBIO;
  X509Cert: PX509;
  ReadCount: Integer;
  AddedCount: Integer;
  AddRet: Integer;
  LErrCode: Cardinal;
begin
  Result := False;
  ReadCount := 0;
  AddedCount := 0;

  if (FStore = nil) or (AFileName = '') then
    Exit;

  if (not Assigned(BIO_new_file)) or (not Assigned(PEM_read_bio_X509)) then
    Exit;

  if not Assigned(X509_STORE_add_cert) then
    Exit;

  if not Assigned(X509_free) then
    Exit;

  try
    FileNameA := AnsiString(AFileName);
    BIO := BIO_new_file(PAnsiChar(FileNameA), 'r');
    if BIO = nil then
      Exit;

    try
      repeat
        X509Cert := PEM_read_bio_X509(BIO, nil, nil, nil);
        if X509Cert <> nil then
        begin
          Inc(ReadCount);

          if Assigned(ERR_clear_error) then
            ERR_clear_error();

          AddRet := X509_STORE_add_cert(FStore, X509Cert);
          if AddRet = 1 then
          begin
            // 保留一份引用用于枚举缓存（原始引用归 FCertificates 所有）
            FCertificates.Add(X509Cert);
            BuildIndexForCertificate(FCertificates.Count - 1, X509Cert);
            Inc(AddedCount);
          end
          else if IsDuplicateStoreCertError then
          begin
            // 已在 store 中：不要重复缓存，释放这份解析出来的对象
            X509_free(X509Cert);
          end
          else
          begin
            // 非重复错误：记录并释放
            LErrCode := 0;
            if Assigned(ERR_peek_last_error) then
              LErrCode := ERR_peek_last_error();

            TSecurityLog.Warning('CertStore',
              nextpas.core.text.conv.Format('X509_STORE_add_cert failed while loading "%s": %s',
                [AFileName, GetFriendlyErrorMessage(LErrCode)]));

            X509_free(X509Cert);
          end;

          if Assigned(ERR_clear_error) then
            ERR_clear_error();
        end;
      until X509Cert = nil;

      // 只要文件里确实读取到证书，就认为 LoadFromFile 成功
      Result := (ReadCount > 0);
    finally
      if Assigned(BIO_free) then
        BIO_free(BIO);
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TOpenSSLCertificateStore.LoadFromPath(const APath: string): Boolean;
var
  SR: TSearchRec;
  FilePath: string;
  Count: Integer;
  SearchPath: string;
  FindResult: Integer;
begin
  Result := False;
  Count := 0;
  
  try
    // 确保路径有正确的分隔符
    SearchPath := nextpas.core.fs.PathEnsureSep(APath);
    
    
    // 扫描目录中的所有 .pem 文件
    // Rust-quality: 使用 try-finally 确保 FindClose 在异常路径也被调用
    FindResult := FindFirst(SearchPath + '*.pem', faAnyFile, SR);
    if FindResult = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FilePath := SearchPath + SR.Name;
          if LoadFromFile(FilePath) then
            Inc(Count);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;

    // 扫描目录中的所有 .crt 文件
    FindResult := FindFirst(SearchPath + '*.crt', faAnyFile, SR);
    if FindResult = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FilePath := SearchPath + SR.Name;
          if LoadFromFile(FilePath) then
            Inc(Count);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    
    Result := (Count > 0);
  except
    on E: Exception do
    begin
      {$IFDEF DEBUG_CERTSTORE}
      // Error during path loading
      {$ENDIF}
      Result := False;
    end;
  end;
end;

function TOpenSSLCertificateStore.LoadSystemStore: Boolean;
const
  // Linux 系统证书路径
  LinuxCertPaths: array[0..4] of string = (
    '/etc/ssl/certs',           // Debian/Ubuntu
    '/etc/pki/tls/certs',       // RedHat/CentOS
    '/usr/share/ca-certificates',
    '/usr/local/share/ca-certificates',
    '/etc/ssl/cert.pem'
  );
var
  I: Integer;
  LoadedAny: Boolean;
begin
  Result := False;
  LoadedAny := False;
  
  // 首先尝试 OpenSSL 默认路径
  if FStore <> nil then
  begin
    if Assigned(X509_STORE_set_default_paths) then
    begin
      try
        X509_STORE_set_default_paths(FStore);
      except
        on E: Exception do
          TSecurityLog.Debug('CertStore', nextpas.core.text.conv.Format('X509_STORE_set_default_paths failed: %s', [E.Message]));
      end;
    end;
  end;
  
  // 尝试从已知的系统路径加载
  for I := Low(LinuxCertPaths) to High(LinuxCertPaths) do
  begin
    if nextpas.core.fs.IsDir(LinuxCertPaths[I]) then
    begin
      if LoadFromPath(LinuxCertPaths[I]) then
        LoadedAny := True;
    end
    else if nextpas.core.fs.IsFile(LinuxCertPaths[I]) then
    begin
      if LoadFromFile(LinuxCertPaths[I]) then
        LoadedAny := True;
    end;
  end;
  
  Result := LoadedAny or (GetCount > 0);
end;

function TOpenSSLCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
var
  I: Integer;
  SearchSubject: string;
begin
  Result := nil;
  if FSubjectCache.Count = 0 then Exit;

  // Phase 2.5: 使用缓存的 Subject 值进行搜索，避免重复 X509 解析
  SearchSubject := NormalizeCertificateStoreDN(ASubject);
  if SearchSubject = '' then
    Exit;

  for I := 0 to FSubjectCache.Count - 1 do
  begin
    if FSubjectCache[I] = SearchSubject then
    begin
      Result := GetCertificate(I);
      Exit;
    end;
  end;

  for I := 0 to FSubjectCache.Count - 1 do
  begin
    // 部分匹配：检查 subject 中是否包含搜索字符串
    if Pos(SearchSubject, FSubjectCache[I]) > 0 then
    begin
      Result := GetCertificate(I);
      Exit;
    end;
  end;
end;

function TOpenSSLCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
var
  I: Integer;
  SearchIssuer: string;
begin
  Result := nil;
  if FIssuerCache.Count = 0 then Exit;

  // Phase 2.5: 使用缓存的 Issuer 值进行搜索，避免重复 X509 解析
  SearchIssuer := NormalizeCertificateStoreDN(AIssuer);
  if SearchIssuer = '' then
    Exit;

  for I := 0 to FIssuerCache.Count - 1 do
  begin
    if FIssuerCache[I] = SearchIssuer then
    begin
      Result := GetCertificate(I);
      Exit;
    end;
  end;

  for I := 0 to FIssuerCache.Count - 1 do
  begin
    // 部分匹配：检查 issuer 中是否包含搜索字符串
    if Pos(SearchIssuer, FIssuerCache[I]) > 0 then
    begin
      Result := GetCertificate(I);
      Exit;
    end;
  end;
end;

function TOpenSSLCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
var
  Idx: Integer;
  CertIndex: PtrInt;
  LTarget: string;
begin
  Result := nil;
  if FIndexBySerialNumber.Count = 0 then Exit;

  LTarget := NormalizeCertificateStoreHex(ASerialNumber);
  if LTarget = '' then
    Exit;

  // Phase 2.5: O(log n) 索引查找替代 O(n) 线性搜索
  Idx := FIndexBySerialNumber.IndexOf(LTarget);
  if Idx >= 0 then
  begin
    CertIndex := PtrInt(FIndexBySerialNumber.Objects[Idx]);
    if (CertIndex >= 0) and (CertIndex < FCertificates.Count) then
      Result := GetCertificate(CertIndex);
  end;
end;

function TOpenSSLCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
var
  Idx: Integer;
  CertIndex: PtrInt;
  SearchFP: string;
begin
  Result := nil;
  if FIndexByFingerprint.Count = 0 then Exit;

  // Phase 2.5: O(log n) 索引查找替代 O(n) 线性搜索
  SearchFP := NormalizeCertificateStoreHex(AFingerprint);
  if SearchFP = '' then
    Exit;

  Idx := FIndexByFingerprint.IndexOf(SearchFP);
  if Idx >= 0 then
  begin
    CertIndex := PtrInt(FIndexByFingerprint.Objects[Idx]);
    if (CertIndex >= 0) and (CertIndex < FCertificates.Count) then
      Result := GetCertificate(CertIndex);
  end;
end;

function TOpenSSLCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := False;
  if (ACert = nil) or (FStore = nil) then
    Exit;
  
  // 直接复用证书对象的 Verify 实现，委托给当前 store
  Result := ACert.Verify(Self);
end;

function TOpenSSLCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
var
  LVerifier: ISSLCertificateChainVerifier;
  LTrustedStore: ISSLCertificateStore;
  LIntermediateStore: ISSLCertificateStore;
  LStoreCert: ISSLCertificate;
  I: Integer;
begin
  Result := nil;
  if ACert = nil then
    Exit;

  LTrustedStore := nil;
  LIntermediateStore := nil;
  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetOptions(LVerifier.GetOptions + [cvoAllowPartialChain]);

  // 不要把整个 store 都当作 trusted store。
  // 否则 shared verifier 会把 intermediate 也提前当成 trust anchor，
  // 导致本该继续补到 self-signed root 的链在第二跳被截断。
  for I := 0 to FCertificates.Count - 1 do
  begin
    LStoreCert := GetCertificate(I);
    if LStoreCert = nil then
      Continue;

    if LStoreCert.IsSelfSigned then
    begin
      if LTrustedStore = nil then
        LTrustedStore := TOpenSSLCertificateStore.Create;
      LTrustedStore.AddCertificate(LStoreCert);
    end
    else
    begin
      if LIntermediateStore = nil then
        LIntermediateStore := TOpenSSLCertificateStore.Create;
      LIntermediateStore.AddCertificate(LStoreCert);
    end;
  end;

  if LTrustedStore <> nil then
    LVerifier.SetTrustedStore(LTrustedStore);
  if LIntermediateStore <> nil then
    LVerifier.SetIntermediateStore(LIntermediateStore);

  if not LVerifier.BuildChain(ACert, Result) then
    SetLength(Result, 0);
end;

function TOpenSSLCertificateStore.GetNativeHandle: Pointer;
begin
  Result := FStore;
end;

function TOpenSSLCertificateStore.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLCertificateStore.IsNativeHandleValid: Boolean;
begin
  Result := (FStore <> nil);
end;

end.
