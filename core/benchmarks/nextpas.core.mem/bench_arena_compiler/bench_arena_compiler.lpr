program bench_arena_compiler;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.base;

var
  LResults: IBenchResults;
  GSink: Pointer;

{ --- TChunkedArena.Alloc vs System.GetMem (small objects 16B-256B) --- }

procedure BenchArenaAlloc16(aIters: Int64);
var
  LIt: Int64;
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(65536);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(16);
      GSink := LP;
    end;
  finally
    LArena.Free;
  end;
end;

procedure BenchGetMem16(aIters: Int64);
var
  LIt: Int64;
  LP: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    GetMem(LP, 16);
    GSink := LP;
  end;
end;

procedure BenchArenaAlloc64(aIters: Int64);
var
  LIt: Int64;
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(65536);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(64);
      GSink := LP;
    end;
  finally
    LArena.Free;
  end;
end;

procedure BenchGetMem64(aIters: Int64);
var
  LIt: Int64;
  LP: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    GetMem(LP, 64);
    GSink := LP;
  end;
end;

procedure BenchArenaAlloc256(aIters: Int64);
var
  LIt: Int64;
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(65536);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(256);
      GSink := LP;
    end;
  finally
    LArena.Free;
  end;
end;

procedure BenchGetMem256(aIters: Int64);
var
  LIt: Int64;
  LP: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    GetMem(LP, 256);
    GSink := LP;
  end;
end;

{ --- TChunkedArena batch alloc with Reset --- }

procedure BenchArenaBatch(aIters: Int64);
var
  LIt: Int64;
  I: Integer;
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(65536);
  try
    for LIt := 1 to aIters do
    begin
      for I := 0 to 9999 do
      begin
        LP := LArena.Alloc(64);
        GSink := LP;
      end;
      LArena.Reset;
    end;
  finally
    LArena.Free;
  end;
end;

begin

  WriteLn('--- TChunkedArena vs System.GetMem (single alloc) ---');
  LResults := TBenchSuite.Create('Arena')
    .AddLoop('TChunkedArena.Alloc_16B', @BenchArenaAlloc16)
    .AddLoop('System.GetMem_16B', @BenchGetMem16)
    .AddLoop('TChunkedArena.Alloc_64B', @BenchArenaAlloc64)
    .AddLoop('System.GetMem_64B', @BenchGetMem64)
    .AddLoop('TChunkedArena.Alloc_256B', @BenchArenaAlloc256)
    .AddLoop('System.GetMem_256B', @BenchGetMem256)
    .AddLoop('TChunkedArena_batch_10000x64B', @BenchArenaBatch)
    .Run;
  WriteLn(LResults.PrintToConsole);
end.
