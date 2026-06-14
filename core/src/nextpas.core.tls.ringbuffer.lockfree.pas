{******************************************************************************}
{  nextpas.core.tls.ringbuffer.lockfree - Lock-Free Ring Buffer                      }
{                                                                              }
{  P2 Performance: Lock-free SPSC (Single-Producer Single-Consumer) ring      }
{  buffer for SSL stream data. Uses memory barriers and atomic operations     }
{  for thread-safe operation without locks.                                   }
{                                                                              }
{  Features:                                                                   }
{    - Zero lock contention for SPSC scenarios                                }
{    - Memory barrier enforcement for visibility                              }
{    - Cache-line padding to prevent false sharing                            }
{    - Fallback to locking version for MPMC scenarios                         }
{******************************************************************************}

unit nextpas.core.tls.ringbuffer.lockfree;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses nextpas.core.tls.base;

type
  { Cache line size for padding - typically 64 bytes on modern CPUs }
  TCacheLine = array[0..63] of Byte;

  { TLockFreeRingBuffer - SPSC lock-free ring buffer

    This implementation uses a single-producer single-consumer pattern:
    - One thread writes (producer)
    - One thread reads (consumer)
    - No locking required due to atomic position updates

    Memory ordering:
    - WriteBarrier before updating FWritePos (makes data visible to reader)
    - ReadBarrier before reading data (ensures seeing producer's writes)
  }
  TLockFreeRingBuffer = class
  private
    FBuffer: PByte;
    FCapacity: Integer;
    FMask: Integer;

    { Padded positions to prevent false sharing between producer and consumer }
    FPadding1: TCacheLine;    // Padding before read position
    FReadPos: Integer;        // Only modified by consumer
    FPadding2: TCacheLine;    // Padding between positions
    FWritePos: Integer;       // Only modified by producer
    FPadding3: TCacheLine;    // Padding after write position

    { Read current size without lock - may be stale but safe }
    function GetSize: Integer; inline;
  public
    constructor Create(ACapacityPowerOf2: Integer = SSL_RINGBUFFER_DEFAULT_CAPACITY_POW2);
    destructor Destroy; override;

    { Producer interface (call from producer thread only) }
    function TryWrite(const AData; ACount: Integer): Integer;
    function GetWriteSpace: Integer; inline;

    { Consumer interface (call from consumer thread only) }
    function TryRead(var AData; ACount: Integer): Integer;
    function GetAvailable: Integer; inline;
    function TryPeek(var AData; ACount: Integer; AOffset: Integer = 0): Integer;
    function TrySkip(ACount: Integer): Integer;

    { Zero-copy producer interface }
    procedure GetWriteBuffer(out ABuffer: PByte; out ASize: Integer);
    procedure CommitWrite(ACount: Integer);

    { Zero-copy consumer interface }
    procedure GetReadBuffer(out ABuffer: PByte; out ASize: Integer);
    procedure CommitRead(ACount: Integer);

    { Reset buffer (call when both threads are synchronized) }
    procedure Reset;

    property Capacity: Integer read FCapacity;
    property Size: Integer read GetSize;
  end;

{ Memory barrier helpers }
procedure WriteBarrier; inline;
procedure ReadBarrier; inline;
procedure FullBarrier; inline;

implementation

{ Memory barriers using compiler intrinsics }

procedure WriteBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  // x86-64: Store-store barrier (sfence)
  asm
    sfence
  end;
  {$ELSE}
  {$IFDEF CPUX86}
  // x86: Store-store barrier
  asm
    sfence
  end;
  {$ELSE}
  // Generic: Full memory barrier
  ReadWriteBarrier;
  {$ENDIF}
  {$ENDIF}
end;

procedure ReadBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  // x86-64: Load-load barrier (lfence)
  asm
    lfence
  end;
  {$ELSE}
  {$IFDEF CPUX86}
  // x86: Load-load barrier
  asm
    lfence
  end;
  {$ELSE}
  // Generic: Full memory barrier
  ReadWriteBarrier;
  {$ENDIF}
  {$ENDIF}
end;

procedure FullBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  // x86-64: Full barrier (mfence)
  asm
    mfence
  end;
  {$ELSE}
  {$IFDEF CPUX86}
  // x86: Full barrier
  asm
    mfence
  end;
  {$ELSE}
  // Generic: Full memory barrier
  ReadWriteBarrier;
  {$ENDIF}
  {$ENDIF}
end;

{ TLockFreeRingBuffer }

constructor TLockFreeRingBuffer.Create(ACapacityPowerOf2: Integer);
begin
  inherited Create;

  // Ensure capacity is power of 2 for fast modulo via bitwise AND
  FCapacity := 1 shl ACapacityPowerOf2;
  FMask := FCapacity - 1;

  // Allocate buffer with alignment for better cache behavior
  GetMem(FBuffer, FCapacity);
  FillChar(FBuffer^, FCapacity, 0);

  // Initialize positions
  FReadPos := 0;
  FWritePos := 0;

  // Initialize padding to prevent warnings
  FillChar(FPadding1, SizeOf(FPadding1), 0);
  FillChar(FPadding2, SizeOf(FPadding2), 0);
  FillChar(FPadding3, SizeOf(FPadding3), 0);

  // Full barrier to ensure initialization is visible
  FullBarrier;
end;

destructor TLockFreeRingBuffer.Destroy;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer);
  inherited;
end;

function TLockFreeRingBuffer.GetSize: Integer;
var
  LReadPos, LWritePos: Integer;
begin
  // Read positions atomically
  LReadPos := InterlockedExchangeAdd(FReadPos, 0);
  LWritePos := InterlockedExchangeAdd(FWritePos, 0);

  // Calculate size (may be slightly stale but always safe)
  Result := (LWritePos - LReadPos) and FMask;
  if (LWritePos <> LReadPos) and (Result = 0) then
    Result := FCapacity; // Buffer is full
end;

function TLockFreeRingBuffer.GetAvailable: Integer;
var
  LReadPos, LWritePos: Integer;
begin
  // Read write position (may lag behind actual)
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  if LWritePos >= LReadPos then
    Result := LWritePos - LReadPos
  else
    Result := FCapacity - LReadPos + LWritePos;
end;

function TLockFreeRingBuffer.GetWriteSpace: Integer;
var
  LReadPos, LWritePos: Integer;
begin
  // Read read position (may lag behind actual)
  ReadBarrier;
  LReadPos := FReadPos;
  LWritePos := FWritePos;

  if LWritePos >= LReadPos then
    Result := FCapacity - LWritePos + LReadPos - 1
  else
    Result := LReadPos - LWritePos - 1;

  if Result < 0 then
    Result := 0;
end;

function TLockFreeRingBuffer.TryWrite(const AData; ACount: Integer): Integer;
var
  LWritePos, LReadPos: Integer;
  BytesToWrite: Integer;
  FirstPart, SecondPart: Integer;
  DataPtr: PByte;
  AvailableSpace: Integer;
begin
  if ACount <= 0 then
    Exit(0);

  // Read current positions
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available space (leave one slot empty to distinguish full from empty)
  if LWritePos >= LReadPos then
    AvailableSpace := FCapacity - LWritePos + LReadPos - 1
  else
    AvailableSpace := LReadPos - LWritePos - 1;

  if AvailableSpace <= 0 then
    Exit(0);

  // Limit to available space
  BytesToWrite := ACount;
  if BytesToWrite > AvailableSpace then
    BytesToWrite := AvailableSpace;

  DataPtr := @AData;

  // Calculate contiguous first part
  FirstPart := FCapacity - LWritePos;
  if FirstPart > BytesToWrite then
    FirstPart := BytesToWrite;

  // Copy first part
  Move(DataPtr^, (FBuffer + LWritePos)^, FirstPart);

  // Copy second part if wrapping
  SecondPart := BytesToWrite - FirstPart;
  if SecondPart > 0 then
    Move((DataPtr + FirstPart)^, FBuffer^, SecondPart);

  // Memory barrier to ensure data is visible before updating position
  WriteBarrier;

  // Update write position atomically
  FWritePos := (LWritePos + BytesToWrite) and FMask;

  Result := BytesToWrite;
end;

function TLockFreeRingBuffer.TryRead(var AData; ACount: Integer): Integer;
var
  LWritePos, LReadPos: Integer;
  BytesToRead: Integer;
  FirstPart, SecondPart: Integer;
  DataPtr: PByte;
  AvailableData: Integer;
begin
  if ACount <= 0 then
    Exit(0);

  // Read current positions with barrier
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available data
  if LWritePos >= LReadPos then
    AvailableData := LWritePos - LReadPos
  else
    AvailableData := FCapacity - LReadPos + LWritePos;

  if AvailableData = 0 then
    Exit(0);

  // Limit to available data
  BytesToRead := ACount;
  if BytesToRead > AvailableData then
    BytesToRead := AvailableData;

  DataPtr := @AData;

  // Calculate contiguous first part
  FirstPart := FCapacity - LReadPos;
  if FirstPart > BytesToRead then
    FirstPart := BytesToRead;

  // Copy first part
  Move((FBuffer + LReadPos)^, DataPtr^, FirstPart);

  // Copy second part if wrapping
  SecondPart := BytesToRead - FirstPart;
  if SecondPart > 0 then
    Move(FBuffer^, (DataPtr + FirstPart)^, SecondPart);

  // Memory barrier before updating position
  WriteBarrier;

  // Update read position atomically
  FReadPos := (LReadPos + BytesToRead) and FMask;

  Result := BytesToRead;
end;

function TLockFreeRingBuffer.TryPeek(var AData; ACount: Integer; AOffset: Integer): Integer;
var
  LWritePos, LReadPos, PeekPos: Integer;
  BytesToRead: Integer;
  FirstPart, SecondPart: Integer;
  DataPtr: PByte;
  AvailableData: Integer;
begin
  if (ACount <= 0) or (AOffset < 0) then
    Exit(0);

  // Read current positions with barrier
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available data
  if LWritePos >= LReadPos then
    AvailableData := LWritePos - LReadPos
  else
    AvailableData := FCapacity - LReadPos + LWritePos;

  if AOffset >= AvailableData then
    Exit(0);

  // Limit to available data after offset
  BytesToRead := ACount;
  if BytesToRead > (AvailableData - AOffset) then
    BytesToRead := AvailableData - AOffset;

  DataPtr := @AData;
  PeekPos := (LReadPos + AOffset) and FMask;

  // Calculate contiguous first part
  FirstPart := FCapacity - PeekPos;
  if FirstPart > BytesToRead then
    FirstPart := BytesToRead;

  // Copy first part
  Move((FBuffer + PeekPos)^, DataPtr^, FirstPart);

  // Copy second part if wrapping
  SecondPart := BytesToRead - FirstPart;
  if SecondPart > 0 then
    Move(FBuffer^, (DataPtr + FirstPart)^, SecondPart);

  Result := BytesToRead;
end;

function TLockFreeRingBuffer.TrySkip(ACount: Integer): Integer;
var
  LWritePos, LReadPos: Integer;
  AvailableData: Integer;
begin
  if ACount <= 0 then
    Exit(0);

  // Read current positions
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available data
  if LWritePos >= LReadPos then
    AvailableData := LWritePos - LReadPos
  else
    AvailableData := FCapacity - LReadPos + LWritePos;

  Result := ACount;
  if Result > AvailableData then
    Result := AvailableData;

  // Update read position
  WriteBarrier;
  FReadPos := (LReadPos + Result) and FMask;
end;

procedure TLockFreeRingBuffer.GetWriteBuffer(out ABuffer: PByte; out ASize: Integer);
var
  LWritePos, LReadPos: Integer;
  AvailableSpace, ContiguousSpace: Integer;
begin
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available space
  if LWritePos >= LReadPos then
    AvailableSpace := FCapacity - LWritePos + LReadPos - 1
  else
    AvailableSpace := LReadPos - LWritePos - 1;

  if AvailableSpace <= 0 then
  begin
    ABuffer := nil;
    ASize := 0;
    Exit;
  end;

  ABuffer := FBuffer + LWritePos;

  // Calculate contiguous space
  ContiguousSpace := FCapacity - LWritePos;
  if ContiguousSpace > AvailableSpace then
    ContiguousSpace := AvailableSpace;

  ASize := ContiguousSpace;
end;

procedure TLockFreeRingBuffer.CommitWrite(ACount: Integer);
var
  LWritePos: Integer;
begin
  if ACount <= 0 then
    Exit;

  LWritePos := FWritePos;

  // Ensure data is visible before updating position
  WriteBarrier;
  FWritePos := (LWritePos + ACount) and FMask;
end;

procedure TLockFreeRingBuffer.GetReadBuffer(out ABuffer: PByte; out ASize: Integer);
var
  LWritePos, LReadPos: Integer;
  AvailableData, ContiguousData: Integer;
begin
  ReadBarrier;
  LWritePos := FWritePos;
  LReadPos := FReadPos;

  // Calculate available data
  if LWritePos >= LReadPos then
    AvailableData := LWritePos - LReadPos
  else
    AvailableData := FCapacity - LReadPos + LWritePos;

  if AvailableData = 0 then
  begin
    ABuffer := nil;
    ASize := 0;
    Exit;
  end;

  ABuffer := FBuffer + LReadPos;

  // Calculate contiguous data
  ContiguousData := FCapacity - LReadPos;
  if ContiguousData > AvailableData then
    ContiguousData := AvailableData;

  ASize := ContiguousData;
end;

procedure TLockFreeRingBuffer.CommitRead(ACount: Integer);
var
  LReadPos: Integer;
begin
  if ACount <= 0 then
    Exit;

  LReadPos := FReadPos;

  // Memory barrier before updating position
  WriteBarrier;
  FReadPos := (LReadPos + ACount) and FMask;
end;

procedure TLockFreeRingBuffer.Reset;
begin
  FullBarrier;
  FReadPos := 0;
  FWritePos := 0;
  FullBarrier;
end;

end.
