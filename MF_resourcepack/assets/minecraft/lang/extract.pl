#!/usr/bin/perl

# USAGE:
# 	run this in the matcha languages directory
# 	copy the minecraft lang files into minecraft/*.json
# 	run the script, it will append missing profession translations to the language JSON file
# 		(this will temporarily make it invalid JSON; move the closing } manually.)
#	entries that simply contain Name/name plainly will be auto-translated
#	otherwise they will be commented out and need to be translated manually
#		(commented-out lines aren't valid JSON, which is intentional.)

use strict; use warnings; use v5.38; use utf8; use open qw(:std :utf8);

# if this has values provided, then only process translations for these professions.
my(@only_profs) = (); # qw( leatherworker cartographer armorer cleric toolsmith butcher librarian ); 

my(@langfiles) = glob("*.json");

my $k_name = 'entity.minecraft.villager';
my $k_work = 'subtitles.entity.villager.work';

my $r_name = qr/"${k_name}.([a-z_]+)": "([^"]+)"/;
my $r_work = qr/"${k_work}_([a-z_]+)": "([^"]+)"/;

my %langs;

for my $lang (@langfiles) {
	my(%names, %works);
	open(my $langfile, '<', "minecraft/$lang") or die "open minecraft/$lang: $!";
	while (<$langfile>) {
		if (/$r_name/) {
			$names{$1} = $2;
			next;
		}
		if (/$r_work/) {
			$works{$1} = $2;
			next;
		}
	}
	close($langfile) or die "close: $!";
	my($l) = ($lang =~ /(^.+)\.json$/);
	$langs{$l} = { names => \%names, works => \%works };
}

my %matcha_langs;

for my $lang (@langfiles) {
	my(%matcha_names, %matcha_works);
	open(my $langfile, '<', $lang) or die "open $lang: $!";
	while (<$langfile>) {
		if (/$r_name/) {
			$matcha_names{$1} = $2;
			next;
		}
		if (/$r_work/) {
			$matcha_works{$1} = $2;
			next;
		}
	}
	close($langfile) or die "close: $!";
	my($l) = ($lang =~ /(^.+)\.json$/);
	$matcha_langs{$l} = { names => \%matcha_names, works => \%matcha_works };
}

for my $lang (sort keys %langs) {
	open(my $langfile, '>>', "$lang.json") or die "open (append) $lang.json: $!";
	my $blank_line = 0;
	my(@profs);
	if (@only_profs) {
		@profs = @only_profs;
	} else {
		@profs = sort keys %{$langs{$lang}{names}};
	}
	for my $prof (@profs) {
		# skip professions that already have a translation
		next if defined $matcha_langs{$lang}{works}{$prof};
		my $matcha_name = $matcha_langs{$lang}{names}{$prof};
		# skip professions that don't need a translation
		next unless defined $matcha_name;
		my $name = $langs{$lang}{names}{$prof};
		my $work = $langs{$lang}{works}{$prof};
		# skip names that don't have a profession subtitle
		next unless defined $work;
		my $orig_work = $work;

		# emit a blank line once, so we don't conflict with the JSON closed brace
		unless ($blank_line) {
			say $langfile '';
			$blank_line = 1;
		}

		# given the Minecraft profession subtitle:

		# - replace the Minecraft profession name with the Matcha name
		$work =~ s/$name/$matcha_name/;

		# - lowercase both names
		my $lcname = lc $name;
		my $matcha_lcname = lc $matcha_name;

		# - replace the lowercased minecraft profession name with the lowercased Matcha name
		$work =~ s/$lcname/$matcha_lcname/;

		# - did we end up making a change or not?
		my($comment_out, $xlate_help);
		if ($orig_work eq $work) {
			$comment_out = '##';
			$xlate_help = sprintf(' // LANG %s - MATCHA: %s - MINECRAFT: %s - WORK: %s', $lang, $matcha_name, $name, $orig_work);
		} else {
			$comment_out = '  ';
			$xlate_help = '';
		}

		# FIXME: print the result to stdout
		say $langfile sprintf('%s"%s": "%s",%s', $comment_out, "${k_work}_$prof", $work, $xlate_help);
	}
	close($langfile) or die "close (append) $lang.json: $!";
}
