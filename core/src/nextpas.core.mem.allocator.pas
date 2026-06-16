{
# nextpas.core.mem.allocator

## 摘要

提供内存分配器的兼容 / 扩展聚合门面。

严格 L0 场景应优先使用 `nextpas.core.mem.allocator.foundation`。
本单元保留为便利入口，并继续聚合可选后端。

本单元所有接口完全遵守 `空操作原则`, 输入参数 `count = 0` 时, 不进行任何操作.

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.callback,
  nextpas.core.mem.allocator.mmap,
  nextpas.core.mem.allocator.mimalloc
  {$IFDEF NEXTPAS_CORE_CRT_ALLOCATOR}
  ,nextpas.core.mem.allocator.crt
  {$ENDIF}
  ;

type
  // 门面导出：接口与抽象基类（保留 IAllocator 名称于本单元，通过别名重导出）
  IAllocator = nextpas.core.mem.allocator.base.IAllocator;
  TAllocator = nextpas.core.mem.allocator.base.TAllocator;

  // 回调类型重导出（从 callback_allocator 单元）
  TGetMemCallback     = nextpas.core.mem.allocator.callback.TGetMemCallback;
  TAllocMemCallback   = nextpas.core.mem.allocator.callback.TAllocMemCallback;
  TReallocMemCallback = nextpas.core.mem.allocator.callback.TReallocMemCallback;
  TFreeMemCallback    = nextpas.core.mem.allocator.callback.TFreeMemCallback;

  // 具体分配器类型重导出
  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  {$IFDEF NEXTPAS_CORE_CRT_ALLOCATOR}
  TCrtAllocator = nextpas.core.mem.allocator.crt.TCrtAllocator;
  {$ENDIF}
  TCallbackAllocator = nextpas.core.mem.allocator.callback.TCallbackAllocator;
  TMemoryMapAllocator = nextpas.core.mem.allocator.mmap.TMemoryMapAllocator;

  // 获取/工厂函数声明（门面转发）
  function GetRtlAllocator: IAllocator;
  {$IFDEF NEXTPAS_CORE_CRT_ALLOCATOR}
  function GetCrtAllocator: IAllocator;
  {$ENDIF}
  function GetMimallocAllocator: IAllocator;
  function TryGetMimallocAllocator(out A: IAllocator): Boolean;
  function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;
  function CreateCallbackAllocator(aGetMem: TGetMemCallback;
                                   aAllocMem: TAllocMemCallback;
                                   aReallocMem: TReallocMemCallback;
                                   aFreeMem: TFreeMemCallback): TCallbackAllocator;

implementation

function GetRtlAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl.GetRtlAllocator;
end;

function GetMimallocAllocator: IAllocator; inline;
begin
  Result := nextpas.core.mem.allocator.mimalloc.GetMimallocAllocator;
end;

function TryGetMimallocAllocator(out A: IAllocator): Boolean; inline;
begin
  Result := nextpas.core.mem.allocator.mimalloc.TryGetMimallocAllocator(A);
end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;
begin
  Result := nextpas.core.mem.allocator.mmap.CreateAnonymousMemoryMapAllocator(aReservationSize);
end;

{$IFDEF NEXTPAS_CORE_CRT_ALLOCATOR}
function GetCrtAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.crt.GetCrtAllocator;
end;
{$ENDIF}


function CreateCallbackAllocator(aGetMem: TGetMemCallback;
  aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback): TCallbackAllocator;
begin
  Result := nextpas.core.mem.allocator.callback.CreateCallbackAllocator(aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

end.
