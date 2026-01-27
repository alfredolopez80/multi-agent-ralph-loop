# Supabase Authentication Examples

Complete examples for implementing basic email/password authentication with Supabase.

## Installation

```bash
npm install @supabase/supabase-js
```

## Configuration

Create a `.env.local` file with your Supabase credentials:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

You can find these values in your Supabase project settings:
1. Go to [supabase.com](https://supabase.com)
2. Select your project
3. Go to Project Settings → API

## Files

- `supabase-auth-example.ts` - Core authentication functions
- `supabase-react-hook.tsx` - React Hook for authentication (coming)
- `README.md` - This file

## Quick Start

### 1. Create Supabase Client

```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseKey)
```

### 2. Sign Up (Register)

```typescript
import { signUp } from './supabase-auth-example'

async function handleSignUp(email: string, password: string) {
  const { data, error } = await signUp(email, password)

  if (error) {
    console.error('Sign up failed:', error.message)
    return
  }

  console.log('Sign up successful!', data)
}
```

### 3. Sign In (Login)

```typescript
import { signIn } from './supabase-auth-example'

async function handleSignIn(email: string, password: string) {
  const { data, error } = await signIn(email, password)

  if (error) {
    console.error('Sign in failed:', error.message)
    return
  }

  console.log('Sign in successful!', data)
}
```

### 4. Sign Out (Logout)

```typescript
import { signOut } from './supabase-auth-example'

async function handleSignOut() {
  const { error } = await signOut()

  if (error) {
    console.error('Sign out failed:', error.message)
    return
  }

  console.log('Signed out successfully')
}
```

### 5. Get Current User

```typescript
import { getCurrentUser } from './supabase-auth-example'

async function checkAuth() {
  const { data, error } = await getCurrentUser()

  if (error || !data) {
    console.log('No user is logged in')
    return
  }

  console.log('Current user:', data)
}
```

### 6. Reset Password

```typescript
import { resetPassword, updatePassword } from './supabase-auth-example'

// Request password reset email
async function requestPasswordReset(email: string) {
  const { error } = await resetPassword(email)

  if (error) {
    console.error('Failed to send reset email:', error.message)
    return
  }

  console.log('Password reset email sent!')
}

// Update password (call from reset page)
async function handleUpdatePassword(newPassword: string) {
  const { error } = await updatePassword(newPassword)

  if (error) {
    console.error('Failed to update password:', error.message)
    return
  }

  console.log('Password updated successfully!')
}
```

### 7. Listen to Auth State Changes

```typescript
import { onAuthStateChange } from './supabase-auth-example'

// Subscribe to auth state changes
const unsubscribe = onAuthStateChange((event, session) => {
  console.log('Auth event:', event)
  console.log('Session:', session)

  switch (event) {
    case 'SIGNED_IN':
      console.log('User signed in')
      break
    case 'SIGNED_OUT':
      console.log('User signed out')
      break
  }
})

// Unsubscribe when done
// unsubscribe()
```

## Authentication Flow

### Email Confirmation (Default)

By default, Supabase requires email confirmation:

1. User signs up → receives confirmation email
2. User clicks confirmation link → redirected to your app
3. User can now sign in

### Disable Email Confirmation (Development Only)

For local development, you can disable email confirmation:

1. Go to Supabase Dashboard → Authentication → Providers
2. Find "Email" provider
3. Toggle "Confirm email" to OFF

## Error Handling

All functions return a consistent response format:

```typescript
interface AuthResponse {
  data: any | null
  error: { message: string; status?: number } | null
}
```

Usage:

```typescript
const { data, error } = await signIn(email, password)

if (error) {
  // Handle error
  if (error.status === 400) {
    console.error('Invalid credentials')
  } else if (error.status === 429) {
    console.error('Too many requests')
  } else {
    console.error(error.message)
  }
  return
}

// Success - use data
console.log('User:', data.user)
console.log('Session:', data.session)
```

## Security Best Practices

1. **Never expose your service_role key** on the client
2. **Use Row Level Security (RLS)** in Supabase to protect data
3. **Enable email confirmation** for production
4. **Use strong password requirements** on the client
5. **Implement rate limiting** for auth endpoints

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Invalid login credentials` | Wrong email or password | Check user input |
| `Email not confirmed` | User hasn't clicked confirmation link | Resend confirmation email |
| `User already registered` | Email already exists | Sign in instead |
| `Password should be at least 6 characters` | Password too short | Enforce minimum length |

## Resources

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Password-based Auth](https://supabase.com/docs/guides/auth/passwords)
- [Supabase JavaScript Client](https://supabase.com/docs/reference/javascript)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

## License

MIT
