-- Seed default privacy-focused ad campaigns
INSERT INTO public.ad_campaigns (id, title, description, banner_url, destination_url, category_target, start_date, end_date, is_active)
VALUES 
  (
    gen_random_uuid(),
    'Proton Mail',
    'Secure email that protects your privacy. Default 100% end-to-end encryption.',
    'https://raw.githubusercontent.com/peter14l/oasis/main/assets/ads/proton.png',
    'https://proton.me/mail',
    'feed',
    now() - interval '1 day',
    now() + interval '365 days',
    true
  ),
  (
    gen_random_uuid(),
    'Brave Browser',
    'Block ads and trackers by default. Secure, fast, and private browsing on all devices.',
    'https://raw.githubusercontent.com/peter14l/oasis/main/assets/ads/brave.png',
    'https://brave.com',
    'circles',
    now() - interval '1 day',
    now() + interval '365 days',
    true
  ),
  (
    gen_random_uuid(),
    'Signal Messenger',
    'Say hello to privacy. No ads, no trackers, no compromise. Pure end-to-end encryption.',
    'https://raw.githubusercontent.com/peter14l/oasis/main/assets/ads/signal.png',
    'https://signal.org',
    'feed',
    now() - interval '1 day',
    now() + interval '365 days',
    true
  ),
  (
    gen_random_uuid(),
    'DuckDuckGo',
    'Privacy, simplified. Seamlessly protect your data no matter where the internet takes you.',
    'https://raw.githubusercontent.com/peter14l/oasis/main/assets/ads/ddg.png',
    'https://duckduckgo.com',
    'wellness',
    now() - interval '1 day',
    now() + interval '365 days',
    true
  )
ON CONFLICT (id) DO NOTHING;
