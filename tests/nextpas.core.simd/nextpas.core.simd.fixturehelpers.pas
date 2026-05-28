unit nextpas.core.simd.fixturehelpers;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base;

type
  TSimdSavedBackendState = record
    Backend: TSimdBackend;
  end;

  TSimdBackendReader = function: TSimdBackend;

procedure SaveActiveBackendState(out aState: TSimdSavedBackendState);
function RestoreSavedBackendState(aOriginalBackend: TSimdBackend): Boolean;
function RestoreSavedBackendStateAndVerify(aOriginalBackend: TSimdBackend;
  aReadBackend: TSimdBackendReader): Boolean;
function RestoreSavedBackendAndVectorAsmState(aOriginalVectorAsm: Boolean;
  aOriginalBackend: TSimdBackend): Boolean;
function RestoreSavedBackendAndVectorAsmStateAndVerify(aOriginalVectorAsm: Boolean;
  aOriginalBackend: TSimdBackend; aReadBackend: TSimdBackendReader): Boolean;

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.dispatch;

procedure SaveActiveBackendState(out aState: TSimdSavedBackendState);
begin
  GetDispatchTable;
  aState.Backend := GetActiveBackend;
end;

function RestoreSavedBackendState(aOriginalBackend: TSimdBackend): Boolean;
begin
  ResetToAutomaticBackend;
  if GetCurrentBackend = aOriginalBackend then
    Exit(True);

  Result := TrySetActiveBackend(aOriginalBackend);
end;

function RestoreSavedBackendStateAndVerify(aOriginalBackend: TSimdBackend;
  aReadBackend: TSimdBackendReader): Boolean;
var
  LObservedBackend: TSimdBackend;
begin
  Result := RestoreSavedBackendState(aOriginalBackend);
  if not Result then
    Exit(False);
  if not Assigned(aReadBackend) then
    Exit(False);

  LObservedBackend := aReadBackend();
  Result := LObservedBackend = aOriginalBackend;
end;

function RestoreSavedBackendAndVectorAsmState(aOriginalVectorAsm: Boolean;
  aOriginalBackend: TSimdBackend): Boolean;
begin
  SetVectorAsmEnabled(aOriginalVectorAsm);
  Result := RestoreSavedBackendState(aOriginalBackend);
end;

function RestoreSavedBackendAndVectorAsmStateAndVerify(aOriginalVectorAsm: Boolean;
  aOriginalBackend: TSimdBackend; aReadBackend: TSimdBackendReader): Boolean;
var
  LObservedBackend: TSimdBackend;
begin
  Result := RestoreSavedBackendAndVectorAsmState(aOriginalVectorAsm,
    aOriginalBackend);
  if not Result then
    Exit(False);
  if not Assigned(aReadBackend) then
    Exit(False);

  LObservedBackend := aReadBackend();
  Result := LObservedBackend = aOriginalBackend;
end;

end.
