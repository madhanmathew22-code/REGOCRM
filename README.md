# Rego Collections CRM

> **Ultra-minimalist, high-end SaaS Payment Collection CRM** built with Next.js 14, Supabase, and Tailwind CSS. Designed for corporate transport and fleet operations.

---

## ✨ Features

| Module | Details |
|---|---|
| **Auth** | Google OAuth via Supabase · Onboarding gate for new users |
| **Dashboard** | 4 KPI cards · 6-month collection chart · Recent invoice feed |
| **Customers** | Full CRUD · Sortable/searchable table · Status management |
| **Payments** | Invoice creation · Status tracking · Mock payment links |
| **Analytics** | 12-month area trend · Status pie chart · Top customer bar chart |
| **Bulk Import** | 4-step wizard: Upload → Column Mapping → Validation → Supabase batch upsert |
| **Settings** | Org name · Currency preferences |

---

## 🗂 Project Structure

```
src/
├── app/
│   ├── auth/
│   │   ├── callback/route.ts      # OAuth exchange handler
│   │   └── login/                 # Sign-in with Google page
│   ├── onboarding/page.tsx        # New user org setup
│   ├── dashboard/
│   │   ├── layout.tsx             # Sidebar layout (server)
│   │   ├── page.tsx               # Main dashboard
│   │   ├── customers/             # List + New + [id]
│   │   ├── payments/              # List + New + [id]
│   │   ├── import/page.tsx        # Bulk Excel wizard
│   │   ├── analytics/page.tsx     # Extended charts
│   │   └── settings/page.tsx      # Profile settings
│   ├── globals.css
│   └── layout.tsx                 # Root layout
├── components/
│   ├── Sidebar.tsx
│   ├── dashboard/                 # DashboardMetrics, CollectionChart, RecentPayments, AnalyticsCharts
│   ├── customers/                 # CustomersTable, CustomerForm
│   ├── payments/                  # PaymentsTable, PaymentForm
│   ├── import/                    # ImportWizard, WizardProgress, StepUpload, StepMapping, StepValidation, StepDone
│   └── settings/                  # SettingsForm
├── lib/
│   ├── supabase.ts                # Browser / Server / Middleware clients
│   ├── database.types.ts          # Auto-generated Supabase types
│   ├── auth-actions.ts            # Server Actions: signIn, signOut, completeOnboarding
│   └── utils.ts                   # formatCurrency, formatDate, etc.
├── middleware.ts                  # Auth guard + onboarding redirect
└── types/index.ts                 # Shared TypeScript types
supabase/
└── migrations/
    └── 001_initial_schema.sql     # Full schema + RLS policies
```

---

## 🚀 Quick Start

### 1. Clone & Install

```bash
git clone <your-repo>
cd rego-collections-crm
npm install
```

### 2. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) → New Project
2. Copy your **Project URL** and **anon/public key** from *Settings → API*

### 3. Environment Variables

```bash
cp .env.example .env.local
# Edit .env.local with your Supabase URL and anon key
```

### 4. Run the Database Migration

```bash
# Option A — Supabase CLI (recommended)
npx supabase db push

# Option B — Dashboard SQL Editor
# Paste the contents of supabase/migrations/001_initial_schema.sql
```

### 5. Configure Google OAuth

In the [Supabase Dashboard](https://supabase.com/dashboard):

1. **Authentication → Providers → Google** → Enable
2. Create a Google OAuth 2.0 app at [console.cloud.google.com](https://console.cloud.google.com)
3. Set Authorized redirect URIs:
   - `https://your-project-ref.supabase.co/auth/v1/callback`
4. Paste **Client ID** and **Client Secret** into Supabase
5. Add your site URL under **Authentication → URL Configuration → Redirect URLs**:
   - `http://localhost:3000/auth/callback` (dev)
   - `https://your-domain.com/auth/callback` (prod)

### 6. Run Dev Server

```bash
npm run dev
# → http://localhost:3000
```

---

## 📥 Bulk Excel Import — How It Works

| Step | What happens |
|---|---|
| **1 Upload** | Drag-and-drop `.xlsx`, `.xls`, or `.csv`. SheetJS parses the first sheet into JSON. |
| **2 Map Columns** | Auto-detects common header names (`Client Name → name`, `Amt Due → amount`, etc.). User can override any mapping via dropdown. |
| **3 Validate** | Each row is validated client-side. Errors (missing name, invalid email) block import. Warnings (unusual phone) allow proceeding. Rows are paginated with color coding. |
| **4 Import** | Valid rows are **batch-upserted** into Supabase in chunks of 50 — first customers, then payment records. Progress tracked, final count shown. |

---

## 🔒 Security & RLS

All three tables (`profiles`, `customers`, `payments`) have Row Level Security enabled. Every policy checks `auth.uid() = user_id`, ensuring complete data isolation between organisations. The Supabase anon key is safe to expose publicly.

---

## 🎨 Design System

- **Background layers**: `#0A0A0F` → `#0D0D1A` → `#16162A`
- **Brand**: Violet `#7C3AED` / Indigo `#4338CA`  
- **Status palette**: Emerald (paid) · Amber (partial/pending) · Red (overdue) · Blue (sent) · Gray (draft)
- **Typography**: Inter (variable font) with tight tracking for headings
- **Border style**: `rgba(255,255,255,0.06–0.10)` for all card borders

---

## 🛠 Tech Stack

| Layer | Choice |
|---|---|
| Framework | Next.js 14 (App Router, Server Components, Server Actions) |
| Database | Supabase (PostgreSQL + Auth + RLS) |
| Styling | Tailwind CSS v3 |
| Charts | Recharts |
| Excel Parsing | SheetJS (xlsx) |
| Icons | Lucide React |
| TypeScript | Strict mode |

---

## 📝 License

MIT © Rego Mobility
