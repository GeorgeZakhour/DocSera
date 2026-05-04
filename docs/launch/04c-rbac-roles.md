# 04c — Admin RBAC: Roles & Permissions

The admin role system is granular, additive, and future-proof. Adding a new role or permission is a SQL insert — never a code change.

## How it works

```
admin_users          ← who has any admin access (status = 'active' / 'suspended')
admin_roles          ← named bundles of permissions
admin_permissions    ← granular capabilities (e.g. 'analytics.read')
admin_role_permissions  ← which permissions each role grants
admin_user_roles     ← which roles each user holds (a user can hold many)
```

Every admin RPC starts with:
```sql
IF NOT public.has_admin_permission(auth.uid(), 'permission.code') THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
END IF;
```

A user with **multiple roles** holds the **union** of all their roles' permissions.

## Permissions catalog

| Permission code | What it allows |
|---|---|
| `analytics.read` | Aggregate analytics dashboards (KPIs, funnels, retention) |
| `analytics.users.read` | Per-user activity journey (for support / debugging) |
| `analytics.partners.read` | Partner-specific analytics (offer views, partner traffic) |
| `analytics.doctors.read` | Doctor-specific analytics (profile views, contact clicks) |
| `analytics.financial.read` | Revenue / payment / subscription analytics |
| `analytics.events.read` | Generic event explorer access (raw event browsing) |
| `analytics.events.export` | Export raw event data to CSV/JSON |
| `admin.users.read` | List admin users and their roles |
| `admin.users.write` | Grant or revoke admin roles to users |
| `admin.config.read` | Read app_config, banners, popups |
| `admin.config.write` | Modify app_config, banners, popups |
| `admin.medical_master.read` | Read medical_master items including unverified |
| `admin.medical_master.write` | Verify, edit, merge medical_master items |
| `admin.support.read` | Read user data for support purposes (read-only) |
| `admin.support.write` | Modify user data for support resolution |

## Pre-seeded roles

| Role | Use case | Permissions |
|---|---|---|
| **super_admin** | Founder, lead engineer | All 15 permissions |
| **analytics_viewer** | Investors, board members, observers | `analytics.read` + `analytics.partners.read` + `analytics.doctors.read` |
| **support_agent** | Customer support team — debug user issues | `analytics.users.read` + `admin.support.read` |
| **marketing_analyst** | Growth team — funnels, partner perf, exports | `analytics.read` + `analytics.partners.read` + `analytics.doctors.read` + `analytics.events.read` + `analytics.events.export` |
| **partner_manager** | Manages partner relationships | `analytics.partners.read` only |
| **content_editor** | Manages banners, popups, app config | `admin.config.read` + `admin.config.write` |
| **data_analyst** | Internal data team | `analytics.events.read` + `analytics.events.export` + `analytics.read` |
| **medical_reviewer** | Reviews custom medical_master entries | `admin.medical_master.read` + `admin.medical_master.write` |

## Common operations (run as `supabase_admin` or via admin RPCs)

### Grant a user super_admin (initial bootstrap)
```sql
-- Find the user's auth.users id
SELECT id FROM auth.users WHERE email = 'gzakhour96@gmail.com';

-- Make them an admin
INSERT INTO public.admin_users (user_id, status, notes)
VALUES ('<their-uuid>', 'active', 'Founder');

-- Assign super_admin
INSERT INTO public.admin_user_roles (user_id, role_code, granted_by)
VALUES ('<their-uuid>', 'super_admin', '<your-uuid>');
```

### Add a support agent
```sql
INSERT INTO public.admin_users (user_id, status, notes, created_by)
VALUES ('<their-uuid>', 'active', 'Support team — Maya', '<your-uuid>');

INSERT INTO public.admin_user_roles (user_id, role_code, granted_by)
VALUES ('<their-uuid>', 'support_agent', '<your-uuid>');
```

### Give a user multiple roles
```sql
INSERT INTO public.admin_user_roles (user_id, role_code, granted_by) VALUES
  ('<uuid>', 'analytics_viewer', '<your-uuid>'),
  ('<uuid>', 'content_editor',   '<your-uuid>');
```

### Revoke a role
```sql
DELETE FROM public.admin_user_roles
WHERE user_id = '<uuid>' AND role_code = 'analytics_viewer';
```

### Suspend (don't delete) an admin
```sql
UPDATE public.admin_users SET status = 'suspended' WHERE user_id = '<uuid>';
```

`is_admin()` and `has_admin_permission()` both check `status = 'active'`, so suspending instantly cuts off access without losing role history.

### List who has what
```sql
SELECT
  au.user_id,
  u.email,
  au.status,
  array_agg(aur.role_code ORDER BY aur.role_code) AS roles,
  array_agg(DISTINCT arp.permission_code ORDER BY arp.permission_code) AS effective_permissions
FROM admin_users au
LEFT JOIN auth.users u ON u.id = au.user_id
LEFT JOIN admin_user_roles aur ON aur.user_id = au.user_id
LEFT JOIN admin_role_permissions arp ON arp.role_code = aur.role_code
GROUP BY au.user_id, u.email, au.status
ORDER BY au.created_at DESC;
```

## Adding a new permission

When a new admin feature is built, add a permission code and assign it to the relevant roles:

```sql
INSERT INTO public.admin_permissions (code, description) VALUES
  ('admin.appointments.refund', 'Issue a refund / waive a no-show fee');

INSERT INTO public.admin_role_permissions (role_code, permission_code) VALUES
  ('super_admin',       'admin.appointments.refund'),
  ('support_agent',     'admin.appointments.refund');
```

## Adding a new role

```sql
INSERT INTO public.admin_roles (code, name, description, is_system) VALUES
  ('finance_lead', 'Finance Lead', 'Read all financial analytics and approve refunds', false);

INSERT INTO public.admin_role_permissions (role_code, permission_code) VALUES
  ('finance_lead', 'analytics.financial.read'),
  ('finance_lead', 'admin.appointments.refund');
```

## Why this architecture

- **Granular** — fine-grained permissions vs. binary "is admin." A support agent doesn't need to see revenue.
- **Additive** — a user can hold multiple roles; permissions union. Easy to compose.
- **Future-proof** — adding capabilities is a SQL insert. Code never changes.
- **Auditable** — `granted_at` / `granted_by` on `admin_user_roles` and `created_by` on `admin_users` form an audit trail.
- **Reversible** — `status = 'suspended'` revokes access without losing history.
- **Database-enforced** — `has_admin_permission()` is the single source of truth; no chance of a buggy app forgetting a check.

## What could go wrong

- **The first super_admin must be bootstrapped via direct SQL.** There is no UI for this yet (the admin panel doesn't exist). The bootstrap SQL above is the only way until the admin panel can manage admins itself.
- **Suspending the only super_admin locks you out of admin RPCs.** Always have at least 2 super_admins on a production system.
- **`admin.users.write` can grant any role** — it's the most dangerous permission. Currently held only by `super_admin`. Keep it that way unless you have a very specific reason.
