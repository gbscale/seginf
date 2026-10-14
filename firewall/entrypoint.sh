#!/bin/sh

# 1. Habilitar IP Forwarding (Repasse de pacotes)[cite: 2]
echo 1 > /proc/sys/net/ipv4/ip_forward

# 2. Limpar regras existentes nas tabelas
iptables -F
iptables -t nat -F
iptables -X

# 3. Definir políticas padrão como DROP (Segurança por padrão)[cite: 1, 2]
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 4. Permitir tráfego loopback e conexões já estabelecidas (Stateful)[cite: 2]
iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 5. Regras para a DMZ:
# Permitir que a Rede Cliente acesse o Servidor Web na DMZ (Portas HTTP/HTTPS)
iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 192.168.20.10 --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 192.168.20.10 --dport 443 -j ACCEPT

# Permitir comunicação interna da DMZ (Servidor Web acessando o Banco de Dados PostgreSQL)
iptables -A FORWARD -p tcp -s 192.168.20.10 -d 192.168.20.20 --dport 5432 -j ACCEPT

# Bloqueio explícito: Rede Cliente tentando acessar o Banco de Dados diretamente (DROP implícito pela política padrão, mas documentado/reforçado se necessário)

# Manter o container rodando
tail -f /dev/null