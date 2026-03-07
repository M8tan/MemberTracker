# Member Tracker

Member Tracker is a PowerShell-based GUI tool that maps **exact membership paths** between an Active Directory user and a target group — including deeply nested group memberships across domains.

It was built after troubleshooting a real-world issue where a user received emails from a group they were not directly a member of.

Instead of manually tracing nested groups in ADUC, this tool programmatically discovers and visualizes every possible membership chain.

---

## 🚩 Problem It Solves

In complex AD environments:

- Users may inherit access via nested groups
- Groups may exist across multiple domains in a forest
- Identifying *why* a user has access is often slow and manual
- ADUC does not clearly show full nested membership paths

This tool answers:

> “Are they actually a group member?”

And if so:

> “How exactly?”
---

## ✨ Features

- 🔎 Cross-domain user discovery (entire forest)
- 🔁 Recursive nested group resolution
- 🛡 Loop-safe traversal (prevents infinite recursion)
- 🖥 Simple Windows Forms GUI
- 📄 Export results to:
  - TXT (human-readable)
  - JSON (machine-readable / automation-friendly)
- 🫣 Clear error handling for missing users/groups
- ⛓️ Displays full membership chains (Group → NestedGroup → User)

---

## 🛠 How It Works

1. Loads all domains in the current AD forest.
2. Locates the user & group across domains.
3. Recursively:
   - Enumerates group members
   - Traverses nested groups
   - Tracks visited groups to prevent loops
   - Builds all valid membership paths
4. Displays each path clearly in order.
5. Optionally exports results {TXT & JSON}.

---

## 🧠 Example Output

User is a member via 2 paths:

1. Corporate-Email → Marketing → Marketing-EMEA → JohnDoe  
2. Corporate-Email → All-Staff → Regional-Users → JohnDoe  

---

## 📦 Requirements

- Windows
- PowerShell 5.1+
- ActiveDirectory module
- Domain connectivity
- AD read permissions

---

## 🚀 Why I Built This

I encountered a case where a user kept receiving emails sent to a group they were supposedly not a member of.

Manual inspection in ADUC didn’t reveal anything obvious, but *Get-ADPrincipalGroupMembership* showed that the user is, in fact, a member of the group.

I realized we have a nested group issue, and from experience, manually checking such incidents is not that fun.

So instead of guessing or digging through AD groups, I built a recursive membership resolver to surface the exact inheritance path.

This project reflects my interest in:

- Identity & Access Management (IAM)
- Active Directory architecture
- Access transparency & auditing
- Automation in infrastructure environments

---

## 🧭 Future Improvements

- CLI version (non-GUI)
- Performance optimization for large forests
- Export to CSV
- Graph visualization output
- Integration with Entra ID / Azure AD
- Logging module

---

If you found this useful or have suggestions, feel free to open an issue or connect! :)
