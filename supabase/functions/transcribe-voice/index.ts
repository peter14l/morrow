import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // 0. AUTHENTICATION: Verify the caller
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No authorization header')
    
    const token = authHeader.replace('Bearer ', '')
    
    // Create a regular client first to verify the user
    const supabaseUserClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    
    const { data: { user }, error: authError } = await supabaseUserClient.auth.getUser()
    
    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    const { message_id, audio_url } = await req.json()
    const openAIKey = Deno.env.get('OPENAI_API_KEY')

    // 1. Download audio file
    const audioResponse = await fetch(audio_url)
    if (!audioResponse.ok) throw new Error('Failed to download audio file')
    const audioBlob = await audioResponse.blob()

    // 2. Prepare Form Data for OpenAI
    const formData = new FormData()
    formData.append('file', audioBlob, 'audio.m4a')
    formData.append('model', 'whisper-1')
    formData.append('response_format', 'json')

    // 3. Request Transcription
    const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${openAIKey}` },
      body: formData
    })

    const result = await whisperResponse.json()
    if (!whisperResponse.ok) throw new Error(result.error?.message || 'Whisper API failed')

    // 4. Update Database using Service Role to bypass RLS for writes
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const transcriptData = {
      message_id,
      text: result.text,
      language: result.language || 'en', // Whisper detects language automatically
      confidence: 1.0
    }

    await supabase.from('message_transcripts').upsert(transcriptData)

    return new Response(JSON.stringify(transcriptData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  } catch (error) {
    console.error(`[Transcription Error] ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
