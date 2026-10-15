# RELATÓRIO TÉCNICO DE INFRAESTRUTURA DE REDE E SEGURANÇA

## Implementação de Firewall Linux com Arquitetura Netfilter, Iptables e Segmentação via Docker

**Instituição:** Instituto Federal Goiano - Campus Ceres

**Curso:** Bacharelado em Sistemas de Informação

**Disciplina:** Segurança da Informação

**Docente:** Prof. Roitier Campos Gonçalves


---

## 1. Definição do Case

* **Empresa Simulada:** *MegaStore E-commerce S.A.*
* **Contexto do Negócio:** A MegaStore é uma plataforma de comércio eletrônico de médio porte responsável por processar pedidos de clientes, gerenciar um catálogo dinâmico de produtos e armazenar dados transacionais e confidenciais.
* **Serviços Operacionais e Topologia:**
* **Rede Cliente (Intranet / LAN Interna):** Estações de trabalho utilizadas por colaboradores do setor administrativo e de suporte que necessitam acessar os sistemas internos de gerenciamento da empresa.
* **Zona Desmilitarizada (DMZ - Web):** Servidor Nginx que hospeda a interface pública da loja virtual e as APIs de atendimento.
* **Zona de Backend (Banco de Dados Isolado):** Servidor PostgreSQL contendo o banco de dados transacional da empresa, segregado da rede externa e da rede de funcionários.
* **Gateway / Firewall de Borda:** Container isolado com privilégios administrativos (`NET_ADMIN`) que intermedeia o tráfego entre a rede interna e a DMZ, aplicando o mecanismo de filtragem de pacotes do kernel Linux (`Netfilter` / `iptables`).





---

## 2. Diagnóstico: Cenário Atual vs. Proposta de Solução

### 2.1. Cenário Atual (Problemas Mapeados)

* **Redes Planas e Ausência de Segmentação:** Em ambientes legados sem segmentação, estações de trabalho e servidores críticos residem no mesmo domínio de broadcast ou possuem visibilidade irrecuperável entre si.
* **Riscos de Segurança:** Caso uma estação de trabalho de um colaborador seja comprometida (ex: via engenharia social ou malware), o invasor ganharia caminho livre para varrer e atacar diretamente o servidor de banco de dados na porta padrão (`5432`), culminando em vazamentos de dados em massa (*data breach*).
* **Falta de Controle Perimetral:** Ausência de regras de filtragem baseadas em estado de conexão e políticas restritivas por padrão.

### 2.2. Proposta de Solução (Hardening de Periferia)

* **Arquitetura de Três Camadas com DMZ:** Isolamento físico/lógico utilizando redes `bridge` personalizadas e segregadas do Docker.
* **Política Padrão Restritiva (`DROP`):** Atendimento estrito aos princípios fundamentais de segurança de redes e *hardening*, aplicando a diretriz do **Mínimo Privilégio** e **Superfície de Ataque Reduzida** (bloqueando todo o tráfego de passagem por padrão e liberando apenas fluxos estritamente necessários e justificados).


* **Rastreamento de Estados (Stateful Inspection):** Utilização dos estados do Netfilter (`ESTABLISHED`, `RELATED`) para permitir de forma eficiente o retorno de pacotes legítimos sem abrir portas desnecessárias.



---

## 3. Matriz de Regras de Segurança (Firewall / Netfilter)

A tabela abaixo detalha o mapeamento lógico e as regras de filtragem implementadas na chain `FORWARD` do firewall:

| Origem | Destino | Porta / Protocolo | Ação | Justificativa do Negócio |
| --- | --- | --- | --- | --- |
| **Rede Cliente (LAN)** | **DMZ (Web - Nginx)** | TCP 80 / 443 | **ACCEPT** | Permite que funcionários acessem o painel administrativo e os serviços web da empresa. |
| **Rede Cliente (LAN)** | **DMZ (Banco de Dados)** | TCP 5432 | **DROP** | Funcionários não devem acessar o banco de dados diretamente; o acesso ocorre exclusivamente de forma mediada pela aplicação web. |
| **DMZ (Web)** | **DMZ (Banco de Dados)** | TCP 5432 | **ACCEPT** | Permite que o servidor web realize consultas transacionais legítimas no banco de dados. |
| **Tráfego Inválido** | **Firewall / Redes** | - | **DROP** | Bloqueia pacotes corrompidos ou com estados inválidos de conexão (*Stateful*). |

---

## 4. Metodologia de Testes e Validação

O ambiente foi integralmente simulado por meio do Docker Compose, garantindo reprodutibilidade automatizada. O roteiro de validação abaixo comprova a eficácia das regras aplicadas:

### 4.1. Passo a Passo de Execução

No diretório raiz do projeto contendo o `docker-compose.yml`, suba o ambiente:

```bash
docker compose up -d --build

```

### 4.2. Testes Positivos (O que DEVE funcionar)

1. **Acesso da Rede Cliente ao Servidor Web na DMZ:**
* Entre no container cliente:
```bash
docker exec -it estacao-cliente sh

```


* Execute a requisição HTTP:
```bash
curl http://192.168.20.10

```


* **Resultado Observado:** O servidor retorna com sucesso o código HTML padrão de boas-vindas do Nginx (`Welcome to nginx!`), comprovando que o tráfego autorizado passa pelo firewall.


2. **Comunicação entre Web e Banco de Dados na DMZ:**
* A aplicação web consegue estabelecer conexão com o PostgreSQL na porta `5432`, conforme validado pelas regras de encaminhamento e teste de conectividade interna (`succeeded`).



### 4.3. Testes Negativos (O que DEVE ser bloqueado)

1. **Tentativa de Acesso Direto da Rede Cliente ao Banco de Dados:**
* A partir do container cliente (`estacao-cliente`), execute o teste de porta:
```bash
nc -zv 192.168.20.20 5432

```


* **Resultado Observado:** O comando resulta em `Operation timed out`, comprovando que a política padrão `DROP` do Netfilter barrou com sucesso a tentativa de acesso não autorizado à camada de dados.



---

## 5. Estrutura do Código e Arquivos do Projeto (Repositório Git)

### 5.1. `docker-compose.yml`

```yaml
version: '3.8'

networks:
  cliente_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.10.0/24
  dmz_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.20.0/24

services:
  firewall:
    build: ./firewall
    container_name: gateway-firewall
    cap_add:
      - NET_ADMIN
    networks:
      cliente_net:
        ipv4_address: 192.168.10.254
      dmz_net:
        ipv4_address: 192.168.20.254
    restart: unless-stopped

  cliente:
    image: alpine:latest
    container_name: estacao-cliente
    command: tail -f /dev/null
    networks:
      cliente_net:
        ipv4_address: 192.168.10.10
    depends_on:
      - firewall

  dmz-web:
    image: nginx:alpine
    container_name: servidor-web-dmz
    networks:
      dmz_net:
        ipv4_address: 192.168.20.10
    depends_on:
      - firewall

  dmz-db:
    image: postgres:alpine
    container_name: servidor-db-dmz
    environment:
      POSTGRES_PASSWORD: secretpassword
    networks:
      dmz_net:
        ipv4_address: 192.168.20.20
    depends_on:
      - firewall

```

### 5.2. `firewall/Dockerfile`

```dockerfile
FROM alpine:latest

RUN apk update && apk add --no-cache iptables iproute2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

```

### 5.3. `firewall/entrypoint.sh`

```sh
#!/bin/sh

# 1. Habilitar IP Forwarding no Kernel do Linux
echo 1 > /proc/sys/net/ipv4/ip_forward

# 2. Limpar regras existentes nas tabelas do Netfilter
iptables -F
iptables -t nat -F
iptables -X

# 3. Definir políticas padrão restritivas (DROP por padrão)[cite: 1, 2]
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 4. Tráfego de loopback e conexões já estabelecidas (Stateful Inspection)[cite: 2]
iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 5. Regras de liberação para a DMZ:
# Permitir que a Rede Cliente acesse o Servidor Web na DMZ (Portas HTTP/HTTPS)
iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 192.168.20.10 --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.10.0/24 -d 192.168.20.10 --dport 443 -j ACCEPT

# Permitir comunicação interna da DMZ (Servidor Web acessando o Banco de Dados PostgreSQL)
iptables -A FORWARD -p tcp -s 192.168.20.10 -d 192.168.20.20 --dport 5432 -j ACCEPT

# Manter o container gateway ativo
tail -f /dev/null

```

### 5.4. `README.md`

```markdown
# Firewall Linux, Arquitetura Netfilter & Iptables

Trabalho prático desenvolvido para a disciplina de **Segurança da Informação** do **IF Goiano - Campus Ceres**.  
**Docente:** Prof. Roitier Campos Gonçalves  

## Descrição
Simulação completa de um cenário real de e-commerce utilizando redes segmentadas em Docker, com um container de firewall aplicando regras estritas de `iptables` e políticas de `DROP` por padrão.

## Como Executar
1. Certifique-se de ter o Docker e o Docker Compose instalados.
2. Clone o repositório e acesse a pasta do projeto.
3. Suba o ambiente com o comando:
   ```bash
   docker compose up -d --build

```

4. Valide o funcionamento conforme descrito no relatório técnico.

```

```