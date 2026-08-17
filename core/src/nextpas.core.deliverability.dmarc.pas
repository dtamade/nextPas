unit nextpas.core.deliverability.dmarc;
{**
 * @desc DMARC(RFC 7489): 记录解析(p/sp/aspf/adkim/pct/rua/ruf)、精确域→
 *       组织域回退、SPF/DKIM 对齐判定、策略结果(INV-9~12, 契约 §3/§4)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.deliverability.base;

{ 解析 DMARC TXT 记录; v=DMARC1/p= 必须, 语法错误 → False(RFC 7489 §6.6.3) }
function DmarcParseRecord(const ARecord: string; out ADmarc: TDmarcRecord;
  out AError: string): Boolean;

{ 校验: 查 _dmarc.<from> 与组织域; 对齐判定 → dmPass/dmFail/dmNone/dmTempError }
function DmarcCheck(const ADns: IDeliverabilityDns; const AFromDomain: string;
  const ASpfResult: TSpfResult; const AEnvelopeSenderDomain: string;
  const ADkimResult: TDkimResult; const ADkimSigningDomain: string;
  const ATimeoutMs: Int32; out AError: string): TDmarcResult;

implementation

function IsNoRecordError(const AErr: string): Boolean;
begin
  Result := (Pos('nxdomain', AErr) > 0) or (Pos('no record', AErr) > 0)
    or (Pos('none', AErr) > 0);
end;

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

function DomainWithoutSender(const AIdentity: string): string;
var
  LAt: Integer;
begin
  LAt := Pos('@', AIdentity);
  if LAt > 0 then
    Result := Copy(AIdentity, LAt + 1, MaxInt)
  else
    Result := AIdentity;
end;

function DmarcParseRecord(const ARecord: string; out ADmarc: TDmarcRecord;
  out AError: string): Boolean;
var
  LPart, LKey, LVal: string;
  LI, LEq, LCode: Integer;
  LPolicy: TDmarcPolicy;
  LHasP: Boolean;
  LSpSet: Boolean;
begin
  Result := False;
  AError := '';
  ADmarc.SPFAlign := amRelaxed;
  ADmarc.DKIMAlign := amRelaxed;
  ADmarc.Pct := 100;
  ADmarc.RUA := '';
  ADmarc.RUF := '';
  LHasP := False;
  { 找 v=DMARC1(INV-9) }
  if Pos('v=dmarc1', LowerAscii(ARecord)) <> 1 then
  begin
    AError := 'missing v=DMARC1';
    Exit;
  end;

  { 分段解析 }
  LI := 1;
  while LI <= Length(ARecord) do
  begin
    LPart := '';
    while (LI <= Length(ARecord)) and (ARecord[LI] <> ';') do
    begin
      LPart := LPart + ARecord[LI];
      Inc(LI);
    end;
    LPart := TrimAscii(LPart);
    LEq := Pos('=', LPart);
    if LEq > 0 then
    begin
      LKey := LowerAscii(TrimAscii(Copy(LPart, 1, LEq - 1)));
      LVal := TrimAscii(Copy(LPart, LEq + 1, MaxInt));
      case LKey of
        'v':
          if LVal <> 'DMARC1' then
          begin
            AError := 'unsupported DMARC version';
            Exit;
          end;
        'p':
          if LVal = 'none' then
          begin
            LPolicy := dmpNone;
            LHasP := True;
          end
          else if LVal = 'quarantine' then
          begin
            LPolicy := dmpQuarantine;
            LHasP := True;
          end
          else if LVal = 'reject' then
          begin
            LPolicy := dmpReject;
            LHasP := True;
          end
          else
          begin
            AError := 'invalid p= policy: ' + LVal;
            Exit;
          end;
        'sp':
          if LVal = 'none' then
          begin
            ADmarc.SubdomainPolicy := dmpNone;
            LSpSet := True;
          end
          else if LVal = 'quarantine' then
          begin
            ADmarc.SubdomainPolicy := dmpQuarantine;
            LSpSet := True;
          end
          else if LVal = 'reject' then
          begin
            ADmarc.SubdomainPolicy := dmpReject;
            LSpSet := True;
          end;
          { 其它值忽略 → 缺省 p }
        'aspf':
          if LVal = 's' then
            ADmarc.SPFAlign := amStrict
          else
            ADmarc.SPFAlign := amRelaxed;   { 未知 → relaxed }
        'adkim':
          if LVal = 's' then
            ADmarc.DKIMAlign := amStrict
          else
            ADmarc.DKIMAlign := amRelaxed;
        'pct':
          begin
            LCode := 0;
            Val(LVal, ADmarc.Pct, LCode);
            if (LCode <> 0) or (ADmarc.Pct > 100) then
              ADmarc.Pct := 100;            { 非法 → 缺省 100 }
          end;
        'rua': ADmarc.RUA := LVal;
        'ruf': ADmarc.RUF := LVal;
      end;
    end;
    if LI <= Length(ARecord) then
      Inc(LI);
  end;

  if not LHasP then
  begin
    AError := 'missing p= tag';
    Exit;
  end;
  ADmarc.Policy := LPolicy;
  { sp= 未显式给出时跟随 p=(RFC 7489 §6.3) }
  if not LSpSet then
    ADmarc.SubdomainPolicy := LPolicy;
  Result := True;
end;

function DmarcCheck(const ADns: IDeliverabilityDns; const AFromDomain: string;
  const ASpfResult: TSpfResult; const AEnvelopeSenderDomain: string;
  const ADkimResult: TDkimResult; const ADkimSigningDomain: string;
  const ATimeoutMs: Int32; out AError: string): TDmarcResult;
var
  LFrom: string;
  LNames: TDeliverabilityStringArray;
  LErr: string;
  LOk: Boolean;
  LRecord: TDmarcRecord;
  LRecordText: string;
  LOrg: string;
  LFound: Boolean;
  LSpfAlign, LDkimAlign: Boolean;
  LEnvDomain: string;
  LCheckDomain: string;
  LTry, LI: Integer;
begin
  Result := dmNone;
  AError := '';
  LFrom := LowerAscii(TrimAscii(AFromDomain));
  if LFrom = '' then
    Exit;                        { INV-12: 空 From 域 → none }

  { 精确域 → 组织域两级回退(INV-11) }
  LFound := False;
  LTry := 0;
  LCheckDomain := LFrom;
  while LTry < 2 do
  begin
    LOk := ADns.QueryTXT('_dmarc.' + LCheckDomain, ATimeoutMs, LNames, LErr);
    if not LOk then
    begin
      if not IsNoRecordError(LErr) then
      begin
        AError := LErr;
        Result := dmTempError;
        Exit;
      end;
    end
    else
    begin
      { 找 v=DMARC1 记录; RFC 7489 §6.6.3: 多条 → 终止发现(不应用) }
      LFound := False;
      for LI := 0 to High(LNames) do
        if Pos('v=dmarc1', LowerAscii(LNames[LI])) = 1 then
        begin
          if LFound then
          begin
            Result := dmNone;
            Exit;
          end;
          LFound := True;
          LRecordText := LNames[LI];
        end;
      if LFound then
      begin
        if not DmarcParseRecord(LRecordText, LRecord, LErr) then
        begin
          AError := LErr;
          Result := dmNone;      { INV-9: 无效记录视同未发布 }
          Exit;
        end;
        Break;
      end;
    end;
    { 回退组织域 }
    LOrg := OrganisationalDomain(LCheckDomain);
    if LOrg = LCheckDomain then
      Break;
    LCheckDomain := LOrg;
    Inc(LTry);
  end;
  if not LFound then
  begin
    Result := dmNone;            { 两级均无记录 }
    Exit;
  end;

  { 对齐判定(INV-10) }
  LEnvDomain := LowerAscii(DomainWithoutSender(AEnvelopeSenderDomain));
  LSpfAlign := (ASpfResult = srPass);
  if LSpfAlign then
  begin
    if LRecord.SPFAlign = amStrict then
      LSpfAlign := LFrom = LEnvDomain
    else
      LSpfAlign := OrganisationalDomain(LFrom) =
        OrganisationalDomain(LEnvDomain);
  end;

  LDkimAlign := (ADkimResult = dkPass);
  if LDkimAlign then
  begin
    { 缺签名域 → 不对齐 }
    if ADkimSigningDomain = '' then
      LDkimAlign := False
    else if LRecord.DKIMAlign = amStrict then
      LDkimAlign := LFrom = LowerAscii(ADkimSigningDomain)
    else
      LDkimAlign := OrganisationalDomain(LFrom) =
        OrganisationalDomain(LowerAscii(ADkimSigningDomain));
  end;

  if LSpfAlign or LDkimAlign then
    Result := dmPass
  else
    Result := dmFail;            { 策略在 Verdict.Policy 字段(由调用方执行) }
end;

end.