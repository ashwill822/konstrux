import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.konstrux.app',
  appName: 'KONSTRUX',
  webDir: 'www',
  server: {
    url: 'https://konstrux.com.au',
    cleartext: false,
    allowNavigation: [
      'konstrux.com.au',
      '*.konstrux.com.au',
    ],
  },
  ios: {
    contentInset: 'always',
    allowsLinkPreview: false,
    scrollEnabled: true,
    backgroundColor: '#0f172a',
  },
};

export default config;
