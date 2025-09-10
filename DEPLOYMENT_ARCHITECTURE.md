# 🏗️ LegalTracking RAG System - Deployment Architecture

## Overview
- **Frontend**: Flutter Web hosted on GitHub Pages (Free)
- **Backend**: RAG API hosted on Hetzner Cloud (€14.49/month)
- **Database**: Supabase (Free tier or paid)
- **Vector DB**: Milvus on Hetzner
- **Storage**: Supabase Storage for documents

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         USERS                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               GitHub Pages (Frontend)                       │
│                                                             │
│  • Flutter Web App (https://yourusername.github.io/app)    │
│  • Static hosting (Free)                                   │
│  • CDN included                                            │
│  • SSL included                                            │
└────────────────────┬────────────────────────────────────────┘
                     │ API Calls (HTTPS)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Hetzner Cloud (Backend API)                    │
│                   5.161.120.86                              │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │            FastAPI/Python Backend                 │      │
│  │                                                   │      │
│  │  • RAG Processing Engine                         │      │
│  │  • Document Processing                           │      │
│  │  • Vector Search                                 │      │
│  │  • Chat Completions                              │      │
│  └──────────────┬───────────────────────────────────┘      │
│                 │                                           │
│  ┌──────────────▼───────────────┐                          │
│  │       Milvus Vector DB       │                          │
│  │   (250GB Volume Storage)     │                          │
│  └──────────────────────────────┘                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴──────────────┬────────────────┐
        ▼                            ▼                ▼
┌──────────────┐           ┌──────────────┐  ┌──────────────┐
│   Supabase   │           │   DeepSeek   │  │  OpenRouter  │
│              │           │     API      │  │     API      │
│ • Auth       │           │              │  │              │
│ • Database   │           │ • LLM        │  │ • Backup LLM │
│ • Storage    │           │ • Embeddings │  │              │
└──────────────┘           └──────────────┘  └──────────────┘
```

## 🚀 Part 1: Backend Deployment (Hetzner)

### Prerequisites
```bash
# Required API Keys
DEEPSEEK_API_KEY=sk-xxxxx
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJxxxxx
SUPABASE_SERVICE_KEY=eyJxxxxx
OPENROUTER_API_KEY=sk-or-xxxxx
```

### Step 1: Create Backend API Service

Create `backend/main.py`:
```python
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os
from datetime import datetime
import httpx
from supabase import create_client, Client
import pymilvus
from pymilvus import Collection, connections
import numpy as np
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="LegalTracking RAG API")

# CORS Configuration - IMPORTANT: Update with your GitHub Pages URL
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://yourusername.github.io",  # Your GitHub Pages URL
        "http://localhost:3000",  # Local development
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Supabase
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY")
)

# Initialize Milvus
connections.connect(
    alias="default",
    host=os.getenv("MILVUS_HOST", "localhost"),
    port=os.getenv("MILVUS_PORT", "19530")
)

# Request/Response Models
class ChatRequest(BaseModel):
    message: str
    context_id: Optional[str] = None
    user_id: str

class ChatResponse(BaseModel):
    response: str
    sources: List[dict]
    context_id: str

class DocumentUpload(BaseModel):
    title: str
    content: str
    category: str
    user_id: str

# Health Check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

# RAG Chat Endpoint
@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        # 1. Generate embedding for the query
        embedding = await generate_embedding(request.message)
        
        # 2. Search similar documents in Milvus
        relevant_docs = await search_vectors(embedding, top_k=5)
        
        # 3. Build context from relevant documents
        context = build_context(relevant_docs)
        
        # 4. Generate response using DeepSeek
        response = await generate_response(
            query=request.message,
            context=context
        )
        
        # 5. Store in Supabase for history
        await store_chat_history(
            user_id=request.user_id,
            message=request.message,
            response=response,
            sources=relevant_docs
        )
        
        return ChatResponse(
            response=response,
            sources=relevant_docs,
            context_id=generate_context_id()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Document Upload Endpoint
@app.post("/api/documents/upload")
async def upload_document(file: UploadFile = File(...), user_id: str = None):
    try:
        # 1. Read and process document
        content = await file.read()
        
        # 2. Extract text (implement based on file type)
        text = extract_text(content, file.filename)
        
        # 3. Chunk the document
        chunks = chunk_document(text)
        
        # 4. Generate embeddings for each chunk
        embeddings = [await generate_embedding(chunk) for chunk in chunks]
        
        # 5. Store in Milvus
        milvus_ids = await store_vectors(embeddings, chunks, file.filename)
        
        # 6. Store metadata in Supabase
        doc_id = await store_document_metadata(
            filename=file.filename,
            user_id=user_id,
            chunks_count=len(chunks),
            milvus_ids=milvus_ids
        )
        
        return {
            "success": True,
            "document_id": doc_id,
            "chunks_processed": len(chunks)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Search Endpoint
@app.get("/api/search")
async def search(query: str, limit: int = 10):
    try:
        # Generate embedding for search query
        embedding = await generate_embedding(query)
        
        # Search in Milvus
        results = await search_vectors(embedding, top_k=limit)
        
        return {
            "query": query,
            "results": results,
            "count": len(results)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Helper Functions
async def generate_embedding(text: str) -> List[float]:
    """Generate embeddings using DeepSeek API"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.deepseek.com/v1/embeddings",
            headers={"Authorization": f"Bearer {os.getenv('DEEPSEEK_API_KEY')}"},
            json={"input": text, "model": "deepseek-embed"}
        )
        return response.json()["data"][0]["embedding"]

async def generate_response(query: str, context: str) -> str:
    """Generate response using DeepSeek Chat API"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {os.getenv('DEEPSEEK_API_KEY')}"},
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": "You are a legal assistant for Mexican law. Use the provided context to answer questions accurately."},
                    {"role": "user", "content": f"Context: {context}\n\nQuestion: {query}"}
                ]
            }
        )
        return response.json()["choices"][0]["message"]["content"]

def build_context(documents: List[dict]) -> str:
    """Build context from relevant documents"""
    context_parts = []
    for doc in documents:
        context_parts.append(f"[{doc['title']}]: {doc['content']}")
    return "\n\n".join(context_parts)

async def search_vectors(embedding: List[float], top_k: int = 5) -> List[dict]:
    """Search similar vectors in Milvus"""
    collection = Collection("legal_documents")
    results = collection.search(
        data=[embedding],
        anns_field="embedding",
        param={"metric_type": "L2", "params": {"nprobe": 10}},
        limit=top_k,
        output_fields=["title", "content", "source"]
    )
    
    return [
        {
            "title": hit.entity.get("title"),
            "content": hit.entity.get("content"),
            "source": hit.entity.get("source"),
            "score": hit.score
        }
        for hit in results[0]
    ]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Step 2: Create Backend Dockerfile

Create `backend/Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Step 3: Backend Requirements

Create `backend/requirements.txt`:
```txt
fastapi==0.104.1
uvicorn==0.24.0
python-dotenv==1.0.0
httpx==0.25.1
supabase==2.0.0
pymilvus==2.3.3
numpy==1.24.3
pydantic==2.4.2
python-multipart==0.0.6
PyPDF2==3.0.1
python-docx==1.0.1
tiktoken==0.5.1
langchain==0.0.335
```

### Step 4: Docker Compose for Backend

Create `backend/docker-compose.yml`:
```yaml
version: '3.8'

networks:
  rag-network:
    driver: bridge

volumes:
  milvus_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/milvus

services:
  # RAG API Service
  rag-api:
    build: .
    container_name: legalrag-api
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - MILVUS_HOST=milvus
      - MILVUS_PORT=19530
      - CORS_ORIGINS=${CORS_ORIGINS}
    depends_on:
      - milvus
    networks:
      - rag-network
    volumes:
      - /mnt/data/uploads:/app/uploads
      - /mnt/data/logs:/app/logs

  # Milvus Vector Database
  milvus:
    image: milvusdb/milvus:latest
    container_name: legalrag-milvus
    restart: unless-stopped
    environment:
      - ETCD_ENDPOINTS=etcd:2379
      - MINIO_ADDRESS=minio:9000
    ports:
      - "19530:19530"
    volumes:
      - milvus_data:/var/lib/milvus
    depends_on:
      - etcd
      - minio
    networks:
      - rag-network

  # Milvus dependencies
  etcd:
    image: quay.io/coreos/etcd:v3.5.5
    container_name: legalrag-etcd
    restart: unless-stopped
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
    volumes:
      - /mnt/data/etcd:/etcd
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls=http://0.0.0.0:2379
    networks:
      - rag-network

  minio:
    image: minio/minio:latest
    container_name: legalrag-minio
    restart: unless-stopped
    environment:
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
    volumes:
      - /mnt/data/minio:/data
    command: minio server /data
    networks:
      - rag-network

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: legalrag-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - rag-api
    networks:
      - rag-network
```

### Step 5: Nginx Configuration for API

Create `backend/nginx.conf`:
```nginx
events {
    worker_connections 1024;
}

http {
    upstream api {
        server rag-api:8000;
    }

    server {
        listen 80;
        server_name 5.161.120.86;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' 'https://yourusername.github.io' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, DELETE, PUT' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;

        location / {
            if ($request_method = 'OPTIONS') {
                return 204;
            }
            
            proxy_pass http://api;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            proxy_pass http://api/health;
        }
    }
}
```

### Step 6: Deployment Script

Create `deploy-backend.sh`:
```bash
#!/bin/bash

SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "Deploying RAG Backend to Hetzner..."

# Create deployment package
tar czf backend.tar.gz backend/

# Upload and deploy
scp -i "$SSH_KEY" backend.tar.gz root@$SERVER_IP:/opt/
ssh -i "$SSH_KEY" root@$SERVER_IP << 'DEPLOY'
cd /opt
tar xzf backend.tar.gz
cd backend
docker compose down
docker compose build
docker compose up -d
docker compose ps
DEPLOY

echo "Backend deployed to http://$SERVER_IP"
```

## 🎨 Part 2: Frontend Deployment (GitHub Pages)

### Step 1: Configure Flutter for Web

Update `lib/core/config/api_config.dart`:
```dart
class ApiConfig {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  // Update with your Hetzner server IP
  static const String productionApiUrl = 'http://5.161.120.86';
  static const String developmentApiUrl = 'http://localhost:8000';
  
  static String get apiUrl => isProduction ? productionApiUrl : developmentApiUrl;
  
  static String get chatEndpoint => '$apiUrl/api/chat';
  static String get uploadEndpoint => '$apiUrl/api/documents/upload';
  static String get searchEndpoint => '$apiUrl/api/search';
}
```

### Step 2: Build Flutter for Web

Create `build-web.sh`:
```bash
#!/bin/bash

echo "Building Flutter Web App..."

# Clean and get dependencies
flutter clean
flutter pub get

# Build for web with production API
flutter build web --release \
  --base-href "/legal-rag-mexico/" \
  --web-renderer html

echo "Build complete! Output in build/web/"
```

### Step 3: GitHub Pages Deployment

Create `.github/workflows/deploy-frontend.yml`:
```yaml
name: Deploy Flutter Web to GitHub Pages

on:
  push:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web
        run: |
          flutter build web --release \
            --base-href "/${{ github.event.repository.name }}/" \
            --web-renderer html
            
      - name: Setup Pages
        uses: actions/configure-pages@v3
        
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: 'build/web'
          
      - name: Deploy to GitHub Pages
        uses: actions/deploy-pages@v2
```

### Step 4: Configure Repository for GitHub Pages

1. Go to your repository Settings
2. Navigate to Pages
3. Source: Deploy from a branch
4. Branch: gh-pages / root
5. Save

## 📝 Environment Variables

### Backend (.env on Hetzner)
```env
# API Keys
DEEPSEEK_API_KEY=sk-xxxxx
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJxxxxx
OPENROUTER_API_KEY=sk-or-xxxxx

# CORS - Your GitHub Pages URL
CORS_ORIGINS=https://yourusername.github.io

# Milvus
MILVUS_HOST=localhost
MILVUS_PORT=19530
```

### Frontend (compile-time)
Built into the app during `flutter build web`

## 🚀 Deployment Commands

### Deploy Backend to Hetzner
```bash
# First time setup
./setup-legaltracking-server.sh

# Deploy backend
./deploy-backend.sh

# Check health
curl http://5.161.120.86/health
```

### Deploy Frontend to GitHub Pages
```bash
# Build and commit
./build-web.sh
git add .
git commit -m "Deploy frontend"
git push

# GitHub Actions will automatically deploy
```

## 🔍 Testing the Deployment

### Test Backend API
```bash
# Health check
curl http://5.161.120.86/health

# Test CORS
curl -H "Origin: https://yourusername.github.io" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     http://5.161.120.86/api/chat
```

### Test Frontend
Visit: `https://yourusername.github.io/legal-rag-mexico/`

## 💰 Cost Breakdown

| Service | Cost | Details |
|---------|------|---------|
| GitHub Pages | $0/month | Frontend hosting |
| Hetzner Cloud | €14.49/month | Backend API + Milvus |
| Supabase | $0-25/month | Database + Auth |
| DeepSeek API | Pay-per-use | ~$0.001 per request |
| **Total** | **~$15-40/month** | Depending on usage |

## 🔒 Security Considerations

1. **API Security**:
   - Add rate limiting to prevent abuse
   - Implement API key authentication
   - Use HTTPS with Let's Encrypt

2. **CORS Configuration**:
   - Only allow your GitHub Pages domain
   - No wildcard origins

3. **Supabase RLS**:
   - Enable Row Level Security
   - Implement proper auth policies

4. **Secrets Management**:
   - Never commit API keys
   - Use environment variables
   - Rotate keys regularly

## 🔧 Monitoring

### Backend Monitoring
```bash
# View logs
ssh -i ./hetzner_key root@5.161.120.86 \
  'docker compose -f /opt/backend/docker-compose.yml logs -f'

# Check status
./health-check.sh

# Monitor resources
./monitor-legalrag.sh
```

### Frontend Monitoring
- GitHub Pages provides basic analytics
- Add Google Analytics or Plausible for detailed metrics

## 📚 API Documentation

### Chat Endpoint
```http
POST http://5.161.120.86/api/chat
Content-Type: application/json

{
  "message": "What are the requirements for a contract in Mexico?",
  "user_id": "user123",
  "context_id": null
}
```

### Upload Document
```http
POST http://5.161.120.86/api/documents/upload
Content-Type: multipart/form-data

file: [PDF/DOCX file]
user_id: user123
```

### Search
```http
GET http://5.161.120.86/api/search?query=contract%20law&limit=10
```

## 🆘 Troubleshooting

### Frontend can't connect to backend
1. Check CORS configuration in nginx.conf
2. Verify API URL in Flutter app
3. Check if backend is running: `curl http://5.161.120.86/health`

### Milvus not starting
1. Check disk space: `df -h /mnt/data`
2. Check logs: `docker logs legalrag-milvus`
3. Restart: `docker compose restart milvus`

### GitHub Pages not updating
1. Check Actions tab for build errors
2. Clear browser cache
3. Wait 10 minutes for CDN propagation

## 🎯 Next Steps

1. **Add Authentication**:
   - Implement JWT tokens
   - Add to API middleware
   - Store in Flutter secure storage

2. **Optimize Performance**:
   - Add Redis caching
   - Implement request batching
   - Use CDN for static assets

3. **Scale Backend**:
   - Add load balancer
   - Implement horizontal scaling
   - Use managed database

4. **Monitoring**:
   - Setup Grafana dashboard
   - Add error tracking (Sentry)
   - Implement logging aggregation