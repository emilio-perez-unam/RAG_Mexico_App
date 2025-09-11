// Supabase Edge Function to proxy OpenRouter API calls
// This handles CORS issues for web platform

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-openrouter-api-key',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the OpenRouter API key from the request header
    const openRouterApiKey = req.headers.get('x-openrouter-api-key')
    
    if (!openRouterApiKey) {
      return new Response(
        JSON.stringify({ error: 'OpenRouter API key is required' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Get the path from the URL (e.g., /chat/completions)
    const url = new URL(req.url)
    const path = url.pathname.replace('/openrouter-proxy', '')
    
    // Forward the request to OpenRouter
    const openRouterUrl = `https://openrouter.ai/api/v1${path}`
    
    // Get the request body
    const body = req.method === 'POST' ? await req.text() : undefined
    
    // Make the request to OpenRouter
    const openRouterResponse = await fetch(openRouterUrl, {
      method: req.method,
      headers: {
        'Authorization': `Bearer ${openRouterApiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://legalragmexico.com',
        'X-Title': 'Legal RAG Mexico',
      },
      body: body,
    })

    // Get the response body
    const responseBody = await openRouterResponse.text()
    
    // Return the response with CORS headers
    return new Response(responseBody, {
      status: openRouterResponse.status,
      headers: {
        ...corsHeaders,
        'Content-Type': openRouterResponse.headers.get('Content-Type') || 'application/json',
      },
    })
  } catch (error) {
    console.error('Error proxying request:', error)
    return new Response(
      JSON.stringify({ error: 'Failed to proxy request', details: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})