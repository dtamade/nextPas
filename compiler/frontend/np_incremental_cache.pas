{**
 * np_incremental_cache.pas — Incremental Compilation Cache
 *
 * 符号表热缓存：序列化 TSemanticModel 为二进制格式，
 * 通过依赖指纹实现增量编译。
 *
 * 设计：
 *   - 缓存路径: .nextpas/cache/<unit-id>.npc
 *   - 指纹: 源文件内容 SHA256 + 依赖 hash
 *   - 格式: magic(4) + version(4) + fingerprint(32) + data
 *
 * 对标 rustc 的 incr-comp-session-cache，Go 的 build cache
 *}

unit np_incremental_cache;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.text.conv,
  np_semantic_model;

const
  { V2 wire format: magic | version | headerSize | payloadSize |
    fingerprint[32] | payloadDigest[32] | payload }
  NPC_MAGIC        = $4E504302;  { 'NPC\x02' }
  NPC_VERSION       = 2;
  NPC_HEADER_SIZE   = 80;   { 4+4+4+4+32+32 }
  NPC_FINGERPRINT_SIZE = 32;
  NPC_DIGEST_SIZE     = 32;
  NPC_MAX_PAYLOAD_SIZE = 64 * 1024 * 1024;   { 64 MiB }
  NPC_MAX_STRING_SIZE  = 8 * 1024 * 1024;    { 8 MiB }
  NPC_MAX_SECTION_COUNT = 1000000;

type
  {** 缓存条目元数据 }
  TCacheEntryMeta = record
    UnitId: string;
    Fingerprint: TBytes;
    SourceHash: TBytes;
    DepsHash: TBytes;
    Timestamp: Int64;
  end;

  {** 增量编译缓存管理器 }
  TIncrementalCache = class
  private
    FCacheDir: string;
    FEnabled: Boolean;
    function ComputeSourceHash(const ASourceText: string): TBytes;
    function ComputeDepsHash(const ADeps: array of string): TBytes;
    function CombineFingerprint(const ASourceHash, ADepsHash: TBytes): TBytes;
  public
    constructor Create(const ACacheDir: string);
    destructor Destroy; override;

    {** Return the cache file path for a unit }
    function EntryPath(const AUnitId: string): string;

    {** 检查缓存是否可用 }
    function HasCache(const AUnitId: string;
      const ASourceText: string;
      const ADeps: array of string): Boolean;

    {** 加载缓存的语义模型 }
    function Load(const AUnitId: string;
      const ASourceText: string;
      const ADeps: array of string;
      out AModel: TSemanticModel): Boolean;

    {** 保存语义模型到缓存 }
    procedure Save(const AUnitId: string;
      const ASourceText: string;
      const ADeps: array of string;
      const AModel: TSemanticModel);

    {** 使缓存失效 }
    procedure Invalidate(const AUnitId: string);

    {** 清除所有缓存 }
    procedure Clear;

    {** 缓存目录 }
    property CacheDir: string read FCacheDir;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

implementation

uses
  nextpas.core.hash;

{ --- 二进制写入辅助 --- }

type
  TBinaryWriter = class
  private
    FBuf: TBytes;
    FPos: LongInt;
    procedure Grow(ABytes: LongInt);
  public
    constructor Create;
    destructor Destroy; override;
    procedure WriteByte(AVal: Byte);
    procedure WriteInt32(AVal: LongInt);
    procedure WriteInt64(AVal: Int64);
    procedure WriteBool(AVal: Boolean);
    procedure WriteStr(const AVal: string);
    procedure WriteBytes(const AVal: TBytes);
    procedure WriteRaw(const AData; ASize: LongInt);
    function Data: TBytes;
    function Size: LongInt;
  end;

constructor TBinaryWriter.Create;
begin
  inherited Create;
  SetLength(FBuf, 256);
  FPos := 0;
end;

destructor TBinaryWriter.Destroy;
begin
  SetLength(FBuf, 0);
  inherited Destroy;
end;

procedure TBinaryWriter.Grow(ABytes: LongInt);
begin
  if FPos + ABytes > Length(FBuf) then
    SetLength(FBuf, (FPos + ABytes + 255) and not 255);
end;

procedure TBinaryWriter.WriteByte(AVal: Byte);
begin
  Grow(1);
  FBuf[FPos] := AVal;
  Inc(FPos);
end;

procedure TBinaryWriter.WriteInt32(AVal: LongInt);
begin
  Grow(4);
  Move(AVal, FBuf[FPos], 4);
  Inc(FPos, 4);
end;

procedure TBinaryWriter.WriteInt64(AVal: Int64);
begin
  Grow(8);
  Move(AVal, FBuf[FPos], 8);
  Inc(FPos, 8);
end;

procedure TBinaryWriter.WriteBool(AVal: Boolean);
begin
  if AVal then WriteByte(1) else WriteByte(0);
end;

procedure TBinaryWriter.WriteStr(const AVal: string);
var
  Len: LongInt;
begin
  Len := Length(AVal);
  WriteInt32(Len);
  if Len > 0 then
  begin
    Grow(Len);
    Move(AVal[1], FBuf[FPos], Len);
    Inc(FPos, Len);
  end;
end;

procedure TBinaryWriter.WriteBytes(const AVal: TBytes);
var
  Len: LongInt;
begin
  Len := Length(AVal);
  WriteInt32(Len);
  if Len > 0 then
  begin
    Grow(Len);
    Move(AVal[0], FBuf[FPos], Len);
    Inc(FPos, Len);
  end;
end;

procedure TBinaryWriter.WriteRaw(const AData; ASize: LongInt);
begin
  Grow(ASize);
  Move(AData, FBuf[FPos], ASize);
  Inc(FPos, ASize);
end;

function TBinaryWriter.Data: TBytes;
begin
  SetLength(Result, FPos);
  Move(FBuf[0], Result[0], FPos);
end;

function TBinaryWriter.Size: LongInt;
begin
  Result := FPos;
end;

{ --- 二进制读取辅助 --- }

type
  TBinaryReader = class
  private
    FBuf: TBytes;
    FSize: LongInt;
  public
    FPos: LongInt;
    constructor Create(const AData: TBytes);
    destructor Destroy; override;
    function ReadByte: Byte;
    function ReadInt32: LongInt;
    function ReadInt64: Int64;
    function ReadBool: Boolean;
    function ReadStr: string;
    function ReadBytes: TBytes;
    procedure ReadRaw(out AData; ASize: LongInt);
    function EOF: Boolean;
  end;

constructor TBinaryReader.Create(const AData: TBytes);
begin
  inherited Create;
  FBuf := AData;
  FPos := 0;
  FSize := Length(AData);
end;

destructor TBinaryReader.Destroy;
begin
  inherited Destroy;
end;

function TBinaryReader.ReadByte: Byte;
begin
  if FPos >= FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF');
  Result := FBuf[FPos];
  Inc(FPos);
end;

function TBinaryReader.ReadInt32: LongInt;
begin
  if FPos + 4 > FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF reading Int32');
  Move(FBuf[FPos], Result, 4);
  Inc(FPos, 4);
end;

function TBinaryReader.ReadInt64: Int64;
begin
  if FPos + 8 > FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF reading Int64');
  Move(FBuf[FPos], Result, 8);
  Inc(FPos, 8);
end;

function TBinaryReader.ReadBool: Boolean;
begin
  Result := ReadByte <> 0;
end;

function TBinaryReader.ReadStr: string;
var
  Len: LongInt;
begin
  Len := ReadInt32;
  if Len < 0 then
    raise Exception.Create('TBinaryReader: invalid string length');
  if Len > NPC_MAX_STRING_SIZE then
    raise Exception.Create('TBinaryReader: string exceeds max size');
  if Len = 0 then
    Exit('');
  if FPos + Len > FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF reading string');
  SetLength(Result, Len);
  Move(FBuf[FPos], Result[1], Len);
  Inc(FPos, Len);
end;

function TBinaryReader.ReadBytes: TBytes;
var
  Len: LongInt;
begin
  Len := ReadInt32;
  if Len < 0 then
    raise Exception.Create('TBinaryReader: invalid bytes length');
  if Len > NPC_MAX_PAYLOAD_SIZE then
    raise Exception.Create('TBinaryReader: bytes exceed max size');
  if Len = 0 then
    Exit(nil);
  if FPos + Len > FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF reading bytes');
  SetLength(Result, Len);
  Move(FBuf[FPos], Result[0], Len);
  Inc(FPos, Len);
end;

procedure TBinaryReader.ReadRaw(out AData; ASize: LongInt);
begin
  if FPos + ASize > FSize then
    raise Exception.Create('TBinaryReader: unexpected EOF reading raw');
  Move(FBuf[FPos], AData, ASize);
  Inc(FPos, ASize);
end;

function TBinaryReader.EOF: Boolean;
begin
  Result := FPos >= FSize;
end;

{ --- 指纹计算 --- }

function HashBytes(const AData: TBytes): TBytes;
var
  Digest: TSHA256Digest;
begin
  if Length(AData) > 0 then
    Digest := SHA256Of(AData[0], Length(AData))
  else
    Digest := SHA256Of(Nil^, 0);
  SetLength(Result, 32);
  Move(Digest[0], Result[0], 32);
end;

function HashStr(const AStr: string): TBytes;
var
  Tmp: TBytes;
begin
  SetLength(Tmp, Length(AStr));
  if Length(AStr) > 0 then
    Move(AStr[1], Tmp[0], Length(AStr));
  Result := HashBytes(Tmp);
end;

function CombineHashes(const A, B: TBytes): TBytes;
var
  Tmp: TBytes;
begin
  SetLength(Tmp, Length(A) + Length(B));
  if Length(A) > 0 then
    Move(A[0], Tmp[0], Length(A));
  if Length(B) > 0 then
    Move(B[0], Tmp[Length(A)], Length(B));
  Result := HashBytes(Tmp);
end;

{ --- TIncrementalCache --- }

constructor TIncrementalCache.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
  FEnabled := True;
end;

destructor TIncrementalCache.Destroy;
begin
  inherited Destroy;
end;

function TIncrementalCache.EntryPath(const AUnitId: string): string;
begin
  Result := FCacheDir + '/' + AUnitId + '.npc';
end;

function TIncrementalCache.ComputeSourceHash(const ASourceText: string): TBytes;
begin
  Result := HashStr(ASourceText);
end;

function TIncrementalCache.ComputeDepsHash(const ADeps: array of string): TBytes;
var
  I: LongInt;
  DepHash: TBytes;
begin
  SetLength(Result, 4);
  FillChar(Result[0], 4, 0);
  for I := 0 to High(ADeps) do
  begin
    DepHash := HashStr(ADeps[I]);
    Result := CombineHashes(Result, DepHash);
  end;
end;

function TIncrementalCache.CombineFingerprint(
  const ASourceHash, ADepsHash: TBytes): TBytes;
begin
  Result := CombineHashes(ASourceHash, ADepsHash);
end;

function TIncrementalCache.HasCache(const AUnitId: string;
  const ASourceText: string;
  const ADeps: array of string): Boolean;
var
  Path: string;
  F: file;
  ActualSize: Int64;
  Magic, Version: LongInt;
  HeaderSize, PayloadSize: LongInt;
  StoredFp, ComputedFp: TBytes;
  SourceHash, DepsHash: TBytes;
begin
  Result := False;
  if not FEnabled then Exit;

  Path := EntryPath(AUnitId);
  if not FileExists(Path) then Exit;

  SourceHash := ComputeSourceHash(ASourceText);
  DepsHash := ComputeDepsHash(ADeps);
  ComputedFp := CombineFingerprint(SourceHash, DepsHash);

  AssignFile(F, Path);
  Reset(F, 1);
  try
    ActualSize := System.FileSize(F);
    if ActualSize < NPC_HEADER_SIZE then Exit;

    BlockRead(F, Magic, 4);
    if Magic <> NPC_MAGIC then Exit;
    BlockRead(F, Version, 4);
    if Version <> NPC_VERSION then Exit;
    BlockRead(F, HeaderSize, 4);
    if HeaderSize <> NPC_HEADER_SIZE then Exit;
    BlockRead(F, PayloadSize, 4);
    if PayloadSize < 0 then Exit;
    if PayloadSize > NPC_MAX_PAYLOAD_SIZE then Exit;
    if ActualSize <> Int64(NPC_HEADER_SIZE) + Int64(PayloadSize) then Exit;

    SetLength(StoredFp, NPC_FINGERPRINT_SIZE);
    BlockRead(F, StoredFp[0], NPC_FINGERPRINT_SIZE);

    Result := (Length(StoredFp) = Length(ComputedFp)) and
              CompareMem(@StoredFp[0], @ComputedFp[0], Length(StoredFp));
  finally
    CloseFile(F);
  end;
end;

{ --- 序列化: 写入 --- }

procedure WriteSemanticModel(W: TBinaryWriter; const M: TSemanticModel);
var
  I, J, C: LongInt;
begin
  { Symbols }
  C := M.SymbolCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.SymbolAt(I) do
    begin
      W.WriteInt32(SymbolId);
      W.WriteStr(Name);
      W.WriteStr(Kind);
      W.WriteStr(OwnerUnitId);
      W.WriteInt32(ScopeId);
      W.WriteInt32(TypeId);
      W.WriteInt32(ParamCount);
      W.WriteInt32(MinParamCount);
      W.WriteStr(ParamSignature);
      W.WriteStr(Visibility);
      W.WriteInt32(ByteOffset);
      W.WriteInt32(ReturnTypeId);
    end;

  { Types }
  C := M.TypeCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.TypeAt(I) do
    begin
      W.WriteInt32(TypeId);
      W.WriteStr(Name);
      W.WriteStr(Kind);
      W.WriteStr(OwnerUnitId);
      W.WriteInt32(ParentTypeId);
      W.WriteStr(TypeParams);
      W.WriteStr(TypeConstraints);
      W.WriteInt32(InstantiatedFrom);
      W.WriteInt32(GenericParent.TemplateTypeId);
      W.WriteInt32(Length(GenericParent.ArgIndices));
      for J := 0 to High(GenericParent.ArgIndices) do
        W.WriteInt32(GenericParent.ArgIndices[J]);
    end;

  { Scopes }
  C := M.ScopeCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.ScopeAt(I) do
    begin
      W.WriteInt32(ScopeId);
      W.WriteByte(Ord(Kind));
      W.WriteStr(Name);
      W.WriteInt32(ParentScopeId);
    end;

  { Bindings }
  C := M.BindingCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.BindingAt(I) do
    begin
      W.WriteInt32(BindingId);
      W.WriteStr(Kind);
      W.WriteStr(Name);
      W.WriteStr(OwnerUnitId);
      W.WriteInt32(ByteOffset);
      W.WriteInt32(TargetSymbolId);
    end;

  { TypedHirNodes }
  C := M.TypedHirNodeCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.TypedHirNodeAt(I) do
    begin
      W.WriteInt32(HirNodeId);
      W.WriteStr(Kind);
      W.WriteStr(DisplayName);
      W.WriteInt32(SymbolId);
      W.WriteInt32(TypeId);
      W.WriteStr(Operand);
      W.WriteInt32(ExprId);
      W.WriteInt32(TargetExprId);
      W.WriteBool(IsThreadVar);
    end;

  { HirExprs }
  C := M.HirExprCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.HirExprAt(I) do
    begin
      W.WriteInt32(ExprId);
      W.WriteByte(Ord(Kind));
      W.WriteInt32(TypeId);
      W.WriteInt32(SymbolId);
      W.WriteInt32(Length(Children));
      for J := 0 to High(Children) do
        W.WriteInt32(Children[J]);
      W.WriteInt64(LiteralInt);
      W.WriteInt64(Int64(LiteralFloat));  { bitcast }
      W.WriteStr(LiteralStr);
      W.WriteStr(Op);
      W.WriteInt32(SourceOffset);
      W.WriteByte(Ord(ValueClass));
    end;

  { RuntimeContracts }
  C := M.RuntimeContractCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.RuntimeContractAt(I) do
    begin
      W.WriteInt32(ContractId);
      W.WriteStr(Name);
    end;

  { ForeignProcedureBindings }
  C := M.ForeignProcedureBindingCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.ForeignProcedureBindingAt(I) do
    begin
      W.WriteInt32(BindingId);
      W.WriteStr(PascalName);
      W.WriteStr(CallingConvention);
      W.WriteStr(LibraryId);
      W.WriteStr(ExternalSymbolName);
      W.WriteInt32(SymbolId);
    end;

  { LibraryRequests }
  C := M.LibraryRequestCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    with M.LibraryRequestAt(I) do
    begin
      W.WriteInt32(RequestId);
      W.WriteStr(LogicalId);
      W.WriteStr(LinkageKind);
      W.WriteStr(Strength);
    end;

  { RootName + Status }
  W.WriteStr(M.RootName);
  W.WriteStr(M.Status);

  { UnitInitOrder }
  C := M.UnitInitOrderCount;
  W.WriteInt32(C);
  for I := 0 to C - 1 do
    W.WriteStr(M.UnitInitOrderAt(I));
end;

{ --- 序列化: 读取 --- }

function ReadSemanticModel(R: TBinaryReader): TSemanticModel;
var
  I, J, C, CC: LongInt;
  Sym: TSemanticSymbol;
  Typ: TSemanticType;
  Scp: TSemanticScope;
  Bnd: TSemanticBinding;
  Hir: TTypedHirNode;
  Expr: TSemanticHirExpr;
  Rc: TRuntimeContract;
  Fpb: TSemanticForeignProcedureBinding;
  Lr: TSemanticLibraryRequest;
  StatusStr: string;
begin
  Result := TSemanticModel.Create;

  { Symbols }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Sym.SymbolId := R.ReadInt32;
    Sym.Name := R.ReadStr;
    Sym.Kind := R.ReadStr;
    Sym.OwnerUnitId := R.ReadStr;
    Sym.ScopeId := R.ReadInt32;
    Sym.TypeId := R.ReadInt32;
    Sym.ParamCount := R.ReadInt32;
    Sym.MinParamCount := R.ReadInt32;
    Sym.ParamSignature := R.ReadStr;
    Sym.Visibility := R.ReadStr;
    Sym.ByteOffset := R.ReadInt32;
    Sym.ReturnTypeId := R.ReadInt32;
    Result.AddSymbol(Sym.Name, Sym.Kind, Sym.OwnerUnitId, Sym.TypeId, Sym.ByteOffset);
  end;

  { Types }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Typ.TypeId := R.ReadInt32;
    Typ.Name := R.ReadStr;
    Typ.Kind := R.ReadStr;
    Typ.OwnerUnitId := R.ReadStr;
    Typ.ParentTypeId := R.ReadInt32;
    Typ.TypeParams := R.ReadStr;
    Typ.TypeConstraints := R.ReadStr;
    Typ.InstantiatedFrom := R.ReadInt32;
    Typ.GenericParent.TemplateTypeId := R.ReadInt32;
    CC := R.ReadInt32;
    SetLength(Typ.GenericParent.ArgIndices, CC);
    for J := 0 to CC - 1 do
      Typ.GenericParent.ArgIndices[J] := R.ReadInt32;
    Result.AddType(Typ.Name, Typ.Kind);
  end;

  { Scopes }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Scp.ScopeId := R.ReadInt32;
    Scp.Kind := TScopeKind(R.ReadByte);
    Scp.Name := R.ReadStr;
    Scp.ParentScopeId := R.ReadInt32;
    Result.AddScope(Scp.Kind, Scp.Name, Scp.ParentScopeId);
  end;

  { Bindings }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Bnd.BindingId := R.ReadInt32;
    Bnd.Kind := R.ReadStr;
    Bnd.Name := R.ReadStr;
    Bnd.OwnerUnitId := R.ReadStr;
    Bnd.ByteOffset := R.ReadInt32;
    Bnd.TargetSymbolId := R.ReadInt32;
    Result.AddBinding(Bnd.Kind, Bnd.Name, Bnd.OwnerUnitId, Bnd.ByteOffset, Bnd.TargetSymbolId);
  end;

  { TypedHirNodes }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Hir.HirNodeId := R.ReadInt32;
    Hir.Kind := R.ReadStr;
    Hir.DisplayName := R.ReadStr;
    Hir.SymbolId := R.ReadInt32;
    Hir.TypeId := R.ReadInt32;
    Hir.Operand := R.ReadStr;
    Hir.ExprId := R.ReadInt32;
    Hir.TargetExprId := R.ReadInt32;
    Hir.IsThreadVar := R.ReadBool;
    Result.AddTypedHirNode(Hir.Kind, Hir.DisplayName, Hir.SymbolId, Hir.TypeId, Hir.Operand);
  end;

  { HirExprs }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Expr.ExprId := R.ReadInt32;
    Expr.Kind := TSemanticHirExprKind(R.ReadByte);
    Expr.TypeId := R.ReadInt32;
    Expr.SymbolId := R.ReadInt32;
    CC := R.ReadInt32;
    SetLength(Expr.Children, CC);
    for J := 0 to CC - 1 do
      Expr.Children[J] := R.ReadInt32;
    Expr.LiteralInt := R.ReadInt64;
    Expr.LiteralFloat := Double(R.ReadInt64);
    Expr.LiteralStr := R.ReadStr;
    Expr.Op := R.ReadStr;
    Expr.SourceOffset := R.ReadInt32;
    Expr.ValueClass := TSemanticHirValueClass(R.ReadByte);
    Result.AddHirExpr(Expr.Kind, Expr.TypeId, Expr.SymbolId,
      Expr.Children, Expr.LiteralInt, Expr.LiteralFloat,
      Expr.LiteralStr, Expr.Op, Expr.SourceOffset, Expr.ValueClass);
  end;

  { RuntimeContracts }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Rc.ContractId := R.ReadInt32;
    Rc.Name := R.ReadStr;
    Result.AddRuntimeContract(Rc.Name);
  end;

  { ForeignProcedureBindings }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Fpb.BindingId := R.ReadInt32;
    Fpb.PascalName := R.ReadStr;
    Fpb.CallingConvention := R.ReadStr;
    Fpb.LibraryId := R.ReadStr;
    Fpb.ExternalSymbolName := R.ReadStr;
    Fpb.SymbolId := R.ReadInt32;
    Result.AddForeignProcedureBinding(Fpb.PascalName, Fpb.CallingConvention,
      Fpb.LibraryId, Fpb.ExternalSymbolName, Fpb.SymbolId);
  end;

  { LibraryRequests }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
  begin
    Lr.RequestId := R.ReadInt32;
    Lr.LogicalId := R.ReadStr;
    Lr.LinkageKind := R.ReadStr;
    Lr.Strength := R.ReadStr;
    Result.AddLibraryRequest(Lr.LogicalId, Lr.LinkageKind, Lr.Strength);
  end;

  { RootName + Status }
  Result.SetRootName(R.ReadStr);
  StatusStr := R.ReadStr;
  if StatusStr = 'ready' then
    Result.MarkReady
  else if StatusStr = 'failure' then
    Result.MarkFailure;

  { UnitInitOrder }
  C := R.ReadInt32;
  for I := 0 to C - 1 do
    { SetUnitInitOrder expects array — just read and skip for now };
end;

{ --- TIncrementalCache 公共方法 --- }

function TIncrementalCache.Load(const AUnitId: string;
  const ASourceText: string;
  const ADeps: array of string;
  out AModel: TSemanticModel): Boolean;
var
  Path: string;
  Data, PayloadData, StoredDigest, ComputedDigest: TBytes;
  F: file;
  ActualSize: Int64;
  Magic, Version: LongInt;
  HeaderSize, PayloadSize: LongInt;
  StoredFp, ComputedFp: TBytes;
  SourceHash, DepsHash: TBytes;
  R: TBinaryReader;
begin
  Result := False;
  AModel := nil;
  if not FEnabled then Exit;

  Path := EntryPath(AUnitId);
  if not FileExists(Path) then Exit;

  SourceHash := ComputeSourceHash(ASourceText);
  DepsHash := ComputeDepsHash(ADeps);
  ComputedFp := CombineFingerprint(SourceHash, DepsHash);

  AssignFile(F, Path);
  Reset(F, 1);
  try
    ActualSize := System.FileSize(F);
    if ActualSize < NPC_HEADER_SIZE then Exit;

    SetLength(Data, ActualSize);
    BlockRead(F, Data[0], ActualSize);
  finally
    CloseFile(F);
  end;

  { Fail closed on any framing error — no exception escapes }
  try
    R := TBinaryReader.Create(Data);
    try
      Magic := R.ReadInt32;
      if Magic <> NPC_MAGIC then Exit;
      Version := R.ReadInt32;
      if Version <> NPC_VERSION then Exit;
      HeaderSize := R.ReadInt32;
      if HeaderSize <> NPC_HEADER_SIZE then Exit;
      PayloadSize := R.ReadInt32;
      if PayloadSize < 0 then Exit;
      if PayloadSize > NPC_MAX_PAYLOAD_SIZE then Exit;
      if ActualSize <> Int64(NPC_HEADER_SIZE) + Int64(PayloadSize) then Exit;

      { Fingerprint at offset 16 }
      SetLength(StoredFp, NPC_FINGERPRINT_SIZE);
      Move(Data[16], StoredFp[0], NPC_FINGERPRINT_SIZE);
      R.FPos := NPC_HEADER_SIZE;  { skip past digest }

      if not ((Length(StoredFp) = Length(ComputedFp)) and
              CompareMem(@StoredFp[0], @ComputedFp[0], Length(StoredFp))) then
        Exit;

      { Verify payload SHA-256 }
      SetLength(PayloadData, PayloadSize);
      if PayloadSize > 0 then
        Move(Data[NPC_HEADER_SIZE], PayloadData[0], PayloadSize);
      ComputedDigest := HashBytes(PayloadData);

      SetLength(StoredDigest, NPC_DIGEST_SIZE);
      Move(Data[48], StoredDigest[0], NPC_DIGEST_SIZE);

      if not CompareMem(@StoredDigest[0], @ComputedDigest[0], NPC_DIGEST_SIZE) then
        Exit;

      AModel := ReadSemanticModel(R);
      if AModel = nil then Exit;
      Result := True;
    finally
      R.Free;
    end;
  except
    on Exception do
    begin
      Result := False;
      if AModel <> nil then
      begin
        AModel.Free;
        AModel := nil;
      end;
    end;
  end;
end;

procedure TIncrementalCache.Save(const AUnitId: string;
  const ASourceText: string;
  const ADeps: array of string;
  const AModel: TSemanticModel);
var
  Path: string;
  W, PayloadW: TBinaryWriter;
  Fp, Payload, PayloadDigest: TBytes;
  Data: TBytes;
  F: file;
  PayloadSize: LongInt;
begin
  if not FEnabled then Exit;

  { Ensure cache directory exists }
  if not DirectoryExists(FCacheDir) then
    ForceDirectories(FCacheDir);

  { Serialize payload first to compute size and digest }
  PayloadW := TBinaryWriter.Create;
  try
    WriteSemanticModel(PayloadW, AModel);
    Payload := PayloadW.Data;
  finally
    PayloadW.Free;
  end;

  PayloadSize := Length(Payload);

  { Fingerprint: source + deps }
  Fp := CombineFingerprint(
    ComputeSourceHash(ASourceText),
    ComputeDepsHash(ADeps));

  { SHA-256 of payload }
  PayloadDigest := HashBytes(Payload);

  { Build V2 envelope }
  W := TBinaryWriter.Create;
  try
    W.WriteInt32(NPC_MAGIC);
    W.WriteInt32(NPC_VERSION);
    W.WriteInt32(NPC_HEADER_SIZE);
    W.WriteInt32(PayloadSize);
    W.WriteRaw(Fp[0], NPC_FINGERPRINT_SIZE);       { offset 16, raw 32 bytes }
    W.WriteRaw(PayloadDigest[0], NPC_DIGEST_SIZE);  { offset 48, raw 32 bytes }
    if PayloadSize > 0 then
      W.WriteRaw(Payload[0], PayloadSize);
    Data := W.Data;
  finally
    W.Free;
  end;

  Path := EntryPath(AUnitId);
  AssignFile(F, Path);
  Rewrite(F, 1);
  try
    BlockWrite(F, Data[0], Length(Data));
  finally
    CloseFile(F);
  end;
end;

procedure TIncrementalCache.Invalidate(const AUnitId: string);
var
  Path: string;
begin
  Path := EntryPath(AUnitId);
  if FileExists(Path) then
    DeleteFile(Path);
end;

procedure TIncrementalCache.Clear;
var
  SR: TSearchRec;
begin
  if FindFirst(FCacheDir + '/*.npc', faAnyFile, SR) = 0 then
  begin
    repeat
      DeleteFile(FCacheDir + '/' + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

end.
