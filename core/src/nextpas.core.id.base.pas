unit nextpas.core.id.base;

{$I nextpas.core.settings.inc}

interface

type
  TUuidString = string;
  TUlidString = string;
  TNanoIdString = string;

const
  UUID_LENGTH = 36;
  ULID_LENGTH = 26;
  NANOID_DEFAULT_LENGTH = 21;
  NANOID_DEFAULT_ALPHABET = '_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

implementation

end.
