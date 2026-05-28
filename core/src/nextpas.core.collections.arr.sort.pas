unit nextpas.core.collections.arr.sort;

{$I nextpas.core.settings.inc}
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

procedure SortI32(aData: PInt32; aCount: SizeUInt);
procedure SortI64(aData: PInt64; aCount: SizeUInt);
procedure SortU32(aData: PUInt32; aCount: SizeUInt);
procedure SortU64(aData: PUInt64; aCount: SizeUInt);

implementation

{$DEFINE SORT_INT32}
{$I nextpas.core.collections.arr.sort.inc}
{$UNDEF SORT_INT32}

{$DEFINE SORT_INT64}
{$I nextpas.core.collections.arr.sort.inc}
{$UNDEF SORT_INT64}

{$DEFINE SORT_UINT32}
{$I nextpas.core.collections.arr.sort.inc}
{$UNDEF SORT_UINT32}

{$DEFINE SORT_UINT64}
{$I nextpas.core.collections.arr.sort.inc}
{$UNDEF SORT_UINT64}

end.
