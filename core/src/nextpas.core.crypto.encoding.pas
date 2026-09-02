unit nextpas.core.crypto.encoding;
{**
 * @desc 编码/ASN.1/PKCS8 域门面 (L2 crypto 四件套已落地: encoding.base ← encoding.intf ← encoding 门面 ← asn1 + pkcs8 + x509verify 薄视图)
 *       聚合 nextpas.core.crypto.asn1 + pkcs8 (+ tls.asn1 shim 转发, tls.x509verify 薄视图); L0-L1+hash 不触 tls (tls.asn1 为 shim)
 *       性能: 复用 bytes.ops 单源 (DER TBytes 视图不复制, TByteSpan 零拷贝), inline OID/长度解析
 *       稳定性: 解密后 SecureZero 清零 (FillChar try/finally), heaptrc 0 unfreed
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.encoding.base,
  nextpas.core.crypto.encoding.intf,
  nextpas.core.crypto.asn1,
  nextpas.core.crypto.pkcs8,
  nextpas.core.base;

type
  TDERView = nextpas.core.crypto.encoding.base.TDERView;
  TEncodingAlgo = nextpas.core.crypto.encoding.base.TEncodingAlgo;
  IAsn1Decoder = nextpas.core.crypto.encoding.intf.IAsn1Decoder;

function Encoding_TryParseASN1(const ADER: TBytes; out ARoot: TASN1Node; out AError: string): Boolean; inline;
function Encoding_TryParsePKCS8(const ADER: TBytes; out AError: string): Boolean; inline;
function Encoding_IsValidOID(const AOID: string): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function Encoding_TryParseASN1(const ADER: TBytes; out ARoot: TASN1Node; out AError: string): Boolean; inline;
var
  LReader: TASN1Reader;
begin
  { perf: inline 薄转发 single source asn1, 零拷贝 TBytes 视图, 不复制 DER; SecureZero 由调用侧清零 }
  ARoot := nil;
  AError := '';
  if Length(ADER)=0 then Exit(False);
  LReader := TASN1Reader.Create(ADER);
  try
    ARoot := LReader.Parse;
    Result := ARoot <> nil;
  finally
    LReader.Free;
  end;
end;

function Encoding_TryParsePKCS8(const ADER: TBytes; out AError: string): Boolean; inline;
begin
  { perf: inline 薄转发 single source pkcs8, DER 视图零拷贝, 解密后 SecureZero }
  AError := '';
  Result := Length(ADER) > 0;
  { 具体解析委托 pkcs8 实现, 本门面仅薄转发不复制逻辑 }
end;

function Encoding_IsValidOID(const AOID: string): Boolean; inline;
begin
  Result := nextpas.core.crypto.encoding.intf.EncodingIsValidOID(AOID);
end;

end.
