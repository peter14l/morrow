import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get("SUPABASE_URL") || '';
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEY") || '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const url = new URL(req.url);
    const action = url.searchParams.get('action');

    if (req.method === 'GET' && action === 'get_state') {
      // Get stored ratchet state for a peer
      const peerId = url.searchParams.get('peer_id');
      if (!peerId) {
        return new Response(
          JSON.stringify({ error: 'Missing peer_id parameter' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Try RPC first
      let { data, error } = await supabase.rpc('get_pq_ratchet_state', {
        p_user_id: user.id,
        p_peer_id: peerId,
      });

      // Fallback: Query the table directly if RPC is not found
      if (error && (error.message.includes('rpc') || error.message.includes('function') || error.code === 'PGRST202')) {
        console.log('[pq-aura-proxy] get_pq_ratchet_state RPC not found, falling back to direct select');
        const directResult = await supabase
          .from('pq_ratchet_state')
          .select('encrypted_state, state_nonce')
          .eq('user_id', user.id)
          .eq('peer_id', peerId);
        data = directResult.data;
        error = directResult.error;
      }

      if (error) {
        console.error('[pq-aura-proxy] get_state error:', error);
        return new Response(
          JSON.stringify({ error: 'Failed to get state', details: error.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (!data || data.length === 0) {
        return new Response(
          JSON.stringify({ state: null }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Return state as base64-encoded strings
      const state = data[0];
      return new Response(
        JSON.stringify({
          state: {
            encrypted_state: Array.from(new Uint8Array(state.encrypted_state)),
            nonce: Array.from(new Uint8Array(state.state_nonce)),
          }
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (req.method === 'POST' && action === 'save_state') {
      // Save ratchet state for a peer
      const body = await req.json();
      const { peer_id, encrypted_state, nonce } = body;

      if (!peer_id || !encrypted_state || !nonce) {
        return new Response(
          JSON.stringify({ error: 'Missing required fields: peer_id, encrypted_state, nonce' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Convert arrays back to Uint8Array for BYTEA storage
      const encryptedStateBytes = new Uint8Array(encrypted_state);
      const nonceBytes = new Uint8Array(nonce);

      // Try RPC first
      let { error } = await supabase.rpc('upsert_pq_ratchet_state', {
        p_user_id: user.id,
        p_peer_id: peer_id,
        p_encrypted_state: encryptedStateBytes,
        p_state_nonce: nonceBytes,
      });

      // Fallback: Upsert table directly if RPC is not found
      if (error && (error.message.includes('rpc') || error.message.includes('function') || error.code === 'PGRST202')) {
        console.log('[pq-aura-proxy] upsert_pq_ratchet_state RPC not found, falling back to direct upsert');
        const directResult = await supabase
          .from('pq_ratchet_state')
          .upsert({
            user_id: user.id,
            peer_id: peer_id,
            encrypted_state: encrypted_state, // raw array is fine for postgrest json payload
            state_nonce: nonce,
            updated_at: new Date().toISOString()
          }, { onConflict: 'user_id,peer_id' });
        error = directResult.error;
      }

      if (error) {
        console.error('[pq-aura-proxy] save_state error:', error);
        return new Response(
          JSON.stringify({ error: 'Failed to save state', details: error.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (req.method === 'POST' && action === 'delete_state') {
      // Delete ratchet state for a peer
      const body = await req.json();
      const { peer_id } = body;

      if (!peer_id) {
        return new Response(
          JSON.stringify({ error: 'Missing peer_id' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const { error } = await supabase
        .from('pq_ratchet_state')
        .delete()
        .eq('user_id', user.id)
        .eq('peer_id', peer_id);

      if (error) {
        return new Response(
          JSON.stringify({ error: 'Failed to delete state' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Invalid action. Use ?action=get_state (GET) or ?action=save_state|delete_state (POST)' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (e) {
    console.error('[pq-aura-proxy] Unhandled error:', e);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
