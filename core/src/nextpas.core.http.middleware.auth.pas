unit nextpas.core.http.middleware.auth;

{**
 * @desc Server-side authentication middleware. Enforces two credential
 *       channels before the request reaches the handler:
 *         - Authorization: Bearer <token>
 *         - X-API-Key: <key>
 *       Authorization wins when both headers are present.
 *
 *       Acceptance is decided by an injected validator (TAuthValidatorFunc,
 *       typical for DB/tenant-backed key lookup) or by static credential
 *       lists (TAuthOptions.BearerTokens / ApiKeys) compared with
 *       TConstantTime.CompareStrings (constant time on equal-length inputs).
 *       The validator is authoritative over static lists.
 *
 *       Failure semantics:
 *         - 401: credentials missing or malformed (unsupported scheme,
 *                empty token). Response carries WWW-Authenticate challenge(s).
 *         - 403: credentials presented but rejected by validator / static list.
 *
 *       On success the authenticated subject (e.g. key id/scope) is stored in
 *       the request context under AUTH_SUBJECT_KEY, read back with
 *       HttpContextGetString(HttpContextOf(AReq), AUTH_SUBJECT_KEY).
 *       A context bag is attached automatically when none exists (request
 *       must support IHttpRequestWithContext — standard core requests do).
 *
 *       Path prefixes listed in TAuthOptions.SkipPrefixes (matched at
 *       segment boundaries, e.g. /health skips /health and /health/… but not
 *       /healthz) bypass authentication entirely.
 *
 *       Usage:
 *         router.Use(AuthMiddlewareWithValidator(
 *           function(const AReq: IHttpRequest; const AKind: TAuthCredentialKind;
 *                    const ACredential: string): string
 *           begin
 *             // constant-time compare against stored hashes; '' = reject
 *             Result := LookupCredential(AKind, ACredential);
 *           end));
 *       or with static tokens:
 *         LOpts := Default(TAuthOptions);
 *         LOpts.BearerTokens := TStringArray.Create('bootstrap-secret');
 *         router.Use(AuthMiddleware(LOpts));
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

const
  { Context key under which the authenticated subject (key id/scope) is
    stored. Read with HttpContextGetString(HttpContextOf(AReq),
    AUTH_SUBJECT_KEY) from nextpas.core.http.middleware.context. }
  AUTH_SUBJECT_KEY = 'auth_subject';

type
  { Credential channel presented by the client. }
  TAuthCredentialKind = (ackBearer, ackApiKey);

  { Injected credential validator. Receives the request, the credential
    channel and the presented credential; returns the authenticated subject
    (e.g. key id/scope) to authorize, or '' to reject with 403.
    Must not raise. Secrets MUST be compared with
    TConstantTime.CompareStrings / CompareBytes (constant time). }
  TAuthValidatorFunc = reference to function(const AReq: IHttpRequest;
    const AKind: TAuthCredentialKind; const ACredential: string): string;

  TAuthOptions = record
    { Credential validator. Assigned → authoritative for both channels and
      static BearerTokens/ApiKeys are ignored. Nil → static lists required. }
    Validator: TAuthValidatorFunc;
    { Path prefixes exempt from authentication (e.g. '/healthz').
      Matched at path-segment boundary: '/health' skips '/health' and
      '/health/...' but not '/healthz'. '/' skips every path.
      The leading '/' is added when missing. }
    SkipPrefixes: TStringArray;
    { WWW-Authenticate realm on 401. Empty → 'restricted'. }
    Realm: string;
    { Static bearer tokens accepted via Authorization: Bearer, compared in
      constant time. Ignored when Validator is assigned. }
    BearerTokens: TStringArray;
    { Static API keys accepted via X-API-Key, compared in constant time.
      Ignored when Validator is assigned. }
    ApiKeys: TStringArray;
    { 额外 API key 头名（小写）：除默认 x-api-key 外再接受这些头提供
      api-key 通道凭证（如 x-admin-api-key，原版管理面契约）。默认头优先，
      额外头按数组序取首个非空；空 = 仅默认头。 }
    ExtraApiKeyHeaders: TStringArray;
  end;

{** @desc Auth middleware with explicit options. Rejects options without
   any acceptance source (validator or static lists) with EHttpError. }
function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware;

{** @desc Auth middleware driven by an injected validator (default options:
   realm 'restricted', no skip prefixes). }
function AuthMiddlewareWithValidator(
  const AValidator: TAuthValidatorFunc): IHttpMiddleware;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.crypto.constant_time,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.message,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.text.conv;

const
  DEFAULT_REALM = 'restricted';

type
  { Outcome of credential extraction / validation. }
  TAuthDecision = (adAuthorized, adMissing, adMalformed, adRejected);
  TCredentialParse = (cpNone, cpOk, cpMalformed);

  { Instance-scoped auth policy. Each middleware call owns its validator and
    static credential lists, so different routes can have independent rules. }
  TAuthMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FValidator: TAuthValidatorFunc;
    FSkipPrefixes: TStringArray;
    FRealm: string;
    FBearerTokens: TStringArray;
    FApiKeys: TStringArray;
    FExtraApiKeyHeaders: TStringArray;
    function IsSkippedPath(const APath: string): Boolean;
    function ApiKeyChannelEnabled: Boolean;
    function MatchStatic(const ACredential: string;
      const AKind: TAuthCredentialKind): Boolean;
    function Evaluate(const AReq: IHttpRequest;
      out ASubject: string): TAuthDecision;
  public
    constructor Create(const AOptions: TAuthOptions);
    destructor Destroy; override;
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

function PathHasPrefix(const APath, APrefix: string): Boolean;
var
  LLen: SizeInt;
  LI: SizeInt;
begin
  if APrefix = '/' then
    Exit(True);
  LLen := Length(APrefix);
  if Length(APath) < LLen then
    Exit(False);
  for LI := 1 to LLen do
    if APath[LI] <> APrefix[LI] then
      Exit(False);
  Result := (Length(APath) = LLen) or (APath[LLen + 1] = '/');
end;

function ParseCredential(const AReq: IHttpRequest;
  const AExtraApiKeyHeaders: TStringArray;
  out AKind: TAuthCredentialKind; out ACredential: string): TCredentialParse;
var
  LAuth: string;
  LPos: SizeInt;
  LToken: string;
  LI: SizeInt;
begin
  Result := cpNone;
  LAuth := Trim(AReq.GetHeaders.Get('authorization'));
  if LAuth <> '' then
  begin
    LPos := Pos(' ', LAuth);
    if (LPos <= 0) or not SameText(Copy(LAuth, 1, LPos - 1), 'Bearer') then
      Exit(cpMalformed);
    LToken := Trim(Copy(LAuth, LPos + 1, Length(LAuth) - LPos));
    if LToken = '' then
      Exit(cpMalformed);
    AKind := ackBearer;
    ACredential := LToken;
    Exit(cpOk);
  end;

  { No Authorization header: fall back to X-API-Key channel, then any
    configured extra api-key headers (default header wins). }
  LToken := Trim(AReq.GetHeaders.Get('x-api-key'));
  if LToken = '' then
    for LI := 0 to High(AExtraApiKeyHeaders) do
    begin
      LToken := Trim(AReq.GetHeaders.Get(AExtraApiKeyHeaders[LI]));
      if LToken <> '' then
        Break;
    end;
  if LToken = '' then
    Exit(cpNone);
  AKind := ackApiKey;
  ACredential := LToken;
  Result := cpOk;
end;

{ TAuthMiddleware }

constructor TAuthMiddleware.Create(const AOptions: TAuthOptions);
var
  LPrefix: string;
  LI: Int32;
  LCount: Int32;
begin
  inherited Create;
  FValidator := AOptions.Validator;
  FRealm := AOptions.Realm;
  if Trim(FRealm) = '' then
    FRealm := DEFAULT_REALM;
  { Normalize prefixes: add missing leading '/', drop empty entries. }
  LCount := 0;
  SetLength(FSkipPrefixes, Length(AOptions.SkipPrefixes));
  for LI := 0 to High(AOptions.SkipPrefixes) do
  begin
    LPrefix := Trim(AOptions.SkipPrefixes[LI]);
    if LPrefix = '' then
      Continue;
    if LPrefix[1] <> '/' then
      LPrefix := '/' + LPrefix;
    FSkipPrefixes[LCount] := LPrefix;
    Inc(LCount);
  end;
  SetLength(FSkipPrefixes, LCount);
  FBearerTokens := AOptions.BearerTokens;
  FApiKeys := AOptions.ApiKeys;
  FExtraApiKeyHeaders := AOptions.ExtraApiKeyHeaders;
  if (not Assigned(FValidator)) and (Length(FBearerTokens) = 0) and
    (Length(FApiKeys) = 0) then
    raise EHttpError.Create(hekArgument,
      'auth middleware requires a validator or static credentials');
end;

destructor TAuthMiddleware.Destroy;
begin
  FValidator := nil;
  FSkipPrefixes := nil;
  FBearerTokens := nil;
  FApiKeys := nil;
  FExtraApiKeyHeaders := nil;
  inherited Destroy;
end;

function TAuthMiddleware.IsSkippedPath(const APath: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to High(FSkipPrefixes) do
    if PathHasPrefix(APath, FSkipPrefixes[LI]) then
      Exit(True);
  Result := False;
end;

function TAuthMiddleware.ApiKeyChannelEnabled: Boolean;
begin
  if Assigned(FValidator) then
    Exit(True);
  Result := Length(FApiKeys) > 0;
end;

{ Constant-work scan over the whole static list: every entry is compared even
  after a match, so the response timing does not reveal which entry matched. }
function TAuthMiddleware.MatchStatic(const ACredential: string;
  const AKind: TAuthCredentialKind): Boolean;
var
  LList: TStringArray;
  LMatch: Int32;
  LI: Int32;
begin
  if AKind = ackBearer then
    LList := FBearerTokens
  else
    LList := FApiKeys;
  LMatch := 0;
  for LI := 0 to High(LList) do
    LMatch := LMatch or Ord(TConstantTime.CompareStrings(ACredential,
      LList[LI]));
  Result := LMatch <> 0;
end;

function TAuthMiddleware.Evaluate(const AReq: IHttpRequest;
  out ASubject: string): TAuthDecision;
var
  LKind: TAuthCredentialKind;
  LCredential: string;
  LParse: TCredentialParse;
begin
  LParse := ParseCredential(AReq, FExtraApiKeyHeaders, LKind, LCredential);
  if LParse = cpNone then
    Exit(adMissing);
  if LParse = cpMalformed then
    Exit(adMalformed);

  if Assigned(FValidator) then
  begin
    ASubject := FValidator(AReq, LKind, LCredential);
    if ASubject = '' then
      Exit(adRejected);
    Exit(adAuthorized);
  end;

  if not MatchStatic(LCredential, LKind) then
    Exit(adRejected);
  ASubject := LCredential;
  Result := adAuthorized;
end;

function TAuthMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LSubject: string;
    LDecision: TAuthDecision;
    LSkipped: Boolean;
    LWithCtx: IHttpRequestWithContext;
    LCtx: IHttpContext;
    LCreated: Boolean;
    LChallenge: string;
  begin
    { Skipped paths pass through unmodified (no context touch). }
    LSubject := '';
    LSkipped := IsSkippedPath(AReq.GetPath);
    LDecision := adAuthorized;
    if not LSkipped then
      LDecision := Evaluate(AReq, LSubject);

    if LDecision = adAuthorized then
    begin
      LCreated := False;
      if not LSkipped then
      begin
        LWithCtx := nil;
        LCtx := HttpContextOf(AReq);
        if LCtx = nil then
        begin
          if Supports(AReq, IHttpRequestWithContext, LWithCtx) then
          begin
            LCtx := NewHttpContext;
            LWithCtx.SetContext(LCtx);
            LCreated := True;
          end;
        end;
        if LCtx <> nil then
          HttpContextSetString(LCtx, AUTH_SUBJECT_KEY, LSubject);
      end;
      try
        ANext.ServeHTTP(AReq, AW);
      finally
        if LCreated then
          LWithCtx.SetContext(nil);
      end;
      Exit;
    end;

    LChallenge := 'Bearer realm="' + FRealm + '"';
    if ApiKeyChannelEnabled then
      LChallenge := LChallenge + ', ApiKey realm="' + FRealm + '"';
    case LDecision of
      adMissing:
      begin
        AW.GetHeaders.SetHeader('www-authenticate', LChallenge);
        HttpWriteErrorUnauthorized(AW, 'credentials required');
      end;
      adMalformed:
      begin
        AW.GetHeaders.SetHeader('www-authenticate', LChallenge);
        HttpWriteErrorUnauthorized(AW, 'malformed credentials');
      end;
      adRejected:
        HttpWriteErrorForbidden(AW, 'invalid credentials');
    else
      ; { adAuthorized handled by the pass-through branch above }
    end;
  end);
end;

function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware;
begin
  Result := TAuthMiddleware.Create(AOptions);
end;

function AuthMiddlewareWithValidator(
  const AValidator: TAuthValidatorFunc): IHttpMiddleware;
var
  LOpts: TAuthOptions;
begin
  if not Assigned(AValidator) then
    raise EHttpError.Create(hekArgument,
      'auth middleware validator must not be nil');
  LOpts := Default(TAuthOptions);
  LOpts.Validator := AValidator;
  Result := AuthMiddleware(LOpts);
end;

end.