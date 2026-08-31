unit nextpas.core.deliverability.base;
{**
 * @desc 投递性校验公共类型: SPF/DKIM/DMARC 结果枚举、对齐、DNS 查询
 *       接口与组织域启发式。契约 docs/deliverability/CONTRACT.md §2。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  TDeliverabilityStringArray = array of string;

  TSpfResult = (srPass, srFail, srSoftFail, srNeutral, srNone,
    srTempError, srPermError);

  TDkimResult = (dkPass, dkFail, dkNeutral, dkTempError, dkPermError);

  TDmarcPolicy = (dmpNone, dmpQuarantine, dmpReject);

  TDmarcResult = (dmPass, dmFail, dmNone, dmTempError);

  TAlignMode = (amRelaxed, amStrict);

  TDkimAlgo = (daRsaSha256, daEd25519Sha256);

  TCanonMode = (cmSimple, cmRelaxed);

  TDkimSignature = record
    Algo: TDkimAlgo;
    Domain: string;
    Selector: string;
    SignedHeaders: TDeliverabilityStringArray;  { h= 小写, 原序 }
    CanonHeader: TCanonMode;
    CanonBody: TCanonMode;
    Signature: TBytes;                          { b= base64 解码 }
    BodyHash: TBytes;                           { bh= base64 解码 }
  end;

  TDmarcRecord = record
    Policy: TDmarcPolicy;                       { p= }
    SubdomainPolicy: TDmarcPolicy;              { sp=; 缺省 = p }
    SPFAlign: TAlignMode;                       { aspf=; 缺省 relaxed }
    DKIMAlign: TAlignMode;                      { adkim=; 缺省 relaxed }
    Pct: Byte;                                  { pct=; 缺省 100 }
    RUA: string;                                { rua= 原始值 }
    RUF: string;                                { ruf= 原始值 }
  end;

  { DNS 查询注入点(纯算法不触网); 生产用 NewDeliverabilityDns(IDnsResolver) 桥接 }
  IDeliverabilityDns = interface
    ['{6F1D6F1D-4D7C-4E31-9100-4100000000D5}']
    function QueryTXT(const AName: string; const ATimeoutMs: Int32;
      out ATexts: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryA(const AName: string; const ATimeoutMs: Int32;
      out AIps: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryMX(const AName: string; const ATimeoutMs: Int32;
      out AHosts: TDeliverabilityStringArray; out AError: string): Boolean;
  end;

  TDeliverabilityVerdict = record
    SPF: TSpfResult;
    SpfError: string;
    DKIM: TDkimResult;
    DkimError: string;
    DKIMSigningDomain: string;
    DMARC: TDmarcResult;
    DmarcError: string;
  end;

{ 组织域启发式: 末两 label; 不足两 label 返回原串(非 PSL, 见契约 §1) }
function OrganisationalDomain(const ADomain: string): string;

{ 结果字符串化(调试/AError 复用) }
function SpfResultToString(const AResult: TSpfResult): string;
function DkimResultToString(const AResult: TDkimResult): string;
function DmarcResultToString(const AResult: TDmarcResult): string;

implementation

function LowerAscii(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Inc(Result[I], 32);
end;

function OrganisationalDomain(const ADomain: string): string;
var
  LDots: Integer;
  LLast, LSecond: Integer;
  I: Integer;
begin
  Result := LowerAscii(ADomain);
  { 找最后两个 label 起点 }
  LDots := 0;
  LSecond := 1;
  LLast := 1;
  for I := Length(Result) downto 1 do
    if Result[I] = '.' then
    begin
      Inc(LDots);
      if LDots = 1 then
        LLast := I + 1
      else
      begin
        LSecond := I + 1;
        Break;
      end;
    end;
  if LDots >= 2 then
    Result := Copy(Result, LSecond, Length(Result) - LSecond + 1);
end;

function SpfResultToString(const AResult: TSpfResult): string;
begin
  case AResult of
    srPass: Result := 'pass';
    srFail: Result := 'fail';
    srSoftFail: Result := 'softfail';
    srNeutral: Result := 'neutral';
    srNone: Result := 'none';
    srTempError: Result := 'temperror';
    srPermError: Result := 'permerror';
  end;
end;

function DkimResultToString(const AResult: TDkimResult): string;
begin
  case AResult of
    dkPass: Result := 'pass';
    dkFail: Result := 'fail';
    dkNeutral: Result := 'neutral';
    dkTempError: Result := 'temperror';
    dkPermError: Result := 'permerror';
  end;
end;

function DmarcResultToString(const AResult: TDmarcResult): string;
begin
  case AResult of
    dmPass: Result := 'pass';
    dmFail: Result := 'fail';
    dmNone: Result := 'none';
    dmTempError: Result := 'temperror';
  end;
end;

end.
