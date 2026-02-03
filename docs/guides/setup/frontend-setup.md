# Frontend Development Setup

This guide covers setting up the Medico24 web dashboard (Next.js + TypeScript + Tailwind CSS).

## Prerequisites

- Node.js 18+ and npm/pnpm/yarn
- Git
- Code editor (VS Code recommended)

---

## Installation

### 1. Navigate to Website Directory

```bash
cd medico24-website
```

### 2. Install Dependencies

=== "pnpm (Recommended)"
    ```bash
    # Install pnpm if not already installed
    npm install -g pnpm

    # Install dependencies
    pnpm install
    ```

=== "npm"
    ```bash
    npm install
    ```

=== "yarn"
    ```bash
    yarn install
    ```

---

## Environment Configuration

### Create `.env.local` File

```bash
cp .env.example .env.local
```

### Environment Variables

```env
# App Configuration
NEXT_PUBLIC_APP_NAME=Medico24
NEXT_PUBLIC_APP_URL=http://localhost:3000
NODE_ENV=development

# Backend API
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api/v1

# Firebase Configuration (from Firebase Console)
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyD...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=medico24.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=medico24
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=medico24.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abc123
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX

# Google Maps API (from Google Cloud Console)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyD...your-maps-api-key

# Google OAuth Client ID (for web app)
NEXT_PUBLIC_GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com

# Feature Flags
NEXT_PUBLIC_ENABLE_ANALYTICS=true
NEXT_PUBLIC_ENABLE_GOOGLE_LOGIN=true
NEXT_PUBLIC_ENABLE_MAPS=true

# Development Tools
NEXT_PUBLIC_DEBUG_MODE=false
ANALYZE=false  # Set to true to analyze bundle size
```

!!! tip "Environment Variables"
    - Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser
    - Never expose secrets with `NEXT_PUBLIC_` prefix
    - See [External Services Guide](external-services.md) for obtaining API keys

---

## Running the Application

### Development Server

```bash
# Using pnpm
pnpm dev

# Using npm
npm run dev

# Using yarn
yarn dev
```

Visit http://localhost:3000

### Production Build

```bash
# Build for production
pnpm build

# Start production server
pnpm start
```

### Docker

```bash
# Build image
docker build -t medico24-website .

# Run container
docker run -p 3000:3000 medico24-website
```

---

## Project Structure

```
medico24-website/
├── app/                      # Next.js App Router pages
│   ├── (auth)/              # Auth routes group
│   │   ├── login/
│   │   └── register/
│   ├── (dashboard)/         # Dashboard routes group
│   │   ├── layout.tsx       # Dashboard layout
│   │   ├── page.tsx        # Dashboard home
│   │   ├── pharmacies/
│   │   ├── patients/
│   │   └── analytics/
│   ├── layout.tsx          # Root layout
│   ├── page.tsx            # Home page
│   └── globals.css         # Global styles
├── components/              # React components
│   ├── ui/                 # shadcn/ui components
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   └── ...
│   ├── auth/               # Authentication components
│   ├── dashboard/          # Dashboard components
│   ├── maps/              # Map components
│   └── shared/            # Shared components
├── hooks/                   # Custom React hooks
│   ├── useAuth.ts
│   ├── useApi.ts
│   └── useLocation.ts
├── lib/                     # Utility libraries
│   ├── api.ts              # API client
│   ├── firebase.ts         # Firebase config
│   ├── utils.ts            # Utility functions
│   └── validations.ts      # Form validations
├── public/                  # Static assets
│   ├── images/
│   └── icons/
├── styles/                  # Additional styles
├── types/                   # TypeScript types
│   ├── api.ts
│   └── models.ts
├── .env.example            # Environment template
├── .eslintrc.json         # ESLint config
├── components.json        # shadcn/ui config
├── next.config.mjs        # Next.js config
├── package.json
├── postcss.config.mjs     # PostCSS config
├── tailwind.config.ts     # Tailwind config
└── tsconfig.json          # TypeScript config
```

---

## Development Workflow

### Creating a New Page

1. **Create page file** in `app/`:

```tsx
// app/pharmacies/page.tsx
export default function PharmaciesPage() {
  return (
    <div>
      <h1>Pharmacies</h1>
    </div>
  )
}
```

2. **Add route metadata**:

```tsx
export const metadata = {
  title: 'Pharmacies | Medico24',
  description: 'Find nearby pharmacies',
}
```

### Creating Components

1. **Create component file** in `components/`:

```tsx
// components/pharmacy/PharmacyCard.tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

interface PharmacyCardProps {
  name: string
  address: string
  distance?: number
}

export function PharmacyCard({ name, address, distance }: PharmacyCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{name}</CardTitle>
      </CardHeader>
      <CardContent>
        <p>{address}</p>
        {distance && <p className="text-sm text-gray-500">{distance} km away</p>}
      </CardContent>
    </Card>
  )
}
```

2. **Use in page**:

```tsx
// app/pharmacies/page.tsx
import { PharmacyCard } from '@/components/pharmacy/PharmacyCard'

export default function PharmaciesPage() {
  return (
    <div className="grid gap-4">
      <PharmacyCard name="ABC Pharmacy" address="123 Main St" distance={1.2} />
    </div>
  )
}
```

### API Integration

1. **Create API client** in `lib/api.ts`:

```typescript
// lib/api.ts
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL

export async function fetchPharmacies() {
  const response = await fetch(`${API_BASE_URL}/pharmacies`)
  if (!response.ok) throw new Error('Failed to fetch pharmacies')
  return response.json()
}

export async function createPharmacy(data: PharmacyCreate) {
  const response = await fetch(`${API_BASE_URL}/pharmacies`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  })
  if (!response.ok) throw new Error('Failed to create pharmacy')
  return response.json()
}
```

2. **Use in Server Component**:

```tsx
// app/pharmacies/page.tsx
import { fetchPharmacies } from '@/lib/api'
import { PharmacyCard } from '@/components/pharmacy/PharmacyCard'

export default async function PharmaciesPage() {
  const pharmacies = await fetchPharmacies()
  
  return (
    <div className="grid gap-4">
      {pharmacies.map((pharmacy) => (
        <PharmacyCard key={pharmacy.id} {...pharmacy} />
      ))}
    </div>
  )
}
```

3. **Use in Client Component** with React Query:

```tsx
'use client'

import { useQuery } from '@tanstack/react-query'
import { fetchPharmacies } from '@/lib/api'

export function PharmacyList() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['pharmacies'],
    queryFn: fetchPharmacies,
  })

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error loading pharmacies</div>

  return (
    <div className="grid gap-4">
      {data?.map((pharmacy) => (
        <PharmacyCard key={pharmacy.id} {...pharmacy} />
      ))}
    </div>
  )
}
```

### Firebase Authentication

```typescript
// lib/firebase.ts
import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
```

```typescript
// hooks/useAuth.ts
'use client'

import { useEffect, useState } from 'react'
import { User, onAuthStateChanged, signInWithPopup, GoogleAuthProvider } from 'firebase/auth'
import { auth } from '@/lib/firebase'

export function useAuth() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setUser(user)
      setLoading(false)
    })
    return unsubscribe
  }, [])

  const signInWithGoogle = async () => {
    const provider = new GoogleAuthProvider()
    await signInWithPopup(auth, provider)
  }

  return { user, loading, signInWithGoogle }
}
```

### Google Maps Integration

```tsx
// components/maps/PharmacyMap.tsx
'use client'

import { GoogleMap, LoadScript, Marker } from '@react-google-maps/api'

interface PharmacyMapProps {
  pharmacies: Array<{ id: number; lat: number; lng: number; name: string }>
}

export function PharmacyMap({ pharmacies }: PharmacyMapProps) {
  const center = { lat: 28.6139, lng: 77.2090 } // Delhi

  return (
    <LoadScript googleMapsApiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
      <GoogleMap
        mapContainerStyle={{ width: '100%', height: '500px' }}
        center={center}
        zoom={12}
      >
        {pharmacies.map((pharmacy) => (
          <Marker
            key={pharmacy.id}
            position={{ lat: pharmacy.lat, lng: pharmacy.lng }}
            title={pharmacy.name}
          />
        ))}
      </GoogleMap>
    </LoadScript>
  )
}
```

---

## Code Quality

### Linting

```bash
# Run ESLint
pnpm lint

# Fix auto-fixable issues
pnpm lint --fix
```

### Type Checking

```bash
# Check TypeScript types
pnpm tsc --noEmit
```

### Formatting

```bash
# Format with Prettier (if installed)
pnpm format

# Or use ESLint
pnpm lint --fix
```

---

## Testing

### Unit Tests (Jest)

```bash
# Run tests
pnpm test

# Watch mode
pnpm test:watch

# Coverage
pnpm test:coverage
```

### E2E Tests (Playwright)

```bash
# Install Playwright
pnpm create playwright

# Run E2E tests
pnpm test:e2e

# Open test UI
pnpm test:e2e:ui
```

---

## UI Components (shadcn/ui)

### Adding Components

```bash
# Add a component
pnpm dlx shadcn-ui@latest add button

# Add multiple components
pnpm dlx shadcn-ui@latest add card dialog form
```

### Available Components

- Button, Input, Select, Checkbox, Radio
- Card, Dialog, Sheet, Popover, Dropdown Menu
- Table, Form, Toast, Alert
- And many more...

### Example Usage

```tsx
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export function Example() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Example Card</CardTitle>
      </CardHeader>
      <CardContent>
        <Button>Click me</Button>
      </CardContent>
    </Card>
  )
}
```

---

## Styling with Tailwind CSS

### Utility Classes

```tsx
<div className="flex items-center justify-between p-4 bg-white rounded-lg shadow-md">
  <h2 className="text-2xl font-bold text-gray-900">Title</h2>
  <Button className="bg-blue-500 hover:bg-blue-600 text-white">
    Action
  </Button>
</div>
```

### Custom Theme

Edit `tailwind.config.ts`:

```typescript
export default {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
      },
    },
  },
}
```

---

## Debugging

### VS Code Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Next.js: debug server-side",
      "type": "node-terminal",
      "request": "launch",
      "command": "pnpm dev"
    },
    {
      "name": "Next.js: debug client-side",
      "type": "chrome",
      "request": "launch",
      "url": "http://localhost:3000"
    }
  ]
}
```

### React DevTools

Install React DevTools browser extension for debugging components.

### Network Inspection

Use browser DevTools Network tab to inspect API calls.

---

## Performance Optimization

### Image Optimization

```tsx
import Image from 'next/image'

<Image
  src="/pharmacy.jpg"
  alt="Pharmacy"
  width={500}
  height={300}
  priority  // For above-the-fold images
/>
```

### Code Splitting

```tsx
// Dynamic imports
import dynamic from 'next/dynamic'

const DynamicMap = dynamic(() => import('@/components/maps/PharmacyMap'), {
  ssr: false,  // Disable server-side rendering
  loading: () => <p>Loading map...</p>,
})
```

### Bundle Analysis

```bash
# Analyze bundle size
ANALYZE=true pnpm build
```

---

## Troubleshooting

### Build Errors

??? question "Module not found"
    ```bash
    # Clear cache and reinstall
    rm -rf .next node_modules
    pnpm install
    ```

??? question "TypeScript errors"
    ```bash
    # Regenerate types
    pnpm tsc --noEmit
    ```

### Environment Variables Not Working

- Ensure variables start with `NEXT_PUBLIC_` for client-side access
- Restart dev server after changing `.env.local`
- Check `.env.local` is not in `.gitignore`

### Firebase Issues

??? question "Firebase not initializing"
    - Verify all Firebase env variables are set
    - Check Firebase console for correct project ID
    - Ensure `firebase.ts` is imported before use

---

## Production Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Production deployment
vercel --prod
```

Set environment variables in Vercel dashboard.

### Docker

```bash
# Build production image
docker build -t medico24-website .

# Run container
docker run -p 3000:3000 medico24-website
```

---

## Next Steps

1. Complete [External Services Setup](external-services.md)
2. Integrate with [Backend API](backend-setup.md)
3. Explore [shadcn/ui components](https://ui.shadcn.com)
4. Read [Next.js Documentation](https://nextjs.org/docs)

**Related Guides:**

- [Setup Overview](overview.md)
- [External Services](external-services.md)
- [Backend Setup](backend-setup.md)
- [Mobile Setup](mobile-setup.md)
