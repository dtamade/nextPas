{**
 * nextpas.core.tls.dane.ldns - ldns DNSSEC library bindings (stub)
 *
 * Minimal type declarations and function stubs for ldns/DANE support.
 * All functions return failure/empty results until real implementation is provided.
 *
 * @since 2026-06-29
 *}
unit nextpas.core.tls.dane.ldns;

{$mode objfpc}{$H+}

interface

uses nextpas.core.base;

const
  LDNS_RR_TYPE_TLSA = 52;

type
  TDNSSECStatus = (
    dnssecIndeterminate = 0,
    dnssecInsecure = 1,
    dnssecSecure = 2,
    dnssecBogus = 3
  );

  TLdnsTLSARecord = record
    Usage: Byte;
    Selector: Byte;
    MatchingType: Byte;
    TTL: Integer;
    CertData: TBytes;
  end;

  TLdnsTLSARecordArray = array of TLdnsTLSARecord;

function IsLdnsLoaded: Boolean;
function LoadLdns: Boolean;
function QueryDNSTLSA(const ADomain: string; APort: Word;
  const AProtocol: string; out ARecords: TLdnsTLSARecordArray;
  out AStatus: TDNSSECStatus): Boolean;
function DNSSECStatusToStr(AStatus: TDNSSECStatus): string;
function VerifyDNSSECChain(const ADomain: string; ARrtype: Word): TDNSSECStatus;

implementation

function IsLdnsLoaded: Boolean;
begin
  Result := False;
end;

function LoadLdns: Boolean;
begin
  Result := False;
end;

function QueryDNSTLSA(const ADomain: string; APort: Word;
  const AProtocol: string; out ARecords: TLdnsTLSARecordArray;
  out AStatus: TDNSSECStatus): Boolean;
begin
  ARecords := nil;
  AStatus := dnssecIndeterminate;
  Result := False;
end;

function DNSSECStatusToStr(AStatus: TDNSSECStatus): string;
begin
  case AStatus of
    dnssecIndeterminate: Result := 'Indeterminate';
    dnssecInsecure:      Result := 'Insecure';
    dnssecSecure:        Result := 'Secure';
    dnssecBogus:         Result := 'Bogus';
  else
    Result := 'Unknown';
  end;
end;

function VerifyDNSSECChain(const ADomain: string; ARrtype: Word): TDNSSECStatus;
begin
  Result := dnssecIndeterminate;
end;

end.
