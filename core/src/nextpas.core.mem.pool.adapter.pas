{
  nextpas.core.mem.pool.adapter

  Deprecated compatibility shim.
  The adapter implementations now live in nextpas.core.mem.compat.
}

unit nextpas.core.mem.pool.adapter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.compat;

type
  TMemPoolToBlockPoolAdapter = nextpas.core.mem.compat.TMemPoolToBlockPoolAdapter deprecated 'Use nextpas.core.mem.compat.TMemPoolToBlockPoolAdapter instead';
  TBlockPoolToMemPoolAdapter = nextpas.core.mem.compat.TBlockPoolToMemPoolAdapter deprecated 'Use nextpas.core.mem.compat.TBlockPoolToMemPoolAdapter instead';
  TStackPoolToArenaAdapter = nextpas.core.mem.compat.TStackPoolToArenaAdapter deprecated 'Use nextpas.core.mem.compat.TStackPoolToArenaAdapter instead';
  TArenaToStackPoolAdapter = nextpas.core.mem.compat.TArenaToStackPoolAdapter deprecated 'Use nextpas.core.mem.compat.TArenaToStackPoolAdapter instead';

function WrapAsBlockPool(aPool: nextpas.core.mem.compat.IMemPool): nextpas.core.mem.compat.IBlockPool;
  deprecated 'Use nextpas.core.mem.compat.WrapAsBlockPool instead';
function WrapAsMemPool(aPool: nextpas.core.mem.compat.IBlockPool): nextpas.core.mem.compat.IMemPool;
  deprecated 'Use nextpas.core.mem.compat.WrapAsMemPool instead';
function WrapAsArena(aPool: nextpas.core.mem.compat.IStackPool): nextpas.core.mem.compat.IArena;
  deprecated 'Use nextpas.core.mem.compat.WrapAsArena instead';
function WrapAsStackPool(aArena: nextpas.core.mem.compat.IArena): nextpas.core.mem.compat.IStackPool;
  deprecated 'Use nextpas.core.mem.compat.WrapAsStackPool instead';

{$WARNING 'nextpas.core.mem.pool.adapter is deprecated: use nextpas.core.mem.compat'}

implementation

function WrapAsBlockPool(aPool: nextpas.core.mem.compat.IMemPool): nextpas.core.mem.compat.IBlockPool;
begin
  Result := nextpas.core.mem.compat.WrapAsBlockPool(aPool);
end;

function WrapAsMemPool(aPool: nextpas.core.mem.compat.IBlockPool): nextpas.core.mem.compat.IMemPool;
begin
  Result := nextpas.core.mem.compat.WrapAsMemPool(aPool);
end;

function WrapAsArena(aPool: nextpas.core.mem.compat.IStackPool): nextpas.core.mem.compat.IArena;
begin
  Result := nextpas.core.mem.compat.WrapAsArena(aPool);
end;

function WrapAsStackPool(aArena: nextpas.core.mem.compat.IArena): nextpas.core.mem.compat.IStackPool;
begin
  Result := nextpas.core.mem.compat.WrapAsStackPool(aArena);
end;

end.
