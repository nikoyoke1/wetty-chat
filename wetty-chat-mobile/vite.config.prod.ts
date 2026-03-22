import { defineConfig, mergeConfig } from 'vite';
import { createBaseConfig } from './vite.config.base';
import { execSync } from 'child_process';

const assetUrl = process.env.ASSET_URL?.replace(/\/+$/, '');

if (!assetUrl) {
  throw new Error('ASSET_URL is required for production builds');
}

let commitHash = 'unknown';
try {
  commitHash = execSync('git rev-parse --short HEAD').toString().trim();
} catch {
  // Ignore
}

export default mergeConfig(createBaseConfig({ assetCdnOrigin: assetUrl }), defineConfig({
  experimental: {
    renderBuiltUrl(filename, { type }) {
      if (type === 'public') {
        return `/${filename}`;
      }

      return `${assetUrl}/${filename}`;
    },
  },
  define: {
    // Uncomment this and comment out __AUTH_REDIRECT_URL__ for separate domain deployment
    // __API_BASE__: JSON.stringify('https://chahui.app/_api'),
    __APP_VERSION__: JSON.stringify(commitHash),
    __AUTH_REDIRECT_URL__: JSON.stringify("/main/member.php?mod=logging&action=login&referer=https://www.shireyishunjian.com/chat/"),
  },
}));
