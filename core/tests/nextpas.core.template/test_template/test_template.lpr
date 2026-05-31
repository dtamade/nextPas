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
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
