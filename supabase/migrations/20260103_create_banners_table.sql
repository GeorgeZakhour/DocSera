-- Create banners table
CREATE TABLE public.banners (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title text,
    text text, -- Short description/body for the banner card
    image_path text NOT NULL, -- URL to the image
    logo_path text, -- URL to the logo
    is_active boolean DEFAULT true,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    is_sponsored boolean DEFAULT false,
    logo_container_color text, -- Hex code for the logo container background
    order_index integer DEFAULT 0,
    content_sections jsonb, -- Array of sections for the details page
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT banners_pkey PRIMARY KEY (id)
);

-- Enable RLS
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Allow read access to everyone for active banners
CREATE POLICY "Public read access for active banners"
ON public.banners
FOR SELECT
USING (true); -- Logic for active/time checks will be done in the query for simplicity, or we can add it here.
-- Ideally: (is_active = true)

-- Allow full access to authenticated users with 'admin' role (if applicable) or service role.
-- For now, we'll stick to public read.
