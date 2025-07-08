---
name: 🐛 Bug Report
about: Report a bug or issue with Rover
title: '[BUG] '
labels: ['bug', 'triage']
assignees: []

---

## 🐛 Bug Description

A clear and concise description of what the bug is.

## 🔄 Steps to Reproduce

1. Go to '...'
2. Run command '...'
3. Set configuration '...'
4. See error

## ✅ Expected Behavior

A clear and concise description of what you expected to happen.

## ❌ Actual Behavior

A clear and concise description of what actually happened.

## 🖼️ Screenshots/Logs

If applicable, add screenshots or logs to help explain your problem.

```
Paste error logs here
```

## 🌍 Environment Information

Please complete the following information:

**Host System:**
- OS: [e.g., Ubuntu 20.04, Windows 11, macOS 12]
- Docker Version: [e.g., 20.10.17]
- Architecture: [e.g., x64, arm64]

**Rover:**
- Rover Version: [e.g., 1.3.0]
- Container Image: [e.g., aztfmod/rover:latest]
- Installation Method: [e.g., Docker Hub, Local Build]

**Azure:**
- Azure CLI Version: [e.g., 2.40.0]
- Subscription Type: [e.g., Free Trial, Pay-As-You-Go, Enterprise]
- Authentication Method: [e.g., Interactive, Service Principal, Managed Identity]

**Terraform:**
- Terraform Version: [e.g., 1.3.0]
- Provider Versions: [e.g., azurerm 3.20.0]

## 🔧 Configuration

**Landing Zone:**
- Level: [e.g., level0, level1, level2]
- Environment: [e.g., dev, staging, production]
- Custom Configuration: [Yes/No]

**Command Used:**
```bash
# Paste the exact rover command that caused the issue
rover -lz ./landingzone -a apply -env production
```

**Terraform Configuration:**
```hcl
# Include relevant terraform configuration if applicable
# Remove any sensitive information
```

## 🕵️ Diagnostic Information

Please run the diagnostic script and paste the output:

```bash
# Run this diagnostic script and paste output
curl -s https://raw.githubusercontent.com/aztfmod/rover/main/scripts/diagnostics.sh | bash
```

<details>
<summary>Diagnostic Output</summary>

```
Paste diagnostic output here
```

</details>

## 🔍 Additional Context

Add any other context about the problem here.

- Have you encountered this issue before? [Yes/No]
- Does this issue occur consistently? [Yes/No]
- Any recent changes to your environment? [Yes/No - describe]
- Are you using any custom configurations? [Yes/No - describe]

## 📋 Checklist

Before submitting this issue, please confirm:

- [ ] I have searched existing issues to avoid duplicates
- [ ] I have included all required environment information
- [ ] I have included the exact error message and/or logs
- [ ] I have included steps to reproduce the issue
- [ ] I have removed any sensitive information (credentials, personal data)
- [ ] I have run the diagnostic script and included the output

## 💡 Possible Solution

If you have any ideas on how to solve this issue, please describe them here.

---

**Note**: This issue will be triaged by the maintainers. Please be patient and provide additional information if requested.