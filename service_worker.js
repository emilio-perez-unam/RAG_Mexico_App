// Service Worker to handle CORS (requires API to support CORS or use proxy)
self.addEventListener('fetch', function(event) {
  const url = new URL(event.request.url);
  
  // Intercept calls to OpenRouter API
  if (url.href.includes('openrouter.ai/api')) {
    // Option 1: Redirect to your backend proxy
    // const proxyUrl = 'https://your-backend.com/api/openrouter-proxy';
    
    // Option 2: Use a public CORS proxy (development only)
    const corsProxy = 'https://corsproxy.io/?';
    const proxiedRequest = new Request(
      corsProxy + encodeURIComponent(event.request.url),
      {
        method: event.request.method,
        headers: event.request.headers,
        body: event.request.body,
        mode: 'cors',
        credentials: event.request.credentials,
      }
    );
    
    event.respondWith(fetch(proxiedRequest));
    return;
  }
  
  // Let other requests pass through normally
  event.respondWith(fetch(event.request));
});