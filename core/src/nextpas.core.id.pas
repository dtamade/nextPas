unit nextpas.core.id;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base,
  nextpas.core.id.uuid,
  nextpas.core.id.ulid,
  nextpas.core.id.nanoid;

type
  TUuidString = nextpas.core.id.base.TUuidString;
  TUlidString = nextpas.core.id.base.TUlidString;
  TNanoIdString = nextpas.core.id.base.TNanoIdString;

const
  UUID_LENGTH = nextpas.core.id.base.UUID_LENGTH;
  ULID_LENGTH = nextpas.core.id.base.ULID_LENGTH;
  NANOID_DEFAULT_LENGTH = nextpas.core.id.base.NANOID_DEFAULT_LENGTH;
  NANOID_DEFAULT_ALPHABET = nextpas.core.id.base.NANOID_DEFAULT_ALPHABET;

function UuidV4: TUuidString; inline;
function Ulid: TUlidString; inline;
function UlidFromTimestamp(const ATimestampMs: UInt64): TUlidString; inline;
function NanoId: TNanoIdString; inline;
function NanoIdCustom(const AAlphabet: string; const ASize: Integer): TNanoIdString; inline;

implementation

function UuidV4: TUuidString;
begin
  Result := nextpas.core.id.uuid.UuidV4;
end;

function Ulid: TUlidString;
begin
  Result := nextpas.core.id.ulid.Ulid;
end;

function UlidFromTimestamp(const ATimestampMs: UInt64): TUlidString;
begin
  Result := nextpas.core.id.ulid.UlidFromTimestamp(ATimestampMs);
end;

function NanoId: TNanoIdString;
begin
  Result := nextpas.core.id.nanoid.NanoId;
end;

function NanoIdCustom(const AAlphabet: string; const ASize: Integer): TNanoIdString;
begin
  Result := nextpas.core.id.nanoid.NanoIdCustom(AAlphabet, ASize);
end;

end.
