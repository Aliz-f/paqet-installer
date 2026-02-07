# Paqet Auto-Setup Scripts

This repository contains automated installation and configuration scripts for **[Paqet](https://github.com/hanselime/paqet)**.

These scripts streamline the deployment process by:
*   **Auto-detecting** OS, Architecture, IPs, and Gateway MAC addresses.
*   **Downloading** the correct binary.
*   **Configuring** the `.yaml` files automatically.
*   **Setting up** Systemd services (Server) and IPTables rules.

---

## 🚀 Server Installation (VPS)

Run this command on your **Server** (Linux VPS). This will install dependencies, configure the firewall, and generate your Secret Key.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ali-f/paqet-installer/main/server.sh)
```

**⚠️ After the script finishes:**
It will display a **Green Box** containing your **Server IP**, **Port**, and **Secret Key**.  
**Copy these details!** You will need them for the client setup.

---

## 💻 Client Installation (PC/Laptop)

### 1. Windows Pre-requisites (Important!)
If you are on Windows, you **must** install Npcap before running the script.
1.  **Download Npcap:** [https://npcap.com/dist/npcap-1.87.exe](https://npcap.com/dist/npcap-1.87.exe)
2.  **Install it:** During installation, ensure you check the box:  
    ☑️ *"Install Npcap in WinPcap API-compatible Mode"*

### 2. Run the Script
Open your terminal (Terminal on Linux/Mac, or **Git Bash** on Windows) and run:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/client.sh)
```

Follow the on-screen prompts to enter the **IP**, **Port**, and **Secret Key** provided by the server script.

---

## 🌐 How to Browse (Browser Configuration)

Once the client is running, Paqet creates a secure **SOCKS5 Proxy** on your local machine.

*   **Proxy IP:** `127.0.0.1`
*   **Proxy Port:** `1080`

To use the internet through Paqet, configure your browser (or use an extension like Proxy SwitchyOmega):

1.  **Firefox:** Settings > Network Settings > Manual Proxy Config > SOCKS Host: `127.0.0.1`, Port: `1080` (Select SOCKS v5).
2.  **Chrome/Edge:** It is recommended to use the **SwitchyOmega** extension and set up a SOCKS5 profile with the details above.

---

## 🛠 Troubleshooting

*   **Windows "Command not found":** Ensure you are running the command in **Git Bash** (included with Git for Windows), not standard CMD or PowerShell.
*   **Permission Denied:** The script attempts to use `sudo` automatically. If prompted, enter your system password.
*   **Connection Refused:** Ensure the Server Port (default 4443) is allowed in your VPS firewall (the server script attempts to open this automatically via UFW/IPTables).

---

## 🤝 Contribution

Contributions are welcome! If you have improvements for the scripts, bug fixes, or better OS support, please feel free to:
1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/improvement`).
3.  Commit your changes.
4.  Push to the branch and open a **Pull Request**.

---

## 📜 Credits
*   **Paqet Core:** [hanselime/paqet](https://github.com/hanselime/paqet)


