use strict; # strict keeps us from making stupid typos
use warnings; # helps us find problems in code
use diagnostics; # good for detailed explanations about any problems in code
use Socket; # networking constants and support functions
use IO::Select; # allows the user to see what IO handles, ready for reading, writing or have an exception pending

# Make sure server, port and CD-KEY are defined
if (!defined($ARGV[0])) { &die_nice("Server is not defined, please check your command line parameters."); }
if (!defined($ARGV[1])) { &die_nice("Port is not defined, please check your command line parameters."); }
if (!defined($ARGV[2])) { &die_nice("CD-KEY is not defined, please check your command line parameters."); }
if (!defined($ARGV[3])) { &die_nice("PBGUID is not defined, please check your command line parameters."); }

my $masterserver = 'cod2master.activision.com';
my $masterserverport = 20700;
my $server = $ARGV[0];
my $port = $ARGV[1];
my $cdkey = $ARGV[2];
$cdkey =~ s/-//g; # strip the Hyphen
my $cdkeypart = substr($cdkey, 0, 16);
my $pbguid = $ARGV[3];
my $masterstring = "\xff\xff\xff\xffgetKeyAuthorize 0 " . $cdkeypart . " PB " . $pbguid;
my $serverstring = "\xff\xff\xff\xff" . 'getchallenge 0 "' . $pbguid . '"';
my $d_ip;
my $portaddr;
my $message;
my $fakeplayer = 'Fake_Player # ' . int(rand(1000)); # randomize the names
my $maximum_lenth = 500;
my $challenge;

# Prepare the socket, udp protocol will be used
socket(SOCKET, PF_INET, SOCK_DGRAM, getprotobyname("udp")) or &die_nice("Socket error: $!");
my $selecta = IO::Select->new;
$selecta->add(\*SOCKET);

# Before we connect to a server, we need to authorize our CD-KEY on activision master server
$d_ip = gethostbyname($masterserver);
$portaddr = sockaddr_in($masterserverport, $d_ip);
send(SOCKET, $masterstring, 0, $portaddr) == length($masterstring) or &die_nice("Cannot send message");

# Now we need to get a challenge response from a server
$d_ip = inet_aton($server);
$portaddr = sockaddr_in($port, $d_ip);
send(SOCKET, $serverstring, 0, $portaddr) == length($serverstring) or &die_nice("Cannot send message");
$portaddr = recv(SOCKET, $message, $maximum_lenth, 0) or &die_nice("Socket error: recv: $!");

# Check if any errors has happend, maybe CD-KEY is in use already 
if ($message =~ /\xff\xff\xff\xffchallengeResponse ([\d\-]+)/) { }
elsif ($message =~ /\xff\xff\xff\xfferror\x0aEXE_ERR_CDKEY_IN_USE/) { &die_nice("CD-KEY is currently in use, please try again later.\n"); }
elsif ($message =~ /\xff\xff\xff\xffneedcdkey/) { &die_nice("CD-KEY is requied to use this program, check your parameters, or try run this script again.\n"); }
else { &die_nice("$message"); }

# We need to remember this challenge
$challenge = substr($message, 22, 20);

# We got the challenge, now send a connect string to bring our fake player on server
my $connectstring = ("\xff\xff\xff\xff" . 'connect "\\cg_predictItems\\1\\cl_anonymous\\0\\cl_voice\\1\\cl_allowDownload\\1\\rate\\25000\\snaps\\30\\name\\' . $fakeplayer . '\\protocol\\118\\challenge\\' . $challenge . '\\qport\\' . rand(65534) . '"');
$d_ip = inet_aton($server);
$portaddr = sockaddr_in($port, $d_ip);
send(SOCKET, $connectstring, 0, $portaddr) == length($connectstring) or &die_nice("Cannot send message");
$portaddr = recv(SOCKET, $message, $maximum_lenth, 0) or &die_nice("Socket error: recv: $!");

# Everything is good? Player should be now in CNCT state
if ($message =~ /\xff\xff\xff\xffconnectResponse/) { &die_nice("SUCCESS! $fakeplayer is now joining a server ($server:$port)\n"); }

# If not good, maybe server is full or we got a bad challenge
elsif ($message =~ /\xff\xff\xff\xfferror\x0aEXE_SERVERISFULL/) { &die_nice("Server is FULL, please try again later."); }
elsif ($message =~ /\xff\xff\xff\xfferror\x0aEXE_BAD_CHALLENGE/) { &die_nice("Bad challenge received, please try again later."); }
else { &die_nice("$message"); }

sub die_nice {
    my $message = shift;
    if ((!defined($message)) or ($message !~ /./)) { $message = 'default die_nice message.\n\n'; }
    print "\n$message\n\n";
    exit 1;
}