# Switch HP V1910-24G (JE006A) — SWPZCPD01

Levantamento feito em 10/10/2026 pela console serial, sem nenhuma alteração ou gravação de configuração.
A saída completa de cada comando está em `SWPZCPD01_captura_2026-10-10.txt`, nesta mesma pasta.

## 1. Conexão

| Item | Valor |
|---|---|
| Cabo | USB-serial CH340 (driver WCH 3.9.2024.9) |
| Porta | COM6 |
| Parâmetros | 38400 bps, 8 bits, sem paridade, 1 stop bit, sem controle de fluxo |

Observação: o `System.IO.Ports.SerialPort` do .NET (e, por consequência, alguns programas) falha ao abrir a COM6 com
"Um dispositivo conectado ao sistema não está funcionando". O `mode COM6` e o acesso direto via Win32 (`CreateFile`) funcionam.
O PuTTY ou o Tera Term devem abrir normalmente.

## 2. Comandos usados, em ordem

| # | Comando | O que faz | Altera config? |
|---|---|---|---|
| 1 | *(Enter)* | Acorda a console e mostra o prompt de login | Não |
| 2 | `admin` | Usuário padrão de fábrica | Não |
| 3 | `<REDACTED>` | Senha do usuário `admin` | Não |
| 4 | `_cmdline-mode on` | Libera todos os comandos CLI (o 1910 vem limitado) | Não, vale só para a sessão |
| 5 | `Y` | Confirma a pergunta "All commands can be displayed and executed. Continue?" | Não |
| 6 | `<REDACTED>` | Senha padrão do `_cmdline-mode` | Não |
| 7 | `screen-length disable` | Desliga a paginação ("---- More ----") só nesta sessão | Não |
| 8 | `undo terminal monitor` | Para de mostrar logs/traps na tela desta sessão | Não |
| 9 | `display version` | Versão do firmware, hardware e uptime | Não |
| 10 | `display current-configuration` | Configuração em execução | Não |
| 11 | `display interface brief` | Estado, velocidade e VLAN de cada porta | Não |
| 12 | `display vlan all` | VLANs e portas tagged/untagged | Não |
| 13 | `display ip interface brief` | Interfaces com IP | Não |
| 14 | `quit` | Encerra a sessão (logout) | Não |

Nenhum `system-view`, `save` ou comando de configuração foi executado.

## 3. Resumo da configuração

**Equipamento**
- Modelo: HP V1910-24G (24 portas GE + 4 SFP), hardware REV.B, Bootrom 163, CPLD 002
- Firmware: Comware 5.20, Release 1513P62
- Hostname: `SWPZCPD01`
- Uptime no momento: 1 semana, 4 dias, 16 h
- Relógio do switch está errado (marca maio de 2000); não há NTP configurado

**Gerência**
- IP: `192.168.1.50/22` (máscara 255.255.252.0, rede 192.168.0.0–192.168.3.255) na Vlan-interface1
- Gateway padrão: `192.168.1.254`
- Usuário local: `admin`, nível 3, serviços SSH, Telnet, terminal e web, senha `<REDACTED>`
- Console e VTY (Telnet/SSH) autenticam pelo esquema local (`authentication-mode scheme`)
- `password-recovery enable` ativo

**VLANs**
- VLAN 1 (padrão, onde fica o IP de gerência): portas 2, 3, 4, 6, 9, 10, 12, 15, 18, 19, 21, 22, 25–28 sem tag, e porta 24 sem tag
- VLAN 111 (sem IP no switch): portas 1, 5, 7, 8, 11, 13, 14, 16, 17, 20, 23 sem tag (access), e porta 24 com tag

**Uplink**
- Porta 24 em modo *hybrid*: VLAN 111 com tag e VLAN 1 sem tag. É o tronco natural para o roteador ou outro switch.

**Spanning Tree**
- RSTP ativo; todas as 28 portas marcadas como *edged-port* (porta de borda), inclusive a 24

**Estado das portas na hora da leitura**
- Ativas (1 Gbps full, VLAN 111): portas 1, 5, 7 e 11
- Todas as demais, incluindo a porta 24 de uplink, estão sem link

## 4. Pontos de atenção

1. **A gerência está inacessível pela rede agora.** A Vlan-interface1 está DOWN porque nenhuma porta da VLAN 1 tem link
   (a porta 24 de uplink está desconectada). Só a console funciona no momento.
2. **Credencial do usuário `admin` a revisar**, com Telnet e web habilitados. Recomendável definir uma senha forte e preferir SSH.
3. **Porta 24 (uplink) marcada como edged-port.** Se ela ligar outro switch, o ideal é tirar o `stp edged-port` dela para o RSTP proteger contra loop.
4. As portas 1, 5, 7 e 11 estão ativas na VLAN 111, mas como a porta 24 está sem link, esses equipamentos só conversam entre si.
5. Relógio desacertado (ano 2000), o que dificulta ler os logs.

Nenhum desses ajustes foi feito na leitura; veja a seção 5 para as alterações feitas depois, a pedido.

## 5. Alteração feita em 10/10/2026 (a pedido do Cláudio)

Pedido: apagar todas as VLANs e deixar tudo numa rede única, mudar o IP de gerência para 192.168.0.3 e marcar a porta 1 como uplink.
O log completo da sessão está em `SWPZCPD01_alteracao_2026-10-10.txt`.

**Decisões tomadas**
- Máscara mantida em /22 (255.255.252.0). Assim 192.168.0.3 continua na mesma rede do gateway 192.168.1.254 (rede 192.168.0.0 a 192.168.3.255).
- "Uplink" na porta 1 = descrição `UPLINK` e remoção do `stp edged-port`. Ela fica em VLAN 1 sem tag, como todas as outras.

**Comandos executados, em ordem**

```
admin / <REDACTED>
_cmdline-mode on
Y
<REDACTED>
screen-length disable
undo terminal monitor
dir
copy flash:/startup.cfg flash:/startup_bkp_20261010.cfg
Y
system-view
interface GigabitEthernet1/0/1     (repetido para 1, 5, 7, 8, 11, 13, 14, 16, 17, 20 e 23)
 undo port access vlan
 quit
interface GigabitEthernet1/0/24
 undo port hybrid vlan 111
 port link-type access
 quit
undo vlan 111
interface Vlan-interface1
 ip address 192.168.0.3 255.255.252.0
 quit
interface GigabitEthernet1/0/1
 description UPLINK
 undo stp edged-port
 quit
display vlan all
display interface brief
display ip interface brief
ping -c 3 192.168.1.254
save
Y
(Enter, mantém flash:/startup.cfg)
Y
quit
display saved-configuration
quit
```

**Resultado conferido**
- Só existe a VLAN 1, com as 28 portas sem tag (access).
- Vlan-interface1 está UP com 192.168.0.3/22.
- A porta 1 tem a descrição UPLINK, sem edged-port, ligada a 1 Gbps.
- A configuração foi salva no `startup.cfg` e confere com `display saved-configuration`.
- O ping para o gateway 192.168.1.254 não respondeu (3 de 3 perdidos).

**Troca do gateway (pedido seguinte)**

O gateway foi trocado de 192.168.1.254 para 192.168.0.1. Mesmo login e `_cmdline-mode on` de antes, depois:

```
system-view
undo ip route-static 0.0.0.0 0.0.0.0 192.168.1.254
ip route-static 0.0.0.0 0.0.0.0 192.168.0.1
display ip routing-table
ping -c 3 192.168.0.1
save
Y
(Enter)
Y
quit
display saved-configuration | include route-static
quit
```

Resultado: a rota padrão aponta para 192.168.0.1, o ping respondeu 3 de 3 (3 ms) e a configuração foi salva.

**Como desfazer**
O `startup.cfg` anterior ficou salvo na flash como `startup_bkp_20261010.cfg`. Para voltar:
`startup saved-configuration flash:/startup_bkp_20261010.cfg` e depois `reboot`.

## 6. SNMP e LLDP para o Net Inventory (10/10/2026, a pedido do Cláudio)

Motivo: o Net Inventory consulta SNMP com a community `<REDACTED>` e mostrava 192.168.0.3 como "sem resposta SNMP".
Antes da alteração o switch estava com `SNMP Agent disabled` e `Global status of LLDP: Disable`.
Log completo em `SWPZCPD01_snmp_2026-10-10.txt`.

**Achado antes de mexer:** o hostname em execução era `HPV191024GJE006A`, diferente do salvo (`SWPZCPD01`).
O log do switch mostra um login pela interface web vindo de 192.168.0.92 às 19:32 (relógio do switch), então a troca
foi feita pela web e ainda não estava salva. O relógio também passou a marcar a data certa.

**Comandos executados** (mesmo login e `_cmdline-mode on` das seções anteriores):

```
copy flash:/startup.cfg flash:/startup_bkp_pre_snmp_20261010.cfg
Y
system-view
snmp-agent                              (liga o agente SNMP)
snmp-agent sys-info version v1 v2c      (aceita SNMP v1 e v2c; o v3 continua ativo)
snmp-agent community read <REDACTED>        (community "<REDACTED>" somente leitura)
snmp-agent sys-info location CPD        (localização, aparece no sysLocation)
lldp enable                             (liga o LLDP global; as 28 portas já ficam em Tx_Rx)
quit
display snmp-agent sys-info
display snmp-agent community
display lldp status
```

**Teste feito deste PC** com o script `SWPZCPD01_teste_snmp.ps1` (SNMP v2c GET puro em PowerShell, sem instalar nada):

| OID | Resposta |
|---|---|
| sysDescr (1.3.6.1.2.1.1.1.0) | HP V1910-24G Switch Software Version 5.20, Release 1513P62 |
| sysName (1.3.6.1.2.1.1.5.0) | HPV191024GJE006A |
| sysLocation (1.3.6.1.2.1.1.6.0) | CPD |
| lldpLocSysName (1.0.8802.1.1.2.1.3.3.0) | HPV191024GJE006A |

Com a community errada (`xyz`) o switch não responde, como esperado.

Para repetir o teste: `powershell -ExecutionPolicy Bypass -File SWPZCPD01_teste_snmp.ps1 -Ip 192.168.0.3 -Community <REDACTED>`

**Segurança:** a community em uso é a padrão que qualquer scanner tenta. Como é só leitura, ninguém altera nada por ela,
mas qualquer máquina da rede consegue ler a configuração básica, as portas e a tabela MAC. Para endurecer depois:
trocar para uma community própria (no switch e no Net Inventory) e limitar quem pode consultar com uma ACL, por exemplo
`acl number 2000` / `rule permit source 192.168.0.92 0` / `snmp-agent community read <nome> acl 2000`.

**Gravação:** pendente. O SNMP e o LLDP já estão valendo na configuração em execução, mas ainda não foram salvos.
Um `save` também grava o novo hostname feito pela web. Sem salvar, tudo volta ao estado anterior se o switch reiniciar.

**Como desfazer:** `system-view`, `undo snmp-agent`, `undo lldp enable`. Se já tiver salvo, há o backup
`flash:/startup_bkp_pre_snmp_20261010.cfg`.
