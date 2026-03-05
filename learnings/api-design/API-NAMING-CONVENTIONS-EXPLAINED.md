# API Naming Conventions Review

## Current API Endpoints

| Method | Path                                | Status          | Notes                                                                 |
| ------ | ----------------------------------- | --------------- | --------------------------------------------------------------------- |
| POST   | `/api/email-attachments`            | ✅ Good         | Clear, descriptive                                                    |
| GET    | `/api/locations`                    | ✅ Good         | Simple, RESTful                                                       |
| GET    | `/api/get-batch`                    | ⚠️ Inconsistent | Should be `/api/batches` or `/api/batch`                              |
| POST   | `/api/send-batch-reminder`          | ✅ Good         | Action-based, clear                                                   |
| POST   | `/api/fitnesspassport-cancellation` | ⚠️ Inconsistent | Should be `/api/memberships/cancel` or `/api/fitness-passport/cancel` |
| GET    | `/api/offline-access`               | ✅ Good         | Clear purpose                                                         |

## Recommended Naming Conventions

### ✅ Best Practices

1. **Use plural nouns for resources**:
    - ✅ `/api/locations` (good)
    - ❌ `/api/get-batch` (should be `/api/batches`)

2. **Use HTTP methods for actions**:
    - ✅ `GET /api/locations` (get all)
    - ✅ `POST /api/batches` (create)
    - ✅ `GET /api/batches/:id` (get one)
    - ✅ `PUT /api/batches/:id` (update)
    - ✅ `DELETE /api/batches/:id` (delete)

3. **Use nested resources for related data**:
    - ✅ `/api/memberships/:id/cancel`
    - ✅ `/api/batches/:id/reminders`

4. **Use kebab-case for multi-word paths**:
    - ✅ `/api/email-attachments`
    - ✅ `/api/offline-access`
    - ❌ `/api/fitnesspassport-cancellation` (should be `/api/fitness-passport/cancel`)

5. **Use verbs only for actions that don't fit CRUD**:
    - ✅ `/api/send-batch-reminder` (action)
    - ✅ `/api/cancel-membership` (action)

### 🔄 Suggested Improvements

#### Current → Recommended

1. **`GET /api/get-batch`** → **`GET /api/batches`**
    - Remove "get" verb (HTTP method already indicates GET)
    - Use plural form

2. **`POST /api/fitnesspassport-cancellation`** → **`POST /api/memberships/cancel`**
    - More RESTful
    - Clearer resource hierarchy
    - Or: `/api/fitness-passport/memberships/cancel`

3. **`POST /api/send-batch-reminder`** → **`POST /api/batches/:id/reminders`**
    - More RESTful (nested resource)
    - Or keep as action: `/api/batches/remind` (if no ID needed)

## Future-Proof Structure

### Resource-Based Structure

```
/api
  /locations              GET, POST, PUT, DELETE
  /batches                GET, POST
  /batches/:id            GET, PUT, DELETE
  /batches/:id/reminders  POST
  /memberships            GET, POST
  /memberships/:id        GET, PUT, DELETE
  /memberships/:id/cancel POST
  /email-attachments      POST
  /offline-access         GET
```

### Action-Based Structure (Alternative)

```
/api
  /locations              GET
  /batches                GET
  /send-batch-reminder    POST
  /cancel-membership      POST
  /email-attachments      POST
  /offline-access         GET
```

## Migration Strategy

If you want to improve naming:

1. **Keep old endpoints** (for backward compatibility)
2. **Add new endpoints** with better names
3. **Deprecate old endpoints** (add deprecation headers)
4. **Remove old endpoints** after migration period

Example:

```typescript
// Old endpoint (deprecated)
apiRouter.get("/get-batch", getBatchRouter);

// New endpoint
apiRouter.get("/batches", getBatchRouter);
```

## Current Status: ✅ Good Enough

Your current naming is **functional and clear**. The suggested improvements are **optional** and mainly for:

- RESTful consistency
- Better developer experience
- Industry standard alignment

**Recommendation**: Keep current naming unless you're doing a major refactor. Focus on functionality first! 🚀
