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
```
# [Equal [Divide 1 x] [Root y 2]]
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
    [LaTeX => $fm, MathML => "latex«$fm»", |@targets.map({ $_ => latex-interpret($fm, actions => $_).raku })].Hash
}

@res 
==> { .&to-long-format(id-columns => 'LaTeX', variables-to => 'Format', values-to => 'Translation') }()
==> { group-by($_, 'LaTeX').map({ $_.value.sort(*<LaTeX Format>).kv.map(-> $i, %r { %r<LaTeX> ='' if $i; %r }) }) }()
==> { $_.flat(1) }()
==> to-html(field-names => <LaTeX Format Translation>, align => 'left')
==> { .subst(/ 'latex«' (.*?) '»' /, { latex-interpret($0.Str, actions => 'MathML')}, :g) }()
==> { .subst(/ '"' | '&quot;' /, :g).subst('\{', '{', :g) }()
```
<table border=1><thead><tr><th>LaTeX</th><th>Format</th><th>Translation</th></tr></thead><tbody><tr><td align=left>\sqrt{4 * x^2 + 12 * x + 9}</td><td align=left>AsciiMath</td><td align=left>sqrt((4*x^2+12*x)+9)</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Root, [Add, [Add, [Multiply, 4, [Power, x, 2]], [Multiply, 12, x]], 9], 2]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><msqrt><mrow><mrow><mrow><mn>4</mn><mo>&#xD7;</mo><msup><mi>x</mi><mn>2</mn></msup></mrow><mo>+</mo><mrow><mn>12</mn><mo>&#xD7;</mo><mi>x</mi></mrow></mrow><mo>+</mo><mn>9</mn></mrow></msqrt></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Sqrt[Plus[Plus[Times[4,Power[x,2]],Times[12,x]],9]]</td></tr><tr><td align=left>\log\left( \frac{x+1}{x-1} \right)</td><td align=left>AsciiMath</td><td align=left>log((x+1)/(x-1))</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Log, [Divide, [Add, x, 1], [Subtract, x, 1]]]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mrow><mi>log</mi><mo>(</mo><mfrac><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow><mrow><mi>x</mi><mo>-</mo><mn>1</mn></mrow></mfrac><mo>)</mo></mrow></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Log[Rational[Plus[x,1],Plus[x,Times[-1,1]]]]</td></tr><tr><td align=left>\sum_{n=1}^{10} n^2</td><td align=left>AsciiMath</td><td align=left>sum_(n=1)^(10) n^2</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Sum, [Power, n, 2], [Limits, n, 1, 10]]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mrow><msubsup><mo>&#x2211;</mo><mrow><mi>n</mi><mo>=</mo><mn>1</mn></mrow><mn>10</mn></msubsup><msup><mi>n</mi><mn>2</mn></msup></mrow></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Sum[Power[n,2],{n,1,10}]</td></tr><tr><td align=left>\int_{0}^{1} x^{2} d x</td><td align=left>AsciiMath</td><td align=left>int_(0)^(1) x^2 dx</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Integrate, [Function, [Block, [Power, x, 2]], x], [Limits, x, 0, 1]]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mrow><msubsup><mo>&#x222B;</mo><mn>0</mn><mn>1</mn></msubsup><msup><mi>x</mi><mn>2</mn></msup><mrow><mo>d</mo><mi>x</mi></mrow></mrow></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Integrate[Power[x,2],{x,0,1}]</td></tr><tr><td align=left>\log_{5} x</td><td align=left>AsciiMath</td><td align=left>log_5(x)</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Log, x, 5]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mrow><msub><mi>log</mi><mn>5</mn></msub><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Log[5,x]</td></tr><tr><td align=left>\frac{-1214}{117}</td><td align=left>AsciiMath</td><td align=left>-1214/117</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Rational, -1214, 117]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mfrac><mn>-1214</mn><mn>117</mn></mfrac></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Rational[-1214,117]</td></tr><tr><td align=left>\lim_{x\to0} \frac{\sin(x)}{x}</td><td align=left>AsciiMath</td><td align=left>lim_(x-&gt;0) sin(x)/x</td></tr><tr><td align=left></td><td align=left>MathJSON</td><td align=left>$[Limit, [Function, [Block, [Divide, [Sin, x], x]], x], 0]</td></tr><tr><td align=left></td><td align=left>MathML</td><td align=left><math xmlns=http://www.w3.org/1998/Math/MathML><mrow><munder><mi>lim</mi><mrow><mi>x</mi><mo>&#x2192;</mo><mn>0</mn></mrow></munder><mfrac><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow><mi>x</mi></mfrac></mrow></math></td></tr><tr><td align=left></td><td align=left>WL</td><td align=left>Limit[Times[ Sin[x] , Power[x, -1]],x-&gt;0]</td></tr></tbody></table>


See also the Jupyter notebook ["Basic-usage.ipynb"](./docs/Basic-usage.ipynb).

Translating LaTeX to RakuAST:

```raku
latex-interpret('\sum_{n=1}^{10} n^2', actions => 'RakuAST').DEPARSE
```
```
# [+] (1 .. 10).map(-> $n! { ($n ** 2) })
```


-----

## CLI

The package provides Command Line Interface (CLI) script. Here is usage message:

```shell
from-latex --help
```
```
# Usage:
#   from-latex <text> [-t|--actions|--to=<Str>] [-f|--format=<Str>] [-o|--output=<Str>] -- Converts LaTeX code or files into AsciiMath, MathJSON, MathML, Mathematica, or Raku files.
#   
#     <text>                     Input file or LaTeX spec.
#     -t|--actions|--to=<Str>    Language to translate to. (One of 'asciimath', 'mathjson', 'mathml', 'mathematica', 'raku', 'rakuast', 'wolfram', or 'Whatever'.) [default: 'Whatever']
#     -f|--format=<Str>          Format of the result. (One of 'ast', 'json', 'raku', or 'Whatever'.) [default: 'Whatever']
#     -o|--output=<Str>          Output file; if an empty string then the result is printed to stdout. [default: '']
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
