use v6.d;

use LaTeX::Actions::MathJSON;

class LaTeX::Actions::WL {

    my constant %BIN-OPS = (
        Add => '+',
        Subtract => '-',
        Multiply => '*',
        Divide => '/',
        Equal => '==',
        Less => '<',
        Greater => '>',
        LessEqual => '<=',
        GreaterEqual => '>=',
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

        if $head ~~ Str && %BIN-OPS{$head}.defined && $x.elems >= 3 {
            my $lhs = self!wrap-term($x[1]);
            my $rhs = self!wrap-term($x[2]);
            return "$lhs" ~ %BIN-OPS{$head} ~ "$rhs";
        }

        given $head {
            when 'Power' {
                return self!wrap-term($x[1]) ~ '^' ~ self!wrap-power($x[2]);
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
                return '-' ~ self!wrap-term($x[1]);
            }
            when 'Factorial' {
                return self!wrap-term($x[1]) ~ '!';
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

    method !wrap-term($x) {
        my $s = self!node($x);
        my $needs = $x ~~ Positional && $x.elems > 0 && $x[0] ~~ Str && $x[0] eq any(<Add Subtract Equal Less Greater LessEqual GreaterEqual>);
        $needs ?? '(' ~ $s ~ ')' !! $s;
    }

    method !wrap-power($x) {
        my $s = self!node($x);
        my $simple = $x ~~ Str || $x ~~ Int || $x ~~ Rat || $x ~~ Num;
        $simple ?? $s !! '(' ~ $s ~ ')';
    }
}
