unit np_package_lock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPackageLockEntryInfo = record
    Name: string;
    Version: string;
  end;

  TPackageLockEntryInfoArray = array of TPackageLockEntryInfo;

  TPackageLockIssueInfo = record
    Code: string;
    Message: string;
    LineText: string;
  end;

  TPackageLockIssueInfoArray = array of TPackageLockIssueInfo;

  TPackageLockInfo = record
    Status: string;
    LockfilePath: string;
    FormatVersion: LongInt;
    Entries: TPackageLockEntryInfoArray;
    Issues: TPackageLockIssueInfoArray;
  end;

function LoadPackageLockInfo(const ALockfilePath: string): TPackageLockInfo;
function TryLoadPackageLockInfo(
  const ALockfilePath: string;
  out AInfo: TPackageLockInfo;
  out AErrorText: string
): Boolean;

implementation

procedure AppendPackageLockEntryInfo(
  var AValues: TPackageLockEntryInfoArray;
  const AValue: TPackageLockEntryInfo
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

procedure AppendPackageLockIssueInfo(
  var AValues: TPackageLockIssueInfoArray;
  const AValue: TPackageLockIssueInfo
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

function StripTomlComment(const ALine: string): string;
var
  Index: SizeInt;
  InString: Boolean;
begin
  Result := '';
  InString := False;
  for Index := 1 to Length(ALine) do
  begin
    if ALine[Index] = '"' then
      InString := not InString
    else if (ALine[Index] = '#') and not InString then
      Break;

    Result := Result + ALine[Index];
  end;
end;

function TrySplitTomlAssignment(
  const ALine: string;
  out AKey: string;
  out AValue: string
): Boolean;
var
  SeparatorIndex: SizeInt;
begin
  SeparatorIndex := Pos('=', ALine);
  Result := SeparatorIndex > 0;
  if not Result then
  begin
    AKey := '';
    AValue := '';
    Exit;
  end;

  AKey := Trim(Copy(ALine, 1, SeparatorIndex - 1));
  AValue := Trim(Copy(ALine, SeparatorIndex + 1, MaxInt));
end;

function TryParseTomlStringLiteral(
  const AValue: string;
  out AText: string
): Boolean;
var
  TrimmedValue: string;
begin
  TrimmedValue := Trim(AValue);
  Result := (Length(TrimmedValue) >= 2) and
    (TrimmedValue[1] = '"') and (TrimmedValue[Length(TrimmedValue)] = '"');
  if Result then
    AText := Copy(TrimmedValue, 2, Length(TrimmedValue) - 2)
  else
    AText := '';
end;

procedure AddPackageLockIssue(
  var AInfo: TPackageLockInfo;
  const ACode: string;
  const AMessage: string;
  const ALineText: string
);
var
  Issue: TPackageLockIssueInfo;
begin
  Issue.Code := ACode;
  Issue.Message := AMessage;
  Issue.LineText := ALineText;
  AppendPackageLockIssueInfo(AInfo.Issues, Issue);
end;

function LoadPackageLockInfo(const ALockfilePath: string): TPackageLockInfo;
var
  CurrentEntry: TPackageLockEntryInfo;
  CurrentSection: string;
  FormatVersionFound: Boolean;
  Key: string;
  LineIndex: LongInt;
  Lines: TStringList;
  LineText: string;
  ParsedFormatVersion: LongInt;
  RawLineText: string;
  StringValue: string;
  Value: string;
  WithinPackageEntry: Boolean;

  procedure ClearCurrentEntry;
  begin
    CurrentEntry.Name := '';
    CurrentEntry.Version := '';
  end;

  procedure FinalizeCurrentEntry;
  begin
    if not WithinPackageEntry then
      Exit;

    if Trim(CurrentEntry.Name) = '' then
      AddPackageLockIssue(
        Result,
        'package.lock.package-name-missing',
        'package lockfile package name is missing',
        ''
      );
    if Trim(CurrentEntry.Version) = '' then
      AddPackageLockIssue(
        Result,
        'package.lock.package-version-missing',
        'package lockfile package version is missing',
        ''
      );

    AppendPackageLockEntryInfo(Result.Entries, CurrentEntry);
    ClearCurrentEntry;
    WithinPackageEntry := False;
  end;

begin
  Result.Status := 'missing';
  if Trim(ALockfilePath) <> '' then
    Result.LockfilePath := ExpandFileName(ALockfilePath)
  else
    Result.LockfilePath := '';
  Result.FormatVersion := 0;
  SetLength(Result.Entries, 0);
  SetLength(Result.Issues, 0);

  if (Result.LockfilePath = '') or (not FileExists(Result.LockfilePath)) then
    Exit;

  CurrentSection := '';
  FormatVersionFound := False;
  WithinPackageEntry := False;
  ClearCurrentEntry;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Result.LockfilePath);
    for LineIndex := 0 to Lines.Count - 1 do
    begin
      RawLineText := Lines[LineIndex];
      LineText := Trim(StripTomlComment(RawLineText));
      if LineText = '' then
        Continue;

      if LineText = '[lockfile]' then
      begin
        FinalizeCurrentEntry;
        CurrentSection := 'lockfile';
        Continue;
      end;

      if LineText = '[[package]]' then
      begin
        FinalizeCurrentEntry;
        CurrentSection := 'package';
        WithinPackageEntry := True;
        ClearCurrentEntry;
        Continue;
      end;

      if (Length(LineText) >= 2) and (LineText[1] = '[') and
        (LineText[Length(LineText)] = ']') then
      begin
        FinalizeCurrentEntry;
        CurrentSection := '';
        Continue;
      end;

      if not TrySplitTomlAssignment(LineText, Key, Value) then
        Continue;

      if (CurrentSection = 'lockfile') and (Key = 'format-version') then
      begin
        FormatVersionFound := True;
        if TryStrToInt(Value, ParsedFormatVersion) then
        begin
          Result.FormatVersion := ParsedFormatVersion;
          if ParsedFormatVersion <> 1 then
            AddPackageLockIssue(
              Result,
              'package.lock.format-version-unsupported',
              'package lockfile format-version is unsupported',
              LineText
            );
        end
        else
          AddPackageLockIssue(
            Result,
            'package.lock.format-version-unsupported',
            'package lockfile format-version is unsupported',
            LineText
          );
        Continue;
      end;

      if (CurrentSection = 'package') and WithinPackageEntry then
      begin
        if (Key = 'name') and TryParseTomlStringLiteral(Value, StringValue) then
          CurrentEntry.Name := StringValue
        else if (Key = 'version') and
          TryParseTomlStringLiteral(Value, StringValue) then
          CurrentEntry.Version := StringValue;
      end;
    end;
    FinalizeCurrentEntry;
  finally
    Lines.Free;
  end;

  if not FormatVersionFound then
    AddPackageLockIssue(
      Result,
      'package.lock.format-version-missing',
      'package lockfile format-version is missing',
      ''
    );

  if Length(Result.Issues) > 0 then
    Result.Status := 'invalid'
  else
    Result.Status := 'ready';
end;

function TryLoadPackageLockInfo(
  const ALockfilePath: string;
  out AInfo: TPackageLockInfo;
  out AErrorText: string
): Boolean;
begin
  AErrorText := '';
  try
    AInfo := LoadPackageLockInfo(ALockfilePath);
    Result := True;
  except
    on E: Exception do
    begin
      AInfo.Status := 'invalid';
      if Trim(ALockfilePath) <> '' then
        AInfo.LockfilePath := ExpandFileName(ALockfilePath)
      else
        AInfo.LockfilePath := '';
      AInfo.FormatVersion := 0;
      SetLength(AInfo.Entries, 0);
      SetLength(AInfo.Issues, 0);
      AErrorText := E.Message;
      Result := False;
    end;
  end;
end;

end.
