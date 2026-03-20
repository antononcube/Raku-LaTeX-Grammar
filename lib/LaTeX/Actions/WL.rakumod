use v6.d;

use LaTeX::Actions::MathJSON;

class LaTeX::Actions::WL {

    my constant %BIN-FUNC = (
        Add => 'Plus',
        Multiply => 'Times',
        Equal => 'Equal',
        Less => 'Less',
        Greater => 'Greater',
        LessEqual => 'LessEqual',
        GreaterEqual => 'GreaterEqual',
    );

    my constant %FUNC-MAP = (
        Sin => 'Sin',
        Cos => 'Cos',
        Tan => 'Tan',
        Csc => 'Csc',
        Sec => 'Sec',
        Cot => 'Cot',
        Arcsin => 'ArcSin',
        Arccos => 'ArcCos',
        Arctan => 'ArcTan',
        Arccsc => 'ArcCsc',
        Arcsec => 'ArcSec',
        Arccot => 'ArcCot',
        Sinh => 'Sinh',
        Cosh => 'Cosh',
        Tanh => 'Tanh',
        Arsinh => 'ArcSinh',
        Arcosh => 'ArcCosh',
        Artanh => 'ArcTanh',
        Log => 'Log',
        Ln => 'Log',
    );

    method TOP($/) {
        my $mathjson-actions = LaTeX::Actions::MathJSON.new;
        $mathjson-actions.TOP($/);
        my $ast = $/.made;

        make self!node($ast);
    }

    method !node($x) {
        return $x.Str if $x ~~ Int || $x ~~ Rat || $x ~~ Num;
        return $x if $x ~~ Str;
        return '' unless $x ~~ Positional && $x.elems > 0;

        my $head = $x[0];

        if $head ~~ Str && $x.elems >= 3 {
            my $lhs = self!node($x[1]);
            my $rhs = self!node($x[2]);

            return %BIN-FUNC{$head} ~ '[' ~ $lhs ~ ',' ~ $rhs ~ ']' if %BIN-FUNC{$head}.defined;
            return 'Plus[' ~ $lhs ~ ',Times[-1,' ~ $rhs ~ ']]' if $head eq 'Subtract';
            return 'Rational[' ~ $lhs ~ ',' ~ $rhs ~ ']' if $head eq 'Divide';
        }

        given $head {
            when 'Power' {
                return 'Power[' ~ self!node($x[1]) ~ ',' ~ self!node($x[2]) ~ ']';
            }
            when 'Subscript' {
                return 'Subscript[' ~ self!node($x[1]) ~ ',' ~ self!node($x[2]) ~ ']';
            }
            when 'Root' {
                my $radicand = self!node($x[1]);
                my $deg = $x[2];
                return $deg ~~ Int && $deg == 2
                    ?? 'Sqrt[' ~ $radicand ~ ']'
                    !! 'Surd[' ~ $radicand ~ ',' ~ self!node($deg) ~ ']';
            }
            when 'Negate' {
                return 'Times[-1,' ~ self!node($x[1]) ~ ']';
            }
            when 'Factorial' {
                return 'Factorial[' ~ self!node($x[1]) ~ ']';
            }
            when 'Abs' {
                return 'Abs[' ~ self!node($x[1]) ~ ']';
            }
            when 'Apply' {
                my $name = $x[1].Str;
                my $args = self!node($x[2]);
                return $name ~ '[' ~ $args ~ ']';
            }
            when 'Sequence' {
                return $x[1..*].map({ self!node($_) }).join(',');
            }
            when 'DifferentialD' {
                return 'DifferentialD[' ~ self!node($x[1]) ~ ']';
            }
            when 'Integrate' {
                return self!integral($x);
            }
            when 'Sum' {
                return self!sum-or-product($x, 'Sum');
            }
            when 'Product' {
                return self!sum-or-product($x, 'Product');
            }
            when 'Limit' {
                return self!limit($x);
            }
            when $head ~~ Str && %FUNC-MAP{$head}.defined {
                return %FUNC-MAP{$head} ~ '[' ~ self!node($x[1]) ~ ']';
            }
            when 'Approach' {
                return self!node($x[1]) ~ '->' ~ self!node($x[2]);
            }
            default {
                return $head.Str ~ '[' ~ $x[1..*].map({ self!node($_) }).join(',') ~ ']';
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

        return 'Integrate[' ~ $body ~ ']' unless $var.defined;
        return 'Integrate[' ~ $body ~ ',{' ~ self!node($var) ~ ',' ~ self!node($lower) ~ ',' ~ self!node($upper) ~ '}]'
            if $lower.defined && $upper.defined;

        'Integrate[' ~ $body ~ ',' ~ self!node($var) ~ ']';
    }

    method !sum-or-product($x, Str:D $op) {
        my $body = self!node($x[1]);
        my $tuple = $x[2];

        my ($var, $start, $limit) = (Any, Any, Any);
        if $tuple ~~ Positional && $tuple.elems == 4 && $tuple[0] eq 'Tuple' {
            ($var, $start, $limit) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        return $op ~ '[' ~ $body ~ ']' unless $var.defined;
        return $op ~ '[' ~ $body ~ ',{' ~ self!node($var) ~ ',' ~ self!node($start) ~ ',' ~ self!node($limit) ~ '}]'
            if $start.defined && $limit.defined;

        $op ~ '[' ~ $body ~ ',' ~ self!node($var) ~ ']';
    }

    method !limit($x) {
        my $body = self!node($x[1]);
        my $spec = $x[2];

        if $spec ~~ Positional && $spec.elems >= 4 && $spec[0] eq 'Approach' {
            return 'Limit[' ~ $body ~ ',' ~ self!node($spec[1]) ~ '->' ~ self!node($spec[2]) ~ ']';
        }

        return 'Limit[' ~ $body ~ ']' unless $spec.defined;
        'Limit[' ~ $body ~ ',' ~ self!node($spec) ~ ']';
    }

}
