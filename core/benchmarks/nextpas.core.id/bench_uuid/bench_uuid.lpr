program bench_uuid;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.id.uuid,
  nextpas.core.time;

procedure BenchOp(const AName: string; const AOps: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
begin
  LNs := AElapsed.AsNanoseconds;
  if (LNs > 0) and (AOps > 0) then
    WriteLn('  ', AName:40, LNs div AOps:8, ' ns/op')
  else
    WriteLn('  ', AName:40, '       ? ns/op');
end;

const
  N_GEN = 1000000;
  N_PARSE = 2000000;

var
  LStart: TInstant;
  LI: Int32;
  LU: TUuid;
  LS: string;

begin
  WriteLn('=== nextpas.core.id.uuid benchmarks ===');
  WriteLn;

  WriteLn('--- Generate ---');
  LStart := TInstant.Now;
  for LI := 1 to N_GEN do
    LU := TUuid.NewV4;
  BenchOp('TUuid.NewV4', N_GEN, LStart.Elapsed);

  LStart := TInstant.Now;
  for LI := 1 to N_GEN do
    LU := TUuid.NewV7;
  BenchOp('TUuid.NewV7', N_GEN, LStart.Elapsed);

  LStart := TInstant.Now;
  for LI := 1 to N_GEN do
    LS := UuidV4;
  BenchOp('UuidV4 (string)', N_GEN, LStart.Elapsed);

  LStart := TInstant.Now;
  for LI := 1 to N_GEN do
    LS := UuidV7;
  BenchOp('UuidV7 (string)', N_GEN, LStart.Elapsed);

  WriteLn;
  WriteLn('--- Parse ---');
  LS := '550e8400-e29b-41d4-a716-446655440000';
  LStart := TInstant.Now;
  for LI := 1 to N_PARSE do
    LU := TUuid.Parse(LS);
  BenchOp('TUuid.Parse', N_PARSE, LStart.Elapsed);

  WriteLn;
  WriteLn('--- Format ---');
  LU := TUuid.NewV4;
  LStart := TInstant.Now;
  for LI := 1 to N_PARSE do
    LS := LU.ToString;
  BenchOp('TUuid.ToString', N_PARSE, LStart.Elapsed);

  WriteLn;
  WriteLn('--- Reference (published benchmarks) ---');
  WriteLn('  Go uuid.New() (v4):                     ~150 ns/op');
  WriteLn('  Rust uuid::Uuid::new_v4():               ~30 ns/op');
  WriteLn('  Go uuid.NewV7():                        ~160 ns/op');
  WriteLn('  Rust uuid::Uuid::now_v7():               ~35 ns/op');
  WriteLn;
  WriteLn('Done.');
end.
