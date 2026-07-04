program bench_hashmap_fpcrtl;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, sysutils;
const N = 1000000; BUCKET_COUNT = 2097152;
type
  PNode = ^TNode;
  TNode = record Key, Value: UInt64; Next: PNode; end;
  TChainTable = record Buckets: array of PNode; Count: Integer; end;
var GKeys: array of UInt64; GTable: TChainTable;
function Hash64(AKey: UInt64): UInt64;
begin AKey := (AKey xor (AKey shr 30)) * $BF58476D1CE4E5B9; AKey := (AKey xor (AKey shr 27)) * $94D049BB133111EB; Result := AKey xor (AKey shr 31); end;
procedure InitTable(var ATable: TChainTable; ACap: Integer);
begin SetLength(ATable.Buckets, ACap); FillChar(ATable.Buckets[0], ACap * SizeOf(Pointer), 0); ATable.Count := 0; end;
procedure ChainPut(var ATable: TChainTable; AKey, AValue: UInt64);
var LIdx: Integer; LNode: PNode;
begin
  LIdx := Integer(Hash64(AKey) and UInt64(Length(ATable.Buckets) - 1));
  LNode := ATable.Buckets[LIdx];
  while LNode <> nil do begin if LNode^.Key = AKey then begin LNode^.Value := AValue; Exit; end; LNode := LNode^.Next; end;
  New(LNode); LNode^.Key := AKey; LNode^.Value := AValue; LNode^.Next := ATable.Buckets[LIdx]; ATable.Buckets[LIdx] := LNode; Inc(ATable.Count);
end;
function ChainGet(var ATable: TChainTable; AKey: UInt64; out AValue: UInt64): Boolean;
var LIdx: Integer; LNode: PNode;
begin
  LIdx := Integer(Hash64(AKey) and UInt64(Length(ATable.Buckets) - 1));
  LNode := ATable.Buckets[LIdx];
  while LNode <> nil do begin if LNode^.Key = AKey then begin AValue := LNode^.Value; Exit(True); end; LNode := LNode^.Next; end;
  Result := False;
end;
procedure InitData;
var LI: Integer;
begin
  SetLength(GKeys, N);
  for LI := 0 to N - 1 do GKeys[LI] := UInt64(LI) * 6364136223846793005 + 1442695040888963407;
  InitTable(GTable, BUCKET_COUNT);
end;
procedure BenchPut(const ACtx: IBenchContext);
var LI: Integer;
begin
  InitTable(GTable, BUCKET_COUNT);
  for LI := 0 to N - 1 do ChainPut(GTable, GKeys[LI], UInt64(LI));
  ACtx.SetAllocs(0);
end;
procedure BenchGet(const ACtx: IBenchContext);
var LI: Integer; LVal: UInt64;
begin for LI := 0 to N - 1 do ChainGet(GTable, GKeys[LI], LVal); ACtx.SetAllocs(0); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('hashmap_fpcrtl');
  LSuite.Add('Put', @BenchPut).Add('Get', @BenchGet);
  WriteLn(LSuite.Run.PrintToConsole);
end.
