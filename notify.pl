##
## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load notify
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
use HTML::Entities;

$VERSION = "0.5";
%IRSSI = (
    authors     => 'Luke Macken, Paul W. Frields',
    contact     => 'lewk@csh.rit.edu, stickster@gmail.com',
    name        => 'notify.pl',
    description => 'Use D-Bus to alert user to hilighted messages',
    license     => 'GNU General Public License',
    url         => 'http://code.google.com/p/irssi-libnotify',
);

Irssi::settings_add_str('notify', 'notify_remote', '');
Irssi::settings_add_str('notify', 'notify_debug', '');

# Send no more than one notification within the threshold interval (seconds)
Irssi::settings_add_int('notify', 'notify_threshold', 15);
my $last_notify_time = time();

sub sanitize {
  my ($text) = @_;
  encode_entities($text,'\'<>&');
  my $apos = "&#39;";
  my $aposenc = "\&apos;";
  $text =~ s/$apos/$aposenc/g;
  $text =~ s/"/\\"/g;
  $text =~ s/\$/\\\$/g;
  $text =~ s/`/\\"/g;
  return $text;
}

sub notify {
    my ($server, $summary, $message) = @_;

    # throttle notifications by the configured number of seconds
    return if ((time() - $last_notify_time) <
        Irssi::settings_get_int('notify_threshold'));

    # Make the message entity-safe
    $summary = sanitize($summary);
    $message = sanitize($message);

    my $debug = Irssi::settings_get_str('notify_debug');
    my $nodebugstr = '- ';
    if ($debug ne '') {
	$nodebugstr = '';
    }
    my $cmd = "EXEC " . $nodebugstr .
	" ~/bin/irssi-notifier.sh " .
	"dbus-send --session /org/irssi/Irssi org.irssi.Irssi.IrssiNotify" .
	" string:'" . $summary . "'" .
	" string:'" . $message . "'";
    $server->command($cmd);

    my $remote = Irssi::settings_get_str('notify_remote');
    if ($remote ne '') {
	my $cmd = "EXEC " . $nodebugstr . "ssh -q " . $remote . " \"".
	    " ~/bin/irssi-notifier.sh".
	    " dbus-send --session /org/irssi/Irssi org.irssi.Irssi.IrssiNotify" .
	    " string:'" . $summary . "'" .
	    " string:'" . $message . "'\"";
	#print $cmd;
	$server->command($cmd);
    }

    $last_notify_time = time();
}
 
sub print_text_notify {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};

    return if (!$server || !($dest->{level} & MSGLEVEL_HILIGHT));
    my $sender = $stripped;
    $sender =~ s/^\<.([^\>]+)\>.+/\1/ ;
    $stripped =~ s/^\<.[^\>]+\>.// ;
    my $summary = $dest->{target} . ": " . $sender;
    notify($server, $summary, $stripped);
}

sub message_private_notify {
    my ($server, $msg, $nick, $address) = @_;

    return if (!$server);

    # don't send notification if the message originates from the current window
    return if (Irssi::active_win()->{active}->{visible_name} eq $nick);

    notify($server, "PM from ".$nick, $msg);
}

sub dcc_request_notify {
    my ($dcc, $sendaddr) = @_;
    my $server = $dcc->{server};

    return if (!$dcc);
    notify($server, "DCC ".$dcc->{type}." request", $dcc->{nick});
}

Irssi::signal_add('print text', 'print_text_notify');
Irssi::signal_add('message private', 'message_private_notify');
Irssi::signal_add('dcc request', 'dcc_request_notify');

