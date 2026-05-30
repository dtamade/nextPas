unit nextpas.core.io.uring;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern;

type
  TIoUringSqRing = record
    Head: PUInt32;
    Tail: PUInt32;
    RingMask: PUInt32;
    RingEntries: PUInt32;
    Flags: PUInt32;
    Dropped: PUInt32;
    ArrayPtr: PUInt32;
    RingPtr: Pointer;
    RingSize: SizeUInt;
  end;

  TIoUringCqRing = record
    Head: PUInt32;
    Tail: PUInt32;
    RingMask: PUInt32;
    RingEntries: PUInt32;
    Overflow: PUInt32;
    CqesPtr: PIoUringCqe;
    RingPtr: Pointer;
    RingSize: SizeUInt;
  end;

  TIoUring = record
  private
    FFd: Int32;
    FSqRing: TIoUringSqRing;
    FCqRing: TIoUringCqRing;
    FSqeArray: PIoUringSqe;
    FSqeCount: UInt32;
    FSqHead: UInt32;
    FSqTail: UInt32;
    FValid: Boolean;
  public
    class function Create(AEntries: UInt32; AFlags: UInt32 = 0): TIoUring; static;
    procedure Close;
    function IsValid: Boolean; inline;
    function GetSqe: PIoUringSqe;
    function Submit: Int32;
    function SubmitAndWait(AWaitNr: UInt32): Int32;
    function PeekCqe(out ACqe: PIoUringCqe): Boolean;
    function WaitCqe(out ACqe: PIoUringCqe): Int32;
    procedure CqeSeen(ACqe: PIoUringCqe);
    function CqeReady: UInt32;
  end;

procedure IoUringPrepNop(ASqe: PIoUringSqe);
procedure IoUringPrepRead(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
procedure IoUringPrepWrite(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
procedure IoUringPrepClose(ASqe: PIoUringSqe; AFd: Int32);
procedure IoUringPrepFsync(ASqe: PIoUringSqe; AFd: Int32; AFlags: UInt32);
procedure IoUringPrepAccept(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32);
procedure IoUringPrepConnect(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: UInt32);
procedure IoUringPrepSend(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
procedure IoUringPrepRecv(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
procedure IoUringPrepPollAdd(ASqe: PIoUringSqe; AFd: Int32; APollMask: UInt32);
procedure IoUringPrepCancel(ASqe: PIoUringSqe; AUserData: UInt64; AFlags: Int32);
procedure IoUringPrepReadv(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
procedure IoUringPrepWritev(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
procedure IoUringPrepTimeout(ASqe: PIoUringSqe; ATs: Pointer;
  ACount: UInt32; AFlags: UInt32);
procedure IoUringPrepTimeoutRemove(ASqe: PIoUringSqe; AUserData: UInt64; AFlags: UInt32);
procedure IoUringPrepOpenAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AFlags: Int32; AMode: UInt32);
procedure IoUringPrepSplice(ASqe: PIoUringSqe; AFdIn: Int32; AOffIn: Int64;
  AFdOut: Int32; AOffOut: Int64; ALen: UInt32; AFlags: UInt32);
procedure IoUringPrepShutdown(ASqe: PIoUringSqe; AFd: Int32; AHow: Int32);
procedure IoUringPrepUnlinkAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AFlags: Int32);
procedure IoUringPrepMkdirAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AMode: UInt32);
procedure IoUringPrepRenameAt(ASqe: PIoUringSqe; AOldDirFd: Int32;
  AOldPath: PAnsiChar; ANewDirFd: Int32; ANewPath: PAnsiChar; AFlags: UInt32);

procedure IoUringSqeSetData(ASqe: PIoUringSqe; AData: UInt64); inline;
function IoUringCqeGetData(ACqe: PIoUringCqe): UInt64; inline;

implementation

uses
  BaseUnix;

const
  PROT_READ  = 1;
  PROT_WRITE = 2;
  MAP_SHARED = 1;
  MAP_POPULATE = $8000;

  IORING_OFF_SQ_RING = 0;
  IORING_OFF_CQ_RING = $8000000;
  IORING_OFF_SQES    = $10000000;

procedure ReadBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  // x86_64 TSO: loads not reordered. Compiler barrier suffices.
  ReadWriteBarrier;
  {$ELSE}
  ReadWriteBarrier;
  {$ENDIF}
end;

procedure WriteBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  // x86_64 TSO: stores not reordered. Compiler barrier suffices.
  ReadWriteBarrier;
  {$ELSE}
  ReadWriteBarrier;
  {$ENDIF}
end;

function do_mmap(addr: Pointer; len: size_t; prot: cint; flags: cint;
  fd: cint; offset: off_t): Pointer; cdecl; external 'c' name 'mmap';
function do_munmap(addr: Pointer; len: size_t): cint; cdecl; external 'c' name 'munmap';

class function TIoUring.Create(AEntries: UInt32; AFlags: UInt32): TIoUring;
var
  LParams: TIoUringParams;
  LSqPtr, LCqPtr, LSqePtr: Pointer;
  LSqRingSize, LCqRingSize: SizeUInt;
begin
  FillChar(Result, SizeOf(Result), 0);
  FillChar(LParams, SizeOf(LParams), 0);
  LParams.flags := AFlags;

  Result.FFd := io_uring_setup(AEntries, @LParams);
  if Result.FFd < 0 then Exit;

  Result.FSqeCount := LParams.sq_entries;

  // mmap SQ ring
  LSqRingSize := SizeUInt(LParams.sq_off.array_off) +
    SizeUInt(LParams.sq_entries) * SizeOf(UInt32);
  LSqPtr := do_mmap(nil, LSqRingSize, PROT_READ or PROT_WRITE,
    MAP_SHARED or MAP_POPULATE, Result.FFd, IORING_OFF_SQ_RING);
  if LSqPtr = Pointer(-1) then begin FpClose(Result.FFd); Result.FFd := -1; Exit; end;

  Result.FSqRing.RingPtr := LSqPtr;
  Result.FSqRing.RingSize := LSqRingSize;
  Result.FSqRing.Head := PUInt32(LSqPtr + LParams.sq_off.head);
  Result.FSqRing.Tail := PUInt32(LSqPtr + LParams.sq_off.tail);
  Result.FSqRing.RingMask := PUInt32(LSqPtr + LParams.sq_off.ring_mask);
  Result.FSqRing.RingEntries := PUInt32(LSqPtr + LParams.sq_off.ring_entries);
  Result.FSqRing.Flags := PUInt32(LSqPtr + LParams.sq_off.flags);
  Result.FSqRing.Dropped := PUInt32(LSqPtr + LParams.sq_off.dropped);
  Result.FSqRing.ArrayPtr := PUInt32(LSqPtr + LParams.sq_off.array_off);

  // mmap CQ ring
  LCqRingSize := SizeUInt(LParams.cq_off.cqes) +
    SizeUInt(LParams.cq_entries) * SizeOf(TIoUringCqe);
  LCqPtr := do_mmap(nil, LCqRingSize, PROT_READ or PROT_WRITE,
    MAP_SHARED or MAP_POPULATE, Result.FFd, IORING_OFF_CQ_RING);
  if LCqPtr = Pointer(-1) then
  begin
    do_munmap(LSqPtr, LSqRingSize);
    FpClose(Result.FFd); Result.FFd := -1; Exit;
  end;

  Result.FCqRing.RingPtr := LCqPtr;
  Result.FCqRing.RingSize := LCqRingSize;
  Result.FCqRing.Head := PUInt32(LCqPtr + LParams.cq_off.head);
  Result.FCqRing.Tail := PUInt32(LCqPtr + LParams.cq_off.tail);
  Result.FCqRing.RingMask := PUInt32(LCqPtr + LParams.cq_off.ring_mask);
  Result.FCqRing.RingEntries := PUInt32(LCqPtr + LParams.cq_off.ring_entries);
  Result.FCqRing.Overflow := PUInt32(LCqPtr + LParams.cq_off.overflow);
  Result.FCqRing.CqesPtr := PIoUringCqe(LCqPtr + LParams.cq_off.cqes);

  // mmap SQE array
  LSqePtr := do_mmap(nil, SizeUInt(LParams.sq_entries) * SizeOf(TIoUringSqe),
    PROT_READ or PROT_WRITE, MAP_SHARED or MAP_POPULATE,
    Result.FFd, IORING_OFF_SQES);
  if LSqePtr = Pointer(-1) then
  begin
    do_munmap(LCqPtr, LCqRingSize);
    do_munmap(LSqPtr, LSqRingSize);
    FpClose(Result.FFd); Result.FFd := -1; Exit;
  end;

  Result.FSqeArray := PIoUringSqe(LSqePtr);
  Result.FSqHead := Result.FSqRing.Head^;
  Result.FSqTail := Result.FSqRing.Tail^;
  Result.FValid := True;
end;

procedure TIoUring.Close;
begin
  if not FValid then Exit;
  if FSqeArray <> nil then
    do_munmap(FSqeArray, SizeUInt(FSqeCount) * SizeOf(TIoUringSqe));
  if FCqRing.RingPtr <> nil then
    do_munmap(FCqRing.RingPtr, FCqRing.RingSize);
  if FSqRing.RingPtr <> nil then
    do_munmap(FSqRing.RingPtr, FSqRing.RingSize);
  if FFd >= 0 then
    FpClose(FFd);
  FValid := False;
end;

function TIoUring.IsValid: Boolean;
begin
  Result := FValid;
end;

function TIoUring.GetSqe: PIoUringSqe;
var
  LIdx: UInt32;
begin
  // Read kernel's SQ head to know how many slots are free
  ReadBarrier;
  FSqHead := FSqRing.Head^;
  if (FSqTail - FSqHead) >= FSqeCount then
  begin
    Result := nil;
    Exit;
  end;
  LIdx := FSqTail and FSqRing.RingMask^;
  Result := PIoUringSqe(PByte(FSqeArray) + LIdx * SizeOf(TIoUringSqe));
  FillChar(Result^, SizeOf(TIoUringSqe), 0);
  Inc(FSqTail);
end;

function TIoUring.Submit: Int32;
var
  LToSubmit: UInt32;
  LIdx, LI: UInt32;
begin
  LToSubmit := FSqTail - FSqRing.Tail^;
  if LToSubmit = 0 then begin Result := 0; Exit; end;

  for LI := 1 to LToSubmit do
  begin
    LIdx := (FSqRing.Tail^ + LI - 1) and FSqRing.RingMask^;
    FSqRing.ArrayPtr[LIdx] := LIdx;
  end;

  WriteBarrier;
  FSqRing.Tail^ := FSqTail;
  WriteBarrier;

  Result := io_uring_enter(FFd, LToSubmit, 0, 0, nil);
end;

function TIoUring.SubmitAndWait(AWaitNr: UInt32): Int32;
var
  LToSubmit: UInt32;
  LIdx, LI: UInt32;
begin
  LToSubmit := FSqTail - FSqRing.Tail^;

  if LToSubmit > 0 then
  begin
    for LI := 1 to LToSubmit do
    begin
      LIdx := (FSqRing.Tail^ + LI - 1) and FSqRing.RingMask^;
      FSqRing.ArrayPtr[LIdx] := LIdx;
    end;
    WriteBarrier;
    FSqRing.Tail^ := FSqTail;
    WriteBarrier;
  end;

  Result := io_uring_enter(FFd, LToSubmit, AWaitNr, IORING_ENTER_GETEVENTS, nil);
end;

function TIoUring.PeekCqe(out ACqe: PIoUringCqe): Boolean;
var
  LHead, LTail, LIdx: UInt32;
begin
  ReadBarrier;
  LHead := FCqRing.Head^;
  LTail := FCqRing.Tail^;
  if LHead = LTail then
  begin
    ACqe := nil;
    Result := False;
    Exit;
  end;
  LIdx := LHead and FCqRing.RingMask^;
  ACqe := PIoUringCqe(PByte(FCqRing.CqesPtr) + LIdx * SizeOf(TIoUringCqe));
  Result := True;
end;

function TIoUring.WaitCqe(out ACqe: PIoUringCqe): Int32;
begin
  if PeekCqe(ACqe) then begin Result := 0; Exit; end;
  Result := io_uring_enter(FFd, 0, 1, IORING_ENTER_GETEVENTS, nil);
  if Result < 0 then begin ACqe := nil; Exit; end;
  if not PeekCqe(ACqe) then Result := -1;
end;

procedure TIoUring.CqeSeen(ACqe: PIoUringCqe);
begin
  if ACqe = nil then Exit;
  ReadBarrier;
  Inc(FCqRing.Head^);
  WriteBarrier;
end;

function TIoUring.CqeReady: UInt32;
begin
  ReadBarrier;
  Result := FCqRing.Tail^ - FCqRing.Head^;
end;

{ Prep helpers }

procedure IoUringPrepNop(ASqe: PIoUringSqe);
begin
  ASqe^.opcode := IORING_OP_NOP;
  ASqe^.fd := -1;
end;

procedure IoUringPrepRead(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
begin
  ASqe^.opcode := IORING_OP_READ;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(ABuf));
  ASqe^.len := ALen;
  ASqe^.off := UInt64(AOffset);
end;

procedure IoUringPrepWrite(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
begin
  ASqe^.opcode := IORING_OP_WRITE;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(ABuf));
  ASqe^.len := ALen;
  ASqe^.off := UInt64(AOffset);
end;

procedure IoUringPrepClose(ASqe: PIoUringSqe; AFd: Int32);
begin
  ASqe^.opcode := IORING_OP_CLOSE;
  ASqe^.fd := AFd;
end;

procedure IoUringPrepFsync(ASqe: PIoUringSqe; AFd: Int32; AFlags: UInt32);
begin
  ASqe^.opcode := IORING_OP_FSYNC;
  ASqe^.fd := AFd;
  ASqe^.op_flags.fsync_flags := AFlags;
end;

procedure IoUringPrepAccept(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32);
begin
  ASqe^.opcode := IORING_OP_ACCEPT;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(AAddr));
  ASqe^.off := UInt64(PtrUInt(AAddrLen));
  ASqe^.op_flags.accept_flags := UInt32(AFlags);
end;

procedure IoUringPrepConnect(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: UInt32);
begin
  ASqe^.opcode := IORING_OP_CONNECT;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(AAddr));
  ASqe^.off := UInt64(AAddrLen);
end;

procedure IoUringPrepSend(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
begin
  ASqe^.opcode := IORING_OP_SEND;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(ABuf));
  ASqe^.len := ALen;
  ASqe^.op_flags.msg_flags := UInt32(AFlags);
end;

procedure IoUringPrepRecv(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
begin
  ASqe^.opcode := IORING_OP_RECV;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(ABuf));
  ASqe^.len := ALen;
  ASqe^.op_flags.msg_flags := UInt32(AFlags);
end;

procedure IoUringPrepPollAdd(ASqe: PIoUringSqe; AFd: Int32; APollMask: UInt32);
begin
  ASqe^.opcode := IORING_OP_POLL_ADD;
  ASqe^.fd := AFd;
  ASqe^.op_flags.poll_events := UInt16(APollMask);
end;

procedure IoUringPrepCancel(ASqe: PIoUringSqe; AUserData: UInt64; AFlags: Int32);
begin
  ASqe^.opcode := IORING_OP_ASYNC_CANCEL;
  ASqe^.fd := -1;
  ASqe^.addr := AUserData;
  ASqe^.op_flags.cancel_flags := UInt32(AFlags);
end;

procedure IoUringPrepReadv(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
begin
  ASqe^.opcode := IORING_OP_READV;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(AIovecs));
  ASqe^.len := ANrVecs;
  ASqe^.off := UInt64(AOffset);
end;

procedure IoUringPrepWritev(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
begin
  ASqe^.opcode := IORING_OP_WRITEV;
  ASqe^.fd := AFd;
  ASqe^.addr := UInt64(PtrUInt(AIovecs));
  ASqe^.len := ANrVecs;
  ASqe^.off := UInt64(AOffset);
end;

procedure IoUringPrepTimeout(ASqe: PIoUringSqe; ATs: Pointer;
  ACount: UInt32; AFlags: UInt32);
begin
  ASqe^.opcode := IORING_OP_TIMEOUT;
  ASqe^.fd := -1;
  ASqe^.addr := UInt64(PtrUInt(ATs));
  ASqe^.len := ACount;
  ASqe^.op_flags.timeout_flags := AFlags;
end;

procedure IoUringPrepTimeoutRemove(ASqe: PIoUringSqe; AUserData: UInt64; AFlags: UInt32);
begin
  ASqe^.opcode := IORING_OP_TIMEOUT_REMOVE;
  ASqe^.fd := -1;
  ASqe^.addr := AUserData;
  ASqe^.op_flags.timeout_flags := AFlags;
end;

procedure IoUringPrepOpenAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AFlags: Int32; AMode: UInt32);
begin
  ASqe^.opcode := IORING_OP_OPENAT;
  ASqe^.fd := ADirFd;
  ASqe^.addr := UInt64(PtrUInt(APath));
  ASqe^.len := AMode;
  ASqe^.op_flags.open_flags := UInt32(AFlags);
end;

procedure IoUringPrepSplice(ASqe: PIoUringSqe; AFdIn: Int32; AOffIn: Int64;
  AFdOut: Int32; AOffOut: Int64; ALen: UInt32; AFlags: UInt32);
begin
  ASqe^.opcode := IORING_OP_SPLICE;
  ASqe^.fd := AFdOut;
  ASqe^.off := UInt64(AOffOut);
  ASqe^.splice_fd_in := AFdIn;
  ASqe^.addr := UInt64(AOffIn);
  ASqe^.len := ALen;
  ASqe^.op_flags.splice_flags := AFlags;
end;

procedure IoUringPrepShutdown(ASqe: PIoUringSqe; AFd: Int32; AHow: Int32);
begin
  ASqe^.opcode := IORING_OP_SHUTDOWN;
  ASqe^.fd := AFd;
  ASqe^.len := UInt32(AHow);
end;

procedure IoUringPrepUnlinkAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AFlags: Int32);
begin
  ASqe^.opcode := IORING_OP_UNLINKAT;
  ASqe^.fd := ADirFd;
  ASqe^.addr := UInt64(PtrUInt(APath));
  ASqe^.op_flags.open_flags := UInt32(AFlags);
end;

procedure IoUringPrepMkdirAt(ASqe: PIoUringSqe; ADirFd: Int32;
  APath: PAnsiChar; AMode: UInt32);
begin
  ASqe^.opcode := IORING_OP_MKDIRAT;
  ASqe^.fd := ADirFd;
  ASqe^.addr := UInt64(PtrUInt(APath));
  ASqe^.len := AMode;
end;

procedure IoUringPrepRenameAt(ASqe: PIoUringSqe; AOldDirFd: Int32;
  AOldPath: PAnsiChar; ANewDirFd: Int32; ANewPath: PAnsiChar; AFlags: UInt32);
begin
  ASqe^.opcode := IORING_OP_RENAMEAT;
  ASqe^.fd := AOldDirFd;
  ASqe^.addr := UInt64(PtrUInt(AOldPath));
  ASqe^.len := ANewDirFd;
  ASqe^.off := UInt64(PtrUInt(ANewPath));
  ASqe^.op_flags.open_flags := AFlags;
end;

procedure IoUringSqeSetData(ASqe: PIoUringSqe; AData: UInt64);
begin
  ASqe^.user_data := AData;
end;

function IoUringCqeGetData(ACqe: PIoUringCqe): UInt64;
begin
  Result := ACqe^.user_data;
end;

end.
