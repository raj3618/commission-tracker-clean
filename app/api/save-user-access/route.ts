import { NextRequest, NextResponse } from "next/server";

const SUPABASE_SCHEMA = "commission_tracker";

function json(message: string, status = 200, extra: Record<string, unknown> = {}) {
  return NextResponse.json({ message, ...extra }, { status });
}

function dbHeaders(key: string, token?: string, extra: Record<string, string> = {}) {
  return {
    apikey: key,
    Authorization: `Bearer ${token || key}`,
    "Content-Type": "application/json",
    "Accept-Profile": SUPABASE_SCHEMA,
    "Content-Profile": SUPABASE_SCHEMA,
    ...extra,
  };
}

function authHeaders(key: string, token?: string) {
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

function isUuid(value: unknown) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || ""));
}

export async function POST(request: NextRequest) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const callerToken = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json("User access save is not configured on Render. Add the Supabase environment variables.", 500);
  }
  if (!callerToken) return json("Please sign in before saving user access.", 401);

  try {
    const authUser = await supabaseJson(
      `${supabaseUrl}/auth/v1/user`,
      { headers: authHeaders(anonKey, callerToken) },
      "Login check",
    ) as { id?: string };

    if (!authUser.id) return json("Signed-in user could not be verified.", 401);

    const callerProfiles = await supabaseJson(
      `${supabaseUrl}/rest/v1/user_profiles?select=id,permissions,status&id=eq.${encodeURIComponent(authUser.id)}`,
      { headers: dbHeaders(serviceKey) },
      "Permission check",
    ) as Array<{ permissions?: string[]; status?: string }>;

    const callerProfile = callerProfiles[0];
    if (!callerProfile || callerProfile.status !== "Active" || !callerProfile.permissions?.includes("manageUsers")) {
      return json("Only a Commission Tracker user with Manage users access can save user access.", 403);
    }

    const body = await request.json();
    const userId = String(body.id || "");
    const fullName = String(body.name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const status = body.status === "Disabled" ? "Disabled" : "Active";
    const notes = String(body.notes || "").trim();
    const permissions: string[] = Array.isArray(body.permissions) ? body.permissions.map(String) : [];
    const ledgerIds: string[] = Array.isArray(body.ledgerIds) ? body.ledgerIds.map(String).filter(isUuid) : [];

    if (!isUuid(userId)) return json("Select a shared staff member first. The staff member needs a Supabase Auth user ID.", 400);
    if (!fullName) return json("Staff name is required.", 400);
    if (!email) return json("Login email is required.", 400);

    await supabaseJson(
      `${supabaseUrl}/rest/v1/user_profiles`,
      {
        method: "POST",
        headers: dbHeaders(serviceKey, undefined, { Prefer: "resolution=merge-duplicates" }),
        body: JSON.stringify({
          id: userId,
          full_name: fullName,
          email,
          status,
          permissions,
          notes,
        }),
      },
      "Save user profile access",
    );

    await supabaseJson(
      `${supabaseUrl}/rest/v1/user_ledger_access?user_id=eq.${encodeURIComponent(userId)}`,
      {
        method: "DELETE",
        headers: dbHeaders(serviceKey),
      },
      "Clear old ledger access",
    );

    if (ledgerIds.length) {
      await supabaseJson(
        `${supabaseUrl}/rest/v1/user_ledger_access`,
        {
          method: "POST",
          headers: dbHeaders(serviceKey),
          body: JSON.stringify(ledgerIds.map(ledgerId => ({ user_id: userId, ledger_id: ledgerId }))),
        },
        "Save ledger access",
      );
    }

    await supabaseJson(
      `${supabaseUrl}/rest/v1/staff_directory?on_conflict=email`,
      {
        method: "POST",
        headers: dbHeaders(serviceKey, undefined, { Prefer: "resolution=merge-duplicates" }),
        body: JSON.stringify({
          auth_user_id: userId,
          staff_name: fullName,
          email,
          status,
          source_app: "Shared",
          notes,
        }),
      },
      "Save shared staff directory",
    );

    return json(`Commission Tracker access saved for ${fullName}.`);
  } catch (error) {
    return json(error instanceof Error ? error.message : "Could not save user access.", 500);
  }
}
