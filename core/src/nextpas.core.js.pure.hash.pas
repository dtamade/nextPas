unit nextpas.core.js.pure.hash;
{$I nextpas.core.settings.inc}
{ pure.hash — single source for FNV1a32 host/prop hash + shared bucket template (奢华收敛, L2 pure family, Owner pure.hash, 守 bytes.ops 单源, inline 零拷贝)
  收敛 pure.host HostHashView + pure.value PropHashStr 两份克隆 → 单源 JsPureHashView/JsPureHashStr via bytes.ops FNV1a32；
  阈值 16 单源 JS_PURE_HASH_THRESHOLD；几何桶 0→64→2× via bytes.ops BytesNextCapacity 单源；桶模板 Prepare/Put 单源 via open array, amortized O(1) 已收敛 PropBucketsRebuild + HostBucketsRebuild 同模板, 资源 inline 不丢。 }
interface
uses
  nextpas.core.text.view,
  nextpas.core.js.pure.base;
const
  JS_PURE_HASH_THRESHOLD = 16;
function JsPureHashView(const V: TStringView): UInt32; inline;
function JsPureHashStr(const S: string): UInt32; inline;
function JsPureBucketCapacity(AItemCount: Integer): Integer; inline;
procedure JsPureBucketsPrepare(var Buckets: TJsPureBuckets; var Mask: UInt32; var Count: Integer; ACap: Integer; AItemCount: Integer);
procedure JsPureBucketPut(var Buckets: TJsPureBuckets; AMask: UInt32; AHash: UInt32; AIndex: Integer);
// shared bucket template — threshold+capacity+prepare single source for host/prop, inline threshold, amortized O(1) via bytes.ops, candidate for future pure.hash.buckets auxiliary module
function JsPureBucketsShouldUse(AItemCount: Integer): Boolean; inline;
function JsPureBucketsTryRebuild(var Buckets: TJsPureBuckets; var Mask: UInt32; var Count: Integer; AItemCount: Integer): Boolean;
type
  TJsPureBucketHashGetter = function(AIdx: Integer; AUserData: Pointer): UInt32;
function JsPureBucketFindPos(const Buckets: TJsPureBuckets; AMask: UInt32; AHash: UInt32; AIdx: Integer): Integer;
procedure JsPureBucketDeletePosEx(var Buckets: TJsPureBuckets; AMask: UInt32; ADelPos: Integer; AItemCount: Integer; AGetHash: TJsPureBucketHashGetter; AUserData: Pointer);
implementation
uses
  nextpas.core.bytes.ops;
function JsPureHashView(const V: TStringView): UInt32; inline;
begin
  // single source FNV1a32 via bytes.ops, inline zero-copy view, no heap alloc, shared by pure.host + pure.value
  if V.Len = 0 then Exit(0);
  Result := FNV1a32(PByte(V.Data), V.Len);
end;
function JsPureHashStr(const S: string): UInt32; inline;
var V: TStringView;
begin
  // single source via JsPureHashView zero-copy, no duplicate FNV, bytes.ops single source
  if Length(S)=0 then Exit(0);
  V := TStringView.FromStr(S);
  Result := JsPureHashView(V);
end;
function JsPureBucketCapacity(AItemCount: Integer): Integer; inline;
begin
  // single source geometric via bytes.ops BytesNextCapacity 0→64→2× amortized O(1), inline
  Result := Integer(BytesNextCapacity(0, SizeUInt(AItemCount)*2));
end;
procedure JsPureBucketsPrepare(var Buckets: TJsPureBuckets; var Mask: UInt32; var Count: Integer; ACap: Integer; AItemCount: Integer);
var I: Integer;
begin
  // not inline per red-line 2 (loop + alloc pattern) — single source init -1 + mask/count, caller already SetLength(Buckets,ACap), zero-copy via open array
  for I := 0 to ACap - 1 do Buckets[I] := -1;
  Mask := UInt32(ACap - 1);
  Count := AItemCount;
end;
procedure JsPureBucketPut(var Buckets: TJsPureBuckets; AMask: UInt32; AHash: UInt32; AIndex: Integer);
var LIdx: Integer;
begin
  // inline hot path later? loop probe not inline per red-line but thin; single source linear probing open addressing
  LIdx := Integer(AHash and AMask);
  while Buckets[LIdx] <> -1 do LIdx := (LIdx + 1) and Integer(AMask);
  Buckets[LIdx] := AIndex;
end;
function JsPureBucketsShouldUse(AItemCount: Integer): Boolean; inline;
begin
  // inline threshold single source, zero alloc, shared by host/prop
  Result := AItemCount > JS_PURE_HASH_THRESHOLD;
end;
function JsPureBucketsTryRebuild(var Buckets: TJsPureBuckets; var Mask: UInt32; var Count: Integer; AItemCount: Integer): Boolean;
var LCap: Integer;
begin
  // shared template: threshold+capacity+prepare single source, amortized O(1) via bytes.ops BytesNextCapacity, host/prop deduplicated, candidate for pure.hash.buckets auxiliary module
  if AItemCount <= JS_PURE_HASH_THRESHOLD then
  begin
    SetLength(Buckets, 0);
    Mask := 0;
    Count := 0;
    Result := False;
    Exit;
  end;
  LCap := JsPureBucketCapacity(AItemCount);
  SetLength(Buckets, LCap);
  JsPureBucketsPrepare(Buckets, Mask, Count, LCap, AItemCount);
  Result := True;
end;
function JsPureBucketFindPos(const Buckets: TJsPureBuckets; AMask: UInt32; AHash: UInt32; AIdx: Integer): Integer;
var LPos, LProbe: Integer;
begin
  // single source bucket probe via pure.hash, inline zero-copy, amortized O(1), shared by prop/host delete cluster, not inline per red-line 2
  if Length(Buckets)=0 then Exit(-1);
  LPos := Integer(AHash and AMask);
  for LProbe:=0 to High(Buckets) do
  begin
    if Buckets[LPos]=AIdx then Exit(LPos);
    if Buckets[LPos]=-1 then Exit(-1);
    LPos := (LPos+1) and Integer(AMask);
  end;
  Result:=-1;
end;
procedure JsPureBucketDeletePosEx(var Buckets: TJsPureBuckets; AMask: UInt32; ADelPos: Integer; AItemCount: Integer; AGetHash: TJsPureBucketHashGetter; AUserData: Pointer);
var LCur, LRe: Integer; LHash: UInt32;
begin
  // single source cluster rehash via pure.hash, shared by prop/host, amortized O(1) incremental patch vs O(n) rebuild, bytes.ops JsPureBucketPut single source, not inline per red-line 2
  Buckets[ADelPos]:=-1;
  LCur := (ADelPos+1) and Integer(AMask);
  while Buckets[LCur]<>-1 do
  begin
    LRe := Buckets[LCur];
    if (LRe<0) or (LRe>=AItemCount) then
    begin
      Buckets[LCur]:=-1;
      LCur := (LCur+1) and Integer(AMask);
      Continue;
    end;
    if Assigned(AGetHash) then LHash := AGetHash(LRe, AUserData) else LHash := 0;
    Buckets[LCur]:=-1;
    JsPureBucketPut(Buckets, AMask, LHash, LRe);
    LCur := (LCur+1) and Integer(AMask);
  end;
end;
end.
