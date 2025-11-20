# RescuePC Repairs

**Professional Windows Repair Toolkit** - Automated diagnostics, driver management, security scanning, and system optimization.

## 🚀 Features

- ✅ **AI System Diagnostics** - Intelligent system analysis
- ✅ **Automated Repairs** - One-click fixes for network, audio, services
- ✅ **Driver Management** - SDIO driver packs and updates
- ✅ **Security & Malware** - Advanced scanning and removal
- ✅ **Performance Boost** - System optimization tools
- ✅ **Backup & Recovery** - User data protection

## 🏗️ Project Structure

```
rescuepc-repairs/
├── src/                          # Next.js application
│   ├── app/                      # App router pages & API routes
│   │   ├── api/                  # API endpoints (Stripe, licensing)
│   │   ├── download/             # Download page
│   │   ├── pricing/              # Pricing page
│   │   └── legal/                # Legal pages
│   └── lib/                      # Utilities (license, email)
├── prisma/                       # Database schema
├── scripts/                      # PowerShell repair scripts
│   ├── build/                    # Build & deployment scripts
│   ├── ops/                      # Operations (audit, logs)
│   ├── repair/                   # Repair scripts
│   ├── security/                 # Security & diagnostics
│   └── drivers/                  # Driver management
├── bin/                          # Executable build scripts
├── docs/                         # Documentation
├── legal/                        # Legal documents
├── public/                       # Static assets
└── archive/                      # Legacy files
```

## 🛠️ Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL database
- Stripe account
- Resend account

### Installation

1. **Clone & Install**
   ```bash
   git clone <repository>
   cd rescuepc-repairs
   npm install
   ```

2. **Database Setup**
   ```bash
   npx prisma generate
   npm run scripts/build/setup-database.ps1
   ```

3. **Environment Variables**
   ```bash
   cp .env.example .env.local
   # Edit with your API keys
   ```

4. **Development**
   ```bash
   npm run dev
   ```

## 📦 Scripts

### Build & Deploy
```bash
npm run desktop:build          # Build unsigned EXE
npm run desktop:build:signed   # Build signed EXE
npm run scripts/build/deploy-production.ps1  # Full deployment
```

### Testing
```bash
npm run desktop:audit          # Run script audits
npm run desktop:run            # Launch application
npm run test:api               # Hit API endpoints (dev server must be running)
npm run test:all               # Lint + build + API smoke tests
pwsh -File scripts/test-api-endpoints.ps1   # PowerShell wrapper
```

### Database
```bash
npm run db:generate             # Generate Prisma client
npm run db:push                 # Push schema changes
npm run db:studio               # Open Prisma Studio
```

## 🔐 Licensing System

- **Automated**: Stripe webhooks process payments instantly
- **Secure**: JWT tokens with expiration
- **Scalable**: PostgreSQL backend
- **Professional**: HTML email templates

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION_GUIDE.md)
- [Licensing Setup](docs/LICENSING_SETUP.md)
- [Deployment Guide](DEPLOYMENT_COMPLETE.md)

## 🎯 Support

- **Email**: support@rescuepcrepairs.com
- **Issues**: GitHub Issues
- **Security**: security@rescuepcrepairs.com

## 📄 License

See [LICENSE](legal/LICENSE.txt) for details.

---

**Built with ❤️ for Windows users worldwide**
