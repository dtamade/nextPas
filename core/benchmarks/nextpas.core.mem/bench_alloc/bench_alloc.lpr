program bench_alloc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.mem;

var
  B: TBenchRunner;
  GSink: Pointer;

procedure BenchAlloc64_Default(aIters: Int64);
var
  LIt: Int64;
  LA: IAllocator;
  LP: Pointer;
begin
  LA := DefaultAllocator;
  for LIt := 1 to aIters do
  begin
    LP := LA.Allocate(64);
    LA.Deallocate(LP);
  end;
  GSink := LP;
end;

procedure BenchAlloc256_Default(aIters: Int64);
var
  LIt: Int64;
  LA: IAllocator;
  LP: Pointer;
begin
  LA := DefaultAllocator;
  for LIt := 1 to aIters do
  begin
    LP := LA.Allocate(256);
    LA.Deallocate(LP);
  end;
  GSink := LP;
end;

procedure BenchAlloc4K_Default(aIters: Int64);
var
  LIt: Int64;
  LA: IAllocator;
  LP: Pointer;
begin
  LA := DefaultAllocator;
  for LIt := 1 to aIters do
  begin
    LP := LA.Allocate(4096);
    LA.Deallocate(LP);
  end;
  GSink := LP;
end;

procedure BenchAllocZeroed64(aIters: Int64);
var
  LIt: Int64;
  LA: IAllocator;
  LP: Pointer;
begin
  LA := DefaultAllocator;
  for LIt := 1 to aIters do
  begin
    LP := AllocZeroed(LA, 64);
    LA.Deallocate(LP);
  end;
  GSink := LP;
end;

procedure BenchRawGetMem64(aIters: Int64);
var
  LIt: Int64;
  LP: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    LP := GetMem(64);
    FreeMem(LP);
  end;
  GSink := LP;
end;

procedure BenchRawGetMem4K(aIters: Int64);
var
  LIt: Int64;
  LP: Pointer;
begin
  for LIt := 1 to aIters do
  begin
    LP := GetMem(4096);
    FreeMem(LP);
  end;
  GSink := LP;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.mem benchmark ===');
  WriteLn;
  B.Run('IAllocator.GetMem(64)', @BenchAlloc64_Default);
  B.Run('IAllocator.GetMem(256)', @BenchAlloc256_Default);
  B.Run('IAllocator.GetMem(4096)', @BenchAlloc4K_Default);
  B.Run('AllocZeroed(64)', @BenchAllocZeroed64);
  B.Run('Raw GetMem(64) baseline', @BenchRawGetMem64);
  B.Run('Raw GetMem(4096) baseline', @BenchRawGetMem4K);
  WriteLn;
  B.Summary;
  B.Free;
end.
