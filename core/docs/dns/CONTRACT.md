# CONTRACT: nextpas.core.dns(L2)

状态:v1.0(draft→landing 冻结)| 日期:2026-08-17 | 归属:批次 4(net.resolve 增强)

## 1. 职责与边界

- 提供 DNS 记录查询原语:TXT/MX/NS/SOA/A/AAAA 的**同步 UDP 查询**、
  `resolv.conf` nameserver 读取、按 TTL 的结果缓存。
- 供 mailServer888 Phase 2(SPF/DMARC 读 TXT,MX 供出站直投)与 Phase 5 消费。
- **不做**:EDNS0、DNSSEC 验证、TCP fallback、异步 API(调用方自行卸载到
  worker/async 层)、域名字符串国际化(IDN)。
- 依赖:同层单向 `net`(net.base/net.intf/net.udp)+ L0(`platform.socket`、
  `collections`、`text.conv`、`encoding`)。**不反向依赖**上层模块。

## 2. 类型(冻结)

```pascal
TDnsRecordType = (drtA, drtAAAA, drtMX, drtTXT, drtNS, drtSOA);

TDnsRecord = record
  Name: string; RType: TDnsRecordType; TTL: UInt32;
  A: UInt32;                       // drtA: 网络字节序 IPv4
  AAAA: string;                    // drtAAAA: 冒号文本(如 2001:db8::1)
  MXPreference: UInt16; MXExchange: string;   // drtMX
  TXT: string;                     // drtTXT: 多字符串按序拼接
  NSOwner: string;                 // drtNS: 权威 NS 域名
  SOAMName: string; SOARName: string; SOASerial: UInt32;  // drtSOA
end;

TDnsQueryKind = (dqA, dqAAAA, dqMX, dqTXT, dqNS, dqSOA);

IDnsResolver = interface
  ['{6F1D6F1D-4D7C-4E31-9100-4100000000D1}']
  function Query(const AName: string; const AKind: TDnsQueryKind;
    const ATimeoutMs: Int32; out ARecords: array of TDnsRecord;
    out AError: string): Boolean;
  function QueryTXT(const AName: string; const ATimeoutMs: Int32;
    out ATexts: array of string; out AError: string): Boolean;
  function QueryMX(const AName: string; const ATimeoutMs: Int32;
    out AHosts: array of string; out AError: string): Boolean;
end;

function DnsResolver(const ANameserver: string = '';
  const ACacheSize: Integer = 256;
  const APort: UInt16 = 53): IDnsResolver;
```

- `Query`:单次查询预算 `ATimeoutMs`(整体上限,含 nameserver 轮换);成功
  返回 `True` 且 `ARecords` 按序填充(类型=请求类型);`False` 时 `AError`
  给原因(nxdomain/timedout/network/malformed/truncated/refused/servfail)。
- `QueryTXT`/`QueryMX`:便捷方法,等价于 `Query` + 投影(TXT 拼接串列表 /
  MX 按 preference 升序的 exchange 列表)。
- `DnsResolver`:空 `ANameserver` 时读取 `/etc/resolv.conf` 的 nameserver
  行(首个可用);`ACacheSize<=0` 禁用缓存;`APort` 默认 53,测试/内网
  可指定高位端口。

## 3. 不变量(INV-*)

- **INV-1 名称编码**:每个 label ≤ 63 字节、全名 ≤ 255 字节(否则拒绝,
  返回 False);标签按小写输出。
- **INV-2 名称解码**:压缩指针递归深度 ≤ 16;每个指针偏移严格指向
  已扫描区之前的更小偏移(防环);越界/坏长度一律拒绝并返回 False。
- **INV-3 响应归属**:应答头部 ID 必须等于查询 ID,否则丢弃重收(单次
  RecvFrom 预算内)。
- **INV-4 超时**:`Query` 不无限阻塞;到 `ATimeoutMs` 必返回 False
  (内部 poll 等待,非忙等)。
- **INV-5 缓存**:命中条目未过期(TTL 秒,最小 60s)才可返回;过期即失效;
  失败结果不缓存。`ACacheSize` 约束容量(LRU 淘汰)。
- **INV-6 TXT**:多字符串按 wire 顺序拼接;零字符串(空应答)不算错误,
  返回空列表。
- **INV-7 MX**:返回顺序按 preference 升序(同 preference 保持 wire 序)。
- **INV-8 RCODE**:非零 RCODE(如 NXDOMAIN=3)返回 False + 原因;
  TC 截断标志置位时返回 False('truncated')。
- **INV-9 畸形**:编解码遇截断/坏类型/坏指针一律返回 False,不抛异常、
  不越界读。
- **INV-10 线程**:`IDnsResolver` 实例不承诺线程安全;每线程/每调用方
  独立实例(缓存即线程隔离)。

## 4. 实现注记

- UDP 超时:`IUdpSocketRuntime.NativeSocketHandle` 取原生 fd +
  `platform_socket_poll(PLATFORM_POLL_IN, timeout)` 等待,再阻塞
  `RecvFrom`(就绪后必有数据)。
- 应答报文允许含非请求类型记录(如 CNAME 链):解析器保留 CNAME 于
  `TDnsResponse`(内部),`Query` 只返回请求类型的记录。
- 缓存键:小写域名 + 类型;TTL 取应答记录最小值(≥60s)。
- AAAA 记录解码(16 字节→文本)按 RFC 5952 简写(省略前导零、压缩
  最长零组)。

## 5. 测试矩阵(测试项目对应)

| 项目 | 覆盖 |
|---|---|
| test_dns_wire | 名称编码/解码、压缩指针、TXT 多字符串、MX 排序、SOA 字段、AAAA 文本化、RCODE/TC、畸形拒绝(INV-1/2/8/9) |
| test_dns_resolve | 本地 mock DNS 对跑:查询/应答归属(INV-3)、超时(INV-4)、缓存命中与过期(INV-5)、nameserver 不可达、NXDOMAIN 原因(INV-8) |

## 6. 风险登记

- resolv.conf 解析仅认 `nameserver <ip>` 行(忽略 search/options)。
- 系统 DNS 不可达时表现:超时 False,由调用方(SPF/DMARC)转 temperror。
- 无 EDNS0:应答 >512B 时 TC 截断 → False('truncated'),不做 TCP 回退。