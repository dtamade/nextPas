unit nextpas.core.db.redis.addr;

{** @desc Redis 地址解析单源（V3-A5 抽离）。
       由 redis.adapter 抽离以满足 800 行软阈值（CONTRACT 体积债务收口）：
       复用 text.kv ScanKV（host/port/db 键）、text.conv（SameText/Trim）
       与 db.base 常量 DB_REDIS_DEFAULT_PORT；零 SysUtils/BaseUnix/Windows。
       薄 helper：BytesFromText / RedisCategory / ParseRedisAddr 均单源于此。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base;

function BytesFromText(const AStr: string): TBytes;
function RedisCategory(const AErrType: string): TDbErrorCategory;
procedure ParseRedisAddr(const AAddr: string;
  const AOptions: TDbConnectOptions; out AOpts: TDbRedisConnectOptions);

implementation

uses
  nextpas.core.exception,
  nextpas.core.db.err,
  nextpas.core.text.kv,
  nextpas.core.text.conv;

function BytesFromText(const AStr: string): TBytes;
begin
  if Length(AStr) = 0 then
    Exit(nil);
  SetLength(Result, Length(AStr));
  Move(AStr[1], Result[0], Length(AStr));
end;

function RedisCategory(const AErrType: string): TDbErrorCategory;
var
  LCon: TDbConstraintKind;
begin
  ClassifyRedis(AErrType, Result, LCon);
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

end.
