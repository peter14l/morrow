import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    })
  }

  try {
    const { email, type = "reset" } = await req.json()

    if (!email) {
      return new Response(JSON.stringify({ error: "Email is required" }), {
        status: 400,
      })
    }

    // Get environment variables
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const brevoApiKey = Deno.env.get("BREVO_API_KEY") || Deno.env.get("SENDINBLUE_API_KEY")
    const resendApiKey = Deno.env.get("RESEND_API_KEY")
    const sendgridApiKey = Deno.env.get("SENDGRID_API_KEY")

    console.log(`Processing password reset for: ${email}`)

    // Create Supabase admin client
    const supabaseAdmin = await createSupabaseAdminClient(supabaseUrl, serviceRoleKey)

    // Find user by email
    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.listUsers()

    if (userError) {
      return new Response(JSON.stringify({ error: "Failed to list users" }), {
        status: 500,
      })
    }

    // Find user with matching email
    const user = userData.users.find((u) => 
      u.email?.toLowerCase() === email.toLowerCase()
    )

    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404,
      })
    }

    // Generate password reset link using Supabase Admin API
    // This creates a valid reset token without sending email
    // IMPORTANT: Use the Supabase auth callback URL, not the app URL directly
    // The auth callback will validate the token and redirect to the app
    const siteUrl = Deno.env.get("SITE_URL") || "https://oasis-web-red.vercel.app"
    const fromEmail = Deno.env.get("BREVO_FROM_EMAIL") || Deno.env.get("RESEND_FROM_EMAIL") || Deno.env.get("SENDGRID_FROM_EMAIL") || "baban012008@gmail.com"
    const fromName = Deno.env.get("BREVO_FROM_NAME") || Deno.env.get("RESEND_FROM_NAME") || Deno.env.get("SENDGRID_FROM_NAME") || "Oasis"
    
    const callbackUrl = `${supabaseUrl}/auth/v1/callback?redirect_to=${siteUrl}/reset-password`
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: "recovery",
      email: email,
      // Supabase will redirect to this URL after validating the token
      // This must be registered in Supabase Dashboard → Authentication → URL Configuration
      redirectTo: callbackUrl,
    })

    if (linkError || !linkData) {
      console.error("generateLink error:", linkError)
      return new Response(JSON.stringify({ error: "Failed to generate reset link", details: linkError?.message }), {
        status: 500,
      })
    }

    // Extract the reset link - properties.href contains the full URL with token
    const resetLink = linkData.properties?.href

    if (!resetLink) {
      console.error("No href in linkData:", linkData)
      return new Response(JSON.stringify({ error: "Failed to generate reset link - no href in response" }), {
        status: 500,
      })
    }

    console.log("Generated reset link successfully")

    // Email content
    const emailSubject = type === "magic" 
      ? "Your Magic Sign-in Link" 
      : "Reset your password"
    
    const emailHtml = type === "magic"
      ? `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
          <h1>Sign in to Oasis</h1>
          <p>Click the button below to sign in to your account:</p>
          <a href="${resetLink}" style="display: inline-block; background: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 16px 0;">
            Sign In
          </a>
          <p style="color: #6B7280; font-size: 14px;">
            This link expires in 1 hour.<br>
            If you didn't request this, you can safely ignore this email.
          </p>
        </div>
      `
      : `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
          <h1>Reset Your Password</h1>
          <p>Click the button below to reset your password:</p>
          <a href="${resetLink}" style="display: inline-block; background: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 16px 0;">
            Reset Password
          </a>
          <p style="color: #6B7280; font-size: 14px;">
            This link expires in 1 hour.<br>
            If you didn't request a password reset, you can safely ignore this email.
          </p>
        </div>
      `

    let emailSent = false
    let lastError = ""

    // 1. Try Brevo API if key is present
    if (brevoApiKey) {
      const brevoResponse = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": brevoApiKey,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          sender: { name: fromName, email: fromEmail },
          to: [{ email: email }],
          subject: emailSubject,
          htmlContent: emailHtml,
        }),
      })

      if (brevoResponse.ok) {
        emailSent = true
      } else {
        lastError = await brevoResponse.text()
        console.error("Brevo API error:", lastError)
      }
    }

    // 2. Fallback to Resend if Brevo is not set or failed
    if (!emailSent && resendApiKey) {
      const resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `${fromName} <${fromEmail}>`,
          to: [email],
          subject: emailSubject,
          html: emailHtml,
        }),
      })

      if (resendResponse.ok) {
        emailSent = true
      } else {
        lastError = await resendResponse.text()
        console.error("Resend API error:", lastError)
      }
    }

    // 3. Fallback to SendGrid if configured
    if (!emailSent && sendgridApiKey) {
      const sendgridResponse = await fetch("https://api.sendgrid.com/v3/mail/send", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${sendgridApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          personalizations: [{ to: [{ email }] }],
          from: { email: fromEmail, name: fromName },
          subject: emailSubject,
          content: [{ type: "text/html", value: emailHtml }],
        }),
      })

      if (sendgridResponse.ok) {
        emailSent = true
      } else {
        lastError = await sendgridResponse.text()
        console.error("SendGrid API error:", lastError)
      }
    }

    if (!emailSent) {
      return new Response(JSON.stringify({ error: "Failed to send email", details: lastError }), {
        status: 500,
      })
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: "Password reset email sent" 
    }), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (error) {
    console.error("Error:", error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    })
  }
})

// Helper function to create Supabase admin client
async function createSupabaseAdminClient(url: string, serviceKey: string) {
  // Dynamic import for Supabase admin
  const supabaseModule = await import("https://esm.sh/@supabase/supabase-js@2")
  return supabaseModule.createClient(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  })
}