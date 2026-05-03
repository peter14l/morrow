import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json()
    const { event } = body
    
    if (!event) throw new Error('No event found in request body')

    // 1. Authenticate Webhook
    const authHeader = req.headers.get('Authorization')
    const expectedToken = Deno.env.get('RC_WEBHOOK_AUTH_TOKEN')
    
    if (expectedToken && authHeader !== `Bearer ${expectedToken}` && authHeader !== expectedToken) {
      throw new Error('Unauthorized: Invalid or missing Webhook Auth Token')
    }

    // 2. Setup Supabase
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const userId = event.app_user_id
    const eventType = event.type
    const productId = event.product_id
    const expirationAtMs = event.expiration_at_ms
    const store = event.store
    const transactionId = event.transaction_id

    console.log(`[RevenueCat Webhook] Processing ${eventType} for user ${userId}`)

    // 2. Map RevenueCat events to subscription status
    let status = 'active'
    if (eventType === 'EXPIRATION' || eventType === 'BILLING_ISSUE') {
      status = 'expired'
    } else if (eventType === 'CANCELLATION') {
      // In RC, CANCELLATION means the user turned off auto-renew, not necessarily that access is revoked immediately.
      // But we can update the cancel_at_period_end flag if our table supports it.
    }

    // 3. Update Subscriptions table
    const { error: upsertError } = await supabase.from('subscriptions').upsert({
      user_id: userId,
      status: status,
      plan_id: productId,
      payment_provider: `revenuecat_${store.toLowerCase()}`,
      provider_subscription_id: transactionId,
      current_period_start: new Date(event.purchased_at_ms).toISOString(),
      current_period_end: new Date(expirationAtMs).toISOString(),
    }, { onConflict: 'user_id' })

    if (upsertError) throw upsertError

    // 4. Sync Pro status to profiles table (if your schema uses is_pro flag there)
    const isPro = status === 'active' && (event.entitlement_ids?.includes('Oasis Pro') ?? false)
    
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ is_pro: isPro })
      .eq('id', userId)

    if (profileError) {
      console.warn(`[RevenueCat Webhook] Failed to update profile is_pro: ${profileError.message}`)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error(`[RevenueCat Webhook Error] ${error.message}`)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
