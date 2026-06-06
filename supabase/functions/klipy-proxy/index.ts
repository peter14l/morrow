import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { endpoint, query, limit = 20, offset = 0, platform = 'web' } = await req.json()

    // Retrieve the corresponding Klipy Key from environment
    let apiKey = Deno.env.get('KLIPY_WEB_KEY')
    if (platform === 'android') {
      apiKey = Deno.env.get('KLIPY_ANDROID_KEY') || apiKey
    } else if (platform === 'ios') {
      apiKey = Deno.env.get('KLIPY_IOS_KEY') || apiKey
    } else if (platform === 'windows') {
      apiKey = Deno.env.get('KLIPY_WINDOWS_KEY') || apiKey
    } else if (platform === 'macos') {
      apiKey = Deno.env.get('KLIPY_MACOS_KEY') || apiKey
    }

    if (!apiKey) {
      throw new Error('Klipy API Key is not configured on the server.')
    }

    const baseUrl = 'https://api.klipy.com/api/v1'
    let targetUrl = ''

    if (endpoint === 'search') {
      if (!query) {
        throw new Error('Query parameter is required for search endpoint.')
      }
      targetUrl = `${baseUrl}/${apiKey}/gifs/search?q=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}`
    } else if (endpoint === 'trending') {
      targetUrl = `${baseUrl}/${apiKey}/gifs/trending?limit=${limit}&offset=${offset}`
    } else {
      throw new Error(`Unsupported endpoint: ${endpoint}`)
    }

    const response = await fetch(targetUrl, { method: 'GET' })

    if (response.status === 204) {
      return new Response(JSON.stringify({ data: { data: [] } }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Klipy API returned status ${response.status}: ${errorText}`)
    }

    const responseData = await response.json()
    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
