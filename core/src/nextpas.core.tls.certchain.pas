{******************************************************************************}
{                                                                              }
{  fafafa.ssl - A unified SSL/TLS library for FreePascal                      }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{  证书链验证模块 - 提供完整的证书链验证功能                                 }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.certchain;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  nextpas.core.tls.base, nextpas.core.tls.crl, nextpas.core.tls.x509, nextpas.core.crypto.x509verify;

type
  { 证书链验证选项 }
  TChainVerifyOption = (
    cvoCheckTime,           // 检查证书有效期
    cvoCheckSignature,      // 验证签名
    cvoCheckKeyUsage,       // 检查密钥用途
    cvoCheckExtKeyUsage,    // 检查扩展密钥用途
    cvoCheckCAConstraints,  // 检查CA约束
    cvoCheckRevocation,     // 检查吊销状态
    cvoCheckHostname,       // 验证主机名
    cvoAllowSelfSigned,     // 允许自签名证书
    cvoAllowPartialChain,   // 允许部分链
    cvoRequireEVCert        // 要求EV证书
  );
  TChainVerifyOptions = set of TChainVerifyOption;

  { 证书链验证结果 }
  TChainVerifyResult = record
    IsValid: Boolean;
    ErrorCode: Integer;
    ErrorMessage: string;
    ChainLength: Integer;
    TrustedRoot: Boolean;
    SelfSigned: Boolean;
    HostnameMatch: Boolean;
    RevocationStatus: Cardinal;
    Warnings: TStringArray;
  end;

  {**
   * ISSLCertificateChainVerifier - 证书链验证器接口
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLCertificateChainVerifier = interface
    ['{A8B3C4D5-E6F7-4829-9ABC-DEF012345678}']

    // 设置选项
    procedure SetOptions(AOptions: TChainVerifyOptions);
    function GetOptions: TChainVerifyOptions;

    // 设置信任的根证书存储
    procedure SetTrustedStore(AStore: ISSLCertificateStore);
    function GetTrustedStore: ISSLCertificateStore;

    // 设置中间证书存储
    procedure SetIntermediateStore(AStore: ISSLCertificateStore);
    function GetIntermediateStore: ISSLCertificateStore;

    // 设置CRL存储
    procedure SetCRLStore(const ACRLs: TStringArray);
    function GetCRLStore: TStringArray;

    // 验证单个证书
    function VerifyCertificate(ACert: ISSLCertificate;
                              const AHostname: string = ''): TChainVerifyResult;

    // 验证证书链
    function VerifyChain(const AChain: TSSLCertificateArray;
                        const AHostname: string = ''): TChainVerifyResult;

    // 构建证书链（从叶证书开始）
    function BuildChain(ALeafCert: ISSLCertificate;
                      out AChain: TSSLCertificateArray): Boolean;

    // 检查特定的验证项
    function CheckCertificateTime(ACert: ISSLCertificate): Boolean;
    function CheckCertificateSignature(ACert: ISSLCertificate;
                                      AIssuer: ISSLCertificate): Boolean;
    function CheckCertificateKeyUsage(ACert: ISSLCertificate;
                                    AIsCA: Boolean): Boolean;
    function CheckCertificateRevocation(ACert: ISSLCertificate): Boolean;
    function CheckHostname(ACert: ISSLCertificate;
                          const AHostname: string): Boolean;
  end;

  { 证书链验证器基类 }
  TSSLCertificateChainVerifier = class(TInterfacedObject, ISSLCertificateChainVerifier)
  private
    FOptions: TChainVerifyOptions;
    FTrustedStore: ISSLCertificateStore;
    FIntermediateStore: ISSLCertificateStore;
    FCRLStore: TStringArray;
    FLastRevocationStatus: Cardinal;
    FLastRevocationError: string;

    function FindIssuer(ACert: ISSLCertificate): ISSLCertificate;
    function IsRootCertificate(ACert: ISSLCertificate): Boolean;
    function IsSelfSigned(ACert: ISSLCertificate): Boolean;
    function ValidatePathLength(const AChain: TSSLCertificateArray): Boolean;
    function MatchHostname(const ACertName, AHostname: string): Boolean;
    function ParseSubjectAltNames(ACert: ISSLCertificate): TStringArray;
    function CheckCertificateExtendedKeyUsage(ACert: ISSLCertificate;
      AIsCA: Boolean): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // ISSLCertificateChainVerifier implementation
    procedure SetOptions(AOptions: TChainVerifyOptions);
    function GetOptions: TChainVerifyOptions;

    procedure SetTrustedStore(AStore: ISSLCertificateStore);
    function GetTrustedStore: ISSLCertificateStore;

    procedure SetIntermediateStore(AStore: ISSLCertificateStore);
    function GetIntermediateStore: ISSLCertificateStore;

    procedure SetCRLStore(const ACRLs: TStringArray);
    function GetCRLStore: TStringArray;

    function VerifyCertificate(ACert: ISSLCertificate;
                              const AHostname: string = ''): TChainVerifyResult;

    function VerifyChain(const AChain: TSSLCertificateArray;
                        const AHostname: string = ''): TChainVerifyResult;

    function BuildChain(ALeafCert: ISSLCertificate;
                      out AChain: TSSLCertificateArray): Boolean;

    function CheckCertificateTime(ACert: ISSLCertificate): Boolean;
    function CheckCertificateSignature(ACert: ISSLCertificate;
                                      AIssuer: ISSLCertificate): Boolean;
    function CheckCertificateKeyUsage(ACert: ISSLCertificate;
                                    AIsCA: Boolean): Boolean;
    function CheckCertificateRevocation(ACert: ISSLCertificate): Boolean;
    function CheckHostname(ACert: ISSLCertificate;
                          const AHostname: string): Boolean;
  end;

  { 默认的证书链验证选项 }
const
  DefaultChainVerifyOptions: TChainVerifyOptions = [
    cvoCheckTime,
    cvoCheckSignature,
    cvoCheckKeyUsage,
    cvoCheckCAConstraints,
    cvoCheckHostname
  ];

  StrictChainVerifyOptions: TChainVerifyOptions = [
    cvoCheckTime,
    cvoCheckSignature,
    cvoCheckKeyUsage,
    cvoCheckExtKeyUsage,
    cvoCheckCAConstraints,
    cvoCheckRevocation,
    cvoCheckHostname
  ];

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.strings,
    nextpas.core.time;

{ TSSLCertificateChainVerifier }

constructor TSSLCertificateChainVerifier.Create;
begin
  inherited Create;
  FOptions := DefaultChainVerifyOptions;
  FLastRevocationStatus := 0;
  FLastRevocationError := '';
end;

destructor TSSLCertificateChainVerifier.Destroy;
begin
  inherited;
end;

procedure TSSLCertificateChainVerifier.SetOptions(AOptions: TChainVerifyOptions);
begin
  FOptions := AOptions;
end;

function TSSLCertificateChainVerifier.GetOptions: TChainVerifyOptions;
begin
  Result := FOptions;
end;

procedure TSSLCertificateChainVerifier.SetTrustedStore(AStore: ISSLCertificateStore);
begin
  FTrustedStore := AStore;
end;

function TSSLCertificateChainVerifier.GetTrustedStore: ISSLCertificateStore;
begin
  Result := FTrustedStore;
end;

procedure TSSLCertificateChainVerifier.SetIntermediateStore(AStore: ISSLCertificateStore);
begin
  FIntermediateStore := AStore;
end;

function TSSLCertificateChainVerifier.GetIntermediateStore: ISSLCertificateStore;
begin
  Result := FIntermediateStore;
end;

procedure TSSLCertificateChainVerifier.SetCRLStore(const ACRLs: TStringArray);
begin
  FCRLStore.Clear;
  if ACRLs <> nil then
    FCRLStore.Assign(ACRLs);
end;

function TSSLCertificateChainVerifier.GetCRLStore: TStringArray;
begin
  Result := FCRLStore;
end;

function TSSLCertificateChainVerifier.FindIssuer(ACert: ISSLCertificate): ISSLCertificate;
var
  IssuerName: string;
begin
  Result := nil;

  if ACert = nil then
    Exit;

  IssuerName := ACert.GetIssuer;

  // 先在信任的根证书中查找
  if Assigned(FTrustedStore) then
  begin
    Result := FTrustedStore.FindBySubject(IssuerName);
    if Result <> nil then
      Exit;
  end;

  // 再在中间证书中查找
  if Assigned(FIntermediateStore) then
  begin
    Result := FIntermediateStore.FindBySubject(IssuerName);
  end;
end;

function TSSLCertificateChainVerifier.IsRootCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := False;

  if (ACert = nil) or (FTrustedStore = nil) then
    Exit;

  // 检查是否在信任的根证书存储中
  Result := FTrustedStore.Contains(ACert);
end;

function TSSLCertificateChainVerifier.IsSelfSigned(ACert: ISSLCertificate): Boolean;
begin
  Result := False;

  if ACert = nil then
    Exit;

  // 自签名证书的 Subject 和 Issuer 相同
  Result := ACert.GetSubject = ACert.GetIssuer;
end;

function TSSLCertificateChainVerifier.ValidatePathLength(const AChain: TSSLCertificateArray): Boolean;
var
  i: Integer;
  RemainingPath: Integer;
  CertInfo: TSSLCertificateInfo;
begin
  Result := True;
  if Length(AChain) <= 1 then
    Exit;

  RemainingPath := -1;

  for i := High(AChain) downto 1 do
  begin
    CertInfo := AChain[i].GetInfo;

    if CertInfo.IsCA then
    begin
      if CertInfo.PathLenConstraint >= 0 then
      begin
        if (RemainingPath < 0) or (CertInfo.PathLenConstraint < RemainingPath) then
          RemainingPath := CertInfo.PathLenConstraint;
      end;
    end;

    if RemainingPath >= 0 then
    begin
      if RemainingPath = 0 then
      begin
        if (i - 1 > 0) and AChain[i - 1].GetInfo.IsCA then
        begin
          Result := False;
          Exit;
        end;
      end
      else
        Dec(RemainingPath);
    end;
  end;
end;

function TSSLCertificateChainVerifier.MatchHostname(const ACertName, AHostname: string): Boolean;
var
  CertParts, HostParts: TStringArray;
  i: Integer;
begin
  Result := False;

  // 精确匹配
  if nextpas.core.text.conv.SameText(ACertName, AHostname) then
  begin
    Result := True;
    Exit;
  end;

  // 通配符匹配
  if (Pos('*.', ACertName) = 1) then
  begin
    try

      // 域名级数必须相同
      if Length(CertParts) = Length(HostParts) then
      begin
        Result := True;
        // 从第二级开始比较（跳过通配符）
        for i := 1 to Length(CertParts) - 1 do
        begin
          if not nextpas.core.text.conv.SameText(CertParts[i], HostParts[i]) then
          begin
            Result := False;
            Break;
          end;
        end;
      end;
    finally
    end;
  end;
end;

function TSSLCertificateChainVerifier.ParseSubjectAltNames(ACert: ISSLCertificate): TStringArray;
var
  RawSANs: TSSLStringArray;
  Line, Item: string;
  i, SepPos: Integer;
begin

  if ACert = nil then
    Exit;

  RawSANs := ACert.GetSubjectAltNames;
  if Length(RawSANs) = 0 then
    Exit;

  for i := 0 to Length(RawSANs) - 1 do
  begin
    Line := nextpas.core.text.conv.Trim(RawSANs[i]);
    if Line = '' then
      Continue;

    // 一行中可能包含多个以逗号分隔的条目
    repeat
      SepPos := Pos(',', Line);
      if SepPos > 0 then
      begin
        Item := nextpas.core.text.conv.Trim(Copy(Line, 1, SepPos - 1));
        Line := nextpas.core.text.conv.Trim(Copy(Line, SepPos + 1, MaxInt));
      end
      else
      begin
        Item := Line;
        Line := '';
      end;

      if Item <> '' then
      begin
        // 去掉类似 "DNS:" 这类前缀，只保留主机名部分
        SepPos := Pos(':', Item);
        if SepPos > 0 then
          Item := nextpas.core.text.conv.Trim(Copy(Item, SepPos + 1, MaxInt));

        if Item <> '' then
          Result.Add(Item);
      end;
    until Line = '';
  end;
end;

function TSSLCertificateChainVerifier.CheckCertificateTime(ACert: ISSLCertificate): Boolean;
var
  Info: TSSLCertificateInfo;
  CurrentTime: TDateTime;
begin
  Result := False;

  if ACert = nil then
    Exit;

  Info := ACert.GetInfo;
  CurrentTime := DateTimeUtcNow;

  // 检查证书是否在有效期内
  Result := (CurrentTime >= Info.NotBefore) and (CurrentTime <= Info.NotAfter);
end;

function TSSLCertificateChainVerifier.CheckCertificateSignature(ACert: ISSLCertificate;
  AIssuer: ISSLCertificate): Boolean;
var
  LSubjectDER, LIssuerDER: TBytes;
  LSubjectX509, LIssuerX509: TX509Certificate;
  LError: string;
begin
  Result := False;

  if ACert = nil then
    Exit;

  // Discover the issuer by DN only when not already provided by the caller.
  // Store lookup is for *finding* a candidate issuer, never for *proving* the
  // signature is valid — the cryptographic check below is mandatory.
  if AIssuer = nil then
    AIssuer := FindIssuer(ACert);

  if AIssuer = nil then
    Exit;

  if ACert.GetIssuer <> AIssuer.GetSubject then
    Exit;

  LSubjectDER := ACert.SaveToDER;
  LIssuerDER := AIssuer.SaveToDER;
  if (Length(LSubjectDER) = 0) or (Length(LIssuerDER) = 0) then
    Exit;

  LSubjectX509 := TX509Certificate.Create;
  try
    LIssuerX509 := TX509Certificate.Create;
    try
      try
        LSubjectX509.LoadFromDER(LSubjectDER);
        LIssuerX509.LoadFromDER(LIssuerDER);
      except
        Exit;
      end;
      Result := VerifyChainSignatureEx(LSubjectX509, LIssuerX509, LError);
    finally
    end;
  finally
  end;
end;

function TSSLCertificateChainVerifier.CheckCertificateKeyUsage(ACert: ISSLCertificate;
  AIsCA: Boolean): Boolean;
var
  Info: TSSLCertificateInfo;
begin
  Result := True;

  if ACert = nil then
  begin
    Result := False;
    Exit;
  end;

  Info := ACert.GetInfo;

  if AIsCA then
  begin
    // CA证书必须有 keyCertSign 权限
    Result := Info.IsCA and (Info.KeyUsage and $04 <> 0); // keyCertSign
  end
  else
  begin
    // 终端证书通常需要 digitalSignature 和 keyEncipherment
    Result := (Info.KeyUsage and $80 <> 0) or  // digitalSignature
              (Info.KeyUsage and $20 <> 0);     // keyEncipherment
  end;
end;

function TSSLCertificateChainVerifier.CheckCertificateExtendedKeyUsage(
  ACert: ISSLCertificate; AIsCA: Boolean): Boolean;
var
  LUsage: TSSLStringArray;
  I: Integer;
begin
  Result := False;

  if ACert = nil then
    Exit;

  if AIsCA or ACert.IsCA then
    Exit(True);

  LUsage := ACert.GetExtendedKeyUsage;
  for I := 0 to High(LUsage) do
  begin
    if nextpas.core.text.conv.SameText(nextpas.core.text.conv.Trim(LUsage[I]), 'serverAuth') then
      Exit(True);
  end;
end;

function TSSLCertificateChainVerifier.CheckCertificateRevocation(ACert: ISSLCertificate): Boolean;
var
  LCertificateDER: TBytes;
  LCertificate: TX509Certificate;
  LCRL: TX509CRL;
  LCRLIndex: Integer;
  LCertificateIssuer: string;
  LHasApplicableCRL: Boolean;
  LHasUsableCRL: Boolean;
  LLastMaterialError: string;
begin
  Result := False;
  FLastRevocationStatus := 0;
  FLastRevocationError := '';

  if ACert = nil then
  begin
    FLastRevocationStatus := 2;
    FLastRevocationError := 'Certificate revocation/CRL verification requires a certificate';
    Exit;
  end;

  if (FCRLStore = nil) or (Length(FCRLStore) = 0) then
  begin
    FLastRevocationStatus := 2;
    FLastRevocationError := 'No caller-provided CRL material is configured';
    Exit;
  end;

  LCertificateDER := ACert.SaveToDER;
  if Length(LCertificateDER) = 0 then
  begin
    FLastRevocationStatus := 2;
    FLastRevocationError := 'Certificate revocation/CRL verification requires certificate DER material';
    Exit;
  end;

  LCertificate := TX509Certificate.Create;
  try
    try
      LCertificate.LoadFromDER(LCertificateDER);
    except
      on E: Exception do
      begin
        FLastRevocationStatus := 2;
        FLastRevocationError := 'Failed to parse certificate DER for revocation/CRL verification: ' + E.Message;
        Exit;
      end;
    end;

    LCertificateIssuer := nextpas.core.text.conv.Trim(LCertificate.Issuer.ToString);
    LHasApplicableCRL := False;
    LHasUsableCRL := False;
    LLastMaterialError := '';

    for LCRLIndex := 0 to Length(FCRLStore) - 1 do
    begin
      if nextpas.core.text.conv.Trim(FCRLStore[LCRLIndex]) = '' then
        Continue;

      LCRL := TX509CRL.Create;
      try
        try
          LCRL.LoadFromPEM(FCRLStore[LCRLIndex]);
        except
          on E: Exception do
          begin
            LLastMaterialError := nextpas.core.text.conv.Format(
              'Failed to parse configured CRL material #%d: %s',
              [LCRLIndex + 1, E.Message]
            );
            Continue;
          end;
        end;

        if not nextpas.core.text.conv.SameText(nextpas.core.text.conv.Trim(LCRL.Issuer.ToString), LCertificateIssuer) then
          Continue;

        LHasApplicableCRL := True;

        if not LCRL.IsValid then
        begin
          if LCRL.IsExpired then
            LLastMaterialError := 'Configured CRL material for certificate issuer is expired'
          else
            LLastMaterialError := 'Configured CRL material for certificate issuer is not yet valid';
          Continue;
        end;

        LHasUsableCRL := True;
        if LCRL.IsRevoked(LCertificate.SerialNumber) then
        begin
          FLastRevocationStatus := 1;
          FLastRevocationError := 'Certificate has been revoked by caller-provided CRL material';
          Exit(False);
        end;
      finally
      end;
    end;

    if LHasUsableCRL then
    begin
      FLastRevocationStatus := 0;
      FLastRevocationError := '';
      Result := True;
      Exit;
    end;

    FLastRevocationStatus := 2;
    if LLastMaterialError <> '' then
      FLastRevocationError := LLastMaterialError
    else if LHasApplicableCRL then
      FLastRevocationError := 'Configured CRL material for certificate issuer is unavailable'
    else
      FLastRevocationError := 'No applicable caller-provided CRL material found for certificate issuer';
  finally
  end;
end;

function TSSLCertificateChainVerifier.CheckHostname(ACert: ISSLCertificate;
  const AHostname: string): Boolean;
var
  CN: string;
  SANs: TStringArray;
  i: Integer;
  LSANCount: Integer;
  CertInfo: TSSLCertificateInfo;
begin
  Result := False;

  if (ACert = nil) or (AHostname = '') then
    Exit;

  SANs := ParseSubjectAltNames(ACert);
  try
    LSANCount := Length(SANs);
    for i := 0 to Length(SANs) - 1 do
    begin
      if MatchHostname(SANs[i], AHostname) then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
  end;

  // RFC 6125: when dNSName SANs exist, CN must be ignored even if no SAN matched.
  if LSANCount > 0 then
    Exit;

  CertInfo := ACert.GetInfo;
  if Pos('CN=', CertInfo.Subject) > 0 then
  begin
    CN := CertInfo.Subject;
    CN := Copy(CN, Pos('CN=', CN) + 3, Length(CN));
    if Pos(',', CN) > 0 then
      CN := Copy(CN, 1, Pos(',', CN) - 1);

    Result := MatchHostname(nextpas.core.text.conv.Trim(CN), AHostname);
  end;
end;

function TSSLCertificateChainVerifier.BuildChain(ALeafCert: ISSLCertificate;
  out AChain: TSSLCertificateArray): Boolean;
var
  CurrentCert, IssuerCert: ISSLCertificate;
  ChainList: TInterfaceList;
  MaxDepth: Integer;
  LIndex: Integer;
begin
  Result := False;
  SetLength(AChain, 0);

  if ALeafCert = nil then
    Exit;

  ChainList := TInterfaceList.Create;
  try
    CurrentCert := ALeafCert;
    ChainList.Add(CurrentCert);
    MaxDepth := 10; // 防止无限循环

    // 构建证书链
    while (not IsSelfSigned(CurrentCert)) and
          (not IsRootCertificate(CurrentCert)) and
          (Length(ChainList) < MaxDepth) do
    begin
      IssuerCert := FindIssuer(CurrentCert);
      if IssuerCert = nil then
      begin
        // 无法找到颁发者，链断裂
        if cvoAllowPartialChain in FOptions then
          Result := True  // 允许部分链
        else
          Exit;
        Break;
      end;

      ChainList.Add(IssuerCert);
      CurrentCert := IssuerCert;
    end;

    // 转换为数组
    SetLength(AChain, Length(ChainList));
    for LIndex := 0 to Length(ChainList) - 1 do
      AChain[LIndex] := ISSLCertificate(ChainList[LIndex]);

    Result := True;
  finally
  end;
end;

function TSSLCertificateChainVerifier.VerifyCertificate(ACert: ISSLCertificate;
  const AHostname: string = ''): TChainVerifyResult;
var
  Chain: TSSLCertificateArray;
begin
  // 构建证书链
  if BuildChain(ACert, Chain) then
    Result := VerifyChain(Chain, AHostname)
  else
  begin
    Result.IsValid := False;
    Result.ErrorCode := -1;
    Result.ErrorMessage := 'Failed to build certificate chain';
    Result.ChainLength := 0;
    Result.TrustedRoot := False;
    Result.SelfSigned := IsSelfSigned(ACert);
    Result.HostnameMatch := False;
    Result.RevocationStatus := 0;
    Result.Warnings := nil;
  end;
end;

function TSSLCertificateChainVerifier.VerifyChain(const AChain: TSSLCertificateArray;
  const AHostname: string = ''): TChainVerifyResult;
var
  i: Integer;
  CurrentCert, IssuerCert: ISSLCertificate;
begin
  // 初始化结果
  Result.IsValid := True;
  Result.ErrorCode := 0;
  Result.ErrorMessage := '';
  Result.ChainLength := Length(AChain);
  Result.TrustedRoot := False;
  Result.SelfSigned := False;
  Result.HostnameMatch := True;
  Result.RevocationStatus := 0;

  FLastRevocationStatus := 0;
  FLastRevocationError := '';

  if Length(AChain) = 0 then
  begin
    Result.IsValid := False;
    Result.ErrorMessage := 'Empty certificate chain';
    Exit;
  end;

  // 检查主机名（只检查叶证书）
  if (cvoCheckHostname in FOptions) and (AHostname <> '') then
  begin
    Result.HostnameMatch := CheckHostname(AChain[0], AHostname);
    if not Result.HostnameMatch then
    begin
      Result.IsValid := False;
      Result.ErrorMessage := 'Hostname verification failed';
      Exit;
    end;
  end;

  // 验证证书链
  for i := 0 to High(AChain) do
  begin
    CurrentCert := AChain[i];

    // 检查时间有效性
    if cvoCheckTime in FOptions then
    begin
      if not CheckCertificateTime(CurrentCert) then
      begin
        Result.IsValid := False;
        Result.ErrorMessage := nextpas.core.text.conv.Format('Certificate %d expired or not yet valid', [i]);
        Exit;
      end;
    end;

    // 检查密钥用途
    if cvoCheckKeyUsage in FOptions then
    begin
      if not CheckCertificateKeyUsage(CurrentCert, i > 0) then
      begin
        Result.IsValid := False;
        Result.ErrorMessage := nextpas.core.text.conv.Format('Invalid key usage for certificate %d', [i]);
        Exit;
      end;
    end;

    if cvoCheckExtKeyUsage in FOptions then
    begin
      if not CheckCertificateExtendedKeyUsage(CurrentCert, i > 0) then
      begin
        Result.IsValid := False;
        if i = 0 then
          Result.ErrorMessage := 'Strict-chain verification requires serverAuth extended key usage on the leaf certificate'
        else
          Result.ErrorMessage := nextpas.core.text.conv.Format('Invalid extended key usage for certificate %d', [i]);
        Exit;
      end;
    end;

    // 检查吊销状态
    if cvoCheckRevocation in FOptions then
    begin
      if not CheckCertificateRevocation(CurrentCert) then
      begin
        Result.IsValid := False;
        Result.RevocationStatus := FLastRevocationStatus;
        if FLastRevocationStatus = 1 then
          Result.ErrorMessage := nextpas.core.text.conv.Format('Certificate %d is revoked', [i])
        else if FLastRevocationError <> '' then
          Result.ErrorMessage := nextpas.core.text.conv.Format(
            'Certificate %d revocation/CRL verification failed: %s',
            [i, FLastRevocationError]
          )
        else
          Result.ErrorMessage := nextpas.core.text.conv.Format('Certificate %d revocation/CRL status is unavailable', [i]);
        Exit;
      end;
    end;

    // 验证签名（除了根证书）
    if (cvoCheckSignature in FOptions) and (i < High(AChain)) then
    begin
      IssuerCert := AChain[i + 1];
      if not CheckCertificateSignature(CurrentCert, IssuerCert) then
      begin
        Result.IsValid := False;
        Result.ErrorMessage := nextpas.core.text.conv.Format('Invalid signature for certificate %d', [i]);
        Exit;
      end;
    end;
  end;

  // 检查根证书
  if High(AChain) >= 0 then
  begin
    Result.SelfSigned := IsSelfSigned(AChain[High(AChain)]);
    Result.TrustedRoot := IsRootCertificate(AChain[High(AChain)]);

    if not Result.TrustedRoot and not (cvoAllowSelfSigned in FOptions) then
    begin
      Result.IsValid := False;
      Result.ErrorMessage := 'Untrusted root certificate';
    end;
  end;

  // 验证路径长度约束
  if (cvoCheckCAConstraints in FOptions) and not ValidatePathLength(AChain) then
  begin
    Result.IsValid := False;
    Result.ErrorMessage := 'Path length constraint violated';
  end;
end;

end.
