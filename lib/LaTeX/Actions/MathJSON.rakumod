use v6.d;

use JSON::Fast;

class LaTeX::Actions::MathJSON {
    has $.function-wrap = False;

    submethod BUILD(:$!function-wrap=False) {}

    my constant %FUNC-MAP = (
        log => 'Log',
        ln => 'Ln',
        sin => 'Sin',
        cos => 'Cos',
        tan => 'Tan',
        csc => 'Csc',
        sec => 'Sec',
        cot => 'Cot',
        arcsin => 'Arcsin',
        arccos => 'Arccos',
        arctan => 'Arctan',
        arccsc => 'Arccsc',
        arcsec => 'Arcsec',
        arccot => 'Arccot',
        sinh => 'Sinh',
        cosh => 'Cosh',
        tanh => 'Tanh',
        arsinh => 'Arsinh',
        arcosh => 'Arcosh',
        artanh => 'Artanh',
    );

    method TOP($/) {
        make $<math>.made;
    }

    method add-op($/) {
        make $/.Str eq '+' ?? 'Add' !! 'Subtract';
    }

    method mul-op($/) {
        my $op = $/.Str;
        make $op eq '*' || $op eq '\\times' || $op eq '\\cdot' ?? 'Multiply' !! 'Divide';
    }

    method rel-op($/) {
        make do given $/.Str {
            when '='     { 'Equal' }
            when '<'     { 'Less' }
            when '>'     { 'Greater' }
            when '\\leq' { 'LessEqual' }
            when '\\geq' { 'GreaterEqual' }
            default      { 'Relation' }
        }
    }

    method approach-sym($/) {
        make $/.Str;
    }

    method letter($/) {
        make $/.Str;
    }

    method symbol($/) {
        make self!strip-leading-slash($/.Str);
    }

    method number($/) {
        make $/.Str.subst(',', '', :g).Numeric;
    }

    method differential($/) {
        my $var = $<letter> ?? $<letter>.made !! $<symbol>.made;
        make [ 'DifferentialD', $var ];
    }

    method math($/) {
        make $<relation>.made;
    }

    method relation($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        my @ops = self!capture-list($/, 'rel-op').map(*.made);
        make self!process-recursive-operations(@parts, @ops);
    }

    method equality($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        make [ 'Equal', @parts[0], @parts[1] ];
    }

    method expr($/) {
        make $<additive>.made;
    }

    method additive($/) {
        my @parts = self!capture-list($/, 'mp').map(*.made);
        my @ops = self!capture-list($/, 'add-op').map(*.made);
        make self!process-recursive-operations(@parts, @ops);
    }

    method mp($/) {
        my @parts = self!capture-list($/, 'unary').map(*.made);
        my @ops = self!capture-list($/, 'mul-op').map(*.made);
        make self!process-recursive-operations(@parts, @ops);
    }

    method mp-nofunc($/) {
        my @parts = self!capture-list($/, 'unary-nofunc').map(*.made);
        my @ops = self!capture-list($/, 'mul-op').map(*.made);
        make self!process-recursive-operations(@parts, @ops);
    }

    method unary($/) {
        my @parts = self!capture-list($/, 'postfix').map(*.made);
        my @ops = 'Multiply' xx (@parts.elems - 1);
        my $res = self!process-recursive-operations(@parts, @ops);

        my $neg-count = self!capture-list($/, 'add-op').map(*.made).grep(* eq 'Subtract').elems;
        $res = [ 'Negate', $res ] if $neg-count % 2;

        make $res;
    }

    method unary-nofunc($/) {
        my @parts;
        @parts.append: self!capture-list($/, 'postfix').map(*.made);
        @parts.append: self!capture-list($/, 'postfix-nofunc').map(*.made);

        my @ops = 'Multiply' xx (@parts.elems - 1);
        my $res = self!process-recursive-operations(@parts, @ops);

        my $neg-count = self!capture-list($/, 'add-op').map(*.made).grep(* eq 'Subtract').elems;
        $res = [ 'Negate', $res ] if $neg-count % 2;

        make $res;
    }

    method postfix($/) {
        my $res = $<exp>.made;
        for self!capture-list($/, 'postfix-op').map(*.made) -> $op {
            if $op eq 'Factorial' {
                $res = [ 'Factorial', $res ];
            } elsif $op ~~ Positional && $op.elems >= 1 && $op[0] eq 'EvaluateAt' {
                $res = [ 'EvaluateAt', $res, $op[1], $op[2] ];
            }
        }
        make $res;
    }

    method postfix-nofunc($/) {
        my $res = $<exp-nofunc>.made;
        for self!capture-list($/, 'postfix-op').map(*.made) -> $op {
            if $op eq 'Factorial' {
                $res = [ 'Factorial', $res ];
            } elsif $op ~~ Positional && $op.elems >= 1 && $op[0] eq 'EvaluateAt' {
                $res = [ 'EvaluateAt', $res, $op[1], $op[2] ];
            }
        }
        make $res;
    }

    method postfix-op($/) {
        make $/.Str eq '!' ?? 'Factorial' !! $<eval-at>.made;
    }

    method eval-at($/) {
        my $sup = $<eval-at-sup> ?? $<eval-at-sup>.made !! Any;
        my $sub = $<eval-at-sub> ?? $<eval-at-sub>.made !! Any;
        make [ 'EvaluateAt', $sub, $sup ];
    }

    method eval-at-sub($/) {
        make $<expr> ?? $<expr>.made !! $<equality>.made;
    }

    method eval-at-sup($/) {
        make $<expr> ?? $<expr>.made !! $<equality>.made;
    }

    method exp($/) {
        my $res = $<comp>.made;

        my @pow-items = (
            |self!capture-list($/, 'atom'),
            |self!capture-list($/, 'expr'),
        ).sort(*.from);
        my @sub-items = self!capture-list($/, 'subexpr').sort(*.from);

        for @pow-items.kv -> $i, $pow-match {
            my $next-from = $i < @pow-items.end ?? @pow-items[$i + 1].from !! Inf;
            my $pow = $pow-match.made;

            my $attached-sub = @sub-items.first({ $_.from >= $pow-match.pos && $_.from < $next-from }, :k);
            if $attached-sub.defined {
                $pow = [ 'Subscript', $pow, @sub-items[$attached-sub].made ];
                @sub-items.splice($attached-sub, 1);
            }

            $res = [ 'Power', $res, $pow ];
        }

        make $res;
    }

    method exp-nofunc($/) {
        my $res = $<comp-nofunc>.made;

        my @pow-items = (
            |self!capture-list($/, 'atom'),
            |self!capture-list($/, 'expr'),
        ).sort(*.from);
        my @sub-items = self!capture-list($/, 'subexpr').sort(*.from);

        for @pow-items.kv -> $i, $pow-match {
            my $next-from = $i < @pow-items.end ?? @pow-items[$i + 1].from !! Inf;
            my $pow = $pow-match.made;

            my $attached-sub = @sub-items.first({ $_.from >= $pow-match.pos && $_.from < $next-from }, :k);
            if $attached-sub.defined {
                $pow = [ 'Subscript', $pow, @sub-items[$attached-sub].made ];
                @sub-items.splice($attached-sub, 1);
            }

            $res = [ 'Power', $res, $pow ];
        }

        make $res;
    }

    method comp($/) {
        for <group abs-group func atom frac> -> $k {
            if $/{$k} {
                make $/{$k}.made;
                return;
            }
        }
        make Any;
    }

    method comp-nofunc($/) {
        for <group abs-group atom frac> -> $k {
            if $/{$k} {
                make $/{$k}.made;
                return;
            }
        }
        make Any;
    }

    method group($/) {
        make $<expr>.made;
    }

    method abs-group($/) {
        make [ 'Abs', $<expr>.made ];
    }

    method atom($/) {
        if $<number> {
            make $<number>.made;
            return;
        }

        if $<differential> {
            make $<differential>.made;
            return;
        }

        if $<mathit> {
            make $<mathit>.made;
            return;
        }

        my $base = $<letter> ?? $<letter>.made !! $<symbol>.made;
        if $<subexpr> {
            make [ 'Subscript', $base, $<subexpr>.made ];
        } else {
            make $base;
        }
    }

    method mathit-text($/) {
        make $/.Str;
    }

    method mathit($/) {
        make $<mathit-text>.made;
    }

    method frac($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        make [ 'Divide', @parts[0], @parts[1] ];
    }

    method func-normal($/) {
        my $name = self!strip-leading-slash($/.Str);
        make %FUNC-MAP{$name} // $name.tc;
    }

    method expr-integral($/) {
        my $lower = $<subexpr> ?? $<subexpr>.made !! 'Nothing';
        my $upper = $<supexpr> ?? $<supexpr>.made !! 'Nothing';

        my $integrand = do if $<frac> {
            $<frac>.made;
        } elsif $<additive> {
            $<additive>.made;
        } else {
            1;
        };

        my $var = $<differential> ?? $<differential>.made.tail !! Any;

        if $integrand ~~ Positional:D && $integrand.tail ~~ (Array:D | List:D) && $integrand.tail.head eq 'DifferentialD' {
            $var = $integrand.tail.tail;
            $integrand = $integrand.head(*-1).Array;
            if $integrand.head eq 'Multiply' && $integrand.elems == 2 {
                # The integrand now has the form like ['Multiply', 'x']
                $integrand .= tail
            }
        }

        if $!function-wrap && $lower ne 'Nothing' && $upper ne 'Nothing' && $var {
            $integrand = ['Function', ['Block', $integrand], $var]
        }

        make [ 'Integrate', $integrand, [ 'Limits', $var, $lower, $upper ] ];
    }

    method expr-sqrt($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        my $deg = @parts.elems == 2 ?? @parts[0] !! 2;
        my $radicand = @parts[*-1];
        make [ 'Root', $radicand, $deg ];
    }

    method expr-sum-prod($/) {
        my $head = $<func-sum> ?? 'Sum' !! 'Product';
        my $body = $<mp>.made;

        my $lower = $<subeq> ?? $<subeq>.made !! Any;
        my $upper = $<supexpr> ?? $<supexpr>.made !! Any;

        my ($var, $start) = (Any, Any);
        if $lower ~~ Positional && $lower.elems == 3 && $lower[0] eq 'Equal' {
            ($var, $start) = ($lower[1], $lower[2]);
        }

        make [ $head, $body, [ 'Limits', $var, $start, $upper ] ];
    }

    method expr-limit($/) {
        if $!function-wrap {
            make [ 'Limit', ['Function', ['Block', $<mp>.made], $<limit-sub>.made[1]], $<lmit-sub>.made[2] ];
        } else {
            # Elegant and "proper", but CortexJS gives (or prefers) function block format
            make [ 'Limit', $<mp>.made, $<limit-sub>.made ];
        }
    }

    method func-normal-short($/) {
        my $head = $<func-normal>.made;
        my $arg = $<func-arg> ?? $<func-arg>.made !! $<func-arg-noparens>.made;
        make [ $head, $arg ];
    }

    method func-normal-full($/) {
        my $head = $<func-normal>.made;
        my $arg = $<func-arg> ?? $<func-arg>.made !! $<func-arg-noparens>.made;
        my $res = [ $head, $arg ];
        if $<supexpr> {
            $res = ["Power", $res, $<supexpr>.made]
        }
        make $res;
    }

    method func-letter-symbol($/) {
        my $name = $<letter> ?? $<letter>.made !! $<symbol>.made;
        if $<subexpr> {
            $name = [ 'Subscript', $name, $<subexpr>.made ];
        }
        make [ 'Apply', $name, $<args>.made ];
    }

    method func($/) {
        make $/.values[0].made;
    }

    method args($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        make @parts.elems == 1 ?? @parts[0] !! [ 'Sequence', |@parts ];
    }

    method limit-sub($/) {
        my $var = $<letter> ?? $<letter>.made !! $<symbol>.made;
        my $to = $<expr>.made;
        my $dir = do if $<add-op> {
            $<add-op>.made eq 'Add' ?? 'FromAbove' !! 'FromBelow';
        } else {
            'TwoSided';
        };

        make [ 'Approach', $var, $to, $dir ];
    }

    method func-arg($/) {
        my @parts = self!capture-list($/, 'expr').map(*.made);
        make @parts.elems == 1 ?? @parts[0] !! [ 'Sequence', |@parts ];
    }

    method func-arg-noparens($/) {
        make $<mp-nofunc>.made;
    }

    method subexpr($/) {
        make $<atom> ?? $<atom>.made !! $<expr>.made;
    }

    method supexpr($/) {
        make $<atom> ?? $<atom>.made !! $<expr>.made;
    }

    method subeq($/) {
        make $<equality>.made;
    }

    method supeq($/) {
        make $<equality>.made;
    }

    #------

    method !process-recursive-operations(@parts, @ops) {
        return Any unless @parts.elems;
        return @parts.head if @parts.elems == 1;

        my $res = @parts[0];
        for @ops.kv -> $i, $op {
            my $rhs = @parts[$i + 1];
            $res = [ $op, $res, $rhs ];
        }
        $res;
    }

    method !capture-list($/, Str:D $name) {
        my $cap = $/{$name};
        return () unless $cap.defined;
        return $cap ~~ Positional ?? $cap.list !! ($cap,);
    }

    method !strip-leading-slash(Str:D $s) {
        $s.starts-with('\\') ?? $s.substr(1) !! $s;
    }
}
