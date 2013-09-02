#!/usr/bin/perl
#
# Copyright (c) 2013 Jeff Green <jgreen@wikimedia.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
use strict;

# default location to write mail
my $Mbox = "/tmp/mbox";

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';
use Getopt::Long;
use Kernel::Config;
use Kernel::System::DB;
use Kernel::System::Encode;
use Kernel::System::Log;
use Kernel::System::Main;
use Kernel::System::Ticket;
use Kernel::System::Time;

# create common objects
my (%CommonObject,$Help,@TicketIDs,@TicketNumbers,@ArticleIDs);
$CommonObject{ConfigObject} = Kernel::Config->new();
$CommonObject{EncodeObject} = Kernel::System::Encode->new(%CommonObject);
$CommonObject{LogObject}    = Kernel::System::Log->new(
    LogPrefix => 'OTRS-otrs.TicketExport2Mbox.pl',
	%CommonObject,
);
$CommonObject{MainObject}   = Kernel::System::Main->new(%CommonObject);
$CommonObject{TimeObject}   = Kernel::System::Time->new(%CommonObject);
$CommonObject{DBObject}     = Kernel::System::DB->new(%CommonObject);
$CommonObject{TicketObject} = Kernel::System::Ticket->new(%CommonObject);

GetOptions(
	'help'                => \$Help,
	'mbox=s'              => \$Mbox,
	'TicketNumber=s{,}'   => \@TicketNumbers,
	'TicketID=s{,}'       => \@TicketIDs,
);

# when called from Generic Agent, ARG[0] is TicketNumber and ARG[1] is TicketID
if (($ARGV[0] =~ /^\d{16}/) and ($ARGV[1] =~ /^(\d+)/)) {
	my $TicketID = $1;
	chomp $TicketID;
	push @TicketIDs, $TicketID;
}

usage() if defined $Help;
usage() unless @TicketIDs or @TicketNumbers;

for my $TicketNumber (@TicketNumbers) {
	my $TicketID = $CommonObject{TicketObject}->TicketIDLookup(
		TicketNumber => $TicketNumber,
		UserID => 1,
		Silent => 0,
	);
	if (defined $TicketID) {
		push @TicketIDs, $TicketID;
	} else {
		printlog("Unable to find TicketNumber $TicketNumber.");	
	}
}

for my $TicketID (@TicketIDs) {
	my %Ticket = $CommonObject{TicketObject}->TicketGet(
		TicketID => $TicketID,
		UserID    => 1,
		Silent    => 0,
	);
	# this is a horrible quick & dirty hack to skip messages that appear to have been
	# automatically queued into Junk
	if (($Ticket{'Queue'} eq 'Junk') and ($Ticket{'Changed'} eq $Ticket{'Created'})) {
		printlog("Skip TicketID $TicketID, it was already autoqueued to Junk.",'debug');
	} else {
		my @TicketArticleIds = $CommonObject{TicketObject}->ArticleIndex(
			TicketID => $TicketID,
			UserID => 1,
			Silent => 0,
		);
		if (@TicketArticleIds) {
			for my $ArticleID (@TicketArticleIds) {
				printArticle($ArticleID);
			}
		} else {
			printlog("Unable to find articles for TicketID $TicketID.");
		}
	}
}

exit;

sub printArticle {
	my $ArticleID = shift;
	my $PlainMessage = $CommonObject{TicketObject}->ArticlePlain(
		ArticleID => $ArticleID,
		UserID => 1,
		Silent => 0,
	);
	if (defined $PlainMessage) {
		my $CleanPlainMessage = cleanupArticle($PlainMessage);
		if (open MBOX, ">> $Mbox") {
			print MBOX "$CleanPlainMessage\n";
			close MBOX;
			printlog("ArticleID $ArticleID written to $Mbox.",'debug');
		} else {
			printlog("can't write to $Mbox.",'error');
			exit;
		}
	} else {
		printlog("No plain message found for ArticleID $ArticleID.");
	}
}

sub usage {
	print "\notrs.TicketExport2Mbox.pl - export messages to mbox format.\n\n" .
		"Usage:\n\n" .
		"$0 [TicketNumber] [TicketID]\n\n" .
		"  ~OR~\n\n" . 
		"$0 [options]\n" .
		"  --help                          display this option help\n" .
		"  --mbox /path/to/mbox            mbox output file (default $Mbox)\n" .
		"  --TicketID no1 no2 no3          export messages by TicketID\n" .
		"  --TicketNumber no1 no2 no3      export messages by TicketNumber\n\n";
    exit;
}

# otrs messes with multiline headers, undo that
sub cleanupArticle {
	my $msg;
	my $position = 'head';
	for my $line (split /^/, shift) {
		if ($line =~ /^$/) {
			$position = 'body';
		} elsif ($position eq 'head') {
			$line =~ s/(\t+)/\n$1/g;
		}
		$msg .= $line;
	}
	return $msg;
}

sub printlog {
    my $msg = $_[0] ? $_[0] : '';
    my $priority = $_[1] ? $_[1] : 'notice';
	$CommonObject{LogObject}->Log(
		Priority => $priority,
		Message  => $msg,
	);
}
