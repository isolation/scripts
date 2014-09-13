# sysinfo script for xchat
# full functionality on windows, partial functionality on linux
# required CPAN modules on linux: Time::Duration
# required CPAN modules on windows: Time::Duration, DateTime::Format::Strptime
use warnings;
use strict;
use POSIX qw(floor);
use Time::Duration qw(concise duration); # CPAN
use Xchat qw(:all);

my ($windows, $linux);
if ($^O eq "MSWin32") {
	$windows = 1;
} elsif ($^O eq "linux") {
	$linux = 1;
} else {
	prnt("This script does not support your detected OS: " . $^O);
}

if ($windows) {
	require Win32;
	require DateTime::Format::Strptime;
}

my $VERSION = "0.9.8";
register("psysinfo", $VERSION, "perl sysinfo script");
hook_command("PSYSINFO", \&sysinfo);
hook_command("PMEMINFO", \&single_mem);
# i haven't made these commands fully work on linux yet
if ($windows) {
	hook_command("PCPUINFO", \&single_cpu);
	hook_command("POSINFO", \&single_os);
	hook_command("PDISKINFO", \&single_disk);
	hook_command("PVIDEOINFO", \&single_video);
	hook_command("PMBINFO", \&single_mobo);
}
prnt("psysinfo v" . $VERSION . " loaded");

# things surrounding name of each piece of info
my $PRE = "\x{02}\x{03}03";
my $POST = "\x{03}\x{02}";

# these are out here for caching
my ($cpu_name, $gpu_name, $epoch_bt, $os_string, $os_install, $mobo);

# command: PSYSINFO
sub sysinfo {
	my ($free_mem, $total_mem, $uptime, $total_disk, $free_disk, $wmi);

	if ($windows) {
		$wmi = Win32::OLE->GetObject("winmgmts://./root/cimv2");
	}

	# free/total memory
	if ($windows) {
		($free_mem, $total_mem) = win32_mem($wmi);
	} elsif ($linux) {
		($free_mem, $total_mem) = linux_mem();
	}

	# epoch time of system start
	unless ($epoch_bt) {
		if ($windows) {
			$epoch_bt = win32_bt_epoch($wmi);
		} elsif ($linux) {
			$epoch_bt = linux_bt_epoch();
		}
	}

	$uptime = concise(duration((time - $epoch_bt), "5"));
	# space the units out. this will have a leading space
	$uptime =~ s/(\d+[a-z])/ $1/g;

	# cpu model name
	unless ($cpu_name) {
		if ($windows) {
			$cpu_name = win32_cpu_name($wmi);
		} elsif ($linux) {
			$cpu_name = linux_cpu_name();
		}
        }
		
	# gpu model name
	unless ($gpu_name) {
		if ($windows) {
			$gpu_name = win32_gpu_name($wmi);
		} elsif ($linux) {
			$gpu_name = linux_gpu_name();
		}
	}

	# total / free disk space
	if ($windows) {
		($total_disk, $free_disk) = win32_disk_info($wmi);
	} elsif ($linux) {
		($total_disk, $free_disk) = linux_disk_info();
	}

	# OS version number
	unless ($os_string) {
		if ($windows) {
			$os_string = win32_os_string();
		} elsif ($linux) {
			$os_string = linux_os_string();
		}
	}

	command("SAY " .
		$PRE . "os" . $POST . "[" . $os_string . "] " .
		$PRE . "cpu" . $POST . "[" . $cpu_name . "] " .
		$PRE . "mem" . $POST . "[Physical: " . $total_mem . " MB, " . $free_mem . " MB Free] " .
		$PRE . "disk" . $POST . "[Total: " . $total_disk . " GB, " . $free_disk . " GB Free] " .
		$PRE . "video" . $POST . "[" . $gpu_name . "] " .
		$PRE . "uptime" . $POST . "[Current:" . $uptime . "]");

	return EAT_ALL;
}

# command: POSINFO
sub single_os {
	unless ($os_install) {
		if ($windows) {
			$os_install = win32_install_date(Win32::OLE->GetObject("winmgmts://./root/cimv2"));
		} elsif ($linux) {
			$os_install = linux_install_date();
		}
	}
	
	unless ($os_string) {
		if ($windows) {
			$os_string = win32_os_string();
		} elsif ($linux) {
			$os_string = linux_os_string();
		}
	}
	
	command ("SAY " . $PRE . "os" . $POST . "[" . $os_string . " | Installed: " .
		scalar localtime($os_install) . "]");
	return EAT_ALL;
}

# command: PCPUINFO
sub single_cpu {
	my ($cpu_count, $cpu_load);
	if ($windows) {
		($cpu_name, $cpu_count, $cpu_load) = win32_cpu_full(Win32::OLE->GetObject("winmgmts://./root/cimv2"));
	} elsif ($linux) {
		($cpu_name, $cpu_count, $cpu_load) = linux_cpu_full();
	}

	command("SAY " . $PRE . "cpu" . $POST . "[" . $cpu_count . " x " . $cpu_name .
		" | Load: " . $cpu_load . "%]");
	return EAT_ALL;
}

# command: PMEMINFO
sub single_mem {
	my ($total_mem, $free_mem);

	if ($windows) {
		($free_mem, $total_mem) = win32_mem(Win32::OLE->GetObject("winmgmts://./root/cimv2"));
	} elsif ($linux) {
		($free_mem, $total_mem) = linux_mem();
	}

	command("SAY " .
		$PRE . "mem" . $POST . "[Physical: " . $total_mem . " MB, " . $free_mem .
		" MB Free | Load: " . sprintf('%d', (($total_mem - $free_mem) / $total_mem) * 100) .
		"%]");
	return EAT_ALL;
}

# command: PDISKINFO
sub single_disk {
	my ($total_disk, $free_disk, @drives);
	my $wmi = Win32::OLE->GetObject("winmgmts://./root/cimv2");
	if ($windows) {
		($total_disk, $free_disk) = win32_disk_info($wmi);
	} elsif ($linux) {
		($total_disk, $free_disk) = linux_disk_info();
	}

	if ($windows) {
		win32_disk_array($wmi, \@drives);
	} elsif ($linux) {
		linux_disk_array(\@drives);
	}
	
	command("SAY " . $PRE . "disk" . $POST . "[Total: " . $total_disk . " GB, " .
		$free_disk . " GB Free (" . join(' ', @drives) . ")]");
	return EAT_ALL;
}

# command PVIDEOINFO
sub single_video {
	my $wmi = Win32::OLE->GetObject("winmgmts://./root/cimv2");
	my ($monitor, $resolution);
	unless ($gpu_name) {
		if ($windows) {
			$gpu_name = win32_gpu_name($wmi);
		} elsif ($linux) {
			$gpu_name = linux_gpu_name();
		}
	}

	if ($windows) {
		($monitor, $resolution) = win32_monitor_info($wmi);
	} elsif ($linux) {
		($monitor, $resolution) = linux_monitor_info();
	}

	command("SAY " . $PRE . "video" . $POST . "[" . $monitor . " on " .
		$gpu_name . " @ " . $resolution . "]");
	return EAT_ALL;
}

# command PMBINFO
sub single_mobo {
	unless ($mobo) {
		if ($windows) {
			$mobo = win32_mobo_name(Win32::OLE->GetObject("winmgmts://./root/cimv2"));
		} elsif ($linux) {
			$mobo = linux_mobo_name();
		}
	}
	
	command("SAY " . $PRE . "motherboard" . $POST . "[" . $mobo . "]");
	return EAT_ALL;
}

sub win32_bt_epoch {
	return time - (Win32::GetTickCount() / 1000);
}

sub linux_bt_epoch {
	return `sed -n '/^btime /s///p' /proc/stat`;
}

sub win32_mem {
	my ($wmi) = @_;
	my ($free_mem, $total_mem);
	# class: Win32_OperatingSystem
	# info: free physical memory, total physical memory
	# variables: $free_mem, $total_mem
	for (Win32::OLE::in $wmi->InstancesOf("Win32_OperatingSystem")) {
		($free_mem, $total_mem) = (floor($_->{FreePhysicalMemory} / 1024),
			floor($_->{TotalVisibleMemorySize} / 1024));
	}
	return ($free_mem, $total_mem);
}

sub linux_mem {
	my ($total_mem, $free_mem);
	my $meminfo_snap = `cat /proc/meminfo`;
	for (split /\n/, $meminfo_snap) {
		$total_mem = sprintf("%.0f", $1 / 1024) if (/^MemTotal:\s+(\d+)/);
		$free_mem = sprintf("%.0f", $1 / 1024) if (/^MemFree:\s+(\d+)/);
		$free_mem += sprintf("%.0f", $1 / 1024) if (/^Cached:\s+(\d+)/);
		$free_mem += sprintf("%.0f", $1 / 1024) if (/^Buffers:\s+(\d+)/);
	}
	return ($free_mem, $total_mem);

}

sub win32_cpu_name {
	my ($wmi) = @_;
	my $cpu_name;
	# class: Win32_Processor
	# info: CPU name
	# variables: $cpu_name
	prnt("Caching slow WMI info...");
	for (Win32::OLE::in $wmi->InstancesOf("Win32_Processor")) {
		$cpu_name = $_->{Name};
		last;
	}
	return $cpu_name;
}

sub linux_cpu_name {
	my $cpu_name = `sed -n '0,/^model name\t: /s///p' /proc/cpuinfo`;
	chomp($cpu_name);
	return $cpu_name;
}

sub win32_cpu_full {
	my ($wmi) = @_;
	my ($name, $count, $load);
	for (Win32::OLE::in $wmi->InstancesOf("Win32_Processor")) {
		$name = $_->{"Name"};
		$count = $_->{"NumberOfLogicalProcessors"};
		$load = $_->{"LoadPercentage"};
	}
	return ($name, $count, $load);
}

sub linux_cpu_full {
	return ("NTI", "NYI", "NYI");
}

sub win32_os_string {
	#return Win32::GetOSDisplayName();
	my @os_info = Win32::GetOSVersion();
	# [1] major . [2] minor
	my $os_string = "Windows " . $os_info[1] . "." . $os_info[2];
	# [5] is SP version number
	$os_info[5] and $os_string .= " SP" . $os_info[5];
	$os_string .= " (Build #" . $os_info[3] . ")";
}

sub linux_os_string {
	my $os_string = `cat /proc/version`;
	$os_string =~ s/^(\S+) \S+ (\S+) .*\n$/$1 $2/;
	return $os_string;
}

sub win32_disk_info {
	my ($wmi) = @_;
	my ($total_disk, $free_disk);
	# class: Win32_DiskPartition
	# info: total partitioned disk space
	# variable: $total_disk
	for (Win32::OLE::in $wmi->InstancesOf("Win32_LogicalDisk")) {
		if ($_->{DriveType} eq "3") {
			$total_disk += $_->{Size};
			$free_disk += $_->{FreeSpace};
		}
	}
	$total_disk /= (1024 ** 3);
	$total_disk = sprintf("%.02f", $total_disk);
	$free_disk /= (1024 ** 3);
	$free_disk = sprintf("%.02f", $free_disk);
	return ($total_disk, $free_disk);
}

sub linux_disk_info {
	my $total_disk = 0;
	my $free_disk = 0;
	for (`df 2>/dev/null`) {
		if (/^\/dev\/(mapper\/\S+|(s|h|x|xv)d[a-z]\d+)\s+(\d+)\s+\w+\s+(\d+)/) {
			$total_disk += $3;
			$free_disk += $4;
		}
	}
	$free_disk = sprintf("%.02f", $free_disk / 1048576);
	$total_disk = sprintf("%.02f", $total_disk / 1048576);
	return ($total_disk, $free_disk);
}

sub win32_gpu_name {
	my ($wmi) = @_;
	my $win_gpu;
	# class: Win32_VideoController
	# info: video adapter
	# variable: $gpu_name
	for (Win32::OLE::in $wmi->InstancesOf("Win32_VideoController")) {
		$win_gpu = $_->{Name};
		last;
	}
	return $win_gpu;
}

sub linux_gpu_name {
	my $lin_gpu = `lspci | grep 'VGA compatible controller'`;
	$lin_gpu =~ s/VGA Compatible controller: (.*)$/$1/;
	# abbreviate intel igpu names
	if ($lin_gpu =~ /(Intel Corporation \d+.. Gen)/) {
		$lin_gpu = $1 . " Graphics";
	}
	return $lin_gpu;
}

sub win32_install_date {
	my ($wmi) = @_;
	my $install_date;
	# class: Win32_OperatingSystem
	# info: install date
	# variable: $os_install
	for (Win32::OLE::in $wmi->InstancesOf("Win32_OperatingSystem")) {
		$install_date = $_->{"InstallDate"};
		last;
	}
	return win32_dt_to_epoch($install_date);
}

sub linux_install_date {
	return "install date unknown";
}

sub win32_disk_array {
	my ($wmi, $drives_ref) = @_;
	for (Win32::OLE::in $wmi->InstancesOf("Win32_LogicalDisk")) {
		if ($_->{DriveType} eq "3") {
			my $curr_drive = "[";
			$curr_drive .= $_->{"Name"};
			$curr_drive .= $_->{"VolumeName"} if $_->{"VolumeName"};
			$curr_drive .= "] ";
			
			my $curr_free = $_->{"FreeSpace"};
			$curr_free /= (1024 ** 3);
			$curr_drive .= sprintf("%.02f/", $curr_free);
			
			my $curr_size = $_->{"Size"};
			$curr_size /= (1024 ** 3);
			$curr_drive .= sprintf("%.02f GB", $curr_size);
			
			push(@$drives_ref, $curr_drive);
		}
	}
}

sub linux_disk_array {
	push($_[0], "not yet implemented");
}

sub win32_monitor_info {
	my ($wmi) = @_;
	my ($monitor, $resolution);
	for (Win32::OLE::in $wmi->InstancesOf("Win32_DesktopMonitor")) {
		$monitor = $_->{"Name"};
		$resolution = $_->{"ScreenWidth"} . "x" . $_->{"ScreenHeight"};
		last;
	}
	return ($monitor, $resolution);
}

sub linux_monitor_info {
	return ("not yet implemented", "not yet implemented");
}

sub win32_mobo_name {
	my ($wmi) = @_;
	my $mobo;
	for (Win32::OLE::in $wmi->InstancesOf("Win32_BaseBoard")) {
		$mobo = $_->{"Manufacturer"} . " " . $_->{"Product"};
	}
	return $mobo;
}

sub linux_mobo_name {
	return "not yet implemented";
}

sub win32_dt_to_epoch {
	my ($orig_dt) = @_;
	# pull the timezone offset off of the windows datetime format
	my ($tz_off) = $orig_dt =~ /([-+]\d+)$/;
	# now clear off everything after the yyyymmddhhmmss
	$orig_dt =~ s/\..*//;
	# prep a datetime parser
	my $parser = DateTime::Format::Strptime->new( pattern => "%Y%m%d%H%M%S" );
	my $dt = $parser->parse_datetime($orig_dt);
	# get the epoch time from the parser (still need tz offset)
	my $win_epoch = $dt->epoch;
	# now either add or remove as many seconds as dictated by the tz offset from earlier
	($tz_off =~ s/^\+//) and $win_epoch -= ($tz_off * 60);
	($tz_off =~ s/^\-//) and $win_epoch += ($tz_off * 60);
	return $win_epoch;
}
