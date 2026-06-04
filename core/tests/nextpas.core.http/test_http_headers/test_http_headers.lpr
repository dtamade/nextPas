program test_http_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
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
  T.Summary;
end.
