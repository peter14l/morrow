import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from 'npm:@aws-sdk/client-s3@3.341.0'
import { getSignedUrl } from 'npm:@aws-sdk/s3-request-presigner@3.341.0'
import { createClient } from 'npm:@supabase/supabase-js@2.39.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Validate User Session
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')
    const token = authHeader.replace('Bearer ', '').trim()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )
    
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError) throw new Error(`Auth Error: ${authError.message}`)
    if (!user) throw new Error('User not found')

    // 2. Parse Request
    const { bucket, fileId, type, method } = await req.json()
    // bucket: 'oasis' (CF), 'oasis-feed' (B2), 'oasis-ripples' (B2)
    // type: 'images', 'videos', 'documents', 'recordings', 'posts', 'ripples'
    // method: 'PUT', 'GET', or 'DELETE'
    // fileId: should be simple filename for PUT, but for our ChatMediaService it's "userId/filename"

    let clientConfig;
    if (bucket === 'oasis') {
      // Cloudflare R2 Configuration
      clientConfig = {
        region: 'auto',
        endpoint: `https://${Deno.env.get('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: Deno.env.get('R2_ACCESS_KEY_ID')!,
          secretAccessKey: Deno.env.get('R2_SECRET_ACCESS_KEY')!,
        },
      }
    } else if (bucket === 'oasis-feed' || bucket === 'oasis-ripples') {
      // Backblaze B2 Configuration
      const b2Endpoint = Deno.env.get('B2_ENDPOINT')!;
      // Extract region from endpoint (e.g. s3.eu-central-003.backblazeb2.com -> eu-central-003)
      const regionMatch = b2Endpoint.match(/s3\.([^.]+)\.backblazeb2\.com/);
      const b2Region = regionMatch ? regionMatch[1] : 'us-east-005';
      
      const endpoint = b2Endpoint.startsWith('http') ? b2Endpoint : `https://${b2Endpoint}`;

      clientConfig = {
        region: b2Region,
        endpoint: endpoint,
        credentials: {
          accessKeyId: Deno.env.get('B2_ACCESS_KEY_ID')!,
          secretAccessKey: Deno.env.get('B2_SECRET_ACCESS_KEY')!,
        },
      }
    } else {
      throw new Error('Invalid bucket')
    }

    const s3Client = new S3Client(clientConfig)
    
    // SECURITY: Enforce directory structure
    // Path: <type>/<user_id>/<file_name>

    // Extract filename from fileId (to prevent path traversal if user sends "../../etc")
    const parts = fileId.split('/');
    const fileName = parts.pop();
    // Uploads always land in the authenticated user's own folder.
    // GET/DELETE must respect the owner encoded in the fileId ("userId/fileName")
    // so a recipient can fetch (and decrypt) E2EE media uploaded by another user.
    const ownerId = method === 'PUT'
      ? user.id
      : (parts.length >= 1 && parts[0] ? parts[0] : user.id);
    const key = `${type}/${ownerId}/${fileName}`;
    
    let url;
    if (method === 'PUT') {
      const command = new PutObjectCommand({ Bucket: bucket, Key: key })
      // PUT URLs expire in 5 minutes
      url = await getSignedUrl(s3Client, command, { expiresIn: 300 })
    } else if (method === 'DELETE') {
      const command = new DeleteObjectCommand({ Bucket: bucket, Key: key })
      // DELETE URLs expire in 5 minutes
      url = await getSignedUrl(s3Client, command, { expiresIn: 300 })
    } else {
      const command = new GetObjectCommand({ Bucket: bucket, Key: key })
      // GET URLs expire in 1 hour
      url = await getSignedUrl(s3Client, command, { expiresIn: 3600 })
    }

    return new Response(
      JSON.stringify({ url, key }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
