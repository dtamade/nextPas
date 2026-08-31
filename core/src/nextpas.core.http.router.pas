unit nextpas.core.http.router;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.regex;

type
  TRouteParam = record
    Name: string;
    Value: string;
  end;
  TRouteParams = array of TRouteParam;

  THttpRouter = class(TInterfacedObject, IHttpRouter, IHttpHandler)
  private
    type
      TNodeKind = (nkStatic, nkParam, nkWildcard);
      PRouteNode = ^TRouteNode;
      TRouteNode = record
        Prefix: string;
        Kind: TNodeKind;
        ParamName: string;
        Children: array of PRouteNode;
        Handler: THttpHandlerFunc;
        HasHandler: Boolean;
      end;
      TRegexRouteEntry = record
        Pattern: string;
        Regex: TRegex;
        Handler: THttpHandlerFunc;
      end;
    var
      FTrees: array[THttpMethod] of PRouteNode;
      FRegexRoutes: array[THttpMethod] of array of TRegexRouteEntry;
      FMiddlewares: array of IHttpMiddleware;
    function NewNode(const APrefix: string; const AKind: TNodeKind): PRouteNode;
    procedure FreeNode(ANode: PRouteNode);
    procedure InsertRoute(var ARoot: PRouteNode; const APath: string; const AHandler: THttpHandlerFunc);
    function MatchNode(ANode: PRouteNode; const APath: string; var AParams: TRouteParams): THttpHandlerFunc;
  public
    constructor Create;
    destructor Destroy; override;
    { IHttpRouter }
    procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure HandleRegex(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
    { IHttpHandler }
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
    { Convenience }
    procedure Get(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Head(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Patch(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Options(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Connect(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Trace(const APattern: string; const AHandler: THttpHandlerFunc);
    { Regex route convenience }
    procedure GetRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PostRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PutRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure DeleteRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PatchRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    { Test helper — public route lookup }
    function FindRoute(const AMethod: THttpMethod; const APath: string; out AParams: TRouteParams): THttpHandlerFunc;
  end;

function NewRouter: IHttpRouter;

{ 路径模式匹配（独立判定原语，与 THttpRouter 消费语义同源：nkParam 单段非空、
  nkWildcard 剩余可空）。按 '/'-分段比较——':xxx' 段通配单个非空段；'*xxx' 段
  （段首 '*'）通配剩余全部段（含空，须为末段，其后段无意义）；静态段逐字相等；
  无通配时 pattern 与 path 段数必须相等。连续 '/' 折叠、首尾 '/' 忽略（等价
  请求路径规范化）；空 pattern 只匹配空 path。 }
function MatchPathPattern(const APattern, APath: string): Boolean;

implementation

uses
  nextpas.core.encoding,
  nextpas.core.http.message,
  nextpas.core.http.middleware;

const
  MAX_ROUTE_SEGMENTS = 64;

{ Helpers }

function CommonPrefixLen(const A, B: string): SizeInt;
var
  LMax: SizeInt;
  I: SizeInt;
begin
  LMax := Length(A);
  if Length(B) < LMax then
    LMax := Length(B);
  Result := 0;
  for I := 1 to LMax do
  begin
    if A[I] <> B[I] then
      Exit;
    Inc(Result);
  end;
end;

{ MatchPathPattern: 单趟双指针扫描，语义与 token888 侧使用方对齐
  （连续 '/' 折叠 → 段必然非空；'*' 段即返回 True → nkWildcard consumes rest
  可空；无 '*' 时段数须相等）。零分配（仅静态段比较时 Copy 单段）。 }
function MatchPathPattern(const APattern, APath: string): Boolean;
var
  LP, LE: SizeInt; { pattern 当前段起止（LE 指向段后 '/' 或串尾） }
  LQ, LF: SizeInt; { path 当前段起止 }
begin
  Result := False;
  if (APattern = '') or (APath = '') then
    Exit(APattern = APath);

  LP := 1;
  LQ := 1;
  while LP <= Length(APattern) do
  begin
    { pattern 段首：折叠前导 '/' }
    while (LP <= Length(APattern)) and (APattern[LP] = '/') do
      Inc(LP);
    if LP > Length(APattern) then
      Break;
    LE := LP;
    while (LE <= Length(APattern)) and (APattern[LE] <> '/') do
      Inc(LE);

    { '*xxx' 段：匹配剩余全部（可空）——其后段无意义 }
    if APattern[LP] = '*' then
      Exit(True);

    { path 需有当前段（折叠前导 '/'，段非空） }
    while (LQ <= Length(APath)) and (APath[LQ] = '/') do
      Inc(LQ);
    if LQ > Length(APath) then
      Exit;
    LF := LQ;
    while (LF <= Length(APath)) and (APath[LF] <> '/') do
      Inc(LF);

    { ':xxx' 单段通配；静态段逐字相等 }
    if (APattern[LP] <> ':') and
       (Copy(APattern, LP, LE - LP) <> Copy(APath, LQ, LF - LQ)) then
      Exit;

    { 推进到下一段 }
    LP := LE;
    LQ := LF;
  end;

  { path 剩余段：折叠 '/' 后必须空 }
  while (LQ <= Length(APath)) and (APath[LQ] = '/') do
    Inc(LQ);
  Result := LQ > Length(APath);
end;

{ Normalize request path: strip trailing slash, collapse duplicate slashes.
  "/" stays as "/".  "/api/users//" → "/api/users". }
function NormalizeRequestPath(const APath: string): string;
var
  LLen: SizeInt;
begin
  if APath = '' then
    Exit('/');
  LLen := Length(APath);
  { Strip trailing slash (but keep root "/" as-is) }
  while (LLen > 1) and (APath[LLen] = '/') do
    Dec(LLen);
  Result := Copy(APath, 1, LLen);
end;

{ THttpRouter }

function THttpRouter.NewNode(const APrefix: string; const AKind: TNodeKind): PRouteNode;
begin
  New(Result);
  Result^.Prefix := APrefix;
  Result^.Kind := AKind;
  Result^.ParamName := '';
  Result^.Children := nil;
  Result^.Handler := nil;
  Result^.HasHandler := False;
end;

procedure THttpRouter.FreeNode(ANode: PRouteNode);
var
  I: SizeInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to High(ANode^.Children) do
    FreeNode(ANode^.Children[I]);
  ANode^.Children := nil;
  ANode^.Handler := nil;
  Dispose(ANode);
end;

constructor THttpRouter.Create;
var
  LM: THttpMethod;
begin
  inherited Create;
  for LM := Low(THttpMethod) to High(THttpMethod) do
    FTrees[LM] := nil;
end;

destructor THttpRouter.Destroy;
var
  LM: THttpMethod;
  LI: SizeInt;
begin
  for LM := Low(THttpMethod) to High(THttpMethod) do
  begin
    FreeNode(FTrees[LM]);
    FTrees[LM] := nil;
    for LI := 0 to High(FRegexRoutes[LM]) do
    begin
      FRegexRoutes[LM][LI].Regex.Free;
      FRegexRoutes[LM][LI].Handler := nil;
      FRegexRoutes[LM][LI].Pattern := '';
    end;
    SetLength(FRegexRoutes[LM], 0);
  end;
  SetLength(FMiddlewares, 0);
  inherited Destroy;
end;

procedure THttpRouter.InsertRoute(var ARoot: PRouteNode; const APath: string; const AHandler: THttpHandlerFunc);
var
  LSegments: array of string;
  LSegCount: SizeInt;
  LCur: PRouteNode;
  LI, LJ: SizeInt;
  LSeg: string;
  LFound: Boolean;
  LChild: PRouteNode;
  LCommon: SizeInt;
  LSplit: PRouteNode;

  procedure ParseSegments(const AFullPath: string);
  var
    LP, LStart: SizeInt;
  begin
    LSegCount := 0;
    SetLength(LSegments, 16);
    LP := 1;
    while LP <= Length(AFullPath) do
    begin
      if LSegCount >= MAX_ROUTE_SEGMENTS then
        Exit;
      if AFullPath[LP] = '/' then
      begin
        { Collect the '/' plus the following segment text }
        LStart := LP;
        Inc(LP);
        while (LP <= Length(AFullPath)) and (AFullPath[LP] <> '/') do
          Inc(LP);
        if LSegCount >= Length(LSegments) then
          SetLength(LSegments, Length(LSegments) * 2);
        LSegments[LSegCount] := Copy(AFullPath, LStart, LP - LStart);
        Inc(LSegCount);
      end
      else
      begin
        { Leading text before first '/' (shouldn't happen for well-formed paths) }
        LStart := LP;
        while (LP <= Length(AFullPath)) and (AFullPath[LP] <> '/') do
          Inc(LP);
        if LSegCount >= Length(LSegments) then
          SetLength(LSegments, Length(LSegments) * 2);
        LSegments[LSegCount] := Copy(AFullPath, LStart, LP - LStart);
        Inc(LSegCount);
      end;
    end;
    SetLength(LSegments, LSegCount);
  end;

begin
  LSegCount := 0;
  LSegments := nil;
  if ARoot = nil then
    ARoot := NewNode('', nkStatic);

  ParseSegments(APath);

  LCur := ARoot;
  LI := 0;
  while LI < LSegCount do
  begin
    LSeg := LSegments[LI];

    { Check if this is a param segment: /: }
    if (Length(LSeg) >= 2) and (LSeg[1] = '/') and (LSeg[2] = ':') then
    begin
      { Param node }
      LFound := False;
      for LJ := 0 to High(LCur^.Children) do
      begin
        if LCur^.Children[LJ]^.Kind = nkParam then
        begin
          LCur := LCur^.Children[LJ];
          LFound := True;
          Break;
        end;
      end;
      if not LFound then
      begin
        LChild := NewNode('', nkParam);
        LChild^.ParamName := Copy(LSeg, 3, Length(LSeg) - 2);
        SetLength(LCur^.Children, Length(LCur^.Children) + 1);
        LCur^.Children[High(LCur^.Children)] := LChild;
        LCur := LChild;
      end;
      Inc(LI);
      Continue;
    end;

    { Check if this is a wildcard segment: /* }
    if (Length(LSeg) >= 2) and (LSeg[1] = '/') and (LSeg[2] = '*') then
    begin
      { Check for existing wildcard at this level }
      for LJ := 0 to High(LCur^.Children) do
        if LCur^.Children[LJ]^.Kind = nkWildcard then
          raise EHttpError.Create(hekArgument, 'Duplicate wildcard at: ' + APath);
      LChild := NewNode('', nkWildcard);
      LChild^.ParamName := Copy(LSeg, 3, Length(LSeg) - 2);
      SetLength(LCur^.Children, Length(LCur^.Children) + 1);
      LCur^.Children[High(LCur^.Children)] := LChild;
      LCur := LChild;
      { Wildcard consumes rest — assign handler here }
      Break;
    end;

    { Static segment — radix insert }
    LFound := False;
    for LJ := 0 to High(LCur^.Children) do
    begin
      if LCur^.Children[LJ]^.Kind <> nkStatic then
        Continue;
      LCommon := CommonPrefixLen(LCur^.Children[LJ]^.Prefix, LSeg);
      if LCommon = 0 then
        Continue;

      if LCommon = Length(LCur^.Children[LJ]^.Prefix) then
      begin
        { Full match of existing node prefix }
        if LCommon = Length(LSeg) then
        begin
          { Exact match — descend }
          LCur := LCur^.Children[LJ];
          LFound := True;
          Break;
        end
        else
        begin
          { Remaining part of segment — update LSeg and descend }
          LSeg := Copy(LSeg, LCommon + 1, Length(LSeg) - LCommon);
          LSegments[LI] := LSeg;
          LCur := LCur^.Children[LJ];
          LFound := True;
          Dec(LI); { Re-process this index with updated segment }
          Break;
        end;
      end
      else
      begin
        { Partial match — split the existing node }
        LSplit := NewNode(Copy(LCur^.Children[LJ]^.Prefix, 1, LCommon), nkStatic);
        LSplit^.Children := nil;

        { Shorten existing node }
        LCur^.Children[LJ]^.Prefix := Copy(LCur^.Children[LJ]^.Prefix, LCommon + 1,
          Length(LCur^.Children[LJ]^.Prefix) - LCommon);

        { Old node becomes child of split }
        SetLength(LSplit^.Children, 1);
        LSplit^.Children[0] := LCur^.Children[LJ];

        { Replace in parent }
        LCur^.Children[LJ] := LSplit;

        { Now insert remaining part of our segment }
        if LCommon < Length(LSeg) then
        begin
          LChild := NewNode(Copy(LSeg, LCommon + 1, Length(LSeg) - LCommon), nkStatic);
          SetLength(LSplit^.Children, Length(LSplit^.Children) + 1);
          LSplit^.Children[High(LSplit^.Children)] := LChild;
          LCur := LChild;
        end
        else
        begin
          { Our segment exactly matches the common prefix }
          LCur := LSplit;
        end;
        LFound := True;
        Break;
      end;
    end;

    if not LFound then
    begin
      { No matching child — create new static node }
      LChild := NewNode(LSeg, nkStatic);
      SetLength(LCur^.Children, Length(LCur^.Children) + 1);
      LCur^.Children[High(LCur^.Children)] := LChild;
      LCur := LChild;
    end;

    Inc(LI);
  end;

  { Assign handler }
  if LCur^.HasHandler then
    raise EHttpError.Create(hekArgument, 'Duplicate route: ' + APath);
  LCur^.Handler := AHandler;
  LCur^.HasHandler := True;
end;

function THttpRouter.MatchNode(ANode: PRouteNode; const APath: string; var AParams: TRouteParams): THttpHandlerFunc;
const
  MAX_MATCH_DEPTH = 128;

  function DoMatch(ANode: PRouteNode; const APath: string; ADepth: Int32): THttpHandlerFunc;
  var
    LPos, LEnd: SizeInt;
    LSeg: string;
    LI: SizeInt;
    LCommon: SizeInt;
    LRest: string;
    LResult: THttpHandlerFunc;
  begin
    Result := nil;
    if (ANode = nil) or (ADepth > MAX_MATCH_DEPTH) then
      Exit;

    if APath = '' then
    begin
      if ANode^.HasHandler then
        Result := ANode^.Handler;
      Exit;
    end;

    for LI := 0 to High(ANode^.Children) do
    begin
      if ANode^.Children[LI]^.Kind <> nkStatic then
        Continue;
      LCommon := CommonPrefixLen(ANode^.Children[LI]^.Prefix, APath);
      if LCommon = Length(ANode^.Children[LI]^.Prefix) then
      begin
        LRest := Copy(APath, LCommon + 1, Length(APath) - LCommon);
        LResult := DoMatch(ANode^.Children[LI], LRest, ADepth + 1);
        if LResult <> nil then
          Exit(LResult);
      end;
    end;

    for LI := 0 to High(ANode^.Children) do
    begin
      if ANode^.Children[LI]^.Kind <> nkParam then
        Continue;
      if (Length(APath) >= 1) and (APath[1] = '/') then
      begin
        LPos := 2;
        LEnd := LPos;
        while (LEnd <= Length(APath)) and (APath[LEnd] <> '/') do
          Inc(LEnd);
        LSeg := Copy(APath, LPos, LEnd - LPos);
        if LSeg <> '' then
        begin
          SetLength(AParams, Length(AParams) + 1);
          AParams[High(AParams)].Name := ANode^.Children[LI]^.ParamName;
          { 路径参数按 RFC 3986 percent-decode（%xx → 原字符；如邮箱地址
            客户端 encodeURIComponent 后 %40）。段内解码不改 '/' 拆分语义，
            '+' 保持字面（PercentDecode 为 path 语义，非 form 语义）。 }
          AParams[High(AParams)].Value := PercentDecode(LSeg);
          LRest := Copy(APath, LEnd, Length(APath) - LEnd + 1);
          LResult := DoMatch(ANode^.Children[LI], LRest, ADepth + 1);
          if LResult <> nil then
            Exit(LResult);
          SetLength(AParams, Length(AParams) - 1);
        end;
      end;
    end;

    for LI := 0 to High(ANode^.Children) do
    begin
      if ANode^.Children[LI]^.Kind <> nkWildcard then
        Continue;
      if (Length(APath) >= 1) and (APath[1] = '/') then
      begin
        SetLength(AParams, Length(AParams) + 1);
        AParams[High(AParams)].Name := ANode^.Children[LI]^.ParamName;
        AParams[High(AParams)].Value := PercentDecode(
          Copy(APath, 2, Length(APath) - 1));
        if ANode^.Children[LI]^.HasHandler then
          Exit(ANode^.Children[LI]^.Handler);
        SetLength(AParams, Length(AParams) - 1);
      end;
    end;
  end;

begin
  Result := DoMatch(ANode, APath, 0);
end;

procedure THttpRouter.Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
begin
  if not Assigned(AHandler) then
    raise EHttpError.Create(hekArgument, 'Route handler must not be nil');
  if APattern = '' then
    raise EHttpError.Create(hekArgument, 'Route pattern must not be empty');
  if (Length(APattern) < 1) or (APattern[1] <> '/') then
    raise EHttpError.Create(hekArgument, 'Route pattern must start with /');
  InsertRoute(FTrees[AMethod], APattern, AHandler);
end;

procedure THttpRouter.HandleRegex(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
var
  LLen: SizeInt;
  LEntry: TRegexRouteEntry;
  LError: string;
begin
  if not Assigned(AHandler) then
    raise EHttpError.Create(hekArgument, 'Route handler must not be nil');
  if APattern = '' then
    raise EHttpError.Create(hekArgument, 'Route pattern must not be empty');
  if (Length(APattern) < 1) or (APattern[1] <> '/') then
    raise EHttpError.Create(hekArgument, 'Route pattern must start with /');
  if not TRegex.TryCompile(APattern, LEntry.Regex, LError) then
    raise EHttpError.Create(hekArgument, 'Invalid regex route pattern: ' + LError);
  LEntry.Pattern := APattern;
  LEntry.Handler := AHandler;
  LLen := Length(FRegexRoutes[AMethod]);
  SetLength(FRegexRoutes[AMethod], LLen + 1);
  FRegexRoutes[AMethod][LLen] := LEntry;
end;

procedure THttpRouter.Use(const AMiddleware: IHttpMiddleware);
begin
  if AMiddleware = nil then
    raise EHttpError.Create(hekArgument, 'Route middleware must not be nil');
  SetLength(FMiddlewares, Length(FMiddlewares) + 1);
  FMiddlewares[High(FMiddlewares)] := AMiddleware;
end;

procedure THttpRouter.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
var
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
  LMethod: THttpMethod;
  LPath: string;
  LM: THttpMethod;
  LFound: Boolean;
  LAllow: string;
  LTerminal: THttpHandlerFunc;

  procedure InvokeHandler(const AHandler: THttpHandlerFunc;
    const AParams: TRouteParams);
  var
    LParamIndex: SizeInt;
    LWrappedHandler: IHttpHandler;
  begin
    if AParams <> nil then
      for LParamIndex := 0 to High(AParams) do
        (AReq as THttpRequest).SetPathParam(AParams[LParamIndex].Name,
          AParams[LParamIndex].Value);
    if Length(FMiddlewares) > 0 then
    begin
      LWrappedHandler := HandlerFunc(AHandler);
      for LParamIndex := High(FMiddlewares) downto 0 do
        LWrappedHandler := FMiddlewares[LParamIndex].Wrap(LWrappedHandler);
      LWrappedHandler.ServeHTTP(AReq, AW);
    end
    else
      AHandler(AReq, AW);
  end;

  procedure AppendAllowedMethod(const AMethod: THttpMethod);
  begin
    if LAllow <> '' then
      LAllow := LAllow + ', ';
    LAllow := LAllow + HttpMethodToStr(AMethod);
  end;

  function MatchRegexRoute(AMethod: THttpMethod): THttpHandlerFunc;
  var
    LI: SizeInt;
  begin
    Result := nil;
    for LI := 0 to High(FRegexRoutes[AMethod]) do
    begin
      if FRegexRoutes[AMethod][LI].Regex.IsMatch(LPath) then
        Exit(FRegexRoutes[AMethod][LI].Handler);
    end;
  end;

  function HasRouteFor(const AMethod: THttpMethod): Boolean;
  var
    LRouteParams: TRouteParams;
    LI: SizeInt;
  begin
    LRouteParams := nil;
    if MatchNode(FTrees[AMethod], LPath, LRouteParams) <> nil then
      Exit(True);
    for LI := 0 to High(FRegexRoutes[AMethod]) do
      if FRegexRoutes[AMethod][LI].Regex.IsMatch(LPath) then
        Exit(True);
    Result := False;
  end;
begin
  LMethod := AReq.Method;
  LPath := NormalizeRequestPath(AReq.Path);
  LParams := nil;
  LHandler := MatchNode(FTrees[LMethod], LPath, LParams);
  if LHandler <> nil then
  begin
    InvokeHandler(LHandler, LParams);
    Exit;
  end;

  { Check regex routes for primary method }
  LHandler := MatchRegexRoute(LMethod);
  if LHandler <> nil then
  begin
    InvokeHandler(LHandler, LParams);
    Exit;
  end;

  if LMethod = hmHead then
  begin
    LParams := nil;
    LHandler := MatchNode(FTrees[hmGet], LPath, LParams);
    if LHandler <> nil then
    begin
      InvokeHandler(LHandler, LParams);
      Exit;
    end;
    LHandler := MatchRegexRoute(hmGet);
    if LHandler <> nil then
    begin
      InvokeHandler(LHandler, LParams);
      Exit;
    end;
  end;

  LFound := False;
  LAllow := '';
  for LM := Low(THttpMethod) to High(THttpMethod) do
  begin
    if LM = LMethod then
      Continue;
    if HasRouteFor(LM) then
    begin
      LFound := True;
      AppendAllowedMethod(LM);
      if (LM = hmGet) and (LMethod <> hmHead) and (not HasRouteFor(hmHead)) then
        AppendAllowedMethod(hmHead);
    end;
  end;

  if LFound then
  begin
    { Not-found and method-not-allowed responses are terminal handlers that
      run through the same middleware chain as matched routes: middleware is
      a global request chain (recovery/metrics/headers/CORS-preflight apply
      to every response, including 404/405). Status, Allow and problem body
      are untouched. }
    LTerminal := procedure(const AR: IHttpRequest;
      const RW: IHttpResponseWriter)
      begin
        RW.Headers.SetHeader('allow', LAllow);
        HttpWriteErrorResponse(RW, HTTP_STATUS_METHOD_NOT_ALLOWED,
          'method_not_allowed', 'Method not allowed');
      end;
  end
  else
    LTerminal := procedure(const AR: IHttpRequest;
      const RW: IHttpResponseWriter)
      begin
        HttpWriteErrorNotFound(RW, 'Route not found');
      end;
  InvokeHandler(LTerminal, nil);
end;

procedure THttpRouter.Get(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmGet, APattern, AHandler);
end;

procedure THttpRouter.Head(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmHead, APattern, AHandler);
end;

procedure THttpRouter.Post(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPost, APattern, AHandler);
end;

procedure THttpRouter.Put(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPut, APattern, AHandler);
end;

procedure THttpRouter.Delete(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmDelete, APattern, AHandler);
end;

procedure THttpRouter.Patch(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPatch, APattern, AHandler);
end;

procedure THttpRouter.Options(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmOptions, APattern, AHandler);
end;

procedure THttpRouter.Connect(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmConnect, APattern, AHandler);
end;

procedure THttpRouter.Trace(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmTrace, APattern, AHandler);
end;

procedure THttpRouter.GetRegex(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  HandleRegex(hmGet, APattern, AHandler);
end;

procedure THttpRouter.PostRegex(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  HandleRegex(hmPost, APattern, AHandler);
end;

procedure THttpRouter.PutRegex(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  HandleRegex(hmPut, APattern, AHandler);
end;

procedure THttpRouter.DeleteRegex(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  HandleRegex(hmDelete, APattern, AHandler);
end;

procedure THttpRouter.PatchRegex(const APattern: string; const AHandler: THttpHandlerFunc);
begin
  HandleRegex(hmPatch, APattern, AHandler);
end;

function THttpRouter.FindRoute(const AMethod: THttpMethod; const APath: string; out AParams: TRouteParams): THttpHandlerFunc;
begin
  AParams := nil;
  Result := MatchNode(FTrees[AMethod], APath, AParams);
end;

function NewRouter: IHttpRouter;
begin
  Result := THttpRouter.Create;
end;

end.
