# ⚡ Spark — Micro-Mentorship Marketplace

> Book 20-minute expert advice sessions. No long commitments. Real advice, real results.

Built with **Next.js 16.2**, **Tailwind CSS 4**, **Supabase**, **Stripe Connect**, and **Claude AI**.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 16.2 (App Router) |
| Styling | Tailwind CSS 4.1 (CSS-native config) |
| Database | Supabase (Postgres 16) |
| Auth | Supabase Auth (Google OAuth) |
| Payments | Stripe Connect (20% platform split) |
| AI | Anthropic Claude Sonnet 4.5 |
| Scheduling | Cal.com embed |
| Hosting | Netlify (serverless functions) |
| Charts | Recharts |

---

## 🚀 Quick Start

### 1. Install

```bash
npm install
cp .env.example .env.local
# Fill in your credentials
```

### 2. Set Up Database

Run `supabase-schema.sql` in your Supabase SQL editor.

### 3. Run Dev Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## 📁 Structure

```
src/
├── app/
│   ├── page.tsx                   # Landing page
│   ├── experts/page.tsx           # Discovery + search
│   ├── experts/[id]/page.tsx      # Profile + booking + AI prep
│   ├── dashboard/page.tsx         # Expert dashboard + charts
│   ├── onboarding/page.tsx        # Multi-step expert application
│   └── api/
│       ├── experts/               # GET with filters, POST apply
│       ├── booking/               # Session booking
│       ├── payments/              # Stripe intents + webhooks
│       ├── ai/session-prep/       # Claude prep guide
│       ├── ai/session-summary/    # Claude post-session summary
│       └── reviews/               # Session reviews
├── components/
│   ├── layout/ (Navbar, Footer)
│   ├── expert/ (ExpertCard, FilterSidebar)
│   └── ui/ (StarRating)
├── lib/ (supabase, mock-data, utils)
└── types/
```

---

## 💰 Revenue Model

```
Learner pays ₹650 per session
├── Expert receives: ₹520 (80%)
└── Platform fee:   ₹130 (20%)
```

Stripe Connect handles automatic split on every transaction.

---

## 🤖 AI Features (Claude Sonnet 4.5)

- **Session Prep**: Learner inputs question → Claude generates agenda + key questions
- **Session Summary**: Transcript → Claude generates insights + action items

---

## 🚢 Deploy to Netlify

```bash
netlify deploy --prod
```

All API routes run as serverless functions via `@netlify/plugin-nextjs`.
