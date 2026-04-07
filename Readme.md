
````md
  ____  _               _              ____              __
 / ___|| |__   __ _  __| | _____      / ___| _   _ _ __ / _|
 \___ \| '_ \ / _` |/ _` |/ _ \ \ /\ / / _ \| | | | '__| |_
  ___) | | | | (_| | (_| | (_) \ V  V / (_) | |_| | |  |  _|
 |____/|_| |_|\__,_|\__,_|\___/ \_/\_/ \___/ \__,_|_|  |_|

                 ShadowSurf for KALI

     transparent Tor routing for local host
            

**Creator:** Bluuhaxor

ShadowSurf for KALI is a lightweight transparent Tor routing setup for a local Kali/Linux host using:

- `tor`
- `iptables`
- `ip6tables`

It installs four helper commands:

- `shadow-start`
- `shadow-stop`
- `shadow-status`
- `shadow-restart`

## What it does

ShadowSurf routes local host traffic through Tor by using:

- `TransPort 9040` for transparent TCP routing
- `DNSPort 9053` for DNS redirection
- a fail-closed IPv4 firewall policy
- blocked IPv6 to reduce leak risk

This setup is intended for the **local machine only**.  
It does **not** route traffic from other devices on your network.

## Required Tor configuration

Before using ShadowSurf, make sure `/etc/tor/torrc` contains at least:

```conf
SocksPort 9050
TransPort 9040
DNSPort 9053
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
````

Then restart Tor:

```bash
sudo systemctl restart tor@default
sudo systemctl status tor@default --no-pager
```

## Installation

Save the installer as `install.sh`, then run:

```bash
chmod +x install.sh
sudo ./install.sh
```

This will install:

* `/usr/local/bin/shadow-start`
* `/usr/local/bin/shadow-stop`
* `/usr/local/bin/shadow-status`
* `/usr/local/bin/shadow-restart`

## Usage

Start ShadowSurf:

```bash
sudo shadow-start
```

Check status:

```bash
shadow-status
```

Restart ShadowSurf:

```bash
sudo shadow-restart
```

Stop ShadowSurf:

```bash
sudo shadow-stop
```

## Quick test

After starting, test with:

```bash
dig example.com
curl https://check.torproject.org/api/ip
curl https://ifconfig.me
journalctl -u tor@default -n 50 --no-pager | grep 'Bootstrapped'
```

Expected result:

* DNS resolution works
* `check.torproject.org` returns `"IsTor": true`
* your visible IP is a Tor exit IP
* bootsrap should be by 100 % in a few seconds

## Notes

* This setup protects **only the host where it is installed**
* IPv6 is blocked to reduce leak risk
* `shadow-stop` resets firewall rules to a permissive state
* it does **not** restore a previous custom firewall ruleset
* Tor must already be installed and working

## Commands installed

The installer places these commands in `/usr/local/bin`:

* `shadow-start`
* `shadow-stop`
* `shadow-status`
* `shadow-restart`

## Disclaimer

ShadowSurf for KALI is a custom transparent Tor routing setup inspired by Anonsurf-style behavior. It is not the original Anonsurf package.

```
