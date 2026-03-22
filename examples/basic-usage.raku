#!/usr/bin/env raku
use v6.d;
use LaTeX::Grammar;
use Data::Reshapers;

my @formulas = (
'\\int _{0} ^{1} x^{2} d x',
'\\sum_{n=1}^{10} n^2',
'\\lim_{x\to0} \\frac{\\sin(x)}{x}',
);
my @targets = <AsciiMath WL MathJSON MathML>;

my @res = do for @formulas -> $fm {
    [Formula => $fm, |@targets.map({ $_ => latex-interpret($fm, actions => $_) })].Hash
}

say to-pretty-table(@res, field-names => ['Formula', |@targets], align => 'l');
