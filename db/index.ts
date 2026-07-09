export function getDb() {
  throw new Error(
    "Database connection is not enabled yet. The hosted Commission Tracker will use Supabase when the database step is connected."
  );
}
