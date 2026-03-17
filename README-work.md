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