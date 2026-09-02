unit nextpas.core.js.pure.hash;
{$I nextpas.core.settings.inc}
{ pure.hash — single source for FNV1a32 host/prop hash + shared bucket template (奢华收敛, L2 pure family, Owner pure.hash, 守 bytes.ops 单源, inline 零拷贝)
  收敛 pure.host HostHashView + pure.value PropHashStr 两份克隆 → 单源 JsPureHashView/JsPureHashStr via bytes.ops FNV1a32；
  阈值 64 单源 JS_PURE_HASH_THRESHOLD；几何桶 0→64→2× via bytes.ops BytesNextCapacity 单源；桶模板 Prepare/Put 单源 via open array, amortized O(1) 已收敛 PropBucketsRebuild + HostBucketsRebuild 同模板, 资源 inline 不丢。 }
interface
uses
  nextpas.core.text.view;
const
  JS_PURE_HASH_THRESHOLD = 64;
  JS_PURE_HOST_THRESHOLD = JS_PURE_HASH_THRESHOLD; // alias for host compat, single source
  JS_PURE_HEAP_HASH_THRESHOLD = JS_PURE_HASH_THRESHOLD; // alias for heap compat, single source
function JsPureHashView(const V: TStringView): UInt32; inline;
function JsPureHashStr(const S: string): UInt32; inline;
function JsPureBucketCapacity(AItemCount: Integer): Integer; inline;
procedure JsPureBucketsPrepare(var Buckets: array of Integer; var Mask: UInt32; var Count: Integer; ACap: Integer; AItemCount: Integer);
procedure JsPureBucketPut(var Buckets: array of Integer; AMask: UInt32; AHash: UInt32; AIndex: Integer);
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
procedure JsPureBucketsPrepare(var Buckets: array of Integer; var Mask: UInt32; var Count: Integer; ACap: Integer; AItemCount: Integer);
var I: Integer;
begin
  // not inline per red-line 2 (loop + alloc pattern) — single source init -1 + mask/count, caller already SetLength(Buckets,ACap), zero-copy via open array
  for I := 0 to ACap - 1 do Buckets[I] := -1;
  Mask := UInt32(ACap - 1);
  Count := AItemCount;
end;
procedure JsPureBucketPut(var Buckets: array of Integer; AMask: UInt32; AHash: UInt32; AIndex: Integer);
var LIdx: Integer;
begin
  // inline hot path later? loop probe not inline per red-line but thin; single source linear probing open addressing
  LIdx := Integer(AHash and AMask);
  while Buckets[LIdx] <> -1 do LIdx := (LIdx + 1) and Integer(AMask);
  Buckets[LIdx] := AIndex;
end;
end.
