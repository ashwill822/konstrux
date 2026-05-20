import { CapacitorConfig } from '@capacitor/cli';



const config: CapacitorConfig = {
  
  appId: 'com.konstrux.app',
  
  appName: 'KONSTRUX',
  
  webDir: 'www',
  
  server: {
    
    url: 'https://konstrux.com.au',
    
    cleartext: false,
    
    // IMPORTANT: Do NOT add manus.im or manus.space here.
    
    // If those domains are in allowNavigation, Capacitor navigates the WKWebView
    
    // directly to the OAuth portal instead of opening SFSafariViewController via
    
    // Browser.open(). WKWebView cannot handle the konstrux:// deep link redirect
    
    // after auth, causing login failures.
    
    // Browser.open() must open SFSafariViewController so iOS can intercept
    
    // the konstrux:// URL scheme and fire appUrlOpen back in the app.
    
    allowNavigation: [
      
      'konstrux.com.au',
      
      '*.konstrux.com.au',
      
    ],
    
  },
  
  ios: {
    
    contentInset: 'always',
    
    allowsLinkPreview: false,
    
    scrollEnabled: true,
    
    backgroundColor: '#0A0A0A',
    
  },
  
};



export default config;
























