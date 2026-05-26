unit nextpas.core.mem.pool.fixed_slab;

{$GOTO ON}  // nginx 移植代码使用 goto 控制流
{$I nextpas.core.settings.inc}
{.$define FAFAFA_SLAB_TESTGUARD} // enable when diagnosing

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in slab internals

interface

uses
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base;

type
  {$IFDEF FAFAFA_CORE_SLAB_STATS}
  TFixedSlabSlotStat = record
    total: SizeUInt;
    used: SizeUInt;
    reqs: SizeUInt;
    fails: SizeUInt;
  end;
  TFixedSlabStats = record
    TotalPages: SizeUInt;
    FreePages: SizeUInt;
    SlotCount: SizeUInt;
  end;
  {$ENDIF}

  IFixedSlabPool = interface(IMemoryPool)
    ['{0C89D0E7-601B-49E1-92B0-6ED38E319A11}']

    function GetCapacity: SizeUInt;
    function GetUsed: SizeUInt;
    {$IFDEF FAFAFA_CORE_SLAB_STATS}
    function GetStats: TFixedSlabStats;
    function GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
    {$ENDIF}

    property Capacity: SizeUInt read GetCapacity;
    property Used: SizeUInt read GetUsed;
  end;

  TFixedSlabPool = class(TInterfacedObject, IFixedSlabPool, IMemoryPool, IAllocator)
  private
    // Fields first
    FAllocator: IAllocator;
    FRaw: Pointer;        // 原始分配指针（释放用）
    FBase: PByte;         // 区域基址（也是 pool header 地址）
    FRegionEnd: PByte;    // 区域结束地址（传给 pool^.endp）
    FSize: SizeUInt;      // 数据区容量（endp - start）
    FMinShift: SizeUInt;  // 最小阶（默认 3 -> 8B）
    FCore: Pointer;       // 指向 pool header（等于 FBase）

    // Private helpers
    {$IFDEF FAFAFA_CORE_SLAB_STATS}
    function GetStats: TFixedSlabStats; inline;
    function GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat; inline;
    function BuildStats: TFixedSlabStats;
    function BuildSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
    {$ENDIF}
    function ChunkSizeOf(APtr: Pointer): SizeUInt;

  public
    constructor Create(ACapacity: SizeUInt; AAllocator: IAllocator = nil; AMinShift: SizeUInt = 3);
    destructor Destroy; override;

    function Acquire(out AUnit: Pointer): Boolean;
    function TryAcquire(out AUnit: Pointer): Boolean; inline;
    function AcquireN(out AUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(AUnit: Pointer);
    procedure ReleaseN(const AUnits: array of Pointer; aCount: Integer);
    procedure Reset;

    function GetCapacity: SizeUInt;
    function GetUsed: SizeUInt;

    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);

    // IAllocator aligned allocation (fallback to GetMem with size class alignment)
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);

    // IAllocator capability
    function Traits: TAllocatorTraits;

    // Public helper for callers needing old block size
    function MemSizeOf(APtr: Pointer): SizeUInt;

    // Helpers for segment management
    function Owns(aPtr: Pointer): Boolean;
    function PageShift: SizeUInt; inline;
    function RegionStart: PByte; inline;
    function RegionEnd: PByte; inline;

    property Capacity: SizeUInt read GetCapacity;
    property Used: SizeUInt read GetUsed;
  end;


implementation

// nginx slab 字节级移植 - 常量定义
const
  NGX_SLAB_PAGE_SIZE  = 4096;
  NGX_SLAB_PAGE_SHIFT = 12;

  NGX_SLAB_PAGE_MASK   = 3;
  NGX_SLAB_PAGE        = 0;
  NGX_SLAB_BIG         = 1;
  NGX_SLAB_EXACT       = 2;
  NGX_SLAB_SMALL       = 3;

{$if SizeOf(PtrUInt)=4}
const
  NGX_SLAB_PAGE_FREE   = PtrUInt(0);
  NGX_SLAB_PAGE_BUSY   = PtrUInt($FFFFFFFF);
  NGX_SLAB_PAGE_START  = PtrUInt($80000000);
  NGX_SLAB_SHIFT_MASK  = PtrUInt($0000000F);
  NGX_SLAB_MAP_MASK    = PtrUInt($FFFF0000);
  NGX_SLAB_MAP_SHIFT   = 16;
  NGX_SLAB_BUSY        = PtrUInt($FFFFFFFF);
{$else}
const
  NGX_SLAB_PAGE_FREE   = PtrUInt(0);
  NGX_SLAB_PAGE_BUSY   = PtrUInt($FFFFFFFFFFFFFFFF);
  NGX_SLAB_PAGE_START  = PtrUInt($8000000000000000);
  NGX_SLAB_SHIFT_MASK  = PtrUInt($000000000000000F);
  NGX_SLAB_MAP_MASK    = PtrUInt($FFFFFFFF00000000);
  NGX_SLAB_MAP_SHIFT   = 32;
  NGX_SLAB_BUSY        = PtrUInt($FFFFFFFFFFFFFFFF);
{$endif}

{$IFDEF FAFAFA_SLAB_TESTGUARD}
procedure SlabDbg(const s: AnsiString);
var f: Text;
begin
  {$I-}
  AssignFile(f, 'slab_debug.log');
  Append(f);
  if IOResult <> 0 then Rewrite(f);
  Writeln(f, s);
  CloseFile(f);
  {$I+}
end;

function NumU(u: PtrUInt): AnsiString;
var t: AnsiString;
begin
  Str(u, t);
  Result := t;
end;
{$ENDIF}

// nginx slab 字节级移植 - 数据结构
type
  Pngx_slab_page_t = ^ngx_slab_page_t;
  ngx_slab_page_t = record
    slab: PtrUInt;
    next: Pngx_slab_page_t;
    prev: PtrUInt;
  end;

  Pngx_slab_stat_t = ^ngx_slab_stat_t;
  ngx_slab_stat_t = record
    total: SizeUInt;
    used: SizeUInt;
    reqs: SizeUInt;
    fails: SizeUInt;
  end;

  Pngx_slab_pool_t = ^ngx_slab_pool_t;
  ngx_slab_pool_t = record
    // 注意：我们跳过 lock 字段，因为我们不需要多线程支持
    min_size: SizeUInt;
    min_shift: SizeUInt;

    pages: Pngx_slab_page_t;
    last: Pngx_slab_page_t;
    free: ngx_slab_page_t;

    stats: Pngx_slab_stat_t;
    pfree: SizeUInt;

    start: PByte;
    endp: PByte;  // 保持 endp 名称以避免与 Pascal 关键字冲突
    // 注意：我们跳过 mutex, log_ctx, zero, log_nomem, data, addr 字段
  end;


// nginx slab 字节级移植 - 全局变量和辅助函数

// nginx 调试宏
{$IFDEF DEBUG}
procedure ngx_slab_junk(p: Pointer; size: SizeUInt); inline;
begin
  if (p <> nil) and (size > 0) then
    FillChar(p^, size, $A5);
end;
{$ELSE}
procedure ngx_slab_junk(p: Pointer; size: SizeUInt); inline;
begin
  // no-op
end;
{$ENDIF}

// nginx 全局变量（线程安全一次性初始化）
var
  ngx_slab_sizes_initialized: LongInt = 0;  // 0=未初始化, 1=已初始化
  ngx_slab_max_size: SizeUInt = 0;
  ngx_slab_exact_size: SizeUInt = 0;
  ngx_slab_exact_shift: SizeUInt = 0;
  ngx_pagesize: SizeUInt = NGX_SLAB_PAGE_SIZE;
  ngx_pagesize_shift: SizeUInt = NGX_SLAB_PAGE_SHIFT;

// nginx 宏定义转换为内联函数
function ngx_slab_slots(pool: Pngx_slab_pool_t): Pngx_slab_page_t; inline;
begin
  Result := Pngx_slab_page_t(PByte(pool) + SizeOf(ngx_slab_pool_t));
end;

function ngx_slab_page_type(page: Pngx_slab_page_t): PtrUInt; inline;
begin
  Result := page^.prev and NGX_SLAB_PAGE_MASK;
end;

function ngx_slab_page_prev(page: Pngx_slab_page_t): Pngx_slab_page_t; inline;
begin
  Result := Pngx_slab_page_t(page^.prev and not NGX_SLAB_PAGE_MASK);
end;

function ngx_slab_page_addr(pool: Pngx_slab_pool_t; page: Pngx_slab_page_t): PtrUInt; inline;
begin
  Result := ((PtrUInt(page) - PtrUInt(pool^.pages)) div SizeOf(ngx_slab_page_t)) shl ngx_pagesize_shift;
  Result := Result + PtrUInt(pool^.start);
end;

// nginx 辅助函数
function ngx_align_ptr(p: PByte; a: SizeUInt): PByte; inline;
begin
  Result := PByte((PtrUInt(p) + (a - 1)) and not (a - 1));
end;

// ngx_slab_sizes_init 的字节级移植（线程安全一次性初始化）
procedure ngx_slab_sizes_init;
var
  n: SizeUInt;
begin
  // ✅ 线程安全：只有第一个线程会执行初始化
  if InterlockedCompareExchange(ngx_slab_sizes_initialized, 1, 0) <> 0 then
    Exit;  // 已初始化，直接返回

  ngx_slab_max_size := ngx_pagesize div 2;
  ngx_slab_exact_size := ngx_pagesize div (8 * SizeOf(PtrUInt));
  ngx_slab_exact_shift := 0;
  n := ngx_slab_exact_size;
  while n > 1 do
  begin
    n := n shr 1;
    Inc(ngx_slab_exact_shift);
  end;
end;

// ngx_slab_init 的字节级移植
procedure ngx_slab_init(pool: Pngx_slab_pool_t);
var
  p: PByte;
  size: SizeUInt;
  m: SizeInt;
  i, n, pages: SizeUInt;
  slots, page: Pngx_slab_page_t;
begin
  pool^.min_size := SizeUInt(1) shl pool^.min_shift;

  slots := ngx_slab_slots(pool);

  p := PByte(slots);
  size := PtrUInt(pool^.endp) - PtrUInt(p);

  ngx_slab_junk(p, size);

  n := ngx_pagesize_shift - pool^.min_shift;

  for i := 0 to n - 1 do
  begin
    // only "next" is used in list head
    slots[i].slab := 0;
    slots[i].next := @slots[i];
    slots[i].prev := 0;
  end;

  Inc(p, n * SizeOf(ngx_slab_page_t));

  pool^.stats := Pngx_slab_stat_t(p);
  FillChar(pool^.stats^, n * SizeOf(ngx_slab_stat_t), 0);

  Inc(p, n * SizeOf(ngx_slab_stat_t));

  Dec(size, n * (SizeOf(ngx_slab_page_t) + SizeOf(ngx_slab_stat_t)));

  pages := size div (ngx_pagesize + SizeOf(ngx_slab_page_t));

  pool^.pages := Pngx_slab_page_t(p);
  FillChar(pool^.pages^, pages * SizeOf(ngx_slab_page_t), 0);

  page := pool^.pages;

  // only "next" is used in list head
  pool^.free.slab := 0;
  pool^.free.next := page;
  pool^.free.prev := 0;

  page^.slab := pages;
  page^.next := @pool^.free;
  page^.prev := PtrUInt(@pool^.free);

  pool^.start := ngx_align_ptr(p + pages * SizeOf(ngx_slab_page_t), ngx_pagesize);

  m := SizeInt(pages) - SizeInt((PtrUInt(pool^.endp) - PtrUInt(pool^.start)) div ngx_pagesize);
  if m > 0 then
  begin
    Dec(pages, SizeUInt(m));
    page^.slab := pages;
  end;

  pool^.last := pool^.pages + pages;
  pool^.pfree := pages;
end;

// ngx_slab_alloc_pages 的字节级移植
function ngx_slab_alloc_pages(pool: Pngx_slab_pool_t; pages: SizeUInt): Pngx_slab_page_t;
var
  page, p: Pngx_slab_page_t;
  remaining_pages: SizeUInt;
begin
  Result := nil;
  page := pool^.free.next;

  while page <> @pool^.free do
  begin
    if page^.slab >= pages then
    begin
      if page^.slab > pages then
      begin
        // 分割页面
        remaining_pages := page^.slab - pages;
        page[page^.slab - 1].prev := PtrUInt(@page[pages]);

        page[pages].slab := remaining_pages;
        page[pages].next := page^.next;
        page[pages].prev := page^.prev;

        p := Pngx_slab_page_t(page^.prev);
        p^.next := @page[pages];
        page^.next^.prev := PtrUInt(@page[pages]);
      end
      else
      begin
        // 完全使用这个页面块
        p := Pngx_slab_page_t(page^.prev);
        p^.next := page^.next;
        page^.next^.prev := page^.prev;
      end;

      page^.slab := pages or NGX_SLAB_PAGE_START;
      page^.next := nil;
      page^.prev := NGX_SLAB_PAGE;

      Dec(pool^.pfree, pages);

      Dec(pages);
      if pages = 0 then
      begin
        Result := page;
        Exit;
      end;

      // 标记后续页面
      p := page + 1;
      while pages > 0 do
      begin
        p^.slab := NGX_SLAB_PAGE_BUSY;
        p^.next := nil;
        p^.prev := NGX_SLAB_PAGE;
        Inc(p);
        Dec(pages);
      end;

      Result := page;
      Exit;
    end;

    page := page^.next;
  end;

  // 没有足够的内存
  Result := nil;
end;

// ngx_slab_free_pages 的字节级移植
procedure ngx_slab_free_pages(pool: Pngx_slab_pool_t; page: Pngx_slab_page_t; pages: SizeUInt);
var
  prev, join: Pngx_slab_page_t;
  original_pages: SizeUInt;
begin
  Inc(pool^.pfree, pages);

  original_pages := pages;
  page^.slab := pages;
  Dec(pages);

  if pages > 0 then
    FillChar(page[1], pages * SizeOf(ngx_slab_page_t), 0);

  if page^.next <> nil then
  begin
    prev := ngx_slab_page_prev(page);
    prev^.next := page^.next;
    page^.next^.prev := page^.prev;
  end;

  join := page + page^.slab;

  if PtrUInt(join) < PtrUInt(pool^.last) then
  begin
    if ngx_slab_page_type(join) = NGX_SLAB_PAGE then
    begin
      if join^.next <> nil then
      begin
        Inc(original_pages, join^.slab);
        Inc(page^.slab, join^.slab);

        prev := ngx_slab_page_prev(join);
        prev^.next := join^.next;
        join^.next^.prev := join^.prev;

        join^.slab := NGX_SLAB_PAGE_FREE;
        join^.next := nil;
        join^.prev := NGX_SLAB_PAGE;
      end;
    end;
  end;

  if PtrUInt(page) > PtrUInt(pool^.pages) then
  begin
    join := page - 1;

    if ngx_slab_page_type(join) = NGX_SLAB_PAGE then
    begin
      if join^.slab = NGX_SLAB_PAGE_FREE then
        join := ngx_slab_page_prev(join);

      if join^.next <> nil then
      begin
        Inc(original_pages, join^.slab);
        Inc(join^.slab, page^.slab);

        prev := ngx_slab_page_prev(join);
        prev^.next := join^.next;
        join^.next^.prev := join^.prev;

        page^.slab := NGX_SLAB_PAGE_FREE;
        page^.next := nil;
        page^.prev := NGX_SLAB_PAGE;

        page := join;
      end;
    end;
  end;

  if original_pages > 1 then
    page[original_pages - 1].prev := PtrUInt(page);

  page^.prev := PtrUInt(@pool^.free);
  page^.next := pool^.free.next;

  page^.next^.prev := PtrUInt(page);

  pool^.free.next := page;
end;

// ngx_slab_alloc_locked 的字节级移植
function ngx_slab_alloc_locked(pool: Pngx_slab_pool_t; size: SizeUInt): Pointer;
var
  p, m, mask: PtrUInt;
  bitmap: ^PtrUInt;
  i, n, slot, shift, map: SizeUInt;
  page, prev, slots: Pngx_slab_page_t;
label
  done;
begin
  Result := nil;

  if size >= ngx_slab_max_size then
  begin
    // 大块分配
    page := ngx_slab_alloc_pages(pool, (size shr ngx_pagesize_shift) +
                                       Ord((size and (ngx_pagesize - 1)) <> 0));
    if page <> nil then
      p := ngx_slab_page_addr(pool, page)
    else
      p := 0;

    goto done;
  end;

  // 计算 slot：shift 为最小的使 (1 shl shift) >= size 的值
  if size > pool^.min_size then
  begin
    shift := pool^.min_shift;
    while (SizeUInt(1) shl shift) < size do
      Inc(shift);
    slot := shift - pool^.min_shift;
  end
  else
  begin
    shift := pool^.min_shift;
    slot := 0;
  end;

  Inc(pool^.stats[slot].reqs);

  slots := ngx_slab_slots(pool);
  page := slots[slot].next;

  if page^.next <> page then
  begin
    // 复用现有页面
    if shift < ngx_slab_exact_shift then
    begin
      // small 路径
      bitmap := Pointer(ngx_slab_page_addr(pool, page));

      map := (ngx_pagesize shr shift) div (8 * SizeOf(PtrUInt));

      for n := 0 to map - 1 do
      begin
        if bitmap[n] <> NGX_SLAB_BUSY then
        begin
          m := 1;
          i := 0;
          while (m <> 0) and ((bitmap[n] and m) <> 0) do
          begin
            m := m shl 1;
            Inc(i);
          end;

          bitmap[n] := bitmap[n] or m;

          i := (n * 8 * SizeOf(PtrUInt) + i) shl shift;
          p := PtrUInt(bitmap) + i;

          Inc(pool^.stats[slot].used);

          if bitmap[n] = NGX_SLAB_BUSY then
          begin
            // 检查页面是否全满
            i := n + 1;
            while i <= map - 1 do
            begin
              if bitmap[i] <> NGX_SLAB_BUSY then
                goto done;
              Inc(i);
            end;

            // 页面全满，从链表中移除
            prev := ngx_slab_page_prev(page);
            prev^.next := page^.next;
            page^.next^.prev := page^.prev;

            page^.next := nil;
            page^.prev := NGX_SLAB_SMALL;
          end;

          goto done;
        end;
      end;
    end
    else if shift = ngx_slab_exact_shift then
    begin
      // exact 路径
      m := 1;
      i := 0;
      while m <> 0 do
      begin
        if (page^.slab and m) <> 0 then
        begin
          m := m shl 1;
          Inc(i);
          continue;
        end;

        page^.slab := page^.slab or m;

        if page^.slab = NGX_SLAB_BUSY then
        begin
          prev := ngx_slab_page_prev(page);
          prev^.next := page^.next;
          page^.next^.prev := page^.prev;

          page^.next := nil;
          page^.prev := NGX_SLAB_EXACT;
        end;

        p := ngx_slab_page_addr(pool, page) + (i shl shift);

        Inc(pool^.stats[slot].used);

        goto done;
      end;
    end
    else
    begin
      // big 路径 (shift > ngx_slab_exact_shift)
      mask := (PtrUInt(1) shl (ngx_pagesize shr shift)) - 1;
      mask := mask shl NGX_SLAB_MAP_SHIFT;

      m := PtrUInt(1) shl NGX_SLAB_MAP_SHIFT;
      i := 0;
      while (m and mask) <> 0 do
      begin
        if (page^.slab and m) <> 0 then
        begin
          m := m shl 1;
          Inc(i);
          continue;
        end;

        page^.slab := page^.slab or m;

        if (page^.slab and NGX_SLAB_MAP_MASK) = mask then
        begin
          prev := ngx_slab_page_prev(page);
          prev^.next := page^.next;
          page^.next^.prev := page^.prev;

          page^.next := nil;
          page^.prev := NGX_SLAB_BIG;
        end;

        p := ngx_slab_page_addr(pool, page) + (i shl shift);

        Inc(pool^.stats[slot].used);

        goto done;
      end;
    end;

    // 页面已满，但这不应该发生
    // ngx_slab_error(pool, NGX_LOG_ALERT, "ngx_slab_alloc(): page is busy");
  end;

  // 分配新页面
  page := ngx_slab_alloc_pages(pool, 1);

  if page <> nil then
  begin
    if shift < ngx_slab_exact_shift then
    begin
      // small 路径新页面
      bitmap := Pointer(ngx_slab_page_addr(pool, page));

      n := (ngx_pagesize shr shift) div ((SizeUInt(1) shl shift) * 8);
      if n = 0 then n := 1;

      // "n" elements for bitmap, plus one requested
      // 严格按照 nginx C 代码逻辑
      i := 0;
      while i < (n + 1) div (8 * SizeOf(PtrUInt)) do
      begin
        bitmap[i] := NGX_SLAB_BUSY;
        Inc(i);
      end;
      // 现在 i 的值等于 (n + 1) div (8 * SizeOf(PtrUInt))

      m := (PtrUInt(1) shl ((n + 1) mod (8 * SizeOf(PtrUInt)))) - 1;
      bitmap[i] := m;

      map := (ngx_pagesize shr shift) div (8 * SizeOf(PtrUInt));
      Inc(i);
      while i < map do
      begin
        bitmap[i] := 0;
        Inc(i);
      end;

      page^.slab := shift;
      page^.next := @slots[slot];
      page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_SMALL;

      slots[slot].next := page;

      Inc(pool^.stats[slot].total, (ngx_pagesize shr shift) - n);

      p := ngx_slab_page_addr(pool, page) + (n shl shift);

      Inc(pool^.stats[slot].used);

      goto done;
    end
    else if shift = ngx_slab_exact_shift then
    begin
      // exact 路径新页面
      page^.slab := 1;
      page^.next := @slots[slot];
      page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_EXACT;

      slots[slot].next := page;

      Inc(pool^.stats[slot].total, 8 * SizeOf(PtrUInt));

      p := ngx_slab_page_addr(pool, page);

      Inc(pool^.stats[slot].used);

      goto done;
    end
    else
    begin
      // big 路径新页面
      page^.slab := (PtrUInt(1) shl NGX_SLAB_MAP_SHIFT) or shift;
      page^.next := @slots[slot];
      page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_BIG;

      slots[slot].next := page;

      Inc(pool^.stats[slot].total, ngx_pagesize shr shift);

      p := ngx_slab_page_addr(pool, page);

      Inc(pool^.stats[slot].used);

      goto done;
    end;
  end;

  // 分配失败
  p := 0;
  Inc(pool^.stats[slot].fails);

done:
  Result := Pointer(p);
end;

// ngx_slab_free_locked 的字节级移植
procedure ngx_slab_free_locked(pool: Pngx_slab_pool_t; p: Pointer);
var
  size: SizeUInt;
  slab, m: PtrUInt;
  bitmap: PPtrUInt;
  i, n, page_type, slot, shift, map: SizeUInt;
  slots, page: Pngx_slab_page_t;
label
  done;
begin
  // 边界检查
  if (PByte(p) < pool^.start) or (PByte(p) >= pool^.endp) then
    Exit;

  n := (PtrUInt(p) - PtrUInt(pool^.start)) shr ngx_pagesize_shift;
  page := @pool^.pages[n];
  slab := page^.slab;
  page_type := ngx_slab_page_type(page);

  {$IFDEF FAFAFA_SLAB_TESTGUARD}
  WriteLn('[Free] p=', PtrUInt(p):16, ', n=', n, ', page_type=', page_type, ', slab=', slab:16);
  {$ENDIF}

  case page_type of
    NGX_SLAB_SMALL:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      size := SizeUInt(1) shl shift;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit; // wrong_chunk

      n := (PtrUInt(p) and (ngx_pagesize - 1)) shr shift;
      m := PtrUInt(1) shl (n mod (8 * SizeOf(PtrUInt)));
      n := n div (8 * SizeOf(PtrUInt));
      bitmap := PPtrUInt(PtrUInt(p) and not (PtrUInt(ngx_pagesize) - 1));

      if (bitmap[n] and m) <> 0 then
      begin
        slot := shift - pool^.min_shift;

        // reinstate to slots list if it was removed when fully busy
        if page^.next = nil then
        begin
          slots := ngx_slab_slots(pool);

          page^.next := slots[slot].next;
          slots[slot].next := page;

          page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_SMALL;
          page^.next^.prev := PtrUInt(page) or NGX_SLAB_SMALL;
        end;

        bitmap[n] := bitmap[n] and not m;

        n := (ngx_pagesize shr shift) div ((SizeUInt(1) shl shift) * 8);
        if n = 0 then n := 1;

        i := n div (8 * SizeOf(PtrUInt));
        m := (PtrUInt(1) shl (n mod (8 * SizeOf(PtrUInt)))) - 1;

        if (bitmap[i] and not m) <> 0 then
          goto done;

        map := (ngx_pagesize shr shift) div (8 * SizeOf(PtrUInt));

        for i := i + 1 to map - 1 do
        begin
          if bitmap[i] <> 0 then
            goto done;
        end;

        ngx_slab_free_pages(pool, page, 1);
        Dec(pool^.stats[slot].total, (ngx_pagesize shr shift) - n);

        goto done;
      end;
      // chunk_already_free - 忽略
    end;

    NGX_SLAB_EXACT:
    begin
      m := PtrUInt(1) shl ((PtrUInt(p) and (ngx_pagesize - 1)) shr ngx_slab_exact_shift);
      size := ngx_slab_exact_size;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit; // wrong_chunk

      if (slab and m) <> 0 then
      begin
        slot := ngx_slab_exact_shift - pool^.min_shift;


        // reinstate to slots list if it was removed when fully busy
        if page^.next = nil then
        begin
          slots := ngx_slab_slots(pool);

          page^.next := slots[slot].next;
          slots[slot].next := page;

          page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_EXACT;
          page^.next^.prev := PtrUInt(page) or NGX_SLAB_EXACT;
        end;

        page^.slab := page^.slab and not m;

        if page^.slab <> 0 then
          goto done;

        ngx_slab_free_pages(pool, page, 1);
        Dec(pool^.stats[slot].total, 8 * SizeOf(PtrUInt));

        goto done;
      end;
      // chunk_already_free - 忽略
    end;

    NGX_SLAB_BIG:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      size := SizeUInt(1) shl shift;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit; // wrong_chunk

      m := PtrUInt(1) shl (((PtrUInt(p) and (ngx_pagesize - 1)) shr shift) + NGX_SLAB_MAP_SHIFT);

      if (slab and m) <> 0 then
      begin
        slot := shift - pool^.min_shift;

        // reinstate to slots list if it was removed when fully busy
        if page^.next = nil then
        begin
          slots := ngx_slab_slots(pool);

          page^.next := slots[slot].next;
          slots[slot].next := page;

          page^.prev := PtrUInt(@slots[slot]) or NGX_SLAB_BIG;
          page^.next^.prev := PtrUInt(page) or NGX_SLAB_BIG;
        end;

        page^.slab := page^.slab and not m;

        if (page^.slab and NGX_SLAB_MAP_MASK) <> 0 then
          goto done;

        ngx_slab_free_pages(pool, page, 1);
        Dec(pool^.stats[slot].total, ngx_pagesize shr shift);

        goto done;
      end;
      // chunk_already_free - 忽略
    end;

    NGX_SLAB_PAGE:
    begin
      if (PtrUInt(p) and (ngx_pagesize - 1)) <> 0 then
        Exit; // wrong_chunk

      // 必须是起始页，且不能是 BUSY 标记
      if (slab and NGX_SLAB_PAGE_START) = 0 then
        Exit; // page is already free or pointer to wrong page

      if slab = NGX_SLAB_PAGE_BUSY then
        Exit; // pointer to wrong page

      size := slab and not NGX_SLAB_PAGE_START;

      ngx_slab_free_pages(pool, page, size);
      ngx_slab_junk(p, size shl ngx_pagesize_shift);

      Exit; // 注意：page 路径不调整 slot 统计
    end;
  end;

  Exit; // 错误情况

done:
  Dec(pool^.stats[slot].used);
end;

// 所有旧的 slab 函数已删除，使用 nginx 移植版本

{ TFixedSlabPool }
constructor TFixedSlabPool.Create(ACapacity: SizeUInt; AAllocator: IAllocator; AMinShift: SizeUInt);
var
  n: SizeUInt;
  desired_pages: SizeUInt;
  overhead_base: SizeUInt;
  per_page_cost: SizeUInt;
  total_size: SizeUInt;
begin
  inherited Create;

  if AAllocator = nil then
    FAllocator := nextpas.core.mem.allocator.GetRtlAllocator
  else
    FAllocator := AAllocator;

  if ACapacity = 0 then
    Exit;

  // Initialize nginx globals for sizes
  FMinShift := AMinShift;
  ngx_slab_sizes_init;

  // We must allocate ONE contiguous region for:
  // [ ngx_slab_pool_t | slots[n] | stats[n] | pages[?] | data pages ]
  // so that ngx_slab_init() can carve out structures like nginx does.
  // Compute conservative total size to ensure at least ACapacity data bytes.
  // n = number of slots (and stats)
  n := NGX_SLAB_PAGE_SHIFT - FMinShift;
  desired_pages := (ACapacity + NGX_SLAB_PAGE_SIZE - 1) div NGX_SLAB_PAGE_SIZE;
  overhead_base := SizeOf(ngx_slab_pool_t) + n * (SizeOf(ngx_slab_page_t) + SizeOf(ngx_slab_stat_t));
  // total per-page cost inside the region = page descriptor + one page
  per_page_cost := SizeOf(ngx_slab_page_t) + NGX_SLAB_PAGE_SIZE;
  total_size := overhead_base + desired_pages * per_page_cost + NGX_SLAB_PAGE_SIZE; // add one page slack

  // Allocate and align the region
  FRaw := FAllocator.GetMem(total_size + (NGX_SLAB_PAGE_SIZE - 1));
  if FRaw = nil then Exit;

  // Pool header will live at aligned base
  FBase := ngx_align_ptr(PByte(FRaw), NGX_SLAB_PAGE_SIZE);
  FCore := FBase; // pool header at start of region

  // Set pool fields for init(). endp is end of region
  Pngx_slab_pool_t(FCore)^.min_shift := FMinShift;
  FRegionEnd := FBase + total_size;
  Pngx_slab_pool_t(FCore)^.endp := FRegionEnd;
  // start will be decided by ngx_slab_init based on pages table and alignment

  ngx_slab_init(Pngx_slab_pool_t(FCore));

  // After init, compute usable data capacity (endp - start)
  FSize := PtrUInt(Pngx_slab_pool_t(FCore)^.endp) - PtrUInt(Pngx_slab_pool_t(FCore)^.start);
end;

destructor TFixedSlabPool.Destroy;
begin
  // In the current design, FCore points inside the aligned region FRaw.
  // So we must only free FRaw to avoid double free.
  if FRaw <> nil then
    FAllocator.FreeMem(FRaw);
  FCore := nil;
  FBase := nil;
  inherited Destroy;
end;

function TFixedSlabPool.Acquire(out AUnit: Pointer): Boolean;
var
  LUnitSize: SizeUInt;
begin
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  AUnit := GetMem(LUnitSize);
  Result := AUnit <> nil;
end;

function TFixedSlabPool.TryAcquire(out AUnit: Pointer): Boolean;
begin
  Result := Acquire(AUnit);
end;

function TFixedSlabPool.AcquireN(out AUnits: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
  LUnitSize: SizeUInt;
begin
  Result := 0;
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(AUnits) then
      Break;
    LPtr := GetMem(LUnitSize);
    if LPtr = nil then
      Break;
    AUnits[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TFixedSlabPool.Release(AUnit: Pointer);
begin
  FreeMem(AUnit);
end;

procedure TFixedSlabPool.ReleaseN(const AUnits: array of Pointer; aCount: Integer);
var i: Integer;
begin
  for i := 0 to aCount-1 do
    FreeMem(AUnits[i]);
end;

function TFixedSlabPool.ChunkSizeOf(APtr: Pointer): SizeUInt;
var
  pool: Pngx_slab_pool_t;
  n, page_type, shift: SizeUInt;
  page: Pngx_slab_page_t;
begin
  Result := 0;
  if (APtr = nil) or (FCore = nil) then Exit;

  pool := Pngx_slab_pool_t(FCore);

  // 边界检查
  if (PByte(APtr) < pool^.start) or (PByte(APtr) >= pool^.endp) then
    Exit;

  // 计算页面索引
  n := (PtrUInt(APtr) - PtrUInt(pool^.start)) shr ngx_pagesize_shift;
  page := @pool^.pages[n];
  page_type := ngx_slab_page_type(page);

  case page_type of
    NGX_SLAB_SMALL:
    begin
      shift := page^.slab and NGX_SLAB_SHIFT_MASK;
      Result := SizeUInt(1) shl shift;
    end;

    NGX_SLAB_EXACT:
    begin
      Result := ngx_slab_exact_size;
    end;

    NGX_SLAB_BIG:
    begin
      shift := page^.slab and NGX_SLAB_SHIFT_MASK;
      Result := SizeUInt(1) shl shift;
    end;

    NGX_SLAB_PAGE:
    begin
      // only start page holds size with START bit
      if (page^.slab and NGX_SLAB_PAGE_START) = 0 then
        Exit(0);
      Result := (page^.slab and not NGX_SLAB_PAGE_START) shl ngx_pagesize_shift;
    end;

    else
      Result := SizeUInt(1) shl FMinShift; // 默认最小大小
  end;
end;

procedure TFixedSlabPool.Reset;
begin
  if (FBase <> nil) and (FCore <> nil) and (FRegionEnd <> nil) then
  begin
    Pngx_slab_pool_t(FCore)^.min_shift := FMinShift;
    Pngx_slab_pool_t(FCore)^.endp := FRegionEnd;
    ngx_slab_init(Pngx_slab_pool_t(FCore));
    // refresh FSize after init
    FSize := PtrUInt(Pngx_slab_pool_t(FCore)^.endp) - PtrUInt(Pngx_slab_pool_t(FCore)^.start);
  end;
end;

{$IFDEF FAFAFA_CORE_SLAB_STATS}
function TFixedSlabPool.GetStats: TFixedSlabStats;
begin
  Result := BuildStats;
end;

function TFixedSlabPool.GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
begin
  Result := BuildSlotStat(Index);
end;

function TFixedSlabPool.BuildStats: TFixedSlabStats;
var
  core: Pngx_slab_pool_t;
  totalPages: SizeUInt;
begin
  core := Pngx_slab_pool_t(FCore);
  if core = nil then
  begin
    Result.TotalPages := 0;
    Result.FreePages := 0;
    Result.SlotCount := 0;
    Exit;
  end;
  totalPages := SizeUInt(core^.last - core^.pages);
  Result.TotalPages := totalPages;
  Result.FreePages := core^.pfree;
  Result.SlotCount := NGX_SLAB_PAGE_SHIFT - core^.min_shift;
end;

function TFixedSlabPool.BuildSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
var
  core: Pngx_slab_pool_t;
  n: SizeUInt;
begin
  core := Pngx_slab_pool_t(FCore);
  if core = nil then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  n := NGX_SLAB_PAGE_SHIFT - core^.min_shift;
  if Index >= n then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  Result.total := core^.stats[Index].total;
  Result.used  := core^.stats[Index].used;
  Result.reqs  := core^.stats[Index].reqs;
  Result.fails := core^.stats[Index].fails;
end;
{$ENDIF}

function TFixedSlabPool.GetCapacity: SizeUInt;
begin
  Result := FSize;
end;
function TFixedSlabPool.Traits: TAllocatorTraits;
begin
  // 固定 slab：AllocMem 保证零填充，默认非线程安全，提供块大小查询
  Result.ZeroInitialized := True;   // AllocMem 中有 FillChar
  Result.ThreadSafe      := False;  // 当前实现未加锁
  Result.HasMemSize      := True;   // 提供 ChunkSizeOf / MemSizeOf
  Result.SupportsAligned := False;  // 未提供专门对齐 API
end;

function TFixedSlabPool.MemSizeOf(APtr: Pointer): SizeUInt;
begin
  Result := ChunkSizeOf(APtr);
end;

function TFixedSlabPool.Owns(aPtr: Pointer): Boolean;
begin
  if (aPtr = nil) or (FCore = nil) then Exit(False);
  Result := (PByte(aPtr) >= Pngx_slab_pool_t(FCore)^.start) and (PByte(aPtr) < Pngx_slab_pool_t(FCore)^.endp);
end;

function TFixedSlabPool.PageShift: SizeUInt;
begin
  Result := NGX_SLAB_PAGE_SHIFT;
end;

function TFixedSlabPool.RegionStart: PByte; inline;
begin
  if FCore=nil then Exit(nil);
  Result := Pngx_slab_pool_t(FCore)^.start;
end;

function TFixedSlabPool.RegionEnd: PByte; inline;
begin
  if FCore=nil then Exit(nil);
  Result := Pngx_slab_pool_t(FCore)^.endp;
end;

function TFixedSlabPool.GetUsed: SizeUInt;
var
  pool: Pngx_slab_pool_t;
  total_pages, data_size: SizeUInt;
begin
  if FCore <> nil then
  begin
    pool := Pngx_slab_pool_t(FCore);
    // 计算数据区域的总大小（不包括管理结构）
    data_size := PtrUInt(pool^.endp) - PtrUInt(pool^.start);
    total_pages := data_size shr NGX_SLAB_PAGE_SHIFT;

    if pool^.pfree <= total_pages then
      Result := (total_pages - pool^.pfree) shl NGX_SLAB_PAGE_SHIFT
    else
      Result := 0;
  end
  else
    Result := 0;
end;

function TFixedSlabPool.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TFixedSlabPool.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TFixedSlabPool.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TFixedSlabPool.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then Exit(nil);
  if FCore = nil then Exit(nil);
  Result := ngx_slab_alloc_locked(Pngx_slab_pool_t(FCore), aSize);
end;

function TFixedSlabPool.AllocMem(aSize: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TFixedSlabPool.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  p: Pointer;
  oldSize, copySize: SizeUInt;
  pool: Pngx_slab_pool_t;
  offInPool, offInPage, pageRemain: SizeUInt;
begin
  if aDst = nil then Exit(GetMem(aSize));
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;

  p := GetMem(aSize);
  if p = nil then Exit(nil);

  // 估算旧块大小，并复制不超过块大小且不跨页边界的最小字节数
  oldSize := ChunkSizeOf(aDst);
  if oldSize > aSize then copySize := aSize else copySize := oldSize;

  pool := Pngx_slab_pool_t(FCore);
  if (pool <> nil) and (aDst <> nil) then
  begin
    // 计算页内剩余空间，slab 小块永不跨页
    offInPool := PtrUInt(aDst) - PtrUInt(pool^.start);
    offInPage := offInPool and (ngx_pagesize - 1);
    pageRemain := ngx_pagesize - offInPage;
    if copySize > pageRemain then
      copySize := pageRemain;
  end;

  {$IFDEF FAFAFA_SLAB_TESTGUARD}
  WriteLn('[Realloc] aDst=', PtrUInt(aDst):16, ', aSize=', aSize, ', oldSize=', oldSize, ', copySize=', copySize, ', pageRemain=', pageRemain);
  {$ENDIF}

  if copySize > 0 then
    Move(aDst^, p^, copySize);

  FreeMem(aDst);
  Result := p;
end;

procedure TFixedSlabPool.FreeMem(aDst: Pointer);
begin
  if (aDst = nil) or (FCore = nil) then Exit;
  ngx_slab_free_locked(Pngx_slab_pool_t(FCore), aDst);
end;

function TFixedSlabPool.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  // Slab pool size classes provide natural alignment based on size class:
  // - 8B blocks are 8-byte aligned
  // - 16B blocks are 16-byte aligned
  // - etc.
  // For alignment requests ≤ size class alignment, GetMem works directly.
  // For larger alignment, fall back to underlying allocator if available.
  if (aAlignment <= 8) or (aAlignment <= aSize) then
    Result := GetMem(aSize)
  else if FAllocator <> nil then
    Result := FAllocator.AllocAligned(aSize, aAlignment)
  else
    Result := nil; // Cannot satisfy alignment request without backing allocator
end;

procedure TFixedSlabPool.FreeAligned(aPtr: Pointer);
begin
  // If pointer is within our region, free it ourselves; otherwise delegate
  if Owns(aPtr) then
    FreeMem(aPtr)
  else if FAllocator <> nil then
    FAllocator.FreeAligned(aPtr);
  // else: ignore (pointer not ours and no backing allocator)
end;

initialization
  // 确保全局变量正确初始化
  ngx_slab_max_size := 0;
  ngx_slab_exact_size := 0;
  ngx_slab_exact_shift := 0;
  ngx_pagesize := NGX_SLAB_PAGE_SIZE;
  ngx_pagesize_shift := NGX_SLAB_PAGE_SHIFT;

{$POP}

end.
