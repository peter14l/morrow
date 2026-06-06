import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { endpoint, query, isSticker = false, limit = 20, offset = 0, platform = 'web' } = await req.json()

    // Retrieve corresponding Giphy key from environment
    let apiKey = Deno.env.get('GIPHY_WEB_KEY')
    if (platform === 'android') {
      apiKey = Deno.env.get('GIPHY_ANDROID_KEY') || apiKey
    } else if (platform === 'ios') {
      apiKey = Deno.env.get('GIPHY_IOS_KEY') || apiKey
    } else if (platform === 'windows') {
      apiKey = Deno.env.get('GIPHY_WINDOWS_KEY') || apiKey
    } else if (platform === 'macos') {
      apiKey = Deno.env.get('GIPHY_MACOS_KEY') || apiKey
    }

    if (!apiKey) {
      throw new Error('Giphy API Key is not configured on the server.')
    }

    const type = isSticker ? 'stickers' : 'gifs'
    const baseUrl = 'https://api.giphy.com/v1'
    let targetUrl = ''

    if (endpoint === 'search') {
      if (!query) {
        throw new Error('Query parameter is required for search endpoint.')
      }
      targetUrl = `${baseUrl}/${type}/search?api_key=${apiKey}&q=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}&rating=g`
    } else if (endpoint === 'trending') {
      targetUrl = `${baseUrl}/${type}/trending?api_key=${apiKey}&limit=${limit}&offset=${offset}&rating=g`
    } else {
      throw new Error(`Unsupported endpoint: ${endpoint}`)
    }

    const response = await fetch(targetUrl, { method: 'GET' })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Giphy API returned status ${response.status}: ${errorText}`)
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
