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
  plugins: {
    // Register our custom native OAuth plugin.
    // This ensures Capacitor includes "OAuthPlugin" in the packageClassList inside
    // capacitor.config.json, so the bridge loads it at startup and
    // Capacitor.Plugins.OAuth is available in JavaScript.
    // Without this entry, cap sync omits OAuthPlugin from packageClassList and
    // the plugin is never registered — causing the app to fall back to
    // SFSafariViewController (which loses sessionStorage during Google redirect).
    OAuth: {},
  },
  ios: {
    contentInset: 'always',
    allowsLinkPreview: false,
    scrollEnabled: true,
    backgroundColor: '#0A0A0A',
  },
};

export default config;
