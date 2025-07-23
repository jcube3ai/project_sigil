# SIGIL
RedTeam SIM Tool for Pentesting 

# SIGIL SIM  
**Red Team Simulation Tool for Pentesting**

---

## 🧩 Overview
SIGIL (Simulated Intel for Global Intrusion Logic) is a PowerShell–based red‑team simulator designed to emulate realistic adversary behaviors against Windows hosts in a completely lab‑safe environment. Each of the included scripts represents a different threat actor or technique—complete with automatic cleanup options—so you can practice detection, response, and forensic analysis without fear of persistent infections.

---

## 📂 Repository Contents

| File                                    | Description                                                         |
| --------------------------------------- | ------------------------------------------------------------------- |
| `APT28_SIM.ps1`                         | Simulates APT28‑style operations: spear‑phishing, credential theft, lateral movement. |
| `Authentic_ANTICS-SIM.ps1`              | Recreates the “Antics” toolset: custom payload delivery & C2 callbacks. |
| `Mitre_Simulation_ArgParsed.ps1`        | Modular simulation harness: choose sub‑techniques via CLI arguments. |
| `Registry_Hijack_SIM.ps1`               | Demonstrates registry hijacking and persistence across reboots.     |
| `Silent_Ransom_Group.ps1`               | Ransomware‑style behavior: file encryption, ransom note drop, cleanup. |
| `README.md`                             | This document.                                                     |

---

## ⚙️ Prerequisites

- **OS**: Windows 10 or later (PowerShell 5.1+)  
- **Execution Policy**:  
  ```powershell
  Set-ExecutionPolicy Bypass -Scope Process


# <img width="623" height="519" alt="image" src="https://github.com/user-attachments/assets/0842b483-2db7-4caa-9900-386c1afadab7" />

