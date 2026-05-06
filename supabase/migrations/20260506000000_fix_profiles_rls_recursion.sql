-- Fix for infinite recursion (42P17) in profiles relation when updating/deleting posts
-- The issue is caused by the UPDATE policy on profiles doing a sub-select on profiles.

-- Create a SECURITY DEFINER function to check pro status without triggering RLS
CREATE OR REPLACE FUNCTION public.check_is_pro_status(profile_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_pro FROM public.profiles WHERE id = profile_id;
$$;

-- Replace the problematic recursive policy
DROP POLICY IF EXISTS "Users can update own profile except pro status" ON public.profiles;

CREATE POLICY "Users can update own profile except pro status"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id 
    AND (
        -- Protect is_pro from being updated by the user directly.
        -- Uses a SECURITY DEFINER function to bypass RLS and prevent infinite recursion.
        is_pro = public.check_is_pro_status(id)
    )
);
