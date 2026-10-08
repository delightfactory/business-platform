import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  webpack(config, { isServer }) {
    // Next 16.3.6 omits concatenated client module ID 0 from the RSC manifest.
    if (!isServer) config.optimization.concatenateModules = false;
    return config;
  },
  experimental: {
    serverActions: { bodySizeLimit: '3mb' },
  },
  async headers() {
    return [{
      source: '/sw.js',
      headers: [
        { key: 'Content-Type', value: 'application/javascript; charset=utf-8' },
        { key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' },
        { key: 'Content-Security-Policy', value: "default-src 'none'; script-src 'self'; connect-src 'self'" },
      ],
    }, {
      source: '/offline.html',
      headers: [
        { key: 'Referrer-Policy', value: 'no-referrer' },
        { key: 'Content-Security-Policy', value: "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'" },
      ],
    }, {
      source: '/auth/invitations/callback',
      headers: [
        { key: 'Cache-Control', value: 'private, no-store, max-age=0' },
        { key: 'Referrer-Policy', value: 'no-referrer' },
      ],
    }, {
      source: '/auth/membership-invitations/callback',
      headers: [
        { key: 'Cache-Control', value: 'private, no-store, max-age=0' },
        { key: 'Referrer-Policy', value: 'no-referrer' },
      ],
    }, {
      source: '/auth/employee-account-activation/callback',
      headers: [
        { key: 'Cache-Control', value: 'private, no-store, max-age=0' },
        { key: 'Referrer-Policy', value: 'no-referrer' },
      ],
    }];
  },
};

export default nextConfig;
