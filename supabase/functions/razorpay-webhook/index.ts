import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { createHmac } from "node:crypto"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const textBody = await req.text()
    const signature = req.headers.get('X-Razorpay-Signature')
    const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')
    
    if (webhookSecret && signature) {
      const expectedSignature = createHmac('sha256', webhookSecret)
        .update(textBody)
        .digest('hex')
      if (expectedSignature !== signature) {
        throw new Error('Unauthorized: Invalid Webhook Signature')
      }
    }

    const payload = JSON.parse(textBody)
    const event = payload.event
    
    console.log(`[Razorpay Webhook] Received event: ${event}`)

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    if (event === 'subscription.charged' || event === 'payment.captured') {
      const isSubscription = event === 'subscription.charged'
      const entity = isSubscription ? payload.payload.subscription.entity : payload.payload.payment.entity
      
      console.log(`[Razorpay Webhook] Processing ${event}: ${entity.id}`)

      // For one-time payments, we might need to find the user via notes or metadata if not provided in payload
      // For now, let's assume we have user_id in notes or subscription mapping exists
      let userId = entity.notes?.user_id
      
      if (!userId && isSubscription) {
        const { data: subData } = await supabaseAdmin
          .from('subscriptions')
          .select('user_id')
          .eq('provider_subscription_id', entity.id)
          .maybeSingle()
        userId = subData?.user_id
      }

      if (!userId) {
        console.error(`[Razorpay Webhook] Could not find user_id for ${event} ${entity.id}`)
        return new Response(JSON.stringify({ error: 'User not found in metadata' }), { status: 200 }) // Return 200 to acknowledge receipt anyway
      }

      // 1. Update Profile (Idempotent)
      await supabaseAdmin.from('profiles').update({ is_pro: true }).eq('id', userId)

      // 2. Update Subscription Record (Idempotent Upsert)
      const periodEnd = new Date()
      periodEnd.setDate(periodEnd.getDate() + 30)

      await supabaseAdmin.from('subscriptions').upsert({
        user_id: userId,
        status: 'active',
        payment_provider: 'razorpay',
        provider_payment_id: isSubscription ? payload.payload.payment.entity.id : entity.id,
        provider_subscription_id: isSubscription ? entity.id : null,
        current_period_end: periodEnd.toISOString(),
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' })
      
      console.log(`[Razorpay Webhook] Successfully processed ${event} for user ${userId}`)
    } 
    else if (event === 'subscription.cancelled' || event === 'subscription.halted') {
      const subscription = payload.payload.subscription.entity
      console.log(`[Razorpay Webhook] Subscription cancelled/halted: ${subscription.id}`)

      const { data: subData } = await supabaseAdmin
        .from('subscriptions')
        .select('user_id')
        .eq('provider_subscription_id', subscription.id)
        .maybeSingle()

      if (subData) {
        // Mark as canceled
        await supabaseAdmin.from('subscriptions').update({
          status: 'canceled',
          updated_at: new Date().toISOString()
        }).eq('user_id', subData.user_id)

        // Revoke Pro status
        await supabaseAdmin.from('profiles').update({ is_pro: false }).eq('id', subData.user_id)
      }
    }

    return new Response(JSON.stringify({ received: true }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200 
    })
  } catch (error) {
    console.error(`[Razorpay Webhook Error] ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400 
    })
  }
})
