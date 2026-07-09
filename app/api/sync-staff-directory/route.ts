import { NextRequest, NextResponse } from "next/server";

const SUPABASE_SCHEMA = "commission_tracker";

function json(message: string, status = 200, extra: Record<string, unknown> = {}) {
  return NextResponse.json({ message, ...extra }, { status });
}

function supabaseHeaders(key: string, token?: string) {
  return {
    apikey: key,
    Authorization: `Bearer ${token || key}`,
    "Content-Type": "application/json",
    "Accept-Profile": SUPABASE_SCHEMA,
    "Content-Profile": SUPABASE_SCHEMA,
  };
}

function supabaseAuthHeaders(key: string, token?: string) {
  return {
    apikey: key,
    Authorization: `Bearer ${token || key}`,
    "Content-Type": "application/json",
  };
}

async function supabaseJson(url: string, init: RequestInit, label: string) {
  const response = await fetch(url, init);
  const text = await response.text();
  let body: unknown = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!response.ok) {
    const message =
      typeof body === "object" && body && "message" in body
        ? String((body as { message?: unknown }).message)
        : text || `${label} failed`;
    throw new Error(`${label}: ${message}`);
  }
  return body;
}

export async function POST(request: NextRequest) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const callerToken = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json("Staff sync is not configured on Render. Add NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY.", 500);
  }
  if (!callerToken) {
    return json("Please sign in before syncing staff.", 401);
  }

  try {
    const authUser = await supabaseJson(
      `${supabaseUrl}/auth/v1/user`,
      { headers: supabaseAuthHeaders(anonKey, callerToken) },
      "Login check",
    ) as { id?: string; email?: string; user_metadata?: Record<string, unknown> };

    if (!authUser.id) return json("Signed-in user could not be verified.", 401);

    const profiles = await supabaseJson(
      `${supabaseUrl}/rest/v1/user_profiles?select=id,permissions,status&id=eq.${encodeURIComponent(authUser.id)}`,
      { headers: supabaseHeaders(serviceKey) },
      "Permission check",
    ) as Array<{ permissions?: string[]; status?: string }>;

    const profile = profiles[0];
    if (!profile || profile.status !== "Active" || !profile.permissions?.includes("manageUsers")) {
      return json("Only a Commission Tracker user with Manage users access can sync staff.", 403);
    }

    const usersResponse = await supabaseJson(
      `${supabaseUrl}/auth/v1/admin/users?per_page=1000`,
      { headers: supabaseAuthHeaders(serviceKey) },
      "Auth user list",
    ) as { users?: Array<{ id: string; email?: string; user_metadata?: Record<string, unknown>; created_at?: string; banned_until?: string | null }> };

    const rows = (usersResponse.users || [])
      .filter(user => user.id && user.email)
      .map(user => {
        const meta = user.user_metadata || {};
        const staffName =
          String(meta.full_name || meta.name || meta.display_name || "").trim()
          || String(user.email || "").split("@")[0];
        return {
          auth_user_id: user.id,
          staff_name: staffName,
          email: String(user.email || "").toLowerCase(),
          status: user.banned_until ? "Disabled" : "Active",
          source_app: "Supabase Auth",
          notes: "Synced from Supabase Auth",
        };
      });

    if (rows.length) {
      await supabaseJson(
        `${supabaseUrl}/rest/v1/staff_directory?on_conflict=email`,
        {
          method: "POST",
          headers: {
            ...supabaseHeaders(serviceKey),
            Prefer: "resolution=merge-duplicates",
          },
          body: JSON.stringify(rows),
        },
        "Save shared staff directory",
      );
    }

    return json(`Synced ${rows.length} staff users into the shared staff directory.`, 200, { count: rows.length });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Staff sync failed.";
    if (message.toLowerCase().includes("permission denied for schema commission_tracker")) {
      return json("Staff sync needs one Supabase permission fix. Run supabase/fix-api-permissions.sql, then try Sync again.", 500, { originalError: message });
    }
    return json(message, 500);
  }
}
