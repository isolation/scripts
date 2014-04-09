# creates a window to showcase all of your highlights
use warnings;
use strict;
use Xchat qw(:all);

my $VERSION = "1.1";
register("hilightwin", $VERSION, "creates a tab to show all hilights");
hook_print("Channel Msg Hilight", \&do_hiwin, {priority => PRI_LOW});
hook_print("Channel Action Hilight", \&do_hiwin_act, {priority => PRI_LOW});
prnt("hilightwin v" . $VERSION . " loaded");
unless (find_context(undef, '@hilight')) {
	command('newserver -noconnect @hilight');
}

sub do_hiwin {
	prnt(format_other(get_info("network")) . "/" .
		format_other(get_info("channel")) . ": <" .
		format_nick($_[0][0], $_[0][2]) . "> " .
		$_[0][1], undef, '@hilight');
	return EAT_NONE;
}

sub do_hiwin_act {
	prnt(format_other(get_info("network")) . "/" .
		format_other(get_info("channel")) . ": * " .
		$_[0][0] . " " . $_[0][1], undef, '@hilight');
	return EAT_NONE;
}

sub format_nick {
	return ($_[1] ? $_[1] : " ") . "\x{03}" . get_xchat_color($_[0]) .
		$_[0] . "\x{03}";
}

sub format_other {
	return "\x{03}" . get_xchat_color($_[0]) . $_[0] . "\x{03}";
}

sub get_xchat_color {
	my @rcolors = ("19", "20", "22", "24", "25", "26", "27", "28", "29");
	my $sum = 0;
	$sum += ord $_ for (split "", $_[0]);
	return $rcolors[$sum % 9];
}