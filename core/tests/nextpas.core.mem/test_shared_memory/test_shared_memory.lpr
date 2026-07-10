program test_shared_memory;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.memory_map;

var
  T: TTestSuite;
  LRunPassed: Boolean;

function ShmName(AIndex: Integer): string;
begin
  Result := '/np_test_shm_' + IntToStr(AIndex);
end;

procedure TestCreateAndDestroy;
var
  LShm: TSharedMemory;
begin
  LShm := TSharedMemory.Create;
  try
    Check(not LShm.IsValid, 'fresh create should not be valid');
    CheckEqual('', LShm.Name);
    CheckEqual(Int64(0), Int64(LShm.Size));
    Check(not LShm.IsCreator, 'fresh create should not be creator');
  finally
    LShm.Free;
  end;
end;

procedure TestCreateShared;
var
  LShm: TSharedMemory;
  LOk: Boolean;
begin
  LShm := TSharedMemory.Create;
  try
    LOk := LShm.CreateShared(ShmName(1), 4096);
    Check(LOk, 'CreateShared should succeed');
    Check(LShm.IsValid, 'should be valid after CreateShared');
    CheckEqual(Int64(4096), Int64(LShm.Size));
    Check(LShm.IsCreator, 'first instance should be creator');
    CheckEqual(ShmName(1), LShm.Name);
  finally
    LShm.Free;
  end;
end;

procedure TestOpenShared;
var
  LCreator, LOpener: TSharedMemory;
begin
  LCreator := TSharedMemory.Create;
  LOpener := TSharedMemory.Create;
  try
    Check(LCreator.CreateShared(ShmName(2), 8192), 'CreateShared should succeed');
    Check(LCreator.IsValid, 'creator should be valid');
    Check(LCreator.IsCreator, 'creator flag set');

    Check(LOpener.OpenShared(ShmName(2)), 'OpenShared should succeed');
    Check(LOpener.IsValid, 'opener should be valid');
    Check(not LOpener.IsCreator, 'opener should not be creator');
    CheckEqual(Int64(8192), Int64(LOpener.Size));
  finally
    LOpener.Free;
    LCreator.Free;
  end;
end;

procedure TestReadWriteLPBytes;
var
  LShm: TSharedMemory;
  LWrite, LRead: RawByteString;
  LOk: Boolean;
begin
  LShm := TSharedMemory.Create;
  try
    Check(LShm.CreateShared(ShmName(3), 4096), 'CreateShared');

    LWrite := 'hello shared memory';
    LOk := LShm.WriteLPBytes(0, LWrite);
    Check(LOk, 'WriteLPBytes should succeed');

    LOk := LShm.ReadLPBytes(0, LRead);
    Check(LOk, 'ReadLPBytes should succeed');
    CheckEqual(LWrite, LRead);
  finally
    LShm.Free;
  end;
end;

procedure TestReadWriteLPUTF8;
var
  LShm: TSharedMemory;
  LWrite: UnicodeString;
  LRead: UTF8String;
  LOk: Boolean;
begin
  LShm := TSharedMemory.Create;
  try
    Check(LShm.CreateShared(ShmName(4), 4096), 'CreateShared');

    LWrite := 'utf8 test: hello world';
    LOk := LShm.WriteLPUTF8(0, LWrite);
    Check(LOk, 'WriteLPUTF8 should succeed');

    LOk := LShm.ReadLPUTF8(0, LRead);
    Check(LOk, 'ReadLPUTF8 should succeed');
    CheckEqual(UTF8String(LWrite), LRead);
  finally
    LShm.Free;
  end;
end;

procedure TestGetPointerAndBaseAddress;
var
  LShm: TSharedMemory;
  LP, LBase: Pointer;
begin
  LShm := TSharedMemory.Create;
  try
    Check(LShm.CreateShared(ShmName(5), 4096), 'CreateShared');

    LBase := LShm.GetBaseAddress;
    Check(LBase <> nil, 'BaseAddress should not be nil');

    LP := LShm.GetPointer(0);
    Check(LP <> nil, 'GetPointer(0) should not be nil');
    Check(LP = LBase, 'GetPointer(0) should equal BaseAddress');

    LP := LShm.GetPointer(100);
    Check(LP <> nil, 'GetPointer(100) should not be nil');
    Check(LP <> LBase, 'GetPointer(100) should differ from base');
  finally
    LShm.Free;
  end;
end;

procedure TestFlush;
var
  LShm: TSharedMemory;
  LWrite: RawByteString;
  LOk: Boolean;
begin
  LShm := TSharedMemory.Create;
  try
    Check(LShm.CreateShared(ShmName(6), 4096), 'CreateShared');

    LWrite := 'flush test data';
    Check(LShm.WriteLPBytes(0, LWrite), 'WriteLPBytes');

    LOk := LShm.Flush;
    Check(LOk, 'Flush should return True after write');
  finally
    LShm.Free;
  end;
end;

procedure TestCloseAndReopen;
var
  LShm: TSharedMemory;
begin
  LShm := TSharedMemory.Create;
  try
    Check(LShm.CreateShared(ShmName(7), 4096), 'CreateShared');
    Check(LShm.IsValid, 'should be valid after CreateShared');

    LShm.Close;
    Check(not LShm.IsValid, 'should not be valid after Close');
    CheckEqual('', LShm.Name);
    CheckEqual(Int64(0), Int64(LShm.Size));

    Check(LShm.CreateShared(ShmName(7), 4096), 'CreateShared again');
    Check(LShm.IsValid, 'should be valid after reopen');
  finally
    LShm.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.shared_memory');
  T.Test('Create and Destroy', @TestCreateAndDestroy);
  T.Test('CreateShared', @TestCreateShared);
  T.Test('OpenShared', @TestOpenShared);
  T.Test('Read/Write LPBytes', @TestReadWriteLPBytes);
  T.Test('Read/Write LPUTF8', @TestReadWriteLPUTF8);
  T.Test('GetPointer and BaseAddress', @TestGetPointerAndBaseAddress);
  T.Test('Flush', @TestFlush);
  T.Test('Close and Reopen', @TestCloseAndReopen);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
