unit nextpas.core.tls.dns.ldns;

{**
 * nextpas.core.tls.dns.ldns - ldns 库动态绑定
 *
 * 提供对 ldns DNS 库的动态绑定，支持 DNS TLSA 查询和 DNSSEC 验证。
 * ldns 是一个可选依赖，如果不可用，相关功能将优雅降级。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-02-05
 *}

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.base,
  nextpas.core.text.conv;

const
  // ldns 库名
  {$IFDEF WINDOWS}
  LDNS_LIB_NAME_1 = 'ldns.dll';
  LDNS_LIB_NAME_2 = 'libldns.dll';
  LDNS_LIB_NAME_3 = '';
  {$ELSE}
  LDNS_LIB_NAME_1 = 'libldns.so.3';
  LDNS_LIB_NAME_2 = 'libldns.so.2';
  LDNS_LIB_NAME_3 = 'libldns.so';
  {$ENDIF}

  // ldns 常量
  LDNS_STATUS_OK = 0;

  // ldns RR 类型 (RFC 6698)
  LDNS_RR_TYPE_TLSA = 52;
  LDNS_RR_TYPE_A = 1;
  LDNS_RR_TYPE_AAAA = 28;
  LDNS_RR_TYPE_DNSKEY = 48;
  LDNS_RR_TYPE_DS = 43;
  LDNS_RR_TYPE_RRSIG = 46;
  LDNS_RR_TYPE_NSEC = 47;
  LDNS_RR_TYPE_NSEC3 = 50;

  // ldns RR 类
  LDNS_RR_CLASS_IN = 1;

  // ldns 数据包段
  LDNS_SECTION_QUESTION = 0;
  LDNS_SECTION_ANSWER = 1;
  LDNS_SECTION_AUTHORITY = 2;
  LDNS_SECTION_ADDITIONAL = 3;
  LDNS_SECTION_ANY = 4;
  LDNS_SECTION_ANY_NOQUESTION = 5;

  // ldns RDF 类型
  LDNS_RDF_TYPE_NONE = 0;
  LDNS_RDF_TYPE_DNAME = 1;
  LDNS_RDF_TYPE_INT8 = 2;
  LDNS_RDF_TYPE_INT16 = 3;
  LDNS_RDF_TYPE_INT32 = 4;

  // ldns 查询标志
  LDNS_RD = $0100;  // 递归期望
  LDNS_CD = $0010;  // 检查禁用
  LDNS_AD = $0020;  // 认证数据

type
  // ldns 不透明类型
  Pldns_resolver = Pointer;
  PPldns_resolver = ^Pldns_resolver;
  Pldns_rdf = Pointer;
  PPldns_rdf = ^Pldns_rdf;
  Pldns_rr = Pointer;
  PPldns_rr = ^Pldns_rr;
  Pldns_rr_list = Pointer;
  PPldns_rr_list = ^Pldns_rr_list;
  Pldns_pkt = Pointer;
  PPldns_pkt = ^Pldns_pkt;
  Pldns_buffer = Pointer;
  Pldns_zone = Pointer;
  Pldns_dnssec_trust_tree = Pointer;
  Pldns_dnssec_data_chain = Pointer;

  // ldns 状态类型
  ldns_status = Integer;
  ldns_rr_type = Word;
  ldns_rr_class = Word;
  ldns_pkt_section = Integer;
  ldns_rdf_type = Integer;

  // TLSA 记录解析结果
  TLdnsTLSARecord = record
    Usage: Byte;          // 证书使用 (0-3)
    Selector: Byte;       // 选择器 (0-1)
    MatchingType: Byte;   // 匹配类型 (0-2)
    CertData: TBytes;     // 证书数据或哈希
    TTL: Cardinal;        // 生存时间
  end;

  TLdnsTLSARecordArray = array of TLdnsTLSARecord;

  // DNSSEC 状态
  TDNSSECStatus = (
    dnssecUnknown,       // 未知状态
    dnssecSecure,        // DNSSEC 验证通过
    dnssecInsecure,      // 未签名（非安全）
    dnssecBogus,         // DNSSEC 验证失败
    dnssecIndeterminate  // 无法确定
  );

var
  // ========== ldns 函数指针 ==========

  // 解析器函数
  ldns_resolver_new: function: Pldns_resolver; cdecl;
  ldns_resolver_new_frm_file: function(res: PPldns_resolver; filename: PAnsiChar): ldns_status; cdecl;
  ldns_resolver_free: procedure(res: Pldns_resolver); cdecl;
  ldns_resolver_deep_free: procedure(res: Pldns_resolver); cdecl;
  ldns_resolver_query: function(res: Pldns_resolver; name: Pldns_rdf;
    rrtype: ldns_rr_type; rrclass: ldns_rr_class; flags: Word): Pldns_pkt; cdecl;
  ldns_resolver_set_dnssec: procedure(res: Pldns_resolver; b: Byte); cdecl;
  ldns_resolver_set_dnssec_cd: procedure(res: Pldns_resolver; b: Byte); cdecl;
  ldns_resolver_set_dnssec_anchors: procedure(res: Pldns_resolver; list: Pldns_rr_list); cdecl;
  ldns_resolver_dnssec: function(res: Pldns_resolver): Byte; cdecl;
  ldns_resolver_set_timeout: procedure(res: Pldns_resolver; timeout: Pointer); cdecl;
  ldns_resolver_set_retry: procedure(res: Pldns_resolver; retry: Byte); cdecl;
  ldns_resolver_nameserver_count: function(res: Pldns_resolver): Cardinal; cdecl;
  ldns_resolver_push_nameserver_rr: function(res: Pldns_resolver; rr: Pldns_rr): ldns_status; cdecl;
  ldns_resolver_push_nameserver: function(res: Pldns_resolver; rdf: Pldns_rdf): ldns_status; cdecl;

  // RDF (资源数据字段) 函数
  ldns_rdf_new_frm_str: function(rdftype: ldns_rdf_type; str: PAnsiChar): Pldns_rdf; cdecl;
  ldns_rdf_new_frm_data: function(rdftype: ldns_rdf_type; size: Cardinal; data: Pointer): Pldns_rdf; cdecl;
  ldns_rdf_free: procedure(rdf: Pldns_rdf); cdecl;
  ldns_rdf_deep_free: procedure(rdf: Pldns_rdf); cdecl;
  ldns_rdf_data: function(rdf: Pldns_rdf): PByte; cdecl;
  ldns_rdf_size: function(rdf: Pldns_rdf): Cardinal; cdecl;
  ldns_rdf_get_type: function(rdf: Pldns_rdf): ldns_rdf_type; cdecl;
  ldns_rdf2native_int8: function(rdf: Pldns_rdf): Byte; cdecl;
  ldns_rdf2native_int16: function(rdf: Pldns_rdf): Word; cdecl;
  ldns_dname_new_frm_str: function(str: PAnsiChar): Pldns_rdf; cdecl;

  // RR (资源记录) 函数
  ldns_rr_new: function: Pldns_rr; cdecl;
  ldns_rr_free: procedure(rr: Pldns_rr); cdecl;
  ldns_rr_get_type: function(rr: Pldns_rr): ldns_rr_type; cdecl;
  ldns_rr_get_class: function(rr: Pldns_rr): ldns_rr_class; cdecl;
  ldns_rr_ttl: function(rr: Pldns_rr): Cardinal; cdecl;
  ldns_rr_rd_count: function(rr: Pldns_rr): Cardinal; cdecl;
  ldns_rr_rdf: function(rr: Pldns_rr; nr: Cardinal): Pldns_rdf; cdecl;
  ldns_rr_owner: function(rr: Pldns_rr): Pldns_rdf; cdecl;

  // RR 列表函数
  ldns_rr_list_new: function: Pldns_rr_list; cdecl;
  ldns_rr_list_free: procedure(list: Pldns_rr_list); cdecl;
  ldns_rr_list_deep_free: procedure(list: Pldns_rr_list); cdecl;
  ldns_rr_list_rr_count: function(list: Pldns_rr_list): Cardinal; cdecl;
  ldns_rr_list_rr: function(list: Pldns_rr_list; nr: Cardinal): Pldns_rr; cdecl;
  ldns_rr_list_push_rr: function(list: Pldns_rr_list; rr: Pldns_rr): Byte; cdecl;
  ldns_rr_list_pop_rr: function(list: Pldns_rr_list): Pldns_rr; cdecl;

  // 数据包函数
  ldns_pkt_free: procedure(pkt: Pldns_pkt); cdecl;
  ldns_pkt_rr_list_by_type: function(pkt: Pldns_pkt; rrtype: ldns_rr_type;
    section: ldns_pkt_section): Pldns_rr_list; cdecl;
  ldns_pkt_ancount: function(pkt: Pldns_pkt): Word; cdecl;
  ldns_pkt_answer: function(pkt: Pldns_pkt): Pldns_rr_list; cdecl;
  ldns_pkt_ad: function(pkt: Pldns_pkt): Byte; cdecl;  // Authentic Data 标志
  ldns_pkt_get_rcode: function(pkt: Pldns_pkt): Byte; cdecl;
  ldns_pkt_tc: function(pkt: Pldns_pkt): Byte; cdecl;  // Truncated 标志

  // DNSSEC 函数
  ldns_dnssec_data_chain_new: function: Pldns_dnssec_data_chain; cdecl;
  ldns_dnssec_data_chain_free: procedure(chain: Pldns_dnssec_data_chain); cdecl;
  ldns_dnssec_data_chain_deep_free: procedure(chain: Pldns_dnssec_data_chain); cdecl;
  ldns_dnssec_build_data_chain: function(res: Pldns_resolver; flags: Word;
    rrset: Pldns_rr_list; pkt: Pldns_pkt; trust_anchor: Pldns_rr): Pldns_dnssec_data_chain; cdecl;
  ldns_dnssec_trust_tree_new: function: Pldns_dnssec_trust_tree; cdecl;
  ldns_dnssec_trust_tree_free: procedure(tree: Pldns_dnssec_trust_tree); cdecl;
  ldns_dnssec_derive_trust_tree: function(chain: Pldns_dnssec_data_chain;
    rr: Pldns_rr): Pldns_dnssec_trust_tree; cdecl;
  ldns_dnssec_trust_tree_contains_keys: function(tree: Pldns_dnssec_trust_tree;
    keys: Pldns_rr_list): ldns_status; cdecl;
  ldns_dnssec_verify_denial: function(rr: Pldns_rr; nsecs: Pldns_rr_list;
    rrsigs: Pldns_rr_list): ldns_status; cdecl;
  ldns_verify: function(rrset: Pldns_rr_list; rrsig: Pldns_rr;
    keys: Pldns_rr_list; good_keys: Pldns_rr_list): ldns_status; cdecl;
  ldns_verify_rrsig_keylist: function(rrset: Pldns_rr_list; rrsig: Pldns_rr;
    keys: Pldns_rr_list; good_keys: Pldns_rr_list): ldns_status; cdecl;

  // 错误函数
  ldns_get_errorstr_by_id: function(err: ldns_status): PAnsiChar; cdecl;

  // 转换函数
  ldns_rr2str: function(rr: Pldns_rr): PAnsiChar; cdecl;
  ldns_rdf2str: function(rdf: Pldns_rdf): PAnsiChar; cdecl;
  ldns_pkt2str: function(pkt: Pldns_pkt): PAnsiChar; cdecl;


{**
 * 加载 ldns 库
 * @return 如果加载成功返回 True，否则返回 False
 *}
function LoadLdns: Boolean;

{**
 * 检查 ldns 库是否已加载
 * @return 如果已加载返回 True
 *}
function IsLdnsLoaded: Boolean;

{**
 * 卸载 ldns 库
 *}
procedure UnloadLdns;

{**
 * 获取 ldns 加载错误信息
 * @return 错误信息字符串
 *}
function GetLdnsLoadError: string;

{**
 * 查询 DNS TLSA 记录
 * @param ADomain 域名
 * @param APort 端口号
 * @param AProtocol 协议 (tcp/udp)
 * @param ARecords 输出 TLSA 记录数组
 * @param ADNSSECStatus 输出 DNSSEC 状态
 * @return 查询成功返回 True
 *}
function QueryDNSTLSA(const ADomain: string; APort: Word;
  const AProtocol: string; out ARecords: TLdnsTLSARecordArray;
  out ADNSSECStatus: TDNSSECStatus): Boolean;

{**
 * 验证 DNSSEC 链
 * @param ADomain 域名
 * @param ARRType 记录类型
 * @return DNSSEC 验证状态
 *}
function VerifyDNSSECChain(const ADomain: string; ARRType: ldns_rr_type): TDNSSECStatus;

{**
 * 获取 DNSSEC 状态描述
 * @param AStatus DNSSEC 状态
 * @return 状态描述字符串
 *}
function DNSSECStatusToStr(AStatus: TDNSSECStatus): string;

implementation

var
  LdnsHandle: TPlatformLibrary;
  LdnsLoaded: Boolean = False;
  LdnsLoadError: string = '';

function LdnsHandleValid(const ALib: TPlatformLibrary): Boolean; inline;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := ALib.Handle <> 0;
  {$ELSE}
  Result := ALib.Handle <> nil;
  {$ENDIF}
end;

function LoadLdns: Boolean;

  function LoadFunc(const AName: string): Pointer;
  begin
    Result := nil;
    platform_dl_sym(LdnsHandle, PAnsiChar(AnsiString(AName)), Result);
  end;

var
  LLib: TPlatformLibrary;
begin
  // 如果已加载，直接返回
  if LdnsLoaded then
    Exit(True);

  LdnsLoadError := '';

  // 尝试加载 ldns 库
  if platform_dl_open(PAnsiChar(AnsiString(LDNS_LIB_NAME_1)), PLATFORM_DL_NOW, LLib) = 0 then
    LdnsHandle := LLib
  else if LDNS_LIB_NAME_2 <> '' then
  begin
    if platform_dl_open(PAnsiChar(AnsiString(LDNS_LIB_NAME_2)), PLATFORM_DL_NOW, LLib) = 0 then
      LdnsHandle := LLib;
  end;
  if not LdnsHandleValid(LdnsHandle) then
  begin
    if LDNS_LIB_NAME_3 <> '' then
    begin
      if platform_dl_open(PAnsiChar(AnsiString(LDNS_LIB_NAME_3)), PLATFORM_DL_NOW, LLib) = 0 then
        LdnsHandle := LLib;
    end;
  end;

  if not LdnsHandleValid(LdnsHandle) then
  begin
    LdnsLoadError := '无法加载 ldns 库: ' + LDNS_LIB_NAME_1;
    Exit(False);
  end;

  // 加载解析器函数
  Pointer(ldns_resolver_new) := LoadFunc('ldns_resolver_new');
  Pointer(ldns_resolver_new_frm_file) := LoadFunc('ldns_resolver_new_frm_file');
  Pointer(ldns_resolver_free) := LoadFunc('ldns_resolver_free');
  Pointer(ldns_resolver_deep_free) := LoadFunc('ldns_resolver_deep_free');
  Pointer(ldns_resolver_query) := LoadFunc('ldns_resolver_query');
  Pointer(ldns_resolver_set_dnssec) := LoadFunc('ldns_resolver_set_dnssec');
  Pointer(ldns_resolver_set_dnssec_cd) := LoadFunc('ldns_resolver_set_dnssec_cd');
  Pointer(ldns_resolver_set_dnssec_anchors) := LoadFunc('ldns_resolver_set_dnssec_anchors');
  Pointer(ldns_resolver_dnssec) := LoadFunc('ldns_resolver_dnssec');
  Pointer(ldns_resolver_set_timeout) := LoadFunc('ldns_resolver_set_timeout');
  Pointer(ldns_resolver_set_retry) := LoadFunc('ldns_resolver_set_retry');
  Pointer(ldns_resolver_nameserver_count) := LoadFunc('ldns_resolver_nameserver_count');
  Pointer(ldns_resolver_push_nameserver_rr) := LoadFunc('ldns_resolver_push_nameserver_rr');
  Pointer(ldns_resolver_push_nameserver) := LoadFunc('ldns_resolver_push_nameserver');

  // 加载 RDF 函数
  Pointer(ldns_rdf_new_frm_str) := LoadFunc('ldns_rdf_new_frm_str');
  Pointer(ldns_rdf_new_frm_data) := LoadFunc('ldns_rdf_new_frm_data');
  Pointer(ldns_rdf_free) := LoadFunc('ldns_rdf_free');
  Pointer(ldns_rdf_deep_free) := LoadFunc('ldns_rdf_deep_free');
  Pointer(ldns_rdf_data) := LoadFunc('ldns_rdf_data');
  Pointer(ldns_rdf_size) := LoadFunc('ldns_rdf_size');
  Pointer(ldns_rdf_get_type) := LoadFunc('ldns_rdf_get_type');
  Pointer(ldns_rdf2native_int8) := LoadFunc('ldns_rdf2native_int8');
  Pointer(ldns_rdf2native_int16) := LoadFunc('ldns_rdf2native_int16');
  Pointer(ldns_dname_new_frm_str) := LoadFunc('ldns_dname_new_frm_str');

  // 加载 RR 函数
  Pointer(ldns_rr_new) := LoadFunc('ldns_rr_new');
  Pointer(ldns_rr_free) := LoadFunc('ldns_rr_free');
  Pointer(ldns_rr_get_type) := LoadFunc('ldns_rr_get_type');
  Pointer(ldns_rr_get_class) := LoadFunc('ldns_rr_get_class');
  Pointer(ldns_rr_ttl) := LoadFunc('ldns_rr_ttl');
  Pointer(ldns_rr_rd_count) := LoadFunc('ldns_rr_rd_count');
  Pointer(ldns_rr_rdf) := LoadFunc('ldns_rr_rdf');
  Pointer(ldns_rr_owner) := LoadFunc('ldns_rr_owner');

  // 加载 RR 列表函数
  Pointer(ldns_rr_list_new) := LoadFunc('ldns_rr_list_new');
  Pointer(ldns_rr_list_free) := LoadFunc('ldns_rr_list_free');
  Pointer(ldns_rr_list_deep_free) := LoadFunc('ldns_rr_list_deep_free');
  Pointer(ldns_rr_list_rr_count) := LoadFunc('ldns_rr_list_rr_count');
  Pointer(ldns_rr_list_rr) := LoadFunc('ldns_rr_list_rr');
  Pointer(ldns_rr_list_push_rr) := LoadFunc('ldns_rr_list_push_rr');
  Pointer(ldns_rr_list_pop_rr) := LoadFunc('ldns_rr_list_pop_rr');

  // 加载数据包函数
  Pointer(ldns_pkt_free) := LoadFunc('ldns_pkt_free');
  Pointer(ldns_pkt_rr_list_by_type) := LoadFunc('ldns_pkt_rr_list_by_type');
  Pointer(ldns_pkt_ancount) := LoadFunc('ldns_pkt_ancount');
  Pointer(ldns_pkt_answer) := LoadFunc('ldns_pkt_answer');
  Pointer(ldns_pkt_ad) := LoadFunc('ldns_pkt_ad');
  Pointer(ldns_pkt_get_rcode) := LoadFunc('ldns_pkt_get_rcode');
  Pointer(ldns_pkt_tc) := LoadFunc('ldns_pkt_tc');

  // 加载 DNSSEC 函数
  Pointer(ldns_dnssec_data_chain_new) := LoadFunc('ldns_dnssec_data_chain_new');
  Pointer(ldns_dnssec_data_chain_free) := LoadFunc('ldns_dnssec_data_chain_free');
  Pointer(ldns_dnssec_data_chain_deep_free) := LoadFunc('ldns_dnssec_data_chain_deep_free');
  Pointer(ldns_dnssec_build_data_chain) := LoadFunc('ldns_dnssec_build_data_chain');
  Pointer(ldns_dnssec_trust_tree_new) := LoadFunc('ldns_dnssec_trust_tree_new');
  Pointer(ldns_dnssec_trust_tree_free) := LoadFunc('ldns_dnssec_trust_tree_free');
  Pointer(ldns_dnssec_derive_trust_tree) := LoadFunc('ldns_dnssec_derive_trust_tree');
  Pointer(ldns_dnssec_trust_tree_contains_keys) := LoadFunc('ldns_dnssec_trust_tree_contains_keys');
  Pointer(ldns_dnssec_verify_denial) := LoadFunc('ldns_dnssec_verify_denial');
  Pointer(ldns_verify) := LoadFunc('ldns_verify');
  Pointer(ldns_verify_rrsig_keylist) := LoadFunc('ldns_verify_rrsig_keylist');

  // 加载错误函数
  Pointer(ldns_get_errorstr_by_id) := LoadFunc('ldns_get_errorstr_by_id');

  // 加载转换函数
  Pointer(ldns_rr2str) := LoadFunc('ldns_rr2str');
  Pointer(ldns_rdf2str) := LoadFunc('ldns_rdf2str');
  Pointer(ldns_pkt2str) := LoadFunc('ldns_pkt2str');

  // 检查关键函数是否加载成功
  if not Assigned(ldns_resolver_new_frm_file) or
    not Assigned(ldns_resolver_query) or
    not Assigned(ldns_pkt_rr_list_by_type) or
    not Assigned(ldns_rr_rdf) then
  begin
    LdnsLoadError := 'ldns 库缺少必要的函数';
    platform_dl_close(LdnsHandle);
    Exit(False);
  end;

  LdnsLoaded := True;
  Result := True;
end;

function IsLdnsLoaded: Boolean;
begin
  Result := LdnsLoaded;
end;

procedure UnloadLdns;
begin
  if LdnsHandleValid(LdnsHandle) then
    platform_dl_close(LdnsHandle);

  LdnsLoaded := False;

  // 清除函数指针
  ldns_resolver_new := nil;
  ldns_resolver_new_frm_file := nil;
  ldns_resolver_free := nil;
  ldns_resolver_deep_free := nil;
  ldns_resolver_query := nil;
  ldns_resolver_set_dnssec := nil;
  ldns_resolver_set_dnssec_cd := nil;
  ldns_resolver_set_dnssec_anchors := nil;
  ldns_resolver_dnssec := nil;
  ldns_resolver_set_timeout := nil;
  ldns_resolver_set_retry := nil;
  ldns_resolver_nameserver_count := nil;
  ldns_resolver_push_nameserver_rr := nil;
  ldns_resolver_push_nameserver := nil;

  ldns_rdf_new_frm_str := nil;
  ldns_rdf_new_frm_data := nil;
  ldns_rdf_free := nil;
  ldns_rdf_deep_free := nil;
  ldns_rdf_data := nil;
  ldns_rdf_size := nil;
  ldns_rdf_get_type := nil;
  ldns_rdf2native_int8 := nil;
  ldns_rdf2native_int16 := nil;
  ldns_dname_new_frm_str := nil;

  ldns_rr_new := nil;
  ldns_rr_free := nil;
  ldns_rr_get_type := nil;
  ldns_rr_get_class := nil;
  ldns_rr_ttl := nil;
  ldns_rr_rd_count := nil;
  ldns_rr_rdf := nil;
  ldns_rr_owner := nil;

  ldns_rr_list_new := nil;
  ldns_rr_list_free := nil;
  ldns_rr_list_deep_free := nil;
  ldns_rr_list_rr_count := nil;
  ldns_rr_list_rr := nil;
  ldns_rr_list_push_rr := nil;
  ldns_rr_list_pop_rr := nil;

  ldns_pkt_free := nil;
  ldns_pkt_rr_list_by_type := nil;
  ldns_pkt_ancount := nil;
  ldns_pkt_answer := nil;
  ldns_pkt_ad := nil;
  ldns_pkt_get_rcode := nil;
  ldns_pkt_tc := nil;

  ldns_dnssec_data_chain_new := nil;
  ldns_dnssec_data_chain_free := nil;
  ldns_dnssec_data_chain_deep_free := nil;
  ldns_dnssec_build_data_chain := nil;
  ldns_dnssec_trust_tree_new := nil;
  ldns_dnssec_trust_tree_free := nil;
  ldns_dnssec_derive_trust_tree := nil;
  ldns_dnssec_trust_tree_contains_keys := nil;
  ldns_dnssec_verify_denial := nil;
  ldns_verify := nil;
  ldns_verify_rrsig_keylist := nil;

  ldns_get_errorstr_by_id := nil;

  ldns_rr2str := nil;
  ldns_rdf2str := nil;
  ldns_pkt2str := nil;
end;

function GetLdnsLoadError: string;
begin
  Result := LdnsLoadError;
end;

function QueryDNSTLSA(const ADomain: string; APort: Word;
  const AProtocol: string; out ARecords: TLdnsTLSARecordArray;
  out ADNSSECStatus: TDNSSECStatus): Boolean;
var
  Resolver: Pldns_resolver;
  QueryName: Pldns_rdf;
  Packet: Pldns_pkt;
  RRList: Pldns_rr_list;
  RR: Pldns_rr;
  QueryStr: AnsiString;
  i, RDCount: Integer;
  UsageRdf, SelectorRdf, MatchingRdf, DataRdf: Pldns_rdf;
  DataPtr: PByte;
  DataSize: Cardinal;
  Status: ldns_status;
begin
  Result := False;
  SetLength(ARecords, 0);
  ADNSSECStatus := dnssecUnknown;

  // 检查 ldns 是否可用
  if not IsLdnsLoaded then
  begin
    if not LoadLdns then
      Exit(False);
  end;

  Resolver := nil;
  QueryName := nil;
  Packet := nil;
  RRList := nil;

  try
    // 从 /etc/resolv.conf 创建解析器
    Status := ldns_resolver_new_frm_file(@Resolver, nil);
    if (Status <> LDNS_STATUS_OK) or (Resolver = nil) then
      Exit(False);

    // 启用 DNSSEC
    if Assigned(ldns_resolver_set_dnssec) then
      ldns_resolver_set_dnssec(Resolver, 1);

    // 构造 TLSA 查询名称: _<port>._<protocol>.<domain>
    QueryStr := AnsiString(Format('_%d._%s.%s', [APort, LowerCase(AProtocol), ADomain]));
    QueryName := ldns_dname_new_frm_str(PAnsiChar(QueryStr));
    if QueryName = nil then
      Exit(False);

    // 执行 DNS 查询
    Packet := ldns_resolver_query(Resolver, QueryName, LDNS_RR_TYPE_TLSA,
      LDNS_RR_CLASS_IN, LDNS_RD);
    if Packet = nil then
      Exit(False);

    // 检查 AD (Authentic Data) 标志以确定 DNSSEC 状态
    if Assigned(ldns_pkt_ad) then
    begin
      if ldns_pkt_ad(Packet) <> 0 then
        ADNSSECStatus := dnssecSecure
      else
        ADNSSECStatus := dnssecInsecure;
    end;

    // 获取 TLSA 记录
    RRList := ldns_pkt_rr_list_by_type(Packet, LDNS_RR_TYPE_TLSA, LDNS_SECTION_ANSWER);
    if RRList = nil then
      Exit(True);  // 查询成功但没有记录

    // 解析 TLSA 记录
    for i := 0 to ldns_rr_list_rr_count(RRList) - 1 do
    begin
      RR := ldns_rr_list_rr(RRList, i);
      if RR = nil then
        Continue;

      // TLSA 记录格式: usage selector matchingType certificateData
      RDCount := ldns_rr_rd_count(RR);
      if RDCount < 4 then
        Continue;

      UsageRdf := ldns_rr_rdf(RR, 0);
      SelectorRdf := ldns_rr_rdf(RR, 1);
      MatchingRdf := ldns_rr_rdf(RR, 2);
      DataRdf := ldns_rr_rdf(RR, 3);

      if (UsageRdf = nil) or (SelectorRdf = nil) or
        (MatchingRdf = nil) or (DataRdf = nil) then
        Continue;

      SetLength(ARecords, Length(ARecords) + 1);
      with ARecords[High(ARecords)] do
      begin
        Usage := ldns_rdf2native_int8(UsageRdf);
        Selector := ldns_rdf2native_int8(SelectorRdf);
        MatchingType := ldns_rdf2native_int8(MatchingRdf);
        TTL := ldns_rr_ttl(RR);

        // 获取证书数据
        DataPtr := ldns_rdf_data(DataRdf);
        DataSize := ldns_rdf_size(DataRdf);
        if (DataPtr <> nil) and (DataSize > 0) then
        begin
          SetLength(CertData, DataSize);
          Move(DataPtr^, CertData[0], DataSize);
        end;
      end;
    end;

    Result := True;

  finally
    // 清理资源
    if RRList <> nil then
      ldns_rr_list_deep_free(RRList);
    if Packet <> nil then
      ldns_pkt_free(Packet);
    if QueryName <> nil then
      ldns_rdf_deep_free(QueryName);
    if Resolver <> nil then
      ldns_resolver_deep_free(Resolver);
  end;
end;

function VerifyDNSSECChain(const ADomain: string; ARRType: ldns_rr_type): TDNSSECStatus;
var
  Resolver: Pldns_resolver;
  QueryName: Pldns_rdf;
  Packet: Pldns_pkt;
  Status: ldns_status;
  QueryStr: AnsiString;
begin
  Result := dnssecUnknown;

  // 检查 ldns 是否可用
  if not IsLdnsLoaded then
  begin
    if not LoadLdns then
      Exit(dnssecUnknown);
  end;

  Resolver := nil;
  QueryName := nil;
  Packet := nil;

  try
    // 创建解析器
    Status := ldns_resolver_new_frm_file(@Resolver, nil);
    if (Status <> LDNS_STATUS_OK) or (Resolver = nil) then
      Exit(dnssecUnknown);

    // 启用 DNSSEC
    if Assigned(ldns_resolver_set_dnssec) then
      ldns_resolver_set_dnssec(Resolver, 1);

    // 创建查询名称
    QueryStr := AnsiString(ADomain);
    QueryName := ldns_dname_new_frm_str(PAnsiChar(QueryStr));
    if QueryName = nil then
      Exit(dnssecUnknown);

    // 执行查询
    Packet := ldns_resolver_query(Resolver, QueryName, ARRType,
      LDNS_RR_CLASS_IN, LDNS_RD or LDNS_AD);
    if Packet = nil then
      Exit(dnssecUnknown);

    // 检查 AD 标志
    if Assigned(ldns_pkt_ad) then
    begin
      if ldns_pkt_ad(Packet) <> 0 then
        Result := dnssecSecure
      else
      begin
        // 检查是否有 RRSIG 记录
        if ldns_pkt_ancount(Packet) > 0 then
          Result := dnssecInsecure
        else
          Result := dnssecIndeterminate;
      end;
    end;

  finally
    if Packet <> nil then
      ldns_pkt_free(Packet);
    if QueryName <> nil then
      ldns_rdf_deep_free(QueryName);
    if Resolver <> nil then
      ldns_resolver_deep_free(Resolver);
  end;
end;

function DNSSECStatusToStr(AStatus: TDNSSECStatus): string;
begin
  case AStatus of
    dnssecUnknown: Result := 'Unknown';
    dnssecSecure: Result := 'Secure (DNSSEC validated)';
    dnssecInsecure: Result := 'Insecure (not signed)';
    dnssecBogus: Result := 'Bogus (DNSSEC validation failed)';
    dnssecIndeterminate: Result := 'Indeterminate';
  end;
end;

initialization
  LdnsLoaded := False;
  FillChar(LdnsHandle, SizeOf(LdnsHandle), 0);
  LdnsLoadError := '';

finalization
  UnloadLdns;

end.
