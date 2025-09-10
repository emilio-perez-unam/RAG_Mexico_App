# Legal RAG México 🇲🇽 ⚖️

A production-ready Retrieval-Augmented Generation (RAG) system for Mexican legal documents, powered by Flutter, Supabase, and AI.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)
![Supabase](https://img.shields.io/badge/Supabase-2.0+-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🌟 Features

- **AI-Powered Legal Search**: Advanced semantic search through Mexican legal documents
- **Multi-Model Support**: DeepSeek and OpenRouter integration
- **Real-time Chat**: Interactive legal consultation with context awareness
- **Document Management**: Store, search, and cite legal documents
- **User Authentication**: Secure login with Supabase Auth
- **Vector Search**: Milvus-powered similarity search
- **Cross-Platform**: iOS, Android, Web, Desktop support
- **Offline Support**: Local caching for offline access

## 📋 Prerequisites

- Flutter SDK (^3.0.0)
- Dart SDK
- Supabase account
- DeepSeek API key
- Milvus instance (optional)
- Git

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/legal-rag-mexico.git
cd legal-rag-mexico
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment

Copy the environment template and fill in your credentials:

```bash
# Create .env file with your actual values
# See PRODUCTION_CONFIG.md for detailed instructions
```

Edit `.env` with your actual values:
```env
DEEPSEEK_API_KEY=your_actual_key
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

### 4. Setup Supabase

1. Create a new Supabase project at [https://app.supabase.com](https://app.supabase.com)
2. Run the migration file in `supabase/migrations/001_initial_schema.sql`
3. Configure authentication providers in Supabase dashboard

### 5. Run the Application

```bash
# Development
flutter run

# Production build
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web --release  # Web
```

## 📖 Documentation

For detailed setup and configuration, see:
- [PRODUCTION_CONFIG.md](./PRODUCTION_CONFIG.md) - Complete production setup guide with copy-paste configuration
- [CLAUDE.md](./CLAUDE.md) - Technical implementation details and development progress

## 🏗️ Project Structure

```
lib/
├── core/              # Core functionality
│   ├── config/        # Configuration management
│   ├── constants/     # App constants
│   ├── services/      # Core services
│   └── theme/         # Theme configuration
├── data/              # Data layer
│   ├── datasources/   # Remote and local data sources
│   ├── models/        # Data models
│   └── repositories/  # Repository implementations
├── domain/            # Domain layer
│   ├── entities/      # Business entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Business logic
├── presentation/      # Presentation layer
│   ├── providers/     # State management
│   ├── screens/       # UI screens
│   └── widgets/       # Reusable widgets
└── main.dart          # Application entry point
```

## 🔧 Configuration

### Supabase Setup

1. **Create Tables**: Run the SQL migration in `supabase/migrations/`
2. **Configure Auth**: Set up email authentication in Supabase dashboard
3. **Set RLS Policies**: Ensure Row Level Security is properly configured
4. **Add API Keys**: Add your Supabase URL and anon key to `.env`

### Vector Database Setup

#### Option A: Milvus Cloud
1. Sign up at [cloud.zilliz.com](https://cloud.zilliz.com)
2. Create a cluster
3. Add connection details to `.env`

#### Option B: Local Milvus
```bash
docker-compose up -d
```

### API Keys Required

- **DeepSeek**: Get from [platform.deepseek.com](https://platform.deepseek.com)
- **OpenRouter** (Optional): Get from [openrouter.ai](https://openrouter.ai)
- **Supabase**: Get from your Supabase project settings

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

## 📱 Platform-Specific Setup

### Android
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS
Add to `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🚢 Deployment

### Web Deployment
```bash
flutter build web --release
# Deploy the build/web folder to your hosting service
```

### Mobile Deployment
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release
# Then use Xcode to archive and upload to App Store
```

## 🔒 Security

- All API keys are stored in environment variables
- Supabase RLS policies protect user data
- Authentication required for all operations
- SSL/TLS encryption for all API calls

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Supabase](https://supabase.com) - Backend as a Service
- [DeepSeek](https://deepseek.com) - AI/LLM provider
- [Milvus](https://milvus.io) - Vector database

## 📞 Support

For support, email support@legalragmexico.com or open an issue in this repository.

## 🔄 Version History

- **1.0.0** - Initial release with core features
- **1.1.0** - Added Supabase authentication
- **1.2.0** - Implemented vector search
- **1.3.0** - Production-ready release

## ⚠️ Disclaimer

This application provides legal information and AI-assisted search capabilities. It is not a substitute for professional legal advice. Always consult with a qualified attorney for legal matters.

---

Made with ❤️ for the Mexican legal community
