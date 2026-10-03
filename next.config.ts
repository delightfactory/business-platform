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
