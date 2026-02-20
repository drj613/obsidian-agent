# Frontmatter Rules

Every note (except indexes and templates) MUST have YAML frontmatter.

## Fields

| Field | Required? | Description |
|-------|-----------|-------------|
| `created` | required | [describe] |
| `category` | required | [describe] |
| `tags` | required | [describe] |
| `status` | optional | [describe] |
| `type` | optional | [describe] |

## Validation

- All required fields must be present
- `tags` must be an array (even if empty `[]`)
- `created` must be a valid date (YYYY-MM-DD)
