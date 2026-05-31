-- Add missing columns to profiles table to match backend Profile model
-- Fields for Personal Advisor (PAK)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS personal_advisor TEXT,
ADD COLUMN IF NOT EXISTS personal_advisor_email TEXT;

-- Fields for Kokurikulum Metrics
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS kokurikulum_score DOUBLE PRECISION DEFAULT 0,
ADD COLUMN IF NOT EXISTS kokurikulum_credits INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS kokurikulum_activities TEXT[] DEFAULT '{}';

-- Fields for Academic Info (Direct columns)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS student_id TEXT,
ADD COLUMN IF NOT EXISTS department TEXT,
ADD COLUMN IF NOT EXISTS faculty TEXT,
ADD COLUMN IF NOT EXISTS year_of_study TEXT,
ADD COLUMN IF NOT EXISTS cgpa TEXT;

-- Fields for Enhanced Profile Data
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS academic_info JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS experiences JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS projects JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS phone_number TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS headline TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS linkedin_url TEXT,
ADD COLUMN IF NOT EXISTS github_url TEXT,
ADD COLUMN IF NOT EXISTS portfolio_url TEXT,
ADD COLUMN IF NOT EXISTS languages TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN DEFAULT FALSE;

-- Create index for faster search by Personal Advisor
CREATE INDEX IF NOT EXISTS idx_profiles_personal_advisor ON public.profiles(personal_advisor);

-- Create index for student_id lookups
CREATE INDEX IF NOT EXISTS idx_profiles_student_id ON public.profiles(student_id);
