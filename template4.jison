/* lexical grammar */
%lex

%x tp4

%%
"[{"                    this.begin("tp4");
<tp4>"replace"|"var"    return 'TP4_REPLACE'
<tp4>"condition"|"if"   return 'TP4_IF'
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
<tp4>[^\s{}[]]+         return 'TP4_WORD'
<tp4>[\s]+              /* ignore */
<tp4>"}]"               this.popState();

"<!--"                  /* ignore */
"-->"                   /* ignore */

[^{}[]]+                return 'STRING'

/lex

%start input

%% /* language grammar */

input:    /* empty */
        | input part
;

part:   STRING
      | TP4_WORD
      | TP4_REPLACE TP4_WORD {console.log("replace:", $2)}
      | TP4_IF TP4_WORD tp4_operator input TP4_IF TP4_WORD TP4_END {console.log("if:", $2)}
      | TP4_SECTION TP4_WORD input TP4_SECTION TP4_WORD TP4_END {console.log("section:", $2)}
      | TP4_LOOP TP4_WORD input TP4_LOOP TP4_WORD TP4_END {console.log("loop:", $2)}
      | TP4_INCLUDE tp4_include_type TP4_WORD tp4_include_name {console.log("include:", $3)}
;

tp4_operator:   TP4_IN
              | TP4_NOT TP4_IN
              | TP4_IS
              | TP4_NOT
;

tp4_set:    TP4_WORD
          | tp4_set TP4_WORD
;

tp4_include_type:   /* empty */
                  | TP4_TEMPLATE
                  | TP4_COMPONENT
;

tp4_include_name:   /* empty */
                  | TP4_AS TP4_WORD
;
