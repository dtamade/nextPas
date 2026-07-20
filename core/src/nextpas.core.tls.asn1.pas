{ Compatibility shim: ASN.1 lives in nextpas.core.crypto.asn1 }
unit nextpas.core.tls.asn1;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.crypto.asn1;

const
  ASN1_CLASS_UNIVERSAL = nextpas.core.crypto.asn1.ASN1_CLASS_UNIVERSAL;
  ASN1_CLASS_APPLICATION = nextpas.core.crypto.asn1.ASN1_CLASS_APPLICATION;
  ASN1_CLASS_CONTEXT = nextpas.core.crypto.asn1.ASN1_CLASS_CONTEXT;
  ASN1_CLASS_PRIVATE = nextpas.core.crypto.asn1.ASN1_CLASS_PRIVATE;
  ASN1_CLASS_MASK = nextpas.core.crypto.asn1.ASN1_CLASS_MASK;
  ASN1_CONSTRUCTED = nextpas.core.crypto.asn1.ASN1_CONSTRUCTED;
  ASN1_PRIMITIVE = nextpas.core.crypto.asn1.ASN1_PRIMITIVE;
  ASN1_TAG_EOC = nextpas.core.crypto.asn1.ASN1_TAG_EOC;
  ASN1_TAG_BOOLEAN = nextpas.core.crypto.asn1.ASN1_TAG_BOOLEAN;
  ASN1_TAG_INTEGER = nextpas.core.crypto.asn1.ASN1_TAG_INTEGER;
  ASN1_TAG_BIT_STRING = nextpas.core.crypto.asn1.ASN1_TAG_BIT_STRING;
  ASN1_TAG_OCTET_STRING = nextpas.core.crypto.asn1.ASN1_TAG_OCTET_STRING;
  ASN1_TAG_NULL = nextpas.core.crypto.asn1.ASN1_TAG_NULL;
  ASN1_TAG_OID = nextpas.core.crypto.asn1.ASN1_TAG_OID;
  ASN1_TAG_OBJECT_DESCRIPTOR = nextpas.core.crypto.asn1.ASN1_TAG_OBJECT_DESCRIPTOR;
  ASN1_TAG_EXTERNAL = nextpas.core.crypto.asn1.ASN1_TAG_EXTERNAL;
  ASN1_TAG_REAL = nextpas.core.crypto.asn1.ASN1_TAG_REAL;
  ASN1_TAG_ENUMERATED = nextpas.core.crypto.asn1.ASN1_TAG_ENUMERATED;
  ASN1_TAG_EMBEDDED_PDV = nextpas.core.crypto.asn1.ASN1_TAG_EMBEDDED_PDV;
  ASN1_TAG_UTF8STRING = nextpas.core.crypto.asn1.ASN1_TAG_UTF8STRING;
  ASN1_TAG_RELATIVE_OID = nextpas.core.crypto.asn1.ASN1_TAG_RELATIVE_OID;
  ASN1_TAG_TIME = nextpas.core.crypto.asn1.ASN1_TAG_TIME;
  ASN1_TAG_SEQUENCE = nextpas.core.crypto.asn1.ASN1_TAG_SEQUENCE;
  ASN1_TAG_SET = nextpas.core.crypto.asn1.ASN1_TAG_SET;
  ASN1_TAG_NUMERICSTRING = nextpas.core.crypto.asn1.ASN1_TAG_NUMERICSTRING;
  ASN1_TAG_PRINTABLESTRING = nextpas.core.crypto.asn1.ASN1_TAG_PRINTABLESTRING;
  ASN1_TAG_T61STRING = nextpas.core.crypto.asn1.ASN1_TAG_T61STRING;
  ASN1_TAG_VIDEOTEXSTRING = nextpas.core.crypto.asn1.ASN1_TAG_VIDEOTEXSTRING;
  ASN1_TAG_IA5STRING = nextpas.core.crypto.asn1.ASN1_TAG_IA5STRING;
  ASN1_TAG_UTCTIME = nextpas.core.crypto.asn1.ASN1_TAG_UTCTIME;
  ASN1_TAG_GENERALIZEDTIME = nextpas.core.crypto.asn1.ASN1_TAG_GENERALIZEDTIME;
  ASN1_TAG_GRAPHICSTRING = nextpas.core.crypto.asn1.ASN1_TAG_GRAPHICSTRING;
  ASN1_TAG_VISIBLESTRING = nextpas.core.crypto.asn1.ASN1_TAG_VISIBLESTRING;
  ASN1_TAG_GENERALSTRING = nextpas.core.crypto.asn1.ASN1_TAG_GENERALSTRING;
  ASN1_TAG_UNIVERSALSTRING = nextpas.core.crypto.asn1.ASN1_TAG_UNIVERSALSTRING;
  ASN1_TAG_CHARACTERSTRING = nextpas.core.crypto.asn1.ASN1_TAG_CHARACTERSTRING;
  ASN1_TAG_BMPSTRING = nextpas.core.crypto.asn1.ASN1_TAG_BMPSTRING;
  ASN1_TAG_SEQUENCE_OF = nextpas.core.crypto.asn1.ASN1_TAG_SEQUENCE_OF;
  ASN1_TAG_SET_OF = nextpas.core.crypto.asn1.ASN1_TAG_SET_OF;

type
  EASN1Exception = nextpas.core.crypto.asn1.EASN1Exception;
  EASN1ParseException = nextpas.core.crypto.asn1.EASN1ParseException;
  EASN1InvalidDataException = nextpas.core.crypto.asn1.EASN1InvalidDataException;
  TASN1TagClass = nextpas.core.crypto.asn1.TASN1TagClass;
  TASN1Tag = nextpas.core.crypto.asn1.TASN1Tag;
  TASN1Node = nextpas.core.crypto.asn1.TASN1Node;
  TASN1NodeList = nextpas.core.crypto.asn1.TASN1NodeList;
  TASN1Reader = nextpas.core.crypto.asn1.TASN1Reader;
  TASN1Writer = nextpas.core.crypto.asn1.TASN1Writer;

const
  asn1Universal = nextpas.core.crypto.asn1.asn1Universal;
  asn1Application = nextpas.core.crypto.asn1.asn1Application;
  asn1Context = nextpas.core.crypto.asn1.asn1Context;
  asn1Private = nextpas.core.crypto.asn1.asn1Private;

function ParseOID(const AData: TBytes): string; inline;
function EncodeOID(const AOID: string): TBytes; inline;
function OIDToName(const AOID: string): string; inline;
function NameToOID(const AName: string): string; inline;
function TagToString(ATag: Byte): string; inline;

implementation

function ParseOID(const AData: TBytes): string;
begin
  Result := nextpas.core.crypto.asn1.ParseOID(AData);
end;

function EncodeOID(const AOID: string): TBytes;
begin
  Result := nextpas.core.crypto.asn1.EncodeOID(AOID);
end;

function OIDToName(const AOID: string): string;
begin
  Result := nextpas.core.crypto.asn1.OIDToName(AOID);
end;

function NameToOID(const AName: string): string;
begin
  Result := nextpas.core.crypto.asn1.NameToOID(AName);
end;

function TagToString(ATag: Byte): string;
begin
  Result := nextpas.core.crypto.asn1.TagToString(ATag);
end;

end.
