{
  能力矩阵序列化单元

  提供 JSON 和 XML 格式的序列化/反序列化支持
}

unit nextpas.core.tls.capability.serializer;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.tls.base;

{ JSON 序列化 }
function CapabilitiesToJSON(const ACaps: TSSLBackendCapabilities;
                            const APretty: Boolean = True): string;
function JSONToCapabilities(const AJSON: string): TSSLBackendCapabilities;

{ XML 序列化 }
function CapabilitiesToXML(const ACaps: TSSLBackendCapabilities;
                          const APretty: Boolean = True): string;
function XMLToCapabilities(const AXML: string): TSSLBackendCapabilities;

{ 文件操作 }
procedure SaveCapabilitiesToFile(const ACaps: TSSLBackendCapabilities;
                                const AFileName: string;
                                const AFormat: string = 'json');  // 'json' or 'xml'
function LoadCapabilitiesFromFile(const AFileName: string): TSSLBackendCapabilities;

implementation

uses
  SysUtils, StrUtils,
  nextpas.core.exception;

{ Local helper: StringsSplit (text.strings PPU has loading issues) }
function StringsSplit(const AStr: string; ASep: Char; ARemoveEmpty: Boolean): TStringArray;
var
  I, LStart, LCount: Integer;
  LPart: string;
begin
  SetLength(Result, 0);
  LStart := 1;
  for I := 1 to Length(AStr) do
  begin
    if AStr[I] = ASep then
    begin
      LPart := Copy(AStr, LStart, I - LStart);
      if (not ARemoveEmpty) or (LPart <> '') then
      begin
        LCount := Length(Result);
        SetLength(Result, LCount + 1);
        Result[LCount] := LPart;
      end;
      LStart := I + 1;
    end;
  end;
  LPart := Copy(AStr, LStart, Length(AStr) - LStart + 1);
  if (not ARemoveEmpty) or (LPart <> '') then
  begin
    LCount := Length(Result);
    SetLength(Result, LCount + 1);
    Result[LCount] := LPart;
  end;
end;

{ ============================================================================ }
{ JSON 序列化 }
{ ============================================================================ }

function BoolToJSONStr(AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function JSONStrToBool(const AValue: string): Boolean;
begin
  Result := SameText(AValue, 'true');
end;

function FeatureLevelPresent(ALevel: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ALevel <> sslSupportNone;
end;

function HasAnySupportLevelTruth(const ACaps: TSSLBackendCapabilities): Boolean;
begin
  Result :=
    FeatureLevelPresent(ACaps.SNISupport) or
    FeatureLevelPresent(ACaps.ALPNSupport) or
    FeatureLevelPresent(ACaps.OCSPStaplingSupport) or
    FeatureLevelPresent(ACaps.CertTransparencySupport) or
    FeatureLevelPresent(ACaps.SessionTicketsSupport) or
    FeatureLevelPresent(ACaps.SessionCacheSupport) or
    FeatureLevelPresent(ACaps.ZeroRTTSupport) or
    FeatureLevelPresent(ACaps.EarlyDataSupport) or
    FeatureLevelPresent(ACaps.RenegotiationSupport) or
    FeatureLevelPresent(ACaps.PostHandshakeAuthSupport);
end;

procedure PrepareCapabilitiesForSerialization(
  const ASource: TSSLBackendCapabilities;
  out APrepared: TSSLBackendCapabilities);
begin
  APrepared := ASource;

  // Only normalize when the record already carries v1.2 support-level truth.
  // Pure legacy-only in-memory records still remain ambiguous without presence bits.
  if HasAnySupportLevelTruth(APrepared) then
    NormalizeLegacyCapabilityBooleans(APrepared);
end;

procedure ApplySupportLevelTruth(
  var ACaps: TSSLBackendCapabilities;
  const AHasSNISupport,
        AHasALPNSupport,
        AHasOCSPStaplingSupport,
        AHasCertTransparencySupport,
        AHasSessionTicketsSupport: Boolean);
begin
  if AHasSNISupport then
    ACaps.SupportsSNI := FeatureLevelPresent(ACaps.SNISupport);
  if AHasALPNSupport then
    ACaps.SupportsALPN := FeatureLevelPresent(ACaps.ALPNSupport);
  if AHasOCSPStaplingSupport then
    ACaps.SupportsOCSPStapling := FeatureLevelPresent(ACaps.OCSPStaplingSupport);
  if AHasCertTransparencySupport then
    ACaps.SupportsCertificateTransparency :=
      FeatureLevelPresent(ACaps.CertTransparencySupport);
  if AHasSessionTicketsSupport then
    ACaps.SupportsSessionTickets := FeatureLevelPresent(ACaps.SessionTicketsSupport);
end;

function EscapeJSON(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    case S[I] of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
      else
        Result := Result + S[I];
    end;
  end;
end;

function SetToJSONArray(const ASet; const ANames: array of string): string;
var
  I: Integer;
  First: Boolean;
  Value: Integer;
begin
  Result := '[';
  First := True;
  Value := Integer(ASet);

  for I := Low(ANames) to High(ANames) do
  begin
    if (Value and (1 shl I)) <> 0 then
    begin
      if not First then
        Result := Result + ', ';
      Result := Result + '"' + ANames[I] + '"';
      First := False;
    end;
  end;

  Result := Result + ']';
end;

function EncodeCipherSet(const ASet: TSSLCipherSupport): string;
var
  LCipher: TSSLCipher;
begin
  Result := '';
  for LCipher := Low(TSSLCipher) to High(TSSLCipher) do
  begin
    if LCipher in ASet then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + nextpas.core.text.conv.IntToStr(Ord(LCipher));
    end;
  end;
end;

function DecodeCipherSet(const AValue: string): TSSLCipherSupport;
var
  LParts: TStringArray;
  LPart: string;
  LOrdinal: Integer;
begin
  Result := [];
  if nextpas.core.text.conv.Trim(AValue) = '' then
    Exit;

    LParts := StringsSplit(AValue, ';', True);
    for LPart in LParts do
    begin
      LOrdinal := nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LPart), -1);
      if (LOrdinal >= Ord(Low(TSSLCipher))) and
        (LOrdinal <= Ord(High(TSSLCipher))) then
        Include(Result, TSSLCipher(LOrdinal));
    end;
end;

function EncodeHashSet(const ASet: TSSLHashSupport): string;
var
  LHash: TSSLHash;
begin
  Result := '';
  for LHash := Low(TSSLHash) to High(TSSLHash) do
  begin
    if LHash in ASet then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + nextpas.core.text.conv.IntToStr(Ord(LHash));
    end;
  end;
end;

function DecodeHashSet(const AValue: string): TSSLHashSupport;
var
  LParts: TStringArray;
  LPart: string;
  LOrdinal: Integer;
begin
  Result := [];
  if nextpas.core.text.conv.Trim(AValue) = '' then
    Exit;

    LParts := StringsSplit(AValue, ';', True);
    for LPart in LParts do
    begin
      LOrdinal := nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LPart), -1);
      if (LOrdinal >= Ord(Low(TSSLHash))) and
        (LOrdinal <= Ord(High(TSSLHash))) then
        Include(Result, TSSLHash(LOrdinal));
    end;
end;

function EncodeKeyExchangeSet(const ASet: TSSLKeyExchangeSupport): string;
var
  LKex: TSSLKeyExchange;
begin
  Result := '';
  for LKex := Low(TSSLKeyExchange) to High(TSSLKeyExchange) do
  begin
    if LKex in ASet then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + nextpas.core.text.conv.IntToStr(Ord(LKex));
    end;
  end;
end;

function DecodeKeyExchangeSet(const AValue: string): TSSLKeyExchangeSupport;
var
  LParts: TStringArray;
  LPart: string;
  LOrdinal: Integer;
begin
  Result := [];
  if nextpas.core.text.conv.Trim(AValue) = '' then
    Exit;

    LParts := StringsSplit(AValue, ';', True);
    for LPart in LParts do
    begin
      LOrdinal := nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LPart), -1);
      if (LOrdinal >= Ord(Low(TSSLKeyExchange))) and
        (LOrdinal <= Ord(High(TSSLKeyExchange))) then
        Include(Result, TSSLKeyExchange(LOrdinal));
    end;
end;

{ 6018 抑制范围含嵌套函数 FeatureSupportLevelToStr 等 — FPC 限制，函数级指令无法缩小到单个 case }
{$WARN 6018 OFF}
function CapabilitiesToJSON(const ACaps: TSSLBackendCapabilities;
                            const APretty: Boolean = True): string;
var
  LCaps: TSSLBackendCapabilities;
  LEmitSupportLevels: Boolean;
  Indent: string;
  NL: string;

  function AddField(const AName, AValue: string; ALast: Boolean = False): string;
  begin
    Result := Indent + '"' + AName + '": ' + AValue;
    if not ALast then
      Result := Result + ',';
    Result := Result + NL;
  end;

  function FeatureSupportLevelToStr(ALevel: TSSLFeatureSupportLevel): string;
  begin
    case ALevel of
      sslSupportNone: Result := '"none"';
      sslSupportExperimental: Result := '"experimental"';
      sslSupportStable: Result := '"stable"';
      sslSupportDeprecated: Result := '"deprecated"';
      else Result := '"unknown"';
    end;
  end;

begin
  PrepareCapabilitiesForSerialization(ACaps, LCaps);
  LEmitSupportLevels := HasAnySupportLevelTruth(LCaps);

  if APretty then
  begin
    Indent := '  ';
    NL := LineEnding;
  end
  else
  begin
    Indent := '';
    NL := '';
  end;

  Result := '{' + NL;

  // v1.1.0 字段
  Result := Result + AddField('supportsTLS13', BoolToJSONStr(LCaps.SupportsTLS13));
  Result := Result + AddField('supportsALPN', BoolToJSONStr(LCaps.SupportsALPN));
  Result := Result + AddField('supportsSNI', BoolToJSONStr(LCaps.SupportsSNI));
  Result := Result + AddField('supportsOCSPStapling', BoolToJSONStr(LCaps.SupportsOCSPStapling));
  Result := Result + AddField('supportsCertificateTransparency', BoolToJSONStr(LCaps.SupportsCertificateTransparency));
  Result := Result + AddField('supportsSessionTickets', BoolToJSONStr(LCaps.SupportsSessionTickets));
  Result := Result + AddField('supportsECDHE', BoolToJSONStr(LCaps.SupportsECDHE));
  Result := Result + AddField('supportsChaChaPoly', BoolToJSONStr(LCaps.SupportsChaChaPoly));
  Result := Result + AddField('supportsPEMPrivateKey', BoolToJSONStr(LCaps.SupportsPEMPrivateKey));
  Result := Result + AddField('minTLSVersion', nextpas.core.text.conv.IntToStr(Ord(LCaps.MinTLSVersion)));
  Result := Result + AddField('maxTLSVersion', nextpas.core.text.conv.IntToStr(Ord(LCaps.MaxTLSVersion)));

  // v1.2.0 字段
  Result := Result + AddField('backendType', nextpas.core.text.conv.IntToStr(Ord(LCaps.BackendType)));
  Result := Result + AddField('backendImplType', nextpas.core.text.conv.IntToStr(Ord(LCaps.BackendImplType)));
  Result := Result + AddField('backendVersion', '"' + EscapeJSON(LCaps.BackendVersion) + '"');
  Result := Result + AddField('supportsDTLS', BoolToJSONStr(LCaps.SupportsDTLS));

  // 功能支持级别
  if LEmitSupportLevels then
  begin
    Result := Result + AddField('sniSupport', FeatureSupportLevelToStr(LCaps.SNISupport));
    Result := Result + AddField('alpnSupport', FeatureSupportLevelToStr(LCaps.ALPNSupport));
    Result := Result + AddField('ocspStaplingSupport', FeatureSupportLevelToStr(LCaps.OCSPStaplingSupport));
    Result := Result + AddField('certTransparencySupport', FeatureSupportLevelToStr(LCaps.CertTransparencySupport));
    Result := Result + AddField('sessionTicketsSupport', FeatureSupportLevelToStr(LCaps.SessionTicketsSupport));
    Result := Result + AddField('sessionCacheSupport', FeatureSupportLevelToStr(LCaps.SessionCacheSupport));
    Result := Result + AddField('zeroRTTSupport', FeatureSupportLevelToStr(LCaps.ZeroRTTSupport));
    Result := Result + AddField('earlyDataSupport', FeatureSupportLevelToStr(LCaps.EarlyDataSupport));
    Result := Result + AddField('renegotiationSupport', FeatureSupportLevelToStr(LCaps.RenegotiationSupport));
    Result := Result + AddField('postHandshakeAuthSupport', FeatureSupportLevelToStr(LCaps.PostHandshakeAuthSupport));
  end;

  // 算法支持
  Result := Result + AddField('supportedCiphers', '"' + EncodeCipherSet(LCaps.SupportedCiphers) + '"');
  Result := Result + AddField('supportedHashes', '"' + EncodeHashSet(LCaps.SupportedHashes) + '"');
  Result := Result + AddField('supportedKeyExchanges', '"' + EncodeKeyExchangeSet(LCaps.SupportedKeyExchanges) + '"');

  // 性能特性
  Result := Result + AddField('hasHardwareAcceleration', BoolToJSONStr(LCaps.HasHardwareAcceleration));
  Result := Result + AddField('hasSIMDOptimization', BoolToJSONStr(LCaps.HasSIMDOptimization));
  Result := Result + AddField('hasAssemblyOptimization', BoolToJSONStr(LCaps.HasAssemblyOptimization));

  // 平台特性
  Result := Result + AddField('requiresExternalLibrary', BoolToJSONStr(LCaps.RequiresExternalLibrary));
  Result := Result + AddField('supportsSystemCertStore', BoolToJSONStr(LCaps.SupportsSystemCertStore));
  Result := Result + AddField('supportsPKCS11', BoolToJSONStr(LCaps.SupportsPKCS11));
  Result := Result + AddField('supportsTPM', BoolToJSONStr(LCaps.SupportsTPM));

  // 安全特性
  Result := Result + AddField('hasConstantTimeOperations', BoolToJSONStr(LCaps.HasConstantTimeOperations));
  Result := Result + AddField('supportsFIPSMode', BoolToJSONStr(LCaps.SupportsFIPSMode));
  Result := Result + AddField('hasSecureMemoryWipe', BoolToJSONStr(LCaps.HasSecureMemoryWipe));

  // 证书和密钥支持
  Result := Result + AddField('supportsDERPrivateKey', BoolToJSONStr(LCaps.SupportsDERPrivateKey));
  Result := Result + AddField('supportsPKCS8PrivateKey', BoolToJSONStr(LCaps.SupportsPKCS8PrivateKey));
  Result := Result + AddField('supportsPKCS12', BoolToJSONStr(LCaps.SupportsPKCS12));
  Result := Result + AddField('supportsPasswordProtectedKeys', BoolToJSONStr(LCaps.SupportsPasswordProtectedKeys));

  // 扩展性
  Result := Result + AddField('supportsCustomCipherSuites', BoolToJSONStr(LCaps.SupportsCustomCipherSuites));
  Result := Result + AddField('supportsCallbacks', BoolToJSONStr(LCaps.SupportsCallbacks));

  // 兼容性
  Result := Result + AddField('compatibilityLevel', nextpas.core.text.conv.IntToStr(LCaps.CompatibilityLevel));
  Result := Result + AddField('knownIssues', '"' + EscapeJSON(LCaps.KnownIssues) + '"', True);

  Result := Result + '}';
end;
{$WARN 6018 ON}

function JSONToCapabilities(const AJSON: string): TSSLBackendCapabilities;
var
  LValue: string;
  LIsString: Boolean;
  LHasSNISupport: Boolean;
  LHasALPNSupport: Boolean;
  LHasOCSPStaplingSupport: Boolean;
  LHasCertTransparencySupport: Boolean;
  LHasSessionTicketsSupport: Boolean;

  function IntToProtocolVersion(AInt: Integer): TSSLProtocolVersion;
  begin
    if (AInt >= Ord(Low(TSSLProtocolVersion))) and
      (AInt <= Ord(High(TSSLProtocolVersion))) then
      Result := TSSLProtocolVersion(AInt)
    else
      Result := sslProtocolUnknown;
  end;

  function IntToLibraryType(AInt: Integer): TSSLLibraryType;
  begin
    if (AInt >= Ord(Low(TSSLLibraryType))) and
      (AInt <= Ord(High(TSSLLibraryType))) then
      Result := TSSLLibraryType(AInt)
    else
      Result := sslAutoDetect;
  end;

  function IntToBackendImplType(AInt: Integer): TSSLBackendImplType;
  begin
    if (AInt >= Ord(Low(TSSLBackendImplType))) and
      (AInt <= Ord(High(TSSLBackendImplType))) then
      Result := TSSLBackendImplType(AInt)
    else
      Result := sslImplNative;
  end;

  function StrToFeatureSupportLevel(const AValue: string): TSSLFeatureSupportLevel;
  begin
    if SameText(AValue, 'none') then
      Result := sslSupportNone
    else if SameText(AValue, 'experimental') then
      Result := sslSupportExperimental
    else if SameText(AValue, 'stable') then
      Result := sslSupportStable
    else if SameText(AValue, 'deprecated') then
      Result := sslSupportDeprecated
    else
      Result := sslSupportNone;
  end;

  function JSONUnescape(const S: string): string;
  var
    I: Integer;
  begin
    Result := '';
    I := 1;
    while I <= Length(S) do
    begin
      if (S[I] = '\') and (I < Length(S)) then
      begin
        Inc(I);
        case S[I] of
          '"': Result := Result + '"';
          '\': Result := Result + '\';
          '/': Result := Result + '/';
          'b': Result := Result + #8;
          't': Result := Result + #9;
          'n': Result := Result + #10;
          'f': Result := Result + #12;
          'r': Result := Result + #13;
        else
          Result := Result + S[I];
        end;
      end
      else
        Result := Result + S[I];
      Inc(I);
    end;
  end;

  function ExtractJSONValue(const AName: string; out AOutValue: string;
    out AOutIsString: Boolean): Boolean;
  var
    LKey: string;
    LKeyPos: Integer;
    LColonPos: Integer;
    LPos: Integer;
    LStart: Integer;
    LEscaped: Boolean;
  begin
    Result := False;
    AOutValue := '';
    AOutIsString := False;

    LKey := '"' + AName + '"';
    LKeyPos := Pos(LKey, AJSON);
    if LKeyPos <= 0 then
      Exit;

    LColonPos := PosEx(':', AJSON, LKeyPos + Length(LKey));
    if LColonPos <= 0 then
      Exit;

    LPos := LColonPos + 1;
    while (LPos <= Length(AJSON)) and (AJSON[LPos] in [' ', #9, #10, #13]) do
      Inc(LPos);

    if LPos > Length(AJSON) then
      Exit;

    if AJSON[LPos] = '"' then
    begin
      AOutIsString := True;
      Inc(LPos);
      LStart := LPos;
      LEscaped := False;
      while LPos <= Length(AJSON) do
      begin
        if LEscaped then
          LEscaped := False
        else if AJSON[LPos] = '\\' then
          LEscaped := True
        else if AJSON[LPos] = '"' then
          Break;
        Inc(LPos);
      end;

      if (LPos > Length(AJSON)) or (AJSON[LPos] <> '"') then
        Exit;

      AOutValue := JSONUnescape(Copy(AJSON, LStart, LPos - LStart));
      Result := True;
      Exit;
    end;

    LStart := LPos;
    while (LPos <= Length(AJSON)) and not (AJSON[LPos] in [',', '}', #10, #13]) do
      Inc(LPos);

    AOutValue := nextpas.core.text.conv.Trim(Copy(AJSON, LStart, LPos - LStart));
    Result := AOutValue <> '';
  end;

begin
  Result := Default(TSSLBackendCapabilities);
  LHasSNISupport := False;
  LHasALPNSupport := False;
  LHasOCSPStaplingSupport := False;
  LHasCertTransparencySupport := False;
  LHasSessionTicketsSupport := False;

  // v1.1.0 字段
  if ExtractJSONValue('supportsTLS13', LValue, LIsString) then
    Result.SupportsTLS13 := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsALPN', LValue, LIsString) then
    Result.SupportsALPN := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsSNI', LValue, LIsString) then
    Result.SupportsSNI := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsOCSPStapling', LValue, LIsString) then
    Result.SupportsOCSPStapling := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsCertificateTransparency', LValue, LIsString) then
    Result.SupportsCertificateTransparency := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsSessionTickets', LValue, LIsString) then
    Result.SupportsSessionTickets := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsECDHE', LValue, LIsString) then
    Result.SupportsECDHE := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsChaChaPoly', LValue, LIsString) then
    Result.SupportsChaChaPoly := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsPEMPrivateKey', LValue, LIsString) then
    Result.SupportsPEMPrivateKey := JSONStrToBool(LValue);
  if ExtractJSONValue('minTLSVersion', LValue, LIsString) then
    Result.MinTLSVersion := IntToProtocolVersion(nextpas.core.text.conv.StrToIntDef(LValue, Ord(sslProtocolUnknown)));
  if ExtractJSONValue('maxTLSVersion', LValue, LIsString) then
    Result.MaxTLSVersion := IntToProtocolVersion(nextpas.core.text.conv.StrToIntDef(LValue, Ord(sslProtocolUnknown)));

  // v1.2.0 字段
  if ExtractJSONValue('backendType', LValue, LIsString) then
    Result.BackendType := IntToLibraryType(nextpas.core.text.conv.StrToIntDef(LValue, Ord(sslAutoDetect)));
  if ExtractJSONValue('backendImplType', LValue, LIsString) then
    Result.BackendImplType := IntToBackendImplType(nextpas.core.text.conv.StrToIntDef(LValue, Ord(sslImplNative)));
  if ExtractJSONValue('backendVersion', LValue, LIsString) then
    Result.BackendVersion := LValue;
  if ExtractJSONValue('supportsDTLS', LValue, LIsString) then
    Result.SupportsDTLS := JSONStrToBool(LValue);

  // 功能支持级别
  if ExtractJSONValue('sniSupport', LValue, LIsString) then
  begin
    Result.SNISupport := StrToFeatureSupportLevel(LValue);
    LHasSNISupport := True;
  end;
  if ExtractJSONValue('alpnSupport', LValue, LIsString) then
  begin
    Result.ALPNSupport := StrToFeatureSupportLevel(LValue);
    LHasALPNSupport := True;
  end;
  if ExtractJSONValue('ocspStaplingSupport', LValue, LIsString) then
  begin
    Result.OCSPStaplingSupport := StrToFeatureSupportLevel(LValue);
    LHasOCSPStaplingSupport := True;
  end;
  if ExtractJSONValue('certTransparencySupport', LValue, LIsString) then
  begin
    Result.CertTransparencySupport := StrToFeatureSupportLevel(LValue);
    LHasCertTransparencySupport := True;
  end;
  if ExtractJSONValue('sessionTicketsSupport', LValue, LIsString) then
  begin
    Result.SessionTicketsSupport := StrToFeatureSupportLevel(LValue);
    LHasSessionTicketsSupport := True;
  end;
  if ExtractJSONValue('sessionCacheSupport', LValue, LIsString) then
    Result.SessionCacheSupport := StrToFeatureSupportLevel(LValue);
  if ExtractJSONValue('zeroRTTSupport', LValue, LIsString) then
    Result.ZeroRTTSupport := StrToFeatureSupportLevel(LValue);
  if ExtractJSONValue('earlyDataSupport', LValue, LIsString) then
    Result.EarlyDataSupport := StrToFeatureSupportLevel(LValue);
  if ExtractJSONValue('renegotiationSupport', LValue, LIsString) then
    Result.RenegotiationSupport := StrToFeatureSupportLevel(LValue);
  if ExtractJSONValue('postHandshakeAuthSupport', LValue, LIsString) then
    Result.PostHandshakeAuthSupport := StrToFeatureSupportLevel(LValue);

  // 算法支持
  if ExtractJSONValue('supportedCiphers', LValue, LIsString) then
    Result.SupportedCiphers := DecodeCipherSet(LValue);
  if ExtractJSONValue('supportedHashes', LValue, LIsString) then
    Result.SupportedHashes := DecodeHashSet(LValue);
  if ExtractJSONValue('supportedKeyExchanges', LValue, LIsString) then
    Result.SupportedKeyExchanges := DecodeKeyExchangeSet(LValue);

  // 性能特性
  if ExtractJSONValue('hasHardwareAcceleration', LValue, LIsString) then
    Result.HasHardwareAcceleration := JSONStrToBool(LValue);
  if ExtractJSONValue('hasSIMDOptimization', LValue, LIsString) then
    Result.HasSIMDOptimization := JSONStrToBool(LValue);
  if ExtractJSONValue('hasAssemblyOptimization', LValue, LIsString) then
    Result.HasAssemblyOptimization := JSONStrToBool(LValue);

  // 平台特性
  if ExtractJSONValue('requiresExternalLibrary', LValue, LIsString) then
    Result.RequiresExternalLibrary := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsSystemCertStore', LValue, LIsString) then
    Result.SupportsSystemCertStore := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsPKCS11', LValue, LIsString) then
    Result.SupportsPKCS11 := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsTPM', LValue, LIsString) then
    Result.SupportsTPM := JSONStrToBool(LValue);

  // 安全特性
  if ExtractJSONValue('hasConstantTimeOperations', LValue, LIsString) then
    Result.HasConstantTimeOperations := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsFIPSMode', LValue, LIsString) then
    Result.SupportsFIPSMode := JSONStrToBool(LValue);
  if ExtractJSONValue('hasSecureMemoryWipe', LValue, LIsString) then
    Result.HasSecureMemoryWipe := JSONStrToBool(LValue);

  // 证书和密钥支持
  if ExtractJSONValue('supportsDERPrivateKey', LValue, LIsString) then
    Result.SupportsDERPrivateKey := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsPKCS8PrivateKey', LValue, LIsString) then
    Result.SupportsPKCS8PrivateKey := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsPKCS12', LValue, LIsString) then
    Result.SupportsPKCS12 := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsPasswordProtectedKeys', LValue, LIsString) then
    Result.SupportsPasswordProtectedKeys := JSONStrToBool(LValue);

  // 扩展性
  if ExtractJSONValue('supportsCustomCipherSuites', LValue, LIsString) then
    Result.SupportsCustomCipherSuites := JSONStrToBool(LValue);
  if ExtractJSONValue('supportsCallbacks', LValue, LIsString) then
    Result.SupportsCallbacks := JSONStrToBool(LValue);

  // 兼容性
  if ExtractJSONValue('compatibilityLevel', LValue, LIsString) then
    Result.CompatibilityLevel := nextpas.core.text.conv.StrToIntDef(LValue, 0);
  if ExtractJSONValue('knownIssues', LValue, LIsString) then
    Result.KnownIssues := LValue;

  // v1.2 support-level 字段一旦出现，就以它为真相源回填 legacy boolean
  ApplySupportLevelTruth(Result,
    LHasSNISupport,
    LHasALPNSupport,
    LHasOCSPStaplingSupport,
    LHasCertTransparencySupport,
    LHasSessionTicketsSupport);
end;

{ ============================================================================ }
{ XML 序列化 }
{ ============================================================================ }

{ 6018 抑制范围含嵌套函数 — 同 CapabilitiesToJSON }
{$WARN 6018 OFF}
function CapabilitiesToXML(const ACaps: TSSLBackendCapabilities;
                          const APretty: Boolean = True): string;
var
  LCaps: TSSLBackendCapabilities;
  LEmitSupportLevels: Boolean;
  Indent: string;
  NL: string;

  function XMLEscape(const S: string): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 1 to Length(S) do
    begin
      case S[I] of
        '<': Result := Result + '&lt;';
        '>': Result := Result + '&gt;';
        '&': Result := Result + '&amp;';
        '"': Result := Result + '&quot;';
        '''': Result := Result + '&apos;';
        else
          Result := Result + S[I];
      end;
    end;
  end;

  function AddElement(const AName, AValue: string; const AIndent: Integer = 1): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 1 to AIndent do
      Result := Result + Indent;
    Result := Result + '<' + AName + '>' + AValue + '</' + AName + '>' + NL;
  end;

  function FeatureSupportLevelToStr(ALevel: TSSLFeatureSupportLevel): string;
  begin
    case ALevel of
      sslSupportNone: Result := 'none';
      sslSupportExperimental: Result := 'experimental';
      sslSupportStable: Result := 'stable';
      sslSupportDeprecated: Result := 'deprecated';
      else Result := 'unknown';
    end;
  end;

begin
  PrepareCapabilitiesForSerialization(ACaps, LCaps);
  LEmitSupportLevels := HasAnySupportLevelTruth(LCaps);

  if APretty then
  begin
    Indent := '  ';
    NL := LineEnding;
  end
  else
  begin
    Indent := '';
    NL := '';
  end;

  Result := '<?xml version="1.0" encoding="UTF-8"?>' + NL;
  Result := Result + '<SSLBackendCapabilities>' + NL;

  // v1.1.0 字段
  Result := Result + AddElement('supportsTLS13', BoolToJSONStr(LCaps.SupportsTLS13));
  Result := Result + AddElement('supportsALPN', BoolToJSONStr(LCaps.SupportsALPN));
  Result := Result + AddElement('supportsSNI', BoolToJSONStr(LCaps.SupportsSNI));
  Result := Result + AddElement('supportsOCSPStapling', BoolToJSONStr(LCaps.SupportsOCSPStapling));
  Result := Result + AddElement('supportsCertificateTransparency', BoolToJSONStr(LCaps.SupportsCertificateTransparency));
  Result := Result + AddElement('supportsSessionTickets', BoolToJSONStr(LCaps.SupportsSessionTickets));
  Result := Result + AddElement('supportsECDHE', BoolToJSONStr(LCaps.SupportsECDHE));
  Result := Result + AddElement('supportsChaChaPoly', BoolToJSONStr(LCaps.SupportsChaChaPoly));
  Result := Result + AddElement('supportsPEMPrivateKey', BoolToJSONStr(LCaps.SupportsPEMPrivateKey));
  Result := Result + AddElement('minTLSVersion', nextpas.core.text.conv.IntToStr(Ord(LCaps.MinTLSVersion)));
  Result := Result + AddElement('maxTLSVersion', nextpas.core.text.conv.IntToStr(Ord(LCaps.MaxTLSVersion)));

  // v1.2.0 字段
  Result := Result + AddElement('backendType', nextpas.core.text.conv.IntToStr(Ord(LCaps.BackendType)));
  Result := Result + AddElement('backendImplType', nextpas.core.text.conv.IntToStr(Ord(LCaps.BackendImplType)));
  Result := Result + AddElement('backendVersion', XMLEscape(LCaps.BackendVersion));
  Result := Result + AddElement('supportsDTLS', BoolToJSONStr(LCaps.SupportsDTLS));

  // 功能支持级别
  if LEmitSupportLevels then
  begin
    Result := Result + AddElement('sniSupport', FeatureSupportLevelToStr(LCaps.SNISupport));
    Result := Result + AddElement('alpnSupport', FeatureSupportLevelToStr(LCaps.ALPNSupport));
    Result := Result + AddElement('ocspStaplingSupport', FeatureSupportLevelToStr(LCaps.OCSPStaplingSupport));
    Result := Result + AddElement('certTransparencySupport', FeatureSupportLevelToStr(LCaps.CertTransparencySupport));
    Result := Result + AddElement('sessionTicketsSupport', FeatureSupportLevelToStr(LCaps.SessionTicketsSupport));
    Result := Result + AddElement('sessionCacheSupport', FeatureSupportLevelToStr(LCaps.SessionCacheSupport));
    Result := Result + AddElement('zeroRTTSupport', FeatureSupportLevelToStr(LCaps.ZeroRTTSupport));
    Result := Result + AddElement('earlyDataSupport', FeatureSupportLevelToStr(LCaps.EarlyDataSupport));
    Result := Result + AddElement('renegotiationSupport', FeatureSupportLevelToStr(LCaps.RenegotiationSupport));
    Result := Result + AddElement('postHandshakeAuthSupport', FeatureSupportLevelToStr(LCaps.PostHandshakeAuthSupport));
  end;

  // 算法支持
  Result := Result + AddElement('supportedCiphers', EncodeCipherSet(LCaps.SupportedCiphers));
  Result := Result + AddElement('supportedHashes', EncodeHashSet(LCaps.SupportedHashes));
  Result := Result + AddElement('supportedKeyExchanges', EncodeKeyExchangeSet(LCaps.SupportedKeyExchanges));

  // 性能特性
  Result := Result + AddElement('hasHardwareAcceleration', BoolToJSONStr(LCaps.HasHardwareAcceleration));
  Result := Result + AddElement('hasSIMDOptimization', BoolToJSONStr(LCaps.HasSIMDOptimization));
  Result := Result + AddElement('hasAssemblyOptimization', BoolToJSONStr(LCaps.HasAssemblyOptimization));

  // 平台特性
  Result := Result + AddElement('requiresExternalLibrary', BoolToJSONStr(LCaps.RequiresExternalLibrary));
  Result := Result + AddElement('supportsSystemCertStore', BoolToJSONStr(LCaps.SupportsSystemCertStore));
  Result := Result + AddElement('supportsPKCS11', BoolToJSONStr(LCaps.SupportsPKCS11));
  Result := Result + AddElement('supportsTPM', BoolToJSONStr(LCaps.SupportsTPM));

  // 安全特性
  Result := Result + AddElement('hasConstantTimeOperations', BoolToJSONStr(LCaps.HasConstantTimeOperations));
  Result := Result + AddElement('supportsFIPSMode', BoolToJSONStr(LCaps.SupportsFIPSMode));
  Result := Result + AddElement('hasSecureMemoryWipe', BoolToJSONStr(LCaps.HasSecureMemoryWipe));

  // 证书和密钥支持
  Result := Result + AddElement('supportsDERPrivateKey', BoolToJSONStr(LCaps.SupportsDERPrivateKey));
  Result := Result + AddElement('supportsPKCS8PrivateKey', BoolToJSONStr(LCaps.SupportsPKCS8PrivateKey));
  Result := Result + AddElement('supportsPKCS12', BoolToJSONStr(LCaps.SupportsPKCS12));
  Result := Result + AddElement('supportsPasswordProtectedKeys', BoolToJSONStr(LCaps.SupportsPasswordProtectedKeys));

  // 扩展性
  Result := Result + AddElement('supportsCustomCipherSuites', BoolToJSONStr(LCaps.SupportsCustomCipherSuites));
  Result := Result + AddElement('supportsCallbacks', BoolToJSONStr(LCaps.SupportsCallbacks));

  // 兼容性
  Result := Result + AddElement('compatibilityLevel', nextpas.core.text.conv.IntToStr(LCaps.CompatibilityLevel));
  Result := Result + AddElement('knownIssues', XMLEscape(LCaps.KnownIssues));

  Result := Result + '</SSLBackendCapabilities>';
end;
{$WARN 6018 ON}

function XMLToCapabilities(const AXML: string): TSSLBackendCapabilities;
var
  LValue: string;
  LHasSNISupport: Boolean;
  LHasALPNSupport: Boolean;
  LHasOCSPStaplingSupport: Boolean;
  LHasCertTransparencySupport: Boolean;
  LHasSessionTicketsSupport: Boolean;

  function IntToProtocolVersion(AInt: Integer): TSSLProtocolVersion;
  begin
    if (AInt >= Ord(Low(TSSLProtocolVersion))) and
      (AInt <= Ord(High(TSSLProtocolVersion))) then
      Result := TSSLProtocolVersion(AInt)
    else
      Result := sslProtocolUnknown;
  end;

  function IntToLibraryType(AInt: Integer): TSSLLibraryType;
  begin
    if (AInt >= Ord(Low(TSSLLibraryType))) and
      (AInt <= Ord(High(TSSLLibraryType))) then
      Result := TSSLLibraryType(AInt)
    else
      Result := sslAutoDetect;
  end;

  function IntToBackendImplType(AInt: Integer): TSSLBackendImplType;
  begin
    if (AInt >= Ord(Low(TSSLBackendImplType))) and
      (AInt <= Ord(High(TSSLBackendImplType))) then
      Result := TSSLBackendImplType(AInt)
    else
      Result := sslImplNative;
  end;

  function StrToFeatureSupportLevel(const AValue: string): TSSLFeatureSupportLevel;
  begin
    if SameText(AValue, 'none') then
      Result := sslSupportNone
    else if SameText(AValue, 'experimental') then
      Result := sslSupportExperimental
    else if SameText(AValue, 'stable') then
      Result := sslSupportStable
    else if SameText(AValue, 'deprecated') then
      Result := sslSupportDeprecated
    else
      Result := sslSupportNone;
  end;

  function XMLUnescape(const S: string): string;
  begin
    Result := S;
    Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
    Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
    Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
    Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
    Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  end;

  function ExtractXMLValue(const AName: string; out AOutValue: string): Boolean;
  var
    LOpenTag: string;
    LCloseTag: string;
    LOpenPos: Integer;
    LValueStart: Integer;
    LClosePos: Integer;
  begin
    Result := False;
    AOutValue := '';

    LOpenTag := '<' + AName + '>';
    LCloseTag := '</' + AName + '>';

    LOpenPos := Pos(LOpenTag, AXML);
    if LOpenPos <= 0 then
      Exit;

    LValueStart := LOpenPos + Length(LOpenTag);
    LClosePos := PosEx(LCloseTag, AXML, LValueStart);
    if LClosePos <= 0 then
      Exit;

    AOutValue := XMLUnescape(Copy(AXML, LValueStart, LClosePos - LValueStart));
    Result := True;
  end;

begin
  Result := Default(TSSLBackendCapabilities);
  LHasSNISupport := False;
  LHasALPNSupport := False;
  LHasOCSPStaplingSupport := False;
  LHasCertTransparencySupport := False;
  LHasSessionTicketsSupport := False;

  // v1.1.0 字段
  if ExtractXMLValue('supportsTLS13', LValue) then
    Result.SupportsTLS13 := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsALPN', LValue) then
    Result.SupportsALPN := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsSNI', LValue) then
    Result.SupportsSNI := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsOCSPStapling', LValue) then
    Result.SupportsOCSPStapling := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsCertificateTransparency', LValue) then
    Result.SupportsCertificateTransparency := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsSessionTickets', LValue) then
    Result.SupportsSessionTickets := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsECDHE', LValue) then
    Result.SupportsECDHE := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsChaChaPoly', LValue) then
    Result.SupportsChaChaPoly := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsPEMPrivateKey', LValue) then
    Result.SupportsPEMPrivateKey := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('minTLSVersion', LValue) then
    Result.MinTLSVersion := IntToProtocolVersion(nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LValue), Ord(sslProtocolUnknown)));
  if ExtractXMLValue('maxTLSVersion', LValue) then
    Result.MaxTLSVersion := IntToProtocolVersion(nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LValue), Ord(sslProtocolUnknown)));

  // v1.2.0 字段
  if ExtractXMLValue('backendType', LValue) then
    Result.BackendType := IntToLibraryType(nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LValue), Ord(sslAutoDetect)));
  if ExtractXMLValue('backendImplType', LValue) then
    Result.BackendImplType := IntToBackendImplType(nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LValue), Ord(sslImplNative)));
  if ExtractXMLValue('backendVersion', LValue) then
    Result.BackendVersion := LValue;
  if ExtractXMLValue('supportsDTLS', LValue) then
    Result.SupportsDTLS := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 功能支持级别
  if ExtractXMLValue('sniSupport', LValue) then
  begin
    Result.SNISupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
    LHasSNISupport := True;
  end;
  if ExtractXMLValue('alpnSupport', LValue) then
  begin
    Result.ALPNSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
    LHasALPNSupport := True;
  end;
  if ExtractXMLValue('ocspStaplingSupport', LValue) then
  begin
    Result.OCSPStaplingSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
    LHasOCSPStaplingSupport := True;
  end;
  if ExtractXMLValue('certTransparencySupport', LValue) then
  begin
    Result.CertTransparencySupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
    LHasCertTransparencySupport := True;
  end;
  if ExtractXMLValue('sessionTicketsSupport', LValue) then
  begin
    Result.SessionTicketsSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
    LHasSessionTicketsSupport := True;
  end;
  if ExtractXMLValue('sessionCacheSupport', LValue) then
    Result.SessionCacheSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('zeroRTTSupport', LValue) then
    Result.ZeroRTTSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('earlyDataSupport', LValue) then
    Result.EarlyDataSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('renegotiationSupport', LValue) then
    Result.RenegotiationSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('postHandshakeAuthSupport', LValue) then
    Result.PostHandshakeAuthSupport := StrToFeatureSupportLevel(nextpas.core.text.conv.Trim(LValue));

  // 算法支持
  if ExtractXMLValue('supportedCiphers', LValue) then
    Result.SupportedCiphers := DecodeCipherSet(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportedHashes', LValue) then
    Result.SupportedHashes := DecodeHashSet(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportedKeyExchanges', LValue) then
    Result.SupportedKeyExchanges := DecodeKeyExchangeSet(nextpas.core.text.conv.Trim(LValue));

  // 性能特性
  if ExtractXMLValue('hasHardwareAcceleration', LValue) then
    Result.HasHardwareAcceleration := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('hasSIMDOptimization', LValue) then
    Result.HasSIMDOptimization := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('hasAssemblyOptimization', LValue) then
    Result.HasAssemblyOptimization := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 平台特性
  if ExtractXMLValue('requiresExternalLibrary', LValue) then
    Result.RequiresExternalLibrary := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsSystemCertStore', LValue) then
    Result.SupportsSystemCertStore := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsPKCS11', LValue) then
    Result.SupportsPKCS11 := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsTPM', LValue) then
    Result.SupportsTPM := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 安全特性
  if ExtractXMLValue('hasConstantTimeOperations', LValue) then
    Result.HasConstantTimeOperations := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsFIPSMode', LValue) then
    Result.SupportsFIPSMode := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('hasSecureMemoryWipe', LValue) then
    Result.HasSecureMemoryWipe := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 证书和密钥支持
  if ExtractXMLValue('supportsDERPrivateKey', LValue) then
    Result.SupportsDERPrivateKey := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsPKCS8PrivateKey', LValue) then
    Result.SupportsPKCS8PrivateKey := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsPKCS12', LValue) then
    Result.SupportsPKCS12 := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsPasswordProtectedKeys', LValue) then
    Result.SupportsPasswordProtectedKeys := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 扩展性
  if ExtractXMLValue('supportsCustomCipherSuites', LValue) then
    Result.SupportsCustomCipherSuites := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));
  if ExtractXMLValue('supportsCallbacks', LValue) then
    Result.SupportsCallbacks := JSONStrToBool(nextpas.core.text.conv.Trim(LValue));

  // 兼容性
  if ExtractXMLValue('compatibilityLevel', LValue) then
    Result.CompatibilityLevel := nextpas.core.text.conv.StrToIntDef(nextpas.core.text.conv.Trim(LValue), 0);
  if ExtractXMLValue('knownIssues', LValue) then
    Result.KnownIssues := LValue;

  // v1.2 support-level 字段一旦出现，就以它为真相源回填 legacy boolean
  ApplySupportLevelTruth(Result,
    LHasSNISupport,
    LHasALPNSupport,
    LHasOCSPStaplingSupport,
    LHasCertTransparencySupport,
    LHasSessionTicketsSupport);
end;

{ ============================================================================ }
{ 文件操作 }
{ ============================================================================ }

procedure SaveCapabilitiesToFile(const ACaps: TSSLBackendCapabilities;
                                const AFileName: string;
                                const AFormat: string = 'json');
var
  Content: string;
  F: System.TextFile;
begin
  if SameText(AFormat, 'json') then
    Content := CapabilitiesToJSON(ACaps, True)
  else if SameText(AFormat, 'xml') then
    Content := CapabilitiesToXML(ACaps, True)
  else
    raise Exception.CreateFmt('Unsupported format: %s', [AFormat]);

  System.Assign(F, AFileName);
  System.Rewrite(F);
  try
    System.Write(F, Content);
  finally
    System.Close(F);
  end;
end;

function LoadCapabilitiesFromFile(const AFileName: string): TSSLBackendCapabilities;
var
  Content: string;
  Ext: string;
  F: file;
  LFileSize: Integer;
begin
  System.Assign(F, AFileName);
  System.Reset(F, 1);
  try
    LFileSize := System.FileSize(F);
    SetLength(Content, LFileSize);
    if LFileSize > 0 then
      System.BlockRead(F, Content[1], LFileSize);
  finally
    System.Close(F);
  end;
    Ext := LowerCase(ExtractFileExt(AFileName));
    if Ext = '.json' then
      Result := JSONToCapabilities(Content)
    else if Ext = '.xml' then
      Result := XMLToCapabilities(Content)
    else
      raise Exception.CreateFmt('Unknown file extension: %s', [Ext]);
end;

end.
