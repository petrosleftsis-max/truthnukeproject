use strict; use warnings;
# Rebuilds docs/perplexity_combat_context.md from its parts: Part 1 and the title
# (rules_part.md), Part 2 and Part 3's heading as they stand in the file, Part 3's
# body from a fresh refdump (tests/run.sh refdump writes refdump_data.md beside the
# test logs), Part 4 (decisions_part.md). Run from the project folder:
#   perl tools/context/rebuild_context.pl /tmp/mot-test-harness/logs/refdump_data.md
# The parts are in tools/context unless a second argument names another folder.
my ($refdump, $scratch) = @ARGV;
$scratch //= "tools/context";
my $f = "docs/perplexity_combat_context.md";
sub slurp { my ($p) = @_; open my $in, '<', $p or die "$p: $!"; local $/; my $t = <$in>; close $in; return $t; }
my $current = slurp($f);
my $rules = slurp("$scratch/rules_part.md");
my $decisions = slurp("$scratch/decisions_part.md");
my $data = slurp($refdump);
# Part 2, through Part 3's heading and its intro paragraph, as they stand.
my $p2 = index($current, "\n# Part 2 - ");
my $p3 = index($current, "\n# Part 3 - ");
my $body_at = index($current, "\n## The party", $p3);
die "parts not found ($p2, $p3, $body_at)" if $p2 < 0 or $p3 < 0 or $body_at < 0;
my $middle = substr($current, $p2, $body_at - $p2 + 1);
# The refdump's own heading and intro go; Part 3's stand in for them.
my $data_at = index($data, "## The party");
die "refdump: no party section" if $data_at < 0;
my $body = substr($data, $data_at);
$body =~ s/\n+\z/\n/;
# A blank line before every heading, for Markdown.
$body =~ s/([^\n])\n(#{1,6} )/$1\n\n$2/g;
my $out = $rules . $middle . $body . $decisions;
open my $o, '>', $f or die; binmode $o; print $o $out; close $o;
print "rebuilt: " . (() = $out =~ /\n/g) . " lines\n";
