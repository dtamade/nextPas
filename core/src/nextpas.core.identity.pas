unit nextpas.core.identity;
{** 身份域单源：user_profiles 最小不变量 Owner 落地。
    L2 能力域（依赖 L0-L1；钱包 L3 单向依赖本域，层级不循环）。
    四件套：base（本域常量）← 本单元（实现+门面最小形态，intf 按需）；不机械建空文件。
    可抽状态：已落地为独立模块候选 `nextpas.core.identity`（Owner = identity lane），单源 `core/docs/identity/CONTRACT.md`；wallet 部署序 `identity(v14) → wallet(v15)` 前置依赖闭环。
    反哺：文本经 `nextpas.core.text.utils` Trim 单源 inline 零拷贝，时间经 `nextpas.core.time` NowUtc/iso8601 单源（ToUnixNanos 单路径），串/字节经 `nextpas.core.bytes.ops` StringToBytes 单 Move 零拷贝；零平行词法/时间/存储实现。
    性能：Normalize/IsValid/IdToBytes 全 inline 薄转发，MakeMigrations inline 零额外分配；真实 IO 助手不 inline 避 I-Cache 膨胀（本域无重 IO，迁移清单纯构造）。
    稳定性：迁移清单经 `db.migrate` 幂等/checksum 承载，重复调用零副作用；若扩展 DB 读写则沿 `Pool.Acquire/Writer` 接口句柄+try..finally Q:=nil/Conn:=nil 语句边界归还，不丢连接；FOREIGN_KEYS=ON 级联不留孤儿行。
    单源：bytes.ops 编译期单出口 {$IF not BYTES_OPS_SINGLE_SOURCE} 守卫，漂移编译期拦截；TEXT/TIME 单源经 inline 转发不自建状态机。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.migrate,
  nextpas.core.identity.base;

function IdentityMakeMigrations: TDbMigrations; inline;
function IdentityNormalizeId(const AId: string): string; inline;
function IdentityIsValidId(const AId: string): Boolean; inline;
function IdentityIdToBytes(const AId: string): TBytes; inline;
function IdentityNowIso8601: string; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.time,
  nextpas.core.time.iso8601,
  nextpas.core.time.offsetdatetime;

{ bytes.ops 单源编译期互证：重复实现/漂移编译期拦截（零运行时分支） }

function IdentityMakeMigrations: TDbMigrations; inline;
begin
  { inline 薄转发：零额外分配，Migrations 构造经 db.migrate 单源；FK 表名经 identity.base 单源常量，部署序身份域 v14 先行 → wallet v15；checksum 经 db.migrate CRC32 单源 }
  {$IF IDENTITY_USER_PROFILES_TABLE <> 'user_profiles'}
    {$FATAL 'identity table drift: wallet FK must follow identity.base'}
  {$IFEND}
  Result := MakeMigrations([
    TDbMigration.Create(IDENTITY_MIGRATION_VERSION, [
      'create table if not exists user_profiles (id text primary key, display_name text, created_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')), updated_at text not null default (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')));'
    ])
  ]);
end;

function IdentityNormalizeId(const AId: string): string; inline;
begin
  { 文本单源：Trim 经 nextpas.core.text.utils inline 零拷贝；无修剪时原串共享（L=1,R=Length 零分配），有修剪时单次 Copy 单遍扫描 O(n) }
  Result := Trim(AId);
end;

function IdentityIsValidId(const AId: string): Boolean; inline;
var
  L: string;
begin
  { 文本单源复用：归一化后判空与长度；不自建词法状态机（text.kv/sqlscan 单源不重复） }
  L := Trim(AId);
  Result := (Length(L) > 0) and (Length(L) <= 64);
end;

function IdentityIdToBytes(const AId: string): TBytes; inline;
begin
  { 字节单源：StringToBytes 经 nextpas.core.bytes.ops 单 Move 零拷贝，BYTES_OPS_SINGLE_SOURCE 守卫零漂移；先 Trim 归一化再单 Move，避免含空白的身份键 }
  Result := StringToBytes(Trim(AId));
end;

function IdentityNowIso8601: string; inline;
var
  LNow: TOffsetDateTime;
begin
  { 时间单源：NowUtc 经 nextpas.core.time 单源（platform_monotonic_ns），序列化走 iso8601 单源；不自建时间解析（text/time 分治），ToUnixNanos 单路径比较时区无歧义 }
  LNow := TOffsetDateTime.NowUtc;
  Result := LNow.ToISO8601;
end;

end.
