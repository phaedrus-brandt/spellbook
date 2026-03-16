# Focus Search

Search the Spellbook index for skills matching a query.

## Process

### 1. Fetch Index

Download `index.yaml` from:
```
https://raw.githubusercontent.com/phrazzld/spellbook/main/index.yaml
```

### 2. Search

Match the query against:
- Skill `name` (exact and substring)
- Skill `description` (keyword matching)
- Skill `tags` (exact tag match)
- Collection names and descriptions

Rank results by match quality:
1. Exact name match
2. Tag match
3. Description keyword match
4. Collection membership match

### 3. Present Results

```markdown
## Spellbook Search: "webhook"

### Skills
| Name | Description | Tags |
|------|-------------|------|
| **stripe** | Stripe integration patterns... | payments, stripe, webhooks |
| **next-patterns** | Next.js patterns... | web, nextjs, api-routes |

### Collections
| Name | Contains | Description |
|------|----------|-------------|
| payments | stripe, bitcoin, lightning | Payment processing |

### Actions
- `/focus add stripe` — add to manifest
- `/focus add payments` — add entire collection
```

### 4. Offer to Add

If the user seems to want to use a result (not just browsing), offer
to add it to the manifest and sync.
