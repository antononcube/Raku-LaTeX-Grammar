use experimental :rakuast;

use LaTeX::Grammarish;
use LaTeX::Actions::AsciiMath;
use LaTeX::Actions::MathJSON;
use LaTeX::Actions::MathML;
use LaTeX::Actions::RakuAST;
use LaTeX::Actions::WL;
use JSON::Fast;

grammar LaTeX::Grammar
        does LaTeX::Grammarish {

}

#-----------------------------------------------------------
our sub latex-subparse(Str:D $command, Str:D :$rule = 'TOP') is export {
    LaTeX::Grammar.subparse($command, :$rule);
}

our sub latex-parse(Str:D $command, Str:D :$rule = 'TOP') is export {
    LaTeX::Grammar.parse($command, :$rule);
}

our sub latex-interpret(Str:D $command,
                        Str:D :$rule = 'TOP',
                        :t(:to(:a(:$actions))) is copy = Whatever,
                        :$format is copy = Whatever,
                        Bool:D :$function-wrap = True
                        ) is export {
    # Choose actions class
    $actions = do given $actions {
        when Whatever {
            LaTeX::Actions::MathJSON.new(:$function-wrap)
        }
#        when $_ ~~ Str:D && $_.lc ∈ ["mathematica", "wl", "wolfram", "wolfram language"] {
#            MermaidJS::Actions::WL::Graph.new
#        }
        when $_ ~~ Str:D && $_.lc ∈ <math-json mathjson json> {
            LaTeX::Actions::MathJSON.new(:$function-wrap)
        }
        when $_ ~~ Str:D && $_.lc ∈ <math-ml mathml mml xml> {
            LaTeX::Actions::MathML.new(:!function-wrap)
        }
        when $_ ~~ Str:D && $_.lc ∈ <ascii-math asciimath am> {
            LaTeX::Actions::AsciiMath.new(:!function-wrap)
        }
        when $_ ~~ Str:D && $_.lc ∈ <wl wolfram mathematica wolfram-language> {
            LaTeX::Actions::WL.new(:!function-wrap)
        }
        when $_ ~~ Str:D && $_.lc ∈ <raku raku-code perl6> {
            LaTeX::Actions::RakuAST.new(:!function-wrap)
        }
        when $_ ~~ Str:D && $_.lc ∈ <ast rakuast> {
            if $format.isa(Whatever) { $format = 'ast' }
            LaTeX::Actions::RakuAST.new(:!function-wrap)
        }
        default {
            $actions
        }
    }

    # Format
    #my @expectedFormats = <asciimath ast mathjson mathml math-ml mmml mathematica wl wolfram wolfram-language raku rakuast>;
    my @expectedFormats = <ast raku json>;
    die "The argument \$format is exected \"{@expectedFormats.join('", "')}\" or Whatever"
    unless $format.isa(Whatever) || $format ~~ Str:D && $format ∈ @expectedFormats;

    # Result
    my $res = LaTeX::Grammar.parse($command, :$rule, :$actions).made;

    return do given $format {
        when Whatever { $res }
        when $_.lc eq 'json' { to-json($res, :!pretty)  }
        when $_.lc eq 'ast' && $actions ~~ LaTeX::Actions::RakuAST { $res }
        when $_.lc eq 'raku' && $actions ~~ LaTeX::Actions::RakuAST { $res.DEPARSE.raku }
        #when $_.lc eq 'raku' { $res.raku }
        default { $res }
    }
}
