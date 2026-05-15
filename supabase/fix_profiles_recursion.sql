-- Final fix for profiles RLS recursion (42P17)
-- This script resolves the infinite recursion detected in the profiles table policy.
-- It redefines the helper function to prevent inlining and consolidates the UPDATE policy.

-- 1. Redefine the helper function with plpgsql to prevent inlining
CREATE OR REPLACE FUNCTION public.check_is_pro_status(profile_id uuid)
RETURNS boolean 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public AS $$
DECLARE
    v_is_pro boolean;
BEGIN
    SELECT is_pro INTO v_is_pro FROM public.profiles WHERE id = profile_id;
    RETURN COALESCE(v_is_pro, false);
END;
$$;

-- 2. Consolidate and simplify the UPDATE policy
-- Drops all previous variations to prevent conflicts
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own encryption keys" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile except pro status" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id 
    AND (
        -- Protect is_pro status from being changed by the user directly.
        -- The function check_is_pro_status is SECURITY DEFINER and plpgsql, so it bypasses RLS securely.
        is_pro = public.check_is_pro_status(id)
    )
);

-- 3. Ensure the SELECT policy is clean and not recursive
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
ON public.profiles FOR SELECT
TO anon
USING (is_private = FALSE);

-- 4. Ensure INSERT and DELETE are also safe
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can delete their own profile" ON public.profiles;
CREATE POLICY "Users can delete their own profile" 
ON public.profiles FOR DELETE 
USING (auth.uid() = id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
