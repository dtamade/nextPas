unit nextpas.core.crypto.errors;

{$mode objfpc}{$H+}

{ nextpas.core.crypto.errors — typed crypto failures

  Owner of ECryptoError. Prefer Try* APIs at public boundaries;
  use RaiseCryptoError only for hard programming/contract violations.
}

interface

uses
  nextpas.core.exception;

type
  TCryptoErrorCode = (
    cecInvalidArgument,
    cecKeyDerivation,
    cecCipher,
    cecInternal
  );

  ECryptoError = class(Exception)
  private
    FCode: TCryptoErrorCode;
  public
    constructor Create(ACode: TCryptoErrorCode; const AMsg: string);
    constructor CreateFmt(ACode: TCryptoErrorCode; const AMsg: string;
      const AArgs: array of const);
    property Code: TCryptoErrorCode read FCode;
  end;

procedure RaiseCryptoError(ACode: TCryptoErrorCode; const AMsg: string);
procedure RaiseCryptoErrorFmt(ACode: TCryptoErrorCode; const AMsg: string;
  const AArgs: array of const);

implementation

constructor ECryptoError.Create(ACode: TCryptoErrorCode; const AMsg: string);
begin
  inherited Create(AMsg);
  FCode := ACode;
end;

constructor ECryptoError.CreateFmt(ACode: TCryptoErrorCode; const AMsg: string;
  const AArgs: array of const);
begin
  inherited CreateFmt(AMsg, AArgs);
  FCode := ACode;
end;

procedure RaiseCryptoError(ACode: TCryptoErrorCode; const AMsg: string);
begin
  raise ECryptoError.Create(ACode, AMsg);
end;

procedure RaiseCryptoErrorFmt(ACode: TCryptoErrorCode; const AMsg: string;
  const AArgs: array of const);
begin
  raise ECryptoError.CreateFmt(ACode, AMsg, AArgs);
end;

end.
