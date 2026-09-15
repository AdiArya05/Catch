import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("LIVE_ACTIVITY_CRON_SECRET") ?? "";
const LTA_KEY = Deno.env.get("LTA_ACCOUNT_KEY") ?? "";
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_PRIVATE_KEY = (Deno.env.get("APNS_PRIVATE_KEY") ?? "").replaceAll("\\n", "\n");
const APNS_TOPIC = "com.adityaarya.catch.push-type.liveactivity";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

type Subscription = {
  activity_id: string;
  push_token: string;
  stop_code: string;
  service_no: string;
  progress_started_at: string;
  last_arrival_at: string | null;
  environment: "sandbox" | "production";
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json" },
});

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function utf8(value: string): Uint8Array { return new TextEncoder().encode(value); }

async function apnsJWT(): Promise<string> {
  const header = base64url(utf8(JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID })));
  const claims = base64url(utf8(JSON.stringify({ iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) })));
  const signingInput = `${header}.${claims}`;
  const der = Uint8Array.from(atob(APNS_PRIVATE_KEY.replace(/-----[^-]+-----|\s/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, utf8(signingInput)));
  return `${signingInput}.${base64url(signature)}`;
}

function appleDate(date: Date): number {
  return date.getTime() / 1000 - 978307200;
}

function arrivalDate(value: unknown): Date | null {
  if (typeof value !== "string" || value.length === 0) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

async function register(req: Request, body: Record<string, unknown>): Promise<Response> {
  const authorization = req.headers.get("authorization") ?? "";
  const client = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
  });
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) return json({ error: "unauthorized" }, 401);

  const activityID = String(body.activity_id ?? "");
  const pushToken = String(body.push_token ?? "");
  const stopCode = String(body.stop_code ?? "");
  const serviceNo = String(body.service_no ?? "");
  const environment = String(body.environment ?? "");
  const progressStartedAt = new Date(String(body.progress_started_at ?? ""));
  if (!activityID || !/^[0-9a-f]{32,}$/.test(pushToken) || !/^[0-9]{5}$/.test(stopCode) ||
      !serviceNo || !["sandbox", "production"].includes(environment) || Number.isNaN(progressStartedAt.getTime())) {
    return json({ error: "invalid registration" }, 400);
  }
  const { error: writeError } = await admin.from("live_activity_subscriptions").upsert({
    activity_id: activityID, user_id: user.id, push_token: pushToken, stop_code: stopCode,
    service_no: serviceNo, progress_started_at: progressStartedAt.toISOString(),
    environment, expires_at: new Date(Date.now() + 4 * 3600_000).toISOString(), updated_at: new Date().toISOString(),
  }, { onConflict: "activity_id" });
  return writeError ? json({ error: "registration failed" }, 500) : json({ registered: true });
}

async function remove(req: Request, body: Record<string, unknown>): Promise<Response> {
  const authorization = req.headers.get("authorization") ?? "";
  const client = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
  });
  const { data: { user } } = await client.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);
  await admin.from("live_activity_subscriptions").delete().eq("activity_id", String(body.activity_id ?? "")).eq("user_id", user.id);
  return json({ removed: true });
}

async function refresh(): Promise<Response> {
  if (![CRON_SECRET, LTA_KEY, APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY].every(Boolean)) {
    return json({ error: "server secrets incomplete" }, 503);
  }
  await admin.from("live_activity_subscriptions").delete().lt("expires_at", new Date().toISOString());
  const { data, error } = await admin.from("live_activity_subscriptions").select("activity_id,push_token,stop_code,service_no,progress_started_at,last_arrival_at,environment");
  if (error) return json({ error: "read failed" }, 500);
  const jwt = await apnsJWT();
  let delivered = 0;

  for (const sub of (data ?? []) as Subscription[]) {
    const lta = await fetch(`https://datamall2.mytransport.sg/ltaodataservice/v3/BusArrival?BusStopCode=${encodeURIComponent(sub.stop_code)}`, { headers: { AccountKey: LTA_KEY } });
    if (!lta.ok) continue;
    const payload = await lta.json();
    const service = payload.Services?.find((item: { ServiceNo?: string }) => item.ServiceNo === sub.service_no);
    if (!service) continue;
    const buses = [service.NextBus, service.NextBus2, service.NextBus3];
    const next = arrivalDate(buses[0]?.EstimatedArrival);
    if (!next) continue;
    const prior = sub.last_arrival_at ? new Date(sub.last_arrival_at) : null;
    const rolledOver = prior && prior <= new Date() && next.getTime() - prior.getTime() > 60_000;
    const progressStart = rolledOver ? new Date() : new Date(sub.progress_started_at);
    const minutes = buses.map((bus: Record<string, unknown>) => {
      const date = arrivalDate(bus?.EstimatedArrival);
      return date ? Math.max(0, Math.floor((date.getTime() - Date.now()) / 60_000)) : null;
    });
    const state = {
      services: [{ serviceNo: sub.service_no, arrivals: minutes,
        busTypes: buses.map((bus: Record<string, unknown>) => bus?.Type ?? null),
        features: buses.map((bus: Record<string, unknown>) => bus?.Feature ?? null),
        arrivalDate: appleDate(next), load: buses[0]?.Load ?? null }],
      updatedAt: appleDate(new Date()), progressStartedAt: appleDate(progressStart),
    };
    const host = sub.environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
    const response = await fetch(`https://${host}/3/device/${sub.push_token}`, {
      method: "POST",
      headers: { authorization: `bearer ${jwt}`, "apns-topic": APNS_TOPIC, "apns-push-type": "liveactivity", "apns-priority": "5" },
      body: JSON.stringify({ aps: { timestamp: Math.floor(Date.now() / 1000), event: "update", "stale-date": Math.floor(next.getTime() / 1000) + 30, "content-state": state } }),
    });
    if (response.ok) delivered += 1;
    if (response.status === 410 || response.status === 400) await admin.from("live_activity_subscriptions").delete().eq("activity_id", sub.activity_id);
    else await admin.from("live_activity_subscriptions").update({ last_arrival_at: next.toISOString(), progress_started_at: progressStart.toISOString(), updated_at: new Date().toISOString() }).eq("activity_id", sub.activity_id);
  }
  return json({ delivered });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "invalid JSON" }, 400); }
  if (body.action === "register") return register(req, body);
  if (body.action === "remove") return remove(req, body);
  if (body.action === "refresh" && req.headers.get("x-catch-cron-secret") === CRON_SECRET) return refresh();
  return json({ error: "unauthorized" }, 401);
});
