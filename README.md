# Jison-based parser-generator for Template4

Formalising the Template4-syntax and &dash; perhaps &dash; create a
production-ready JavaScript-based Template4-parser.

```
npm install
npm run build
npm run test
```

The `npm run test` command will output a rough &ndash; but structurally sound
&ndash; JSON-representation of the Template4 AST as produced by the
jison-generated parser. Currently, only types (`t`), names (`n`), node children
(`c`) and node data (`d`) are present in the AST.

Two test Template4-files are included:

1. `Test.tp4` &ndash; the original test-file used to develop the PHP-based
   Template4-engine about 10 years ago.
2. `New.tp4` &ndash; an updated version of `Test.tp4` to accommodate for
   (backwards-compatible) improvements to the syntax made possible by the new
   lexer/parser approach (changes noted at the start of the file).

There are some major caveats still:

- Readability of the `jison`-file is poor at best... 😇
- I haven't been able to find a good way of capturing "everything but" the
  TP4-syntax. The current approach &ndash; with two patterns &ndash; one
  capturing everything but `{}[]` (the Template4 control-characters) and one
  capturing `{}[]` works just fine from a lexer/parser perspective, but it
  requires some terrible array manipulation to prevent spamming the AST with
  unnecessary HTML-nodes.
- The AST construction-logic is part of the parser (not good for readability).
  Probably best to pull this out into a separate AST class (as seen in most
  online examples using `yy.ast`).
- Some additional validation logic is still required (mainly to ensure matching
  Template4 open- and close-tags have the same identifier; this cannot be done
  in pure BNF). Might consider to simply remove this criterion (as it is
  absolutely _not_ necessary to properly parse the template).
- In some places, EBNF should be used instead of BNF. The end-result is the same
  (EBNF is translated into BNF by jison), but it helps with readability &ndash;
  mainly in places where an optional token is present.
- The original PHP-implementation processed includes as part of the
  parsing-stage. That doesn't seem like a good idea in this approach (pushes too
  much complexity into the `jison`file), which would require an intermediate
  "include-resolving" step after constructing the AST.

## References

1. https://github.com/zaach/jison
2. http://zaa.ch/jison/docs/
3. http://dinosaur.compilertools.net/bison/index.html
4. https://gist.github.com/zaach/1659274
