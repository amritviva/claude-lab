# API Versioning Strategy & Science

## Why Version APIs?

API versioning allows you to:

- **Evolve your API** without breaking existing clients
- **Maintain backward compatibility** while adding new features
- **Deprecate old endpoints** gradually
- **Test new versions** alongside existing ones
- **Support multiple client versions** simultaneously

---

## Versioning Strategies

### 1. URL Path Versioning (What We Use) ✅

**Format:** `/api/v1/resource`, `/api/v2/resource`

**Example:**

```
/api/v1/locations
/api/v2/locations  (new version with different response format)
```

**Pros:**

- ✅ Clear and explicit
- ✅ Easy to understand
- ✅ Can run multiple versions simultaneously
- ✅ Easy to route to different handlers
- ✅ Works with any HTTP client
- ✅ Can cache different versions separately

**Cons:**

- ⚠️ URL changes (but that's the point!)
- ⚠️ More paths to maintain

**Best For:** REST APIs, when you need clear separation

---

### 2. Header Versioning

**Format:** `Accept: application/vnd.api.v1+json`

**Example:**

```bash
curl -H "Accept: application/vnd.api.v1+json" /api/locations
curl -H "Accept: application/vnd.api.v2+json" /api/locations
```

**Pros:**

- ✅ Clean URLs (no version in path)
- ✅ Follows HTTP standards

**Cons:**

- ⚠️ Less discoverable
- ⚠️ Harder to test in browser
- ⚠️ Clients must remember headers

**Best For:** Internal APIs, when URLs should stay clean

---

### 3. Query Parameter Versioning

**Format:** `/api/locations?version=1`

**Example:**

```
/api/locations?version=1
/api/locations?version=2
```

**Pros:**

- ✅ Simple to implement
- ✅ Optional (defaults to latest)

**Cons:**

- ⚠️ Not RESTful
- ⚠️ Can be confusing
- ⚠️ Harder to cache

**Best For:** Quick fixes, not recommended for production

---

### 4. Subdomain Versioning

**Format:** `v1.api.example.com`, `v2.api.example.com`

**Example:**

```
https://v1.api.example.com/locations
https://v2.api.example.com/locations
```

**Pros:**

- ✅ Complete separation
- ✅ Can deploy to different servers

**Cons:**

- ⚠️ DNS complexity
- ⚠️ SSL certificate management
- ⚠️ More infrastructure

**Best For:** Large-scale APIs with dedicated infrastructure

---

## Our Choice: URL Path Versioning

We use **URL Path Versioning** because:

1. ✅ **Clear and explicit** - Developers immediately see the version
2. ✅ **Easy to test** - Works in browser, Postman, curl
3. ✅ **Future-proof** - Can run v1 and v2 simultaneously
4. ✅ **Simple routing** - Express can route to different handlers easily
5. ✅ **Industry standard** - Used by GitHub, Stripe, Twitter APIs

---

## Version Lifecycle

### Phase 1: v1 (Current)

```
/api/v1/locations
/api/v1/batches
/api/v1/memberships
```

- All current endpoints
- Stable, production-ready
- Documented and tested

### Phase 2: v2 (Future)

```
/api/v2/locations      (new response format)
/api/v2/batches        (new features)
/api/v1/locations      (still works!)
```

- New version with improvements
- v1 still available for backward compatibility
- Gradual migration period

### Phase 3: Deprecation

```
/api/v1/locations      (deprecated, will be removed in 6 months)
/api/v2/locations      (current, recommended)
```

- v1 marked as deprecated
- Clients migrate to v2
- v1 removed after migration period

---

## When to Create a New Version

### ✅ Create v2 When:

- **Breaking changes** to request/response format
- **Removing fields** from responses
- **Changing authentication** method
- **Major refactoring** of business logic
- **New data models** that break compatibility

### ❌ Don't Create v2 For:

- **Adding new fields** (backward compatible)
- **Adding new endpoints** (just add to v1)
- **Bug fixes** (fix in v1)
- **Performance improvements** (improve v1)

---

## Migration Strategy

### Step 1: Announce v2

```json
{
    "message": "v2 is available",
    "v1_deprecation_date": "2026-07-01",
    "v2_docs": "https://api.example.com/docs/v2"
}
```

### Step 2: Run Both Versions

- v1: Existing clients continue working
- v2: New clients use new version
- Both: Share same database, different handlers

### Step 3: Deprecation Headers

```http
HTTP/1.1 200 OK
Deprecation: true
Sunset: Sat, 01 Jul 2026 00:00:00 GMT
Link: </api/v2/locations>; rel="successor-version"
```

### Step 4: Remove v1

- After migration period (typically 6-12 months)
- Remove v1 handlers
- Update documentation

---

## Implementation Example

### Router Setup

```typescript
// v1 routes
apiRouter.use("/v1/locations", v1LocationsRouter);
apiRouter.use("/v1/batches", v1BatchesRouter);

// v2 routes (future)
apiRouter.use("/v2/locations", v2LocationsRouter);
apiRouter.use("/v2/batches", v2BatchesRouter);
```

### Handler Structure

```
handlers/
├── v1/
│   ├── locations.handler.ts
│   └── batches.handler.ts
└── v2/
    ├── locations.handler.ts
    └── batches.handler.ts
```

### Shared Logic

```typescript
// services/location-service.ts (shared)
export function getLocations() { ... }

// handlers/v1/locations.handler.ts
import { getLocations } from "../../services/location-service";
// Transform to v1 format

// handlers/v2/locations.handler.ts
import { getLocations } from "../../services/location-service";
// Transform to v2 format
```

---

## Best Practices

### 1. Semantic Versioning

- **v1, v2, v3** for major versions (breaking changes)
- Not **v1.1, v1.2** (those are just updates)

### 2. Version All Endpoints

- Don't mix `/api/v1/endpoint1` and `/api/endpoint2`
- Be consistent: all endpoints in same version

### 3. Document Changes

- Changelog for each version
- Migration guide from v1 to v2
- Clear deprecation timeline

### 4. Test Both Versions

- Unit tests for v1 and v2
- Integration tests
- Backward compatibility tests

### 5. Monitor Usage

- Track which version clients use
- Alert when v1 usage drops (ready to deprecate)
- Monitor error rates per version

---

## Real-World Examples

### GitHub API

```
https://api.github.com/v3/repos
https://api.github.com/v4/graphql  (GraphQL version)
```

### Stripe API

```
https://api.stripe.com/v1/charges
https://api.stripe.com/v2/charges  (when they need it)
```

### Twitter API

```
https://api.twitter.com/1.1/statuses
https://api.twitter.com/2/tweets    (new version)
```

---

## Summary

**Our Strategy:**

- ✅ URL Path Versioning: `/api/v1/...`
- ✅ Start with v1 (current endpoints)
- ✅ Add v2 when breaking changes needed
- ✅ Run both versions during migration
- ✅ Deprecate v1 after migration period

**Key Principle:**

> **Never break existing clients. Always provide a migration path.**

---

## Quick Reference

```bash
# Current (v1)
GET  /api/v1/locations
GET  /api/v1/batches
POST /api/v1/batches/:id/reminders
POST /api/v1/memberships/:id/cancel

# Future (v2) - when needed
GET  /api/v2/locations      (new format)
GET  /api/v2/batches        (new features)
POST /api/v2/batches/:id/reminders
POST /api/v2/memberships/:id/cancel
```

**Remember:** v1 stays active even when v2 is released! 🚀
