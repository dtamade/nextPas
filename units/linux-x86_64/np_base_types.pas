unit np_base_types;

{$mode objfpc}{$H+}

interface

type
  TCoreId = type LongInt;

  TCoreByteSpan = record
    Offset: LongInt;
    Count: LongInt;
  end;

  TCoreSourceSpan = record
    FileId: TCoreId;
    ByteSpan: TCoreByteSpan;
  end;

  TCoreStatus = (
    cstDeferred,
    cstReady,
    cstFailure
  );

  TCoreResultCode = (
    crcOk,
    crcInvalidArgument,
    crcNotFound,
    crcIoError,
    crcOutOfMemory,
    crcUnsupported,
    crcInternalError
  );

  TCoreResult = record
    Code: TCoreResultCode;
    Detail: string;
  end;

function BuildCoreByteSpan(
  const AOffset: LongInt;
  const ACount: LongInt
): TCoreByteSpan;
function BuildCoreSourceSpan(
  const AFileId: TCoreId;
  const AOffset: LongInt;
  const ACount: LongInt
): TCoreSourceSpan;
function BuildCoreResult(
  const ACode: TCoreResultCode;
  const ADetail: string
): TCoreResult;
function BuildCoreOkResult: TCoreResult;
function CoreByteSpanIsEmpty(const ASpan: TCoreByteSpan): Boolean;
function CoreSourceSpanIsValid(const ASpan: TCoreSourceSpan): Boolean;
function CoreResultIsOk(const AResult: TCoreResult): Boolean;
function CoreStatusName(const AStatus: TCoreStatus): string;
function CoreResultCodeName(const ACode: TCoreResultCode): string;

implementation

function BuildCoreByteSpan(
  const AOffset: LongInt;
  const ACount: LongInt
): TCoreByteSpan;
begin
  Result.Offset := AOffset;
  Result.Count := ACount;
end;

function BuildCoreSourceSpan(
  const AFileId: TCoreId;
  const AOffset: LongInt;
  const ACount: LongInt
): TCoreSourceSpan;
begin
  Result.FileId := AFileId;
  Result.ByteSpan := BuildCoreByteSpan(AOffset, ACount);
end;

function BuildCoreResult(
  const ACode: TCoreResultCode;
  const ADetail: string
): TCoreResult;
begin
  Result.Code := ACode;
  Result.Detail := ADetail;
end;

function BuildCoreOkResult: TCoreResult;
begin
  Result := BuildCoreResult(crcOk, '');
end;

function CoreByteSpanIsEmpty(const ASpan: TCoreByteSpan): Boolean;
begin
  Result := ASpan.Count <= 0;
end;

function CoreSourceSpanIsValid(const ASpan: TCoreSourceSpan): Boolean;
begin
  Result := (ASpan.FileId > 0) and (ASpan.ByteSpan.Offset >= 0) and
    (ASpan.ByteSpan.Count >= 0);
end;

function CoreResultIsOk(const AResult: TCoreResult): Boolean;
begin
  Result := AResult.Code = crcOk;
end;

function CoreStatusName(const AStatus: TCoreStatus): string;
begin
  case AStatus of
    cstDeferred:
      Result := 'deferred';
    cstReady:
      Result := 'ready';
    cstFailure:
      Result := 'failure';
  end;
end;

function CoreResultCodeName(const ACode: TCoreResultCode): string;
begin
  case ACode of
    crcOk:
      Result := 'ok';
    crcInvalidArgument:
      Result := 'invalid-argument';
    crcNotFound:
      Result := 'not-found';
    crcIoError:
      Result := 'io-error';
    crcOutOfMemory:
      Result := 'out-of-memory';
    crcUnsupported:
      Result := 'unsupported';
    crcInternalError:
      Result := 'internal-error';
  end;
end;

end.
