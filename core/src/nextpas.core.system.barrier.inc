{**
 * @desc Barrier and prefetch support for the nextPas system kernel.
 *
 * Defines memory barrier and prefetch intrinsics.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by FPC System.
 *}

{ Memory barrier intrinsics }
procedure ReadBarrier; inline;
procedure ReadDependencyBarrier; inline;
procedure ReadWriteBarrier; inline;
procedure WriteBarrier; inline;

{ Prefetch intrinsic }
procedure Prefetch(const AMem); inline;

implementation

{ Memory barrier stubs — real implementations provided by runtime/OS }
procedure ReadBarrier;
begin
  { Stub — runtime provides real implementation }
end;

procedure ReadDependencyBarrier;
begin
  { Stub — runtime provides real implementation }
end;

procedure ReadWriteBarrier;
begin
  { Stub — runtime provides real implementation }
end;

procedure WriteBarrier;
begin
  { Stub — runtime provides real implementation }
end;

{ Prefetch stub — real implementation provided by runtime }
procedure Prefetch(const AMem);
begin
  { Stub — runtime provides real implementation }
end;
