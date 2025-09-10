#!/bin/bash

# =====================================================
# Deploy Flutter Web to GitHub Pages
# LegalTracking RAG System - Frontend
# =====================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_NAME="legal-rag-mexico"
BACKEND_URL="http://5.161.120.86"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 Flutter Web Deployment to GitHub Pages${NC}"
echo -e "${BLUE}================================================${NC}"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed. Please install Flutter first.${NC}"
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Git repository
if [ ! -d .git ]; then
    echo -e "${RED}Not a Git repository. Please initialize Git first.${NC}"
    exit 1
fi

# Get GitHub username
GITHUB_USER=$(git config --get remote.origin.url | sed -n 's/.*github.com[:\/]\([^\/]*\).*/\1/p')
if [ -z "$GITHUB_USER" ]; then
    read -p "Enter your GitHub username: " GITHUB_USER
fi

echo -e "${GREEN}GitHub User: $GITHUB_USER${NC}"
echo -e "${GREEN}Repository: $REPO_NAME${NC}"

# Update API configuration
echo -e "${YELLOW}Updating API configuration...${NC}"

# Create/Update API config
cat > lib/core/config/api_config.dart << EOF
class ApiConfig {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  // Backend API URL (Hetzner server)
  static const String productionApiUrl = '$BACKEND_URL';
  static const String developmentApiUrl = 'http://localhost:8000';
  
  static String get apiUrl => isProduction ? productionApiUrl : developmentApiUrl;
  
  // API Endpoints
  static String get chatEndpoint => '\$apiUrl/api/chat';
  static String get uploadEndpoint => '\$apiUrl/api/documents/upload';
  static String get searchEndpoint => '\$apiUrl/api/search';
  static String get healthEndpoint => '\$apiUrl/health';
  
  // Supabase Configuration (public keys only)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co'
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key'
  );
}
EOF

# Clean and get dependencies
echo -e "${YELLOW}Preparing Flutter project...${NC}"
flutter clean
flutter pub get

# Build for web
echo -e "${YELLOW}Building Flutter web application...${NC}"
flutter build web --release \
  --base-href "/$REPO_NAME/" \
  --web-renderer html \
  --dart-define=BACKEND_URL=$BACKEND_URL

# Check if build was successful
if [ ! -d "build/web" ]; then
    echo -e "${RED}Build failed. Please check the errors above.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"

# Add 404.html for client-side routing
cp build/web/index.html build/web/404.html

# Create .nojekyll file to bypass Jekyll processing
touch build/web/.nojekyll

# Create CNAME file if using custom domain
read -p "Do you have a custom domain? (y/n): " HAS_DOMAIN
if [[ $HAS_DOMAIN =~ ^[Yy]$ ]]; then
    read -p "Enter your domain (e.g., app.legaltracking.com): " CUSTOM_DOMAIN
    echo "$CUSTOM_DOMAIN" > build/web/CNAME
fi

# Check if gh-pages branch exists
if git show-ref --verify --quiet refs/heads/gh-pages; then
    echo -e "${YELLOW}gh-pages branch exists${NC}"
else
    echo -e "${YELLOW}Creating gh-pages branch...${NC}"
    git checkout --orphan gh-pages
    git rm -rf .
    git commit --allow-empty -m "Initial gh-pages commit"
    git push origin gh-pages
    git checkout main
fi

# Deploy using git subtree
echo -e "${YELLOW}Deploying to GitHub Pages...${NC}"

# Add build directory to git
git add -f build/web
git commit -m "Deploy Flutter web to GitHub Pages [skip ci]"

# Push to gh-pages branch
git subtree push --prefix build/web origin gh-pages

echo -e "${GREEN}✓ Deployed to GitHub Pages${NC}"

# Create GitHub Actions workflow for automatic deployment
echo -e "${YELLOW}Setting up GitHub Actions for automatic deployment...${NC}"

mkdir -p .github/workflows
cat > .github/workflows/deploy-web.yml << 'ACTIONS'
name: Deploy Flutter Web to GitHub Pages

on:
  push:
    branches: [ main ]
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'
      - '.github/workflows/deploy-web.yml'
  workflow_dispatch:

permissions:
  contents: write
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
          channel: 'stable'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web
        run: |
          flutter build web --release \
            --base-href "/${{ github.event.repository.name }}/" \
            --web-renderer html \
            --dart-define=BACKEND_URL=http://5.161.120.86
            
      - name: Prepare deployment
        run: |
          cp build/web/index.html build/web/404.html
          touch build/web/.nojekyll
          
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
          cname: ${{ secrets.CUSTOM_DOMAIN }}
ACTIONS

echo -e "${GREEN}✓ GitHub Actions workflow created${NC}"

# Update README with deployment info
cat >> README.md << README_UPDATE

## 🌐 Live Demo

Frontend: https://$GITHUB_USER.github.io/$REPO_NAME/
Backend API: $BACKEND_URL

## 📱 Deployment

### Frontend (GitHub Pages)
\`\`\`bash
./deploy-flutter-github-pages.sh
\`\`\`

### Backend (Hetzner)
\`\`\`bash
./deploy-backend.sh
\`\`\`
README_UPDATE

# Create deployment status checker
cat > check-deployment.sh << 'CHECK_SCRIPT'
#!/bin/bash

echo "Checking deployment status..."

# Check GitHub Pages
GITHUB_URL="https://$GITHUB_USER.github.io/$REPO_NAME/"
if curl -s -o /dev/null -w "%{http_code}" "$GITHUB_URL" | grep -q "200\|304"; then
    echo "✓ GitHub Pages is live: $GITHUB_URL"
else
    echo "✗ GitHub Pages not accessible yet (may take a few minutes)"
fi

# Check Backend API
if curl -s -o /dev/null -w "%{http_code}" "http://5.161.120.86/health" | grep -q "200"; then
    echo "✓ Backend API is healthy"
else
    echo "✗ Backend API not responding"
fi
CHECK_SCRIPT

chmod +x check-deployment.sh

# Summary
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Your Flutter web app will be available at:${NC}"
echo -e "${GREEN}https://$GITHUB_USER.github.io/$REPO_NAME/${NC}"
echo ""
echo -e "${YELLOW}Note: It may take 5-10 minutes for GitHub Pages to activate${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Wait for GitHub Pages to activate"
echo "2. Run ./check-deployment.sh to verify deployment"
echo "3. Configure repository settings:"
echo "   - Go to: https://github.com/$GITHUB_USER/$REPO_NAME/settings/pages"
echo "   - Source: Deploy from a branch"
echo "   - Branch: gh-pages / (root)"
echo ""
echo -e "${BLUE}Backend API:${NC}"
echo "   URL: $BACKEND_URL"
echo "   Health: $BACKEND_URL/health"
echo ""
echo -e "${GREEN}================================================${NC}"