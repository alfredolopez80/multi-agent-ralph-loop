/**
 * Supabase Basic Authentication Example
 *
 * This example demonstrates how to implement basic email/password authentication
 * with Supabase using the @supabase/supabase-js client library.
 *
 * Documentation: https://supabase.com/docs/guides/auth/passwords
 *
 * Install:
 * npm install @supabase/supabase-js
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js'

// ============================================================================
// CONFIGURATION
// ============================================================================

const supabaseUrl = process.env.SUPABASE_URL || 'https://your-project.supabase.co'
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'your-anon-key'

// Create Supabase client
const supabase: SupabaseClient = createClient(supabaseUrl, supabaseKey)

// ============================================================================
// TYPES
// ============================================================================

interface AuthError {
  message: string
  status?: number
}

interface AuthResponse {
  data: any | null
  error: AuthError | null
}

interface User {
  id: string
  email: string
  created_at: string
}

// ============================================================================
// SIGN UP (Register new user)
// ============================================================================

/**
 * Sign up a new user with email and password
 *
 * Note: If email confirmation is enabled, the user will receive a confirmation
 * email and won't be able to sign in until they click the link.
 */
export async function signUp(
  email: string,
  password: string
): Promise<AuthResponse> {
  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        // Optional: Redirect URL after email confirmation
        emailRedirectTo: `${window.location.origin}/welcome`,
      },
    })

    if (error) {
      return { data: null, error: { message: error.message, status: error.status } }
    }

    return { data, error: null }
  } catch (err) {
    return {
      data: null,
      error: { message: 'An unexpected error occurred during sign up' },
    }
  }
}

// ============================================================================
// SIGN IN (Login existing user)
// ============================================================================

/**
 * Sign in an existing user with email and password
 */
export async function signIn(
  email: string,
  password: string
): Promise<AuthResponse> {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      return { data: null, error: { message: error.message, status: error.status } }
    }

    return { data, error: null }
  } catch (err) {
    return {
      data: null,
      error: { message: 'An unexpected error occurred during sign in' },
    }
  }
}

// ============================================================================
// SIGN OUT (Logout)
// ============================================================================

/**
 * Sign out the current user
 */
export async function signOut(): Promise<{ error: AuthError | null }> {
  try {
    const { error } = await supabase.auth.signOut()

    if (error) {
      return { error: { message: error.message, status: error.status } }
    }

    return { error: null }
  } catch (err) {
    return {
      error: { message: 'An unexpected error occurred during sign out' },
    }
  }
}

// ============================================================================
// GET CURRENT USER
// ============================================================================

/**
 * Get the currently logged-in user
 */
export async function getCurrentUser(): Promise<AuthResponse> {
  try {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser()

    if (error) {
      return { data: null, error: { message: error.message, status: error.status } }
    }

    return { data: user, error: null }
  } catch (err) {
    return {
      data: null,
      error: { message: 'An unexpected error occurred while fetching user' },
    }
  }
}

// ============================================================================
// GET CURRENT SESSION
// ============================================================================

/**
 * Get the current session (includes access token, user, etc.)
 */
export async function getSession(): Promise<AuthResponse> {
  try {
    const {
      data: { session },
      error,
    } = await supabase.auth.getSession()

    if (error) {
      return { data: null, error: { message: error.message, status: error.status } }
    }

    return { data: session, error: null }
  } catch (err) {
    return {
      data: null,
      error: { message: 'An unexpected error occurred while fetching session' },
    }
  }
}

// ============================================================================
// RESET PASSWORD
// ============================================================================

/**
 * Request a password reset email
 * The user will receive an email with a link to reset their password
 */
export async function resetPassword(
  email: string,
  redirectTo: string = '/account/update-password'
): Promise<{ error: AuthError | null }> {
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}${redirectTo}`,
    })

    if (error) {
      return { error: { message: error.message, status: error.status } }
    }

    return { error: null }
  } catch (err) {
    return {
      error: { message: 'An unexpected error occurred during password reset' },
    }
  }
}

/**
 * Update the user's password (should be called from the reset password page)
 */
export async function updatePassword(
  newPassword: string
): Promise<{ error: AuthError | null }> {
  try {
    const { error } = await supabase.auth.updateUser({
      password: newPassword,
    })

    if (error) {
      return { error: { message: error.message, status: error.status } }
    }

    return { error: null }
  } catch (err) {
    return {
      error: { message: 'An unexpected error occurred while updating password' },
    }
  }
}

// ============================================================================
// AUTH STATE LISTENER
// ============================================================================

/**
 * Listen to auth state changes (sign in, sign out, etc.)
 * Useful for updating UI when auth state changes
 */
export function onAuthStateChange(
  callback: (event: string, session: any) => void
): () => void {
  const {
    data: { subscription },
  } = supabase.auth.onAuthStateChange((_event, session) => {
    callback(_event, session)
  })

  // Return unsubscribe function
  return () => {
    subscription.unsubscribe()
  }
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

/**
 * Example: Sign up a new user
 */
async function exampleSignUp() {
  const response = await signUp('user@example.com', 'securePassword123')

  if (response.error) {
    console.error('Sign up failed:', response.error.message)
    return
  }

  console.log('Sign up successful!', response.data)
}

/**
 * Example: Sign in a user
 */
async function exampleSignIn() {
  const response = await signIn('user@example.com', 'securePassword123')

  if (response.error) {
    console.error('Sign in failed:', response.error.message)
    return
  }

  console.log('Sign in successful!', response.data)
  console.log('Access token:', response.data.session.access_token)
}

/**
 * Example: Get current user
 */
async function exampleGetCurrentUser() {
  const response = await getCurrentUser()

  if (response.error) {
    console.error('Failed to get user:', response.error.message)
    return
  }

  if (response.data) {
    console.log('Current user:', response.data)
  } else {
    console.log('No user is logged in')
  }
}

/**
 * Example: Listen to auth state changes
 */
function exampleAuthListener() {
  const unsubscribe = onAuthStateChange((event, session) => {
    console.log('Auth event:', event)
    console.log('Session:', session)

    switch (event) {
      case 'INITIAL_SESSION':
        console.log('Initial session loaded')
        break
      case 'SIGNED_IN':
        console.log('User signed in')
        break
      case 'SIGNED_OUT':
        console.log('User signed out')
        break
      case 'USER_UPDATED':
        console.log('User updated')
        break
    }
  })

  // Later, if you want to stop listening:
  // unsubscribe()
}

/**
 * Example: Reset password flow
 */
async function examplePasswordReset() {
  // Step 1: Request password reset email
  const response = await resetPassword('user@example.com')

  if (response.error) {
    console.error('Failed to send reset email:', response.error.message)
    return
  }

  console.log('Password reset email sent!')

  // Step 2: After user clicks link in email and is redirected to reset page
  // Call this from the update password page:
  // const updateResponse = await updatePassword('newSecurePassword456')
  // if (updateResponse.error) {
  //   console.error('Failed to update password:', updateResponse.error.message)
  // } else {
  //   console.log('Password updated successfully!')
  // }
}

// ============================================================================
// EXPORTS
// ============================================================================

export default supabase
