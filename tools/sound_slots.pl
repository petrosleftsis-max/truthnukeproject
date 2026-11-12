use strict;
use warnings;
use File::Find;
use FindBin; my $root = "$FindBin::Bin/..";
sub slurp { my $f = shift; open(my $in, "<", $f) or die "$f"; local $/; my $t = <$in>; close($in); return $t; }

# The sound bank.
my $bank_gd = slurp("$root/audio/SoundBank.gd");
my $bank = slurp("$root/audio/sound_bank.tres");
my %filled = map { $_ => 1 } ($bank =~ /^([a-z_]+) = ExtResource/mg);
my %stand_in = (footstep => "a soft thud", footstep_wet => "a splash", codex_reveal => "three rising notes");
my @rows;
my $group = "";
for my $line (split /\n/, $bank_gd) {
	if ($line =~ /^\@export_group\("([^"]+)"\)/) { $group = $1; next; }
	if ($line =~ /^\@export var ([a-z_]+): AudioStream/) {
		my $slot = $1;
		my $state = $filled{$slot} ? "yours" : ($stand_in{$slot} ? "stand-in: $stand_in{$slot}" : "**empty, silent**");
		push @rows, "| $group | `$slot` | $state |";
	}
}

# The pictures.
my $feedback_gd = slurp("$root/exploration/PictureFeedback.gd");
my $feedback = slurp("$root/pictures/feedback.tres");
my %pic_filled = map { $_ => 1 } ($feedback =~ /^([a-z_]+) = ExtResource/mg);
my @pic_rows;
for my $slot ($feedback_gd =~ /^\@export var ([a-z_]+): AudioStream/mg) {
	push @pic_rows, "| `$slot` | " . ($pic_filled{$slot} ? "yours" : "stand-in") . " |";
}

# The moves and the items, by folder.
my %by_folder;
find(sub {
	return unless /\.tres$/;
	my $path = $File::Find::name;
	my $text = slurp($path);
	return unless $text =~ /script_class="(SkillDefinition|ItemDefinition|GateNadeDefinition)"/;
	my ($name) = $text =~ /^name = "([^"]*)"/m;
	$name //= $_;
	my $launch = $text =~ /^sound = /m ? "yours" : "stand-in";
	my $impact = $text =~ /^impact_sound = /m ? "yours" : "stand-in";
	my $travel = $text =~ /^travel_sound = /m ? "yours" : "stand-in";
	(my $rel = $path) =~ s{^\Q$root\E/}{};
	(my $folder = $rel) =~ s{/[^/]+$}{};
	push @{$by_folder{$folder}}, [$name, $launch, $travel, $impact];
}, "$root/data/skills", "$root/data/items");

# Conditions that tick.
my @tick_rows;
opendir(my $dh, "$root/data/conditions") or die;
for my $f (sort grep { /\.tres$/ } readdir($dh)) {
	my $text = slurp("$root/data/conditions/$f");
	next unless $text =~ /^dot_strength = /m;
	my ($name) = $text =~ /^display_name = "([^"]*)"/m;
	push @tick_rows, "| $name | " . ($text =~ /^tick_sound = /m ? "yours" : "the move's own, or silent") . " |";
}
closedir($dh);

my $out = "";
$out .= "# Sound slots: what is filled, what plays a stand-in, what is silent\n\n";
$out .= "Every sound the game asks for, as of 2026-11-12 (made by `perl tools/sound_slots.pl` over the data; run it again when sounds go in). **Yours** is a\n";
$out .= "file you placed. A **stand-in** is a placeholder made in code on the spot (`exploration/PlaceholderSounds.gd`), heard until a file\n";
$out .= "fills the slot. **Silent** is a slot that plays nothing until filled. Fill a slot in the editor: the sound bank is\n";
$out .= "`audio/sound_bank.tres`, the pictures' `pictures/feedback.tres`, a move's or a condition's own file (its Sound fields).\n\n";
$out .= "## The sound bank (`audio/sound_bank.tres`)\n\n| Group | Slot | Now |\n| --- | --- | --- |\n" . join("\n", @rows) . "\n\n";
$out .= "## Pictures and puzzles (`pictures/feedback.tres`)\n\n| Slot | Now |\n| --- | --- |\n" . join("\n", @pic_rows) . "\n\n";
$out .= "## Conditions that tick (each condition's Tick Sound)\n\nA tick plays the condition's own sound, else the sound of the move that put it on.\n\n| Condition | Now |\n| --- | --- |\n" . join("\n", @tick_rows) . "\n\n";
$out .= "## Moves and items (each one's Sound, Travel Sound and Impact Sound)\n\n";
$out .= "Launch is as the move leaves its user, travel while it flies, impact where it lands. Stand-ins go by kind (a shot, a spell, a throw)\n";
$out .= "and by element.\n\n";
for my $folder (sort keys %by_folder) {
	my @moves = sort { $a->[0] cmp $b->[0] } @{$by_folder{$folder}};
	$out .= "### `$folder`\n\n| Move | Launch | Travel | Impact |\n| --- | --- | --- | --- |\n";
	$out .= join("\n", map { "| $_->[0] | $_->[1] | $_->[2] | $_->[3] |" } @moves) . "\n\n";
}
open(my $o, ">", "$root/docs/sound_slots.md") or die; print $o $out; close($o);
print scalar(@rows), " bank slots, ", scalar(@pic_rows), " picture slots, ", scalar(@tick_rows), " ticking conditions, ", scalar(keys %by_folder), " move folders\n";
