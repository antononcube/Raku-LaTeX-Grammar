# LaTeX::Grammar

Raku package with a parser and interpreters of LaTeX code.
The implemented interpretation formats are:

- [MathJSON](https://mathlive.io/math-json/)
- [MathML](https://www.w3.org/TR/mathml4/), [Wikipedia](https://en.wikipedia.org/wiki/MathML)
- [AsciiMath](https://asciimath.org), [Wikipedia](https://en.wikipedia.org/wiki/AsciiMath)
- [RakuAST](https://docs.raku.org/type/RakuAST)
- [Wolfram Language](https://reference.wolfram.com/language), [Wikipedia](https://en.wikipedia.org/wiki/Wolfram_Language)

The MathJSON interpreter was the first to be implemented, and it is the most important one -- the rest are derived from it.

The primary motivation to make this package is:

- Having a readily available LaTeX parser and interpreters (in Raku) gives the ability to work easier with systems for mathematical (symbolic) computations in Raku sessions.
  
For example, the LaTeX parser can be used to recognize (detect or extract) LaTeX expressions in texts and make certain computations with them.

As for the interpreters:

- The MathJSON one was developed in order to have an alternative way of communicating with the [Computation Engine of CortexJS](https://mathlive.io/compute-engine/).
  - See the Raku package ["CortexJS"](https://raku.land/zef:antononcube/CortexJS), [AAp1].
- The Wolfram Language (WL) one was developed to make interaction with [Wolfram Engine](https://www.wolfram.com/engine/).
  - See the Raku package ["Proc::ZMQed"](https://raku.land/zef:antononcube/Proc::ZMQed), [AAp2], and the presentation ["Using Wolfram Engine in Raku sessions"](https://www.youtube.com/watch?v=nWeGkJU3wdM), [AAv1]. 

------

## Installation

From [Zef ecosystem](https://raku.land):

```
zef install LaTeX::Grammar
```

------

## Usage examples

Interpretation to MathJSON (default interpreter):

```raku
use LaTeX::Grammar;

latex-interpret('\frac{1}{x}=\sqrt{y}')
```

A table that show interpretations to different formats:

```raku, results=asis
use Data::Translators;
use Data::Reshapers;

my @formulas = (
'\frac{-1214}{117}',
'\\sqrt{4 * x^2 + 12 * x + 9}',
'\\int_{0}^{1} x^{2} d x',
'\\sum_{n=1}^{10} n^2',
'\\lim_{x\\to0} \\frac{\\sin(x)}{x}',
'\\log_{5} x',
'\log\left( \frac{x+1}{x-1} \right)'
);
my @targets = <AsciiMath WL MathJSON>;

my @res = do for @formulas -> $fm {
    [
     LaTeX => $fm, 
     MathML => "latex«$fm»",
     RakuAST => latex-interpret($fm, actions => 'RakuAST').DEPARSE,
     |@targets.map({ $_ => latex-interpret($fm, actions => $_).raku })
    ].Hash
}

@res 
==> { .&to-long-format(id-columns => 'LaTeX', variables-to => 'Format', values-to => 'Translation') }()
==> { group-by($_, 'LaTeX').map({ $_.value.sort(*<LaTeX Format>).kv.map(-> $i, %r { %r<LaTeX> ='' if $i; %r }) }) }()
==> { $_.flat(1) }()
==> to-html(field-names => <LaTeX Format Translation>, align => 'left')
==> { .subst(/ 'latex«' (.*?) '»' /, { latex-interpret($0.Str, actions => 'MathML')}, :g) }()
==> { .subst(/ '"' | '&quot;' /, :g).subst('\{', '{', :g) }()
```

See also the Jupyter notebook ["Basic-usage.ipynb"](./docs/Basic-usage.ipynb).

**Remark:** In the table above "RakuAST" fields show the "deparsed" RakuAST constructs, i.e., Raku code. 

**Remark:** The MathML code might be rendered incorrectly in GitHub's README. 
In Jupyter notebooks and specialized Markdown viewers it can be seen that the generated MathML code
corresponds to the LaTeX code.

Here is a LaTeX translation to RakuAST structure:

```raku
latex-interpret('\sin(x + 2)', actions => 'RakuAST')
```


-----

## CLI

The package provides Command Line Interface (CLI) script. Here is usage message:

```shell
from-latex --help
```

-----

## TODO

- [ ] TODO Development
  - [X] DONE Core grammar
  - [X] DONE MathJSON actions
    - [X] DONE First, reasonably well working version.
    - [X] DONE Make both of these cases work:
      - `\int _{0} ^{1} x^{2} d x`
      -  `\int_{0}^{1} x^{2} d x`
    - The generated [MathJSON is CortexJS-style](https://mathlive.io/math-json/), but a simpler version might be better.
       - For example, 
         - LaTeX: `\int_{0}^{1}x^{2}dx`
         - CortexJS: `["Integrate",["Function",["Block",["Power","x",2]],"x"],["Limits","x",0,1]]`
         - Simpler: `["Integrate",["Power","x",2],["Limits","x",0,1]]`
       - I contacted ArnoG (creator of CortexJS and MathJSON):
         - He agreed the simpler version has its place as a primary version.
    - [X] DONE Implement `:$function-wrap` option.
  - [X] DONE MathML actions
    - Based on MathJSON.
  - [X] DONE AsciiMath actions
    - Based on MathJSON.
  - [X] DONE Wolfram Language (WL) actions
    - Based on MathJSON.
  - [X] DONE Raku actions (using RakuAST)
    - The MathJSON interpreter does give Raku expressions (arrays.)
    - But the idea is to make Raku expressions from LaTeX using RakuAST.
      - Or generate code and produce AST objects from it.
  - [ ] TODO Refactor the MathML, AsciiMath, and WL action classes into a separate MathJSON converter package
    - Named, say, "MathJSON::Converter" (similar to ["Jupyter::Converter"](https://github.com/antononcube/Raku-Jupyter-Converter)).
- [ ] TODO Documentation
  - [X] DONE Fuller, more comprehensive README
  - [ ] TODO Blog post
  - [ ] TODO Basic usage examples notebook 

-----

## References

### Packages

[AAp1] Anton Antonov, [CortexJS, Raku package](https://github.com/antononcube/Raku-CortexJS), (2026), [GitHub/antononcube](https://github.com/antononcube). 

[AAp2] Anton Antonov, [Proc::ZMQed, Raku package](https://github.com/antononcube/Raku-Proc-ZMQed), (2022), [GitHub/antononcube](https://github.com/antononcube).

### Videos

[AAv1] Anton Antonov, ["Using Wolfram Engine in Raku sessions"], video presentation, (2022), [YouTube/@AAA4prediction](https://www.youtube.com/@AAA4prediction).
