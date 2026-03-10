## Architecture

MemberTracker works in three stages:

1. **Discovery**
   - Detects domains and domain controllers automatically.

2. **Membership Graph Traversal**
   - Recursively resolves nested group relationships.
   - Tracks and records all membership paths.

3. **Visualization & Export**
   - GUI display of membership paths
   - CLI output for automation
   - Export to JSON and TXT