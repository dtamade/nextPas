unit nextpas.core.http.form.base;
{**
 * @desc HTTP form data types for application/x-www-form-urlencoded and multipart/form-data.
 *}

{$I nextpas.core.settings.inc}

interface

type
  { Single form field (name=value pair) }
  TFormField = record
    Name: string;
    Value: string;
  end;

  TFormFieldArray = array of TFormField;

  { Uploaded file in multipart form }
  THttpFile = record
    FieldName: string;
    FileName: string;
    ContentType: string;
    Content: string; { raw bytes as string }
  end;

  THttpFileArray = array of THttpFile;

  { Parsed multipart form data }
  TMultipartFormData = record
    Fields: TFormFieldArray;
    Files: THttpFileArray;
    function FieldCount: Int32;
    function FileCount: Int32;
    function GetField(const AName: string): string;
    function HasField(const AName: string): Boolean;
    function GetFile(const AFieldName: string): THttpFile;
    function HasFile(const AFieldName: string): Boolean;
  end;

implementation

function TMultipartFormData.FieldCount: Int32;
begin
  Result := Length(Fields);
end;

function TMultipartFormData.FileCount: Int32;
begin
  Result := Length(Files);
end;

function TMultipartFormData.GetField(const AName: string): string;
var
  LI: Int32;
begin
  for LI := 0 to High(Fields) do
    if Fields[LI].Name = AName then
      Exit(Fields[LI].Value);
  Result := '';
end;

function TMultipartFormData.HasField(const AName: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to High(Fields) do
    if Fields[LI].Name = AName then
      Exit(True);
  Result := False;
end;

function TMultipartFormData.GetFile(const AFieldName: string): THttpFile;
var
  LI: Int32;
begin
  for LI := 0 to High(Files) do
    if Files[LI].FieldName = AFieldName then
      Exit(Files[LI]);
  Result := Default(THttpFile);
end;

function TMultipartFormData.HasFile(const AFieldName: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to High(Files) do
    if Files[LI].FieldName = AFieldName then
      Exit(True);
  Result := False;
end;

end.
