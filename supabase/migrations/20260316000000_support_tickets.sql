-- Pari Concierge: in-app support tickets (no third-party SDKs).
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email text NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON public.support_tickets (user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created ON public.support_tickets (created_at DESC);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own support tickets" ON public.support_tickets;
CREATE POLICY "Users can insert their own support tickets" ON public.support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Staff/admin can read/update (optional: add service role or app-specific role later).
-- For now, users cannot read their own tickets via RLS; they get confirmation in-app only.
DROP POLICY IF EXISTS "Users can read own support tickets" ON public.support_tickets;
CREATE POLICY "Users can read own support tickets" ON public.support_tickets
  FOR SELECT USING (auth.uid() = user_id);
