use v6.d;

use JSON::Fast;

class LaTeX::Actions::MathJSON {

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

    method letter($/) {
        make $/.Str;
    }

    method symbol($/) {
        make $/.Str;
    }

    method number($/) {
        make $/.Str.subst(',', '_', :g).Numeric;
    }

    method differential($/) {
        make $/.values[0].made;
    }

    method math($/) {
        make $<relation>.made;
    }

    method relation($/) {
        my @parts = $<expr>>>.made;
        my @ops = $<rel-op>>>.made;
        make self!process-recursive-operations(@parts, @ops);
    }

    method equality($/) {
        make ['Equal', $<expr>.head, $<expr>.tail];
    }

    method expr($/) {
        make $<additive>.made;
    }

    method additive($/) {
        my @parts = $<mp>>>.made;
        my @ops = $<add-op>>>.made;
        say ('additive', :@parts, :@ops);
        make self!process-recursive-operations(@parts, @ops);
    }

    method mp($/) {
        my @parts = $<unary>>>.made;
        my @ops = $<mul-op>>>.made;
        say ('mp', :@parts, :@ops);
        make self!process-recursive-operations(@parts, @ops);
    }

    method mp-nofunc($/) {
        my @parts = $<unary-nofunc>>>.made;
        my @ops = $<mul-op>>>.made;
        make self!process-recursive-operations(@parts, @ops);
    }

    method unary($/) {

    }

    method unary-nofunc($/) {

    }

    method postfix($/) {

    }

    method postfix-nofunc($/) {

    }

    method exp($/) {

    }

    method expr-intergral($/) {

    }

    #------

    method !process-recursive-operations(@parts, @ops) {
        return @parts.head if @parts.elems == 1;
        my $res = @parts[0];
        for @ops.kv -> $i, $op {
            my $rhs = @parts[$i + 1];
            $res = [ $op, $res, $rhs ];
        }
        $res;
    }
}
