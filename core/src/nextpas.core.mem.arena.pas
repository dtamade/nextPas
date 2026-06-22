unit nextpas.core.mem.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.arena.concurrent;

type
  {** Arena 标记 }
  TArenaMark = nextpas.core.mem.arena.base.TArenaMark;
  {** Arena 增长策略 }
  TArenaGrowthKind = nextpas.core.mem.arena.base.TArenaGrowthKind;
  {** Arena 统计信息 }
  TArenaStats = nextpas.core.mem.arena.base.TArenaStats;
  {** Arena 配置 }
  TArenaConfig = nextpas.core.mem.arena.base.TArenaConfig;

  {** IArena 接口 }
  IArena = nextpas.core.mem.arena.intf.IArena;

  {** 固定容量 Arena }
  TLocalArena = nextpas.core.mem.arena.local.TLocalArena;
  {** 分段可增长 Arena }
  TChunkedArena = nextpas.core.mem.arena.chunked.TChunkedArena;
  {** 预留虚拟地址空间 Arena }
  TVirtualArena = nextpas.core.mem.arena.virtual.TVirtualArena;
  {** 线程安全 Arena 包装 }
  TArenaConcurrent = nextpas.core.mem.arena.concurrent.TArenaConcurrent;

{** 初始化 TVirtualArena }
procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt = ARENA_DEFAULT_ALIGNMENT);
{** 释放 TVirtualArena 所有资源 }
procedure TVirtualArena_Release(var AArena: TVirtualArena);

implementation

procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt);
begin
  nextpas.core.mem.arena.virtual.TVirtualArena_Init(AArena, AAlignment);
end;

procedure TVirtualArena_Release(var AArena: TVirtualArena);
begin
  nextpas.core.mem.arena.virtual.TVirtualArena_Release(AArena);
end;

end.
