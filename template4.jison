/* lexical grammar */
%lex

%option caseless
%options easy_keyword_rules

%x tp4
%x tp4str

%%
"[{"|"<!--"\s*"[{"      this.begin("tp4"); return "TP4_OPEN"
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
<tp4>["]                this.begin("tp4str"); return "TP4_QUOTE"
<tp4str>[^"\n]+         return "TP4_STRING"
<tp4str>[\n]+           return "TP4_LN_IN_STRING"
<tp4str>["]             this.popState(); return "TP4_QUOTE"
<tp4>[a-zA-Z0-9_]+      return 'TP4_VALUE'
<tp4>[\s]+              /* ignore whitespace inside TP4-syntax */
<tp4>"}]"|"}]"\s*"-->"  this.popState(); return "TP4_CLOSE"
<tp4>"[{"               return 'TP4_OPEN'   /* disallow dangling TP4_OPEN */
"}]"                    return 'TP4_CLOSE'  /* disallow dangling TP4_CLOSE */

[{}\[\]]+               return 'CONTROL_CHARS'
[^{}\[\]]+              return 'HTML' /* these two capture "everything else" */

<<EOF>>                 return 'EOF'

/lex

%ebnf
%start file

%% /* language grammar */

file: template EOF {return $1;}
;

template:   /* empty */
          | template part
              {{
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
              }}
;

part:   HTML
          {{
            $$ = { t: 'html', d: $1 }
          }}
      | CONTROL_CHARS
          {{
            $$ = { t: 'html', d: $1 }
          }}
      | TP4_OPEN TP4_VAR TP4_VALUE TP4_RAW? TP4_CLOSE /* [{var ... }] */
          {{
            $$ = { t: 'var', n: $3, a: { raw: $4 } }
          }}
      | TP4_OPEN TP4_IF TP4_VALUE tp4_op (TP4_VALUE|tp4_string) TP4_LOCAL? TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE? TP4_END TP4_CLOSE /* [{if ... is|!is ... }] ... [{if end}] */
          {{
            $$ = { t: 'if', n: $3, d: $5, o: $4, c: $8, a: { local: $6 } }
            if($11 !== undefined && $3 != $11){
              throw new Error(yylineno);
            }
          }}
      | TP4_OPEN TP4_IF TP4_VALUE tp4_setop (TP4_VALUE|tp4_string)+ TP4_LOCAL? TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE? TP4_END TP4_CLOSE /* [{if ... in|!in ... }] ... [{if end}] */
          {{
            $$ = { t: 'if', n: $3, d: $5, o: $4, c: $8, a: { local: $6 } }
            if($11 !== undefined && $3 != $11){
              throw new Error(yylineno);
            }
          }}
      | TP4_OPEN TP4_SECTION TP4_VALUE TP4_CLOSE
          template
        TP4_OPEN TP4_SECTION TP4_VALUE? TP4_END TP4_CLOSE /* [{section ... }] ... [{section end}] */
          {{
            $$ = { t: 'section', n: $3, c: $5 }
            if($8 !== undefined && $3 != $8){
              throw new Error(yylineno);
            }
          }}
      | TP4_OPEN TP4_LOOP TP4_VALUE TP4_CLOSE
          template
        TP4_OPEN TP4_LOOP TP4_VALUE? TP4_END TP4_CLOSE /* [{loop ... }] ... [{loop end}]*/
          {{
            $$ = { t: 'loop', n: $3, c: $5 }
            if($8 !== undefined && $3 != $8){
              throw new Error(yylineno);
            }
          }}
      | TP4_OPEN TP4_INCLUDE tp4_string TP4_CLOSE /* [{include ... }] */
          {{
            $$ = { t: 'include', d: $3 }
          }}
      | TP4_OPEN TP4_INCLUDE TP4_TEMPLATE tp4_string tp4_as_name TP4_CLOSE /* [{include template ... }] */
          {{
            $$ = { t: 'template', d: $4, n: $5 }
          }}
      | TP4_OPEN TP4_INCLUDE TP4_COMPONENT tp4_string tp4_as_name TP4_CLOSE /* [{include component ... }] */
          {{
            $$ = { t: 'component', d: $4, n: $5 }
          }}
;

tp4_string:   TP4_QUOTE TP4_QUOTE             { $$ = undefined }
            | TP4_QUOTE TP4_STRING TP4_QUOTE  { $$ = $2 }
;

tp4_op:   TP4_IS            { $$ = 'is' }
        | TP4_NOT           { $$ = 'not' }
        | TP4_NOT TP4_IS    { $$ = 'not' }
;

tp4_setop:  TP4_IN          { $$ = 'is' }
          | TP4_NOT TP4_IN  { $$ = 'not' }
;

tp4_as_name:  /* empty */
            | TP4_AS (TP4_VALUE | tp4_string) { $$ = $2 }
;
