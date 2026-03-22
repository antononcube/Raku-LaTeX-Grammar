use v6.d;
# Reprogrammed to Raku from the ANTLR grammar file:
#   https://github.com/augustt198/latex2sympy/blob/master/PS.g4

role LaTeX::Grammarish {

    rule TOP { ^ <math> $ }

    # Skip inter-token whitespace, similar to ANTLR's WS -> skip.
    token ws { \s* }

    token letter { <[a..zA..Z]> }
    token digit  { <[0..9]> }

    token add-op { '+' | '-' }
    token mul-op { '*' | '\\times' | '\\cdot' | '/' | '\\div' | ':' }
    token rel-op { '=' | '<' | '\\leq' | '>' | '\\geq' }
    token approach-sym { '\\to' | '\\rightarrow' | '\\Rightarrow' | '\\longrightarrow' | '\\Longrightarrow' }

    token func-lim   { '\\lim' }
    token func-int   { '\\int' }
    token func-sum   { '\\sum' }
    token func-prod  { '\\prod' }

    token func-log   { '\\log' }
    token func-ln    { '\\ln' }
    token func-sin   { '\\sin' }
    token func-cos   { '\\cos' }
    token func-tan   { '\\tan' }
    token func-csc   { '\\csc' }
    token func-sec   { '\\sec' }
    token func-cot   { '\\cot' }

    token func-arcsin { '\\arcsin' }
    token func-arccos { '\\arccos' }
    token func-arctan { '\\arctan' }
    token func-arccsc { '\\arccsc' }
    token func-arcsec { '\\arcsec' }
    token func-arccot { '\\arccot' }

    token func-sinh   { '\\sinh' }
    token func-cosh   { '\\cosh' }
    token func-tanh   { '\\tanh' }
    token func-arsinh { '\\arsinh' }
    token func-arcosh { '\\arcosh' }
    token func-artanh { '\\artanh' }

    token func-sqrt  { '\\sqrt' }
    token cmd-frac   { '\\frac' }
    token cmd-mathit { '\\mathit' }

    token symbol { '\\' <[a..zA..Z]>+ }

    token number {
        [ <digit>+ [ ',' <digit>**3 ]* ]
        |
        [ <digit>* [ ',' <digit>**3 ]* '.' <digit>+ ]
    }

    token differential { 'd' \s* [ <letter> | <symbol> ] }

    rule math     { <relation> }
    rule relation { <expr> [ <rel-op> <expr> ]* }
    rule equality { <expr> '=' <expr> }
    rule expr     { <additive> }

    rule additive { <mp> [ <add-op> <mp> ]* }
    rule mp       { <unary> [ <mul-op> <unary> ]* }
    rule mp-nofunc { <unary-nofunc> [ <mul-op> <unary-nofunc> ]* }

    rule unary        { <add-op>* <postfix>+ }
    rule unary-nofunc { <add-op>* <postfix> <postfix-nofunc>* }

    rule postfix         { <exp> <postfix-op>* }
    rule postfix-nofunc  { <exp-nofunc> <postfix-op>* }
    rule postfix-op      { '!' | <eval-at> }

    rule eval-at { '|'
    [ <eval-at-sup> | <eval-at-sub> | <eval-at-sup> <eval-at-sub> ]
    }

    rule eval-at-sub { '_' '{' [ <expr> | <equality> ] '}' }
    rule eval-at-sup { '^' '{' [ <expr> | <equality> ] '}' }

    rule exp { <comp> [ '^' [ <atom> | '{' <expr> '}' ] <subexpr>? ]* }

    rule exp-nofunc { <comp-nofunc> [ '^' [ <atom> | '{' <expr> '}' ] <subexpr>? ]* }

    rule comp {
        <group>
        | <abs-group>
        | <func>
        | <atom>
        | <frac>
    }

    rule comp-nofunc {
            <group>
        | <abs-group>
        | <atom>
        | <frac>
    }

    rule group {
            '(' <expr> ')'
        | '[' <expr> ']'
        | '{' <expr> '}'
    }

    rule abs-group { '|' <expr> '|' }

    rule atom {
            [ <letter> | <symbol> ] <subexpr>?
        | <number>
        | <differential>
        | <mathit>
    }

    rule mathit      { <cmd-mathit> '{' <mathit-text> '}' }
    token mathit-text { <letter>* }

    rule frac {
        <cmd-frac> '{' <expr> '}' '{' <expr> '}'
    }

    token func-normal {
        <func-log> | <func-ln>
        | <func-sin> | <func-cos> | <func-tan>
        | <func-csc> | <func-sec> | <func-cot>
        | <func-arcsin> | <func-arccos> | <func-arctan>
        | <func-arccsc> | <func-arcsec> | <func-arccot>
        | <func-sinh> | <func-cosh> | <func-tanh>
        | <func-arsinh> | <func-arcosh> | <func-artanh>
    }

    rule expr-integral {
        <func-int>
            [ <subexpr> <supexpr> | <supexpr> <subexpr> ]?
            [ <additive>? <differential> | <frac> | <additive> ]
    }

    rule expr-sqrt {
        <func-sqrt> [ '[' <expr> ']' ]? '{' <expr> '}'
    }

    rule expr-sum-prod {
        [ <func-sum> | <func-prod> ]
        [ <subeq> <supexpr> | <supexpr> <subeq> ]
        <mp>
    }

    rule expr-limit { <func-lim> <limit-sub> <mp> }

    rule func-normal-short {
        <func-normal> [ '(' <func-arg> ')' | <func-arg-noparens> ]
    }

    rule func-normal-full {
        <func-normal>
        [ <subexpr> <supexpr>? | <supexpr> <subexpr>? ]
        [ '(' <func-arg> ')' | <func-arg-noparens> ]
    }

    rule func-letter-symbol {
        [ <letter> | <symbol> ] <subexpr>? '(' <args> ')'
    }

    rule func {

        [
            || <func-normal-short>
            || <func-letter-symbol>
        ]
        | <func-normal-full>
        | <expr-integral>
        | <expr-sqrt>
        | <expr-sum-prod>
        | <expr-limit>
    }

    rule args { <expr> [ ',' <expr> ]* }

    rule limit-sub {
        '_' '{'
        [ <letter> | <symbol> ]
            <approach-sym>
        <expr>
        [ '^' '{' <add-op> '}' ]?
        '}'
    }

    rule func-arg         { <expr> [ ',' <expr> ]* }
    rule func-arg-noparens { <mp-nofunc> }

    rule subexpr { '_' [ <atom> | '{' <expr> '}' ] }
    rule supexpr { '^' [ <atom> | '{' <expr> '}' ] }

    rule subeq { '_' '{' <equality> '}' }
    rule supeq { '_' '{' <equality> '}' }

}
