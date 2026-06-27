unit nextpas.core.mem.shuffle;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  {** Minimal free-list node for shuffle operations.
      Compatible with TFreeNode in mem.cache.thread (same layout). }
  PShuffleNode = ^TShuffleNode;
  TShuffleNode = record
    FNext: PShuffleNode;
  end;

{** Insert ANode into the free list at a random position instead of the head.
    AHead: current head of the free list (modified in place).
    ANode: the node to insert.
    ACount: current number of entries in the list.
    Uses per-thread xorshift64* PRNG. No external dependencies.
    Security: prevents heap spraying by randomizing allocation order. }
procedure FreeListInsertShuffled(var AHead: Pointer; ANode: Pointer;
  ACount: Word);

implementation

threadvar
  { Per-thread PRNG state for free-list shuffle. }
  GShuffleState: UInt64;

{ xorshift64* — period 2^64 - 1, passes BigCrush. }
function XorShift64Star(var AState: UInt64): UInt64; inline;
begin
  AState := AState xor (AState shr 12);
  AState := AState xor (AState shl 25);
  AState := AState xor (AState shr 27);
  Result := AState * UInt64(2685821657736338717);
end;

{ Ensure PRNG is seeded (once per thread). }
procedure EnsureSeeded; inline;
var
  LSeed: UInt64;
begin
  if GShuffleState = 0 then
  begin
    LSeed := UInt64(@GShuffleState);
    LSeed := LSeed xor (LSeed shl 13);
    LSeed := LSeed xor (LSeed shr 7);
    LSeed := LSeed xor (LSeed shl 17);
    if LSeed = 0 then
      LSeed := 1;
    GShuffleState := LSeed;
  end;
end;

procedure FreeListInsertShuffled(var AHead: Pointer; ANode: Pointer;
  ACount: Word);
var
  LHead, LNode, LCur: PShuffleNode;
  LPos: Word;
  I: Word;
begin
  LHead := PShuffleNode(AHead);
  LNode := PShuffleNode(ANode);
  { For very small lists, just push to head. }
  if ACount < 2 then
  begin
    LNode^.FNext := LHead;
    AHead := Pointer(LNode);
    Exit;
  end;
  EnsureSeeded;
  { Random position in [0, ACount]. 0 = head, ACount = tail. }
  LPos := Word(XorShift64Star(GShuffleState) mod UInt64(ACount + 1));
  if LPos = 0 then
  begin
    LNode^.FNext := LHead;
    AHead := Pointer(LNode);
    Exit;
  end;
  { Walk to position LPos - 1. }
  LCur := LHead;
  for I := 1 to LPos - 1 do
  begin
    if LCur = nil then
    begin
      LNode^.FNext := LHead;
      AHead := Pointer(LNode);
      Exit;
    end;
    LCur := LCur^.FNext;
  end;
  if LCur = nil then
  begin
    LNode^.FNext := LHead;
    AHead := Pointer(LNode);
    Exit;
  end;
  { Insert after LCur. }
  LNode^.FNext := LCur^.FNext;
  LCur^.FNext := LNode;
end;

end.
