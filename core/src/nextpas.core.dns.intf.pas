unit nextpas.core.dns.intf;
{**
 * @desc DNS 查询接口(契约 docs/dns/CONTRACT.md §2)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.dns.base;

type
  TDnsRecordArray = array of TDnsRecord;
  TDnsStringArray = array of string;

  IDnsResolver = interface
    ['{6F1D6F1D-4D7C-4E31-9100-4100000000D1}']
    { 查询指定类型; 成功 True 且 Records 为该类型记录(缓存可命中) }
    function Query(const AName: string; const AKind: TDnsQueryKind;
      const ATimeoutMs: Int32; out ARecords: TDnsRecordArray;
      out AError: string): Boolean;
    { 便捷: TXT 拼接串列表(每记录一字符串) }
    function QueryTXT(const AName: string; const ATimeoutMs: Int32;
      out ATexts: TDnsStringArray; out AError: string): Boolean;
    { 便捷: MX exchange 按 preference 升序 }
    function QueryMX(const AName: string; const ATimeoutMs: Int32;
      out AHosts: TDnsStringArray; out AError: string): Boolean;
  end;

implementation

end.