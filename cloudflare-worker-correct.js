// Cloudflare Worker for OpenRouter API Proxy with CORS
// Deploy this to: openrouter-proxy.emilio-perez.workers.dev

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Title, HTTP-Referer',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // Get the URL path
    const url = new URL(request.url);
    
    // Simple health check endpoint
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(JSON.stringify({ 
        status: 'healthy', 
        service: 'OpenRouter Proxy',
        timestamp: new Date().toISOString()
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // Proxy requests to OpenRouter
    try {
      // Build the OpenRouter URL
      const openRouterUrl = `https://openrouter.ai${url.pathname}${url.search}`;
      
      // Get headers from the original request
      const headers = new Headers(request.headers);
      
      // Remove Cloudflare-specific headers
      headers.delete('cf-connecting-ip');
      headers.delete('cf-ipcountry');
      headers.delete('cf-ray');
      headers.delete('cf-visitor');
      
      // Ensure proper host header
      headers.set('Host', 'openrouter.ai');
      
      // Add OpenRouter specific headers if not present
      if (!headers.has('HTTP-Referer')) {
        headers.set('HTTP-Referer', 'https://legalragmexico.com');
      }
      if (!headers.has('X-Title')) {
        headers.set('X-Title', 'Legal RAG Mexico');
      }
      
      // Create the proxy request
      const proxyRequest = new Request(openRouterUrl, {
        method: request.method,
        headers: headers,
        body: request.method !== 'GET' && request.method !== 'HEAD' 
          ? await request.text() 
          : undefined,
      });
      
      // Fetch from OpenRouter
      const response = await fetch(proxyRequest);
      
      // Clone the response to modify headers
      const modifiedResponse = new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
      
      // Add CORS headers to the response
      modifiedResponse.headers.set('Access-Control-Allow-Origin', '*');
      modifiedResponse.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      modifiedResponse.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Title, HTTP-Referer');
      
      return modifiedResponse;
      
    } catch (error) {
      // Return error response with CORS headers
      return new Response(JSON.stringify({ 
        error: 'Proxy error', 
        message: error.message,
        timestamp: new Date().toISOString()
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