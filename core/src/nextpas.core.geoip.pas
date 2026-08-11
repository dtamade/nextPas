unit nextpas.core.geoip;
{**
 * @desc IP → 国家（ISO 3166-1 alpha-2）查询 —— 不可变二进制表，一次加载
 *       后内存二分查找。
 * @layer L2
 * 零 SysUtils 依赖。
 *
 * 二进制表格式（生成方与 core 本模块共同遵守；core 定义、生成方消费）：
 *
 *   header（12 字节）:
 *     magic    "PPGIP"（5B）
 *     version  u8（=1）
 *     reserved u16（=0，忽略）
 *     count    u32 BE（记录条数）
 *   record（10 字节/条，按 FromIp 升序、不可重叠，含相邻同国段合并语义）:
 *     from_ip  u32 BE   IPv4 主机序大端
 *     to_ip    u32 BE   闭区间 [from, to]
 *     cc       char[2]  大写 2 字母国家码；未分配段不入表
 *
 * 查询：二分取「最后一个 FromIp <= x」，命中且 x <= ToIp 即返回该段国家码，
 * 否则 ''（未知/未分配）。表加载后不可变只读，无锁并发查询安全。
 *
 * 数据来源无关：IP2Location LITE DB1 等任意导出物生成该格式即可喂入。
 * 数据文件缺失/格式非法 → TryLoadGeoIpTable 返回 False（调用方降级），
 * 不抛异常。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes;

type
  { 国家查询表接口：加载后不可变只读，可并发查询。 }
  IGeoIpTable = interface
    ['{4F2B91C8-6A3D-4E07-9B52-C1D8E4F7A0B6}']
    { 按整数 IPv4（主机序）查国家码；未知/未分配返回 '' }
    function Lookup(const AIp: UInt32): string;
    { 按 "a.b.c.d" 文本查国家码；解析失败/未知返回 '' }
    function LookupIp(const AIpText: string): string;
    { 表内网段条数（0 = 空表，Lookup 恒 ''） }
    function Count: Integer;
  end;

{ 从二进制文件加载国家表（格式见模块头注释）。
  文件缺失/魔数错/版本错/长度不匹配/区间非法/乱序 → False，不抛异常。 }
function TryLoadGeoIpTable(const APath: string; out ATable: IGeoIpTable): Boolean;

{ 从内存字节构造国家表（格式同文件；测试/注入用），失败返回 False。 }
function TryBuildGeoIpTable(const AData: TBytes; out ATable: IGeoIpTable): Boolean;

implementation

uses
  nextpas.core.fs;

const
  { 表格式常量（见模块头注释） }
  cGeoIpMagic0     = Ord('P');
  cGeoIpMagic1     = Ord('P');
  cGeoIpMagic2     = Ord('G');
  cGeoIpMagic3     = Ord('I');
  cGeoIpMagic4     = Ord('P');
  cGeoIpVersion    = 1;
  cGeoIpHeaderSize = 12;
  cGeoIpRecordSize = 10;

type
  TGeoIpEntry = record
    FromIp: UInt32;
    ToIp: UInt32;
    Country: string;
  end;
  TGeoIpEntryArray = array of TGeoIpEntry;

  TGeoIpTable = class(TInterfacedObject, IGeoIpTable)
  private
    FEntries: TGeoIpEntryArray;
  public
    function Lookup(const AIp: UInt32): string;
    function LookupIp(const AIpText: string): string;
    function Count: Integer;
  end;

function TryBuildGeoIpTable(const AData: TBytes; out ATable: IGeoIpTable): Boolean;
var
  LCount, LI: UInt32;
  LP: PByte;
  LTable: TGeoIpTable;
  LFrom, LTo: UInt32;
  LPrevTo: UInt32;
begin
  Result := False;
  ATable := nil;
  if Length(AData) < cGeoIpHeaderSize then
    Exit;   { 连头都不完整 }
  LP := @AData[0];
  if (LP[0] <> cGeoIpMagic0) or (LP[1] <> cGeoIpMagic1) or
    (LP[2] <> cGeoIpMagic2) or (LP[3] <> cGeoIpMagic3) or
    (LP[4] <> cGeoIpMagic4) then
    Exit;   { 魔数不符 }
  if LP[5] <> cGeoIpVersion then
    Exit;   { 版本不符 }
  { LP[6..7] reserved 忽略 }
  LCount := ReadUInt32BE(LP + 8);
  if UInt64(LCount) * cGeoIpRecordSize + cGeoIpHeaderSize <> UInt64(Length(AData)) then
    Exit;   { 长度不匹配（截断/多余）→ 非法 }
  LTable := TGeoIpTable.Create;
  SetLength(LTable.FEntries, LCount);
  LP := LP + cGeoIpHeaderSize;
  LPrevTo := 0;
  for LI := 0 to LCount - 1 do
  begin
    LFrom := ReadUInt32BE(LP);
    LP := LP + 4;
    LTo := ReadUInt32BE(LP);
    LP := LP + 4;
    LTable.FEntries[LI].FromIp := LFrom;
    LTable.FEntries[LI].ToIp := LTo;
    LTable.FEntries[LI].Country := Char(LP[0]) + Char(LP[1]);
    LP := LP + 2;
    if LFrom > LTo then
    begin
      LTable.Free;   { 释放部分构造的表（类引用无引用计数，须显式 Free） }
      Exit;          { 非法区间 }
    end;
    if (LI > 0) and (LFrom <= LPrevTo) then
    begin
      LTable.Free;
      Exit;          { 乱序/重叠（要求严格递增）→ 二分前提被破坏 }
    end;
    LPrevTo := LTo;
  end;
  ATable := LTable;
  Result := True;
end;

function TryLoadGeoIpTable(const APath: string; out ATable: IGeoIpTable): Boolean;
var
  LData: TBytes;
begin
  ATable := nil;
  if not nextpas.core.fs.Exists(APath) then
    Exit(False);
  LData := nextpas.core.fs.ReadFile(APath);
  Result := TryBuildGeoIpTable(LData, ATable);
end;

{ 二分：LHi 收敛到「最后一个 FromIp <= AIp」的索引（-1 = 无），
  命中且 ToIp 覆盖即返回国家码。 }
function TGeoIpTable.Lookup(const AIp: UInt32): string;
var
  LLo, LHi, LMid: Integer;
begin
  Result := '';
  LLo := 0;
  LHi := Length(FEntries) - 1;
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if FEntries[LMid].FromIp <= AIp then
      LLo := LMid + 1
    else
      LHi := LMid - 1;
  end;
  if (LHi >= 0) and (AIp <= FEntries[LHi].ToIp) then
    Result := FEntries[LHi].Country;
end;

{ IPv4 文本 → 主机序 UInt32：4 段十进制 0..255，宽容首尾空白，
  段数不符/越界/残留字符 → 失败返回 ''。 }
function TGeoIpTable.LookupIp(const AIpText: string): string;
var
  LI, LSeg, LOctet: Integer;
  LIp: UInt32;

  { 解析一段十进制并推进 LI；失败返回 -1 }
  function NextOctet: Integer;
  begin
    Result := -1;
    if (LI > Length(AIpText)) or (AIpText[LI] < '0') or (AIpText[LI] > '9') then
      Exit;
    Result := 0;
    while (LI <= Length(AIpText)) and (AIpText[LI] >= '0') and (AIpText[LI] <= '9') do
    begin
      Result := Result * 10 + (Ord(AIpText[LI]) - Ord('0'));
      if Result > 255 then
        Exit(Result);   { 调用方以 >255 判非法 }
      Inc(LI);
    end;
  end;

begin
  Result := '';
  LIp := 0;
  LI := 1;
  while (LI <= Length(AIpText)) and ((AIpText[LI] = ' ') or (AIpText[LI] = #9)) do
    Inc(LI);   { 跳过首部空白 }
  for LSeg := 0 to 2 do
  begin
    LOctet := NextOctet;
    if (LOctet < 0) or (LOctet > 255) then
      Exit;
    if (LI > Length(AIpText)) or (AIpText[LI] <> '.') then
      Exit;
    Inc(LI);
    LIp := (LIp shl 8) or UInt32(LOctet);
  end;
  LOctet := NextOctet;
  if (LOctet < 0) or (LOctet > 255) then
    Exit;
  LIp := (LIp shl 8) or UInt32(LOctet);
  while (LI <= Length(AIpText)) and ((AIpText[LI] = ' ') or (AIpText[LI] = #9)) do
    Inc(LI);   { 跳过尾部空白 }
  if LI <= Length(AIpText) then
    Exit;   { 残留字符 → 非法 }
  Result := Lookup(LIp);
end;

function TGeoIpTable.Count: Integer;
begin
  Result := Length(FEntries);
end;

end.
