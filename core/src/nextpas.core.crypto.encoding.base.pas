unit nextpas.core.crypto.encoding.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.encoding.base — 编码/ASN.1/PKCS8 域公共载体 (L2 crypto)
  Owner: crypto. 纯常量/记录, L0-L1+hash, tls.asn1 为 shim 转发. }

interface

const
  ENCODING_ASN1_MAX_DEPTH = 32;
  ENCODING_ASN1_MAX_LENGTH = 16*1024*1024;
  ENCODING_OID_MAX_LEN = 128;
  ENCODING_PKCS8_ITERATIONS = 2048;

type
  TEncodingAlgo = (encASN1DER, encPKCS8, encX509);

  TDERView = record
    Data: Pointer;
    Len: Integer;
    Tag: Byte;
    class function FromBytes(const ABytes: Pointer; ALen: Integer; ATag: Byte): TDERView; static; inline;
  end;

implementation

class function TDERView.FromBytes(const ABytes: Pointer; ALen: Integer; ATag: Byte): TDERView; static; inline;
begin
  Result.Data := ABytes;
  Result.Len := ALen;
  Result.Tag := ATag;
end;

end.
