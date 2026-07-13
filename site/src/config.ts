const cleanUrl = (value: string | undefined, fallback = '') =>
  (value?.trim() || fallback).replace(/\/$/, '');

export const publicConfig = {
  siteUrl: cleanUrl(import.meta.env.PUBLIC_SITE_URL, 'https://jibiki.app'),
  appUrl: cleanUrl(import.meta.env.PUBLIC_APP_URL, 'https://my.jibiki.app'),
  apiUrl: cleanUrl(import.meta.env.PUBLIC_API_URL),
  gaMeasurementId: import.meta.env.PUBLIC_GA_MEASUREMENT_ID?.trim() || '',
  googleSiteVerification:
    import.meta.env.PUBLIC_GOOGLE_SITE_VERIFICATION?.trim() || '',
} as const;
