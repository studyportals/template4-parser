%parse-param cwd

// Lexical grammar
%lex

%options case-insensitive easy_keyword_rules

%x tp4
%x tp4str

%%
"<!--"\s*"[{"|"[{"      this.pushState('tp4'); return 'TP4_OPEN'
<tp4>"var"|"replace"    return 'TP4_VAR'
<tp4>"if"|"condition"   return 'TP4_IF'
<tp4>"section"          return 'TP4_SECTION'
<tp4>"loop"|"repeater"  return 'TP4_LOOP'
<tp4>"include"          return 'TP4_INCLUDE'
<tp4>"in"               return 'TP4_IN'
<tp4>"is"               return 'TP4_IS'
<tp4>"="                return 'TP4_EQ'
<tp4>"<"                return 'TP4_LT'
<tp4>">"                return 'TP4_GT'
<tp4>"not"|"!"          return 'TP4_NOT'
<tp4>"end"              return 'TP4_END'
<tp4>"template"         return 'TP4_TEMPLATE'
<tp4>"as"               return 'TP4_AS'
<tp4>"raw"              return 'TP4_RAW'
<tp4>\"                 this.pushState('tp4str'); return 'TP4_QUOTE'
<tp4str>[^"\n]+         return 'TP4_STRING'
<tp4str>\n+             return 'TP4_LF_IN_STRING'
<tp4str>\"              this.popState(); return 'TP4_QUOTE'
<tp4>[a-z0-9_]+         return 'TP4_VALUE'
<tp4>[\s]+              // Ignore whitespace inside TP4-syntax
<tp4>"}]"\s*"-->"|"}]"  this.popState(); return 'TP4_CLOSE'
<tp4>"[{"               return 'TP4_OPEN'   // Disallow dangling TP4_OPEN
"}]"                    return 'TP4_CLOSE'  // Disallow dangling TP4_CLOSE
[{\[<]+                 return 'CONTROL_CHARS'
[^{\[<]+                return 'HTML' // These two capture "everything else"

<<EOF>>                 return 'EOF'

/lex

%{
  const fs = require("fs");
  function requireUncached(module){
    delete require.cache[require.resolve(module)];
    return require(module);
  }
  function readInclude(file, cwd){
    cwd = (typeof cwd === 'undefined' ? "" : cwd);
    cwd = cwd.replace(/(\/|\\)+$/, "");
    try{
      return fs.readFileSync(cwd + "/" + file, "utf8");
    }
    catch(e){
      return fs.readFileSync(file, "utf8");
    }
  }
%}

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
        TP4_OPEN TP4_IF TP4_VALUE[name1] tp4_op (TP4_VALUE|tp4_string)[compare] TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $compare = ($compare[0] === undefined ? '' : $compare[0]);
            $$ = { t: 'if', n: $name1, d: $compare, o: $tp4_op, c: $template }
            if($name2 !== undefined && $name1 != $name2){
              let name1 = $name1; let name2 = $name2;
              throw new Error(
                `Unmatched if-statement on line ${@name2.first_line}, expecting "${name1}", got "${name2}"`
              );
            }
          %}
      | // [{if … in|!in … }] … [{if end}]
        TP4_OPEN TP4_IF TP4_VALUE[name1] tp4_setop (TP4_VALUE|tp4_string)+[compare] TP4_CLOSE
          template
        TP4_OPEN TP4_IF TP4_VALUE?[name2] TP4_END TP4_CLOSE
          %{
            $compare = $compare.map(x => x === undefined ? '' : x);
            $$ = { t: 'if', n: $name1, d: $compare, o: $tp4_setop, c: $template }
            if($name2 !== undefined && $name1 != $name2){
              let name1 = $name1; let name2 = $name2;
              throw new Error(
                `Unmatched if-statement on line ${@name2.first_line}, expecting "${name1}", got "${name2}"`
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
              let name1 = $name1; let name2 = $name2;
              throw new Error(
                `Unmatched section-statement on line ${@name2.first_line}, expecting "${name1}", got "${name2}"`
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
              let name1 = $name1; let name2 = $name2;
              throw new Error(
                `Unmatched loop-statement on line ${@name2.first_line}, expecting "${name1}", got "${name2}"`
              );
            }
          %}
      | // [{include … }]
        TP4_OPEN TP4_INCLUDE tp4_string TP4_CLOSE
          %{
            try{
              var data = readInclude(
                $tp4_string,
                (typeof cwd === 'undefined' ? yy.cwd : cwd)
              );
            }
            catch(e){
              let tp4_string = $tp4_string;
              throw new Error(
                `Unable to include "${tp4_string}" on line ${@tp4_string.first_line}`
              );
            }
            $$ = { t: 'html', d: data }
          %}
      | // [{include template … }]
        TP4_OPEN TP4_INCLUDE TP4_TEMPLATE tp4_string tp4_as_name TP4_CLOSE
          %{
            let cwd_t = (typeof cwd === 'undefined' ? yy.cwd : cwd);
            try{
              var data = requireUncached("./template4.js").parse(
                readInclude($tp4_string, cwd_t),
                cwd_t
              );
            }
            catch(e){
              let tp4_string = $tp4_string;
              throw new Error(
                `Unable to include template "${tp4_string}" on line ${@tp4_string.first_line}`
              );
            }
            $$ = { t: 'include', d: data, n: $tp4_as_name }
          %}
;

tp4_string:   TP4_QUOTE TP4_QUOTE             { $$ = undefined }
            | TP4_QUOTE TP4_STRING TP4_QUOTE  { $$ = $TP4_STRING }
;

tp4_op:   TP4_IS            { $$ = '==' }
        | TP4_EQ TP4_EQ?    { $$ = '==' }
        | TP4_NOT           { $$ = '!=' }
        | TP4_NOT TP4_IS    { $$ = '!=' }
        | TP4_NOT TP4_EQ    { $$ = '!=' }
        | TP4_LT            { $$ =  '<' }
        | TP4_LT TP4_EQ     { $$ = '<=' }
        | TP4_GT            { $$ =  '>' }
        | TP4_GT TP4_EQQ    { $$ = '>=' }
;

tp4_setop:  TP4_IN          { $$ =  'in' }
          | TP4_NOT TP4_IN  { $$ = '!in' }
;

tp4_as_name:  // Empty
            | TP4_AS (TP4_VALUE|tp4_string)[value] { $$ = $value }
;

%%
