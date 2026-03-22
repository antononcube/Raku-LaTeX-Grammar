# LaTeX::Grammar

Raku package with a parser and interpreters of LaTeX code

------

## Installation

From [Zef ecosystem](https://raku.land):

```
zef install LaTeX::Grammar
```

------

## Usage examples

```raku
use LaTeX::Grammar;

latex-interpret('\frac{1}{x}=\sqrt{y}')
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
  - [ ] TODO MathJSON actions
    - First, reasonably well working version.
    - Some cases to do not work.
      - This works    : `\int _{0} ^{1} x^{2} d x`
      - This does not work : `\int_{0}^{1} x^{2} d x`
    - I assume because of the rule-based grammar.
       - Should have been regex-based
    - The generated [MathJSON is CortexJS-style](https://mathlive.io/math-json/), but a simpler version might be better.
       - For example, 
         - LaTeX: `\int_{0}^{1}x^{2}dx`
         - CortexJS: `["Integrate",["Function",["Block",["Power","x",2]],"x"],["Limits","x",0,1]]`
         - Simpler: `["Integrate",["Power","x",2],["Limits","x",0,1]]`
  - [X] DONE MathML actions
    - Based on MathJSON.
  - [X] DONE AsciiMath actions
    - Based on MathJSON.
  - [X] DONE Wolfram Language (WL) actions
    - Based on MathJSON.

