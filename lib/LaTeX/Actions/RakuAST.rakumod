use v6.d;
use experimental :rakuast;

use LaTeX::Actions::MathJSON;

class LaTeX::Actions::RakuAST is LaTeX::Actions::MathJSON {

    my constant %FUNC-MAP = (
        Sin => 'sin',
        Cos => 'cos',
        Tan => 'tan',
        Csc => 'csc',
        Sec => 'sec',
        Cot => 'cot',
        Arcsin => 'asin',
        Arccos => 'acos',
        Arctan => 'atan',
        Arccsc => 'acsc',
        Arcsec => 'asec',
        Arccot => 'acot',
        Sinh => 'sinh',
        Cosh => 'cosh',
        Tanh => 'tanh',
        Arsinh => 'asinh',
        Arcosh => 'acosh',
        Artanh => 'atanh',
        Log => 'log',
        Ln => 'log',
    );

    method TOP($/) {
        my $mathjson = LaTeX::Actions::MathJSON.TOP($/);
        my $source = self!to-source($mathjson);
        my $ast = $source.AST;
        make self!extract-expression($ast);
    }

    method !extract-expression($ast) {
        return $ast unless $ast.^name eq 'RakuAST::StatementList';
        return $ast if !$ast.can('statements') || $ast.statements.elems != 1;

        my $stmt = $ast.statements[0];
        $stmt.can('expression') ?? $stmt.expression !! $ast;
    }

    method !to-source($x) {
        if $x ~~ Int:D || $x ~~ Rat:D || $x ~~ Num:D {
            return $x.Str;
        }
        if $x ~~ Str:D {
            return self!as-variable($x);
        }
        return 'Any' unless $x ~~ Positional:D && $x.elems > 0;

        my $head = $x[0];

        if $head ~~ Str:D && $x.elems >= 3 {
            my $lhs = self!to-source($x[1]);
            my $rhs = self!to-source($x[2]);
            return "($lhs + $rhs)" if $head eq 'Add';
            return "($lhs - $rhs)" if $head eq 'Subtract';
            return "($lhs * $rhs)" if $head eq 'Multiply';
            return "($lhs / $rhs)" if $head eq 'Divide' || $head eq 'Rational';
            return "($lhs == $rhs)" if $head eq 'Equal';
            return "($lhs < $rhs)" if $head eq 'Less';
            return "($lhs > $rhs)" if $head eq 'Greater';
            return "($lhs <= $rhs)" if $head eq 'LessEqual';
            return "($lhs >= $rhs)" if $head eq 'GreaterEqual';
        }

        given $head {
            when 'Power'      { return '(' ~ self!to-source($x[1]) ~ ' ** ' ~ self!to-source($x[2]) ~ ')' }
            when 'Subscript'  { return self!call-by-name('subscript', self!to-source($x[1]), self!to-source($x[2])) }
            when 'Root'       { return self!root-source($x) }
            when 'Negate'     { return '(-' ~ self!to-source($x[1]) ~ ')' }
            when 'Factorial'  { return '(' ~ self!to-source($x[1]) ~ '!)' }
            when 'Abs'        { return 'abs(' ~ self!to-source($x[1]) ~ ')' }
            when 'Apply'      { return self!apply-source($x) }
            when 'Sequence'   { return $x[1..*].map({ self!to-source($_) }).join(', ') }
            when 'DifferentialD' { return self!call-by-name('d', self!to-source($x[1])) }
            when 'Integrate'  { return self!integral-source($x) }
            when 'Sum'        { return self!sum-or-product-source($x, 'sum') }
            when 'Product'    { return self!sum-or-product-source($x, 'product') }
            when 'Limit'      { return self!limit-source($x) }
            when 'Approach'   { return self!approach-source($x) }
            when { $head ~~ Str:D && %FUNC-MAP{$head}.defined } {
                return %FUNC-MAP{$head} ~ '(' ~ self!to-source($x[1]) ~ ')';
            }
            default {
                my $args = $x[1..*].map({ self!to-source($_) }).join(', ');
                return self!call-by-name($head.Str, |$x[1..*].map({ self!to-source($_) }));
            }
        }
    }

    method !root-source($x) {
        my $radicand = self!to-source($x[1]);
        my $deg = $x[2];
        return 'sqrt(' ~ $radicand ~ ')' if $deg ~~ Int:D && $deg == 2;
        '(' ~ $radicand ~ ' ** (1 / ' ~ self!to-source($deg) ~ '))';
    }

    method !apply-source($x) {
        my $name = self!to-source($x[1]);
        my $args = self!to-source($x[2]);
        '(' ~ $name ~ ').(' ~ $args ~ ')';
    }

    method !integral-source($x) {
        my $body = self!to-source($x[1]);
        my $tuple = $x[2];

        my ($var, $lower, $upper) = (Any, Any, Any);
        if $tuple ~~ Positional:D && $tuple.elems == 4 && $tuple[0] eq 'Limits' {
            ($var, $lower, $upper) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        return self!call-by-name('integral', $body) unless $var.defined;
        return self!call-by-name('integral', $body, self!to-source($var),
            self!to-source($lower), self!to-source($upper))
            if $lower.defined && $upper.defined;

        self!call-by-name('integral', $body, self!to-source($var));
    }

    method !sum-or-product-source($x, Str:D $op) {
        my $body = self!to-source($x[1]);
        my $tuple = $x[2];

        my ($var, $start, $limit) = (Any, Any, Any);
        if $tuple ~~ Positional:D && $tuple.elems == 4 && $tuple[0] eq 'Limits' {
            ($var, $start, $limit) = ($tuple[1], $tuple[2], $tuple[3]);
        }

        return self!call-by-name($op, $body) unless $var.defined;
        return self!call-by-name($op, $body, self!to-source($var),
            self!to-source($start), self!to-source($limit))
            if $start.defined && $limit.defined;

        self!call-by-name($op, $body, self!to-source($var));
    }

    method !limit-source($x) {
        my $body = self!to-source($x[1]);
        my $spec = $x[2];

        if $spec ~~ Positional:D && $spec.elems >= 4 && $spec[0] eq 'Approach' {
            return self!call-by-name('limit', $body, self!to-source($spec[1]),
                self!to-source($spec[2]), self!as-literal-str($spec[3]));
        }

        return self!call-by-name('limit', $body) unless $spec.defined;
        self!call-by-name('limit', $body, self!to-source($spec));
    }

    method !approach-source($x) {
        self!call-by-name('approach',
            self!to-source($x[1]),
            self!to-source($x[2]),
            self!as-literal-str($x[3]));
    }

    method !is-ident(Str:D $s --> Bool:D) {
        so ($s ~~ /^ <[A..Za..z_]> <[A..Za..z0..9_]>* $/);
    }

    method !call-by-name(Str:D $name, *@args) {
        self!symbol-ref($name) ~ '.(' ~ @args.join(', ') ~ ')';
    }

    method !symbol-ref(Str:D $s) {
        '::("' ~ self!escape-dq($s) ~ '")';
    }

    method !as-variable(Str:D $s) {
        self!symbol-ref($s);
    }

    method !as-literal-str(Str:D $s) {
        "'" ~ $s.trans(["'" => "\\'"]) ~ "'";
    }

    method !escape-dq(Str:D $s) {
        $s.trans(['\\' => '\\\\', '"' => '\\"']);
    }
}
