import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Cloudflare sets the cf-ipcountry header for all requests routed through it.
    // Supabase Edge Functions run on Deno/Cloudflare, so this is readily available.
    const countryCode = req.headers.get('cf-ipcountry') || 
                        req.headers.get('x-vercel-ip-country') || 
                        'US';

    return new Response(
      JSON.stringify({ country_code: countryCode.toUpperCase() }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
