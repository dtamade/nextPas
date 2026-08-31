unit nextpas.core.deliverability.spf;
{**
 * @desc SPF 校验(RFC 7208 子集): v=spf1 记录评估、机制/qualifier/宏、
 *       10 次 DNS 查询上限(INV-1~4, 契约 §3/§4)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.deliverability.base;

{ 评估 domain 对 clientIP 的 SPF 记录; ASender 信封 MAIL FROM(空则
  %s/%l/%o 宏展开失败→permerror); 无记录→srNone }
function SpfCheck(const ADns: IDeliverabilityDns; const ADomain: string;
  const AClientIP: string; const ASender: string; const ATimeoutMs: Int32;
  out AError: string): TSpfResult;

implementation

uses
  nextpas.core.base,
  nextpas.core.net.resolve,
  nextpas.core.text.conv,
  nextpas.core.time.offsetdatetime;

const
  SPF_MAX_LOOKUPS = 10;

type
  TQueryKind = (qkTXT, qkA, qkMX);

  TMechResult = (mrMatch, mrNoMatch, mrError);

  TSpfEval = record
    Dns: IDeliverabilityDns;
    ClientIP: string;            { 原始文本 }
    ClientV4: TBytes;            { 4B; 空 = 非 v4 }
    ClientV6: TBytes;            { 16B; 空 = 非 v6 }
    Sender: string;
    TimeoutMs: Int32;
    Lookups: Integer;            { 10 上限计数(§4.6.4) }
    VoidLookups: Integer;        { 空应答/NXDOMAIN 计数(上限 2) }
  end;

{ ── 通用助手(无 SysUtils) ────────────────────────────────────── }

function TrimAscii(const AStr: string): string;
var
  L, R: Integer;
begin
  L := 1;
  while (L <= Length(AStr)) and (AStr[L] <= ' ') do
    Inc(L);
  R := Length(AStr);
  while (R >= L) and (AStr[R] <= ' ') do
    Dec(R);
  Result := Copy(AStr, L, R - L + 1);
end;

function LowerAscii(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Inc(Result[I], 32);
end;

function TryParseIPv4(const AText: string; out ABytes: TBytes): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv4(TrimAscii(AText), ABytes);
end;

function TryParseIPv6(const AText: string; out AOctets: TBytes): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv6(TrimAscii(AText), AOctets);
end;

{ 客户端 IP 解析; 非法 → False(INV-12: 空/坏 IP → permerror) }
function PrepareClientIP(var ACtx: TSpfEval): Boolean;
var
  LV4, LV6: TBytes;
begin
  ACtx.ClientV4 := nil;
  ACtx.ClientV6 := nil;
  if TryParseIPv4(ACtx.ClientIP, LV4) then
    ACtx.ClientV4 := LV4
  else if TryParseIPv6(ACtx.ClientIP, LV6) then
    ACtx.ClientV6 := LV6
  else
  begin
    Result := False;
    Exit;
  end;
  Result := True;
end;

function IsClientV4(const ACtx: TSpfEval): Boolean;
begin
  Result := Length(ACtx.ClientV4) = 4;
end;

function IsClientV6(const ACtx: TSpfEval): Boolean;
begin
  Result := Length(ACtx.ClientV6) = 16;
end;

{ 前缀匹配: AIpIsV4 时 ANet 为 v4 文本否则 v6 文本; ACidr=-1 表示默认全位 }
function IpMatchesPrefix(const ACtx: TSpfEval; const ANet: string;
  const ACidr: Integer; const AIpIsV4: Boolean): Boolean;
var
  LV4Net, LV6Net: TBytes;
  LSrc, LNet: TBytes;
  LI, LCidr: Integer;
  LByteMask: Byte;
begin
  Result := False;
  if AIpIsV4 then
  begin
    if (not IsClientV4(ACtx)) or (ACidr > 32) then
      Exit;
    if not TryParseIPv4(ANet, LV4Net) then
      Exit;
    LSrc := ACtx.ClientV4;
    LNet := LV4Net;
    if ACidr < 0 then
      LCidr := 32
    else
      LCidr := ACidr;
  end
  else
  begin
    if (not IsClientV6(ACtx)) or (ACidr > 128) then
      Exit;
    if not TryParseIPv6(ANet, LV6Net) then
      Exit;
    LSrc := ACtx.ClientV6;
    LNet := LV6Net;
    if ACidr < 0 then
      LCidr := 128
    else
      LCidr := ACidr;
  end;
  if LCidr = 0 then
  begin
    Result := True;
    Exit;
  end;
  for LI := 0 to Length(LSrc) - 1 do
  begin
    if LCidr >= (LI + 1) * 8 then
      LByteMask := $FF
    else if LCidr <= LI * 8 then
      LByteMask := 0
    else
      LByteMask := Byte($FF shl (8 - (LCidr - LI * 8)));
    if Byte(LSrc[LI] and LByteMask) <> Byte(LNet[LI] and LByteMask) then
      Exit;
  end;
  Result := True;
end;

{ ── 宏展开(RFC 7208 §7 子集, 纯替换, 无修饰) ────────────────── }

function ExpandMacros(const ACtx: TSpfEval; const ADomain: string;
  const ATemplate: string; out AResult: string): Boolean;
var
  LOut: string;
  LI, LClose: Integer;
  LKey: Char;
  LMacro: string;
  LNow: TOffsetDateTime;
  LSenderAt: Integer;
begin
  Result := False;
  LOut := '';
  LI := 1;
  while LI <= Length(ATemplate) do
  begin
    if ATemplate[LI] <> '%' then
    begin
      LOut := LOut + ATemplate[LI];
      Inc(LI);
      Continue;
    end;
    if (LI + 1 > Length(ATemplate)) or (ATemplate[LI + 1] <> '{') then
      Exit;                       { 裸 '%' 畸形 }
    LClose := LI + 2;
    while (LClose <= Length(ATemplate)) and (ATemplate[LClose] <> '}') do
      Inc(LClose);
    if LClose > Length(ATemplate) then
      Exit;                       { 未闭合 }
    LMacro := Copy(ATemplate, LI + 2, LClose - LI - 2);
    if Length(LMacro) <> 1 then
      Exit;                       { 修饰(分隔符/截断/翻转)不支持 }
    LKey := LowerAscii(LMacro)[1];
    case LKey of
      's':
        if ACtx.Sender = '' then
          Exit
        else
          LOut := LOut + ACtx.Sender;
      'l':
        begin
          if ACtx.Sender = '' then
            Exit;
          LSenderAt := Pos('@', ACtx.Sender);
          if LSenderAt = 0 then
            LOut := LOut + ACtx.Sender
          else
            LOut := LOut + Copy(ACtx.Sender, 1, LSenderAt - 1);
        end;
      'o':
        begin
          if ACtx.Sender = '' then
            Exit;
          LSenderAt := Pos('@', ACtx.Sender);
          if LSenderAt = 0 then
            Exit
          else
            LOut := LOut + Copy(ACtx.Sender, LSenderAt + 1, MaxInt);
        end;
      'd': LOut := LOut + ADomain;
      'i': LOut := LOut + ACtx.ClientIP;
      'p': LOut := LOut + 'unknown';   { 无 PTR 验证 }
      'v':
        if IsClientV4(ACtx) then
          LOut := LOut + 'in-addr'
        else
          LOut := LOut + 'ip6';
      'h': LOut := LOut + 'unknown';   { 无 HELO 上下文 }
      'c': LOut := LOut + ACtx.ClientIP;
      'r': LOut := LOut + 'unknown';   { 无 PTR }
      't':
        begin
          LNow := TOffsetDateTime.NowUtc;
          LOut := LOut + IntToStr(LNow.ToUnixSeconds);
        end;
    else
      Exit;                       { 未知宏 }
    end;
    LI := LClose + 1;
  end;
  AResult := LOut;
  Result := True;
end;

{ ── 记录与机制 ──────────────────────────────────────────────── }

function IsNoRecordError(const AErr: string): Boolean;
begin
  Result := (Pos('nxdomain', AErr) > 0) or (Pos('no record', AErr) > 0)
    or (Pos('none', AErr) > 0);
end;

{ 预算检查 + 计数 + 委托查询; False = 预算耗尽或网络错误(LErr 有因) }
function QueryWithBudget(var ACtx: TSpfEval; const AKind: TQueryKind;
  const AName: string; out AOut: TDeliverabilityStringArray;
  out AErr: string): Boolean;
begin
  Result := False;
  if ACtx.Lookups >= SPF_MAX_LOOKUPS then
  begin
    AErr := 'too many DNS lookups';
    Exit;
  end;
  Inc(ACtx.Lookups);
  case AKind of
    qkTXT: Result := ACtx.Dns.QueryTXT(AName, ACtx.TimeoutMs, AOut, AErr);
    qkA: Result := ACtx.Dns.QueryA(AName, ACtx.TimeoutMs, AOut, AErr);
    qkMX: Result := ACtx.Dns.QueryMX(AName, ACtx.TimeoutMs, AOut, AErr);
  end;
  { void lookup(§4.6.4): 空应答或 NXDOMAIN 上限 2 → permerror }
  if (not Result) and IsNoRecordError(AErr) then
  begin
    Inc(ACtx.VoidLookups);
    if ACtx.VoidLookups > 2 then
    begin
      AErr := 'too many void lookups';
      Result := False;
    end;
  end;
end;

{ 'a'/'mx' 机制文本 → (域, v4cidr, v6cidr); cidr=-1 = 全等(缺省)。
  RFC 7208 §5.3/5.4 ABNF: [ ":" domain-spec ] [ ip4-cidr ] [ "/" ip6-cidr ] }
procedure ParseDomainCidr(const AMech: string; const ACurrentDomain: string;
  out ADomain: string; out AV4Cidr, AV6Cidr: Integer; out AErr: Boolean);
var
  LRest, LCidrText: string;
  LSlash1, LSlash2, LCode: Integer;
  LV: Integer;
begin
  AErr := False;
  ADomain := ACurrentDomain;
  AV4Cidr := -1;
  AV6Cidr := -1;
  if AMech[1] = 'm' then
    LRest := Copy(AMech, 3, MaxInt)    { 'mx' 去 2 字符 }
  else
    LRest := Copy(AMech, 2, MaxInt);   { 'a' 去 1 字符 }
  if (Length(LRest) > 0) and (LRest[1] = ':') then
    Delete(LRest, 1, 1);
  if LRest = '' then
    Exit;
  LSlash1 := Pos('/', LRest);
  if LSlash1 > 0 then
  begin
    ADomain := Copy(LRest, 1, LSlash1 - 1);
    LCidrText := Copy(LRest, LSlash1 + 1, MaxInt);
    LSlash2 := Pos('/', LCidrText);
    if LSlash2 = 0 then
    begin
      { 单 cidr = ip4-cidr; v6 用缺省 }
      Val(LCidrText, LV, LCode);
      if (LCode <> 0) or (LV < 0) or (LV > 32) then
        AErr := True
      else
        AV4Cidr := LV;
    end
    else
    begin
      Val(Copy(LCidrText, 1, LSlash2 - 1), LV, LCode);
      if (LCode <> 0) or (LV < 0) or (LV > 32) then
        AErr := True
      else
        AV4Cidr := LV;
      Val(Copy(LCidrText, LSlash2 + 1, MaxInt), LV, LCode);
      if (LCode <> 0) or (LV < 0) or (LV > 128) then
        AErr := True
      else
        AV6Cidr := LV;
    end;
    Exit;
  end;
  ADomain := LRest;
end;

function MatchIpMechanism(const ACtx: TSpfEval; const AMech: string;
  const AIpIsV4: Boolean): TMechResult;
var
  LNet: string;
  LCidr, LCode, LSlash: Integer;
begin
  LNet := Copy(AMech, 5, MaxInt);    { 去 'ip4:'/'ip6:' }
  LCidr := -1;
  LSlash := Pos('/', LNet);
  if LSlash > 0 then
  begin
    Val(Copy(LNet, LSlash + 1, MaxInt), LCidr, LCode);
    if (LCode <> 0) or (LCidr < 0) or (LCidr > 128) or
      (AIpIsV4 and (LCidr > 32)) then
    begin
      Result := mrError;
      Exit;
    end;
    LNet := Copy(LNet, 1, LSlash - 1);
  end;
  if IpMatchesPrefix(ACtx, LNet, LCidr, AIpIsV4) then
    Result := mrMatch
  else
    Result := mrNoMatch;
end;

function MatchAMechanism(var ACtx: TSpfEval; const AMech: string;
  const ACurrentDomain: string): TMechResult;
var
  LDomain, LExpanded, LErr: string;
  LIps: TDeliverabilityStringArray;
  LV4Cidr, LV6Cidr: Integer;
  LErrFlag: Boolean;
  LI: Integer;
  LIsV4: Boolean;
begin
  ParseDomainCidr(AMech, ACurrentDomain, LDomain, LV4Cidr, LV6Cidr,
    LErrFlag);
  if LErrFlag then
  begin
    Result := mrError;
    Exit;
  end;
  { 宏展开(RFC 7208 §4.8) }
  if not ExpandMacros(ACtx, ACurrentDomain, LDomain, LExpanded) then
  begin
    Result := mrError;
    Exit;
  end;
  if not QueryWithBudget(ACtx, qkA, LowerAscii(LExpanded), LIps, LErr) then
  begin
    if IsNoRecordError(LErr) then
      Result := mrNoMatch
    else
      Result := mrError;
    Exit;
  end;
  LIsV4 := IsClientV4(ACtx);
  for LI := 0 to High(LIps) do
    if (LIsV4 and IpMatchesPrefix(ACtx, LIps[LI], LV4Cidr, True)) or
      ((not LIsV4) and IpMatchesPrefix(ACtx, LIps[LI], LV6Cidr, False)) then
    begin
      Result := mrMatch;
      Exit;
    end;
  Result := mrNoMatch;
end;

function MatchMXMechanism(var ACtx: TSpfEval; const AMech: string;
  const ACurrentDomain: string): TMechResult;
var
  LDomain, LExpanded, LErr: string;
  LHosts, LIps: TDeliverabilityStringArray;
  LV4Cidr, LV6Cidr: Integer;
  LErrFlag: Boolean;
  LI, LJ: Integer;
  LIsV4: Boolean;
begin
  ParseDomainCidr(AMech, ACurrentDomain, LDomain, LV4Cidr, LV6Cidr,
    LErrFlag);
  if LErrFlag then
  begin
    Result := mrError;
    Exit;
  end;
  if not ExpandMacros(ACtx, ACurrentDomain, LDomain, LExpanded) then
  begin
    Result := mrError;
    Exit;
  end;
  if not QueryWithBudget(ACtx, qkMX, LowerAscii(LExpanded), LHosts, LErr) then
  begin
    if IsNoRecordError(LErr) then
      Result := mrNoMatch
    else
      Result := mrError;
    Exit;
  end;
  LIsV4 := IsClientV4(ACtx);
  for LI := 0 to High(LHosts) do
  begin
    LDomain := LHosts[LI];
    if (Length(LDomain) > 0) and (LDomain[Length(LDomain)] = '.') then
      Delete(LDomain, Length(LDomain), 1);
    if LDomain = '' then
      Continue;
    if not QueryWithBudget(ACtx, qkA, LowerAscii(LDomain), LIps, LErr) then
      Continue;                  { 该 MX 的 A 解析失败 → 下一个 }
    if Length(LIps) > 10 then
    begin
      Result := mrError;         { §4.6.4: 单 MX 地址记录上限 10 → permerror }
      Exit;
    end;
    for LJ := 0 to High(LIps) do
      if (LIsV4 and IpMatchesPrefix(ACtx, LIps[LJ], LV4Cidr, True)) or
        ((not LIsV4) and IpMatchesPrefix(ACtx, LIps[LJ], LV6Cidr, False)) then
      begin
        Result := mrMatch;
        Exit;
      end;
  end;
  Result := mrNoMatch;
end;

function EvaluateSpf(var ACtx: TSpfEval; const ADomain: string;
  out AError: string): TSpfResult; forward;

function MatchInclude(var ACtx: TSpfEval; const ATarget: string;
  const ACurrentDomain: string): TMechResult;
var
  LExpanded: string;
  LResult: TSpfResult;
  LErr: string;
begin
  { 宏展开(RFC 7208 §5.2: domain-spec 先展开再递归) }
  if not ExpandMacros(ACtx, ACurrentDomain, ATarget, LExpanded) then
  begin
    Result := mrError;
    Exit;
  end;
  { 递归入口的预算检查/计数由 EvaluateSpf 完成(含目标域 TXT 查询) }
  LResult := EvaluateSpf(ACtx, LowerAscii(LExpanded), LErr);
  case LResult of
    srPass: Result := mrMatch;
    srTempError: Result := mrError;
    srPermError, srNone: Result := mrError;
  else
    Result := mrNoMatch;         { fail/softfail/neutral → no-match }
  end;
end;

function MatchExists(var ACtx: TSpfEval; const ATarget: string;
  const ACurrentDomain: string): TMechResult;
var
  LExpanded, LErr: string;
  LIps: TDeliverabilityStringArray;
  LOk: Boolean;
begin
  if not ExpandMacros(ACtx, ACurrentDomain, ATarget, LExpanded) then
  begin
    Result := mrError;           { INV-3: 宏展开失败 → permerror }
    Exit;
  end;
  { RFC 7208 §5.7: 对展开后的域做 A 查询, 任一记录即匹配 }
  LOk := QueryWithBudget(ACtx, qkA, LowerAscii(LExpanded), LIps, LErr);
  if not LOk then
  begin
    if IsNoRecordError(LErr) then
      Result := mrNoMatch
    else
      Result := mrError;
    Exit;
  end;
  Result := mrMatch;             { 任一 A 记录存在即匹配 }
end;

function MatchMechanism(var ACtx: TSpfEval; const AMech: string;
  const ACurrentDomain: string): TMechResult;
begin
  if AMech = 'all' then
    Result := mrMatch
  else if Pos('ip4:', AMech) = 1 then
    Result := MatchIpMechanism(ACtx, AMech, True)
  else if Pos('ip6:', AMech) = 1 then
    Result := MatchIpMechanism(ACtx, AMech, False)
  else if (AMech = 'a') or (Pos('a:', AMech) = 1) or (Pos('a/', AMech) = 1) then
    Result := MatchAMechanism(ACtx, AMech, ACurrentDomain)
  else if (AMech = 'mx') or (Pos('mx:', AMech) = 1) or (Pos('mx/', AMech) = 1) then
    Result := MatchMXMechanism(ACtx, AMech, ACurrentDomain)
  else if Pos('include:', AMech) = 1 then
    Result := MatchInclude(ACtx, Copy(AMech, Length('include:') + 1, MaxInt),
      ACurrentDomain)
  else if Pos('exists:', AMech) = 1 then
    Result := MatchExists(ACtx, Copy(AMech, Length('exists:') + 1, MaxInt),
      ACurrentDomain)
  else if AMech = 'ptr' then
    Result := mrNoMatch           { 契约 §1: ptr 视为 no-match }
  else
    Result := mrError;            { 未知机制 → permerror(INV-3) }
end;

function QualifierToResult(const AQ: Char): TSpfResult;
begin
  case AQ of
    '-': Result := srFail;
    '~': Result := srSoftFail;
    '?': Result := srNeutral;
  else
    Result := srPass;
  end;
end;

{ ── 记录分段与语法校验(RFC 7208 §4.6) ─────────────────────── }

{ 'v=spf1' 之后的 term 段(1*SP 分隔) }
function SplitRecordTerms(const ARecord: string): TDeliverabilityStringArray;
var
  LPos: Integer;
  LPart: string;
begin
  Result := nil;
  LPos := 7;
  while LPos <= Length(ARecord) + 1 do
  begin
    while (LPos <= Length(ARecord)) and (ARecord[LPos] <= ' ') do
      Inc(LPos);
    if LPos > Length(ARecord) then
      Break;
    LPart := '';
    while (LPos <= Length(ARecord)) and (ARecord[LPos] > ' ') do
    begin
      LPart := LPart + ARecord[LPos];
      Inc(LPos);
    end;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LPart;
  end;
end;

{ 剥 qualifier; 返回机制/修饰符文本与 qualifier }
function StripQualifier(const APart: string; out AMech: string;
  out AQualifier: Char): Boolean;
begin
  AMech := APart;
  AQualifier := '+';
  if AMech = '' then
  begin
    Result := False;
    Exit;
  end;
  if (AMech[1] = '+') or (AMech[1] = '-') or (AMech[1] = '~') or
    (AMech[1] = '?') then
  begin
    AQualifier := AMech[1];
    Delete(AMech, 1, 1);
  end;
  Result := AMech <> '';
end;

{ 全量语法预校验(§4.6: 任何语法错误 → permerror, 即使前面已匹配) }
function ValidateRecordSyntax(const ARecord: string): Boolean;
var
  LTerns: TDeliverabilityStringArray;
  LI: Integer;
  LMech, LNet: string;
  LQ: Char;
  LErrFlag: Boolean;
  LDummy: string;
  LC4, LC6, LSlash, LCidr, LCode: Integer;
  LV4: TBytes;
  LV6: TBytes;
begin
  Result := False;
  LTerns := SplitRecordTerms(ARecord);
  for LI := 0 to High(LTerns) do
  begin
    if not StripQualifier(LTerns[LI], LMech, LQ) then
      Exit;                      { 纯 qualifier / 空段 }
    { 修饰符: name "=" macro-string(任意名, 含 redirect=/exp=) }
    if Pos('=', LMech) > 0 then
      Continue;
    if LMech = 'all' then
      Break                      { §5.1: all 之后的机制忽略(不校验) }
    else if Pos('ip4:', LMech) = 1 then
    begin
      LNet := Copy(LMech, 5, MaxInt);
      LCidr := -1;
      LSlash := Pos('/', LNet);
      if LSlash > 0 then
      begin
        Val(Copy(LNet, LSlash + 1, MaxInt), LCidr, LCode);
        if (LCode <> 0) or (LCidr < 0) or (LCidr > 32) then
          Exit;
        LNet := Copy(LNet, 1, LSlash - 1);
      end;
      if not TryParseIPv4(LNet, LV4) then
        Exit;
    end
    else if Pos('ip6:', LMech) = 1 then
    begin
      LNet := Copy(LMech, 5, MaxInt);
      LCidr := -1;
      LSlash := Pos('/', LNet);
      if LSlash > 0 then
      begin
        Val(Copy(LNet, LSlash + 1, MaxInt), LCidr, LCode);
        if (LCode <> 0) or (LCidr < 0) or (LCidr > 128) then
          Exit;
        LNet := Copy(LNet, 1, LSlash - 1);
      end;
      if not TryParseIPv6(LNet, LV6) then
        Exit;
    end
    else if (LMech = 'a') or (Pos('a:', LMech) = 1) or (Pos('a/', LMech) = 1)
      or (LMech = 'mx') or (Pos('mx:', LMech) = 1) or
      (Pos('mx/', LMech) = 1) then
    begin
      ParseDomainCidr(LMech, 'x', LDummy, LC4, LC6, LErrFlag);
      if LErrFlag then
        Exit;
    end
    else if Pos('include:', LMech) = 1 then
    begin
      if Copy(LMech, Length('include:') + 1, MaxInt) = '' then
        Exit;
    end
    else if Pos('exists:', LMech) = 1 then
    begin
      if Copy(LMech, Length('exists:') + 1, MaxInt) = '' then
        Exit;
    end
    else if (LMech = 'ptr') or (Pos('ptr:', LMech) = 1) then
      Continue
    else
      Exit;                      { 未知机制 }
  end;
  Result := True;
end;

function EvaluateSpf(var ACtx: TSpfEval; const ADomain: string;
  out AError: string): TSpfResult;
var
  LTexts: TDeliverabilityStringArray;
  LErr: string;
  LRecordText, LPart, LRedirect: string;
  LQualifier: Char;
  LParts: TDeliverabilityStringArray;
  LI: Integer;
  LOk: Boolean;
  LMech: TMechResult;
  LFound: Integer;
  LHasRedirect, LHasAll: Boolean;
  LExpanded: string;
begin
  Result := srNeutral;
  AError := '';
  if ADomain = '' then
  begin
    AError := 'empty domain';
    Result := srPermError;
    Exit;
  end;
  if ACtx.Lookups >= SPF_MAX_LOOKUPS then
  begin
    AError := 'too many DNS lookups';
    Result := srPermError;
    Exit;
  end;
  Inc(ACtx.Lookups);

  LOk := ACtx.Dns.QueryTXT(LowerAscii(ADomain), ACtx.TimeoutMs, LTexts, LErr);
  if not LOk then
  begin
    if IsNoRecordError(LErr) then
      Result := srNone
    else
      Result := srTempError;
    AError := LErr;
    Exit;
  end;

  { 找 v=spf1 记录(INV-2); §4.5: 多条 → permerror }
  LRecordText := '';
  LFound := 0;
  for LI := 0 to High(LTexts) do
    if (Pos('v=spf1', LTexts[LI]) = 1) and
      ((Length(LTexts[LI]) = 6) or (LTexts[LI][7] = ' ')) then
    begin
      Inc(LFound);
      LRecordText := LTexts[LI];
    end;
  if LFound = 0 then
  begin
    Result := srNone;
    Exit;
  end;
  if LFound > 1 then
  begin
    AError := 'multiple spf records';
    Result := srPermError;
    Exit;
  end;

  { §4.6: 语法全量预校验 }
  if not ValidateRecordSyntax(LRecordText) then
  begin
    AError := 'syntax error in spf record';
    Result := srPermError;
    Exit;
  end;

  { 逐机制; redirect 仅记录(§4.7: 机制全部不匹配后才处理) }
  LParts := SplitRecordTerms(LRecordText);
  LRedirect := '';
  LHasRedirect := False;
  LHasAll := False;
  for LI := 0 to High(LParts) do
  begin
    if not StripQualifier(LParts[LI], LPart, LQualifier) then
      Continue;
    if Pos('redirect=', LPart) = 1 then
    begin
      LRedirect := Copy(LPart, Length('redirect=') + 1, MaxInt);
      LHasRedirect := True;
      Continue;
    end;
    if Pos('=', LPart) > 0 then
      Continue;                  { 其它修饰符(exp= 等)忽略 }
    if LPart = 'all' then
      LHasAll := True;
    LMech := MatchMechanism(ACtx, LPart, ADomain);
    case LMech of
      mrMatch:
        begin
          Result := QualifierToResult(LQualifier);
          Exit;
        end;
      mrError:
        begin
          AError := 'mechanism error: ' + LPart;
          Result := srPermError;
          Exit;
        end;
    else
      { mrNoMatch: 继续下一机制 }
    end;
  end;

  { 无机制匹配: redirect(§6.1 宏展开; 目标无记录 → permerror; 有 all → 忽略) }
  if LHasRedirect and (not LHasAll) then
  begin
    if not ExpandMacros(ACtx, ADomain, LRedirect, LExpanded) then
    begin
      AError := 'redirect macro expansion failed';
      Result := srPermError;
      Exit;
    end;
    Result := EvaluateSpf(ACtx, LowerAscii(LExpanded), AError);
    if Result = srNone then
      Result := srPermError;
    Exit;
  end;

  { §4.7: 无匹配且无 redirect → 隐含 '?all' }
  Result := srNeutral;
end;

function SpfCheck(const ADns: IDeliverabilityDns; const ADomain: string;
  const AClientIP: string; const ASender: string; const ATimeoutMs: Int32;
  out AError: string): TSpfResult;
var
  LCtx: TSpfEval;
begin
  AError := '';
  LCtx.Dns := ADns;
  LCtx.ClientIP := TrimAscii(AClientIP);
  LCtx.Sender := ASender;
  LCtx.TimeoutMs := ATimeoutMs;
  LCtx.Lookups := 0;
  LCtx.VoidLookups := 0;
  { INV-12: 空/非法客户端 IP → permerror }
  if not PrepareClientIP(LCtx) then
  begin
    AError := 'invalid client ip';
    Result := srPermError;
    Exit;
  end;
  Result := EvaluateSpf(LCtx, LowerAscii(TrimAscii(ADomain)), AError);
end;

end.