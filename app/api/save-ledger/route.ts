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

export async function POST(request: NextRequest) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const callerToken = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json("Ledger save is not configured on Render. Add the Supabase environment variables.", 500);
  }
  if (!callerToken) return json("Please sign in before adding a ledger.", 401);

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
      return json("Only a Commission Tracker user with Manage users access can add a ledger.", 403);
    }

    const body = await request.json();
    const ledgerName = String(body.name || "").trim();
    if (!ledgerName) return json("Ledger name is required.", 400);

    const inserted = await supabaseJson(
      `${supabaseUrl}/rest/v1/commission_ledgers`,
      {
        method: "POST",
        headers: dbHeaders(serviceKey, undefined, { Prefer: "return=representation" }),
        body: JSON.stringify({
          ledger_name: ledgerName,
          status: "Active",
          notes: "Created from Commission Tracker",
        }),
      },
      "Save ledger",
    ) as Array<{ id: string; ledger_name: string; status: string }>;

    const ledger = inserted[0];
    if (!ledger?.id) return json("Ledger was saved, but Supabase did not return the ledger ID.", 500);

    await supabaseJson(
      `${supabaseUrl}/rest/v1/user_ledger_access?on_conflict=user_id,ledger_id`,
      {
        method: "POST",
        headers: dbHeaders(serviceKey, undefined, { Prefer: "resolution=ignore-duplicates" }),
        body: JSON.stringify({ user_id: authUser.id, ledger_id: ledger.id }),
      },
      "Give current user ledger access",
    );

    return json(`Ledger ${ledger.ledger_name} added.`, 200, { ledger });
  } catch (error) {
    return json(error instanceof Error ? error.message : "Could not add ledger.", 500);
  }
}
