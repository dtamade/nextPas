program test_config_mutation;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.errors,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSetTypedValuesAndInterpolation;
var
  LCfg: TConfig;
  LRatio: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('app.name', 'nextpas');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetFloat('feature.ratio', 2.5);
    LCfg.SetString('service.url', 'http://${app.name}:${server.port}');

    CheckEqual('nextpas', LCfg.GetString('app.name'), 'string write');
    CheckEqual(Int64(8080), LCfg.GetIntRequired('server.port'), 'int write');
    CheckEqual(True, LCfg.GetBoolRequired('feature.enabled'), 'bool write');
    LRatio := LCfg.GetFloatRequired('feature.ratio');
    Check((LRatio > 2.4) and (LRatio < 2.6), 'float write');
    CheckEqual('http://${app.name}:${server.port}',
      LCfg.GetRawString('service.url'), 'raw string keeps placeholders');
    CheckEqual('http://nextpas:8080',
      LCfg.GetString('service.url'), 'written string still interpolates');
  finally
    LCfg.Free;
  end;
end;

procedure TestSetStringArrayReplacesPriorValues;
var
  LCfg: TConfig;
  LTags: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('tags', 'scalar');
    LCfg.SetStringArray('tags', ['alpha', 'beta', 'gamma']);

    LTags := LCfg.GetStringArray('tags');
    CheckEqual(Int64(3), Int64(Length(LTags)), 'array count after first write');
    CheckEqual('alpha', LTags[0], 'array item 0');
    CheckEqual('beta', LTags[1], 'array item 1');
    CheckEqual('gamma', LTags[2], 'array item 2');
    CheckEqual(False, LCfg.Has('tags'), 'scalar key replaced by array');

    LCfg.SetStringArray('tags', ['prod']);
    LTags := LCfg.GetStringArray('tags');
    CheckEqual(Int64(1), Int64(Length(LTags)), 'array count after replace');
    CheckEqual('prod', LTags[0], 'array item after replace');
    CheckEqual(False, LCfg.Has('tags.1'), 'stale array tail removed');
    CheckEqual(False, LCfg.Has('tags.2'), 'stale array tail removed 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestDeleteKeyRemovesOnlyExactKey;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server', 'root');
    LCfg.SetString('server.host', 'localhost');
    LCfg.SetString('server.port', '8080');

    LCfg.DeleteKey('server');
    CheckEqual(False, LCfg.Has('server'), 'exact key removed');
    CheckEqual(True, LCfg.Has('server.host'), 'child key preserved');
    CheckEqual(True, LCfg.Has('server.port'), 'sibling key preserved');
  finally
    LCfg.Free;
  end;
end;

procedure TestDeleteSectionRemovesExactAndNestedKeys;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('db', 'root');
    LCfg.SetString('db.host', 'localhost');
    LCfg.SetInt('db.port', 5432);
    LCfg.SetStringArray('db.tags', ['primary', 'writer']);

    LCfg.DeleteSection('db');
    CheckEqual(False, LCfg.Has('db'), 'section root removed');
    CheckEqual(False, LCfg.Has('db.host'), 'section child removed');
    CheckEqual(False, LCfg.Has('db.port'), 'section child removed 2');
    CheckEqual(False, LCfg.Has('db.tags.0'), 'section array child removed');
    CheckEqual(False, LCfg.Has('db.tags.1'), 'section array child removed 2');
  finally
    LCfg.Free;
  end;
end;

procedure TestDeleteSectionPreservesLongerPrefixes;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('db.host', 'localhost');
    LCfg.SetString('database.host', 'analytics');

    LCfg.DeleteSection('db');
    CheckEqual(False, LCfg.Has('db.host'), 'db subtree removed');
    CheckEqual(True, LCfg.Has('database.host'),
      'longer non-section prefix preserved');
    CheckEqual('analytics', LCfg.GetString('database.host'),
      'preserved sibling value');
  finally
    LCfg.Free;
  end;
end;

procedure TestClearRemovesAllEntries;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"server":{"host":"localhost","port":8080}}');
    LCfg.SetString('feature.name', 'cfg');
    LCfg.Clear;

    CheckEqual(Int64(0), Int64(LCfg.Count), 'count cleared');
    CheckEqual(False, LCfg.Has('server.host'), 'loaded key removed');
    CheckEqual(False, LCfg.Has('feature.name'), 'written key removed');
    LKeys := LCfg.GetKeys;
    CheckEqual(Int64(0), Int64(Length(LKeys)), 'keys cleared');
    CheckEqual('fallback', LCfg.GetString('server.host', 'fallback'),
      'default still works after clear');
  finally
    LCfg.Free;
  end;
end;

procedure TestMutationRemainsCaseInsensitive;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('Server.Host', 'localhost');
    CheckEqual('localhost', LCfg.GetString('server.host'),
      'lowercase read after mixed-case write');
    CheckEqual('localhost', LCfg.GetString('SERVER.HOST'),
      'uppercase read after mixed-case write');

    LCfg.DeleteKey('server.host');
    CheckEqual(False, LCfg.Has('SERVER.HOST'),
      'delete key remains case-insensitive');

    LCfg.SetString('Feature.Flag', 'yes');
    LCfg.SetString('feature.name', 'cfg');
    LCfg.DeleteSection('FEATURE');
    CheckEqual(False, LCfg.Has('feature.flag'),
      'section delete remains case-insensitive');
    CheckEqual(False, LCfg.Has('FEATURE.NAME'),
      'section delete removes sibling keys');
  finally
    LCfg.Free;
  end;
end;

procedure TestSetStringArrayEmptyClearsPrefix;
var
  LCfg: TConfig;
  LEmpty: TStringArray;
  LTags: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetStringArray('tags', ['alpha', 'beta']);
    SetLength(LEmpty, 0);
    LCfg.SetStringArray('tags', LEmpty);

    LTags := LCfg.GetStringArray('tags');
    CheckEqual(Int64(0), Int64(Length(LTags)), 'empty array clears stored items');
    CheckEqual(False, LCfg.Has('tags.0'), 'first array item removed');
    CheckEqual(False, LCfg.Has('tags.1'), 'second array item removed');
  finally
    LCfg.Free;
  end;
end;

procedure TestMutationRejectsEmptyKeysAndPrefixes;
var
  LCfg: TConfig;
  LRaised: Boolean;
begin
  LCfg := TConfig.Create;
  try
    LRaised := False;
    try
      LCfg.SetString('', 'value');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'SetString rejects empty key');

    LRaised := False;
    try
      LCfg.DeleteKey('');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'DeleteKey rejects empty key');

    LRaised := False;
    try
      LCfg.DeleteSection('');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'DeleteSection rejects empty prefix');
  finally
    LCfg.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.config.mutation');
  T.Run('Mutation.SetTypedValuesAndInterpolation',
    @TestSetTypedValuesAndInterpolation);
  T.Run('Mutation.SetStringArrayReplacesPriorValues',
    @TestSetStringArrayReplacesPriorValues);
  T.Run('Mutation.DeleteKeyRemovesOnlyExactKey',
    @TestDeleteKeyRemovesOnlyExactKey);
  T.Run('Mutation.DeleteSectionRemovesExactAndNestedKeys',
    @TestDeleteSectionRemovesExactAndNestedKeys);
  T.Run('Mutation.DeleteSectionPreservesLongerPrefixes',
    @TestDeleteSectionPreservesLongerPrefixes);
  T.Run('Mutation.ClearRemovesAllEntries',
    @TestClearRemovesAllEntries);
  T.Run('Mutation.RemainsCaseInsensitive',
    @TestMutationRemainsCaseInsensitive);
  T.Run('Mutation.SetStringArrayEmptyClearsPrefix',
    @TestSetStringArrayEmptyClearsPrefix);
  T.Run('Mutation.RejectsEmptyKeysAndPrefixes',
    @TestMutationRejectsEmptyKeysAndPrefixes);
  T.Summary;
end.
