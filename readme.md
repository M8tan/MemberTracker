# Member Tracker – AD Membership Path Analysis Tool

## Overview
**Member Tracker** is a GUI-based PowerShell tool for analyzing **nested Active Directory (AD) group membership** across multiple domains.  

It is designed for large enterprise environments where understanding how users inherit group access through nested groups can be complex. The tool provides clear, readable membership paths and exportable results, helping admins and security teams quickly audit access.

---

## Key Features
- ✅ Recursive traversal of nested AD groups  
- ✅ Cross-domain user and group discovery  
- ✅ Detection of cyclic memberships (loop protection)  
- ✅ GUI built with Windows Forms for easy operation  
- ✅ Export results to text files for reporting or auditing  
- ✅ Provides actionable insights for IAM, automation, and platform engineering tasks  

---

## Technologies
- **PowerShell** – Core automation and AD integration  
- **System.Windows.Forms** – GUI interface  
- **ActiveDirectory module** – User and group querying  
- **Recursive algorithms** – Nested group resolution  

---

## Example Use Case
> In large organizations, a user may inherit permissions from multiple nested groups across domains. Member Tracker allows administrators to:  
> - Verify why a user has access to a specific resource  
> - Audit group memberships efficiently  
> - Quickly export results for compliance or security reporting  

---
