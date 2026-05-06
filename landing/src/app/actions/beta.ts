'use server';

import { supabase } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';
import { sendConfirmationEmail, sendLaunchEmail } from '@/lib/mail';

export async function getMaxBetaTesters(): Promise<number> {
  return 15;
}

export interface BetaSignupResult {
  success: boolean;
  message: string;
  isBetaFull: boolean;
}

export async function joinBetaTester(userEmail: string): Promise<BetaSignupResult> {
  try {
    // Check if email already registered - Check this FIRST so existing users can sign in even if beta is full
    const { data: existing } = await supabase
      .from('beta_testers')
      .select('email, status')
      .eq('email', userEmail)
      .single();

    if (existing) {
      if (existing.status === 'active') {
        return { 
          success: true, 
          message: 'Welcome back! You are already a beta tester.', 
          isBetaFull: false 
        };
      } else {
        // Reactivate if was previously waitlisted - But only if not full!
        const maxTesters = await getMaxBetaTesters();
        const { count } = await supabase
          .from('beta_testers')
          .select('*', { count: 'exact', head: true });
        
        if ((count || 0) >= maxTesters) {
          return { 
            success: false, 
            message: 'Sorry we are filled up now. We\'ll notify you when we expand.', 
            isBetaFull: true 
          };
        }

        await supabase
          .from('beta_testers')
          .update({ status: 'active', updated_at: new Date().toISOString() })
          .eq('email', userEmail);
        
        await sendConfirmationEmail(userEmail);
        
        return { 
          success: true, 
          message: 'You\'re in! Welcome to the beta.',
          isBetaFull: false 
        };
      }
    }

    const maxTesters = await getMaxBetaTesters();
    
    // Check current beta tester count
    const { count, error: countError } = await supabase
      .from('beta_testers')
      .select('*', { count: 'exact', head: true });

    if (countError) {
      console.error('Error checking beta count:', countError);
      return { 
        success: false, 
        message: 'Unable to verify beta status. Please try again.', 
        isBetaFull: false 
      };
    }

    const currentCount = count || 0;

    if (currentCount >= maxTesters) {
      return { 
        success: false, 
        message: 'Sorry we are filled up now. Enter your email below to join the waitlist again and we\'ll notify you when we expand.', 
        isBetaFull: true 
      };
    }

    // Add new beta tester
    const { error: insertError } = await supabase
      .from('beta_testers')
      .insert({
        email: userEmail,
        status: 'active',
        joined_at: new Date().toISOString()
      });

    if (insertError) {
      console.error('Error inserting beta tester:', insertError);
      return { 
        success: false, 
        message: 'Unable to join beta. Please try again.', 
        isBetaFull: false 
      };
    }

    await sendConfirmationEmail(userEmail);

    revalidatePath('/');
    return { 
      success: true, 
      message: 'You\'re in! Welcome to the beta.',
      isBetaFull: false 
    };

  } catch (error) {
    console.error('Unexpected error:', error);
    return { 
      success: false, 
      message: 'An unexpected error occurred. Please try again.', 
      isBetaFull: false 
    };
  }
}

export async function joinWaitlist(userEmail: string): Promise<BetaSignupResult> {
  try {
    // Check if email already exists
    const { data: existing } = await supabase
      .from('waitlist')
      .select('email')
      .eq('email', userEmail)
      .single();

    if (existing) {
      return { 
        success: false, 
        message: 'An account already exists with this email on our waitlist. We\'ll notify you when we expand.', 
        isBetaFull: true 
      };
    }

    // Add to waitlist
    const { error: insertError } = await supabase
      .from('waitlist')
      .insert({
        email: userEmail,
        joined_at: new Date().toISOString()
      });

    if (insertError) {
      console.error('Error adding to waitlist:', insertError);
      return { 
        success: false, 
        message: 'Unable to join waitlist. Please try again.', 
        isBetaFull: true 
      };
    }

    await sendConfirmationEmail(userEmail);

    return { 
      success: true, 
      message: 'You\'ve been added to the waitlist! Please check your spam folder for the verification mail.',
      isBetaFull: true 
    };

  } catch (error) {
    console.error('Unexpected error:', error);
    return { 
      success: false, 
      message: 'An unexpected error occurred. Please try again.', 
      isBetaFull: true 
    };
  }
}

export async function getBetaTesterCount(): Promise<number> {
  const maxTesters = await getMaxBetaTesters();
  const { count, error } = await supabase
    .from('beta_testers')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'active');

  if (error) {
    console.error('Error getting beta count:', error);
    return 0;
  }

  return Math.min(count || 0, maxTesters);
}

export async function notifyAllUsersOfLaunch() {
  try {
    // Fetch all beta testers
    const { data: betaTesters } = await supabase
      .from('beta_testers')
      .select('email');

    // Fetch all waitlist users
    const { data: waitlistUsers } = await supabase
      .from('waitlist')
      .select('email');

    const allEmails = new Set<string>();
    betaTesters?.forEach(u => allEmails.add(u.email));
    waitlistUsers?.forEach(u => allEmails.add(u.email));

    const results = await Promise.all(
      Array.from(allEmails).map(email => sendLaunchEmail(email))
    );

    const successful = results.filter(r => r.success).length;
    return { 
      success: true, 
      total: allEmails.size, 
      successful 
    };
  } catch (error) {
    console.error('Error notifying users of launch:', error);
    return { success: false, message: 'Failed to notify users' };
  }
}

