program test_template;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.template;

var
  T: TTestRunner;

procedure Test_SimpleVar;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'World');
  CheckEqual('Hello World', TemplateRender('Hello {{.Name}}', LCtx));
end;

procedure Test_SimpleVarNoDot;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'World');
  CheckEqual('Hello World', TemplateRender('Hello {{Name}}', LCtx));
end;

procedure Test_MultipleVars;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('First', 'John');
  LCtx.SetVar('Last', 'Doe');
  CheckEqual('John Doe', TemplateRender('{{.First}} {{.Last}}', LCtx));
end;

procedure Test_IntVar;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetInt('Age', 42);
  CheckEqual('Age: 42', TemplateRender('Age: {{.Age}}', LCtx));
end;

procedure Test_IfTrue;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  CheckEqual('visible', TemplateRender('{{if .Show}}visible{{end}}', LCtx));
end;

procedure Test_IfFalse;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', False);
  CheckEqual('', TemplateRender('{{if .Show}}visible{{end}}', LCtx));
end;

procedure Test_IfElseTrue;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Active', True);
  CheckEqual('yes', TemplateRender('{{if .Active}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_IfElseFalse;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Active', False);
  CheckEqual('no', TemplateRender('{{if .Active}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_RangeBasic;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', ['a', 'b', 'c']);
  CheckEqual('[a][b][c]', TemplateRender('{{range .Items}}[{{.}}]{{end}}', LCtx));
end;

procedure Test_RangeEmpty;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', []);
  CheckEqual('', TemplateRender('{{range .Items}}[{{.}}]{{end}}', LCtx));
end;

procedure Test_FilterUpper;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'hello');
  CheckEqual('HELLO', TemplateRender('{{.Name | upper}}', LCtx));
end;

procedure Test_FilterLower;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'HELLO');
  CheckEqual('hello', TemplateRender('{{.Name | lower}}', LCtx));
end;

procedure Test_FilterTrim;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', '  hi  ');
  CheckEqual('hi', TemplateRender('{{.Name | trim}}', LCtx));
end;

procedure Test_FilterDefault_Empty;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('N/A', TemplateRender('{{.Missing | default "N/A"}}', LCtx));
end;

procedure Test_FilterDefault_HasValue;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Val', 'ok');
  CheckEqual('ok', TemplateRender('{{.Val | default "N/A"}}', LCtx));
end;

procedure Test_FilterLen;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'hello');
  CheckEqual('5', TemplateRender('{{.Name | len}}', LCtx));
end;

procedure Test_FilterChain;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', '  hello  ');
  CheckEqual('HELLO', TemplateRender('{{.Name | trim | upper}}', LCtx));
end;

procedure Test_UndefinedVar;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('Hello ', TemplateRender('Hello {{.Unknown}}', LCtx));
end;

procedure Test_EscapedBraces;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('X', 'val');
  CheckEqual('literal {{X}} here', TemplateRender('literal \{{X\}} here', LCtx));
end;

procedure Test_EmptyTemplate;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('', TemplateRender('', LCtx));
end;

procedure Test_NoTags;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('plain text', TemplateRender('plain text', LCtx));
end;

procedure Test_NestedIfInRange;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', ['yes', 'no', 'yes']);
  LCtx.SetBool('Show', True);
  CheckEqual('[yes][no][yes]',
    TemplateRender('{{range .Items}}{{if .Show}}[{{.}}]{{end}}{{end}}', LCtx));
end;

procedure Test_ComplexTemplate;
var
  LCtx: TTemplateContext;
  LTpl: string;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Title', 'Report');
  LCtx.SetBool('HasItems', True);
  LCtx.SetList('Items', ['alpha', 'beta']);
  LTpl := '# {{.Title}}' + LineEnding +
           '{{if .HasItems}}Items:{{range .Items}} {{.}}{{end}}{{else}}None{{end}}';
  CheckEqual('# Report' + LineEnding + 'Items: alpha beta', TemplateRender(LTpl, LCtx));
end;

procedure Test_TTemplateRecord;
var
  LTpl: TTemplate;
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('X', '42');
  LTpl := TTemplate.Create('val={{.X}}');
  CheckEqual('val=42', LTpl.Render(LCtx));
end;

procedure Test_RenderWith;
var
  LTpl: TTemplate;
  LV: TTemplateVar;
begin
  LV.Name := 'Greeting';
  LV.Value := 'Hi';
  LTpl := TTemplate.Create('{{.Greeting}}!');
  CheckEqual('Hi!', LTpl.RenderWith([LV]));
end;

procedure Test_BoolTruthy_NonEmpty;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Val', 'something');
  CheckEqual('yes', TemplateRender('{{if .Val}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_BoolFalsy_Empty;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Val', '');
  CheckEqual('no', TemplateRender('{{if .Val}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_BoolFalsy_Zero;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Val', '0');
  CheckEqual('no', TemplateRender('{{if .Val}}yes{{else}}no{{end}}', LCtx));
end;

{ === TTemplateContext Direct Access Tests === }

procedure Test_GetVar_Existing;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'Alice');
  CheckEqual('Alice', LCtx.GetVar('Name'));
end;

procedure Test_GetVar_Missing;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('', LCtx.GetVar('NonExistent'));
end;

procedure Test_GetBool_True;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Flag', True);
  CheckEqual(True, LCtx.GetBool('Flag'));
end;

procedure Test_GetBool_False;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Flag', False);
  CheckEqual(False, LCtx.GetBool('Flag'));
end;

procedure Test_GetBool_Missing;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual(False, LCtx.GetBool('Missing'));
end;

procedure Test_GetList_Existing;
var
  LCtx: TTemplateContext;
  LList: TStringArray;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', ['x', 'y', 'z']);
  LList := LCtx.GetList('Items');
  CheckEqual(Int64(3), Int64(Length(LList)), 'list length');
  CheckEqual('x', LList[0], 'item 0');
  CheckEqual('y', LList[1], 'item 1');
  CheckEqual('z', LList[2], 'item 2');
end;

procedure Test_GetList_Missing;
var
  LCtx: TTemplateContext;
  LList: TStringArray;
begin
  LCtx := TTemplateContext.Create;
  LList := LCtx.GetList('Missing');
  CheckEqual(Int64(0), Int64(Length(LList)), 'missing list empty');
end;

procedure Test_GetList_ReturnsSnapshot;
var
  LCtx: TTemplateContext;
  LList: TStringArray;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', ['a', 'b']);
  LList := LCtx.GetList('Items');
  LList[0] := 'z';
  CheckEqual('ab', TemplateRender('{{range .Items}}{{.}}{{end}}', LCtx),
    'GetList must not expose mutable context storage');
end;

procedure Test_SetInt_GetVar;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetInt('Count', 99);
  CheckEqual('99', LCtx.GetVar('Count'));
end;

{ === New Feature Tests === }

procedure Test_NestedField;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('User.Name', 'Alice');
  CheckEqual('Hello Alice', TemplateRender('Hello {{.User.Name}}', LCtx));
end;

procedure Test_CompareEq_True;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Status', 'active');
  CheckEqual('yes', TemplateRender('{{if eq .Status "active"}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_CompareEq_False;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Status', 'inactive');
  CheckEqual('no', TemplateRender('{{if eq .Status "active"}}yes{{else}}no{{end}}', LCtx));
end;

procedure Test_CompareNe;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Status', 'inactive');
  CheckEqual('different', TemplateRender('{{if ne .Status "active"}}different{{else}}same{{end}}', LCtx));
end;

procedure Test_CompareGt_Numeric;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Age', '25');
  CheckEqual('adult', TemplateRender('{{if gt .Age "18"}}adult{{else}}minor{{end}}', LCtx));
end;

procedure Test_CompareLt_Numeric;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Age', '10');
  CheckEqual('minor', TemplateRender('{{if lt .Age "18"}}minor{{else}}adult{{end}}', LCtx));
end;

procedure Test_CompareGe_Equal;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Score', '18');
  CheckEqual('pass', TemplateRender('{{if ge .Score "18"}}pass{{else}}fail{{end}}', LCtx));
end;

procedure Test_CompareLe_Equal;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Score', '18');
  CheckEqual('ok', TemplateRender('{{if le .Score "18"}}ok{{else}}over{{end}}', LCtx));
end;

procedure Test_CompareGe_Greater;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Score', '20');
  CheckEqual('pass', TemplateRender('{{if ge .Score "18"}}pass{{else}}fail{{end}}', LCtx));
end;

procedure Test_CompareLe_Less;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Score', '10');
  CheckEqual('ok', TemplateRender('{{if le .Score "18"}}ok{{else}}over{{end}}', LCtx));
end;

function ExclaimFunc(const AValue: string): string;
begin
  Result := AValue + '!';
end;

procedure Test_CustomFunc;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'World');
  LCtx.RegisterFunc('exclaim', @ExclaimFunc);
  CheckEqual('World!', TemplateRender('{{.Name | exclaim}}', LCtx));
end;

function ReverseFunc(const AValue: string): string;
var
  LI, LLen: Integer;
begin
  LLen := Length(AValue);
  SetLength(Result, LLen);
  for LI := 1 to LLen do
    Result[LLen - LI + 1] := AValue[LI];
end;

procedure Test_CustomFunc_Chain;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'hello');
  LCtx.RegisterFunc('reverse', @ReverseFunc);
  CheckEqual('OLLEH', TemplateRender('{{.Name | reverse | upper}}', LCtx));
end;

procedure Test_VarAssign;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'Alice');
  CheckEqual('Hello Alice', TemplateRender('{{$x := .Name}}Hello {{$x}}', LCtx));
end;

procedure Test_VarAssign_WithFilter;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'alice');
  CheckEqual('ALICE', TemplateRender('{{$u := .Name | upper}}{{$u}}', LCtx));
end;

procedure Test_CompareElse;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Role', 'guest');
  CheckEqual('denied', TemplateRender('{{if eq .Role "admin"}}granted{{else}}denied{{end}}', LCtx));
end;

{ === Define/Template/With Tests === }

procedure Test_DefineAndTemplate;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'World');
  CheckEqual('Hello World',
    TemplateRender('{{define "greeting"}}Hello {{.Name}}{{end}}{{template "greeting"}}', LCtx));
end;

procedure Test_WithScope;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('User.Name', 'Alice');
  LCtx.SetVar('User.Age', '30');
  CheckEqual('Alice is 30',
    TemplateRender('{{with .User}}{{.Name}} is {{.Age}}{{end}}', LCtx));
end;

procedure Test_TemplateMissing;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  CheckEqual('before-after',
    TemplateRender('before-{{template "nonexistent"}}after', LCtx));
end;

begin
  T := TTestRunner.Create('nextpas.core.template');
  T.Run('SimpleVar', @Test_SimpleVar);
  T.Run('SimpleVarNoDot', @Test_SimpleVarNoDot);
  T.Run('MultipleVars', @Test_MultipleVars);
  T.Run('IntVar', @Test_IntVar);
  T.Run('IfTrue', @Test_IfTrue);
  T.Run('IfFalse', @Test_IfFalse);
  T.Run('IfElseTrue', @Test_IfElseTrue);
  T.Run('IfElseFalse', @Test_IfElseFalse);
  T.Run('RangeBasic', @Test_RangeBasic);
  T.Run('RangeEmpty', @Test_RangeEmpty);
  T.Run('FilterUpper', @Test_FilterUpper);
  T.Run('FilterLower', @Test_FilterLower);
  T.Run('FilterTrim', @Test_FilterTrim);
  T.Run('FilterDefault_Empty', @Test_FilterDefault_Empty);
  T.Run('FilterDefault_HasValue', @Test_FilterDefault_HasValue);
  T.Run('FilterLen', @Test_FilterLen);
  T.Run('FilterChain', @Test_FilterChain);
  T.Run('UndefinedVar', @Test_UndefinedVar);
  T.Run('EscapedBraces', @Test_EscapedBraces);
  T.Run('EmptyTemplate', @Test_EmptyTemplate);
  T.Run('NoTags', @Test_NoTags);
  T.Run('NestedIfInRange', @Test_NestedIfInRange);
  T.Run('ComplexTemplate', @Test_ComplexTemplate);
  T.Run('TTemplateRecord', @Test_TTemplateRecord);
  T.Run('RenderWith', @Test_RenderWith);
  T.Run('BoolTruthy_NonEmpty', @Test_BoolTruthy_NonEmpty);
  T.Run('BoolFalsy_Empty', @Test_BoolFalsy_Empty);
  T.Run('BoolFalsy_Zero', @Test_BoolFalsy_Zero);
  T.Run('GetVar_Existing', @Test_GetVar_Existing);
  T.Run('GetVar_Missing', @Test_GetVar_Missing);
  T.Run('GetBool_True', @Test_GetBool_True);
  T.Run('GetBool_False', @Test_GetBool_False);
  T.Run('GetBool_Missing', @Test_GetBool_Missing);
  T.Run('GetList_Existing', @Test_GetList_Existing);
  T.Run('GetList_Missing', @Test_GetList_Missing);
  T.Run('GetList_ReturnsSnapshot', @Test_GetList_ReturnsSnapshot);
  T.Run('SetInt_GetVar', @Test_SetInt_GetVar);
  { New feature tests }
  T.Run('NestedField', @Test_NestedField);
  T.Run('CompareEq_True', @Test_CompareEq_True);
  T.Run('CompareEq_False', @Test_CompareEq_False);
  T.Run('CompareNe', @Test_CompareNe);
  T.Run('CompareGt_Numeric', @Test_CompareGt_Numeric);
  T.Run('CompareLt_Numeric', @Test_CompareLt_Numeric);
  T.Run('CompareGe_Equal', @Test_CompareGe_Equal);
  T.Run('CompareLe_Equal', @Test_CompareLe_Equal);
  T.Run('CompareGe_Greater', @Test_CompareGe_Greater);
  T.Run('CompareLe_Less', @Test_CompareLe_Less);
  T.Run('CustomFunc', @Test_CustomFunc);
  T.Run('CustomFunc_Chain', @Test_CustomFunc_Chain);
  T.Run('VarAssign', @Test_VarAssign);
  T.Run('VarAssign_WithFilter', @Test_VarAssign_WithFilter);
  T.Run('CompareElse', @Test_CompareElse);
  { Define/Template/With tests }
  T.Run('DefineAndTemplate', @Test_DefineAndTemplate);
  T.Run('WithScope', @Test_WithScope);
  T.Run('TemplateMissing', @Test_TemplateMissing);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
