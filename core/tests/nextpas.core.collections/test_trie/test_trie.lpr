program test_trie;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.trie;

type
  TStrTrie = specialize TTrie<Integer>;

var
  T: TTestRunner;

procedure TestPutGet;
var LT: TStrTrie; v: Integer;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('hello', 1); LT.Put('world', 2); LT.Put('help', 3);
    Check(LT.TryGetValue('hello', v), 'get hello'); CheckEqual(Int64(1), Int64(v), 'val hello');
    Check(LT.TryGetValue('world', v), 'get world'); CheckEqual(Int64(2), Int64(v), 'val world');
    Check(LT.TryGetValue('help', v), 'get help'); CheckEqual(Int64(3), Int64(v), 'val help');
    Check(not LT.TryGetValue('hell', v), 'miss prefix');
    Check(not LT.TryGetValue('helping', v), 'miss longer');
    CheckEqual(Int64(3), Int64(LT.Count), 'count');
  finally LT.Free; end;
end;

procedure TestUpdate;
var LT: TStrTrie; v: Integer;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('key', 10); LT.Put('key', 99);
    CheckEqual(Int64(1), Int64(LT.Count), 'count');
    Check(LT.TryGetValue('key', v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated');
  finally LT.Free; end;
end;

procedure TestRemove;
var LT: TStrTrie;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('abc', 1); LT.Put('abd', 2); LT.Put('xyz', 3);
    Check(LT.Remove('abd'), 'remove abd');
    Check(not LT.ContainsKey('abd'), 'not contains abd');
    Check(LT.ContainsKey('abc'), 'still contains abc');
    CheckEqual(Int64(2), Int64(LT.Count), 'count');
  finally LT.Free; end;
end;

procedure TestStartsWith;
var LT: TStrTrie; LKeys: TStrTrie.TKeyArray;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('apple', 1); LT.Put('app', 2); LT.Put('banana', 3); LT.Put('application', 4);
    LKeys := LT.KeysWithPrefix('app');
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'prefix app count');
  finally LT.Free; end;
end;

procedure TestClear;
var LT: TStrTrie;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('a', 1); LT.Put('b', 2);
    LT.Clear;
    CheckEqual(Int64(0), Int64(LT.Count), 'count after clear');
    Check(not LT.ContainsKey('a'), 'not contains after clear');
    LT.Put('c', 3);
    CheckEqual(Int64(1), Int64(LT.Count), 'usable after clear');
  finally LT.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.trie');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('StartsWith (prefix search)', @TestStartsWith);
  T.Run('Clear', @TestClear);
  T.Summary;
end.
