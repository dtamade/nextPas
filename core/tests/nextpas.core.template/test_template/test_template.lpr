program test_template;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.template;

var
  T: TTestSuite;

procedure ExpectParseError(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EParseError do
      ;
  end;
end;

procedure ExpectArgumentError(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EArgumentError do
      ;
  end;
end;

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

procedure Test_RangeRestoresDotScope;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('.', 'root');
  LCtx.SetList('Rows', ['r1', 'r2']);
  LCtx.SetList('Cells', ['c1']);
  CheckEqual('root|[r1:(c1)/r1][r2:(c1)/r2]|root',
    TemplateRender('{{.}}|{{range .Rows}}[{{.}}:{{range .Cells}}({{.}}){{end}}/{{.}}]{{end}}|{{.}}', LCtx));
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

procedure Test_MalformedPipeRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'Alice');

  ExpectParseError(
    procedure
    begin
      TemplateRender('{{.Name |}}', LCtx);
    end,
    'empty trailing pipe filter should raise parse error'
  );

  ExpectParseError(
    procedure
    begin
      TemplateRender('{{.Name || upper}}', LCtx);
    end,
    'empty middle pipe filter should raise parse error'
  );
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

procedure Test_RegisterFuncRejectsNil;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectArgumentError(
    procedure
    begin
      LCtx.RegisterFunc('bad', nil);
    end,
    'nil template function should be rejected at registration'
  );
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

var
  GSkipSideEffectCount: Integer = 0;

function CountSideEffectFunc(const AValue: string): string;
begin
  Inc(GSkipSideEffectCount);
  Result := AValue;
end;

procedure Test_SkippedElseDoesNotCallFunc;
var
  LCtx: TTemplateContext;
begin
  GSkipSideEffectCount := 0;
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  LCtx.SetVar('Name', 'hidden');
  LCtx.RegisterFunc('countSideEffect', @CountSideEffectFunc);

  CheckEqual('ok',
    TemplateRender('{{if .Show}}ok{{else}}{{.Name | countSideEffect}}{{end}}', LCtx));
  CheckEqual(Int64(0), Int64(GSkipSideEffectCount), 'skipped else must not call custom function');
end;

procedure Test_EmptyRangeDoesNotDefineTemplate;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetList('Items', []);

  CheckEqual('',
    TemplateRender('{{range .Items}}{{define "hidden"}}leaked{{end}}{{end}}{{template "hidden"}}', LCtx));
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

procedure Test_LocalAssignDoesNotEscapeBlocks;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  LCtx.SetVar('Name', 'Alice');

  CheckEqual('in=Alice;out=',
    TemplateRender('{{if .Show}}{{$x := .Name}}in={{$x}}{{end}};out={{$x}}', LCtx),
    'local assignment inside if must not escape block');

  LCtx.SetList('Items', ['a', 'b']);
  CheckEqual('[a][b];after=',
    TemplateRender('{{range .Items}}{{$item := .}}[{{$item}}]{{end}};after={{$item}}', LCtx),
    'local assignment inside range must not escape range');
end;

procedure Test_MalformedVarAssignRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'Alice');
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{$ := .Name}}', LCtx);
    end,
    'empty local name should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{$x :=}}', LCtx);
    end,
    'empty local assignment expression should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{$x = .Name}}', LCtx);
    end,
    'single equals local assignment should raise parse error'
  );
end;

procedure Test_SkippedMalformedVarAssignRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{$x :=}}{{end}}', LCtx);
    end,
    'malformed local assignment in skipped branch should raise parse error'
  );
end;

procedure Test_SkippedMalformedPipeRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  LCtx.SetVar('Name', 'hidden');

  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{.Name |}}{{end}}', LCtx);
    end,
    'malformed pipe in skipped branch should raise parse error'
  );
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

procedure Test_InlineDefineDoesNotMutateContext;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.Define('slot', 'old');

  CheckEqual('new',
    TemplateRender('{{define "slot"}}new{{end}}{{template "slot"}}', LCtx),
    'inline define remains usable during render');
  CheckEqual('old', LCtx.GetDefine('slot'),
    'inline define must not overwrite caller context');
  CheckEqual('old', TemplateRender('{{template "slot"}}', LCtx),
    'later render sees caller-owned define');
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

procedure Test_MalformedDefineNameRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{define}}bad{{end}}', LCtx);
    end,
    'define without quoted name should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{define foo "bad"}}bad{{end}}', LCtx);
    end,
    'define with non-leading quoted name should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{define ""}}bad{{end}}', LCtx);
    end,
    'define with empty name should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{define "bad}}bad{{end}}', LCtx);
    end,
    'define with unterminated quoted name should raise parse error'
  );
end;

procedure Test_MalformedTemplateNameRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.Define('greeting', 'Hello');
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{template}}', LCtx);
    end,
    'template without quoted name should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{template "greeting" extra}}', LCtx);
    end,
    'template with trailing tokens should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{template ""}}', LCtx);
    end,
    'template with empty name should raise parse error'
  );
end;

procedure Test_SkippedMalformedTemplateNameRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{template}}{{end}}', LCtx);
    end,
    'malformed template in skipped branch should raise parse error'
  );
end;

procedure Test_MalformedIfActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if}}bad{{end}}', LCtx);
    end,
    'if without expression should raise parse error'
  );
end;

procedure Test_SkippedMalformedIfActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{if}}bad{{end}}{{end}}', LCtx);
    end,
    'malformed if in skipped branch should raise parse error'
  );
end;

procedure Test_MalformedIfCompareRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if eq}}bad{{end}}', LCtx);
    end,
    'if comparison without operands should raise parse error'
  );
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if eq .Show}}bad{{end}}', LCtx);
    end,
    'if comparison without right operand should raise parse error'
  );
end;

procedure Test_SkippedMalformedIfCompareRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{if eq}}bad{{end}}{{end}}', LCtx);
    end,
    'malformed if comparison in skipped branch should raise parse error'
  );
end;

procedure Test_MalformedRangeActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{range}}bad{{end}}', LCtx);
    end,
    'range without expression should raise parse error'
  );
end;

procedure Test_SkippedMalformedRangeActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{range}}bad{{end}}{{end}}', LCtx);
    end,
    'malformed range in skipped branch should raise parse error'
  );
end;

procedure Test_MalformedWithActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{with}}bad{{end}}', LCtx);
    end,
    'with without expression should raise parse error'
  );
end;

procedure Test_MalformedStopActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}yes{{end extra}}', LCtx);
    end,
    'end with trailing expression should raise parse error'
  );

  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}yes{{else extra}}no{{end}}', LCtx);
    end,
    'else with trailing expression should raise parse error'
  );
end;

procedure Test_SkippedMalformedStopActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', False);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}yes{{else extra}}no{{end}}', LCtx);
    end,
    'skipped else with trailing expression should raise parse error'
  );

  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}yes{{end extra}}', LCtx);
    end,
    'skipped end with trailing expression should raise parse error'
  );
end;

procedure Test_SkippedMalformedWithActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}ok{{else}}{{with}}bad{{end}}{{end}}', LCtx);
    end,
    'malformed with in skipped branch should raise parse error'
  );
end;

procedure Test_UnclosedIfRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetBool('Show', True);
  ExpectParseError(
    procedure
    begin
      TemplateRender('{{if .Show}}yes', LCtx);
    end,
    'unclosed if block should raise parse error'
  );
end;

procedure Test_UnexpectedEndRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  ExpectParseError(
    procedure
    begin
      TemplateRender('before{{end}}after', LCtx);
    end,
    'top-level end should raise parse error'
  );
end;

procedure Test_UnclosedActionRaisesParseError;
var
  LCtx: TTemplateContext;
begin
  LCtx := TTemplateContext.Create;
  LCtx.SetVar('Name', 'World');
  ExpectParseError(
    procedure
    begin
      TemplateRender('hello {{.Name', LCtx);
    end,
    'unclosed template action should raise parse error'
  );
end;

begin
  T := TTestSuite.Create('nextpas.core.template');
  T.Test('SimpleVar', @Test_SimpleVar);
  T.Test('SimpleVarNoDot', @Test_SimpleVarNoDot);
  T.Test('MultipleVars', @Test_MultipleVars);
  T.Test('IntVar', @Test_IntVar);
  T.Test('IfTrue', @Test_IfTrue);
  T.Test('IfFalse', @Test_IfFalse);
  T.Test('IfElseTrue', @Test_IfElseTrue);
  T.Test('IfElseFalse', @Test_IfElseFalse);
  T.Test('RangeBasic', @Test_RangeBasic);
  T.Test('RangeEmpty', @Test_RangeEmpty);
  T.Test('RangeRestoresDotScope', @Test_RangeRestoresDotScope);
  T.Test('FilterUpper', @Test_FilterUpper);
  T.Test('FilterLower', @Test_FilterLower);
  T.Test('FilterTrim', @Test_FilterTrim);
  T.Test('FilterDefault_Empty', @Test_FilterDefault_Empty);
  T.Test('FilterDefault_HasValue', @Test_FilterDefault_HasValue);
  T.Test('FilterLen', @Test_FilterLen);
  T.Test('FilterChain', @Test_FilterChain);
  T.Test('MalformedPipeRaisesParseError', @Test_MalformedPipeRaisesParseError);
  T.Test('UndefinedVar', @Test_UndefinedVar);
  T.Test('EscapedBraces', @Test_EscapedBraces);
  T.Test('EmptyTemplate', @Test_EmptyTemplate);
  T.Test('NoTags', @Test_NoTags);
  T.Test('NestedIfInRange', @Test_NestedIfInRange);
  T.Test('ComplexTemplate', @Test_ComplexTemplate);
  T.Test('TTemplateRecord', @Test_TTemplateRecord);
  T.Test('RenderWith', @Test_RenderWith);
  T.Test('BoolTruthy_NonEmpty', @Test_BoolTruthy_NonEmpty);
  T.Test('BoolFalsy_Empty', @Test_BoolFalsy_Empty);
  T.Test('BoolFalsy_Zero', @Test_BoolFalsy_Zero);
  T.Test('GetVar_Existing', @Test_GetVar_Existing);
  T.Test('GetVar_Missing', @Test_GetVar_Missing);
  T.Test('GetBool_True', @Test_GetBool_True);
  T.Test('GetBool_False', @Test_GetBool_False);
  T.Test('GetBool_Missing', @Test_GetBool_Missing);
  T.Test('GetList_Existing', @Test_GetList_Existing);
  T.Test('GetList_Missing', @Test_GetList_Missing);
  T.Test('GetList_ReturnsSnapshot', @Test_GetList_ReturnsSnapshot);
  T.Test('SetInt_GetVar', @Test_SetInt_GetVar);
  { New feature tests }
  T.Test('NestedField', @Test_NestedField);
  T.Test('CompareEq_True', @Test_CompareEq_True);
  T.Test('CompareEq_False', @Test_CompareEq_False);
  T.Test('CompareNe', @Test_CompareNe);
  T.Test('CompareGt_Numeric', @Test_CompareGt_Numeric);
  T.Test('CompareLt_Numeric', @Test_CompareLt_Numeric);
  T.Test('CompareGe_Equal', @Test_CompareGe_Equal);
  T.Test('CompareLe_Equal', @Test_CompareLe_Equal);
  T.Test('CompareGe_Greater', @Test_CompareGe_Greater);
  T.Test('CompareLe_Less', @Test_CompareLe_Less);
  T.Test('CustomFunc', @Test_CustomFunc);
  T.Test('RegisterFuncRejectsNil', @Test_RegisterFuncRejectsNil);
  T.Test('CustomFunc_Chain', @Test_CustomFunc_Chain);
  T.Test('SkippedElseDoesNotCallFunc', @Test_SkippedElseDoesNotCallFunc);
  T.Test('EmptyRangeDoesNotDefineTemplate', @Test_EmptyRangeDoesNotDefineTemplate);
  T.Test('VarAssign', @Test_VarAssign);
  T.Test('VarAssign_WithFilter', @Test_VarAssign_WithFilter);
  T.Test('LocalAssignDoesNotEscapeBlocks', @Test_LocalAssignDoesNotEscapeBlocks);
  T.Test('MalformedVarAssignRaisesParseError', @Test_MalformedVarAssignRaisesParseError);
  T.Test('SkippedMalformedVarAssignRaisesParseError', @Test_SkippedMalformedVarAssignRaisesParseError);
  T.Test('SkippedMalformedPipeRaisesParseError', @Test_SkippedMalformedPipeRaisesParseError);
  T.Test('CompareElse', @Test_CompareElse);
  { Define/Template/With tests }
  T.Test('DefineAndTemplate', @Test_DefineAndTemplate);
  T.Test('InlineDefineDoesNotMutateContext', @Test_InlineDefineDoesNotMutateContext);
  T.Test('WithScope', @Test_WithScope);
  T.Test('TemplateMissing', @Test_TemplateMissing);
  T.Test('MalformedDefineNameRaisesParseError', @Test_MalformedDefineNameRaisesParseError);
  T.Test('MalformedTemplateNameRaisesParseError', @Test_MalformedTemplateNameRaisesParseError);
  T.Test('SkippedMalformedTemplateNameRaisesParseError', @Test_SkippedMalformedTemplateNameRaisesParseError);
  T.Test('MalformedIfActionRaisesParseError', @Test_MalformedIfActionRaisesParseError);
  T.Test('SkippedMalformedIfActionRaisesParseError', @Test_SkippedMalformedIfActionRaisesParseError);
  T.Test('MalformedIfCompareRaisesParseError', @Test_MalformedIfCompareRaisesParseError);
  T.Test('SkippedMalformedIfCompareRaisesParseError', @Test_SkippedMalformedIfCompareRaisesParseError);
  T.Test('MalformedRangeActionRaisesParseError', @Test_MalformedRangeActionRaisesParseError);
  T.Test('SkippedMalformedRangeActionRaisesParseError', @Test_SkippedMalformedRangeActionRaisesParseError);
  T.Test('MalformedWithActionRaisesParseError', @Test_MalformedWithActionRaisesParseError);
  T.Test('MalformedStopActionRaisesParseError', @Test_MalformedStopActionRaisesParseError);
  T.Test('SkippedMalformedStopActionRaisesParseError', @Test_SkippedMalformedStopActionRaisesParseError);
  T.Test('SkippedMalformedWithActionRaisesParseError', @Test_SkippedMalformedWithActionRaisesParseError);
  T.Test('UnclosedIfRaisesParseError', @Test_UnclosedIfRaisesParseError);
  T.Test('UnexpectedEndRaisesParseError', @Test_UnexpectedEndRaisesParseError);
  T.Test('UnclosedActionRaisesParseError', @Test_UnclosedActionRaisesParseError);
  if not T.Run then Halt(1);
end.
