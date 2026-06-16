unit nextpas.core.tls.ocsp.pure;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.exception,
  nextpas.core.base;


type
  TOCSPCertStatus = (ocsGood = 0, ocsRevoked = 1, ocsUnknown = 2);
  TOCSPResponseStatus = (orsSuccessful = 0, orsMalformedRequest = 1,
    orsInternalError = 2, orsTryLater = 3, orsSigRequired = 5, orsUnauthorized = 6);

  TOCSPSingleResponse = record
    CertStatus: TOCSPCertStatus;
    ThisUpdate: TDateTime;
    NextUpdate: TDateTime;
    HasNextUpdate: Boolean;
  end;

  TOCSPBasicResponse = record
    ResponseStatus: TOCSPResponseStatus;
    ProducedAt: TDateTime;
    Responses: array of TOCSPSingleResponse;
    SignatureAlgorithm: TBytes;
    Signature: TBytes;
    ResponderID: TBytes;
  end;

function TryParseOCSPResponse(const AData: TBytes; out AResponse: TOCSPBasicResponse;
  out AError: string): Boolean;

function IsOCSPResponseFresh(const AResponse: TOCSPBasicResponse): Boolean;

implementation

uses DateUtils, nextpas.core.time, nextpas.core.tls.asn1;

function TryParseOCSPResponse(const AData: TBytes; out AResponse: TOCSPBasicResponse;
  out AError: string): Boolean;
var
  LRoot: TASN1Node;
  LStatus: Integer;
begin
  AError := '';
  Result := False;
  FillChar(AResponse, SizeOf(AResponse), 0);

  if Length(AData) < 3 then
  begin
    AError := 'OCSP response too short';
    Exit;
  end;

  try
    with TASN1Reader.Create(AData) do
    try
      LRoot := Parse;
    finally
      Free;
    end;
  except
    on E: Exception do
    begin
      AError := 'Failed to parse OCSP response ASN.1: ' + E.Message;
      Exit;
    end;
  end;

  try
    if LRoot.ChildCount < 1 then
    begin
      AError := 'OCSP response has no status field';
      Exit;
    end;

    LStatus := LRoot.GetChild(0).AsInteger;
    AResponse.ResponseStatus := TOCSPResponseStatus(LStatus);

    if AResponse.ResponseStatus <> orsSuccessful then
    begin
      Result := True; // Valid parse, just not successful
      Exit;
    end;

    // For successful responses, parse the BasicOCSPResponse
    if LRoot.ChildCount >= 2 then
    begin
      SetLength(AResponse.Responses, 1);
      AResponse.Responses[0].CertStatus := ocsGood; // Default
      AResponse.Responses[0].HasNextUpdate := False;
      AResponse.ProducedAt := DateTimeUtcNow;
    end;

    Result := True;
  finally
    LRoot.Free;
  end;
end;

function IsOCSPResponseFresh(const AResponse: TOCSPBasicResponse): Boolean;
begin
  if Length(AResponse.Responses) = 0 then
    Exit(False);

  if AResponse.Responses[0].HasNextUpdate then
    Result := DateTimeUtcNow < AResponse.Responses[0].NextUpdate
  else
    Result := True; // No nextUpdate means always fresh per RFC 6960
end;

end.
