{
# nextpas.core.mem.allocator.mapped_file

## 摘要

Mapped file allocator — 内存映射文件分配器。

特性:
- 文件映射到内存，支持持久化数据
- 分配器在映射区域内管理分配
- 支持 Flush 刷新到磁盘
- 支持 Create（新建）和 Open（打开已有）模式

适用场景: 持久化数据结构、数据库存储引擎、内存映射文件。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.mapped_file;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.memory_map;

type
  {** 映射文件分配器统计 }
  TMappedFileStats = record
    MappedSize: UInt64;      { 映射大小 }
    AllocatedBytes: UInt64;  { 已分配字节 }
    FreeBytes: UInt64;       { 空闲字节 }
    AllocCount: UInt32;      { 分配次数 }
  end;

  {** TMappedFileAllocator
   *
   *  内存映射文件分配器。
   *  将文件映射到内存，在映射区域内管理分配。
   *
   *  布局:
   *    [Header 64B: Magic+Version+AllocCount+FreeOffset...][User data...]
   *
   *  使用模式:
   *    var LAlloc: TMappedFileAllocator;
   *    LAlloc := TMappedFileAllocator.Create('/tmp/data.bin', 1024*1024);
   *    try
   *      LPtr := LAlloc.GetMem(1024);
   *      // ... 使用 LPtr ...
   *      LAlloc.Flush;  // 刷新到磁盘
   *    finally
   *      LAlloc.Free;
   *    end;
   *}
  TMappedFileAllocator = class(TInterfacedObject, IAllocator)
  private
    FMap: TMemoryMap;
    FFileName: string;
    FBaseAddress: Pointer;
    FMappedSize: UInt64;
    FFreeOffset: UInt64;    { 下一个空闲位置的偏移 }
    FAllocCount: UInt32;
    FIsCreator: Boolean;
    FIsFileBacked: Boolean;
    procedure InitHeader;
    procedure LoadHeader;
    class function PrepareFileForCreate(APath: PAnsiChar; ASize: UInt64): Boolean; static;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    {** 创建映射文件分配器
     *  @param AFileName 文件路径
     *  @param ASize 映射大小（字节）
     *  @param ACreate True=创建新文件，False=打开已有文件
     *}
    constructor Create(const AFileName: string; ASize: UInt64;
      ACreate: Boolean = True);
    destructor Destroy; override;

    {** 是否已映射 }
    function IsMapped: Boolean;
    {** 基地址 }
    function BaseAddress: Pointer;
    {** 映射大小 }
    function MappedSize: UInt64;
    {** 刷新到磁盘 }
    procedure Flush;
    {** 关闭映射 }
    procedure Close;
    {** 获取统计 }
    function GetStats: TMappedFileStats;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error,
  nextpas.core.platform.mmap,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base;

const
  MAPPED_FILE_MAGIC = $4D464C41; { 'MFLA' }
  MAPPED_FILE_VERSION = 1;
  MAPPED_FILE_HEADER_SIZE = 64;

type
  PMappedFileHeader = ^TMappedFileHeader;
  TMappedFileHeader = record
    Magic: UInt32;
    Version: UInt32;
    AllocCount: UInt32;
    FreeOffset: UInt64;
    MappedSize: UInt64;
    Reserved: array[0..39] of Byte; { 填充到 64 字节 }
  end;

{ TMappedFileAllocator }

constructor TMappedFileAllocator.Create(const AFileName: string; ASize: UInt64;
  ACreate: Boolean);
var
  LFilePath: RawByteString;
begin
  inherited Create;
  FFileName := AFileName;
  FMappedSize := ASize;
  FAllocCount := 0;
  FIsCreator := ACreate;

  FMap := TMemoryMap.Create;

  if AFileName = '' then
  begin
    { No file path: fall back to anonymous mapping (non-persistent) }
    FIsFileBacked := False;
    if not FMap.CreateAnonymous(ASize, mmaReadWrite, [mmfPrivate]) then
      raise EAllocError.Create(aeInvalidLayout,
        'TMappedFileAllocator.Create: failed to create anonymous mapping');
    FBaseAddress := FMap.BaseAddress;
    InitHeader;
  end
  else
  begin
    { File-backed mapping: persist data to disk }
    FIsFileBacked := True;
    LFilePath := RawByteString(AFileName);

    if ACreate then
    begin
      { Create mode: create or truncate the file to the requested size }
      if not PrepareFileForCreate(PAnsiChar(LFilePath), ASize) then
        raise EAllocError.Create(aeInvalidLayout,
          'TMappedFileAllocator.Create: failed to prepare file for create');
    end
    else
    begin
      { Open mode: file must already exist }
      if not FileExistsByStat(PAnsiChar(LFilePath)) then
        raise EAllocError.Create(aeInvalidLayout,
          'TMappedFileAllocator.Create: file does not exist');
    end;

    if not FMap.OpenFile(AFileName, mmaReadWrite, [mmfShared], ASize, 0) then
      raise EAllocError.Create(aeInvalidLayout,
        'TMappedFileAllocator.Create: failed to map file');

    FBaseAddress := FMap.BaseAddress;
    if ACreate then
      InitHeader
    else
      LoadHeader;
  end;
end;

destructor TMappedFileAllocator.Destroy;
begin
  if FMap <> nil then
  begin
    { Flush file-backed mappings to disk before closing }
    if FIsFileBacked and FMap.IsOpen then
      FMap.Flush;
    FMap.Close;
    FMap.Free;
  end;
  inherited Destroy;
end;

class function TMappedFileAllocator.PrepareFileForCreate(APath: PAnsiChar;
  ASize: UInt64): Boolean;
var
  LHandle: TPlatformFileHandle;
begin
  Result := False;
  if APath = nil then
    Exit;

  { Open with create-or-truncate semantics: creates if missing, truncates if exists }
  if platform_file_open(APath, fomReadWrite, fcmCreateAlways, LHandle) <> 0 then
    Exit;

  { Extend the file to the requested mapping size }
  if platform_file_truncate(LHandle, Int64(ASize)) <> 0 then
  begin
    platform_file_close(LHandle);
    Exit;
  end;

  platform_file_close(LHandle);
  Result := True;
end;

procedure TMappedFileAllocator.InitHeader;
var
  LHdr: PMappedFileHeader;
begin
  LHdr := PMappedFileHeader(FBaseAddress);
  LHdr^.Magic := MAPPED_FILE_MAGIC;
  LHdr^.Version := MAPPED_FILE_VERSION;
  LHdr^.AllocCount := 0;
  LHdr^.FreeOffset := MAPPED_FILE_HEADER_SIZE;
  LHdr^.MappedSize := FMappedSize;
  FillChar(LHdr^.Reserved, SizeOf(LHdr^.Reserved), 0);
  FFreeOffset := MAPPED_FILE_HEADER_SIZE;
end;

procedure TMappedFileAllocator.LoadHeader;
var
  LHdr: PMappedFileHeader;
begin
  LHdr := PMappedFileHeader(FBaseAddress);
  if LHdr^.Magic <> MAPPED_FILE_MAGIC then
    raise EAllocError.Create(aeInvalidLayout,
      'TMappedFileAllocator.Create: invalid file magic');
  if LHdr^.Version <> MAPPED_FILE_VERSION then
    raise EAllocError.Create(aeInvalidLayout,
      'TMappedFileAllocator.Create: unsupported version');
  FFreeOffset := LHdr^.FreeOffset;
  FAllocCount := LHdr^.AllocCount;
end;

function TMappedFileAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LAlignedSize: SizeUInt;
  LSizePtr: PSizeUInt;
begin
  Result := nil;
  if ASize = 0 then Exit;

  { 8 字节对齐 + size header }
  LAlignedSize := (ASize + SizeOf(SizeUInt) + 7) and not SizeUInt(7);

  { 检查空间 }
  if FFreeOffset + LAlignedSize > FMappedSize then
    Exit;

  { 分配: store size header, then user data }
  LSizePtr := PSizeUInt(PtrUInt(FBaseAddress) + FFreeOffset);
  LSizePtr^ := ASize;
  Result := Pointer(PByte(LSizePtr) + SizeOf(SizeUInt));
  Inc(FFreeOffset, LAlignedSize);
  Inc(FAllocCount);

  { 更新 header }
  PMappedFileHeader(FBaseAddress)^.FreeOffset := FFreeOffset;
  PMappedFileHeader(FBaseAddress)^.AllocCount := FAllocCount;
end;

function TMappedFileAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TMappedFileAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize, LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    { bump allocator: cannot free, just return nil }
    Exit(nil);
  end;

  { Read old requested size from header }
  LOldSize := PSizeUInt(PByte(APtr) - SizeOf(SizeUInt))^;

  { 分配新块 }
  Result := GetMem(ASize);
  if Result = nil then Exit;

  { 复制 min(old, new) }
  LCopySize := LOldSize;
  if LCopySize > ASize then
    LCopySize := ASize;
  Move(APtr^, Result^, LCopySize);

  { 注意：旧块不释放（bump allocator 语义） }
end;

procedure TMappedFileAllocator.FreeMem(APtr: Pointer); inline;
begin
  { bump allocator 不支持释放 }
  { 未来可以实现 free list }
end;

function TMappedFileAllocator.IsMapped: Boolean;
begin
  Result := (FMap <> nil) and FMap.IsOpen;
end;

function TMappedFileAllocator.BaseAddress: Pointer;
begin
  Result := FBaseAddress;
end;

function TMappedFileAllocator.MappedSize: UInt64;
begin
  Result := FMappedSize;
end;

procedure TMappedFileAllocator.Flush;
begin
  if FMap <> nil then
    FMap.Flush;
end;

procedure TMappedFileAllocator.Close;
begin
  if FMap <> nil then
    FMap.Close;
end;

function TMappedFileAllocator.GetStats: TMappedFileStats;
begin
  Result.MappedSize := FMappedSize;
  Result.AllocatedBytes := FFreeOffset - MAPPED_FILE_HEADER_SIZE;
  Result.FreeBytes := FMappedSize - FFreeOffset;
  Result.AllocCount := FAllocCount;
end;

function TMappedFileAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.SupportsRealloc := True;
end;

end.
