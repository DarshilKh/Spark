/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'i.pravatar.cc',   // MOCK_EXPERTS avatars
      },
      {
        protocol: 'https',
        hostname: 'images.unsplash.com', // BounceCards images
      },
      {
        protocol: 'https',
        hostname: 'ui-avatars.com',  // fallback avatars
      },
    ],
  },
};

module.exports = nextConfig;