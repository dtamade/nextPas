unit nextpas.core.http.router;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

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
    var
      FTrees: array[THttpMethod] of PRouteNode;
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
    { Test helper — public route lookup }
    function FindRoute(const AMethod: THttpMethod; const APath: string; out AParams: TRouteParams): THttpHandlerFunc;
  end;

function NewRouter: IHttpRouter;

implementation

uses
  nextpas.core.http.message,
  nextpas.core.http.middleware;

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
begin
  for LM := Low(THttpMethod) to High(THttpMethod) do
  begin
    FreeNode(FTrees[LM]);
    FTrees[LM] := nil;
  end;
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
          raise EHttpError.Create('Duplicate wildcard at: ' + APath);
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
    raise EHttpError.Create('Duplicate route: ' + APath);
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
          AParams[High(AParams)].Value := LSeg;
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
        AParams[High(AParams)].Value := Copy(APath, 2, Length(APath) - 1);
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
  if APattern = '' then
    raise EHttpError.Create('Route pattern must not be empty');
  if (Length(APattern) < 1) or (APattern[1] <> '/') then
    raise EHttpError.Create('Route pattern must start with /');
  InsertRoute(FTrees[AMethod], APattern, AHandler);
end;

procedure THttpRouter.Use(const AMiddleware: IHttpMiddleware);
begin
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
  LI: SizeInt;
  LWrapped: IHttpHandler;
  LAllow: string;
begin
  LMethod := AReq.Method;
  LPath := AReq.Url.Path;
  LParams := nil;
  LHandler := MatchNode(FTrees[LMethod], LPath, LParams);
  if LHandler <> nil then
  begin
    if LParams <> nil then
      for LI := 0 to High(LParams) do
        (AReq as THttpRequest).SetPathParam(LParams[LI].Name, LParams[LI].Value);
    if Length(FMiddlewares) > 0 then
    begin
      LWrapped := HandlerFunc(LHandler);
      for LI := High(FMiddlewares) downto 0 do
        LWrapped := FMiddlewares[LI].Wrap(LWrapped);
      LWrapped.ServeHTTP(AReq, AW);
    end
    else
      LHandler(AReq, AW);
    Exit;
  end;

  { Check other methods for 405 }
  LFound := False;
  LAllow := '';
  for LM := Low(THttpMethod) to High(THttpMethod) do
  begin
    if LM = LMethod then
      Continue;
    LParams := nil;
    if MatchNode(FTrees[LM], LPath, LParams) <> nil then
    begin
      LFound := True;
      if LAllow <> '' then LAllow := LAllow + ', ';
      LAllow := LAllow + HttpMethodToStr(LM);
    end;
  end;

  if LFound then
  begin
    AW.Headers.Set_('allow', LAllow);
    AW.WriteHeader(HTTP_STATUS_METHOD_NOT_ALLOWED);
  end
  else
    AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
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
