unit nextpas.core.http.impl.h2.session.request;
{**
 * @desc Pure-ish H2 server request assembly from stream headers/body.
 *       Mechanical extract from impl.h2.session (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.stream;

function H2ExtractPseudoHeader(const AHeaders: IHttpHeaders;
  const AName: string): string;
function H2BuildRequestFromStream(const AStream: TH2Stream;
  const ARemoteAddr: TNetAddress): IHttpRequest;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.session.helpers;

function H2ExtractPseudoHeader(const AHeaders: IHttpHeaders;
  const AName: string): string;
var
  LFound: string;
begin
  if AHeaders = nil then
    Exit('');
  LFound := '';
  AHeaders.ForEach(
    procedure(const AHeaderName, AHeaderValue: string)
    begin
      if AHeaderName = AName then
        LFound := AHeaderValue;
    end);
  Result := LFound;
end;

function H2BuildRequestFromStream(const AStream: TH2Stream;
  const ARemoteAddr: TNetAddress): IHttpRequest;
var
  LOriginalHeaders: IHttpHeaders;
  LHeaders: IHttpHeaders;
  LMethod: THttpMethod;
  LPath: string;
  LAuthority: string;
  LRequest: THttpRequest;
  LBody: IH2BodyReader;
begin
  LOriginalHeaders := AStream.Headers;
  if LOriginalHeaders = nil then
    raise EHttpError.Create(hekProtocol, 'h2 stream missing headers');
  LMethod := HttpMethodFromPseudo(H2ExtractPseudoHeader(LOriginalHeaders, ':method'));
  LPath := H2ExtractPseudoHeader(LOriginalHeaders, ':path');
  LAuthority := H2ExtractPseudoHeader(LOriginalHeaders, ':authority');
  if LPath = '' then
    LPath := '/';
  LBody := AStream.CreateBodyReader;
  LHeaders := NewHttpHeaders;
  LOriginalHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if (AName <> '') and (AName[1] = ':') then
        Exit;
      LHeaders.Add(AName, AValue);
    end);
  if LAuthority <> '' then
    LHeaders.SetHeader('host', LAuthority);
  { RFC 9113 §8.1.2.3: :scheme is informational; never trust it for
    x-forwarded-proto since clients can set it to 'https' over cleartext.
    Only a trusted reverse proxy should inject x-forwarded-proto. }
  LRequest := THttpRequest.CreateFromRequestTarget(LMethod, LPath, hvHttp2,
    LHeaders, LBody, Int64(Length(AStream.BodyBuffer)));
  if AStream.Trailers <> nil then
    LRequest.SetTrailers(AStream.Trailers.Clone);
  LRequest.SetRemoteNetAddr(ARemoteAddr);
  Result := LRequest;
end;

end.