program test_db_redis_source_contract;
{$mode objfpc}{$H+}
uses
  nextpas.core.test,
  nextpas.core.fs;

{ Source-contract gate for db.redis L2→L2 same-layer one-way allowlist.
  Seam: db.redis.transport → net.tcp (+ tls.dialer optional) + db.redis.adapter → net (light)
  time/sync are L1 downward not L2 seam, base/resp pure L0/L1, no reverse net/tls→db.redis,
  bytes.ops single source inline/zero-copy, resource FreeAndNil/try-finally not lost.
  Mirrors respack/vfs/canvas gates: uses-graph + inline/zero-copy + stability evidence.
  Runner delegates to shell gate (single source); this LPR provides nextpas.core.test surface. }

var
  T: TTestSuite;

function Load(const ARel: string): string;
begin
  Result := nextpas.core.fs.ReadFileText(nextpas.core.fs.PathRealPath('../../../' + ARel));
end;

procedure AssertContains(const ALabel, ASource, AToken: string);
begin
  Check(Pos(AToken, ASource) > 0, ALabel + ' must contain ' + AToken);
end;

procedure AssertNotContains(const ALabel, ASource, AToken: string);
begin
  Check(Pos(AToken, ASource) = 0, ALabel + ' must not contain ' + AToken);
end;

procedure TestTransportSeam;
var S: string;
begin
  S := Load('src/nextpas.core.db.redis.transport.pas');
  AssertContains('transport', S, 'nextpas.core.net.tcp');
  AssertContains('transport', S, 'nextpas.core.tls');
  AssertContains('transport', S, 'NetTcpConnect');
  AssertContains('transport', S, 'IRedisTransport');
  AssertContains('transport', S, 'procedure Close');
  AssertContains('transport', S, 'destructor Destroy');
  AssertContains('transport', S, 'L2 同层单向 allowlist');
end;

procedure TestAdapterSeam;
var S: string;
begin
  S := Load('src/nextpas.core.db.redis.adapter.pas');
  AssertContains('adapter', S, 'nextpas.core.net');
  AssertContains('adapter', S, 'nextpas.core.sync');
  AssertContains('adapter', S, 'nextpas.core.time');
  AssertContains('adapter', S, 'nextpas.core.bytes.ops');
  AssertContains('adapter', S, 'StringToBytes');
  AssertContains('adapter', S, 'inline');
  AssertContains('adapter', S, 'FreeAndNil');
  AssertContains('adapter', S, 'FTransport.Close');
  AssertContains('adapter', S, 'L2 同层单向 allowlist');
end;

procedure TestPurity;
var S: string;
begin
  S := Load('src/nextpas.core.db.redis.base.pas');
  AssertNotContains('base', S, 'nextpas.core.net');
  AssertNotContains('base', S, 'nextpas.core.tls');
  AssertContains('base', S, '缝位纯度');
  S := Load('src/nextpas.core.db.redis.resp.pas');
  AssertNotContains('resp', S, 'nextpas.core.net');
  AssertNotContains('resp', S, 'nextpas.core.tls');
  AssertContains('resp', S, '缝位纯度');
end;

procedure TestNoReverse;
var S: string;
begin
  S := Load('src/nextpas.core.net.pas');
  AssertNotContains('net', S, 'nextpas.core.db.redis');
  S := Load('src/nextpas.core.tls.pas');
  AssertNotContains('tls', S, 'nextpas.core.db.redis');
end;

procedure TestFacade;
var S: string;
begin
  S := Load('src/nextpas.core.db.redis.pas');
  AssertContains('facade', S, 'inline');
  AssertNotContains('facade', S, 'nextpas.core.net');
  AssertContains('facade', S, '门面零缝');
end;

procedure TestRegistryAndConventions;
var S: string;
begin
  S := Load('docs/core-module-registry.md');
  AssertContains('registry', S, 'db.redis.transport');
  AssertContains('registry', S, '→');
  AssertContains('registry', S, 'net.tcp');
  AssertContains('registry', S, 'cycle-gated');
  AssertContains('registry', S, 'no reverse');
  AssertContains('registry', S, 'bytes.ops');
  AssertContains('registry', S, 'source-contract + focused-runtime');
  S := Load('docs/design-conventions.md');
  AssertContains('conventions', S, 'db.redis.transport→net');
  AssertContains('conventions', S, 'source-contract');
end;

begin
  T := TTestSuite.Create('nextpas.db.redis.source.contract');
  T.Test('transport L2 seam single-point', @TestTransportSeam);
  T.Test('adapter L2 seam + L1 downward', @TestAdapterSeam);
  T.Test('base/resp purity no L2', @TestPurity);
  T.Test('no reverse net/tls→redis', @TestNoReverse);
  T.Test('facade pure inline', @TestFacade);
  T.Test('registry+conventions fine-grained', @TestRegistryAndConventions);
  if not T.Run then Halt(1);
end.
