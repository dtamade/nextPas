program test_http_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers;

var
  T: TTestRunner;

procedure TestSetAndGetBasic;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('Content-Type', 'text/html');
  CheckEqual('text/html', LH.Get('Content-Type'), 'set then get');
end;

procedure TestCaseInsensitiveLookup;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('Content-Type', 'application/json');
  CheckEqual('application/json', LH.Get('content-type'), 'lowercase lookup');
  CheckEqual('application/json', LH.Get('CONTENT-TYPE'), 'uppercase lookup');
  CheckEqual('application/json', LH.Get('Content-type'), 'mixed lookup');
end;

procedure TestAddMultipleValues;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Add('Set-Cookie', 'a=1');
  LH.Add('Set-Cookie', 'b=2');
  CheckEqual(Int64(2), Int64(LH.Count), 'count after two adds');
  CheckEqual('a=1', LH.Get('Set-Cookie'), 'get returns first');
end;

procedure TestGetAllReturnsAllValues;
var
  LH: IHttpHeaders;
  LAll: TStringArray;
begin
  LH := NewHttpHeaders;
  LH.Add('Set-Cookie', 'a=1');
  LH.Add('Set-Cookie', 'b=2');
  LH.Add('Set-Cookie', 'c=3');
  LAll := LH.GetAll('Set-Cookie');
  CheckEqual(Int64(3), Int64(Length(LAll)), 'getall length');
  CheckEqual('a=1', LAll[0], 'first');
  CheckEqual('b=2', LAll[1], 'second');
  CheckEqual('c=3', LAll[2], 'third');
end;

procedure TestSetReplacesExisting;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Add('X-Custom', 'old1');
  LH.Add('X-Custom', 'old2');
  CheckEqual(Int64(2), Int64(LH.Count), 'before set');
  LH.Set_('X-Custom', 'new');
  CheckEqual(Int64(1), Int64(LH.Count), 'after set replaces all');
  CheckEqual('new', LH.Get('X-Custom'), 'new value');
end;

procedure TestDelRemovesAllValues;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Add('X-A', 'v1');
  LH.Add('X-A', 'v2');
  LH.Add('X-B', 'v3');
  CheckEqual(Int64(3), Int64(LH.Count), 'before del');
  LH.Del('X-A');
  CheckEqual(Int64(1), Int64(LH.Count), 'after del');
  Check(not LH.Has('X-A'), 'X-A removed');
  Check(LH.Has('X-B'), 'X-B remains');
end;

procedure TestHasReturnsTrueFalse;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  Check(not LH.Has('X-Missing'), 'missing returns false');
  LH.Set_('X-Present', 'yes');
  Check(LH.Has('X-Present'), 'present returns true');
  Check(LH.Has('x-present'), 'case insensitive has');
  Check(LH.Has('X-PRESENT'), 'uppercase has');
end;

procedure TestCountReflectsTotalEntries;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  CheckEqual(Int64(0), Int64(LH.Count), 'empty');
  LH.Add('A', '1');
  LH.Add('B', '2');
  LH.Add('A', '3');
  CheckEqual(Int64(3), Int64(LH.Count), 'total entries not unique names');
end;

procedure TestCloneCreatesIndependentCopy;
var
  LH, LClone: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('Host', 'example.com');
  LH.Add('Accept', 'text/html');
  LClone := LH.Clone;
  // Verify clone has same data
  CheckEqual('example.com', LClone.Get('Host'), 'clone has host');
  CheckEqual(Int64(2), Int64(LClone.Count), 'clone count');
  // Modify original, clone unaffected
  LH.Del('Host');
  CheckEqual('example.com', LClone.Get('Host'), 'clone independent');
  CheckEqual(Int64(2), Int64(LClone.Count), 'clone count unchanged');
end;

procedure TestGetReturnEmptyForMissing;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  CheckEqual('', LH.Get('X-Nothing'), 'missing returns empty');
end;

procedure TestGetAllReturnEmptyForMissing;
var
  LH: IHttpHeaders;
  LAll: TStringArray;
begin
  LH := NewHttpHeaders;
  LAll := LH.GetAll('X-Nothing');
  CheckEqual(Int64(0), Int64(Length(LAll)), 'missing getall returns empty');
end;

procedure TestDelNonExistentIsNoOp;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('X-Keep', 'val');
  LH.Del('X-Gone');
  CheckEqual(Int64(1), Int64(LH.Count), 'del non-existent no-op');
  CheckEqual('val', LH.Get('X-Keep'), 'existing preserved');
end;

procedure TestCompactionPreservesVisibleOrder;
var
  LH, LClone: IHttpHeaders;
  LAll: TStringArray;
  LSeen: string;
begin
  LH := NewHttpHeaders;
  LH.Add('X-A', 'a1');
  LH.Add('X-B', 'b1');
  LH.Add('X-A', 'a2');
  LH.Add('X-C', 'c1');

  LH.Del('X-B');
  LH.Set_('X-A', 'a3');
  LH.Add('X-D', 'd1');

  CheckEqual(Int64(3), Int64(LH.Count), 'count after del/set/add');
  LAll := LH.GetAll('X-A');
  CheckEqual(Int64(1), Int64(Length(LAll)), 'x-a duplicates collapsed');
  CheckEqual('a3', LAll[0], 'x-a replacement value');

  LSeen := '';
  LH.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LSeen <> '' then
        LSeen := LSeen + '|';
      LSeen := LSeen + AName + '=' + AValue;
    end);
  CheckEqual('x-a=a3|x-c=c1|x-d=d1', LSeen, 'foreach sees compacted order only');

  LClone := LH.Clone;
  CheckEqual(Int64(3), Int64(LClone.Count), 'clone count after compaction');
  CheckEqual('d1', LClone.Get('X-D'), 'clone includes appended entry');
  Check(not LClone.Has('X-B'), 'clone omits deleted entry');
end;

procedure TestClearResetsAndAllowsReuse;
var
  LH: IHttpHeaders;
  LAll: TStringArray;
  LSeen: string;
begin
  LH := NewHttpHeaders;
  LH.Add('X-A', 'a1');
  LH.Add('X-A', 'a2');
  LH.Set_('X-B', 'b1');

  LH.Clear;

  CheckEqual(Int64(0), Int64(LH.Count), 'clear resets count');
  CheckEqual('', LH.Get('X-A'), 'clear removes first value lookup');
  LAll := LH.GetAll('X-A');
  CheckEqual(Int64(0), Int64(Length(LAll)), 'clear removes all values');
  Check(not LH.Has('X-B'), 'clear removes has state');

  LSeen := '';
  LH.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LSeen <> '' then
        LSeen := LSeen + '|';
      LSeen := LSeen + AName + '=' + AValue;
    end);
  CheckEqual('', LSeen, 'clear hides stale entries from iteration');

  LH.Add('X-C', 'c1');
  LH.Add('X-C', 'c2');
  LH.Set_('X-D', 'd1');

  CheckEqual(Int64(3), Int64(LH.Count), 'reused count');
  LAll := LH.GetAll('X-C');
  CheckEqual(Int64(2), Int64(Length(LAll)), 'reused getall length');
  CheckEqual('c1', LAll[0], 'reused first');
  CheckEqual('c2', LAll[1], 'reused second');
  CheckEqual('d1', LH.Get('X-D'), 'reused set/get');
end;

procedure TestParsedAddCanonicalizesParserValidatedHeaders;
var
  LStore: THttpHeaders;
  LH: IHttpHeaders;
  LAll: TStringArray;
  LSeen: string;
begin
  LStore := THttpHeaders.Create;
  LH := LStore;

  LStore.AddParsed('Content-Type', 'text/plain');
  LStore.AddParsed('X-Custom', 'a');
  LStore.AddParsed('x-custom', 'b');

  CheckEqual(Int64(3), Int64(LH.Count), 'parsed add preserves duplicate entries');
  CheckEqual('text/plain', LH.Get('CONTENT-TYPE'), 'parsed add canonical lookup');

  LAll := LH.GetAll('X-Custom');
  CheckEqual(Int64(2), Int64(Length(LAll)), 'parsed add duplicate count');
  CheckEqual('a', LAll[0], 'parsed add first duplicate value');
  CheckEqual('b', LAll[1], 'parsed add second duplicate value');

  LSeen := '';
  LH.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LSeen <> '' then
        LSeen := LSeen + '|';
      LSeen := LSeen + AName + '=' + AValue;
    end);
  CheckEqual('content-type=text/plain|x-custom=a|x-custom=b', LSeen,
    'parsed add stores canonical lowercase names');
end;

procedure TestParsedSpanAddCanonicalizesParserValidatedHeaders;
var
  LStore: THttpHeaders;
  LH: IHttpHeaders;
  LName1, LValue1, LName2, LValue2, LName3, LValue3: AnsiString;
  LAll: TStringArray;
  LSeen: string;
begin
  LStore := THttpHeaders.Create;
  LH := LStore;

  LName1 := 'Content-Type';
  LValue1 := 'text/plain';
  LName2 := 'X-Custom';
  LValue2 := 'a';
  LName3 := 'x-custom';
  LValue3 := 'b';

  LStore.AddParsedSpans(PAnsiChar(LName1), Length(LName1),
    PAnsiChar(LValue1), Length(LValue1));
  LStore.AddParsedSpans(PAnsiChar(LName2), Length(LName2),
    PAnsiChar(LValue2), Length(LValue2));
  LStore.AddParsedSpans(PAnsiChar(LName3), Length(LName3),
    PAnsiChar(LValue3), Length(LValue3));

  CheckEqual(Int64(3), Int64(LH.Count), 'parsed span add preserves duplicate entries');
  CheckEqual('text/plain', LH.Get('CONTENT-TYPE'), 'parsed span add canonical lookup');

  LAll := LH.GetAll('X-Custom');
  CheckEqual(Int64(2), Int64(Length(LAll)), 'parsed span add duplicate count');
  CheckEqual('a', LAll[0], 'parsed span add first duplicate value');
  CheckEqual('b', LAll[1], 'parsed span add second duplicate value');

  LSeen := '';
  LH.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LSeen <> '' then
        LSeen := LSeen + '|';
      LSeen := LSeen + AName + '=' + AValue;
    end);
  CheckEqual('content-type=text/plain|x-custom=a|x-custom=b', LSeen,
    'parsed span add stores canonical lowercase names');
end;

procedure ExpectHeaderError(const ALabel: string; const AUseSet: Boolean;
  const AName, AValue: string);
var
  LH: IHttpHeaders;
  LRaised: Boolean;
begin
  LH := NewHttpHeaders;
  LRaised := False;
  try
    if AUseSet then
      LH.Set_(AName, AValue)
    else
      LH.Add(AName, AValue);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, ALabel);
end;

procedure TestValidationRejectsInvalidNamesAndValues;
begin
  ExpectHeaderError('add rejects empty name', False, '', 'value');
  ExpectHeaderError('set rejects colon in name', True, 'Bad:Name', 'value');
  ExpectHeaderError('add rejects CR in value', False, 'x-good', 'bad'#13'value');
  ExpectHeaderError('set rejects NUL in value', True, 'x-good', 'bad'#0'value');
end;

procedure TestSetBasicAuth;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('authorization', 'Bearer old');

  SetBasicAuth(LH, 'Aladdin', 'open sesame');

  CheckEqual('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
    LH.Get('Authorization'), 'basic auth header value');
  CheckEqual(Int64(1), Int64(LH.Count), 'basic auth replaces existing auth');
end;

procedure TestSetBearerAuth;
var
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;

  SetBearerAuth(LH, 'token-123');

  CheckEqual('Bearer token-123', LH.Get('Authorization'),
    'bearer auth header value');
end;

procedure TestAuthHelpersRejectNilHeaders;
var
  LH: IHttpHeaders;
  LRaised: Boolean;
begin
  LH := nil;
  LRaised := False;
  try
    SetBearerAuth(LH, 'token');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'bearer helper rejects nil headers');

  LRaised := False;
  try
    SetBasicAuth(LH, 'user', 'pass');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'basic helper rejects nil headers');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.headers');
  T.Run('Set and Get basic', @TestSetAndGetBasic);
  T.Run('Case-insensitive lookup', @TestCaseInsensitiveLookup);
  T.Run('Add multiple values', @TestAddMultipleValues);
  T.Run('GetAll returns all values', @TestGetAllReturnsAllValues);
  T.Run('Set replaces existing', @TestSetReplacesExisting);
  T.Run('Del removes all values', @TestDelRemovesAllValues);
  T.Run('Has returns true/false', @TestHasReturnsTrueFalse);
  T.Run('Count reflects total entries', @TestCountReflectsTotalEntries);
  T.Run('Clone creates independent copy', @TestCloneCreatesIndependentCopy);
  T.Run('Get returns empty for missing', @TestGetReturnEmptyForMissing);
  T.Run('GetAll returns empty for missing', @TestGetAllReturnEmptyForMissing);
  T.Run('Del non-existent is no-op', @TestDelNonExistentIsNoOp);
  T.Run('Compaction preserves visible order', @TestCompactionPreservesVisibleOrder);
  T.Run('Clear resets and allows reuse', @TestClearResetsAndAllowsReuse);
  T.Run('Parsed add canonicalizes parser validated headers',
    @TestParsedAddCanonicalizesParserValidatedHeaders);
  T.Run('Parsed span add canonicalizes parser validated headers',
    @TestParsedSpanAddCanonicalizesParserValidatedHeaders);
  T.Run('Validation rejects invalid names and values', @TestValidationRejectsInvalidNamesAndValues);
  T.Run('SetBasicAuth sets Authorization', @TestSetBasicAuth);
  T.Run('SetBearerAuth sets Authorization', @TestSetBearerAuth);
  T.Run('Auth helpers reject nil headers', @TestAuthHelpersRejectNilHeaders);
  T.Summary;
end.
