# README.md v2025.11.18-1
## myWatchDog – Advanced Linux Service & Process Monitor

myWatchDog is a flexible, script-based system watchdog that automatically monitors **Systemd services**, **processes**, and **any scripts**.

It supports:

- Automatic restarts in case of errors
- Detection of “zombie” and “D-state” processes
- CPU freeze detection (jiffies monitoring)
- Telegram notifications (including daily, weekly, and monthly reports)
- Individual configuration per service/process
- Logging per service


---

## 📦 Installation

### Normal Installation
Installs myWatchDog, configs, and cronjob (if not existing):

``` bash
sudo make install
```
## 📦 Force Installation
Overwrites existing files and directories:

``` bash
sudo make install FORCE=1
```
## Dry-Run / Simulation
Shows what would happen without making any changes:

``` bash
sudo make install DRY_RUN=1
```
## Dry-Run + Force
Simulates installation and shows what would be overwritten:

``` bash
make install DRY_RUN=1 FORCE=1
```
## ✅ Notes:

Default installation paths:
``` 
/etc/myWatchDog/             # for main and service configs
/usr/local/bin/myWatchDog.sh # for the script
/etc/cron.d/mywatchdog       # for default cronjob
```
Tree structure is displayed automatically, using tree if installed; otherwise, a textual tree is shown with echo.

## 📂 Example Directory Structure After Installation
```
/etc/myWatchDog/
├── main.conf
├── services
│   ├── process-service.conf.example
│   ├── script-service.conf.example
│   └── systemd-service.conf.example
/usr/local/bin/
├── myWatchDog.sh
/etc/cron.d/
└── mywatchdog
```

## ⚙ Configuration
```
main.conf – global settings
services/ – individual service/process configuration
# Logs are written per service, configurable in main.conf or per service Config.
```

## 💬 Notifications
Telegram notifications can be configured per service or globally.
Supports daily, weekly, and monthly reports.

## 🛠 Usage
```
Usage: /usr/local/bin/myWatchDog.sh [options]

Options:
  --test, -t              Test mode (no real restarts)
  --restart, -r           Force restart in test mode
  --mode, -m MODE         Mode: daily, weekly, monthly
  --get-chatid, -i        Start OTP pairing to get chat id via Telegram
  -h, --help              Show this help
```

## License

[GPL](https://www.gnu.org/licenses/#GPL)
