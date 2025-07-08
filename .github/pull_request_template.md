# Pull Request

## 📝 Description

Provide a brief description of what this PR does.

## 🔗 Related Issues

- Fixes #(issue number)
- Closes #(issue number)
- Related to #(issue number)

## 🎯 Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] 🚀 New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update (improvements or additions to documentation)
- [ ] 🔧 Maintenance (dependency updates, code cleanup, etc.)
- [ ] 🎨 Style (formatting, missing semi colons, etc; no production code change)
- [ ] ♻️ Refactoring (no functional changes, no api changes)
- [ ] ⚡ Performance improvements
- [ ] ✅ Test additions or modifications

## 🧪 Testing

**How has this been tested?**

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] Existing tests pass

**Test Configuration:**
- Rover version: 
- OS: [e.g., Ubuntu 20.04, Windows 11, macOS 12]
- Docker version:
- Azure subscription type:

**Test scenarios covered:**
1. Scenario 1: Description
2. Scenario 2: Description
3. Scenario 3: Description

## 📋 Checklist

**Before submitting this PR, please make sure:**

### Code Quality
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings or errors
- [ ] I have removed any debugging code or console.log statements

### Testing
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

### Documentation
- [ ] I have made corresponding changes to the documentation
- [ ] I have updated the README.md if needed
- [ ] I have added/updated inline code comments
- [ ] I have updated any relevant guides or tutorials

### Security & Compliance
- [ ] My changes don't introduce security vulnerabilities
- [ ] I have not committed sensitive information (credentials, secrets, etc.)
- [ ] I have followed the security guidelines in SECURITY.md
- [ ] My changes comply with relevant compliance requirements

### Breaking Changes
- [ ] This change requires a documentation update
- [ ] This change requires a migration guide
- [ ] I have updated the version number appropriately
- [ ] I have updated CHANGELOG.md

## 📸 Screenshots (if applicable)

**Before:**
<!-- Add screenshots of the current behavior -->

**After:**
<!-- Add screenshots of the new behavior -->

## 🚀 Deployment Notes

**Special deployment considerations:**
- Database migrations required: [ ] Yes [ ] No
- Configuration changes required: [ ] Yes [ ] No
- Dependencies updated: [ ] Yes [ ] No
- Breaking changes: [ ] Yes [ ] No

**Post-deployment verification steps:**
1. Step 1
2. Step 2
3. Step 3

## 🔄 Migration Guide (if breaking changes)

**For users upgrading from previous version:**

1. Step-by-step migration instructions
2. Configuration changes required
3. Deprecated features and alternatives

```bash
# Example migration commands
rover migrate --from v1.0 --to v2.0
```

## 📊 Performance Impact

**Performance considerations:**
- [ ] This change improves performance
- [ ] This change has no performance impact
- [ ] This change may impact performance (explain below)

**Performance testing results:**
- Metric 1: Before/After
- Metric 2: Before/After
- Metric 3: Before/After

## 🔍 Code Review Focus Areas

**Please pay special attention to:**
- [ ] Security implications
- [ ] Performance impact
- [ ] Error handling
- [ ] Edge cases
- [ ] API compatibility
- [ ] User experience

**Specific questions for reviewers:**
1. Question 1 about implementation choice
2. Question 2 about architecture decision
3. Question 3 about test coverage

## 🌍 Additional Context

Add any other context about the pull request here.

**Dependencies:**
- This PR depends on: #(issue/PR number)
- This PR blocks: #(issue/PR number)

**Future work:**
- Follow-up tasks that should be created
- Related improvements planned

**Rollback plan:**
- How to revert this change if needed
- Any data recovery considerations

---

## 👥 Reviewer Guidelines

**For maintainers reviewing this PR:**

1. **Code Review Checklist:**
   - [ ] Code follows project conventions
   - [ ] Logic is clear and well-documented
   - [ ] Error handling is appropriate
   - [ ] Tests are comprehensive
   - [ ] Performance impact is acceptable

2. **Security Review:**
   - [ ] No sensitive data exposed
   - [ ] Input validation is proper
   - [ ] Authentication/authorization correct
   - [ ] No security vulnerabilities introduced

3. **Documentation Review:**
   - [ ] Documentation is accurate and complete
   - [ ] Examples are working and relevant
   - [ ] Breaking changes are clearly documented

**Testing Notes for Reviewers:**
- Key scenarios to test manually
- Edge cases to verify
- Integration points to check

---

Thank you for contributing to Rover! 🚀