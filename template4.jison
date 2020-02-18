// Lexical grammar
%lex

%option caseless
%options easy_keyword_rules

%x tp4
%x tp4str

%%
"[{"|"<!--"\s*"[{"      this.begin('tp4'); return 'TP4_OPEN'
<tp4>"var"|"replace"    return 'TP4_VAR'
<tp4>"if"|"condition"   return 'TP4_IF'
<tp4>"section"          return 'TP4_SECTION'
<tp4>"loop"|"repeater"  return 'TP4_LOOP'
<tp4>"include"          return 'TP4_INCLUDE'
<tp4>"in"               return 'TP4_IN'
<tp4>"is"               return 'TP4_IS'
<tp4>"not"|"!"          return 'TP4_NOT'
<tp4>"end"              return 'TP4_END'
<tp4>"template"         return 'TP4_TEMPLATE'
<tp4>"component"        return 'TP4_COMPONENT'
<tp4>"as"               return 'TP4_AS'
<tp4>"raw"              return 'TP4_RAW'
<tp4>"local"            return 'TP4_LOCAL'
<tp4>["]                this.begin('tp4str'); return 'TP4_QUOTE'
<tp4str>[^"\n]+         return 'TP4_STRING'
<tp4str>[\n]+           return 'TP4_LN_IN_STRING'
<tp4str>["]             this.popState(); return 'TP4_QUOTE'
<tp4>[a-zA-Z0-9_]+      return 'TP4_VALUE'
<tp4>[\s]+              // Ignore whitespace inside TP4-syntax
<tp4>"}]"|"}]"\s*"-->"  this.popState(); return 'TP4_CLOSE'
<tp4>"[{"               return 'TP4_OPEN'   // Disallow dangling TP4_OPEN
"}]"                    return 'TP4_CLOSE'  // Disallow dangling TP4_CLOSE

[{}\[\]]+               return 'CONTROL_CHARS'
[^{}\[\]]+              return 'HTML' // These two capture "everything else"

<<EOF>>                 return 'EOF'

/lex

%ebnf
%start file

%% // Language grammar

file: template EOF {return $template;}
;

template:   // Empty
          | template part
              %{
                if($template === undefined || typeof $$ != 'object'){
                  $$ = [$part]
                }
                else{
                  if($part.t == 'html' && $$.slice(-1)[0].t == 'html'){
                    $$.push({'t': 'html', d: $$.pop().d.concat($part.d)})
                  }
                  else{
                    $$.push($part)
                  }
                }
              %}
;

part:   HTML
          %{
            $$ = { t: 'html', d: $HTML }
          %}
      | CONTROL_CHARS
          %{
            $$ = { t: 'html', d: $CONTROL_CHARS }
          %}
      | // [{var … }]
        TP4_OPEN TP4_VAR TP4_VALUE[name] TP4_RAW?[raw] TP4_CLOSE
          %{
            $raw = ($raw ? true : false);
            $$ = { t: 'var', n: $name, a: { raw: $raw } }
          %}
      | // [{if … is|!is … }] … [{if end}]
        TP4_OPEN TP4_IF TP4_VALUE[name1] tp4_op (TP4_VALUE|tp4_string)[compare] TP4_LOCAL?[local] TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $compare = ($compare[0] === undefined ? '' : $compare[0]);
            $local = ($local ? true : false);
            $$ = { t: 'if', n: $name1, d: $compare, o: $tp4_op, c: $template, a: { local: $local } }
            if($name2 !== undefined && $name1 != $name2){
              throw new Error(
                `Unmatched if-statement on line ${yylineno}, expecting "${$name1}", got "${$name2}"`
              );
            }
          %}
      | // [{if … in|!in … }] … [{if end}]
        TP4_OPEN TP4_IF TP4_VALUE[name1] tp4_setop (TP4_VALUE|tp4_string)+[compare] TP4_LOCAL?[local] TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $compare = $compare.map(x => x === undefined ? '' : x);
            $local = ($local ? true : false);
            $$ = { t: 'if', n: $name1, d: $compare, o: $tp4_setop, c: $template, a: { local: $local } }
            if($name2 !== undefined && $name1 != $name2){
              throw new Error(
                `Unmatched if-statement on line ${yylineno}, expecting "${$name1}", got "${$name2}"`
              );
            }
          %}
      | // [{section … }] … [{section end}]
        TP4_OPEN TP4_SECTION TP4_VALUE[name1] TP4_CLOSE
          template
        TP4_OPEN TP4_SECTION TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $$ = { t: 'section', n: $name1, c: $template }
            if($name2 !== undefined && $name1 != $name2){
              throw new Error(
                `Unmatched section-statement on line ${yylineno}, expecting "${$name1}", got "${$name2}"`
              );
            }
          %}
      | // [{loop … }] … [{loop end}]
        TP4_OPEN TP4_LOOP TP4_VALUE[name1] TP4_CLOSE
          template
        TP4_OPEN TP4_LOOP TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $$ = { t: 'loop', n: $name1, c: $template }
            if($name2 !== undefined && $name1 != $name2){
              throw new Error(
                `Unmatched loop-statement on line ${yylineno}, expecting "${$name1}", got "${$name2}"`
              );
            }
          %}
      | // [{include … }]
        TP4_OPEN TP4_INCLUDE tp4_string TP4_CLOSE
          %{
            $$ = { t: 'include', d: $tp4_string }
          %}
      | // [{include template … }]
        TP4_OPEN TP4_INCLUDE TP4_TEMPLATE tp4_string tp4_as_name TP4_CLOSE
          %{
            $$ = { t: 'template', d: $tp4_string, n: $tp4_as_name }
          %}
      | // [{include component … }]
        TP4_OPEN TP4_INCLUDE TP4_COMPONENT tp4_string tp4_as_name TP4_CLOSE
          %{
            $$ = { t: 'component', d: $tp4_string, n: $tp4_as_name }
          %}
;

tp4_string:   TP4_QUOTE TP4_QUOTE             { $$ = undefined }
            | TP4_QUOTE TP4_STRING TP4_QUOTE  { $$ = $TP4_STRING }
;

tp4_op:   TP4_IS            { $$ = 'is' }
        | TP4_NOT           { $$ = 'not' }
        | TP4_NOT TP4_IS    { $$ = 'not' }
;

tp4_setop:  TP4_IN          { $$ = 'is' }
          | TP4_NOT TP4_IN  { $$ = 'not' }
;

tp4_as_name:  // Empty
            | TP4_AS (TP4_VALUE|tp4_string)[value] { $$ = $value }
;
