use LaTeX::Grammarish;
use LaTeX::Actions::MathJSON;
use LaTeX::Actions::MathML;
use LaTeX::Actions::AsciiMath;
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
                        :t(:to(:a(:$actions))) is copy = LaTeX::Actions::MathJSON.new,
                        :$format is copy = Whatever;
                        ) is export {
    # Choose actions class
    $actions = do given $actions {
        when Whatever {
            LaTeX::Actions::MathJSON.new
        }
#        when $_ ~~ Str:D && $_.lc ∈ ["mathematica", "wl", "wolfram", "wolfram language"] {
#            MermaidJS::Actions::WL::Graph.new
#        }
        when $_ ~~ Str:D && $_.lc ∈ <math-json mathjson json> {
            LaTeX::Actions::MathJSON.new
        }
        when $_ ~~ Str:D && $_.lc ∈ <math-ml mathml mml xml> {
            LaTeX::Actions::MathML.new
        }
        when $_ ~~ Str:D && $_.lc ∈ <ascii-math asciimath am> {
            LaTeX::Actions::AsciiMath.new
        }
        when $_ ~~ Str:D && $_.lc ∈ <wl wolfram mathematica wolfram-language> {
            LaTeX::Actions::WL.new
        }
#        when $_ ~~ Str:D && $_.lc ∈ <raku perl6> {
#            MermaidJS::Actions::Raku.new
#        }
        default {
            $actions
        }
    }

    # Format
    if $format.isa(Whatever) { $format = $actions ~~ LaTeX::Actions::MathJSON ?? 'json' !! 'raku' }

    # Result
    my $res = LaTeX::Grammar.parse($command, :$rule, :$actions).made;
    return $format ~~ Str:D && $format.lc eq 'json' ?? to-json($res, :!pretty) !! $res;
}
