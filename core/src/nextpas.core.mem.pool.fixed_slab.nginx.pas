{
  nextpas.core.mem.pool.fixed_slab.nginx

  Nginx slab allocator byte-level port.
  Extracted from pool.fixed_slab.pas for maintainability.

  This unit contains:
  - ngx_slab_page_t / ngx_slab_stat_t / ngx_slab_pool_t types
  - ngx_slab_init / ngx_slab_alloc_locked / ngx_slab_free_locked
  - ngx_slab_alloc_pages / ngx_slab_free_pages
  - Helper macros as inline functions
}
unit nextpas.core.mem.pool.fixed_slab.nginx;

{$I nextpas.core.settings.inc}

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in slab internals

interface

uses
  nextpas.core.base;

{** Nginx slab page size (4KB) *}
const
  NGX_SLAB_PAGE_SIZE  = 4096;
  NGX_SLAB_PAGE_SHIFT = 12;

{** Nginx slab page type masks *}
const
  NGX_SLAB_PAGE_MASK   = 3;
  NGX_SLAB_PAGE        = 0;
  NGX_SLAB_BIG         = 1;
  NGX_SLAB_EXACT       = 2;
  NGX_SLAB_SMALL       = 3;

{** Nginx slab bitmasks (platform-dependent) *}
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

{** Nginx slab data types *}
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
    min_size: SizeUInt;
    min_shift: SizeUInt;
    pages: Pngx_slab_page_t;
    last: Pngx_slab_page_t;
    free: ngx_slab_page_t;
    stats: Pngx_slab_stat_t;
    pfree: SizeUInt;
    start: PByte;
    endp: PByte;
  end;

{** Nginx slab global state (thread-safe lazy init) *}
var
  ngx_slab_max_size: SizeUInt;
  ngx_slab_exact_size: SizeUInt;
  ngx_slab_exact_shift: SizeUInt;
  ngx_pagesize: SizeUInt;
  ngx_pagesize_shift: SizeUInt;

{** Hash function for slab ownership tracking *}
function FixedSlabHash(AKey: PtrUInt): PtrUInt; inline;

{** Nginx slab inline helper functions *}
function ngx_slab_slots(pool: Pngx_slab_pool_t): Pngx_slab_page_t; inline;
function ngx_slab_page_type(page: Pngx_slab_page_t): PtrUInt; inline;
function ngx_slab_page_prev(page: Pngx_slab_page_t): Pngx_slab_page_t; inline;
function ngx_slab_page_addr(pool: Pngx_slab_pool_t; page: Pngx_slab_page_t): PtrUInt; inline;
function ngx_align_ptr(p: PByte; a: SizeUInt): PByte; inline;

{** Thread-safe lazy initialization of slab size constants *}
procedure ngx_slab_sizes_init;

{** Initialize slab pool structures *}
procedure ngx_slab_init(pool: Pngx_slab_pool_t);

{** Allocate from slab pool (caller must hold lock) *}
function ngx_slab_alloc_locked(pool: Pngx_slab_pool_t; size: SizeUInt): Pointer;

{** Free to slab pool (caller must hold lock) *}
procedure ngx_slab_free_locked(pool: Pngx_slab_pool_t; p: Pointer);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.utils;

{ FixedSlabHash }

function FixedSlabHash(AKey: PtrUInt): PtrUInt; inline;
begin
  Result := PtrUInt(MulHash64(QWord(AKey)));
end;

{ Nginx inline helpers }

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

function ngx_align_ptr(p: PByte; a: SizeUInt): PByte; inline;
begin
  Result := PByte((PtrUInt(p) + (a - 1)) and not (a - 1));
end;

{ ngx_slab_junk — debug fill }

{$IFDEF DEBUG}
procedure ngx_slab_junk(p: Pointer; size: SizeUInt); inline;
begin
  if (p <> nil) and (size > 0) then
    FillMem(p, size, $A5);
end;
{$ELSE}
procedure ngx_slab_junk(p: Pointer; size: SizeUInt); inline;
begin
  // no-op
end;
{$ENDIF}

{ ngx_slab_sizes_init — thread-safe one-shot init }

var
  ngx_slab_sizes_initialized: LongInt = 0;

procedure ngx_slab_sizes_init;
var
  n: SizeUInt;
begin
  if InterlockedCompareExchange(ngx_slab_sizes_initialized, 1, 0) <> 0 then
    Exit;

  ngx_slab_max_size := ngx_pagesize div 2;
  ngx_slab_exact_size := ngx_pagesize div (8 * SizeOf(PtrUInt));
  ngx_slab_exact_shift := 0;
  n := ngx_slab_exact_size;
  while n > 1 do
  begin
    n := n shr 1;
    Inc(ngx_slab_exact_shift);
  end;

  InterlockedExchange(ngx_slab_sizes_initialized, 1);
end;

{ ngx_slab_init }

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
    slots[i].slab := 0;
    slots[i].next := @slots[i];
    slots[i].prev := 0;
  end;

  Inc(p, n * SizeOf(ngx_slab_page_t));

  pool^.stats := Pngx_slab_stat_t(p);
  ZeroMem(pool^.stats, n * SizeOf(ngx_slab_stat_t));

  Inc(p, n * SizeOf(ngx_slab_stat_t));

  Dec(size, n * (SizeOf(ngx_slab_page_t) + SizeOf(ngx_slab_stat_t)));

  pages := size div (ngx_pagesize + SizeOf(ngx_slab_page_t));

  pool^.pages := Pngx_slab_page_t(p);
  ZeroMem(pool^.pages, pages * SizeOf(ngx_slab_page_t));

  page := pool^.pages;

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

{ ngx_slab_alloc_pages }

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

  Result := nil;
end;

{ ngx_slab_free_pages }

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
    ZeroMem(@page[1], pages * SizeOf(ngx_slab_page_t));

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

{ ngx_slab_alloc_locked }

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
    page := ngx_slab_alloc_pages(pool, (size shr ngx_pagesize_shift) +
                                       Ord((size and (ngx_pagesize - 1)) <> 0));
    if page <> nil then
      p := ngx_slab_page_addr(pool, page)
    else
      p := 0;

    goto done;
  end;

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
    if shift < ngx_slab_exact_shift then
    begin
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
            i := n + 1;
            while i <= map - 1 do
            begin
              if bitmap[i] <> NGX_SLAB_BUSY then
                goto done;
              Inc(i);
            end;

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
  end;

  page := ngx_slab_alloc_pages(pool, 1);

  if page <> nil then
  begin
    if shift < ngx_slab_exact_shift then
    begin
      bitmap := Pointer(ngx_slab_page_addr(pool, page));

      n := (ngx_pagesize shr shift) div ((SizeUInt(1) shl shift) * 8);
      if n = 0 then n := 1;

      i := 0;
      while i < (n + 1) div (8 * SizeOf(PtrUInt)) do
      begin
        bitmap[i] := NGX_SLAB_BUSY;
        Inc(i);
      end;

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

  p := 0;
  Inc(pool^.stats[slot].fails);

done:
  Result := Pointer(p);
end;

{ ngx_slab_free_locked }

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
  if (PByte(p) < pool^.start) or (PByte(p) >= pool^.endp) then
    Exit;

  n := (PtrUInt(p) - PtrUInt(pool^.start)) shr ngx_pagesize_shift;
  page := @pool^.pages[n];
  slab := page^.slab;
  page_type := ngx_slab_page_type(page);

  {$IFDEF NEXTPAS_SLAB_TESTGUARD}
  WriteLn('[Free] p=', PtrUInt(p):16, ', n=', n, ', page_type=', page_type, ', slab=', slab:16);
  {$ENDIF}

  case page_type of
    NGX_SLAB_SMALL:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      size := SizeUInt(1) shl shift;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit;

      n := (PtrUInt(p) and (ngx_pagesize - 1)) shr shift;
      m := PtrUInt(1) shl (n mod (8 * SizeOf(PtrUInt)));
      n := n div (8 * SizeOf(PtrUInt));
      bitmap := PPtrUInt(PtrUInt(p) and not (PtrUInt(ngx_pagesize) - 1));

      if (bitmap[n] and m) <> 0 then
      begin
        slot := shift - pool^.min_shift;

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
    end;

    NGX_SLAB_EXACT:
    begin
      m := PtrUInt(1) shl ((PtrUInt(p) and (ngx_pagesize - 1)) shr ngx_slab_exact_shift);
      size := ngx_slab_exact_size;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit;

      if (slab and m) <> 0 then
      begin
        slot := ngx_slab_exact_shift - pool^.min_shift;

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
    end;

    NGX_SLAB_BIG:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      size := SizeUInt(1) shl shift;

      if (PtrUInt(p) and (size - 1)) <> 0 then
        Exit;

      m := PtrUInt(1) shl (((PtrUInt(p) and (ngx_pagesize - 1)) shr shift) + NGX_SLAB_MAP_SHIFT);

      if (slab and m) <> 0 then
      begin
        slot := shift - pool^.min_shift;

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
    end;

    NGX_SLAB_PAGE:
    begin
      if (PtrUInt(p) and (ngx_pagesize - 1)) <> 0 then
        Exit;

      if (slab and NGX_SLAB_PAGE_START) = 0 then
        Exit;

      if slab = NGX_SLAB_PAGE_BUSY then
        Exit;

      size := slab and not NGX_SLAB_PAGE_START;

      ngx_slab_free_pages(pool, page, size);
      ngx_slab_junk(p, size shl ngx_pagesize_shift);

      Exit;
    end;
  end;

  Exit;

done:
  Dec(pool^.stats[slot].used);
end;

{$POP}

initialization
  ngx_slab_max_size := 0;
  ngx_slab_exact_size := 0;
  ngx_slab_exact_shift := 0;
  ngx_pagesize := NGX_SLAB_PAGE_SIZE;
  ngx_pagesize_shift := NGX_SLAB_PAGE_SHIFT;

end.
