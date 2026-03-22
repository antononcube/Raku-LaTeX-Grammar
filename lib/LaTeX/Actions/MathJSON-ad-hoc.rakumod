use v6.d;

use JSON::Fast;

class LaTeX::Actions::MathJSON-ad-hoc {

    my constant @REL-OPS = <\\leq \\geq = < >>;
    my constant @ADD-OPS = <+ ->;
    my constant @MUL-OPS = <\\times \\cdot \\div * / :>;
    my constant @FUNC-NAMES = <
    log ln
    sin cos tan csc sec cot
    arcsin arccos arctan arccsc arcsec arccot
    sinh cosh tanh arsinh arcosh artanh
>;

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
        make self!to-mathjson($/.Str);
    }

    method !to-mathjson(Str:D $raw) {
        my $s = $raw.trim;
        self!relation($s);
    }

    method !relation(Str:D $s) {
        my ($parts, $ops) = self!split-top-level($s, @REL-OPS);
        return self!additive($s) unless $ops.elems;

        my $res = self!additive($parts[0]);
        for $ops.kv -> $i, $op {
            my $rhs = self!additive($parts[$i + 1]);
            my $head = do given $op {
                when '='      { 'Equal' }
                when '<'      { 'Less' }
                when '>'      { 'Greater' }
                when '\\leq' { 'LessEqual' }
                when '\\geq' { 'GreaterEqual' }
                default       { 'Relation' }
            };
            $res = [ $head, $res, $rhs ];
        }

        $res;
    }

    method !additive(Str:D $s) {
        my ($parts, $ops) = self!split-top-level($s, @ADD-OPS, :unary-aware);
        return self!multiplicative($s) unless $ops.elems;

        my $res = self!multiplicative($parts[0]);
        for $ops.kv -> $i, $op {
            my $rhs = self!multiplicative($parts[$i + 1]);
            $res = [ $op eq '+' ?? 'Add' !! 'Subtract', $res, $rhs ];
        }

        $res;
    }

    method !multiplicative(Str:D $s) {
        my ($parts, $ops) = self!split-top-level($s, @MUL-OPS);
        return self!unary($s) unless $ops.elems;

        my $res = self!unary($parts[0]);
        for $ops.kv -> $i, $op {
            my $rhs = self!unary($parts[$i + 1]);
            my $head = $op eq '*' || $op eq '\\times' || $op eq '\\cdot' ?? 'Multiply' !! 'Divide';
            $res = [ $head, $res, $rhs ];
        }

        $res;
    }

    method !unary(Str:D $s) {
        my $t = $s.trim;
        my $neg = 0;

        while $t.chars && ($t.substr(0, 1) eq '+' || $t.substr(0, 1) eq '-') {
            $neg++ if $t.substr(0, 1) eq '-';
            $t = $t.substr(1).trim;
        }

        my $res = self!power($t);
        $neg %% 2 ?? $res !! [ 'Negate', $res ];
    }

    method !power(Str:D $s) {
        my $idx = self!find-top-level-char($s, '^');
        return self!postfix($s) if $idx < 0;

        my $base = self!postfix($s.substr(0, $idx));
        my $expo-raw = $s.substr($idx + 1).trim;
        my $expo = self!strip-braces($expo-raw);

        [ 'Power', $base, self!relation($expo) ];
    }

    method !postfix(Str:D $s) {
        my $t = $s.trim;
        my $bangs = 0;

        while $t.chars && $t.ends-with('!') {
            $bangs++;
            $t = $t.substr(0, $t.chars - 1).trim;
        }

        my $res = self!primary($t);
        for ^$bangs {
            $res = [ 'Factorial', $res ];
        }

        $res;
    }

    method !primary(Str:D $s) {
        my $t = $s.trim;

        if self!is-wrapped($t, '(', ')') || self!is-wrapped($t, '[', ']') || self!is-wrapped($t, '{', '}') {
            return self!relation(self!unwrap($t));
        }

        if self!is-wrapped($t, '|', '|') {
            return [ 'Abs', self!relation(self!unwrap($t)) ];
        }

        if $t.starts-with('\\frac') {
            return self!parse-frac($t);
        }

        if $t.starts-with('\\sqrt') {
            return self!parse-sqrt($t);
        }

        if $t.starts-with('\\int') {
            return self!parse-integral($t);
        }

        if $t.starts-with('\\sum') || $t.starts-with('\\prod') {
            return self!parse-sum-prod($t);
        }

        if $t.starts-with('\\lim') {
            return self!parse-limit($t);
        }

        my $fn = self!parse-known-func($t);
        return $fn if $fn.defined;

        my $call = self!parse-generic-call($t);
        return $call if $call.defined;

        my $sub = self!find-top-level-char($t, '_');
        if $sub > 0 {
            my $left = $t.substr(0, $sub).trim;
            my $right = $t.substr($sub + 1).trim;
            my $rhs = self!script-value($right);
            return [ 'Subscript', self!primary($left), $rhs ];
        }

        if $t ~~ /^ '\\mathit' \{ (.*) \} $/ {
            return ~$0;
        }

        if $t ~~ /^ 'd' \s* (\\<-[\s]>+ | <[A..Za..z]>) $/ {
            my $v = ~$0;
            $v = $v.substr(1) if $v.starts-with('\\');
            return [ 'DifferentialD', $v ];
        }

        if $t ~~ /^ <[0..9]>* [ ',' <[0..9]>**3 ]* [ '.' <[0..9]>+ ]? $/ && $t ne '' {
            my $n = $t.subst(',', '', :g);
            return $n.contains('.') ?? $n.Num !! $n.Int;
        }

        if $t ~~ /^ '\\' <[A..Za..z]>+ $/ {
            return $t.substr(1);
        }

        if $t ~~ /^ <[A..Za..z]> $/ {
            return $t;
        }

        $t;
    }

    method !parse-frac(Str:D $s) {
        my $pos = '\\frac'.chars;
        my ($num, $p1) = self!extract-group($s, $pos, '{', '}');
        my ($den, $p2) = self!extract-group($s, $p1, '{', '}');
        return Any unless $num.defined && $den.defined;

        [ 'Divide', self!relation($num), self!relation($den) ];
    }

    method !parse-sqrt(Str:D $s) {
        my $pos = '\\sqrt'.chars;
        my $root = 2;

        if $pos < $s.chars && $s.substr($pos, 1) eq '[' {
            my ($r, $p1) = self!extract-group($s, $pos, '[', ']');
            return Any unless $r.defined;
            $root = self!relation($r);
            $pos = $p1;
        }

        my ($base, $p2) = self!extract-group($s, $pos, '{', '}');
        return Any unless $base.defined;

        [ 'Root', self!relation($base), $root ];
    }

    method !parse-integral(Str:D $s) {
        my $pos = '\\int'.chars;
        my $lower = Any;
        my $upper = Any;

        ($lower, $pos) = self!consume-script($s, $pos, '_') if $pos < $s.chars && $s.substr($pos, 1) eq '_';
        ($upper, $pos) = self!consume-script($s, $pos, '^') if $pos < $s.chars && $s.substr($pos, 1) eq '^';

        my $rest = $s.substr($pos).trim;
        my $var = Any;

        if $rest ~~ /(.*) 'd' \s* (\\<-[\s]>+ | <[A..Za..z]>) \s* $/ {
            $rest = ~$0;
            $var = ~$1;
            $var = $var.substr(1) if $var.starts-with('\\');
        }

        [ 'Integrate', self!relation($rest), [ 'Tuple', $var, $lower, $upper ] ];
    }

    method !parse-sum-prod(Str:D $s) {
        my $is-sum = $s.starts-with('\\sum');
        my $head = $is-sum ?? 'Sum' !! 'Product';
        my $pos = $is-sum ?? '\\sum'.chars !! '\\prod'.chars;

        my $sub = Any;
        my $sup = Any;

        ($sub, $pos) = self!consume-script($s, $pos, '_') if $pos < $s.chars && $s.substr($pos, 1) eq '_';
        ($sup, $pos) = self!consume-script($s, $pos, '^') if $pos < $s.chars && $s.substr($pos, 1) eq '^';

        my $body = self!relation($s.substr($pos).trim);
        my $var = Any;
        my $start = Any;

        if $sub ~~ Positional && $sub.elems == 3 && $sub[0] eq 'Equal' {
            $var = $sub[1];
            $start = $sub[2];
        }

        [ $head, $body, [ 'Tuple', $var, $start, $sup ] ];
    }

    method !parse-limit(Str:D $s) {
        my $pos = '\\lim'.chars;
        my $spec = Any;

        if $pos < $s.chars && $s.substr($pos, 1) eq '_' {
            ($spec, $pos) = self!consume-script($s, $pos, '_');
        }

        my $body = self!relation($s.substr($pos).trim);

        if $spec ~~ Str {
            my $txt = $spec.trim;
            if $txt ~~ /^ (\\<-[\\]>+ | <[A..Za..z]>) [ '\\to' | '\\rightarrow' | '\\Rightarrow' | '\\longrightarrow' | '\\Longrightarrow' ] (.*) $/ {
                my $var = ~$0;
                $var = $var.substr(1) if $var.starts-with('\\');
                my $to = self!relation(~$1);
                return [ 'Limit', $body, [ 'Approach', $var, $to, 'TwoSided' ] ];
            }
        }

        [ 'Limit', $body, $spec ];
    }

    method !parse-known-func(Str:D $s) {
        for @FUNC-NAMES -> $f {
            my $cmd = "\\$f";
            next unless $s.starts-with($cmd);

            my $rest = $s.substr($cmd.chars).trim;
            my $arg = Any;

            if $rest.starts-with('(') {
                my ($inside, $pos) = self!extract-group($rest, 0, '(', ')');
                return Any unless $inside.defined;
                $arg = self!relation($inside);
            } elsif $rest ne '' {
                $arg = self!relation($rest);
            } else {
                $arg = Any;
            }

            return [ %FUNC-MAP{$f}, $arg ];
        }

        Any;
    }

    method !parse-generic-call(Str:D $s) {
        my $open = self!find-top-level-char($s, '(');
        return Any if $open <= 0 || !$s.ends-with(')');

        my $head = $s.substr(0, $open).trim;
        return Any unless $head ~~ /^ [ '\\' <[A..Za..z]>+ | <[A..Za..z]> ] $/;

        my $inside = $s.substr($open + 1, $s.chars - $open - 2);
        my ($parts, $ops) = self!split-top-level($inside, [',']);

        my $args = $ops.elems
                ?? [ 'Sequence', |($parts.map({ self!relation($_) })) ]
                !! self!relation($inside);

        my $h = $head.starts-with('\\') ?? $head.substr(1) !! $head;
        [ 'Apply', $h, $args ];
    }

    method !script-value(Str:D $s) {
        my $t = $s.trim;
        return self!relation(self!unwrap($t)) if self!is-wrapped($t, '{', '}');
        self!primary($t);
    }

    method !consume-script(Str:D $s, Int:D $pos, Str:D $marker) {
        return (Any, $pos) unless $pos < $s.chars && $s.substr($pos, 1) eq $marker;
        my $i = $pos + 1;
        while $i < $s.chars && $s.substr($i, 1) eq ' ' { $i++ }

        if $i < $s.chars && $s.substr($i, 1) eq '{' {
            my ($v, $p) = self!extract-group($s, $i, '{', '}');
            return (self!relation($v), $p);
        }

        if $i < $s.chars && $s.substr($i, 1) eq '\\' {
            my $j = $i + 1;
            $j++ while $j < $s.chars && $s.substr($j, 1) ~~ /<[A..Za..z]>/;
            return (self!relation($s.substr($i, $j - $i)), $j);
        }

        return (self!relation($s.substr($i, 1)), $i + 1) if $i < $s.chars;
        (Any, $s.chars);
    }

    method !extract-group(Str:D $s, Int:D $pos, Str:D $open, Str:D $close) {
        my $i = $pos;
        while $i < $s.chars && $s.substr($i, 1) eq ' ' { $i++ }
        return (Nil, $pos) unless $i < $s.chars && $s.substr($i, 1) eq $open;

        my $depth = 1;
        my $j = $i + 1;
        while $j < $s.chars {
            my $c = $s.substr($j, 1);
            if $c eq '\\' {
                $j += 2;
                next;
            }
            $depth++ if $c eq $open;
            $depth-- if $c eq $close;
            if $depth == 0 {
                return ($s.substr($i + 1, $j - $i - 1), $j + 1);
            }
            $j++;
        }

        (Nil, $pos);
    }

    method !split-top-level(Str:D $s, @ops, :$unary-aware = False) {
        my @ordered = @ops.sort({ $^b.chars <=> $^a.chars });

        my $paren = 0;
        my $brace = 0;
        my $brack = 0;
        my $bar = 0;

        my @parts;
        my @found;
        my $start = 0;
        my $i = 0;

        while $i < $s.chars {
            my $c = $s.substr($i, 1);

            if $c eq '\\' {
                my $matched = False;
                if $paren == 0 && $brace == 0 && $brack == 0 && $bar == 0 {
                    for @ordered -> $op {
                        next unless $op.starts-with('\\');
                        if $s.substr($i, $op.chars) eq $op {
                            @parts.push: $s.substr($start, $i - $start).trim;
                            @found.push: $op;
                            $i += $op.chars;
                            $start = $i;
                            $matched = True;
                            last;
                        }
                    }
                }
                next if $matched;

                $i++;
                $i++ while $i < $s.chars && $s.substr($i, 1) ~~ /<[A..Za..z]>/;
                next;
            }

            if $c eq '(' { $paren++; $i++; next; }
            if $c eq ')' { $paren--; $i++; next; }
            if $c eq '{' { $brace++; $i++; next; }
            if $c eq '}' { $brace--; $i++; next; }
            if $c eq '[' { $brack++; $i++; next; }
            if $c eq ']' { $brack--; $i++; next; }
            if $c eq '|' { $bar = 1 - $bar; $i++; next; }

            if $paren == 0 && $brace == 0 && $brack == 0 && $bar == 0 {
                my $matched = False;
                for @ordered -> $op {
                    next if $op.starts-with('\\');
                    next unless $s.substr($i, $op.chars) eq $op;

                    if $unary-aware && ($op eq '+' || $op eq '-') {
                        my $left = $s.substr(0, $i).trim;
                        if $left eq '' || $left.ends-with('(') || $left.ends-with('[') || $left.ends-with('{') || $left.ends-with(',') {
                            next;
                        }
                    }

                    @parts.push: $s.substr($start, $i - $start).trim;
                    @found.push: $op;
                    $i += $op.chars;
                    $start = $i;
                    $matched = True;
                    last;
                }
                next if $matched;
            }

            $i++;
        }

        @parts.push: $s.substr($start).trim;
        (@parts, @found);
    }

    method !find-top-level-char(Str:D $s, Str:D $needle --> Int:D) {
        my $paren = 0;
        my $brace = 0;
        my $brack = 0;
        my $bar = 0;

        my $i = 0;
        while $i < $s.chars {
            my $c = $s.substr($i, 1);
            if $c eq '\\' {
                $i++;
                $i++ while $i < $s.chars && $s.substr($i, 1) ~~ /<[A..Za..z]>/;
                next;
            }

            if $c eq '(' { $paren++; $i++; next; }
            if $c eq ')' { $paren--; $i++; next; }
            if $c eq '{' { $brace++; $i++; next; }
            if $c eq '}' { $brace--; $i++; next; }
            if $c eq '[' { $brack++; $i++; next; }
            if $c eq ']' { $brack--; $i++; next; }
            if $c eq '|' { $bar = 1 - $bar; $i++; next; }

            return $i if $paren == 0 && $brace == 0 && $brack == 0 && $bar == 0 && $c eq $needle;
            $i++;
        }

        -1;
    }

    method !is-wrapped(Str:D $s, Str:D $open, Str:D $close --> Bool:D) {
        return False if $s.chars < 2;
        return False unless $s.starts-with($open) && $s.ends-with($close);

        my ($inside, $pos) = self!extract-group($s, 0, $open, $close);
        $inside.defined && $pos == $s.chars;
    }

    method !unwrap(Str:D $s --> Str:D) {
        $s.substr(1, $s.chars - 2);
    }

    method !strip-braces(Str:D $s --> Str:D) {
        my $t = $s.trim;
        self!is-wrapped($t, '{', '}') ?? self!unwrap($t) !! $t;
    }
}
