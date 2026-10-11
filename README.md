# HP V1910-24G (JE006A) · HPV191024GJE006A

[![Firmware](https://img.shields.io/badge/firmware-R1513P62-0096D6)](captura/2026-10-11/display_version.txt)
[![Plataforma](https://img.shields.io/badge/plataforma-Comware%205.20-01A982)](captura/2026-10-11/display_version.txt)
[![Modelo](https://img.shields.io/badge/modelo-JE006A%2024G%2B4SFP-555555)](captura/2026-10-11/display_device_manuinfo.txt)
[![Status](https://img.shields.io/badge/status-em%20produ%C3%A7%C3%A3o-brightgreen)](#estado-atual)
[![Último backup](https://img.shields.io/badge/%C3%BAltimo%20backup-2026--10--11-blue)](config/backups-flash/)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-yellow)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](scripts/hp1910-capture.ps1)
[![SSH](https://img.shields.io/badge/SSH-paramiko%203.5.1-3776AB?logo=python&logoColor=white)](scripts/hp1910_ssh_capture_readonly.py)

Configuração, backups, capturas de CLI e histórico de alterações do switch gerenciável que atende o CPD. Tudo aqui foi coletado em modo somente leitura (SSH ou console) e serve como referência para auditoria e restauração.

> **Dados sensíveis redigidos.** Este repositório é público. A community SNMP, a senha do usuário `admin` e a senha do `_cmdline-mode` foram trocadas por `<REDACTED>` em todas as cópias versionadas. Certificados (`.p12`), firmware (`.bin`) e o manual da HPE (`.pdf`) ficam fora do Git pelo [`.gitignore`](.gitignore). Os originais completos existem apenas na máquina local.

## Sumário

- [Identificação](#identificação)
- [Topologia](#topologia)
- [Estado atual](#estado-atual)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Acesso por SSH](#acesso-por-ssh)
- [Restaurar um backup](#restaurar-um-backup)
- [Histórico de alterações](#histórico-de-alterações)
- [Pendências](#pendências)
- [Segurança](#segurança)

## Identificação

| Item | Valor |
|---|---|
| Modelo | HP V1910-24G, part number JE006A (24 × GE + 4 × SFP), hardware REV.B |
| Serial | CN41BX29CZ |
| MAC base | 4431-9208-BB92 |
| Fabricação | 2014-02-05 |
| Software | Comware 5.20 Release 1513P62 (`flash:/v1910-cmw520-r1513p62.bin`), Bootrom 163, CPLD 002 |
| Memória | 128 MB DRAM, 128 MB NAND (97 920 KB de flash, 77 222 KB livres) |
| Hostname | `HPV191024GJE006A` (backups antigos usam `SWPZCPD01`) |
| Gerência | `192.168.0.3/24` na `Vlan-interface1`, rota padrão para `192.168.0.1` |
| Localização SNMP | `CPD` |

## Topologia

```
                 Internet
                    │
            ┌───────┴────────┐
            │  Modem ARRIS   │ 192.168.0.1 (gateway)
            └───────┬────────┘
                    │ GE1/0/1 (uplink)
   ┌────────────────┴──────────────────────────────┐
   │ HP V1910-24G  ·  HPV191024GJE006A  ·  .0.3/24 │
   └──┬──────────┬──────────┬──────────┬───────────┘
GE1/0/2      GE1/0/3    GE1/0/4    GE1/0/5
D-Link       DVR        Impressora PC i5-3330
DIR-3040 (AP)
```

Rede única em VLAN 1 (`192.168.0.0/24`), sem trunks.

## Estado atual

Verificado em 2026-10-11 por [`display interface brief`](captura/2026-10-11/display_interface_brief.txt) e [`display current-configuration`](config/atual/display_current-configuration.txt).

| Porta | Descrição | Estado | Velocidade | Observações |
|---|---|---|---|---|
| GE1/0/1 | `UPLINK modem` | UP | 1G full | sem `edged-port` (protegida pelo RSTP) |
| GE1/0/2 | `D-Link DIR-3040` | UP | 1G full | access point |
| GE1/0/3 | `DVR` | UP | 1G full | `edged-port` |
| GE1/0/4 | `impressora` | UP | 1G full | `edged-port` |
| GE1/0/5 | `i5-3330` | UP | 100M full | ver [pendências](#pendências) |
| GE1/0/6 a 1/0/24 | `NAO_USADA` | `shutdown` | — | `edged-port`, `broadcast-suppression 5` |
| GE1/0/25 a 1/0/28 (SFP) | `NAO_USADA` | `shutdown` | — | sem `auto-power-down` (não suportado) |

Configuração global relevante:

| Recurso | Estado |
|---|---|
| VLAN | apenas VLAN 1, todas as portas em access |
| Economia de energia | `port auto-power-down` nas portas 1 a 24 |
| Broadcast storm | `broadcast-suppression 5` nas portas 2 a 28 |
| Spanning Tree | RSTP habilitado; `stp edged-port enable` nas portas 3 a 28 |
| LLDP | habilitado globalmente |
| SNMP | agente ligado, v1/v2c/v3, community somente leitura (`<REDACTED>`) |
| HTTP | porta 80, Running (padrão do Comware, não aparece na config) |
| HTTPS | porta 443, Running (`ip https enable`), apenas TLS legado |
| SSH | `ssh server enable`, VTY 0-15 com `authentication-mode scheme` |
| Boot | `flash:/startup.cfg` (atual e próximo boot); configuração salva igual à em execução |

## Estrutura do repositório

```
.
├── captura/
│   └── 2026-10-11/           # saídas de display (version, manuinfo, interface brief,
│                             # dir flash, vlan, ip http/https, snmp, mac-address, clock, startup)
├── config/
│   ├── atual/                # current-configuration, saved-configuration e startup.cfg
│   └── backups-flash/        # cópias dos .cfg de backup existentes na flash do switch
├── docs/
│   └── projeto-SWPZCPD01/    # levantamento inicial, comandos usados e resumos das alterações
├── logs/                     # logbuffer do switch e sessão do ajuste de energia/portas
├── scripts/                  # captura somente leitura (console serial e SSH)
├── LICENSE
└── README.md
```

| Arquivo | Conteúdo |
|---|---|
| `config/atual/startup.cfg` | Arquivo de boot atual (`more flash:/startup.cfg`, 2026-10-11 02:23) |
| `config/backups-flash/startup_bkp_20261010.cfg` | Antes da limpeza de VLANs (2026-10-10) |
| `config/backups-flash/startup_bkp_pre_snmp_20261010.cfg` | Antes de ativar SNMP/LLDP (2026-10-10 19:40) |
| `config/backups-flash/startup_bkp_20261011.cfg` | Backup de 2026-10-11 00:25 |
| `config/backups-flash/startup_bkp_pre_energia_20261011.cfg` | Antes do ajuste de energia e portas (2026-10-11 02:19) |
| `logs/switch_logbuffer_20261011.txt` | `display logbuffer` |
| `logs/switch_energia_portas_20261011.log` | Sessão completa do ajuste de energia e shutdown das portas 6 a 28 |
| `scripts/hp1910-capture.ps1` | Captura somente leitura pela console serial (PowerShell) |
| `scripts/hp1910_ssh_capture_readonly.py` | Captura somente leitura via SSH (paramiko), gera `config/` e `captura/` |

Os `.cfg` foram obtidos com `more flash:/<arquivo>` e gravados como texto, com a linha do comando no topo e o prompt no fim. Servem para leitura e restauração manual, mas não são cópias byte a byte da flash.

## Acesso por SSH

O Comware 5.20 só oferece algoritmos legados. No OpenSSH do Windows 10/11:

```powershell
ssh -o KexAlgorithms=+diffie-hellman-group1-sha1 `
    -o HostKeyAlgorithms=+ssh-rsa `
    -o PubkeyAcceptedAlgorithms=+ssh-rsa `
    -o MACs=+hmac-sha1 `
    -c aes128-cbc `
    admin@192.168.0.3
```

O 1910 vem com a CLI limitada. Para liberar todos os comandos na sessão:

```
_cmdline-mode on
Y
<senha do _cmdline-mode>
screen-length disable
```

Captura automática via Python (paramiko 3.5.1). As credenciais vêm de variáveis de ambiente e nunca ficam no código:

```powershell
pip install paramiko==3.5.1
$env:HP1910_PASSWORD = '...'           # senha do admin
$env:HP1910_CMDLINE_PASSWORD = '...'   # senha do _cmdline-mode
python scripts\hp1910_ssh_capture_readonly.py captura\AAAA-MM-DD
```

Pela console serial (38400 8N1, sem controle de fluxo):

```powershell
$env:HP1910_CMDLINE_PASSWORD = '...'
powershell -ExecutionPolicy Bypass -File scripts\hp1910-capture.ps1 -Port COM6 -CmdlineMode
```

## Restaurar um backup

Os backups listados em `config/backups-flash/` também existem na flash do switch (`dir flash:/`). Os arquivos versionados têm segredos redigidos; antes de enviar um deles ao switch, recoloque os valores reais e remova a primeira linha (`more flash:/...`) e o prompt final.

**A partir de um arquivo que já está na flash:**

```
startup saved-configuration flash:/startup_bkp_pre_energia_20261011.cfg
display startup
reboot
```

**A partir do PC, por TFTP** (servidor TFTP rodando no PC, por exemplo `192.168.0.92`):

```
tftp 192.168.0.92 get startup_restaurado.cfg flash:/startup_restaurado.cfg
startup saved-configuration flash:/startup_restaurado.cfg
reboot
```

Para voltar ao arquivo atual: `startup saved-configuration flash:/startup.cfg` e `reboot`.

## Histórico de alterações

| Data | Alteração | Backup antes | Registro |
|---|---|---|---|
| 2026-10-10 | Levantamento inicial pela console (sem alterações) | — | [`SWPZCPD01_captura_2026-10-10.txt`](docs/projeto-SWPZCPD01/SWPZCPD01_captura_2026-10-10.txt) |
| 2026-10-10 | Limpeza inicial: VLAN 111 removida, todas as portas na VLAN 1, IP de gerência `192.168.0.3`, GE1/0/1 como uplink, gateway trocado para `192.168.0.1`, hostname `HPV191024GJE006A` | `startup_bkp_20261010.cfg` | [`SWPZCPD01_alteracao_2026-10-10.txt`](docs/projeto-SWPZCPD01/SWPZCPD01_alteracao_2026-10-10.txt) |
| 2026-10-10 | SNMP v1/v2c somente leitura, location `CPD`, LLDP ligado | `startup_bkp_pre_snmp_20261010.cfg` | [`SWPZCPD01_comandos_e_resumo-20261010T224329-dab9.md`](docs/projeto-SWPZCPD01/SWPZCPD01_comandos_e_resumo-20261010T224329-dab9.md) |
| 2026-10-11 | 00:25: máscara de gerência ajustada para /24 e hostname gravado. 02:08: interface web HTTP religada (`ip http enable`); HTTPS segue ativo (`ip https enable`) | `startup_bkp_20261011.cfg` | [`switch_logbuffer_20261011.txt`](logs/switch_logbuffer_20261011.txt) |
| 2026-10-11 | `auto-power-down` nas portas 1 a 24, descrições das portas 1 a 5, portas 6 a 28 em `shutdown` com descrição `NAO_USADA`, configuração salva | `startup_bkp_pre_energia_20261011.cfg` | [`switch_energia_portas_20261011.log`](logs/switch_energia_portas_20261011.log) |
| 2026-10-11 | 02:41 BRT: reboot autorizado para zerar os contadores SNMP `ifInErrors` das portas 11 e 13 (ping caiu às 02:41:23 e voltou às 02:43:49) | configuração já salva | registro externo ao repositório |

A captura em `captura/2026-10-11/` foi feita às 02:36 BRT, antes do reboot, por isso mostra uptime de 1 semana e 5 dias e o logbuffer não registra o evento.

## Pendências

- **Arquivos do laptop 6006U**: `ajuste_switch_hp1910.ps1`, o log correspondente e `change_mask.ps1` ainda não foram trazidos (o 6006U estava offline no Tailscale em 2026-10-11). Quando voltar, copiar para `scripts/` e `logs/`.
- **GE1/0/5 a 100 Mbps**: o PC i5-3330 negociou 100M na captura. Conferir a 1 Gbps com o PC ligado; se continuar em 100M, trocar o cabo ou verificar a placa de rede.

## Segurança

- Valores redigidos neste repositório: community SNMP, senha do `admin`, senha do `_cmdline-mode`. Procure por `<REDACTED>`.
- Nunca versione `flash:/https-server.p12`, `.pfx`, `.key` nem o firmware `.bin`.
- Melhorias recomendadas e ainda não aplicadas: senha forte para `admin`, desligar Telnet e HTTP (`undo ip http enable`), community SNMP própria com ACL (`acl number 2000` / `snmp-agent community read <nome> acl 2000`), NTP para manter o relógio certo.
- O switch fica na rede interna; não exponha as portas 22, 80, 443 ou 161 à internet.

## Licença

Scripts e documentação sob a licença [MIT](LICENSE). Comware e o manual do equipamento são da Hewlett Packard Enterprise.
