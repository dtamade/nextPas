unit nextpas.core.deliverability;
{**
 * @desc 投递性校验门面: SPF/DKIM/DMARC 编排(CheckDeliverability)与
 *       批次 4 DNS 适配器(NewDeliverabilityDns)。契约 docs/deliverability/CONTRACT.md。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.deliverability.base,
  nextpas.core.dns.base,
  nextpas.core.dns.intf;

{ 桥接批次 4 IDnsResolver(QueryA 为 A+AAAA 合并) }
function NewDeliverabilityDns(const ADns: IDnsResolver): IDeliverabilityDns;

{ 全链校验: SPF(信封域)+ DKIM(正文/头签名)+ DMARC(From 域, 对齐判定) }
function CheckDeliverability(const ADns: IDeliverabilityDns;
  const ARawMail: string; const AFromDomain, AEnvelopeSenderDomain,
  AClientIP: string; const ATimeoutMs: Int32): TDeliverabilityVerdict;

implementation

uses
  nextpas.core.base,
  nextpas.core.deliverability.dkim,
  nextpas.core.deliverability.dmarc,
  nextpas.core.deliverability.spf,
  nextpas.core.text.builder;

type
  TDeliverabilityDnsAdapter = class(TInterfacedObject, IDeliverabilityDns)
  private
    FDns: IDnsResolver;
  public
    constructor Create(const ADns: IDnsResolver);
    function QueryTXT(const AName: string; const ATimeoutMs: Int32;
      out ATexts: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryA(const AName: string; const ATimeoutMs: Int32;
      out AIps: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryMX(const AName: string; const ATimeoutMs: Int32;
      out AHosts: TDeliverabilityStringArray; out AError: string): Boolean;
  end;

{ 网络字节序 UInt32 → 点分文本 }
function IPv4ToText(const A: UInt32): string; inline;
var
  B: TBufStringBuilder;
begin
  { perf: 单次分配 via TBufStringBuilder(text.builder L1 owner)复用 bytes.ops.BytesGrowCapacity 几何(BYTES_BUILDER_MIN_GROW 0→64→2×)均摊 O(1)零拷贝 BytesCopy 单次 Move 单源；预分配15(4*3+3 dot)单次 GetMem/SetString 无 O(n²) Result+逐次重分配拷贝；inline AppendUInt/AppendChar 单寄存器；稳定性 try/finally B.Done 配对释放不丢 }
  B.Init(15);
  try
    B.AppendUInt((A shr 24) and $FF);
    B.AppendChar('.');
    B.AppendUInt((A shr 16) and $FF);
    B.AppendChar('.');
    B.AppendUInt((A shr 8) and $FF);
    B.AppendChar('.');
    B.AppendUInt(A and $FF);
    Result := B.ToString;
  finally
    B.Done;
  end;
end;

function ExtractDomain(const AIdentity: string): string;
var
  LAt: Integer;
begin
  LAt := Pos('@', AIdentity);
  if LAt > 0 then
    Result := Copy(AIdentity, LAt + 1, MaxInt)
  else
    Result := AIdentity;
end;

{ ── 适配器 ───────────────────────────────────────────────────── }

constructor TDeliverabilityDnsAdapter.Create(const ADns: IDnsResolver);
begin
  inherited Create;
  FDns := ADns;
end;

function TDeliverabilityDnsAdapter.QueryTXT(const AName: string;
  const ATimeoutMs: Int32; out ATexts: TDeliverabilityStringArray;
  out AError: string): Boolean;
begin
  Result := FDns.QueryTXT(AName, ATimeoutMs, ATexts, AError);
end;

function TDeliverabilityDnsAdapter.QueryA(const AName: string;
  const ATimeoutMs: Int32; out AIps: TDeliverabilityStringArray;
  out AError: string): Boolean;
var
  LRecords: TDnsRecordArray;
  LI: Integer;
  LOldLen: Integer;
begin
  AIps := nil;
  Result := FDns.Query(AName, dqA, ATimeoutMs, LRecords, AError);
  if not Result then
    Exit;
  { perf: 单次 SetLength 预分配 vs 逐一 Length+1 O(n²) 拷贝; 已知批量大小精确分配(零拷贝 string 赋值), 等价 bytes.ops 指数/BytesConcatMany 单源思想; inline IPv4ToText 纯寄存器 }
  SetLength(AIps, Length(LRecords));
  for LI := 0 to High(LRecords) do
    AIps[LI] := IPv4ToText(LRecords[LI].A);
  { AAAA 合并(双栈) — 单次扩容追加 }
  if FDns.Query(AName, dqAAAA, ATimeoutMs, LRecords, AError) then
  begin
    LOldLen := Length(AIps);
    SetLength(AIps, LOldLen + Length(LRecords));
    for LI := 0 to High(LRecords) do
      AIps[LOldLen + LI] := LRecords[LI].AAAA;
  end;
  Result := Length(AIps) > 0;
  if not Result then
    AError := 'no records';
end;

function TDeliverabilityDnsAdapter.QueryMX(const AName: string;
  const ATimeoutMs: Int32; out AHosts: TDeliverabilityStringArray;
  out AError: string): Boolean;
begin
  Result := FDns.QueryMX(AName, ATimeoutMs, AHosts, AError);
end;

function NewDeliverabilityDns(const ADns: IDnsResolver): IDeliverabilityDns;
begin
  Result := TDeliverabilityDnsAdapter.Create(ADns);
end;

{ ── 编排 ─────────────────────────────────────────────────────── }

function CheckDeliverability(const ADns: IDeliverabilityDns;
  const ARawMail: string; const AFromDomain, AEnvelopeSenderDomain,
  AClientIP: string; const ATimeoutMs: Int32): TDeliverabilityVerdict;
var
  LEnvDomain: string;
  LSigValue: string;
  LSig: TDkimSignature;
  LErr: string;
begin
  Result.SpfError := '';
  Result.DkimError := '';
  Result.DmarcError := '';
  Result.DKIMSigningDomain := '';
  LEnvDomain := ExtractDomain(AEnvelopeSenderDomain);

  { SPF: 对信封发件人域评估(拼接完整信封地址给宏) }
  Result.SPF := SpfCheck(ADns, LEnvDomain, AClientIP, AEnvelopeSenderDomain,
    ATimeoutMs, Result.SpfError);

  { DKIM }
  Result.DKIM := DkimVerify(ADns, ARawMail, ATimeoutMs, Result.DkimError);
  if Result.DKIM = dkPass then
  begin
    if DkimExtractSignatureValue(ARawMail, LSigValue) and
      DkimParseSignature(LSigValue, LSig, LErr) then
      Result.DKIMSigningDomain := LSig.Domain;
  end;

  { DMARC }
  Result.DMARC := DmarcCheck(ADns, AFromDomain, Result.SPF, LEnvDomain,
    Result.DKIM, Result.DKIMSigningDomain, ATimeoutMs, Result.DmarcError);
end;

end.