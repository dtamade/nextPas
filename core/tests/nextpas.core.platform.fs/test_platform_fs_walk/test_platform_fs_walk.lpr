program test_platform_fs_walk;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  BASE = '/tmp/nextpas_walk_test';

procedure Cleanup;
begin
  platform_file_unlink(BASE + '/a/b/deep.txt');
  platform_file_rmdir(BASE + '/a/b');
  platform_file_unlink(BASE + '/a/file1.txt');
  platform_file_rmdir(BASE + '/a');
  platform_file_unlink(BASE + '/root.txt');
  platform_file_rmdir(BASE + '/empty');
  platform_file_rmdir(BASE);
end;

procedure SetupTree;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  Cleanup;
  platform_file_mkdir(BASE, 493);
  platform_file_mkdir(BASE + '/a', 493);
  platform_file_mkdir(BASE + '/a/b', 493);
  platform_file_mkdir(BASE + '/empty', 493);
  platform_file_open(BASE + '/root.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('r'), 1, W);
  platform_file_close(H);
  platform_file_open(BASE + '/a/file1.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('f'), 1, W);
  platform_file_close(H);
  platform_file_open(BASE + '/a/b/deep.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('d'), 1, W);
  platform_file_close(H);
end;

var
  GCount: Int32;
  GMaxDepth: Int32;
  GFoundDeep: Boolean;
  GFoundRoot: Boolean;

function CountCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
begin
  Inc(GCount);
  if AEntry.Depth > GMaxDepth then
    GMaxDepth := AEntry.Depth;
  Result := pwaContinue;
end;

procedure TestWalkCountsAll;
begin
  SetupTree;
  GCount := 0;
  GMaxDepth := 0;
  Check(platform_fs_walk(BASE, @CountCallback, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk completed');
  Check(GCount = 7, 'count=7 (root + a + a/b + a/b/deep.txt + a/file1.txt + root.txt + empty)');
  Check(GMaxDepth = 3, 'max depth=3');
  Cleanup;
end;

function StopAtDepth1(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
begin
  Inc(GCount);
  if AEntry.Depth >= 1 then
    Exit(pwaStop);
  Result := pwaContinue;
end;

procedure TestWalkStop;
begin
  SetupTree;
  GCount := 0;
  Check(platform_fs_walk(BASE, @StopAtDepth1, nil, False) = PLATFORM_WALK_STOPPED,
    'walk stopped');
  Check(GCount = 2, 'stopped after root + first child');
  Cleanup;
end;

function SkipSubtreeA(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
var
  LName: string;
begin
  Inc(GCount);
  SetString(LName, AEntry.Name, AEntry.NameLen);
  if LName = 'a' then
    Exit(pwaSkipSubtree);
  if LName = 'deep.txt' then
    GFoundDeep := True;
  Result := pwaContinue;
end;

procedure TestWalkSkipSubtree;
begin
  SetupTree;
  GCount := 0;
  GFoundDeep := False;
  Check(platform_fs_walk(BASE, @SkipSubtreeA, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk completed');
  Check(not GFoundDeep, 'deep.txt not visited (subtree skipped)');
  Check(GCount = 4, 'count=4 (root + a(skipped) + root.txt + empty)');
  Cleanup;
end;

procedure TestWalkBadArgs;
begin
  Check(platform_fs_walk(nil, @CountCallback, nil, False) = PLATFORM_WALK_BADARGS,
    'nil root');
  Check(platform_fs_walk(BASE, nil, nil, False) = PLATFORM_WALK_BADARGS,
    'nil callback');
end;

function DepthCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
begin
  Inc(GCount);
  if (AEntry.Depth = 0) and (AEntry.FileType = ftDirectory) then
    GFoundRoot := True;
  Result := pwaContinue;
end;

procedure TestWalkRootIsFirst;
begin
  SetupTree;
  GCount := 0;
  GFoundRoot := False;
  platform_fs_walk(BASE, @DepthCallback, nil, False);
  Check(GFoundRoot, 'root visited as directory at depth 0');
  Cleanup;
end;

procedure TestWalkNonExistentRoot;
begin
  GCount := 0;
  Check(platform_fs_walk('/tmp/nextpas_walk_nonexist_xyz', @CountCallback, nil, False) = PLATFORM_WALK_COMPLETED,
    'non-existent root completes');
  Check(GCount = 1, 'callback invoked once with error');
end;

function UserDataCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
begin
  if AUserData <> nil then
    PInt32(AUserData)^ := PInt32(AUserData)^ + 1;
  Result := pwaContinue;
end;

procedure TestWalkUserData;
var
  LCounter: Int32;
begin
  SetupTree;
  LCounter := 0;
  platform_fs_walk(BASE, @UserDataCallback, @LCounter, False);
  Check(LCounter = 7, 'user data counter = 7');
  Cleanup;
end;

procedure TestWalkSingleFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_open('/tmp/nextpas_walk_single.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W);
  platform_file_close(H);
  GCount := 0;
  Check(platform_fs_walk('/tmp/nextpas_walk_single.txt', @CountCallback, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk single file');
  Check(GCount = 1, 'single file: count=1');
  platform_file_unlink('/tmp/nextpas_walk_single.txt');
end;

procedure TestWalkEmptyDir;
begin
  platform_file_rmdir('/tmp/nextpas_walk_empty_dir');
  platform_file_mkdir('/tmp/nextpas_walk_empty_dir', 493);
  GCount := 0;
  Check(platform_fs_walk('/tmp/nextpas_walk_empty_dir', @CountCallback, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk empty dir');
  Check(GCount = 1, 'empty dir: count=1 (root only)');
  platform_file_rmdir('/tmp/nextpas_walk_empty_dir');
end;

var
  GSymlinkSeen: Boolean;
  GSymlinkType: TPlatformFileType;
  GDirDescended: Boolean;

function SymlinkCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
var
  LName: string;
begin
  Inc(GCount);
  SetString(LName, AEntry.Name, AEntry.NameLen);
  if LName = 'link_to_sub' then
  begin
    GSymlinkSeen := True;
    GSymlinkType := AEntry.FileType;
  end;
  if LName = 'inside.txt' then
    GDirDescended := True;
  Result := pwaContinue;
end;

procedure TestWalkSymlinkNoFollow;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
const
  DIR = '/tmp/nextpas_walk_symlink';
begin
  platform_file_unlink(DIR + '/sub/inside.txt');
  platform_file_rmdir(DIR + '/sub');
  platform_file_unlink(DIR + '/link_to_sub');
  platform_file_rmdir(DIR);

  platform_file_mkdir(DIR, 493);
  platform_file_mkdir(DIR + '/sub', 493);
  platform_file_open(DIR + '/sub/inside.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('i'), 1, W);
  platform_file_close(H);
  platform_file_symlink(DIR + '/sub', DIR + '/link_to_sub');

  GCount := 0;
  GSymlinkSeen := False;
  GDirDescended := False;
  GSymlinkType := ftUnknown;
  Check(platform_fs_walk(DIR, @SymlinkCallback, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk no-follow completed');
  Check(GSymlinkSeen, 'symlink entry seen');
  Check(GSymlinkType = ftSymlink, 'symlink reported as ftSymlink');
  Check(GCount = 4, 'count=4 (root + sub + sub/inside.txt + link_to_sub, symlink not descended)');

  platform_file_unlink(DIR + '/sub/inside.txt');
  platform_file_rmdir(DIR + '/sub');
  platform_file_unlink(DIR + '/link_to_sub');
  platform_file_rmdir(DIR);
end;

procedure TestWalkSymlinkFollow;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
const
  DIR = '/tmp/nextpas_walk_symlink_f';
begin
  platform_file_unlink(DIR + '/sub/inside.txt');
  platform_file_rmdir(DIR + '/sub');
  platform_file_unlink(DIR + '/link_to_sub');
  platform_file_rmdir(DIR);

  platform_file_mkdir(DIR, 493);
  platform_file_mkdir(DIR + '/sub', 493);
  platform_file_open(DIR + '/sub/inside.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('i'), 1, W);
  platform_file_close(H);
  platform_file_symlink(DIR + '/sub', DIR + '/link_to_sub');

  GCount := 0;
  GSymlinkSeen := False;
  GDirDescended := False;
  GSymlinkType := ftUnknown;
  Check(platform_fs_walk(DIR, @SymlinkCallback, nil, True) = PLATFORM_WALK_COMPLETED,
    'walk follow completed');
  Check(GSymlinkSeen, 'symlink entry seen');
  Check(GSymlinkType = ftDirectory, 'symlink resolved to ftDirectory (follow)');
  Check(GDirDescended, 'symlink target descended (follow)');
  Check(GCount = 5, 'count=5 (root + sub + sub/inside.txt + link_to_sub(dir) + link_to_sub/inside.txt)');

  platform_file_unlink(DIR + '/sub/inside.txt');
  platform_file_rmdir(DIR + '/sub');
  platform_file_unlink(DIR + '/link_to_sub');
  platform_file_rmdir(DIR);
end;

var
  GDanglingErrSeen: Boolean;

function DanglingCb(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
var
  LName: string;
begin
  Inc(GCount);
  SetString(LName, AEntry.Name, AEntry.NameLen);
  if (LName = 'broken_link') and (AEntry.FileType = ftSymlink) then
    GDanglingErrSeen := True;
  Result := pwaContinue;
end;

procedure TestWalkDanglingSymlink;
const
  DIR = '/tmp/nextpas_walk_dangling';
begin
  platform_file_unlink(DIR + '/broken_link');
  platform_file_rmdir(DIR);

  platform_file_mkdir(DIR, 493);
  platform_file_symlink('/tmp/nextpas_nonexistent_target_xyz', DIR + '/broken_link');

  GCount := 0;
  GDanglingErrSeen := False;
  Check(platform_fs_walk(DIR, @DanglingCb, nil, False) = PLATFORM_WALK_COMPLETED,
    'walk dangling completed');
  Check(GDanglingErrSeen, 'dangling symlink reported as ftSymlink');
  Check(GCount = 2, 'count=2 (root + broken_link)');

  platform_file_unlink(DIR + '/broken_link');
  platform_file_rmdir(DIR);
end;

procedure TestWalkCycleProtection;
const
  DIR = '/tmp/nextpas_walk_cycle';
begin
  platform_file_unlink(DIR + '/loop');
  platform_file_rmdir(DIR);

  platform_file_mkdir(DIR, 493);
  platform_file_symlink(DIR, DIR + '/loop');

  GCount := 0;
  Check(platform_fs_walk(DIR, @CountCallback, nil, True) = PLATFORM_WALK_COMPLETED,
    'walk cycle terminates');
  Check(GCount < 300, 'cycle bounded by max depth (count=' + IntToStr(GCount) + ')');
  Check(GCount >= 2, 'at least root + loop visited');

  platform_file_unlink(DIR + '/loop');
  platform_file_rmdir(DIR);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.fs.walk');
  T.Run('walk counts all', @TestWalkCountsAll);
  T.Run('walk stop', @TestWalkStop);
  T.Run('walk skip subtree', @TestWalkSkipSubtree);
  T.Run('walk bad args', @TestWalkBadArgs);
  T.Run('walk root is first', @TestWalkRootIsFirst);
  T.Run('walk non-existent root', @TestWalkNonExistentRoot);
  T.Run('walk user data', @TestWalkUserData);
  T.Run('walk single file', @TestWalkSingleFile);
  T.Run('walk empty dir', @TestWalkEmptyDir);
  T.Run('walk symlink no-follow', @TestWalkSymlinkNoFollow);
  T.Run('walk symlink follow', @TestWalkSymlinkFollow);
  T.Run('walk dangling symlink', @TestWalkDanglingSymlink);
  T.Run('walk cycle protection', @TestWalkCycleProtection);
  T.Summary;
end.
