# LaTeX::Grammar

Raku package with a parser and interpreters of LaTeX code.
The implemented interpretation formats are:

- [MathJSON](https://mathlive.io/math-json/)
- [MathML](https://www.w3.org/TR/mathml4/), [Wikipedia](https://en.wikipedia.org/wiki/MathML)
- [AsciiMath](https://asciimath.org), [Wikipedia](https://en.wikipedia.org/wiki/AsciiMath)
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
# ["Equal",["Divide",1,"x"],["Root","y",2]]
```

A table that show interpretations to different formats:

```raku, results=asis
use Data::Translators;

my @formulas = (
'\\sqrt{4 * x^2 + 12 * x + 9}',
'\\int_{0}^{1} x^{2} d x',
'\\sum_{n=1}^{10} n^2',
'\\lim_{x\\to0} \\frac{\\sin(x)}{x}',
);
my @targets = <AsciiMath WL MathJSON>;

my @res = do for @formulas -> $fm {
    [LaTeX => $fm, MathML => "latex«$fm»", |@targets.map({ $_ => latex-interpret($fm, actions => $_) })].Hash
}

@res 
==> to-html(field-names => ['LaTeX', 'MathML', |@targets], align => 'left')
==> { .subst(/ 'latex«' (.*?) '»' /, { latex-interpret($0.Str, actions => 'MathML')}, :g) }()
==> { .subst('"', :g) }()
```
<table border=1><thead><tr><th>LaTeX</th><th>MathML</th><th>AsciiMath</th><th>WL</th><th>MathJSON</th></tr></thead><tbody><tr><td align=left>\sqrt{4 * x^2 + 12 * x + 9}</td><td align=left><math xmlns=\http://www.w3.org/1998/Math/MathML\><msqrt><mrow><mrow><mrow><mn>4</mn><mo>&#xD7;</mo><msup><mi>x</mi><mn>2</mn></msup></mrow><mo>+</mo><mrow><mn>12</mn><mo>&#xD7;</mo><mi>x</mi></mrow></mrow><mo>+</mo><mn>9</mn></mrow></msqrt></math></td><td align=left>&quot;sqrt((4*x^2+12*x)+9)&quot;</td><td align=left>&quot;Sqrt[Plus[Plus[Times[4,Power[x,2]],Times[12,x]],9]]&quot;</td><td align=left>[&quot;Root&quot;,[&quot;Add&quot;,[&quot;Add&quot;,[&quot;Multiply&quot;,4,[&quot;Power&quot;,&quot;x&quot;,2]],[&quot;Multiply&quot;,12,&quot;x&quot;]],9],2]</td></tr><tr><td align=left>\int_{0}^{1} x^{2} d x</td><td align=left><math xmlns=\http://www.w3.org/1998/Math/MathML\><mrow><msubsup><mo>&#x222B;</mo><mn>0</mn><mn>1</mn></msubsup><msup><mi>x</mi><mn>2</mn></msup><mrow><mo>d</mo><mi>x</mi></mrow></mrow></math></td><td align=left>&quot;int x^2&quot;</td><td align=left>&quot;Integrate[Power[x,2],{x,0,1}]&quot;</td><td align=left>[&quot;Integrate&quot;,[&quot;Function&quot;,[&quot;Block&quot;,[&quot;Power&quot;,&quot;x&quot;,2]],&quot;x&quot;],[&quot;Limits&quot;,&quot;x&quot;,0,1]]</td></tr><tr><td align=left>\sum_{n=1}^{10} n^2</td><td align=left><math xmlns=\http://www.w3.org/1998/Math/MathML\><mrow><msubsup><mo>&#x2211;</mo><mrow><mi>n</mi><mo>=</mo><mn>1</mn></mrow><mn>10</mn></msubsup><msup><mi>n</mi><mn>2</mn></msup></mrow></math></td><td align=left>&quot;sum n^2&quot;</td><td align=left>&quot;Sum[Power[n,2],{n,1,10}]&quot;</td><td align=left>[&quot;Sum&quot;,[&quot;Power&quot;,&quot;n&quot;,2],[&quot;Limits&quot;,&quot;n&quot;,1,10]]</td></tr><tr><td align=left>\lim_{x\to0} \frac{\sin(x)}{x}</td><td align=left><math xmlns=\http://www.w3.org/1998/Math/MathML\><mrow><munder><mi>lim</mi><mrow><mi>x</mi><mo>&#x2192;</mo><mn>0</mn></mrow></munder><mfrac><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow><mi>x</mi></mfrac></mrow></math></td><td align=left>&quot;lim_(x-&gt;0) sin(x)/x&quot;</td><td align=left>&quot;Limit[Times[ Sin[x] , Power[x, -1]],x-&gt;0]&quot;</td><td align=left>[&quot;Limit&quot;,[&quot;Function&quot;,[&quot;Block&quot;,[&quot;Divide&quot;,[&quot;Sin&quot;,&quot;x&quot;],&quot;x&quot;]],&quot;x&quot;],0]</td></tr></tbody></table>


-----

## CLI

The package provides Command Line Interface (CLI) script. Here is usage message:

```shell
from-latex --help
```
```
# Usage:
#   from-latex <text> [-t|--format|--to=<Str>] [-o|--output=<Str>] -- Converts LaTeX code or files into AsciiMath, MathJSON, MathML, Mathematica, or Raku files.
#   
#     <text>                    Input file or LaTeX spec.
#     -t|--format|--to=<Str>    Language to translate to. (One of 'asciimath', 'mathjson', 'mathml', 'mathematica', 'raku', or 'Whatever'.) [default: 'Whatever']
#     -o|--output=<Str>         Output file; if an empty string then the result is printed to stdout. [default: '']
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
  - [ ] TODO Raku actions (using RakuAST)
    - The MathJSON interpreter does give Raku expressions (arrays)
    - But the idea is to make Raku expressions from LaTeX using RakuAST
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
