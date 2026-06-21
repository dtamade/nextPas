program bench_arena_compiler;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.mem.arena.compiler,
  nextpas.core.mem.arena.growable,
  nextpas.core.mem.base;

var
  B: TBenchRunner;
  GSink: Pointer;

{ --- TArena.Alloc vs System.GetMem (small objects 16B-256B) --- }

procedure BenchArenaAlloc16(aIters: Int64);
var
  LIt: Int64;
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(16);
      GSink := LP;
    end;
  finally
    TArena_Release(LArena);
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
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(64);
      GSink := LP;
    end;
  finally
    TArena_Release(LArena);
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
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    for LIt := 1 to aIters do
    begin
      LP := LArena.Alloc(256);
      GSink := LP;
    end;
  finally
    TArena_Release(LArena);
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

{ --- TArena.Alloc vs TGrowingArena.Alloc --- }

procedure BenchTArenaBatch(aIters: Int64);
var
  LIt: Int64;
  I: Integer;
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
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
    TArena_Release(LArena);
  end;
end;

procedure BenchTGrowingArenaBatch(aIters: Int64);
var
  LIt: Int64;
  I: Integer;
  LArena: TGrowingArena;
  LP: Pointer;
begin
  LArena := TGrowingArena.Create(65536);
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
  B := TBenchRunner.Create;

  WriteLn('--- TArena vs System.GetMem (single alloc) ---');
  B.Run('TArena.Alloc_16B',    @BenchArenaAlloc16);
  B.Run('System.GetMem_16B',   @BenchGetMem16);
  B.Run('TArena.Alloc_64B',    @BenchArenaAlloc64);
  B.Run('System.GetMem_64B',   @BenchGetMem64);
  B.Run('TArena.Alloc_256B',   @BenchArenaAlloc256);
  B.Run('System.GetMem_256B',  @BenchGetMem256);

  WriteLn;
  WriteLn('--- TArena vs TGrowingArena (batch 10000 x 64B) ---');
  B.Run('TArena_batch_10000x64B',       @BenchTArenaBatch);
  B.Run('TGrowingArena_batch_10000x64B', @BenchTGrowingArenaBatch);

  B.Summary;
end.
