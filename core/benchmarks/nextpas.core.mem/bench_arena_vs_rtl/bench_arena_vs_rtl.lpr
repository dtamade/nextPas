program bench_arena_vs_rtl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.mem.arena,
  nextpas.core.mem.arena.compiler,
  nextpas.core.mem.base;

var
  LResults: IBenchResults;
  GSink: Pointer;

{ --- TLocalArena vs System.GetMem (small objects 16B-256B) --- }

procedure BenchLocalArenaAlloc16(aIters: Int64);
var
  LIt: Int64;
  LArena: TLocalArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024 * 1024); // 1MB
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(16);
      GSink := LP;
      if LIt mod 10000 = 0 then
        LArena.Reset; // 每 10000 次重置
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

procedure BenchLocalArenaAlloc64(aIters: Int64);
var
  LIt: Int64;
  LArena: TLocalArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024 * 1024); // 1MB
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(64);
      GSink := LP;
      if LIt mod 10000 = 0 then
        LArena.Reset;
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

procedure BenchLocalArenaAlloc256(aIters: Int64);
var
  LIt: Int64;
  LArena: TLocalArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024 * 1024); // 1MB
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(256);
      GSink := LP;
      if LIt mod 10000 = 0 then
        LArena.Reset;
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

{ --- TFastArena vs System.GetMem (small objects 16B-256B) --- }

procedure BenchFastArenaAlloc16(aIters: Int64);
var
  LIt: Int64;
  LArena: TFastArena;
  LP: Pointer;
begin
  TFastArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(16);
      GSink := LP;
    end;
  finally
    TFastArena_Release(LArena);
  end;
end;

procedure BenchFastArenaAlloc64(aIters: Int64);
var
  LIt: Int64;
  LArena: TFastArena;
  LP: Pointer;
begin
  TFastArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(64);
      GSink := LP;
    end;
  finally
    TFastArena_Release(LArena);
  end;
end;

procedure BenchFastArenaAlloc256(aIters: Int64);
var
  LIt: Int64;
  LArena: TFastArena;
  LP: Pointer;
begin
  TFastArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(256);
      GSink := LP;
    end;
  finally
    TFastArena_Release(LArena);
  end;
end;

begin
  try
    WriteLn('--- TLocalArena vs System.GetMem (single alloc) ---');
    LResults := TBenchSuite.Create('TLocalArena')
      .AddLoop('TLocalArena.Alloc_16B', @BenchLocalArenaAlloc16)
      .AddLoop('System.GetMem_16B', @BenchGetMem16)
      .AddLoop('TLocalArena.Alloc_64B', @BenchLocalArenaAlloc64)
      .AddLoop('System.GetMem_64B', @BenchGetMem64)
      .AddLoop('TLocalArena.Alloc_256B', @BenchLocalArenaAlloc256)
      .AddLoop('System.GetMem_256B', @BenchGetMem256)
      .AddLoop('TFastArena.Alloc_16B', @BenchFastArenaAlloc16)
      .AddLoop('TFastArena.Alloc_64B', @BenchFastArenaAlloc64)
      .AddLoop('TFastArena.Alloc_256B', @BenchFastArenaAlloc256)
      .Run;
    WriteLn(LResults.PrintToConsole);
  finally
  end;
end.
