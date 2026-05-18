import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.konstrux.app',
  appName: 'KONSTRUX',
  webDir: 'www',
  server: {
    url: 'https://konstrux.com.au',
    cleartext: false,
    // Allow navigation to Manus OAuth portal and API domains so login
    // stays within the WKWebView instead of opening external Safari.
    allowNavigation: [
      'konstrux.com.au',
      '*.konstrux.com.au',
      '*.manus.im',
      'manus.im',
      '*.manus.space',
      'manus.space',
    ],
  },
  ios: {
    // 'never' lets the web app control its own safe area via CSS env() variables.
    // 'always' adds an extra system inset on top of what the web app already handles,
    // which was causing the double-overlap of the status bar.
    contentInset: 'never',
    allowsLinkPreview: false,
    scrollEnabled: true,
    backgroundColor: '#0A0A0A',
  },
};

export default config;
