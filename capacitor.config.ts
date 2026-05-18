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
    // 'always' tells iOS to pass the real safe area inset values (Dynamic Island,
    // status bar height) into the WebView so CSS env(safe-area-inset-top) works.
    // Without this, env(safe-area-inset-top) returns 0 and the header overlaps the status bar.
    contentInset: 'always',
    allowsLinkPreview: false,
    scrollEnabled: true,
    backgroundColor: '#0A0A0A',
  },
};

export default config;
