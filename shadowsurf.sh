#!/usr/bin/env bash
# Creator: Bluuhaxor

set -Eeuo pipefail

INSTALL_DIR="/usr/local/bin"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[-] Please run this installer with sudo or as root."
  exit 1
fi

cat > "${INSTALL_DIR}/shadow-start" <<'EOF'
#!/usr/bin/env bash
# Creator: Bluuhaxor

set -Eeuo pipefail

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
RST='\033[0m'

TOR_SERVICE="tor@default"
TOR_UID="$(id -u debian-tor)"

msg()  { echo -e "${BLU}[*]${RST} $*"; }
ok()   { echo -e "${GRN}[+]${RST} $*"; }
warn() { echo -e "${YEL}[!]${RST} $*"; }
err()  { echo -e "${RED}[-]${RST} $*"; }

cleanup_on_error() {
    err "Error while enabling routing. Restoring permissive firewall state."
    iptables -F || true
    iptables -t nat -F || true
    iptables -X || true
    iptables -P INPUT ACCEPT || true
    iptables -P FORWARD ACCEPT || true
    iptables -P OUTPUT ACCEPT || true

    ip6tables -F || true
    ip6tables -X || true
    ip6tables -P INPUT ACCEPT || true
    ip6tables -P FORWARD ACCEPT || true
    ip6tables -P OUTPUT ACCEPT || true
}
trap cleanup_on_error ERR

banner() {
cat <<'BANNER'

  ____  _               _              ____              __
 / ___|| |__   __ _  __| | _____      / ___| _   _ _ __ / _|
 \___ \| '_ \ / _` |/ _` |/ _ \ \ /\ / / _ \| | | | '__| |_
  ___) | | | | (_| | (_| | (_) \ V  V / (_) | |_| | |  |  _|
 |____/|_| |_|\__,_|\__,_|\___/ \_/\_/ \___/ \__,_|_|  |_|

                 ShadowSurf for KALI

     transparent Tor routing for local host
              Creator: Bluuhaxor
BANNER
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        err "Please run this script as root or with sudo."
        exit 1
    fi
}

save_rules() {
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
}

tor_ready() {
    journalctl -u "$TOR_SERVICE" -n 50 --no-pager 2>/dev/null | grep -q 'Bootstrapped 100% (done): Done'
}

main() {
    banner
    require_root

    msg "Restarting Tor service..."
    systemctl restart "$TOR_SERVICE"
    sleep 2

    if ! systemctl is-active --quiet "$TOR_SERVICE"; then
        err "Tor service is not active."
        exit 1
    fi

    msg "Flushing old IPv4 rules..."
    iptables -F
    iptables -t nat -F
    iptables -X

    msg "Setting default policies (fail closed)..."
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

    msg "Allowing loopback..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    msg "Allowing ESTABLISHED,RELATED traffic..."
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    msg "Allowing Tor daemon traffic..."
    iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT

    msg "Allowing DNS and TCP so NAT redirect can catch them..."
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --syn -j ACCEPT

    msg "Allowing local Tor listener ports..."
    iptables -A OUTPUT -p tcp -d 127.0.0.1 --dport 9040 -j ACCEPT
    iptables -A OUTPUT -p tcp -d 127.0.0.1 --dport 9050 -j ACCEPT
    iptables -A OUTPUT -p udp -d 127.0.0.1 --dport 9053 -j ACCEPT

    msg "Adding NAT bypass for localhost/private networks..."
    iptables -t nat -A OUTPUT -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A OUTPUT -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A OUTPUT -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A OUTPUT -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A OUTPUT -m owner --uid-owner "$TOR_UID" -j RETURN

    msg "Redirecting DNS to 9053 and TCP to 9040..."
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040

    msg "Blocking IPv6..."
    ip6tables -F
    ip6tables -X
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    msg "Saving rules..."
    save_rules

    if tor_ready; then
        ok "Tor is fully bootstrapped."
    else
        warn "Tor is running, but 'Bootstrapped 100%' was not seen yet in the journal."
        warn "Check with: journalctl -u ${TOR_SERVICE} -f"
    fi

    ok "ShadowSurf enabled."
    echo
    echo -e "${CYN}Tests:${RST}"
    echo "  curl https://check.torproject.org/api/ip"
    echo "  curl https://ifconfig.me"
    echo "  dig example.com"
}

main "$@"
EOF

cat > "${INSTALL_DIR}/shadow-stop" <<'EOF'
#!/usr/bin/env bash
# Creator: Bluuhaxor

set -Eeuo pipefail

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
RST='\033[0m'

msg()  { echo -e "${BLU}[*]${RST} $*"; }
ok()   { echo -e "${GRN}[+]${RST} $*"; }
err()  { echo -e "${RED}[-]${RST} $*"; }

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        err "Please run this script as root or with sudo."
        exit 1
    fi
}

save_rules() {
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
}

main() {
    require_root

    msg "Flushing IPv4 rules..."
    iptables -F
    iptables -t nat -F
    iptables -X

    msg "Restoring IPv4 default policies to ACCEPT..."
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    msg "Flushing IPv6 rules..."
    ip6tables -F
    ip6tables -X

    msg "Restoring IPv6 default policies to ACCEPT..."
    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT

    msg "Saving cleared rules..."
    save_rules

    ok "ShadowSurf disabled."
}

main "$@"
EOF

cat > "${INSTALL_DIR}/shadow-status" <<'EOF'
#!/usr/bin/env bash
# Creator: Bluuhaxor

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

YEL='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
RST='\033[0m'

TOR_SERVICE="tor@default"

section() {
    echo
    echo -e "${CYN}=== $* ===${RST}"
}

echo -e "${BLU}[*]${RST} ShadowSurf status overview"
echo "Creator: Bluuhaxor"

section "Tor service"
systemctl status "$TOR_SERVICE" --no-pager | sed -n '1,12p' || true

section "Tor bootstrap"
journalctl -u "$TOR_SERVICE" -n 20 --no-pager | grep 'Bootstrapped' || echo "No bootstrap lines found"

section "Tor listeners"
ss -ltnup | grep -E '(:9040|:9050|:9053)' || echo -e "${YEL}No matching listeners found${RST}"

section "iptables NAT OUTPUT"
iptables -t nat -L OUTPUT -n -v || true

section "iptables FILTER OUTPUT"
iptables -L OUTPUT -n -v || true

section "IPv6 OUTPUT"
ip6tables -L OUTPUT -n -v || true

section "Tor check"
curl -s https://check.torproject.org/api/ip || echo "curl failed"
echo

section "Plain IP"
curl -s https://ifconfig.me || echo "curl failed"
echo
EOF

cat > "${INSTALL_DIR}/shadow-restart" <<'EOF'
#!/usr/bin/env bash
# Creator: Bluuhaxor

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

shadow-stop
sleep 1
shadow-start
EOF

chmod +x \
  "${INSTALL_DIR}/shadow-start" \
  "${INSTALL_DIR}/shadow-stop" \
  "${INSTALL_DIR}/shadow-status" \
  "${INSTALL_DIR}/shadow-restart"

echo "[+] Installed successfully:"
echo "    ${INSTALL_DIR}/shadow-start"
echo "    ${INSTALL_DIR}/shadow-stop"
echo "    ${INSTALL_DIR}/shadow-status"
echo "    ${INSTALL_DIR}/shadow-restart"
echo
echo "[+] Usage:"
echo "    sudo shadow-start"
echo "    shadow-status"
echo "    sudo shadow-restart"
echo "    sudo shadow-stop"