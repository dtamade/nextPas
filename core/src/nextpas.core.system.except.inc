{**
 * @desc Exception classes for the nextPas system kernel.
 *
 * Defines Exception, EAbort, EConvertError, etc.
 * Depends on base.inc, str.inc, cls.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

type
  { Exception base class }
  ExceptClass = class of Exception;
  Exception = class(TObject)
  private
    FMessage: AnsiString;
    FHelpContext: LongInt;
  public
    constructor Create(const Msg: AnsiString);
    constructor CreateFmt(const Msg: AnsiString; const Args: array of const);
    constructor CreateRes(ResStringRec: PResStringRec);
    constructor CreateResFmt(ResStringRec: PResStringRec; const Args: array of const);
    constructor CreateHelp(const Msg: AnsiString; AHelpContext: LongInt);
    constructor CreateFmtHelp(const Msg: AnsiString; const Args: array of const; AHelpContext: LongInt);
    constructor CreateResHelp(ResStringRec: PResStringRec; AHelpContext: LongInt);
    constructor CreateResFmtHelp(ResStringRec: PResStringRec; const Args: array of const; AHelpContext: LongInt);
    property Message: AnsiString read FMessage write FMessage;
    property HelpContext: LongInt read FHelpContext write FHelpContext;
  end;

  { Common exception classes }
  EAbort = class(Exception);
  EConvertError = class(Exception);
  EAssertionFailed = class(Exception);
  EExternal = class(Exception)
  public
    ExceptionRecord: PExceptionRecord;
  end;
  EExternalException = class(EExternal);
  EIntError = class(EExternal);
  EDivByZero = class(EIntError);
  ERangeError = class(EIntError);
  EIntOverflow = class(EIntError);
  EMathError = class(EExternal);
  EInvalidOp = class(EMathError);
  EZeroDivide = class(EMathError);
  EOverflow = class(EMathError);
  EUnderflow = class(EMathError);
  EInvalidPointer = class(EExternal);
  EInvalidCast = class(Exception);
  EAccessViolation = class(EExternal);
  EBusError = class(EExternal);
  EPrivilege = class(EExternal);
  EStackOverflow = class(EExternal);
  EControlC = class(EExternal);
  EVariantError = class(Exception);
  EPropReadOnly = class(Exception);
  EPropWriteOnly = class(Exception);
  EIntfCastError = class(Exception);
  EInvalidContainer = class(Exception);
  EInvalidInsert = class(Exception);
  EPackageError = class(Exception);
  ECFError = class(Exception);

  { ResStringRec type }
  PResStringRec = ^TResStringRec;
  TResStringRec = record
    Identifier: PAnsiString;
  end;

  { Exception record type }
  PExceptionRecord = ^TExceptionRecord;
  TExceptionRecord = record
    ExceptionCode: LongWord;
    ExceptionFlags: LongWord;
    ExceptionRecord: PExceptionRecord;
    ExceptionAddress: Pointer;
    NumberParameters: LongWord;
    ExceptionInformation: array[0..14] of SizeUInt;
  end;

implementation

{ Exception implementation }

constructor Exception.Create(const Msg: AnsiString);
begin
  FMessage := Msg;
end;

constructor Exception.CreateFmt(const Msg: AnsiString; const Args: array of const);
begin
  FMessage := Format(Msg, Args);
end;

constructor Exception.CreateRes(ResStringRec: PResStringRec);
begin
  if ResStringRec <> nil then
    FMessage := ResStringRec^.Identifier^
  else
    FMessage := '';
end;

constructor Exception.CreateResFmt(ResStringRec: PResStringRec; const Args: array of const);
begin
  if ResStringRec <> nil then
    FMessage := Format(ResStringRec^.Identifier^, Args)
  else
    FMessage := '';
end;

constructor Exception.CreateHelp(const Msg: AnsiString; AHelpContext: LongInt);
begin
  FMessage := Msg;
  FHelpContext := AHelpContext;
end;

constructor Exception.CreateFmtHelp(const Msg: AnsiString; const Args: array of const; AHelpContext: LongInt);
begin
  FMessage := Format(Msg, Args);
  FHelpContext := AHelpContext;
end;

constructor Exception.CreateResHelp(ResStringRec: PResStringRec; AHelpContext: LongInt);
begin
  if ResStringRec <> nil then
    FMessage := ResStringRec^.Identifier^
  else
    FMessage := '';
  FHelpContext := AHelpContext;
end;

constructor Exception.CreateResFmtHelp(ResStringRec: PResStringRec; const Args: array of const; AHelpContext: LongInt);
begin
  if ResStringRec <> nil then
    FMessage := Format(ResStringRec^.Identifier^, Args)
  else
    FMessage := '';
  FHelpContext := AHelpContext;
end;
