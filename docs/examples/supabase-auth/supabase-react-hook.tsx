/**
 * Supabase Authentication React Hook
 *
 * A custom React Hook for managing authentication state with Supabase.
 * This hook provides an easy way to handle sign in, sign up, sign out,
 * and track the current user in your React application.
 *
 * Requirements:
 * - @supabase/supabase-js
 * - React 18+
 *
 * Usage:
 * ```tsx
 * function App() {
 *   const { user, signIn, signUp, signOut } = useSupabaseAuth()
 *
 *   if (!user) {
 *     return <LoginForm onSignIn={signIn} onSignUp={signUp} />
 *   }
 *
 *   return <Dashboard user={user} onSignOut={signOut} />
 * }
 * ```
 */

import { useState, useEffect, useCallback } from 'react'
import { User, Session, AuthError } from '@supabase/supabase-js'
import { createClient, SupabaseClient } from '@supabase/supabase-js'

// ============================================================================
// TYPES
// ============================================================================

interface UseSupabaseAuthReturn {
  // User state
  user: User | null
  session: Session | null
  loading: boolean
  error: string | null

  // Auth methods
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  resetPassword: (email: string) => Promise<void>
  updatePassword: (newPassword: string) => Promise<void>

  // Utility methods
  clearError: () => void
  refreshSession: () => Promise<void>
}

interface AuthConfig {
  supabaseUrl: string
  supabaseKey: string
}

// ============================================================================
// HOOK
// ============================================================================

export function useSupabaseAuth(config: AuthConfig): UseSupabaseAuthReturn {
  const [supabase] = useState<SupabaseClient>(() =>
    createClient(config.supabaseUrl, config.supabaseKey)
  )

  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)

  // ============================================================================
  // INIT: Get initial session
  // ============================================================================

  useEffect(() => {
    let mounted = true

    async function getInitialSession() {
      try {
        const {
          data: { session: initialSession },
        } = await supabase.auth.getSession()

        if (mounted) {
          setSession(initialSession)
          setUser(initialSession?.user ?? null)
          setLoading(false)
        }
      } catch (err) {
        if (mounted) {
          setError('Failed to get initial session')
          setLoading(false)
        }
      }
    }

    getInitialSession()

    return () => {
      mounted = false
    }
  }, [supabase])

  // ============================================================================
  // LISTEN: Auth state changes
  // ============================================================================

  useEffect(() => {
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
      setUser(session?.user ?? null)
      setLoading(false)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [supabase])

  // ============================================================================
  // SIGN IN
  // ============================================================================

  const signIn = useCallback(
    async (email: string, password: string) => {
      setError(null)
      setLoading(true)

      try {
        const { data, error: signInError } = await supabase.auth.signInWithPassword(
          {
            email,
            password,
          }
        )

        if (signInError) {
          setError(signInError.message)
          return
        }

        setSession(data.session)
        setUser(data.user)
      } catch (err) {
        setError('An unexpected error occurred during sign in')
      } finally {
        setLoading(false)
      }
    },
    [supabase]
  )

  // ============================================================================
  // SIGN UP
  // ============================================================================

  const signUp = useCallback(
    async (email: string, password: string) => {
      setError(null)
      setLoading(true)

      try {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}/welcome`,
          },
        })

        if (signUpError) {
          setError(signUpError.message)
          return
        }

        setSession(data.session)
        setUser(data.user)
      } catch (err) {
        setError('An unexpected error occurred during sign up')
      } finally {
        setLoading(false)
      }
    },
    [supabase]
  )

  // ============================================================================
  // SIGN OUT
  // ============================================================================

  const signOut = useCallback(async () => {
    setError(null)
    setLoading(true)

    try {
      const { error: signOutError } = await supabase.auth.signOut()

      if (signOutError) {
        setError(signOutError.message)
        return
      }

      setSession(null)
      setUser(null)
    } catch (err) {
      setError('An unexpected error occurred during sign out')
    } finally {
      setLoading(false)
    }
  }, [supabase])

  // ============================================================================
  // RESET PASSWORD
  // ============================================================================

  const resetPassword = useCallback(
    async (email: string) => {
      setError(null)
      setLoading(true)

      try {
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(
          email,
          {
            redirectTo: `${window.location.origin}/account/update-password`,
          }
        )

        if (resetError) {
          setError(resetError.message)
          return
        }
      } catch (err) {
        setError('An unexpected error occurred during password reset')
      } finally {
        setLoading(false)
      }
    },
    [supabase]
  )

  // ============================================================================
  // UPDATE PASSWORD
  // ============================================================================

  const updatePassword = useCallback(
    async (newPassword: string) => {
      setError(null)
      setLoading(true)

      try {
        const { error: updateError } = await supabase.auth.updateUser({
          password: newPassword,
        })

        if (updateError) {
          setError(updateError.message)
          return
        }
      } catch (err) {
        setError('An unexpected error occurred while updating password')
      } finally {
        setLoading(false)
      }
    },
    [supabase]
  )

  // ============================================================================
  // UTILITY: Clear error
  // ============================================================================

  const clearError = useCallback(() => {
    setError(null)
  }, [])

  // ============================================================================
  // UTILITY: Refresh session
  // ============================================================================

  const refreshSession = useCallback(async () => {
    setLoading(true)

    try {
      const {
        data: { session: newSession },
        error: refreshError,
      } = await supabase.auth.refreshSession()

      if (refreshError) {
        setError(refreshError.message)
        return
      }

      setSession(newSession)
      setUser(newSession?.user ?? null)
    } catch (err) {
      setError('An unexpected error occurred while refreshing session')
    } finally {
      setLoading(false)
    }
  }, [supabase])

  // ============================================================================
  // RETURN
  // ============================================================================

  return {
    user,
    session,
    loading,
    error,
    signIn,
    signUp,
    signOut,
    resetPassword,
    updatePassword,
    clearError,
    refreshSession,
  }
}

// ============================================================================
// EXAMPLE COMPONENTS
// ============================================================================

/**
 * Example: Authentication Provider
 */
export function SupabaseAuthProvider({
  children,
  config,
}: {
  children: React.ReactNode
  config: AuthConfig
}) {
  const auth = useSupabaseAuth(config)

  return (
    <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>
  )
}

/**
 * Example: Login Form
 */
export function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
  const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

  const { signIn, signUp, loading, error } = useSupabaseAuth({
    supabaseUrl,
    supabaseKey,
  })

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault()
    await signIn(email, password)
  }

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault()
    await signUp(email, password)
  }

  return (
    <form className="max-w-md mx-auto mt-8">
      <h1 className="text-2xl font-bold mb-4">Sign In</h1>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <div className="mb-4">
        <label className="block mb-2">Email</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full px-3 py-2 border rounded"
          disabled={loading}
        />
      </div>

      <div className="mb-4">
        <label className="block mb-2">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full px-3 py-2 border rounded"
          disabled={loading}
        />
      </div>

      <button
        type="submit"
        onClick={handleSignIn}
        disabled={loading}
        className="w-full bg-blue-500 text-white py-2 rounded mb-2"
      >
        {loading ? 'Loading...' : 'Sign In'}
      </button>

      <button
        type="button"
        onClick={handleSignUp}
        disabled={loading}
        className="w-full bg-green-500 text-white py-2 rounded"
      >
        {loading ? 'Loading...' : 'Sign Up'}
      </button>
    </form>
  )
}

/**
 * Example: Protected Route
 */
export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
  const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

  const { user, loading } = useSupabaseAuth({
    supabaseUrl,
    supabaseKey,
  })

  if (loading) {
    return <div>Loading...</div>
  }

  if (!user) {
    return <LoginForm />
  }

  return <>{children}</>
}

/**
 * Example: Dashboard with user info
 */
export function Dashboard() {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
  const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

  const { user, signOut } = useSupabaseAuth({
    supabaseUrl,
    supabaseKey,
  })

  return (
    <div className="max-w-md mx-auto mt-8">
      <h1 className="text-2xl font-bold mb-4">Dashboard</h1>

      <div className="bg-gray-100 p-4 rounded mb-4">
        <p className="font-semibold">Welcome!</p>
        <p>Email: {user?.email}</p>
        <p>ID: {user?.id}</p>
      </div>

      <button
        onClick={signOut}
        className="w-full bg-red-500 text-white py-2 rounded"
      >
        Sign Out
      </button>
    </div>
  )
}

// ============================================================================
// CONTEXT (Optional: for sharing auth state across components)
// ============================================================================

import { createContext, useContext } from 'react'

const AuthContext = createContext<UseSupabaseAuthReturn | null>(null)

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within SupabaseAuthProvider')
  }
  return context
}
