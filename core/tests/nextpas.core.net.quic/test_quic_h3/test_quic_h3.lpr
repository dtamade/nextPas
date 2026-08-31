program test_quic_h3;

{ HTTP/3 最小面 + QPACK-lite 单元测试：
  帧编解码往返/半帧拒绝、认证头块黄金向量（手算逐字节）、
  编解码自环（三形态全覆盖）、Huffman 解码（RFC 7541 附录 C 黄金向量
  + 手算短串 + padding 校验）、对端 quic-go 风格头块解码、违规面
  （非零前缀/动态引用/越界索引/截断）。
  黄金参照：github.com/quic-go/qpack@v0.5.1 + golang.org/x/net/http2/hpack。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.h3,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cHexDigits: array[0..15] of Char = '0123456789abcdef';

function HexNibbleVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := (HexNibbleVal(AHex[I * 2 + 1]) shl 4) or
      HexNibbleVal(AHex[I * 2 + 2]);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
  begin
    Result := Result + cHexDigits[AData[I] shr 4];
    Result := Result + cHexDigits[AData[I] and $0F];
  end;
end;

function HdrsOf(const APairs: array of string): TQuicH3HeaderArray;
var
  LI: Integer;
begin
  SetLength(Result, Length(APairs) div 2);
  for LI := 0 to High(Result) do
  begin
    Result[LI].Name := APairs[LI * 2];
    Result[LI].Value := APairs[LI * 2 + 1];
  end;
end;

function HeadersText(const AH: TQuicH3HeaderArray): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to Length(AH) - 1 do
    Result := Result + AH[LI].Name + '=' + AH[LI].Value + ';';
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('quic_h3');

  LSuite.Test('frame roundtrip and golden empty-data', procedure
  var
    LBuf, LPayload: TBytes;
    LType: UInt64;
    LOfs, LPo, LPl, LAdv: Integer;
  begin
    { 空 DATA 帧黄金：type=0 len=0 → '0000' }
    LBuf := nil;
    QuicH3FrameAppend(LBuf, cH3FrameData, nil);
    Check(BytesToHex(LBuf) = '0000', 'empty data golden: ' +
      BytesToHex(LBuf));
    { SETTINGS 往返 }
    LPayload := nil;
    QuicH3SettingAppend(LPayload, cH3SettingQpackMaxTableCapacity, 0);
    QuicH3SettingAppend(LPayload, cH3SettingQpackBlockedStreams, 0);
    LBuf := nil;
    QuicH3FrameAppend(LBuf, cH3FrameSettings, LPayload);
    { type(04) len(04) id(01) val(00) id(07) val(00) }
    Check(BytesToHex(LBuf) = '040401000700', 'settings golden: ' +
      BytesToHex(LBuf));
    CheckTrue(TryQuicH3FrameParse(LBuf, 0, LType, LPo, LPl, LAdv),
      'parse ok');
    CheckEqual(UInt64(cH3FrameSettings), LType, 'type');
    CheckEqual(2, LPo, 'payload ofs');
    CheckEqual(4, LPl, 'payload len');
    CheckEqual(6, LAdv, 'consumed');
  end);

  LSuite.Test('frame half-buffer rejected', procedure
  var
    LBuf: TBytes;
    LType: UInt64;
    LPo, LPl, LAdv: Integer;
  begin
    LBuf := HexToBytes('040401');   { 声明 4 字节载荷只有 1 字节 }
    CheckFalse(TryQuicH3FrameParse(LBuf, 0, LType, LPo, LPl, LAdv),
      'half frame rejected');
    LBuf := HexToBytes('04');       { 缺长度字段 }
    CheckFalse(TryQuicH3FrameParse(LBuf, 0, LType, LPo, LPl, LAdv),
      'missing length rejected');
  end);

  LSuite.Test('auth header block golden vector', procedure
  var
    LH: TQuicH3HeaderArray;
    LEnc: string;
  begin
    LH := HdrsOf([':method', 'POST',
                  ':scheme', 'https',
                  ':authority', 'hysteria',
                  ':path', '/auth',
                  'Hysteria-Auth', 'secret']);
    LEnc := BytesToHex(QuicH3EncodeHeaders(LH));
    { 手算逐字节：
      0000                          前缀 RIC=0 Base=0
      D4                            indexed static :method POST (20)
      D7                            indexed static :scheme https (23)
      50 08 hysteria                名索引(:authority=0)+raw 值
      51 05 /auth                   名索引(:path=1)+raw 值
      27 06 Hysteria-Auth           全字面量名（13=len7+续6）
      06 secret                     raw 值 }
    Check(LEnc =
      '0000d4d7500868797374657269615105' +
      '2f61757468270648797374657269' +
      '612d4175746806736563726574',
      'auth block golden: ' + LEnc);
  end);

  LSuite.Test('encode-decode roundtrip covers three forms', procedure
  var
    LH: TQuicH3HeaderArray;
    LOut: TQuicH3HeaderArray;
  begin
    LH := HdrsOf([':method', 'POST',          { 整行静态命中 }
                  ':authority', 'example.com', { 仅名命中 }
                  'x-custom-hdr', 'v@l!ue',   { 全字面量 }
                  ':status', '200',            { 整行静态命中（响应侧） }
                  'content-type', 'text/plain']); { 全字面量（值不命中） }
    CheckTrue(TryQuicH3DecodeHeaders(QuicH3EncodeHeaders(LH), LOut),
      'decode ok');
    Check(HeadersText(LOut) = HeadersText(LH),
      'roundtrip text: ' + HeadersText(LOut));
  end);

  LSuite.Test('huffman decode rfc golden vectors', procedure
  var
    LS: string;
  begin
    { RFC 7541 附录 B 锚点：'a'=00011(5b) 补 3 位全 1 → 0x1F；
      '0'=00000(5b) 补全 → 0x07 }
    CheckTrue(TryHpackHuffDecode(HexToBytes('1F'), 0, 1, LS), 'a parse');
    Check(LS = 'a', 'a decoded: ' + LS);
    CheckTrue(TryHpackHuffDecode(HexToBytes('07'), 0, 1, LS), '0 parse');
    Check(LS = '0', '0 decoded: ' + LS);
    { 黄金向量 = 一手码表（golang.org/x/net/http2/hpack tables.go 转储）
      编码器输出：www.example.com → f1e3c2e5f23a6ba0ab90f4ff；
      no-cache → a8eb10649cbf }
    CheckTrue(TryHpackHuffDecode(HexToBytes('f1e3c2e5f23a6ba0ab90f4ff'),
      0, 12, LS), 'rfc example parse');
    Check(LS = 'www.example.com', 'rfc example decoded: ' + LS);
    CheckTrue(TryHpackHuffDecode(HexToBytes('a8eb10649cbf'), 0, 6, LS),
      'no-cache parse');
    Check(LS = 'no-cache', 'no-cache decoded: ' + LS);
  end);

  LSuite.Test('huffman padding violations rejected', procedure
  var
    LS: string;
  begin
    { 'a'(5 位) 后补 4 个零：padding 非全 1 → 拒 }
    CheckFalse(TryHpackHuffDecode(HexToBytes('10'), 0, 1, LS),
      'zero padding rejected');
    { 尾部剩余 ≥8 位全 1 = 完整 EOS 出现于流中 → 拒（30 位 EOS 的
      前 8 位即 0xFF；此处用非法路径构造：0xFF 是 EOS 前缀，无符号
      可完成） }
    CheckFalse(TryHpackHuffDecode(HexToBytes('FFFFFFFFFF'), 0, 5, LS),
      'eos stream rejected');
  end);

  LSuite.Test('decode quic-go style response block', procedure
  var
    LOut: TQuicH3HeaderArray;
    LRaw: TBytes;
  begin
    { 模拟 quic-go 服务端响应块：
      prefix 0000
      D9 = indexed static :status 200（idx25 → C0|19）
      EE = indexed static content-type application/json（idx46 → C0|2E）
      Hysteria-UDP true → 全字面量 raw：
        20|len('Hysteria-UDP')=12 → 12≥7 → 首字节 0x27 续 0x05
        value 'true' → 04 74727565 }
    LRaw := HexToBytes(
      '0000' +
      'd9' +
      'ee' +
      '270548797374657269612d554450' + '0474727565');
    CheckTrue(TryQuicH3DecodeHeaders(LRaw, LOut), 'server block decode');
    CheckEqual(3, Length(LOut), 'three headers');
    Check((LOut[0].Name = ':status') and (LOut[0].Value = '200'),
      'status line');
    Check((LOut[1].Name = 'content-type') and
      (LOut[1].Value = 'application/json'), 'static literal row');
    Check((LOut[2].Name = 'Hysteria-UDP') and (LOut[2].Value = 'true'),
      'custom literal row');
  end);

  LSuite.Test('decode accepts embedded-huffman name form', procedure
  var
    LOut: TQuicH3HeaderArray;
    LRaw: TBytes;
  begin
    { 字面量形态 name 用 huffman（bit3 置位）：name='a' 编码后 1 字节
      0x1F → 首字节 = 001|H|001 = 0x28|0x01？——001(0x20) + H(0x08)
      + 长度 1(0x01) = 0x29；name 数据 0x1F。value raw：04+'true'。
      注意：huffman 长度指编码后字节数 }
    LRaw := HexToBytes('0000' + '291f' + '0474727565');
    CheckTrue(TryQuicH3DecodeHeaders(LRaw, LOut), 'embedded huffman decode');
    CheckEqual(1, Length(LOut), 'one header');
    Check((LOut[0].Name = 'a') and (LOut[0].Value = 'true'),
      'name=a via huffman');
  end);

  LSuite.Test('decode violation faces are fatal', procedure
  var
    LOut: TQuicH3HeaderArray;
    LRaw: TBytes;
  begin
    { 非零 required insert count：未授权动态表 }
    LRaw := HexToBytes('0200d4');
    CheckFalse(TryQuicH3DecodeHeaders(LRaw, LOut), 'nonzero ric rejected');
    { 动态表整行引用（10xxxxxx = 0x80 形态） }
    LRaw := HexToBytes('00008005');
    CheckFalse(TryQuicH3DecodeHeaders(LRaw, LOut), 'dynamic indexed rejected');
    { 越界静态索引：63+36=99 > 98 }
    LRaw := HexToBytes('0000ff24');
    CheckFalse(TryQuicH3DecodeHeaders(LRaw, LOut), 'index overflow rejected');
    { 截断的名引用 }
    LRaw := HexToBytes('000050');
    CheckFalse(TryQuicH3DecodeHeaders(LRaw, LOut), 'truncated nameref rejected');
  end);

  LSuite.Test('cross-impl: pylsqpack encoded block decodes', procedure
  var
    LOut: TQuicH3HeaderArray;
    LRaw: TBytes;
  begin
    { 一手对拍向量 = pylsqpack（aioquic 同款 C 库，quic-go qpack 行为
      等价面）Encoder.apply_settings(0,0) 后 encode 的响应块：
      :status/content-type/hysteria-udp/hysteria-cc-rx——含 huffman
      编码的自定义名字段（bit3 H 位路径真机形态） }
    LRaw := HexToBytes('0000d9ee2f029fd2125b0c35ad92bf834d96972f039fd2' +
      '125b0c358845acf386089b0000007f');
    CheckTrue(TryQuicH3DecodeHeaders(LRaw, LOut), 'pylsqpack block decode');
    CheckEqual(4, Length(LOut), 'four headers');
    Check((LOut[0].Name = ':status') and (LOut[0].Value = '200'), 'h0');
    Check((LOut[1].Name = 'content-type') and
      (LOut[1].Value = 'application/json'), 'h1');
    Check((LOut[2].Name = 'hysteria-udp') and
      (LOut[2].Value = 'true'), 'h2');
    Check((LOut[3].Name = 'hysteria-cc-rx') and
      (LOut[3].Value = '12500000'), 'h3');
  end);

  LSuite.Test('source contract: no bare FPC RTL in quic.h3', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..',
      'src', 'nextpas.core.net.quic.h3.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL in uses (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.h3');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
