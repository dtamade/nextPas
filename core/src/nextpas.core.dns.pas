unit nextpas.core.dns;
{**
 * @desc DNS 查询门面与同步 UDP 实现。
 *       TXT/MX/NS/SOA/A/AAAA 查询、resolv.conf nameserver、TTL 缓存。
 *       契约 docs/dns/CONTRACT.md(INV-3/4/5/6/7/10)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.dns.base,
  nextpas.core.dns.intf;

{ 查询器工厂: ANameserver 空 → 读 /etc/resolv.conf; ACacheSize<=0 禁用缓存;
  APort 默认 53(测试可指定高位端口) }
function DnsResolver(const ANameserver: string = '';
  const ACacheSize: Integer = 256;
  const APort: UInt16 = 53): IDnsResolver;

implementation

uses
  nextpas.core.base,
  nextpas.core.collections.lrucache,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.udp,
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

const
  DNS_PORT = 53;
  DNS_UDP_BUFFER = 2048;
  DNS_MIN_CACHE_TTL_SECONDS = 60;
  DNS_RESOLV_CONF = '/etc/resolv.conf';

type
  TDnsCacheEntry = record
    ExpiresAt: TInstant;
    Records: TDnsRecordArray;
  end;

  TDnsResolverImpl = class(TInterfacedObject, IDnsResolver)
  private
    FNameservers: TDnsStringArray;
    FCache: specialize TLruCache<string, TDnsCacheEntry>;
    FQueryID: UInt16;
    FPort: UInt16;
  public
    constructor Create(const ANameserver: string; const ACacheSize: Integer;
      const APort: UInt16);
    destructor Destroy; override;
    function Query(const AName: string; const AKind: TDnsQueryKind;
      const ATimeoutMs: Int32; out ARecords: TDnsRecordArray;
      out AError: string): Boolean;
    function QueryTXT(const AName: string; const ATimeoutMs: Int32;
      out ATexts: TDnsStringArray; out AError: string): Boolean;
    function QueryMX(const AName: string; const ATimeoutMs: Int32;
      out AHosts: TDnsStringArray; out AError: string): Boolean;
  private
    function NextQueryID: UInt16;
    function CacheKey(const AName: string; const AKind: TDnsQueryKind): string;
    function TryQueryOnce(const ANameserver: string; const AName: string;
      const AKind: TDnsQueryKind; const ATimeoutMs: Int32;
      out ARecords: TDnsRecordArray; out AError: string): Boolean;
    function CacheTtlSeconds(const ARecords: TDnsRecordArray): Int64;
  end;

{ ── 通用助手 ────────────────────────────────────────────────────── }

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

{ ── 实现 ────────────────────────────────────────────────────────── }

function DnsResolver(const ANameserver: string;
  const ACacheSize: Integer; const APort: UInt16): IDnsResolver;
begin
  Result := TDnsResolverImpl.Create(ANameserver, ACacheSize, APort);
end;

constructor TDnsResolverImpl.Create(const ANameserver: string;
  const ACacheSize: Integer; const APort: UInt16);
var
  LLine: string;
  LFile: Text;
  LS: string;
begin
  inherited Create;
  FQueryID := 0;
  FPort := APort;
  FNameservers := nil;
  LS := TrimAscii(ANameserver);
  if LS = '' then
  begin
    { 解析 resolv.conf(仅构造时一次, 非 hot path) }
    Assign(LFile, DNS_RESOLV_CONF);
    {$I-}
    Reset(LFile);
    {$I+}
    if IOResult = 0 then
    begin
      while not EOF(LFile) do
      begin
        ReadLn(LFile, LLine);
        LLine := TrimAscii(LLine);
        if Pos('nameserver ', LLine) = 1 then
        begin
          SetLength(FNameservers, Length(FNameservers) + 1);
          FNameservers[High(FNameservers)] := TrimAscii(
            Copy(LLine, Length('nameserver ') + 1, MaxInt));
        end;
      end;
      CloseFile(LFile);
    end;
  end
  else
  begin
    SetLength(FNameservers, 1);
    FNameservers[0] := LS;
  end;

  if ACacheSize > 0 then
    FCache := specialize TLruCache<string, TDnsCacheEntry>.Create(ACacheSize)
  else
    FCache := nil;
end;

destructor TDnsResolverImpl.Destroy;
begin
  FCache.Free;
  inherited Destroy;
end;

function TDnsResolverImpl.NextQueryID: UInt16;
begin
  Inc(FQueryID);
  Result := FQueryID;
end;

function TDnsResolverImpl.CacheKey(const AName: string;
  const AKind: TDnsQueryKind): string;
begin
  Result := LowerAscii(AName) + '|' + IntToStr(DnsQueryKindToWire(AKind));
end;

function TDnsResolverImpl.CacheTtlSeconds(
  const ARecords: TDnsRecordArray): Int64;
var
  LI: Integer;
  LMin: Int64;
begin
  LMin := DNS_MIN_CACHE_TTL_SECONDS;
  if Length(ARecords) > 0 then
    for LI := 0 to High(ARecords) do
      if ARecords[LI].TTL < LMin then
        LMin := ARecords[LI].TTL;
  if LMin < DNS_MIN_CACHE_TTL_SECONDS then
    LMin := DNS_MIN_CACHE_TTL_SECONDS;
  Result := LMin;
end;

function TDnsResolverImpl.TryQueryOnce(const ANameserver: string;
  const AName: string; const AKind: TDnsQueryKind; const ATimeoutMs: Int32;
  out ARecords: TDnsRecordArray; out AError: string): Boolean;
var
  LQuery, LBuffer, LRespBytes: TBytes;
  LID: UInt16;
  LAddr, LFrom: TNetAddress;
  LSock: IUdpSocket;
  LRuntime: IUdpSocketRuntime;
  LSockHandle: PtrUInt;
  LSockT: TPlatformSocket;
  LDeadline: TDeadline;
  LWait: Int64;
  LRevents: Int32;
  LN: SizeUInt;
  LResp: TDnsResponse;
  LI: Integer;
begin
  Result := False;
  AError := 'malformed';
  LID := NextQueryID;
  if not DnsEncodeQuery(AName, AKind, LID, LQuery) then
    Exit;
  LSock := NetUdpBind('127.0.0.1', 0);
  if LSock = nil then
  begin
    AError := 'bind failed';
    Exit;
  end;
  try
    LAddr := TNetAddress.IPv4(ANameserver, FPort);
    if LSock.SendTo(LQuery[0], Length(LQuery), LAddr) <> SizeUInt(Length(LQuery)) then
    begin
      AError := 'send failed';
      Exit;
    end;
    LRuntime := LSock as IUdpSocketRuntime;
    LSockHandle := LRuntime.NativeSocketHandle;
{$IFDEF NEXTPAS_WINDOWS}
    LSockT.Value := LSockHandle;
{$ELSE}
    LSockT.Value := Int32(LSockHandle);
{$ENDIF}
    LDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
    SetLength(LBuffer, DNS_UDP_BUFFER);
    ARecords := nil;
    while not LDeadline.IsExpired do
    begin
      LWait := LDeadline.Remaining.AsMilliseconds;
      if LWait < 1 then
        LWait := 1;
      LRevents := 0;
      case platform_socket_poll(LSockT, PLATFORM_POLL_IN, Int32(LWait),
        LRevents) of
        1:
          begin
            { 就绪: 收包; 半开端口由 poll 超时兜底 }
          end;
        0:
          begin
            AError := 'timed out';
            Exit;
          end;
      else
        AError := 'network error';
        Exit;
      end;
      LN := LSock.RecvFrom(LBuffer[0], Length(LBuffer), LFrom);
      if LN < 12 then
        Continue;
      SetLength(LRespBytes, LN);
      Move(LBuffer[0], LRespBytes[0], LN);
      if not DnsParseResponse(LRespBytes, LResp) then
        Continue;
      if LResp.ID <> LID then
        Continue;              { INV-3: 应答归属 }
      if LResp.Truncated then
      begin
        AError := 'truncated';
        Exit;
      end;
      case LResp.RCODE of
        0:
          begin
            for LI := 0 to High(LResp.Answers) do
              if LResp.Answers[LI].RType = TDnsRecordType(Ord(AKind)) then
              begin
                SetLength(ARecords, Length(ARecords) + 1);
                ARecords[High(ARecords)] := LResp.Answers[LI];
              end;
            Result := True;
            Exit;
          end;
        2: AError := 'servfail';
        3: AError := 'nxdomain';
        5: AError := 'refused';
      else
        AError := 'rcode=' + IntToStr(LResp.RCODE);
      end;
      Exit;
    end;
    AError := 'timed out';
  finally
    LSock.Close;
  end;
end;

function TDnsResolverImpl.Query(const AName: string;
  const AKind: TDnsQueryKind; const ATimeoutMs: Int32;
  out ARecords: TDnsRecordArray; out AError: string): Boolean;
var
  LKey: string;
  LEntry: TDnsCacheEntry;
  LDeadline: TDeadline;
  LWait: Int64;
  LLastError, LErr: string;
  LI: Integer;
begin
  Result := False;
  AError := 'no nameserver';
  ARecords := nil;
  if Length(FNameservers) = 0 then
    Exit;

  LKey := CacheKey(AName, AKind);
  if FCache <> nil then
  begin
    if FCache.Get(LKey, LEntry) and (LEntry.ExpiresAt > TInstant.Now) then
    begin
      ARecords := Copy(LEntry.Records);
      Result := True;
      Exit;
    end;
  end;

  LDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
  LLastError := 'timed out';
  for LI := 0 to High(FNameservers) do
  begin
    if LDeadline.IsExpired then
      Break;
    LWait := LDeadline.Remaining.AsMilliseconds;
    if LWait < 1 then
      LWait := 1;
    if TryQueryOnce(FNameservers[LI], AName, AKind, Int32(LWait),
      ARecords, LErr) then
    begin
      if FCache <> nil then
      begin
        LEntry.ExpiresAt := TInstant.Now.Add(
          TDuration.FromSeconds(CacheTtlSeconds(ARecords)));
        LEntry.Records := Copy(ARecords);
        FCache.Put(LKey, LEntry);
      end;
      Result := True;
      Exit;
    end;
    LLastError := LErr;
  end;
  AError := LLastError;
end;

function TDnsResolverImpl.QueryTXT(const AName: string;
  const ATimeoutMs: Int32; out ATexts: TDnsStringArray;
  out AError: string): Boolean;
var
  LRecords: TDnsRecordArray;
  LI: Integer;
begin
  Result := Query(AName, dqTXT, ATimeoutMs, LRecords, AError);
  ATexts := nil;
  if Result then
    for LI := 0 to High(LRecords) do
    begin
      SetLength(ATexts, Length(ATexts) + 1);
      ATexts[High(ATexts)] := LRecords[LI].TXT;
    end;
end;

function TDnsResolverImpl.QueryMX(const AName: string;
  const ATimeoutMs: Int32; out AHosts: TDnsStringArray;
  out AError: string): Boolean;
var
  LRecords: TDnsRecordArray;
  LI, LJ: Integer;
  LSwap: TDnsRecord;
begin
  Result := Query(AName, dqMX, ATimeoutMs, LRecords, AError);
  AHosts := nil;
  if Result then
  begin
    { INV-7: preference 升序(同 preference 保持 wire 序 —— 稳定排序) }
    for LI := 0 to High(LRecords) - 1 do
      for LJ := LI + 1 to High(LRecords) do
        if LRecords[LJ].MXPreference < LRecords[LI].MXPreference then
        begin
          LSwap := LRecords[LI];
          LRecords[LI] := LRecords[LJ];
          LRecords[LJ] := LSwap;
        end;
    for LI := 0 to High(LRecords) do
    begin
      SetLength(AHosts, Length(AHosts) + 1);
      AHosts[High(AHosts)] := LRecords[LI].MXExchange;
    end;
  end;
end;

end.