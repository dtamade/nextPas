program test_mapped_ring_buffer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.mapped_ring_buffer;

var
  T: TTestRunner;

function TempMappedRingPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_mapped_ring_buffer_' + IntToStr(GetProcessID) + '.bin';
end;

procedure TestFileBackedCreateAndOpen;
var
  LPath: string;
  LCreator: TMappedRingBuffer;
  LOpened: TMappedRingBuffer;
begin
  LPath := TempMappedRingPath;
  DeleteFile(LPath);

  LCreator := TMappedRingBuffer.Create;
  LOpened := TMappedRingBuffer.Create;
  try
    Check(LCreator.CreateFile(LPath, 8, SizeOf(UInt64)), 'create file-backed ring buffer');
    Check(FileExists(LPath), 'create file-backed ring buffer should create backing file');
    Check(LCreator.IsCreator, 'first file-backed create should initialize header');
    CheckEqual(Int64(8), Int64(LCreator.Capacity), 'normalized capacity');
    CheckEqual(Int64(SizeOf(UInt64)), Int64(LCreator.ElementSize), 'element size');
    LCreator.Close;

    Check(LOpened.OpenFile(LPath), 'open existing file-backed ring buffer');
    Check(not LOpened.IsCreator, 'OpenFile should not reinitialize existing backing file');
    CheckEqual(Int64(8), Int64(LOpened.Capacity), 'OpenFile persisted capacity');
    CheckEqual(Int64(SizeOf(UInt64)), Int64(LOpened.ElementSize), 'OpenFile persisted element size');
  finally
    LOpened.Free;
    LCreator.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestCreateFileReopensExisting;
var
  LPath: string;
  LCreator: TMappedRingBuffer;
  LReopened: TMappedRingBuffer;
begin
  LPath := TempMappedRingPath;
  DeleteFile(LPath);

  LCreator := TMappedRingBuffer.Create;
  LReopened := TMappedRingBuffer.Create;
  try
    Check(LCreator.CreateFile(LPath, 8, SizeOf(UInt64)), 'create first file-backed ring buffer');
    LCreator.Close;

    Check(LReopened.CreateFile(LPath, 8, SizeOf(UInt64)),
      'CreateFile should reopen existing backing file');
    Check(not LReopened.IsCreator, 'CreateFile existing path should not reinitialize header');
    CheckEqual(Int64(8), Int64(LReopened.Capacity), 'CreateFile existing persisted capacity');
    CheckEqual(Int64(SizeOf(UInt64)), Int64(LReopened.ElementSize), 'CreateFile existing persisted element size');
  finally
    LReopened.Free;
    LCreator.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestOpenFileRejectsMissingBackingFile;
var
  LPath: string;
  LBuffer: TMappedRingBuffer;
begin
  LPath := TempMappedRingPath;
  DeleteFile(LPath);

  LBuffer := TMappedRingBuffer.Create;
  try
    Check(not LBuffer.OpenFile(LPath), 'OpenFile should reject missing backing file');
    Check(not LBuffer.IsValid, 'missing backing file must not leave valid state');
  finally
    LBuffer.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestCreateFileRejectsLayoutOverflow;
var
  LPath: string;
  LBuffer: TMappedRingBuffer;
begin
  LPath := TempMappedRingPath;
  DeleteFile(LPath);

  LBuffer := TMappedRingBuffer.Create;
  try
    Check(not LBuffer.CreateFile(LPath, UInt64(1) shl 63, SizeOf(UInt64)),
      'CreateFile should reject layout overflow before creating a backing file');
    Check(not LBuffer.IsValid, 'layout overflow must not leave a valid ring buffer');
    Check(not FileExists(LPath), 'layout overflow must not create backing file');
  finally
    LBuffer.Free;
    DeleteFile(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_ring_buffer');
  T.Run('file-backed create and open', @TestFileBackedCreateAndOpen);
  T.Run('CreateFile reopens existing file', @TestCreateFileReopensExisting);
  T.Run('OpenFile rejects missing file', @TestOpenFileRejectsMissingBackingFile);
  T.Run('CreateFile rejects layout overflow', @TestCreateFileRejectsLayoutOverflow);
  T.Summary;
end.
