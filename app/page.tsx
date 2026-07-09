const items = [
  "Standalone tracker is available at /commission-calculator.html",
  "Supabase schema draft is in supabase/schema.sql",
  "Migration plan is in docs/migration-plan.md",
  "Render setup draft is in render.yaml",
];

export default function Home() {
  return (
    <main className="min-h-screen bg-slate-100 px-6 py-10 text-slate-950">
      <section className="mx-auto max-w-5xl">
        <div className="mb-6">
          <p className="text-sm font-semibold uppercase text-blue-700">
            Commission Tracker
          </p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">
            GitHub, Render, and Supabase preparation
          </h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
            This project is ready to be pushed to GitHub and connected to Render.
            The current audited standalone tracker is included while the
            Supabase-backed multi-user version is built.
          </p>
        </div>

        <div className="grid gap-4 md:grid-cols-[1.2fr_0.8fr]">
          <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
            <h2 className="text-lg font-semibold">Open Current Tracker</h2>
            <p className="mt-2 text-sm text-slate-600">
              Use this link for the current browser-storage version.
            </p>
            <a
              className="mt-4 inline-flex rounded-md bg-blue-700 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-800"
              href="/commission-calculator.html"
            >
              Open Commission Tracker
            </a>
          </section>

          <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
            <h2 className="text-lg font-semibold">Next Build Target</h2>
            <p className="mt-2 text-sm leading-6 text-slate-600">
              Convert local browser storage to Supabase, then add real login,
              permissions, shared data, and audit history.
            </p>
          </section>
        </div>

        <section className="mt-4 rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <h2 className="text-lg font-semibold">Included Setup Files</h2>
          <ul className="mt-3 grid gap-2 text-sm text-slate-700 md:grid-cols-2">
            {items.map((item) => (
              <li className="rounded-md bg-slate-50 px-3 py-2" key={item}>
                {item}
              </li>
            ))}
          </ul>
        </section>
      </section>
    </main>
  );
}
