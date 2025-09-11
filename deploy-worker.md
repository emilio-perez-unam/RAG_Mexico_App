# Deploy Cloudflare Worker - Quick Fix

## The Problem
Your worker at `openrouter-proxy.emilio-perez.workers.dev` is returning 404 errors. It's deployed but the code isn't handling requests.

## Solution: Deploy This Code

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to Workers & Pages
3. Find your `openrouter-proxy` worker
4. Click "Quick Edit" or "Edit Code"
5. **Replace ALL the code** with this:

```javascript
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': '*',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // Health check endpoint
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(JSON.stringify({ 
        status: 'ok',
        message: 'OpenRouter proxy is running',
        timestamp: new Date().toISOString()
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    try {
      // Build OpenRouter URL
      const openRouterUrl = 'https://openrouter.ai' + url.pathname + url.search;
      
      // Copy headers
      const headers = new Headers(request.headers);
      headers.delete('cf-connecting-ip');
      headers.delete('cf-ipcountry');
      headers.delete('cf-ray');
      headers.delete('cf-visitor');
      headers.delete('x-forwarded-proto');
      headers.delete('x-real-ip');
      
      // Forward request to OpenRouter
      const response = await fetch(openRouterUrl, {
        method: request.method,
        headers: headers,
        body: request.method !== 'GET' && request.method !== 'HEAD' 
          ? request.body 
          : undefined,
      });
      
      // Create response with CORS headers
      const newResponse = new Response(response.body, response);
      newResponse.headers.set('Access-Control-Allow-Origin', '*');
      newResponse.headers.set('Access-Control-Allow-Methods', '*');
      newResponse.headers.set('Access-Control-Allow-Headers', '*');
      
      return newResponse;
      
    } catch (error) {
      return new Response(JSON.stringify({ 
        error: 'Proxy error',
        message: error.message 
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }
  },
};
```

6. Click **"Save and Deploy"**
7. Wait 30 seconds for deployment

## Test After Deployment

Once deployed, test it by visiting:
https://openrouter-proxy.emilio-perez.workers.dev/

You should see:
```json
{
  "status": "ok",
  "message": "OpenRouter proxy is running",
  "timestamp": "2025-09-11T23:30:00.000Z"
}
```

## If Still Not Working

Check that your worker:
1. Is using the code above exactly
2. Has no syntax errors
3. Is deployed to the correct domain

## Alternative: Use Wrangler CLI

If you have Wrangler installed:

```bash
# Save the code above to worker.js
wrangler deploy worker.js --name openrouter-proxy
```