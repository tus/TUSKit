# Rule Loading Guide

This file helps determine which rules to load based on the context and task at hand. Each rule file contains specific guidance for different aspects of Swift development.

## Rule Loading Triggers

Rules are under `ai-rules` folder. If the folder exist in local project directory, use that.

### 📝 general.md - Core Engineering Principles
**Load when:**
- Always
- Starting any new Swift project or feature
- Making architectural decisions
- Discussing code quality, performance, or best practices
- Planning implementation strategy
- Reviewing code for improvements

**Keywords:** architecture, design, performance, quality, best practices, error handling, planning, strategy

## Loading Strategy

1. **Always load `general.md` and `mcp-tools-usage.md first`** - It provides the foundation
2. **Load domain-specific rules** based on the task
3. **Load supporting rules** as needed (e.g., testing when implementing)
4. **Keep loaded rules minimal** - Only what's directly relevant
5. **Refresh rules** when switching contexts or tasks
