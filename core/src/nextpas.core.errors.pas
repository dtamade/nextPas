unit nextpas.core.errors;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base;

type
  { ENextPasError - framework root exception }
  ENextPasError = class(Exception);

  { EArgumentError - invalid argument passed to a function }
  EArgumentError = class(ENextPasError);

  { ENullReferenceError - nil dereference }
  ENullReferenceError = class(ENextPasError);

  { EInvalidOperationError - operation not valid for current state }
  EInvalidOperationError = class(ENextPasError);

  { ENotImplementedError - feature not yet implemented }
  ENotImplementedError = class(ENextPasError);

  { ENotSupportedError - operation not supported }
  ENotSupportedError = class(ENextPasError);

  { ETimeoutError - operation timed out }
  ETimeoutError = class(ENextPasError);

  { EIOError - I/O operation failed }
  EIOError = class(ENextPasError);

  { EOutOfMemoryError - memory allocation failed }
  EOutOfMemoryError = class(ENextPasError);

  { EIndexOutOfRangeError - index out of bounds }
  EIndexOutOfRangeError = class(ENextPasError);

implementation

end.
