program test_trie;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.trie,
  leak_tracker;

type
  TStrTrie = specialize TTrie<Integer>;
  TTrackedTrie = specialize TTrie<ITracked>;

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

procedure RunManagedClearReleasesValues;
var
  LT: TTrackedTrie;
  LSnap: TLeakSnapshot;
  LFirst: ITracked;
  LSecond: ITracked;
  LRoot: ITracked;
begin
  LSnap := SnapTake;
  LT := TTrackedTrie.Create;
  try
    LFirst := MakeTracked(1);
    LSecond := MakeTracked(2);
    LRoot := MakeTracked(3);
    LT.Put('a', LFirst);
    LT.Put('ab', LSecond);
    LT.Put('', LRoot);
    LFirst := nil;
    LSecond := nil;
    LRoot := nil;
    CheckEqual(Int64(LSnap) + 3, Int64(SnapTake), 'tracked values after managed clear setup');
    LT.Clear;
    CheckEqual(Int64(0), Int64(LT.Count), 'count after managed clear');
    SnapAssert(LSnap, 'trie managed clear releases values before destroy');
  finally
    LT.Free;
  end;
end;

procedure TestManagedClearReleasesValues;
var
  LSnap: TLeakSnapshot;
begin
  LSnap := SnapTake;
  RunManagedClearReleasesValues;
  SnapAssert(LSnap, 'trie managed clear releases values after destroy');
end;

procedure RunManagedDestroyReleasesValues;
var
  LT: TTrackedTrie;
  LRoot: ITracked;
  LChild: ITracked;
  LEmpty: ITracked;
begin
  LT := TTrackedTrie.Create;
  try
    LRoot := MakeTracked(10);
    LChild := MakeTracked(11);
    LEmpty := MakeTracked(12);
    LT.Put('root', LRoot);
    LT.Put('rooted', LChild);
    LT.Put('', LEmpty);
    LRoot := nil;
    LChild := nil;
    LEmpty := nil;
  finally
    LT.Free;
  end;
end;

procedure TestManagedDestroyReleasesValues;
var
  LSnap: TLeakSnapshot;
begin
  LSnap := SnapTake;
  RunManagedDestroyReleasesValues;
  SnapAssert(LSnap, 'trie managed destroy releases values');
end;

procedure TestManagedRemoveReleasesValue;
var
  LT: TTrackedTrie;
  LSnap: TLeakSnapshot;
  LRemoved: ITracked;
  LKept: ITracked;
begin
  LSnap := SnapTake;
  LT := TTrackedTrie.Create;
  try
    LRemoved := MakeTracked(20);
    LKept := MakeTracked(21);
    LT.Put('remove', LRemoved);
    LT.Put('keep', LKept);
    LRemoved := nil;
    LKept := nil;
    CheckEqual(Int64(LSnap) + 2, Int64(SnapTake), 'tracked values after remove setup');
    Check(LT.Remove('remove'), 'remove managed value');
    CheckEqual(Int64(1), Int64(LT.Count), 'count after managed remove');
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'removed managed value released');
    Check(not LT.Remove('remove'), 'second remove returns false');
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'second remove does not release again');
  finally
    LT.Free;
  end;
  SnapAssert(LSnap, 'trie managed remove releases values after destroy');
end;

procedure TestManagedRemoveEmptyKeyReleasesValue;
var
  LT: TTrackedTrie;
  LSnap: TLeakSnapshot;
  LRemoved: ITracked;
begin
  LSnap := SnapTake;
  LT := TTrackedTrie.Create;
  try
    LRemoved := MakeTracked(25);
    LT.Put('', LRemoved);
    LRemoved := nil;
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'tracked root value after empty-key put');
    Check(LT.Remove(''), 'remove empty-key managed value');
    CheckEqual(Int64(0), Int64(LT.Count), 'count after empty-key remove');
    SnapAssert(LSnap, 'trie managed empty-key remove releases value');
    Check(not LT.Remove(''), 'second empty-key remove returns false');
  finally
    LT.Free;
  end;
  SnapAssert(LSnap, 'trie managed empty-key remove stays released after destroy');
end;

procedure TestManagedOverwriteReleasesOldValue;
var
  LT: TTrackedTrie;
  LSnap: TLeakSnapshot;
  LOld: ITracked;
  LNew: ITracked;
begin
  LSnap := SnapTake;
  LT := TTrackedTrie.Create;
  try
    LOld := MakeTracked(30);
    LT.Put('same', LOld);
    LOld := nil;
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'tracked value after first put');
    LNew := MakeTracked(31);
    LT.Put('same', LNew);
    LNew := nil;
    CheckEqual(Int64(1), Int64(LT.Count), 'count after managed overwrite');
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'old managed value released on overwrite');
    LT.Clear;
    SnapAssert(LSnap, 'trie managed overwrite value released by clear');
  finally
    LT.Free;
  end;
  SnapAssert(LSnap, 'trie managed overwrite releases values after destroy');
end;

procedure TestManagedOverwriteEmptyKeyReleasesOldValue;
var
  LT: TTrackedTrie;
  LSnap: TLeakSnapshot;
  LOld: ITracked;
  LNew: ITracked;
begin
  LSnap := SnapTake;
  LT := TTrackedTrie.Create;
  try
    LOld := MakeTracked(35);
    LT.Put('', LOld);
    LOld := nil;
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'tracked root value after first empty-key put');
    LNew := MakeTracked(36);
    LT.Put('', LNew);
    LNew := nil;
    CheckEqual(Int64(1), Int64(LT.Count), 'count after empty-key managed overwrite');
    CheckEqual(Int64(LSnap) + 1, Int64(SnapTake), 'old empty-key managed value released on overwrite');
    LT.Clear;
    SnapAssert(LSnap, 'trie managed empty-key overwrite value released by clear');
  finally
    LT.Free;
  end;
  SnapAssert(LSnap, 'trie managed empty-key overwrite releases values after destroy');
end;

procedure TestHasPrefixIgnoresRemovedTombstones;
var
  LT: TStrTrie;
begin
  LT := TStrTrie.Create;
  try
    LT.Put('abc', 1);
    Check(LT.HasPrefix('a'), 'prefix should exist before remove');
    Check(LT.Remove('abc'), 'remove abc');
    Check(not LT.HasPrefix('a'), 'prefix should not exist after removing last key');
  finally
    LT.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.trie');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('StartsWith (prefix search)', @TestStartsWith);
  T.Run('Clear', @TestClear);
  T.Run('Managed Clear releases values', @TestManagedClearReleasesValues);
  T.Run('Managed Destroy releases values', @TestManagedDestroyReleasesValues);
  T.Run('Managed Remove releases value', @TestManagedRemoveReleasesValue);
  T.Run('Managed Remove empty-key releases value', @TestManagedRemoveEmptyKeyReleasesValue);
  T.Run('Managed Overwrite releases old value', @TestManagedOverwriteReleasesOldValue);
  T.Run('Managed Overwrite empty-key releases old value', @TestManagedOverwriteEmptyKeyReleasesOldValue);
  T.Run('HasPrefix ignores removed tombstones', @TestHasPrefixIgnoresRemovedTombstones);
  T.Summary;
end.
