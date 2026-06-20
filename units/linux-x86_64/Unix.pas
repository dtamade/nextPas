unit Unix;

{$mode objfpc}{$H+}

interface

uses BaseUnix, ctypes;

function fpSelect(nfds: cint; readfds, writefds, exceptfds: Pointer; timeout: Pointer): cint;
function fpPipe(var pipefd: array of cint): cint;

implementation

function fpSelect(nfds: cint; readfds, writefds, exceptfds: Pointer; timeout: Pointer): cint;
begin Result := -1; end;

function fpPipe(var pipefd: array of cint): cint;
begin Result := -1; end;

end.
