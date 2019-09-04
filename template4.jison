/* lexical grammar */
%lex

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
<tp4>"[{"               return 'TP4_OPEN' /* disallow dangling TP4_OPEN */
"}]"                    return 'TP4_CLOSE' /* disallow dangling TP4_CLOSE */

[{}[]]+                 return 'CONTROL_CHARS'
[^{}[]]+                return 'HTML' /* these two capture "everything else" */

<<EOF>>                 return 'EOF'

/lex

%start file

%% /* language grammar */

%ebnf

file: template EOF {console.log(JSON.stringify($1))}
;

template:   /* empty */
          | template chunk
          {{
            if($1 === undefined){
              $$ = [$2]
            }
            else{
              if($2.t == 'html' && $$.slice(-1)[0].t == 'html'){
                $$.push({'t': 'html', d: $$.pop().d.concat($2.d)}) /* this is terrible :/ */
              }
              else{
                $$.push($2)
              }
            }
          }}
;

chunk:  HTML
          {{
            $$ = {t: 'html', d: $1}
          }}
      | CONTROL_CHARS
          {{
            $$ = {t: 'html', d: $1}
          }}
      | TP4_OPEN TP4_VAR TP4_VALUE TP4_RAW? TP4_CLOSE /* [{var ... */
          {{
            $$ = {t: 'var', n: $3}
          }}
      | TP4_OPEN TP4_IF TP4_VALUE tp4_op tp4_argument TP4_LOCAL? TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE? TP4_END TP4_CLOSE /* [{if ... is|!is|not ... */
          {{
            $$ = {t: 'if', n: $3, c: $8}
            if($11 !== undefined && $3 != $11){
              throw new Error('[{if ' + $3 + ' closed with "' + $11 + '" on line ' + yylineno);
            }
          }}
      | TP4_OPEN TP4_IF TP4_VALUE tp4_setop tp4_argument+ TP4_LOCAL? TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE? TP4_END TP4_CLOSE /* [{if ... in|!in ... */
          {{
            $$ = {t: 'if', n: $3, c: $8}
          }}
      | TP4_OPEN TP4_SECTION TP4_VALUE TP4_CLOSE
          template
        TP4_OPEN TP4_SECTION TP4_VALUE? TP4_END TP4_CLOSE /* [{section ... */
          {{
            $$ = {t: 'section', n: $3, c: $5}
          }}
      | TP4_OPEN TP4_LOOP TP4_VALUE TP4_CLOSE
          template
        TP4_OPEN TP4_LOOP TP4_VALUE? TP4_END TP4_CLOSE /* [{loop ... */
          {{
            $$ = {t: 'loop', n: $3, c: $5}
          }}
      | TP4_OPEN TP4_INCLUDE (TP4_TEMPLATE|TP4_COMPONENT|) tp4_string tp4_include_name TP4_CLOSE /* [{include ... */
          {{
            $$ = {t: 'include', d: $4, n: $5}
          }}
;

tp4_string:   TP4_QUOTE TP4_QUOTE
                {{
                  $$ = undefined
                }}
            | TP4_QUOTE TP4_STRING TP4_QUOTE
                {{
                  $$ = $2
                }}
;

tp4_argument:   TP4_VALUE
              | tp4_string
;

tp4_op:   TP4_IS
        | TP4_NOT
        | TP4_NOT TP4_IS
;

tp4_setop:  TP4_IN
          | TP4_NOT TP4_IN
;

tp4_include_name:   /* empty */
                  | TP4_AS TP4_VALUE
                      {{
                        $$ = $2
                      }}
;
