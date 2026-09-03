unit nextpas.core.db.redis.addr;

{** @desc Redis 地址解析单源（V3-A5 抽离）。
       由 redis.adapter 抽离以满足 800 行软阈值（CONTRACT 体积债务收口）：
       复用 bytes.ops.StringToBytes（BytesFromText 单源 inline 零拷贝单 Move）、
       text.kv ScanKV（host/port/db 键）、text.conv（SameText/Trim/IntToStr——
       FormatRedisAddr 单源 inline 单分配）与 db.base 常量 DB_REDIS_DEFAULT_PORT；
       零 SysUtils/BaseUnix/Windows。
       薄 helper：BytesFromText / RedisCategory / ParseRedisAddr / FormatRedisAddr /
       RedisDsnOf 均单源于此（RedisDsnOf 单次容量预估+单分配零拷贝经
       text.builder.TBufStringBuilder 单 Move 直写尾缓冲，bytes.ops 单源）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base;

function BytesFromText(const AStr: string): TBytes; inline;
function RedisCategory(const AErrType: string): TDbErrorCategory; inline;
procedure ParseRedisAddr(const AAddr: string;
  const AOptions: TDbConnectOptions; out AOpts: TDbRedisConnectOptions);
function FormatRedisAddr(const AHost: string; const APort: Word): string; inline;
function FormatRedisAddrFromOptions(const AOptions: TDbRedisConnectOptions): string; inline;
function RedisDsnOf(const AOpts: TDbRedisConnectOptions): string; inline;
function BuildRedisDsnWithAuth(const AAddr, APassword: string; const ADbIndex: Integer): string; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.db.err,
  nextpas.core.text.kv,
  nextpas.core.text.conv,
  nextpas.core.text.builder;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: redis.addr must reuse bytes.ops'}
{$IFEND}

function BytesFromText(const AStr: string): TBytes; inline;
begin
  { perf: single-source via bytes.ops.StringToBytes — inline single Move, zero-copy evidence: bytes.ops impl is single Move(PAnsiChar(AText)^, Result[0], Length(AText)) with nil early-exit, no extra alloc }
  Result := StringToBytes(AStr);
end;

function RedisCategory(const AErrType: string): TDbErrorCategory; inline;
var
  LCon: TDbConstraintKind;
begin
  ClassifyRedis(AErrType, Result, LCon);
end;

function FormatRedisAddr(const AHost: string; const APort: Word): string; inline;
begin
  { perf: single-source address formatting — inline, single allocation; port via
    text.conv.IntToStr (System.Str single source, inline) + single string concat
    (bytes.ops StringToBytes/BytesToString uses single Move zero-copy; text.conv
    owns string↔bytes bridge); owner = redis.addr,门面零重复, zero extra alloc
    beyond Result. Reuse bytes.ops invariant: BYTES_OPS_SINGLE_SOURCE }
  Result := AHost + ':' + IntToStr(Int64(APort));
end;

function FormatRedisAddrFromOptions(const AOptions: TDbRedisConnectOptions): string; inline;
begin
  Result := FormatRedisAddr(AOptions.Host, AOptions.Port);
end;

function RedisDsnOf(const AOpts: TDbRedisConnectOptions): string; inline;
var
  LBuilder: TBufStringBuilder;
  LCap: SizeUInt;
begin
  { perf: owner 单源——单次容量预估+单分配零拷贝：常量段+动态字段+数字位宽上界经统一辅助 TBufEstimateForTwo/BuilderCapAdd 单源（bytes.ops BuilderCap* 单源 inline 零拷贝，消除分散 Length+N 手写），避免 Grow 重分配；AppendStr/AppendInt 单 Move 直写尾缓冲；bytes.ops 单源（BYTES_OPS_SINGLE_SOURCE），与门面同资源语义 finally Done 归还 }
  LCap := TBufEstimateForTwo(5, SizeUInt(Length(AOpts.Host)));
  LCap := BuilderCapAdd(LCap, 12);
  if AOpts.DbIndex <> 0 then LCap := BuilderCapAdd(LCap, 9);
  if AOpts.Password <> '' then LCap := BuilderCapAdd(LCap, BuilderCapForTwo(10, SizeUInt(Length(AOpts.Password))));
  if AOpts.UseTls then LCap := BuilderCapAdd(LCap, 6);
  if AOpts.TlsServerName <> '' then LCap := BuilderCapAdd(LCap, BuilderCapForTwo(15, SizeUInt(Length(AOpts.TlsServerName))));
  LBuilder.Init(LCap);
  try
    LBuilder.AppendStr('host=');
    LBuilder.AppendStr(AOpts.Host);
    LBuilder.AppendStr(' port=');
    LBuilder.AppendInt(AOpts.Port);
    if AOpts.DbIndex <> 0 then
    begin
      LBuilder.AppendStr(' db=');
      LBuilder.AppendInt(AOpts.DbIndex);
    end;
    if AOpts.Password <> '' then
    begin
      LBuilder.AppendStr(' password=');
      LBuilder.AppendStr(AOpts.Password);
    end;
    if AOpts.UseTls then
      LBuilder.AppendStr(' tls=1');
    if AOpts.TlsServerName <> '' then
    begin
      LBuilder.AppendStr(' tlsservername=');
      LBuilder.AppendStr(AOpts.TlsServerName);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure ParseRedisAddr(const AAddr: string;
  const AOptions: TDbConnectOptions; out AOpts: TDbRedisConnectOptions);
var
  LHostPart, LTail: string;
  LSlash, LColon: Integer;
  LCode: Integer;
  LIsKv: Boolean;
  LKvHost: string;
  LKvPort: string;
  LKvDb: string;
  LHasKvKey: Boolean;
begin
  AOpts := TDbRedisConnectOptions.Default;
  AOpts.Host := '';
  AOpts.Port := DB_REDIS_DEFAULT_PORT;
  LIsKv := Pos('=', AAddr) > 0;
  if LIsKv then
  begin
    LKvHost := '';
    LKvPort := '';
    LKvDb := '';
    LHasKvKey := False;
    try
      ScanKV(AAddr,
        procedure(const AKey, AValue: string)
        begin
          if SameText(AKey, 'host') or SameText(AKey, 'addr') then
          begin
            LKvHost := AValue;
            LHasKvKey := True;
          end
          else if SameText(AKey, 'port') then
          begin
            LKvPort := AValue;
            LHasKvKey := True;
          end
          else if SameText(AKey, 'db') or SameText(AKey, 'database') or
                  SameText(AKey, 'dbindex') then
          begin
            LKvDb := AValue;
            LHasKvKey := True;
          end
          else if SameText(AKey, 'password') or SameText(AKey, 'pass') then
          begin
            AOpts.Password := AValue;
            LHasKvKey := True;
          end
          else if SameText(AKey, 'tls') or SameText(AKey, 'usetls') then
          begin
            AOpts.UseTls := SameText(Trim(AValue), '1') or SameText(Trim(AValue), 'true') or SameText(Trim(AValue), 'yes');
            LHasKvKey := True;
          end
          else if SameText(AKey, 'tlsservername') or SameText(AKey, 'servername') then
          begin
            AOpts.TlsServerName := AValue;
            LHasKvKey := True;
          end;
        end);
    except
      on E: Exception do
        raise EDbError.CreateSimple(dbkRedis, E.Message);
    end;
    if LHasKvKey then
    begin
      if LKvHost <> '' then
        AOpts.Host := Trim(LKvHost);
      if LKvPort <> '' then
      begin
        Val(LKvPort, AOpts.Port, LCode);
        if (LCode <> 0) or (AOpts.Port = 0) then
          raise EDbError.CreateSimple(dbkRedis,
            'invalid port "' + LKvPort + '"');
      end;
      if LKvDb <> '' then
      begin
        Val(LKvDb, AOpts.DbIndex, LCode);
        if (LCode <> 0) or (AOpts.DbIndex < 0) then
          raise EDbError.CreateSimple(dbkRedis,
            'invalid db index "' + LKvDb + '"');
        if AOpts.DbIndex > 16383 then
          raise EDbError.CreateSimple(dbkRedis,
            'db index out of range (0..16383)');
      end;
      if AOpts.Host = '' then
        raise EDbError.CreateSimple(dbkRedis, 'empty host');
      if AOptions.StatementTimeoutMs > 0 then
        AOpts.IoTimeoutMs := AOptions.StatementTimeoutMs;
      Exit;
    end;
    raise EDbError.CreateSimple(dbkRedis,
      'invalid redis address kv "' + AAddr + '"');
  end;
  LHostPart := AAddr;
  LSlash := Pos('/', LHostPart);
  if LSlash > 0 then
  begin
    LTail := Copy(LHostPart, LSlash + 1, MaxInt);
    LHostPart := Copy(LHostPart, 1, LSlash - 1);
    Val(LTail, AOpts.DbIndex, LCode);
    if (LCode <> 0) or (AOpts.DbIndex < 0) then
      raise EDbError.CreateSimple(dbkRedis,
        'invalid db index "/' + LTail + '"');
  end;
  if AOpts.DbIndex > 16383 then
    raise EDbError.CreateSimple(dbkRedis,
      'db index out of range (0..16383)');
  LColon := Pos(':', LHostPart);
  if LColon > 0 then
  begin
    LTail := Copy(LHostPart, LColon + 1, MaxInt);
    LHostPart := Copy(LHostPart, 1, LColon - 1);
    Val(LTail, AOpts.Port, LCode);
    if (LCode <> 0) or (AOpts.Port = 0) then
      raise EDbError.CreateSimple(dbkRedis,
        'invalid port ":' + LTail + '"');
  end;
  begin
    LHostPart := Trim(LHostPart);
    AOpts.Host := LHostPart;
  end;
  if AOpts.Host = '' then
    raise EDbError.CreateSimple(dbkRedis, 'empty host');
  if AOptions.StatementTimeoutMs > 0 then
    AOpts.IoTimeoutMs := AOptions.StatementTimeoutMs;
end;

function BuildRedisDsnWithAuth(const AAddr, APassword: string; const ADbIndex: Integer): string; inline;
var
  LOpts: TDbRedisConnectOptions;
begin
  { perf: owner 单源 — ParseRedisAddr text.kv 单遍 O(n) + RedisDsnOf TBufStringBuilder 单次容量预估单分配单 Move 零拷贝直写尾缓冲；inline 薄转发；bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE；stability: Builder try..finally Done 归还不丢 }
  ParseRedisAddr(AAddr, TDbConnectOptions.Default, LOpts);
  if APassword <> '' then
    LOpts.Password := APassword;
  if ADbIndex <> 0 then
    LOpts.DbIndex := ADbIndex;
  Result := RedisDsnOf(LOpts);
end;

end.
