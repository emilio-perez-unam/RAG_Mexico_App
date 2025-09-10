# 🚀 PRODUCTION CONFIGURATION GUIDE

## Quick Setup - Copy & Paste Configuration

Follow these steps to make the application production-ready. Simply copy the values into the specified locations.

---

## 1️⃣ Environment Configuration (.env)

Create a `.env` file in the project root with your actual values:

```bash
# ============================================
# COPY THIS ENTIRE BLOCK TO YOUR .env FILE
# ============================================

# DeepSeek API Configuration
DEEPSEEK_API_KEY=sk-YOUR_ACTUAL_DEEPSEEK_API_KEY_HERE

# Supabase Configuration (Get from: https://app.supabase.com/project/YOUR_PROJECT/settings/api)
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.YOUR_ANON_KEY_HERE

# Milvus/Vector Database Configuration
MILVUS_HOST=your.milvus.host.com
MILVUS_PORT=19530
MILVUS_COLLECTION=legal_documents_mexico
MILVUS_USERNAME=your_milvus_username
MILVUS_PASSWORD=your_milvus_password

# OpenRouter Configuration (Optional - for fallback LLM)
OPENROUTER_API_KEY=sk-or-v1-YOUR_OPENROUTER_KEY_HERE
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# Application Configuration
APP_ENV=production
API_TIMEOUT=30000
MAX_RETRIES=3
ENABLE_LOGGING=false

# Feature Flags
ENABLE_CHAT_HISTORY=true
ENABLE_DOCUMENT_UPLOAD=true
ENABLE_PREMIUM_FEATURES=true
```

---

## 2️⃣ Supabase Setup

### A. Create Supabase Project

1. Go to [https://app.supabase.com](https://app.supabase.com)
2. Create new project
3. Save your project URL and anon key

### B. Run Database Migrations

Copy and run these SQL commands in Supabase SQL Editor:

```sql
-- ============================================
-- COPY THIS ENTIRE SQL BLOCK TO SUPABASE
-- ============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Create custom types
CREATE TYPE user_role AS ENUM ('user', 'admin', 'premium');
CREATE TYPE subscription_tier AS ENUM ('free', 'basic', 'professional', 'enterprise');

-- Users table (extends auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  organization TEXT,
  role user_role DEFAULT 'user',
  subscription_tier subscription_tier DEFAULT 'free',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Search history table
CREATE TABLE public.search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  query_embedding vector(1536),
  results JSONB,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Documents table
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  content TEXT,
  document_type TEXT,
  jurisdiction TEXT,
  metadata JSONB,
  embedding vector(1536),
  source_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Saved queries table
CREATE TABLE public.saved_queries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  query TEXT NOT NULL,
  filters JSONB,
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat sessions table
CREATE TABLE public.chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT,
  messages JSONB[],
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Citations table
CREATE TABLE public.citations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
  citation_text TEXT NOT NULL,
  citation_format TEXT NOT NULL,
  page_number INTEGER,
  paragraph_number INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_search_history_user_id ON public.search_history(user_id);
CREATE INDEX idx_search_history_created_at ON public.search_history(created_at DESC);
CREATE INDEX idx_documents_document_type ON public.documents(document_type);
CREATE INDEX idx_documents_jurisdiction ON public.documents(jurisdiction);
CREATE INDEX idx_saved_queries_user_id ON public.saved_queries(user_id);
CREATE INDEX idx_chat_sessions_user_id ON public.chat_sessions(user_id);

-- Create vector similarity search index
CREATE INDEX documents_embedding_idx ON public.documents 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Row Level Security (RLS) Policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own profile
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Users can only see their own search history
CREATE POLICY "Users can view own search history" ON public.search_history
  FOR ALL USING (auth.uid() = user_id);

-- Users can only see their own saved queries
CREATE POLICY "Users can manage own saved queries" ON public.saved_queries
  FOR ALL USING (auth.uid() = user_id);

-- Users can only see their own chat sessions
CREATE POLICY "Users can manage own chat sessions" ON public.chat_sessions
  FOR ALL USING (auth.uid() = user_id);

-- Documents are public read (adjust as needed)
CREATE POLICY "Documents are viewable by all" ON public.documents
  FOR SELECT USING (true);

-- Create function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_sessions_updated_at BEFORE UPDATE ON public.chat_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### C. Configure Authentication

In Supabase Dashboard:

1. Go to Authentication → Providers
2. Enable Email provider
3. Configure email templates:

**Confirmation Email Template:**
```html
<h2>Confirma tu cuenta en Legal RAG México</h2>
<p>Haz clic en el siguiente enlace para confirmar tu cuenta:</p>
<p><a href="{{ .ConfirmationURL }}">Confirmar Email</a></p>
```

**Password Reset Template:**
```html
<h2>Restablecer contraseña - Legal RAG México</h2>
<p>Haz clic en el siguiente enlace para restablecer tu contraseña:</p>
<p><a href="{{ .ConfirmationURL }}">Restablecer Contraseña</a></p>
```

### D. Configure Storage Buckets

```sql
-- Create storage buckets for documents
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('documents', 'documents', false),
  ('user-uploads', 'user-uploads', false);

-- Set up storage policies
CREATE POLICY "Users can upload documents" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own documents" ON storage.objects
  FOR SELECT USING (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own documents" ON storage.objects
  FOR DELETE USING (bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## 3️⃣ Milvus Vector Database Setup

### Option A: Milvus Cloud (Recommended for Production)

1. Sign up at [https://cloud.zilliz.com](https://cloud.zilliz.com)
2. Create a new cluster
3. Get connection details
4. Create collection:

```python
# Run this Python script to create Milvus collection
from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType, utility

# Connect to Milvus
connections.connect(
    host='YOUR_MILVUS_HOST',
    port='19530',
    user='YOUR_USERNAME',
    password='YOUR_PASSWORD'
)

# Define schema
fields = [
    FieldSchema(name="id", dtype=DataType.VARCHAR, is_primary=True, max_length=100),
    FieldSchema(name="document_id", dtype=DataType.VARCHAR, max_length=100),
    FieldSchema(name="title", dtype=DataType.VARCHAR, max_length=500),
    FieldSchema(name="content", dtype=DataType.VARCHAR, max_length=65535),
    FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=1536),
    FieldSchema(name="metadata", dtype=DataType.JSON),
]

schema = CollectionSchema(fields, "Legal documents collection for RAG")

# Create collection
collection = Collection("legal_documents_mexico", schema)

# Create index
index_params = {
    "metric_type": "COSINE",
    "index_type": "IVF_FLAT",
    "params": {"nlist": 1024}
}
collection.create_index(field_name="embedding", index_params=index_params)
```

### Option B: Local Milvus (Development)

```bash
# Using Docker
docker-compose up -d

# docker-compose.yml
version: '3.5'
services:
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.0
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2022-03-17T06-34-49Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/minio:/minio_data
    command: minio server /minio_data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  standalone:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.3.3
    command: ["milvus", "run", "standalone"]
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
    ports:
      - "19530:19530"
    depends_on:
      - "etcd"
      - "minio"
```

---

## 4️⃣ API Keys Setup

### DeepSeek API
1. Go to [https://platform.deepseek.com](https://platform.deepseek.com)
2. Sign up / Login
3. Go to API Keys section
4. Create new API key
5. Copy to .env file

### OpenRouter API (Optional)
1. Go to [https://openrouter.ai](https://openrouter.ai)
2. Sign up / Login
3. Go to Keys section
4. Create new API key
5. Copy to .env file

---

## 5️⃣ Flutter Configuration

### Android Configuration (android/app/src/main/AndroidManifest.xml)

```xml
<!-- Add these permissions -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Add deep linking for Supabase Auth -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="io.supabase.legalragmexico"
        android:host="login-callback" />
</intent-filter>
```

### iOS Configuration (ios/Runner/Info.plist)

```xml
<!-- Add URL Scheme for Supabase Auth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.legalragmexico</string>
        </array>
    </dict>
</array>
```

---

## 6️⃣ Build & Deploy Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app in development
flutter run

# Build for production

# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

---

## 7️⃣ Production Checklist

Before deploying to production, ensure:

- [ ] All API keys are properly set in .env
- [ ] Supabase project is configured with proper RLS policies
- [ ] Email templates are customized
- [ ] Milvus collection is created and indexed
- [ ] App bundle identifiers match your organization
- [ ] Deep linking URLs are configured
- [ ] Error tracking (Sentry) is configured (optional)
- [ ] Analytics are set up (optional)
- [ ] Terms of Service and Privacy Policy are in place
- [ ] SSL certificates are valid
- [ ] Backup strategy is defined
- [ ] Monitoring is set up

---

## 8️⃣ Testing Credentials

For testing, you can use these configurations:

```bash
# .env.test
DEEPSEEK_API_KEY=test_key_123
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=test_anon_key
APP_ENV=test
ENABLE_LOGGING=true
```

---

## 9️⃣ Monitoring & Analytics (Optional)

### Sentry Integration

```yaml
# pubspec.yaml
dependencies:
  sentry_flutter: ^7.14.0
```

```dart
// main.dart
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_SENTRY_DSN';
    options.environment = EnvConfig.instance.appEnv;
  },
);
```

---

## 🎉 Done!

Your application is now production-ready. Simply:

1. Copy the values to your .env file
2. Run the SQL migrations in Supabase
3. Configure your vector database
4. Run `flutter pub get`
5. Build and deploy!

---

## 10️⃣ Docker Deployment on Hetzner Cloud

### Quick Deployment

```bash
# 1. Set environment variables
export DEEPSEEK_API_KEY="your_actual_deepseek_key"
export SUPABASE_URL="your_supabase_url"
export SUPABASE_ANON_KEY="your_supabase_anon_key"
export MILVUS_HOST="your_milvus_host"
export MILVUS_PORT="19530"
export OPENROUTER_API_KEY="your_openrouter_key"
export DOMAIN="your-domain.com"

# 2. Make deployment script executable
chmod +x deploy-hetzner.sh

# 3. Run deployment
./deploy-hetzner.sh
```

### Manual Docker Deployment

#### A. Build and Run Locally

```bash
# Build the Docker image
docker build -t legal-rag-mexico:latest \
  --build-arg DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY \
  --build-arg SUPABASE_URL=$SUPABASE_URL \
  --build-arg SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  .

# Run with Docker Compose
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f legal-rag-web
```

#### B. Deploy to Hetzner Cloud

1. **Create Hetzner Server**:
```bash
# Install Hetzner CLI
brew install hcloud  # macOS
# or
curl -o hcloud.tar.gz -L https://github.com/hetznercloud/cli/releases/download/v1.39.0/hcloud-linux-amd64.tar.gz  # Linux

# Login
hcloud context create legal-rag

# Create server
hcloud server create \
  --name legal-rag-prod \
  --type cx21 \
  --image ubuntu-22.04 \
  --location nbg1
```

2. **SSH to Server and Setup**:
```bash
# SSH to server
ssh root@YOUR_SERVER_IP

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt-get update
apt-get install -y docker-compose-plugin

# Create app directory
mkdir -p /opt/legal-rag-mexico
cd /opt/legal-rag-mexico
```

3. **Deploy Application**:
```bash
# On your local machine, copy files
scp -r * root@YOUR_SERVER_IP:/opt/legal-rag-mexico/

# On server, build and run
cd /opt/legal-rag-mexico
docker compose build
docker compose up -d
```

4. **Setup SSL with Nginx**:
```bash
# Install Nginx and Certbot
apt-get install -y nginx certbot python3-certbot-nginx

# Get SSL certificate
certbot --nginx -d your-domain.com -d www.your-domain.com

# Configure Nginx reverse proxy
cat > /etc/nginx/sites-available/legal-rag << 'EOF'
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
ln -s /etc/nginx/sites-available/legal-rag /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### Docker Commands Reference

```bash
# View running containers
docker ps

# View logs
docker logs legal-rag-web

# Enter container
docker exec -it legal-rag-web sh

# Stop application
docker compose down

# Update and restart
docker compose pull
docker compose up -d

# Clean up old images
docker system prune -af

# Backup data
docker run --rm -v legal-rag-mexico_redis-data:/data -v $(pwd):/backup alpine tar czf /backup/redis-backup.tar.gz -C /data .

# Restore data
docker run --rm -v legal-rag-mexico_redis-data:/data -v $(pwd):/backup alpine tar xzf /backup/redis-backup.tar.gz -C /data
```

### GitHub Actions CI/CD

The repository includes automated deployment via GitHub Actions:

1. **Setup GitHub Secrets**:
   - Go to Settings → Secrets and variables → Actions
   - Add these secrets:
     - `DEEPSEEK_API_KEY`
     - `SUPABASE_URL`
     - `SUPABASE_ANON_KEY`
     - `MILVUS_HOST`
     - `MILVUS_PORT`
     - `OPENROUTER_API_KEY`
     - `STAGING_HOST` (Staging server IP)
     - `STAGING_SSH_KEY` (SSH private key)
     - `PRODUCTION_HOST` (Production server IP)
     - `PRODUCTION_SSH_KEY` (SSH private key)
     - `SLACK_WEBHOOK` (Optional, for notifications)

2. **Deployment Workflow**:
   - Push to `main` → Deploys to staging
   - Push to `production` → Deploys to production
   - Manual trigger available via Actions tab

### Monitoring

Access monitoring dashboards:
- Grafana: `http://your-server:3000` (admin/admin)
- Prometheus: `http://your-server:9090`

To enable monitoring:
```bash
docker compose --profile monitoring up -d
```

### Scaling on Hetzner

For high traffic, use Hetzner Load Balancer:

```bash
# Create load balancer
hcloud load-balancer create \
  --name legal-rag-lb \
  --type lb11 \
  --location nbg1

# Add targets
hcloud load-balancer add-target legal-rag-lb \
  --server legal-rag-prod-1

hcloud load-balancer add-target legal-rag-lb \
  --server legal-rag-prod-2

# Configure health checks
hcloud load-balancer add-service legal-rag-lb \
  --protocol https \
  --listen-port 443 \
  --destination-port 443
```

### Troubleshooting

```bash
# Check Docker logs
docker compose logs -f --tail=100

# Check system resources
docker stats

# Test health endpoint
curl http://localhost/health

# Check disk space
df -h

# Check memory
free -h

# Restart services
docker compose restart

# Full reset
docker compose down -v
docker compose up -d --force-recreate
```

---

For support or questions, refer to the main CLAUDE.md documentation.