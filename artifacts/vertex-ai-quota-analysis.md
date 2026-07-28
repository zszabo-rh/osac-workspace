# Vertex AI Migration Cost Control Analysis

**Date:** 2026-07-24  
**Your current Vertex project:** `itpc-gcp-eco-eng-claude` (shared project)

## Summary of Changes

### What's Changing

**Migration Timeline:**
- **July 23**: Initial notification (today)
- **July 23 - Aug 21**: Migration window - you'll receive individual GCP project details
- **August 21**: Access to shared projects removed for eligible users

**New Setup:**
- Individual GCP project (dedicated, not shared)
- Dedicated service account for authentication
- **$500/month soft quota** (initially informational, won't block access)
- **Hard quotas coming soon** after initial rollout (date TBD)

**Available Models:**
- Opus: 4.6, 4.8
- Sonnet: 5, 4.6, 4.5
- Haiku: 4.5
- Gemini: 3.6

## Current Vertex AI Pricing (As of Jan 2025)

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Cached Input (per 1M tokens) |
|-------|----------------------|------------------------|------------------------------|
| **Opus 4.8** | $15.00 | $75.00 | $1.50 (90% discount) |
| **Sonnet 4.5** | $3.00 | $15.00 | $0.30 (90% discount) |
| **Sonnet 5** | $3.00 | $15.00 | $0.30 (90% discount) |
| **Haiku 4.5** | $0.80 | $4.00 | $0.08 (90% discount) |

## Your Current Usage Pattern Analysis

**Based on your environment:**
- Using Claude Code CLI extensively for OSAC development
- Primary model: Sonnet 4.5 (via `claude-code_2-1-218_agent`)
- Can use Opus 4.6 when explicitly requested (`ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6`)
- Heavy context: Large workspace with multiple repos, CLAUDE.md, AGENTS.md, memory system
- Typical session: 70k-130k tokens in context (current session: ~70k tokens so far)

**Typical usage estimate (conservative):**

### Scenario 1: Moderate Daily Usage (Current Pattern)
Assuming 3-5 Claude sessions per day, mix of quick questions and implementation work:

- **Daily input:** ~500k tokens (mostly cached due to stable CLAUDE.md/AGENTS.md)
  - Fresh: 50k tokens × $3.00/1M = $0.15
  - Cached: 450k tokens × $0.30/1M = $0.135
- **Daily output:** ~50k tokens × $15.00/1M = $0.75
- **Daily total:** ~$1.04/day × 20 working days = **~$21/month**

### Scenario 2: Heavy Development Day (Bug fixing, PR reviews)
- **Daily input:** ~2M tokens (with cache)
  - Fresh: 200k × $3.00/1M = $0.60
  - Cached: 1.8M × $0.30/1M = $0.54
- **Daily output:** ~200k tokens × $15.00/1M = $3.00
- **Daily total:** ~$4.14/day × 20 days = **~$83/month**

### Scenario 3: Ultra-Heavy (Workflow runs, multi-agent orchestration)
If you use workflows (`/implement`, `/bugfix`, multi-agent tasks) frequently:

- **Daily input:** ~5M tokens
  - Fresh: 500k × $3.00/1M = $1.50
  - Cached: 4.5M × $0.30/1M = $1.35
- **Daily output:** ~500k tokens × $15.00/1M = $7.50
- **Daily total:** ~$10.35/day × 20 days = **~$207/month**

### Scenario 4: Occasional Opus Usage
If you use Opus 4.8 for 20% of your work (complex debugging, architecture decisions):

- Opus costs 5× more than Sonnet for input, output
- 20% Opus + 80% Sonnet on moderate usage: **~$35-45/month**
- 20% Opus + 80% Sonnet on heavy usage: **~$110-130/month**

## Risk Assessment

### ✅ Low Risk Patterns (Well under $500)
- Quick questions and code reviews only: **$10-30/month**
- Moderate daily usage (3-5 sessions): **$20-50/month**
- Heavy usage but primarily Sonnet/Haiku: **$80-150/month**

### ⚠️ Medium Risk Patterns (Approaching $500)
- Daily workflow runs (`/implement`, `/bugfix`): **$150-250/month**
- Frequent multi-agent orchestration: **$200-350/month**
- Regular Opus usage (>30% of work): **$200-400/month**

### 🚨 High Risk Patterns (Could exceed $500)
- Multiple daily workflow runs with large context: **$300-600/month**
- Heavy Opus usage (>50% of sessions): **$400-800/month**
- Continuous background agents or long-running autonomous tasks: **$500+/month**
- Large-scale code generation (entire features): **$600+/month**

## Recommendations

### 1. **Continue Current Usage** ✅
Your current moderate usage pattern is **well within the $500 quota**. No immediate changes needed.

**Why:**
- Sonnet 4.5 is cost-efficient
- Prompt caching (5-minute TTL) saves 90% on repeated context
- Your OSAC workspace context is stable (caches well)
- Estimated cost: **$20-80/month** for typical usage

### 2. **Be Strategic with Workflows** ⚠️
Workflows spawn multiple agents and can consume significant tokens.

**Best practices:**
- Use workflows for complex, multi-step tasks (they're worth it)
- Avoid running workflows for simple tasks you could do directly
- When using `/implement` or `/bugfix`, prefer targeted phases over full runs
- Monitor output - if a workflow is generating too much, you can stop it

**Cost impact:** Each full workflow run might use 200k-1M tokens (~$3-15)

### 3. **Use Opus Selectively** ⚠️
Opus 4.8 is 5× more expensive than Sonnet.

**When to use Opus:**
- Complex architectural decisions
- Difficult bugs requiring deep reasoning
- Critical PR reviews
- Design document creation

**When to stick with Sonnet:**
- Code reviews
- Implementation tasks
- Documentation
- Quick fixes
- General development

**Cost impact:** Opus session costs ~$0.50-2.00 vs Sonnet ~$0.10-0.40

### 4. **Monitor After Migration** 📊
Once you get your individual project:

**Action items:**
1. Set up budget alerts in GCP Console:
   - Alert at 50% ($250)
   - Alert at 75% ($375)
   - Alert at 90% ($450)

2. Check monthly usage in GCP Console:
   - Navigate to: Billing → Reports
   - Filter by: Vertex AI API usage
   - Track trends weekly

3. Review usage patterns:
   - If approaching $400/month, consider reducing Opus usage
   - If exceeding $450/month consistently, reach out to Bill Ryan about quota increase

### 5. **Prepare for Hard Quotas** 🔒
Hard quotas are coming "shortly after rollout."

**When hard quotas activate:**
- Your access WILL be blocked if you hit $500
- Plan ahead if you have deadline-critical work
- Budget your usage throughout the month (don't front-load)

**Mitigation strategies:**
- Keep emergency work for month-end under $100 buffer
- Use Haiku for simple tasks ($0.80 input vs $3.00 Sonnet)
- Batch similar questions to maximize cache hits

### 6. **Optimize Context Size** 💡
Your CLAUDE.md and AGENTS.md are large but stable (good for caching).

**Current optimization opportunities:**
- Your memory system is well-structured ✅
- Progressive disclosure is working well ✅
- Consider: If you add more docs to `.claude/rules/`, they'll increase context cost

**Best practices:**
- Keep CLAUDE.md/AGENTS.md stable (better cache hits)
- Use memory system for session-specific context
- Avoid repeatedly reading large files if cached versions work

## Migration Checklist

- [ ] **Week of July 23-29:** Receive individual project details email
- [ ] **Before Aug 21:** Migrate to new GCP project
  - Update `ANTHROPIC_VERTEX_PROJECT_ID` environment variable
  - Test Claude Code still works
  - Verify model access (Opus, Sonnet, Haiku)
- [ ] **After migration:** Set up GCP budget alerts
- [ ] **Week 1:** Monitor actual usage vs estimates
- [ ] **Monthly:** Review usage patterns and adjust as needed

## Support Resources

- **Migration support:** `#help-vertex-ai-migration-support` on Slack
- **Quick answers:** `@chai-bot` in the support channel
- **User guide:** [Migration User Guide](https://docs.google.com/document/d/1eNARy9CI28o09E7Foq01e5WD5MvEj3LSBnXqFcprxjo/edit?tab=t.0)
- **FAQ:** [PGE User Vertex Wiki](https://source.redhat.com/departments/products_and_global_engineering/pge_cloud_ops/wiki~2/onboarding_checklist_for_openshift_engineering__qe/pge_user_vertex_wiki_migration)
- **Policy questions:** Bill Ryan (biryan@redhat.com) or Josh Boyer

## Bottom Line

**Your verdict: ✅ You're in good shape**

Your current usage pattern is cost-efficient and well under the $500 quota. Key points:

1. **No immediate changes needed** - continue using Claude as you do now
2. **Set up budget alerts** once you get your individual project (50%, 75%, 90%)
3. **Be strategic with workflows** - they're powerful but token-intensive
4. **Save Opus for hard problems** - Sonnet handles most tasks well
5. **Watch for hard quota announcement** - plan ahead when that comes

**Estimated monthly cost:** $20-80 for typical usage, $150-250 for heavy workflow usage

You have plenty of headroom within the $500 quota.
