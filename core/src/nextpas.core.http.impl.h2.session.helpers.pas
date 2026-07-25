unit nextpas.core.http.impl.h2.session.helpers;
{**
 * @desc Pure H2 server-session helpers (no session state).
 *       Mechanical extract from impl.h2.session (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.impl.h2.types;

function EffectiveMaxConcurrentStreams(const ASettings: TH2Settings): UInt32;
function AnsiToString(const AValue: AnsiString): string; inline;
function StringToAnsi(const AValue: string): AnsiString; inline;
function StatusHeaderValue(const AStatus: THttpStatus): string; inline;
function HttpMethodFromPseudo(const AValue: string): THttpMethod;
function ResponseStatusMustNotHaveBody(const AStatus: THttpStatus): Boolean;

implementation

uses
  nextpas.core.text.conv;

{ RFC 9113 §6.5.2: SETTINGS_MAX_CONCURRENT_STREAMS default is 100.
  A value of 0 means "not advertised" and should use the RFC default. }
function EffectiveMaxConcurrentStreams(const ASettings: TH2Settings): UInt32;
begin
  if ASettings.MaxConcurrentStreams = 0 then
    Result := 100
  else
    Result := ASettings.MaxConcurrentStreams;
end;

function AnsiToString(const AValue: AnsiString): string; inline;
begin
  Result := string(AValue);
end;

function StringToAnsi(const AValue: string): AnsiString; inline;
begin
  Result := AnsiString(AValue);
end;

function StatusHeaderValue(const AStatus: THttpStatus): string; inline;
begin
  Result := IntToStr(Int64(AStatus));
end;

function HttpMethodFromPseudo(const AValue: string): THttpMethod;
begin
  Result := HttpStrToMethod(AValue);
end;

function ResponseStatusMustNotHaveBody(const AStatus: THttpStatus): Boolean;
begin
  Result := HttpStatusIsInformational(AStatus) or
    (AStatus = HTTP_STATUS_NO_CONTENT) or
    (AStatus = HTTP_STATUS_NOT_MODIFIED) or
    (AStatus = HTTP_STATUS_RESET_CONTENT);
end;

end.