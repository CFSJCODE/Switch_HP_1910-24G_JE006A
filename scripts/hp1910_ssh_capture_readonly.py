# Captura somente leitura da HP V1910-24G via SSH (paramiko). Nenhum comando de alteracao.
import paramiko, time, re, sys, os

OUT = sys.argv[1]
HOST = os.environ.get("HP1910_HOST", "192.168.0.3")
USER = os.environ.get("HP1910_USER", "admin")
PASSWORD = os.environ.get("HP1910_PASSWORD", "")
CMDLINE_PASSWORD = os.environ.get("HP1910_CMDLINE_PASSWORD", "")
PROMPT = re.compile(r"[<\[][^\r\n<>\[\]]+[>\]]\s*$")
MORE = re.compile(r"-+\s*More\s*-+")

t = paramiko.Transport((HOST, 22))
sec = t.get_security_options()
sec.kex = tuple(sec.kex) + ("diffie-hellman-group1-sha1",) if "diffie-hellman-group1-sha1" not in sec.kex else sec.kex
t.connect()
try:
    t.auth_password(USER, PASSWORD)
except paramiko.ssh_exception.BadAuthenticationType:
    t.auth_none(USER)
if not t.is_authenticated():
    t.auth_none(USER)
ch = t.open_session(); ch.get_pty(width=200, height=1000); ch.invoke_shell()

def read_until(pats, timeout=30):
    buf = ""; last = time.time()
    while time.time() - last < timeout:
        if ch.recv_ready():
            d = ch.recv(65535).decode("latin-1"); buf += d; last = time.time()
            if MORE.search(d[-40:]):
                ch.send(" ")
                continue
            if any(p.search(buf) for p in pats):
                return buf
        else:
            time.sleep(0.1)
    return buf

def clean(s):
    s = re.sub(r"-+\s*More\s*-+", "", s)
    s = re.sub(r"\x1b\[\d*[A-Za-z]", "", s)
    s = re.sub(r"\x1b\[\d+D", "", s)
    return s.replace("\r", "")

ch.send("\r"); read_until([PROMPT], 8)
ch.send("_cmdline-mode on\r")
r = read_until([re.compile(r"\[Y/N\]"), PROMPT], 6)
if "[Y/N]" in r:
    ch.send("Y\r"); r = read_until([re.compile("assword"), PROMPT], 6)
if "assword" in r:
    ch.send(CMDLINE_PASSWORD + "\r"); read_until([PROMPT], 6)
ch.send("screen-length disable\r"); read_until([PROMPT], 6)

cmds = {
    "display_version.txt": "display version",
    "display_device_manuinfo.txt": "display device manuinfo",
    "display_current-configuration.txt": "display current-configuration",
    "display_saved-configuration.txt": "display saved-configuration",
    "display_interface_brief.txt": "display interface brief",
    "display_dir_flash.txt": "dir flash:/",
    "display_vlan_all.txt": "display vlan all",
    "display_ip_interface_brief.txt": "display ip interface brief",
    "display_clock.txt": "display clock",
    "display_mac-address.txt": "display mac-address",
    "display_logbuffer.txt": "display logbuffer",
    "display_startup.txt": "display startup",
}
os.makedirs(OUT, exist_ok=True)
for fn, c in cmds.items():
    ch.send(c + "\r")
    r = read_until([PROMPT], 60)
    open(os.path.join(OUT, fn), "w", encoding="utf-8", newline="\n").write(clean(r))
    print(fn, len(r))

# lista de .cfg na flash
dirout = open(os.path.join(OUT, "display_dir_flash.txt"), encoding="utf-8").read()
cfgs = sorted(set(re.findall(r"(\S+\.cfg)\s*$", dirout, re.M)))
print("cfgs:", cfgs)
for f in cfgs:
    ch.send(f"more flash:/{f}\r")
    r = read_until([PROMPT], 60)
    open(os.path.join(OUT, "flash_" + f), "w", encoding="utf-8", newline="\n").write(clean(r))
    print(f, len(r))
ch.send("quit\r"); time.sleep(0.5); t.close()
