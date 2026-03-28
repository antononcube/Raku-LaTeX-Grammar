use v6.d;

use LaTeX::Actions::MathJSON;
use LaTeX::Actions::MathJSON-ad-hoc;

class LaTeX::Actions::MathML is LaTeX::Actions::MathJSON {

    my constant %BIN-OPS = (
        Add => '+',
        Subtract => '-',
        Multiply => '&#xD7;',
        Divide => '/',
        Rational => '/',
        Equal => '=',
        Less => '&lt;',
        Greater => '&gt;',
        LessEqual => '&#x2264;',
        GreaterEqual => '&#x2265;',
    );

    method TOP($/) {
        my $ast = LaTeX::Actions::MathJSON.TOP($/);

        make '<math xmlns="http://www.w3.org/1998/Math/MathML">' ~ self!node($ast) ~ '</math>';
    }

    method !node($x) {
        return self!mn($x) if $x ~~ Numeric:D; # $x ~~ Int:D || $x ~~ Rat:D || $x ~~ Num;
        return self!mi($x) if $x ~~ Str:D;

        return '<mtext></mtext>' unless $x ~~ Positional && $x.elems > 0;

        my $head = $x[0];

        if $head ~~ Str:D && %BIN-OPS{$head}.defined && $x.elems >= 3 {
            if $head ∈ <Divide Rational> {
                return '<mfrac>' ~ self!node($x[1]) ~ self!node($x[2]) ~ '</mfrac>';
            } else {
                return self!mrow(self!node($x[1]), self!mo(%BIN-OPS{$head}), self!node($x[2]));
            }
        }

        given $head {
            when 'Power' {
                return '<msup>' ~ self!node($x[1]) ~ self!node($x[2]) ~ '</msup>';
            }
            when 'Subscript' {
                return '<msub>' ~ self!node($x[1]) ~ self!node($x[2]) ~ '</msub>';
            }
            when 'Root' {
                my $base = self!node($x[1]);
                my $deg = $x[2];
                return $deg ~~ Int && $deg == 2
                    ?? '<msqrt>' ~ $base ~ '</msqrt>'
                    !! '<mroot>' ~ $base ~ self!node($deg) ~ '</mroot>';
            }
            when 'Negate' {
                return self!mrow(self!mo('-'), self!node($x[1]));
            }
            when 'Factorial' {
                return self!mrow(self!node($x[1]), self!mo('!'));
            }
            when 'Abs' {
                return self!mrow(self!mo('|'), self!node($x[1]), self!mo('|'));
            }
            when 'Apply' {
                my $name = self!mi($x[1].Str);
                my $arg = self!node($x[2]);
                return self!mrow($name, self!mo('('), $arg, self!mo(')'));
            }
            when 'Sequence' {
                my @parts = $x[1..*].map({ self!node($_) });
                return self!join-with-op(@parts, ',');
            }
            when 'DifferentialD' {
                return self!mrow(self!mo('d'), self!mi($x[1].Str));
            }
            when 'Integrate' {
                return self!integral($x);
            }
            when 'Sum' {
                return self!sum-or-product($x, '&#x2211;');
            }
            when 'Product' {
                return self!sum-or-product($x, '&#x220F;');
            }
            when 'Limit' {
                return self!limit($x);
            }
            when 'Log' {
                my $fname = $head.lc;
                return do if $x.elems == 2 {
                    self!mrow(self!mi($fname), self!mo('('), self!node($x[1]), self!mo(')'))
                } else {
                    self!mrow('<msub>' ~ self!mi($fname) ~ self!node($x[2]) ~ '</msub>', self!mo('('), self!node($x[1]), self!mo(')'))
                }
            }
            when /^(Sin|Cos|Tan|Csc|Sec|Cot|Arcsin|Arccos|Arctan|Arccsc|Arcsec|Arccot|Sinh|Cosh|Tanh|Arsinh|Arcosh|Artanh)$/ {
                my $fname = $head.lc;
                return self!mrow(self!mi($fname), self!mo('('), self!node($x[1]), self!mo(')'));
            }
            default {
                return self!mi($head.Str);
            }
        }
    }

    method !integral($x) {
        my $body = self!node($x[1]);
        my $tuple = $x[2];

        my ($var, $lower, $upper) = (Any, Any, Any);
        if $tuple ~~ Positional && $tuple.elems == 4 && $tuple[0] eq 'Limits' {
            ($var, $lower, $upper) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        my $int = self!bounded-op('&#x222B;', $lower, $upper);
        my $dvar = $var.defined ?? self!mrow(self!mo('d'), self!node($var)) !! '<mtext></mtext>';

        self!mrow($int, $body, $dvar);
    }

    method !sum-or-product($x, Str:D $sym) {
        my $body = self!node($x[1]);
        my $tuple = $x[2];

        my ($var, $start, $limit) = (Any, Any, Any);
        if $tuple ~~ Positional:D && $tuple.elems == 4 && $tuple[0] eq 'Limits' {
            ($var, $start, $limit) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        my $lower = ($var.defined && $start.defined)
            ?? self!mrow(self!node($var), self!mo('='), self!node($start))
            !! Any;

        my $op = self!bounded-op($sym, $lower, $limit);
        self!mrow($op, $body);
    }

    method !limit($x) {
        my $body = self!node($x[1]);
        my $spec = $x[2];

        my $under = do if $spec ~~ Positional && $spec.elems >= 4 && $spec[0] eq 'Approach' {
            self!mrow(self!node($spec[1]), self!mo('&#x2192;'), self!node($spec[2]));
        } elsif $spec.defined {
            self!node($spec);
        } else {
            Any;
        };

        my $lim = $under.defined
            ?? '<munder>' ~ self!mi('lim') ~ $under ~ '</munder>'
            !! self!mi('lim');

        self!mrow($lim, $body);
    }

    method !bounded-op(Str:D $sym, $lower, $upper) {
        my $op = $sym.starts-with('<mo>') ?? $sym !! self!mo($sym);

        my $lower2 = Any;
        with $lower {
            $lower2 = $lower ~~ / ^ '<mi>' | '<mn>' /  ?? $lower !! self!node($lower);
        }

        my $upper2 = Any;
        with $upper {
            $upper2 = $upper ~~ / ^ '<mi>' | '<mn>' / ?? $upper !! self!node($upper);
        }

        return '<msubsup>' ~ $op ~ $lower2 ~ $upper2 ~ '</msubsup>' if $lower.defined && $upper.defined;
        return '<msub>' ~ $op ~ $lower2 ~ '</msub>' if $lower.defined;
        return '<msup>' ~ $op ~ $upper2 ~ '</msup>' if $upper.defined;

        $op;
    }

    method !join-with-op(@nodes, Str:D $op) {
        return '<mtext></mtext>' unless @nodes.elems;
        my @flat;
        for @nodes.kv -> $i, $n {
            @flat.push: $n;
            @flat.push: self!mo($op) if $i < @nodes.end;
        }
        self!mrow(|@flat);
    }

    method !mi(Str:D $s) {
        '<mi>' ~ self!escape($s) ~ '</mi>';
    }

    method !mn($n) {
        '<mn>' ~ self!escape($n.Str) ~ '</mn>';
    }

    method !mo(Str:D $s) {
        '<mo>' ~ $s ~ '</mo>';
    }

    method !mrow(*@parts) {
        '<mrow>' ~ @parts.join('') ~ '</mrow>';
    }

    method !escape(Str:D $s) {
        $s
            .subst('&', '&amp;', :g)
            .subst('<', '&lt;', :g)
            .subst('>', '&gt;', :g)
            .subst('"', '&quot;', :g)
            .subst("'", '&apos;', :g);
    }
}
