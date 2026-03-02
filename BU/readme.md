# Member Tracker – AD Nested Group Membership Tool

**Member Tracker** is a GUI-based **PowerShell tool** for analyzing **nested Active Directory (AD) group memberships** across multiple domains. It helps IT, security, and platform teams quickly identify how users inherit access through groups, including nested or cross-domain memberships.

---

## 🚀 Key Features
- **Recursive nested group traversal** – Find all membership paths from a group to a user.  
- **Cross-domain support** – Search users and groups across all domains in the AD forest.  
- **Loop protection** – Detects and avoids cyclic group memberships.  
- **User-friendly GUI** – Built with Windows Forms for intuitive operation.  
- **Exportable results** – Save outputs as **TXT** and **JSON** for auditing or reporting.  
- **Actionable insights** – Ideal for IAM, security audits, and automation tasks.  


---

## 📌 Example Use Case
> Large organizations often have deeply nested AD groups. Determining why a user has a certain permission can be challenging. Member Tracker allows you to:  
> - Audit user memberships efficiently  
> - Understand nested and cross-domain access paths  
> - Export results for compliance, security, or reporting purposes  

**Example Output:**

>  User is a member via 2 paths:
> 1. IT → Admins → John Doe
> 2. IT → Security → John Doe


---

## ⚙️ Usage
1. Clone or download the repository.  
2. Run `MemberTracker.ps1` in **PowerShell 5+** with the **ActiveDirectory module installed**.  
3. Enter the **username** (SAMAccountName) and **group name** (SAMAccountName).  
4. Click **Search membership** to view all paths.  
5. Use the **Export** button to save results as TXT or JSON.  

---

## 📂 Prerequisites
- Windows PowerShell 5 or higher  
- ActiveDirectory module (`RSAT-AD-PowerShell`)  
- Read access to Active Directory  

---

## 🔮 Future Enhancements
- Bulk user/group search  
- Progress bar for large environments  
- Logging for audit trails  
- Optional EXE packaging for non-PowerShell users  