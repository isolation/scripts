# announce your excellent music from your excellent music player
# requires Time::Duration module from CPAN
use strict;
use warnings;
use v5.10;
use utf8;
use Time::Duration qw(concise duration);
use Win32::OLE qw(CP_UTF8);
use Xchat qw(:all);

my $VERSION = "1.2";
register("itunes np", $VERSION, "itunes now playing script");
hook_command("NP", \&NowPlaying, {help_text => "Usage: NP, announces what is currently playing in iTunes"});
prnt("itunes np v" . $VERSION . " loaded");

Win32::OLE->Option(CP => CP_UTF8, Warn => \&OLEError);

sub OLEError {
	prnt("itunes np encountered a Win32::OLE error");
}

sub NowPlaying {
	my ($np) = new Win32::OLE("itunes.Application");
	
	my $is_playing = $np->PlayerState;
	if (!$is_playing) {
		prnt("iTunes is not playing anything");
		return EAT_ALL;
	}
	
	my $iTunes = $np->CurrentTrack;
	
	my $track = $iTunes->Name;
	my $artist = $iTunes->Artist;
	my $album = $iTunes->Album;
	my $play_count = $iTunes->PlayedCount;
	
	# protect formatting if album missing
	my $bum_msg = " ";
	$album and $bum_msg = " [" . $album . "] ";
	
	# enforce grammar for play count
	my $count_msg;
	if ($play_count eq "0") {
		$count_msg = "first play";
	} elsif ($play_count eq "1") {
		$count_msg = "1 play";
	} else {
		$count_msg = $play_count . " plays";
	}
	
	if ($play_count > 250) {
		my $time = $play_count * $iTunes->Duration;
		$count_msg .= " (" . concise(duration($time)) . ")";
	}
	
	command("ME np: " . $artist . " - " . $track . $bum_msg . "[" . $count_msg . "]");
	return EAT_ALL;
}