
```raku, results=asis
use LaTeX::Grammar;
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
my @targets = <AsciiMath WL MathML>;

my @res = do for @formulas -> $fm {
    [
     LaTeX => $fm, 
     RakuAST => latex-interpret($fm, actions => 'RakuAST').DEPARSE,
     MathJSON => latex-interpret($fm, actions => 'MathJSON').raku,
     |@targets.map({ $_ => latex-interpret($fm, actions => $_) })
    ].Hash
}

@res 
==> { .&to-long-format(id-columns => 'LaTeX', variables-to => 'Format', values-to => 'Translation') }()
==> { group-by($_, 'LaTeX')}()
==> { $_.map({ %(LaTeX => $_.key, Translations => to-html($_.value.sort(*<Format>), field-names => <Format Translation>, align => 'left').subst(/'<thead>' .*? '</thead>'/, :g) ) }) }()
==> { .&to-html(field-names => <LaTeX Translations>) }()
```