use v6.d;

use LaTeX::Actions::MathJSON;

class LaTeX::Actions::AsciiMath is LaTeX::Actions::MathJSON {

    my constant %BIN-OPS = (
        Add => '+',
        Subtract => '-',
        Multiply => '*',
        Divide => '/',
        Rational => '/',
        Equal => '=',
        Less => '<',
        Greater => '>',
        LessEqual => '<=',
        GreaterEqual => '>=',
    );

    my constant %FUNC-MAP = (
        Sin => 'sin',
        Cos => 'cos',
        Tan => 'tan',
        Csc => 'csc',
        Sec => 'sec',
        Cot => 'cot',
        Arcsin => 'arcsin',
        Arccos => 'arccos',
        Arctan => 'arctan',
        Arccsc => 'arccsc',
        Arcsec => 'arcsec',
        Arccot => 'arccot',
        Sinh => 'sinh',
        Cosh => 'cosh',
        Tanh => 'tanh',
        Arsinh => 'arsinh',
        Arcosh => 'arcosh',
        Artanh => 'artanh',
        Log => 'log',
        Ln => 'ln',
    );

    method TOP($/) {
        my $ast = LaTeX::Actions::MathJSON.TOP($/);

        make self!node($ast);
    }

    method !node($x) {
        return $x.Str if $x ~~ Int || $x ~~ Rat || $x ~~ Num;
        return $x if $x ~~ Str;
        return '' unless $x ~~ Positional && $x.elems > 0;

        my $head = $x[0];

        if $head ~~ Str && %BIN-OPS{$head}.defined && $x.elems >= 3 {
            my $lhs = self!wrap-term($x[1]);
            my $rhs = self!wrap-term($x[2]);
            return "$lhs" ~ %BIN-OPS{$head} ~ "$rhs";
        }

        given $head {
            when 'Power' {
                return self!wrap-term($x[1]) ~ '^' ~ self!wrap-script($x[2]);
            }
            when 'Subscript' {
                return self!wrap-term($x[1]) ~ '_' ~ self!wrap-script($x[2]);
            }
            when 'Root' {
                my $radicand = self!node($x[1]);
                my $deg = $x[2];
                return $deg ~~ Int && $deg == 2
                    ?? "sqrt(" ~ $radicand ~ ")"
                    !! "root(" ~ self!node($deg) ~ ")(" ~ $radicand ~ ")";
            }
            when 'Negate' {
                return '-' ~ self!wrap-term($x[1]);
            }
            when 'Factorial' {
                return self!wrap-term($x[1]) ~ '!';
            }
            when 'Abs' {
                return '|' ~ self!node($x[1]) ~ '|';
            }
            when 'Apply' {
                my $name = $x[1].Str;
                my $args = self!node($x[2]);
                return $name ~ '(' ~ $args ~ ')';
            }
            when 'Sequence' {
                return $x[1..*].map({ self!node($_) }).join(',');
            }
            when 'DifferentialD' {
                return 'd' ~ self!node($x[1]);
            }
            when 'Integrate' {
                return self!integral($x);
            }
            when 'Sum' {
                return self!sum-or-product($x, 'sum');
            }
            when 'Product' {
                return self!sum-or-product($x, 'prod');
            }
            when 'Limit' {
                return self!limit($x);
            }
            when 'Log' {
                return do if $x.elems == 2 {
                    'log(' ~ self!node($x[1]) ~ ')'
                } else {
                    'log_' ~ self!node($x[2]) ~ '(' ~ self!node($x[1]) ~ ')'
                }
            }
            when $head ~~ Str && %FUNC-MAP{$head}.defined {
                return %FUNC-MAP{$head} ~ '(' ~ self!node($x[1]) ~ ')';
            }
            when 'Approach' {
                return self!node($x[1]) ~ '->' ~ self!node($x[2]);
            }
            default {
                return $head.Str ~ '(' ~ $x[1..*].map({ self!node($_) }).join(',') ~ ')';
            }
        }
    }

    method !integral($x) {
        my $body = self!node($x[1]);
        my $tuple = $x[2];

        my ($var, $lower, $upper) = (Any, Any, Any);
        if $tuple ~~ Positional && $tuple.elems == 4 && $tuple[0] eq 'Tuple' {
            ($var, $lower, $upper) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        my $res = 'int';
        $res ~= '_(' ~ self!node($lower) ~ ')' if $lower.defined;
        $res ~= '^(' ~ self!node($upper) ~ ')' if $upper.defined;
        $res ~= ' ' ~ $body;
        $res ~= ' d' ~ self!node($var) if $var.defined;

        $res;
    }

    method !sum-or-product($x, Str:D $op) {
        my $body = self!node($x[1]);
        my $tuple = $x[2];

        my ($var, $start, $limit) = (Any, Any, Any);
        if $tuple ~~ Positional && $tuple.elems == 4 && $tuple[0] eq 'Tuple' {
            ($var, $start, $limit) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        my $res = $op;
        $res ~= '_(' ~ self!node($var) ~ '=' ~ self!node($start) ~ ')' if $var.defined && $start.defined;
        $res ~= '^(' ~ self!node($limit) ~ ')' if $limit.defined;
        $res ~= ' ' ~ $body;

        $res;
    }

    method !limit($x) {
        my $body = self!node($x[1]);
        my $spec = $x[2];

        my $res = 'lim';
        if $spec ~~ Positional && $spec.elems >= 4 && $spec[0] eq 'Approach' {
            $res ~= '_(' ~ self!node($spec[1]) ~ '->' ~ self!node($spec[2]) ~ ')';
        } elsif $spec.defined {
            $res ~= '_(' ~ self!node($spec) ~ ')';
        }

        $res ~ ' ' ~ $body;
    }

    method !wrap-term($x) {
        my $s = self!node($x);
        my $needs = $x ~~ Positional && $x.elems > 0 && $x[0] ~~ Str && $x[0] eq any(<Add Subtract Equal Less Greater LessEqual GreaterEqual>);
        $needs ?? '(' ~ $s ~ ')' !! $s;
    }

    method !wrap-script($x) {
        my $s = self!node($x);
        my $simple = $x ~~ Str || $x ~~ Int || $x ~~ Rat || $x ~~ Num;
        $simple ?? $s !! '(' ~ $s ~ ')';
    }
}
