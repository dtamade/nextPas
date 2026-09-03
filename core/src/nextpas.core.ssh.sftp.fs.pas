unit nextpas.core.ssh.sftp.fs;

{** nextpas.core.ssh.sftp.fs - SFTP 文件系统门面实现（四件套 impl）。
 *
 * 单职责：ISshFileSystem 语义（RealPath/Stat/ListDir/ReadFile/WriteFile 等）；
 * 委托 TSftpConnection 完成握手与流水线 RoundTrip，经 ISftpWire 解耦通道。
 * 性能：ReadFile/WriteFile SFTP_PIPELINE_WINDOW=16 流水线（RTT 线性屏蔽，16×32760≈512KB 在途，乱序缓冲）；
 *        ListDir/ReadFile 用 IBytesBuilder/BytesEnsureCapacity 几何倍增（BYTES_BUILDER_MIN_GROW 单源，O(n) amortized，避 O(n²)）；
 *        零拷贝 Move/CopyMem 单源 bytes.ops；热路径 inline。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.sftp.intf,
  nextpas.core.ssh.sftp.conn,
  nextpas.core.ssh.channel;

type
  TSshFileSystem = class(TInterfacedObject, ISshFileSystem)
  private
    FConn: TSftpConnection;
    FOwnsChan: Boolean;
    FChan: TSshChannel;
    function OpenHandle(const APath: string; APFlags: UInt32): TBytes;
    procedure CloseHandle(const AHandle: TBytes);
    function StatOf(AIsLstat: Boolean; const APath: string): TSftpAttrs;
  public
    constructor Create(AChannel: TSshChannel; ATimeoutMs: Integer);
    constructor CreateWithWire(AWire: ISftpWire; ATimeoutMs: Integer);
    destructor Destroy; override;
    function RealPath(const APath: string): string;
    function Stat(const APath: string): TSftpAttrs;
    function Lstat(const APath: string): TSftpAttrs;
    function ListDir(const APath: string): TSftpDirEntryArray;
    function ReadFile(const APath: string): TBytes;
    procedure WriteFile(const APath: string; const AData: TBytes);
    procedure Remove(const APath: string);
    procedure Mkdir(const APath: string);
    procedure Rmdir(const APath: string);
    procedure Rename(const AOldPath, ANewPath: string);
  end;

implementation

uses
  nextpas.core.bytes.builder,
  nextpas.core.bytes.ops,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.sftp.wire;

constructor TSshFileSystem.Create(AChannel: TSshChannel; ATimeoutMs: Integer);
var
  LConn: TSftpConnection;
begin
  inherited Create;
  FOwnsChan := True;
  LConn := TSftpConnection.Create(nextpas.core.ssh.sftp.wire.TSshChannelWire.Create(AChannel), ATimeoutMs);
  try
    LConn.Handshake;
  except
    LConn.Free;
    raise;
  end;
  FChan := AChannel;
  FConn := LConn;
end;

constructor TSshFileSystem.CreateWithWire(AWire: ISftpWire;
  ATimeoutMs: Integer);
var
  LConn: TSftpConnection;
begin
  inherited Create;
  FOwnsChan := False;
  FChan := nil;
  LConn := TSftpConnection.Create(AWire, ATimeoutMs);
  try
    LConn.Handshake;
  except
    LConn.Free;
    raise;
  end;
  FConn := LConn;
end;

destructor TSshFileSystem.Destroy;
begin
  FConn.Free;
  if FOwnsChan and (FChan <> nil) then
  begin
    FChan.TryClose;
    FChan.Free;
    FChan := nil;
  end;
  inherited Destroy;
end;

function TSshFileSystem.OpenHandle(const APath: string; APFlags: UInt32): TBytes;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LTail.PutUInt32(APFlags);
    PutAttrs(LTail, Default(TSftpAttrs));
    LRaw := FConn.RoundTrip(SSH_FXP_OPEN, LTail.ToBytes,
      [SSH_FXP_HANDLE], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    Result := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
end;

procedure TSshFileSystem.CloseHandle(const AHandle: TBytes);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(16);
  try
    LTail.PutStringBytes(AHandle);
    FConn.RoundTrip(SSH_FXP_CLOSE, LTail.ToBytes, [SSH_FXP_STATUS], LRT, 'close');
  finally
    LTail.Free;
  end;
end;

function TSshFileSystem.StatOf(AIsLstat: Boolean; const APath: string): TSftpAttrs;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    if AIsLstat then
      LRaw := FConn.RoundTrip(SSH_FXP_LSTAT, LTail.ToBytes,
        [SSH_FXP_ATTRS], LRT, APath)
    else
      LRaw := FConn.RoundTrip(SSH_FXP_STAT, LTail.ToBytes,
        [SSH_FXP_ATTRS], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    Result := ReadAttrs(LR);
  finally
    LR.Free;
  end;
end;

function TSshFileSystem.RealPath(const APath: string): string;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LN, I: Integer;
  LBuilder: IStringBuilder;
  LFirst: Boolean;
  LText: string;
begin
  Result := '';
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LRaw := FConn.RoundTrip(SSH_FXP_REALPATH, LTail.ToBytes,
      [SSH_FXP_NAME], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    LN := Integer(LR.ReadUInt32);
    if LN > 0 then
    begin
      // perf: IStringBuilder 倍增追加 O(n) amortized，避 Result+', '+text O(n²) 重复拷贝与临时串；Move 零拷贝单源 bytes.ops/text.builder，inline 热路径；接口 refcount 保释放
      LBuilder := MakeStringBuilder(256);
      LFirst := True;
      for I := 1 to LN do
      begin
        LText := LR.ReadStringText;
        LR.ReadStringText;
        ReadAttrs(LR);
        if LFirst then
          LFirst := False
        else
          LBuilder.AppendStr(', ');
        LBuilder.AppendStr(LText);
      end;
      Result := LBuilder.ToString;
    end;
  finally
    LR.Free;
  end;
end;

function TSshFileSystem.Stat(const APath: string): TSftpAttrs;
begin
  Result := StatOf(False, APath);
end;

function TSshFileSystem.Lstat(const APath: string): TSftpAttrs;
begin
  Result := StatOf(True, APath);
end;

function TSshFileSystem.ListDir(const APath: string): TSftpDirEntryArray;
var
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LHandle: TBytes;
  LEof: Boolean;
  LN, I: Integer;
  LCount, LCap: SizeUInt;
  LName, LLong: string;
  LAttrs: TSftpAttrs;
begin
  Result := nil;
  LCount := 0;
  LCap := 0;
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    LRaw := FConn.RoundTrip(SSH_FXP_OPENDIR, LTail.ToBytes,
      [SSH_FXP_HANDLE], LRT, APath);
  finally
    LTail.Free;
  end;
  LR := TsshReader.Create(LRaw);
  try
    LR.ReadByte;
    LR.ReadUInt32;
    LHandle := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  try
    repeat
      LTail := TsshWriter.Create(16);
      try
        LTail.PutStringBytes(LHandle);
        LRaw := FConn.RoundTrip(SSH_FXP_READDIR, LTail.ToBytes,
          [SSH_FXP_NAME, SSH_FXP_STATUS], LRT, APath);
      finally
        LTail.Free;
      end;
      LEof := False;
      if LRT = SSH_FXP_STATUS then
        LEof := True
      else
      begin
        LR := TsshReader.Create(LRaw);
        try
          LR.ReadByte;
          LR.ReadUInt32;
          LN := Integer(LR.ReadUInt32);
          for I := 1 to LN do
          begin
            // perf: read all fields first, filter dot before growing array (avoid O(n²) churn)
            LName := LR.ReadStringText;
            LLong := LR.ReadStringText;
            LAttrs := ReadAttrs(LR);
            if (LName = '.') or (LName = '..') then
              Continue;
            // perf: BytesEnsureCapacity 单源几何倍增（BYTES_BUILDER_MIN_GROW=64, 2×），inline 零拷贝，避免三处手写 16→2× 漂移
            if LCount >= LCap then
            begin
              BytesEnsureCapacity(LCap, LCount + 1);
              SetLength(Result, LCap);
            end;
            Result[LCount].Name := LName;
            Result[LCount].LongName := LLong;
            Result[LCount].Attrs := LAttrs;
            Inc(LCount);
          end;
        finally
          LR.Free;
        end;
      end;
    until LEof;
  finally
    CloseHandle(LHandle);
  end;
  if LCount <> LCap then
    SetLength(Result, LCount);
end;

function TSshFileSystem.ReadFile(const APath: string): TBytes;
var
  LHandle: TBytes;
  LNextOffset: UInt64;
  LTail: TsshWriter;
  LRaw: TBytes;
  LR: TsshReader;
  LRT: Byte;
  LChunk: TBytes;
  LBuilder: IBytesBuilder;
  LPendingIds: array of UInt32;
  LPendingOffs: array of UInt64;
  LPendingHead: SizeUInt;
  LPendingCount: SizeUInt;
  LId: UInt32;
  LTargetWindow: SizeUInt;
  // perf: ring buffer O(1) push/pop via modulo index, no linear compaction Move; BytesEnsureCapacity单源几何倍增, inline, Move零拷贝仅扩容线性化时
  function PendingFirstId: UInt32; inline;
  begin
    Result := LPendingIds[LPendingHead];
  end;
  procedure PushPending(AId: UInt32; AOff: UInt64); inline;
  var LCap, LOldCap: SizeUInt; LTail: SizeUInt; LNewIds: array of UInt32; LNewOffs: array of UInt64; LFirstPart: SizeUInt;
  begin
    LCap := SizeUInt(Length(LPendingIds));
    if LPendingCount >= LCap then
    begin
      LOldCap := LCap;
      BytesEnsureCapacity(LCap, LPendingCount + 1);
      if LCap <> LOldCap then
      begin
        if LOldCap = 0 then
        begin
          SetLength(LPendingIds, LCap);
          SetLength(LPendingOffs, LCap);
        end
        else if LPendingHead = 0 then
        begin
          SetLength(LPendingIds, LCap);
          SetLength(LPendingOffs, LCap);
        end
        else
        begin
          SetLength(LNewIds, LCap);
          SetLength(LNewOffs, LCap);
          if LPendingHead + LPendingCount <= LOldCap then
          begin
            Move(LPendingIds[LPendingHead], LNewIds[0], LPendingCount * SizeOf(UInt32));
            Move(LPendingOffs[LPendingHead], LNewOffs[0], LPendingCount * SizeOf(UInt64));
          end
          else
          begin
            LFirstPart := LOldCap - LPendingHead;
            Move(LPendingIds[LPendingHead], LNewIds[0], LFirstPart * SizeOf(UInt32));
            Move(LPendingIds[0], LNewIds[LFirstPart], (LPendingCount - LFirstPart) * SizeOf(UInt32));
            Move(LPendingOffs[LPendingHead], LNewOffs[0], LFirstPart * SizeOf(UInt64));
            Move(LPendingOffs[0], LNewOffs[LFirstPart], (LPendingCount - LFirstPart) * SizeOf(UInt64));
          end;
          LPendingIds := LNewIds;
          LPendingOffs := LNewOffs;
          LPendingHead := 0;
        end;
      end;
      LCap := SizeUInt(Length(LPendingIds));
    end;
    LTail := (LPendingHead + LPendingCount) mod LCap;
    LPendingIds[LTail] := AId;
    LPendingOffs[LTail] := AOff;
    Inc(LPendingCount);
  end;
  procedure PopFrontPending; inline;
  var LCap: SizeUInt;
  begin
    if LPendingCount = 0 then Exit;
    LCap := SizeUInt(Length(LPendingIds));
    if LCap = 0 then
    begin
      Dec(LPendingCount);
      LPendingHead := 0;
      Exit;
    end;
    LPendingHead := (LPendingHead + 1) mod LCap;
    Dec(LPendingCount);
    if LPendingCount = 0 then
      LPendingHead := 0;
  end;
  procedure PopPendingAt(AIdx: SizeUInt); inline;
  var LCap: SizeUInt; I: SizeUInt; LPhys, LNext: SizeUInt;
  begin
    if AIdx >= LPendingCount then Exit;
    if AIdx = 0 then
    begin
      PopFrontPending;
      Exit;
    end;
    LCap := SizeUInt(Length(LPendingIds));
    for I := AIdx to LPendingCount - 2 do
    begin
      LPhys := (LPendingHead + I) mod LCap;
      LNext := (LPendingHead + I + 1) mod LCap;
      LPendingIds[LPhys] := LPendingIds[LNext];
      LPendingOffs[LPhys] := LPendingOffs[LNext];
    end;
    Dec(LPendingCount);
    if LPendingCount = 0 then
      LPendingHead := 0;
  end;
begin
  LBuilder := CreateBytesBuilder;
  LHandle := OpenHandle(APath, SSH_FXF_READ);
  try
    LNextOffset := 0;
    LPendingHead := 0;
    LPendingCount := 0;
    SetLength(LPendingIds, 0);
    SetLength(LPendingOffs, 0);
    // perf: SFTP_PIPELINE_WINDOW=16 流水线，RTT 线性屏蔽（16×32760≈512KB 在途），乱序缓冲；IBytesBuilder 倍增+inline零拷贝；head+count O(1) 零抖动
    LTail := TsshWriter.Create(24);
    try
      LTail.PutStringBytes(LHandle);
      LTail.PutUInt64(LNextOffset);
      LTail.PutUInt32(SFTP_CHUNK_SIZE);
      LId := FConn.SendRequest(SSH_FXP_READ, LTail.ToBytes);
    finally LTail.Free; end;
    PushPending(LId, LNextOffset);
    Inc(LNextOffset, SFTP_CHUNK_SIZE);
    while LPendingCount > 0 do
    begin
      // recv earliest in-flight (out-of-order buffered internally)
      LRaw := FConn.RecvForId(PendingFirstId, [SSH_FXP_DATA, SSH_FXP_STATUS], LRT, APath);
      PopFrontPending;
      if LRT = SSH_FXP_STATUS then
        Break;
      LR := TsshReader.Create(LRaw);
      try
        LR.ReadByte;
        LR.ReadUInt32;
        LChunk := LR.ReadStringBytes;
      finally LR.Free; end;
      if Length(LChunk) = 0 then
        Break;
      // perf: IBytesBuilder 倍增追加，O(n) amortized，零拷贝 Move 单次/块，避免 O(n²) SetLength+Move；inline 热路径
      LBuilder.AppendBytes(@LChunk[0], SizeUInt(Length(LChunk)));
      if SizeUInt(Length(LChunk)) = SFTP_CHUNK_SIZE then
        LTargetWindow := SFTP_PIPELINE_WINDOW
      else
        LTargetWindow := 1;
      // fill pipeline to target window
      while LPendingCount < LTargetWindow do
      begin
        LTail := TsshWriter.Create(24);
        try
          LTail.PutStringBytes(LHandle);
          LTail.PutUInt64(LNextOffset);
          LTail.PutUInt32(SFTP_CHUNK_SIZE);
          LId := FConn.SendRequest(SSH_FXP_READ, LTail.ToBytes);
        finally LTail.Free; end;
        PushPending(LId, LNextOffset);
        Inc(LNextOffset, SFTP_CHUNK_SIZE);
        if LTargetWindow = 1 then Break;
      end;
    end;
    // drain over-sent pipeline (EOF probes) to avoid buffered leak
    while LPendingCount > 0 do
    begin
      try
        LRaw := FConn.RecvForId(PendingFirstId, [SSH_FXP_DATA, SSH_FXP_STATUS], LRT, APath);
      except
        Break;
      end;
      PopFrontPending;
      if LRT = SSH_FXP_STATUS then Break;
      LR := TsshReader.Create(LRaw);
      try
        LR.ReadByte; LR.ReadUInt32;
        LChunk := LR.ReadStringBytes;
      finally LR.Free; end;
      if Length(LChunk) > 0 then
        LBuilder.AppendBytes(@LChunk[0], SizeUInt(Length(LChunk)));
      if SizeUInt(Length(LChunk)) < SFTP_CHUNK_SIZE then Break;
    end;
  finally
    CloseHandle(LHandle);
  end;
  Result := LBuilder.ToBytes;
end;

procedure TSshFileSystem.WriteFile(const APath: string; const AData: TBytes);
var
  LHandle: TBytes;
  LOffset: UInt64;
  LOff: SizeUInt;
  LTake: SizeUInt;
  LTail: TsshWriter;
  LRT: Byte;
  LPending: array of UInt32;
  LPendingHead: SizeUInt;
  LPendingCount: SizeUInt;
  LId: UInt32;
  // perf: ring buffer O(1) via modulo, no Move compaction on pop/push; BytesEnsureCapacity单源, inline, Move仅扩容线性化
  function PendingFirst: UInt32; inline;
  begin
    Result := LPending[LPendingHead];
  end;
  procedure Push(AId: UInt32); inline;
  var LCap, LOldCap: SizeUInt; LTail: SizeUInt; LNew: array of UInt32; LFirstPart: SizeUInt;
  begin
    LCap := SizeUInt(Length(LPending));
    if LPendingCount >= LCap then
    begin
      LOldCap := LCap;
      BytesEnsureCapacity(LCap, LPendingCount + 1);
      if LCap <> LOldCap then
      begin
        if LOldCap = 0 then
          SetLength(LPending, LCap)
        else if LPendingHead = 0 then
          SetLength(LPending, LCap)
        else
        begin
          SetLength(LNew, LCap);
          if LPendingHead + LPendingCount <= LOldCap then
            Move(LPending[LPendingHead], LNew[0], LPendingCount * SizeOf(UInt32))
          else
          begin
            LFirstPart := LOldCap - LPendingHead;
            Move(LPending[LPendingHead], LNew[0], LFirstPart * SizeOf(UInt32));
            Move(LPending[0], LNew[LFirstPart], (LPendingCount - LFirstPart) * SizeOf(UInt32));
          end;
          LPending := LNew;
          LPendingHead := 0;
        end;
      end;
      LCap := SizeUInt(Length(LPending));
    end;
    LTail := (LPendingHead + LPendingCount) mod LCap;
    LPending[LTail] := AId;
    Inc(LPendingCount);
  end;
  procedure PopFront; inline;
  var LCap: SizeUInt;
  begin
    if LPendingCount = 0 then Exit;
    LCap := SizeUInt(Length(LPending));
    if LCap = 0 then
    begin
      Dec(LPendingCount);
      LPendingHead := 0;
      Exit;
    end;
    LPendingHead := (LPendingHead + 1) mod LCap;
    Dec(LPendingCount);
    if LPendingCount = 0 then
      LPendingHead := 0;
  end;
begin
  LHandle := OpenHandle(APath, SSH_FXF_WRITE or SSH_FXF_CREAT or SSH_FXF_TRUNC);
  try
    // perf: SFTP_PIPELINE_WINDOW=16 流水线，RTT 线性屏蔽（16×32760≈512KB），零拷贝 PutRaw；inline 热路径
    LOff := 0;
    LOffset := 0;
    LPendingHead := 0;
    LPendingCount := 0;
    SetLength(LPending, 0);
    // fill initial window
    while (LOff < SizeUInt(Length(AData))) and (LPendingCount < SFTP_PIPELINE_WINDOW) do
    begin
      LTake := SizeUInt(Length(AData)) - LOff;
      if LTake > SFTP_CHUNK_SIZE then
        LTake := SFTP_CHUNK_SIZE;
      LTail := TsshWriter.Create(24 + Integer(LTake));
      try
        LTail.PutStringBytes(LHandle);
        LTail.PutUInt64(LOffset);
        LTail.PutUInt32(UInt32(LTake));
        if LTake > 0 then
          LTail.PutRaw(@AData[LOff], LTake);
        LId := FConn.SendRequest(SSH_FXP_WRITE, LTail.ToBytes);
      finally LTail.Free; end;
      Push(LId);
      Inc(LOff, LTake);
      Inc(LOffset, LTake);
    end;
    while LPendingCount > 0 do
    begin
      FConn.RecvForId(PendingFirst, [SSH_FXP_STATUS], LRT, APath);
      PopFront;
      while (LOff < SizeUInt(Length(AData))) and (LPendingCount < SFTP_PIPELINE_WINDOW) do
      begin
        LTake := SizeUInt(Length(AData)) - LOff;
        if LTake > SFTP_CHUNK_SIZE then
          LTake := SFTP_CHUNK_SIZE;
        LTail := TsshWriter.Create(24 + Integer(LTake));
        try
          LTail.PutStringBytes(LHandle);
          LTail.PutUInt64(LOffset);
          LTail.PutUInt32(UInt32(LTake));
          if LTake > 0 then
            LTail.PutRaw(@AData[LOff], LTake);
          LId := FConn.SendRequest(SSH_FXP_WRITE, LTail.ToBytes);
        finally LTail.Free; end;
        Push(LId);
        Inc(LOff, LTake);
        Inc(LOffset, LTake);
      end;
    end;
  finally
    CloseHandle(LHandle);
  end;
end;

procedure TSshFileSystem.Remove(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    FConn.RoundTrip(SSH_FXP_REMOVE, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Mkdir(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(80);
  try
    LTail.PutStringText(APath);
    PutAttrs(LTail, Default(TSftpAttrs));
    FConn.RoundTrip(SSH_FXP_MKDIR, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Rmdir(const APath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(64);
  try
    LTail.PutStringText(APath);
    FConn.RoundTrip(SSH_FXP_RMDIR, LTail.ToBytes, [SSH_FXP_STATUS], LRT, APath);
  finally
    LTail.Free;
  end;
end;

procedure TSshFileSystem.Rename(const AOldPath, ANewPath: string);
var
  LTail: TsshWriter;
  LRT: Byte;
begin
  LTail := TsshWriter.Create(128);
  try
    LTail.PutStringText(AOldPath);
    LTail.PutStringText(ANewPath);
    FConn.RoundTrip(SSH_FXP_RENAME, LTail.ToBytes, [SSH_FXP_STATUS],
      LRT, AOldPath + ' -> ' + ANewPath);
  finally
    LTail.Free;
  end;
end;

end.
