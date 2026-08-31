unit nextpas.core.net.quic.h3;

{** @desc HTTP/3 最小面（RFC 9114）+ QPACK-lite（RFC 9204）：E3 hysteria2
       认证层承载，独立可测，未来 H3 用途可复用。
       帧层：SETTINGS/HEADERS/DATA/GOAWAY 收发（type varint + len varint +
       payload），其余帧类型收方忽略（RFC 9114 §7.1 unknown frame 语义）。
       头块编码三形态择优：静态表整行索引（:method POST 等）/ 名索引字面量
       （:authority、:path）/ 全字面量；字符串一律 raw 不 huffman（合法优化
       省略——RFC 7541 §5.2 huffman 为发送方可选项）。头块解码按「我方通告
       QPACK 容量 0」场景：对端动态表容量必为 0，required insert count 或
       base 非 0 即拒绝（fail-closed：我方从未授权动态表）；支持 static
       indexed / name-ref / literal 三形态 + huffman/raw 字符串双态解码
       （真机 quic-go 服务端恒 huffman 编码，实测确认）。
       对拍源：github.com/quic-go/qpack@v0.5.1 + golang.org/x/net/http2/hpack。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.varint;

const
  { RFC 9114 §7.5 帧类型（我方实现面；其余类型解析层跳过） }
  cH3FrameData     = $0;
  cH3FrameHeaders  = $1;
  cH3FrameSettings = $4;
  cH3FrameGoaway   = $7;

  { RFC 9114 §6.2 单向流类型（控制流首字节） }
  cH3StreamControl = $0;

  { RFC 9114 §7.2.4 SETTINGS 标识符 }
  cH3SettingQpackMaxTableCapacity = $1;
  cH3SettingMaxFieldSectionSize   = $6;
  cH3SettingQpackBlockedStreams   = $7;

  { RFC 9204 附录 A 静态表认证请求锚点 }
  cQpackIdxAuthority   = 0;
  cQpackIdxPath        = 1;
  cQpackIdxMethodPost  = 20;
  cQpackIdxSchemeHttps = 23;
  cQpackIdxStatus200   = 25;

type
  TQuicH3Header = record
    Name: string;
    Value: string;
  end;
  TQuicH3HeaderArray = array of TQuicH3Header;

{ ---- 帧层（RFC 9114 §7.1）：type(varint) ‖ len(varint) ‖ payload ---- }

{** @desc 追加一帧到 ABuf 尾部 *}
procedure QuicH3FrameAppend(var ABuf: TBytes; AType: UInt64;
  const APayload: TBytes);

{** @desc 从 ABuf[AOfs] 解析一帧。成功输出类型、载荷区间与整帧消耗；
  *       缓冲不足（半帧）返回 False（调用方继续等数据）。 *}
function TryQuicH3FrameParse(const ABuf: TBytes; AOfs: Integer;
  out AType: UInt64; out APayloadOfs, APayloadLen, AConsumed: Integer): Boolean;

{** @desc SETTINGS 载荷追加一条目：id(varint) ‖ value(varint) *}
procedure QuicH3SettingAppend(var APayload: TBytes; AId, AValue: UInt64);

{ ---- QPACK 头块（RFC 9204 §4.5） ---- }

{** @desc 编码头块：前缀 RIC=0/Base=0 + 每头三形态择优（整行静态 →
  *       名引用 → 全字面量）；值一律 raw。 *}
function QuicH3EncodeHeaders(
  const AHeaders: TQuicH3HeaderArray): TBytes;

{** @desc 解码头块（容量 0 场景）。前缀非零、动态表指令形态、索引越界、
  *       截断一律 False（fail-closed）。 *}
function TryQuicH3DecodeHeaders(const ABuf: TBytes;
  out AHeaders: TQuicH3HeaderArray): Boolean;

{** @desc HPACK/QPACK Huffman 解码（RFC 7541 附录 B 码表）：ASrc[AOfs..]
  *       共 ABitLen 字节区间按位解码；尾部 padding 必须 <8 位且全 1。
  *       编码方向不提供（我方恒 raw，合法）。 *}
function TryHpackHuffDecode(const ASrc: TBytes; AOfs, ALen: Integer;
  out AStr: string): Boolean;

implementation

const
  { Huffman 解码树节点池上界：257 符号的前缀码树节点总数 ≤ 2×257-1 }
  cHuffNodeCap = 600;

type
  THuffNode = record
    ChildLo: Integer;   { -1 = 无子 }
    ChildHi: Integer;
    Sym: Integer;       { >=0 = 叶子符号 }
  end;

  TQpackStaticEntry = record
    N: string;
    V: string;
  end;

const
{$I nextpas.core.net.quic.h3.tables.inc}

var
  { 单元 initialization 一次构建，运行期只读（无并发写面） }
  GHuffTree: array[0..cHuffNodeCap - 1] of THuffNode;
  GHuffCount: Integer;

procedure HuffTreeBuild;
var
  LSym, LBit, LNode, LNext: Integer;
begin
  GHuffCount := 1;
  FillChar(GHuffTree, SizeOf(GHuffTree), 0);
  for LBit := 0 to cHuffNodeCap - 1 do
  begin
    GHuffTree[LBit].ChildLo := -1;
    GHuffTree[LBit].ChildHi := -1;
    GHuffTree[LBit].Sym := -1;
  end;
  for LSym := 0 to 255 do
  begin
    LNode := 0;
    for LBit := cHpackHuffBits[LSym] - 1 downto 0 do
    begin
      if (Integer(cHpackHuffCodes[LSym] shr LBit) and 1) = 0 then
      begin
        if GHuffTree[LNode].ChildLo < 0 then
        begin
          if GHuffCount >= cHuffNodeCap then
            Exit;   { 不可能：节点池按树规模定界 }
          LNext := GHuffCount;
          Inc(GHuffCount);
          GHuffTree[LNode].ChildLo := LNext;
        end;
        LNode := GHuffTree[LNode].ChildLo;
      end
      else
      begin
        if GHuffTree[LNode].ChildHi < 0 then
        begin
          if GHuffCount >= cHuffNodeCap then
            Exit;
          LNext := GHuffCount;
          Inc(GHuffCount);
          GHuffTree[LNode].ChildHi := LNext;
        end;
        LNode := GHuffTree[LNode].ChildHi;
      end;
    end;
    GHuffTree[LNode].Sym := LSym;
  end;
end;

function TryHpackHuffDecode(const ASrc: TBytes; AOfs, ALen: Integer;
  out AStr: string): Boolean;
var
  LNode, LSym: Integer;
  LByte, LBitIdx, LBit: Integer;
  LTrailBits: Integer;
  LTrailCode: Integer;
  LCh: Byte;
begin
  Result := False;
  AStr := '';
  if (AOfs < 0) or (ALen < 0) or (AOfs + ALen > Length(ASrc)) then
    Exit;
  LTrailBits := 0;
  LTrailCode := 0;
  LNode := 0;
  for LByte := AOfs to AOfs + ALen - 1 do
  begin
    LCh := ASrc[LByte];
    for LBitIdx := 7 downto 0 do
    begin
      LBit := (LCh shr LBitIdx) and 1;
      if LBit = 0 then
        LNode := GHuffTree[LNode].ChildLo
      else
        LNode := GHuffTree[LNode].ChildHi;
      if LNode < 0 then
        Exit;   { 非法前缀码路径 }
      if GHuffTree[LNode].Sym >= 0 then
      begin
        LSym := GHuffTree[LNode].Sym;
        AStr := AStr + Chr(LSym);
        LNode := 0;
        LTrailBits := 0;
        LTrailCode := 0;
      end
      else
      begin
        LTrailCode := (LTrailCode shl 1) or LBit;
        Inc(LTrailBits);
        if LTrailBits > 30 then
          Exit;   { EOS 形态超界：流中不允许完整 EOS }
      end;
    end;
  end;
  { RFC 7541 §6.2：尾部 padding <8 位且必须全为 EOS 最高位（全 1） }
  if LTrailBits > 0 then
  begin
    if (LTrailBits >= 8) or
       (LTrailCode <> (1 shl LTrailBits) - 1) then
      Exit;
  end;
  Result := True;
end;

{ ---- RFC 7541 §5.1 前缀整数（QPACK 复用同一线格式） ---- }

procedure AppendTail(var ABuf: TBytes; const ATail: TBytes);
var
  LN, LI: Integer;
begin
  if Length(ATail) = 0 then
    Exit;
  LN := Length(ABuf);
  SetLength(ABuf, LN + Length(ATail));
  for LI := 0 to Length(ATail) - 1 do
    ABuf[LN + LI] := ATail[LI];
end;

procedure PrefixIntAppend(var ABuf: TBytes; APrefixBits: Byte;
  AFirstByteFlags: Byte; AValue: UInt64);
var
  LMax, LV: UInt64;
begin
  LMax := (UInt64(1) shl APrefixBits) - 1;
  if AValue < LMax then
  begin
    QuicBufAppendByte(ABuf, AFirstByteFlags or Byte(AValue));
    Exit;
  end;
  QuicBufAppendByte(ABuf, AFirstByteFlags or Byte(LMax));
  LV := AValue - LMax;
  while LV >= $80 do
  begin
    QuicBufAppendByte(ABuf, Byte(LV and $7F) or $80);
    LV := LV shr 7;
  end;
  QuicBufAppendByte(ABuf, Byte(LV));
end;

function TryPrefixIntRead(const ABuf: TBytes; AOfs: Integer;
  APrefixBits: Byte; out AValue: UInt64; out AConsumed: Integer): Boolean;
var
  LMax, LMul: UInt64;
  LB: Byte;
  LGroups: Integer;
begin
  Result := False;
  AValue := 0;
  AConsumed := 0;
  if (AOfs < 0) or (AOfs >= Length(ABuf)) or (APrefixBits = 0) or
     (APrefixBits > 8) then
    Exit;
  LMax := (UInt64(1) shl APrefixBits) - 1;
  LB := ABuf[AOfs] and Byte(LMax);
  if LB < LMax then
  begin
    AValue := LB;
    AConsumed := 1;
    Result := True;
    Exit;
  end;
  AValue := LMax;
  LMul := 1;
  LGroups := 0;
  while True do
  begin
    Inc(AOfs);
    Inc(LGroups);
    if (AOfs >= Length(ABuf)) or (LGroups > 10) then
      Exit;   { 截断或恶意长编码 }
    LB := ABuf[AOfs];
    AValue := AValue + UInt64(LB and $7F) * LMul;
    LMul := LMul * $80;
    if (LB and $80) = 0 then
      Break;
  end;
  AConsumed := LGroups + 1;
  Result := True;
end;

{ ---- RFC 7541 §5.2 字符串表示 ---- }

procedure HpackStringAppend(var ABuf: TBytes; APrefixBits: Byte;
  AFlagsByte: Byte; const AValue: string);
var
  LN, I: Integer;
begin
  LN := Length(AValue);
  PrefixIntAppend(ABuf, APrefixBits, AFlagsByte, UInt64(LN));   { H 恒 0 raw }
  for I := 1 to LN do
    QuicBufAppendByte(ABuf, Byte(Ord(AValue[I])));
end;

function TryHpackStringRead(const ABuf: TBytes; AOfs: Integer;
  APrefixBits: Byte; AHuffFlagMask: Byte; out AStr: string;
  out AConsumed: Integer): Boolean;
var
  LLen: UInt64;
  LHdr, LLenInt, LI: Integer;
  LHuffman: Boolean;
begin
  Result := False;
  AStr := '';
  AConsumed := 0;
  if (AOfs < 0) or (AOfs >= Length(ABuf)) then
    Exit;
  { H 位位置由形态定：独立字符串字段 = 首字节 MSB（0x80）；
    字面量指令嵌入的 name = 指令位与长度前缀之间的 bit3（0x08），
    一手判据 quic-go/qpack decoder.go usesHuffmanForName }
  LHuffman := (ABuf[AOfs] and AHuffFlagMask) <> 0;
  if not TryPrefixIntRead(ABuf, AOfs, APrefixBits, LLen, LHdr) then
    Exit;
  LLenInt := Integer(LLen);
  if (LLen > $100000) or (AOfs + LHdr + LLenInt > Length(ABuf)) then
    Exit;   { 长度上界防御 + 截断拒绝 }
  if LHuffman then
  begin
    if not TryHpackHuffDecode(ABuf, AOfs + LHdr, LLenInt, AStr) then
      Exit;
  end
  else
  begin
    AStr := '';
    for LI := 0 to LLenInt - 1 do
      AStr := AStr + Chr(ABuf[AOfs + LHdr + LI]);
  end;
  AConsumed := LHdr + LLenInt;
  Result := True;
end;

{ ---- 帧层实现 ---- }

procedure QuicH3FrameAppend(var ABuf: TBytes; AType: UInt64;
  const APayload: TBytes);
begin
  QuicVarintAppend(ABuf, AType);
  QuicVarintAppend(ABuf, UInt64(Length(APayload)));
  AppendTail(ABuf, APayload);
end;

function TryQuicH3FrameParse(const ABuf: TBytes; AOfs: Integer;
  out AType: UInt64; out APayloadOfs, APayloadLen, AConsumed: Integer): Boolean;
var
  LLen: UInt64;
  LC1, LC2: Integer;
begin
  Result := False;
  AType := 0;
  APayloadOfs := 0;
  APayloadLen := 0;
  AConsumed := 0;
  if not QuicVarintDecode(ABuf, AOfs, AType, LC1) then
    Exit;
  if not QuicVarintDecode(ABuf, AOfs + LC1, LLen, LC2) then
    Exit;
  APayloadOfs := AOfs + LC1 + LC2;
  APayloadLen := Integer(LLen);
  if (APayloadLen > $1000000) or
     (APayloadOfs + APayloadLen > Length(ABuf)) then
    Exit;   { 半帧 = 调用方继续等；声明长度越界同理 }
  AConsumed := LC1 + LC2 + APayloadLen;
  Result := True;
end;

procedure QuicH3SettingAppend(var APayload: TBytes; AId, AValue: UInt64);
begin
  QuicVarintAppend(APayload, AId);
  QuicVarintAppend(APayload, AValue);
end;

{ ---- QPACK 头块编码 ---- }

function StaticExactMatch(const AName, AValue: string;
  out AIndex: Integer): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to High(cQpackStaticTable) do
    if (cQpackStaticTable[LI].N = AName) and
       (cQpackStaticTable[LI].V = AValue) then
    begin
      AIndex := LI;
      Result := True;
      Exit;
    end;
end;

function StaticNameMatch(const AName: string; out AIndex: Integer): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to High(cQpackStaticTable) do
    if cQpackStaticTable[LI].N = AName then
    begin
      AIndex := LI;
      Result := True;
      Exit;
    end;
end;

function QuicH3EncodeHeaders(
  const AHeaders: TQuicH3HeaderArray): TBytes;
var
  LBuf: TBytes;
  LI, LIdx: Integer;
begin
  LBuf := nil;
  { RFC 9204 §4.5.1 头块前缀：容量 0 ⇒ RIC=0 且 Base=0（双 varint 零） }
  PrefixIntAppend(LBuf, 8, 0, 0);
  PrefixIntAppend(LBuf, 7, 0, 0);
  for LI := 0 to Length(AHeaders) - 1 do
  begin
    if StaticExactMatch(AHeaders[LI].Name, AHeaders[LI].Value, LIdx) then
      PrefixIntAppend(LBuf, 6, $C0, UInt64(LIdx))   { 1Txxxxxx，T=1 静态 }
    else if StaticNameMatch(AHeaders[LI].Name, LIdx) then
    begin
      PrefixIntAppend(LBuf, 4, $50, UInt64(LIdx));  { 0101xxxx：指令 01+T=1 }
      HpackStringAppend(LBuf, 7, 0, AHeaders[LI].Value);
    end
    else
    begin
      { 001 + H(bit3)=0 + 3 位名字长度前缀（一手判据 quic-go encoder.go
        writeLiteralFieldWithoutNameReference 的 xor $28 位型） }
      HpackStringAppend(LBuf, 3, $20, AHeaders[LI].Name);
      HpackStringAppend(LBuf, 7, 0, AHeaders[LI].Value);
    end;
  end;
  Result := LBuf;
end;

{ ---- QPACK 头块解码 ---- }

function TryQuicH3DecodeHeaders(const ABuf: TBytes;
  out AHeaders: TQuicH3HeaderArray): Boolean;
var
  LRic, LBase, LVal: UInt64;
  LOfs, LAdv, LIdx: Integer;
  LB: Byte;
  LHdr: TQuicH3Header;
  LN, LC: Integer;
begin
  Result := False;
  AHeaders := nil;
  LOfs := 0;
  if not TryPrefixIntRead(ABuf, LOfs, 8, LRic, LN) then
    Exit;
  Inc(LOfs, LN);
  if not TryPrefixIntRead(ABuf, LOfs, 7, LBase, LN) then
    Exit;
  Inc(LOfs, LN);
  { 容量 0 场景：动态表从未授权，任何非零前缀 = 对端违规
    （一手判据 quic-go decoder.go decode 的双零校验） }
  if (LRic <> 0) or (LBase <> 0) then
    Exit;

  SetLength(AHeaders, 0);
  while LOfs < Length(ABuf) do
  begin
    LB := ABuf[LOfs];
    if (LB and $C0) = $C0 then
    begin
      { 1Txxxxxx indexed，T 必须为静态（10xxxxxx 动态引用 = 违规） }
      if not TryPrefixIntRead(ABuf, LOfs, 6, LVal, LN) then
        Exit;
      LIdx := Integer(LVal);
      if LIdx > High(cQpackStaticTable) then
        Exit;
      Inc(LOfs, LN);
      LHdr.Name := cQpackStaticTable[LIdx].N;
      LHdr.Value := cQpackStaticTable[LIdx].V;
    end
    else if (LB and $F0) = $50 then
    begin
      { 0101xxxx 名引用字面量（指令 01 + T=1；0100xxxx 动态引用违规） }
      if not TryPrefixIntRead(ABuf, LOfs, 4, LVal, LN) then
        Exit;
      LIdx := Integer(LVal);
      if LIdx > High(cQpackStaticTable) then
        Exit;
      Inc(LOfs, LN);
      LHdr.Name := cQpackStaticTable[LIdx].N;
      if not TryHpackStringRead(ABuf, LOfs, 7, $80, LHdr.Value, LC) then
        Exit;
      Inc(LOfs, LC);
    end
    else if (LB and $E0) = $20 then
    begin
      { 001xxxxx 全字面量：name 嵌首字节（H=bit3、3 位前缀） }
      if not TryHpackStringRead(ABuf, LOfs, 3, $08, LHdr.Name, LC) then
        Exit;
      Inc(LOfs, LC);
      if LOfs >= Length(ABuf) then
        Exit;
      if not TryHpackStringRead(ABuf, LOfs, 7, $80, LHdr.Value, LC) then
        Exit;
      Inc(LOfs, LC);
    end
    else
      Exit;   { 动态表指令/重复条目形态：容量 0 场景不可能合法出现 }

    LN := Length(AHeaders);
    SetLength(AHeaders, LN + 1);
    AHeaders[LN] := LHdr;
  end;
  LAdv := LOfs;
  if LAdv > Length(ABuf) then
    Exit;
  Result := True;
end;

initialization
  HuffTreeBuild;

end.
