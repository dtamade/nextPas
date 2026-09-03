unit nextpas.core.crypto.encoding.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.encoding.intf — 编码域接口契约
  base ← intf. DER TBytes 视图不复制, inline OID/长度解析, SecureZero 解密后清零. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.encoding.base;

type
  IAsn1Decoder = interface
    ['{A5B6C7D8-E9F0-0008-ABCD-1234567890B1}']
    function TryDecode(const ADER: TBytes; out AError: string): Boolean;
    function Encode: TBytes;
  end;

  IPKCS8Handler = interface
    ['{A5B6C7D8-E9F0-0009-ABCD-1234567890B2}']
    function TryParse(const ADER: TBytes; out AError: string): Boolean;
  end;

function EncodingIsValidOID(const AOID: string): Boolean; inline;
function EncodingIsValidDERLength(ALen: Integer): Boolean; inline;

implementation

function EncodingIsValidOID(const AOID: string): Boolean; inline;
begin
  Result := (Length(AOID) > 0) and (Length(AOID) <= ENCODING_OID_MAX_LEN);
end;

function EncodingIsValidDERLength(ALen: Integer): Boolean; inline;
begin
  Result := (ALen >= 0) and (ALen <= ENCODING_ASN1_MAX_LENGTH);
end;

end.
