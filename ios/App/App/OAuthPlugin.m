#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Register the OAuthPlugin with Capacitor so it is accessible from JavaScript
// as Capacitor.Plugins.OAuth
CAP_PLUGIN(OAuthPlugin, "OAuth",
    CAP_PLUGIN_METHOD(start, CAPPluginReturnPromise);
)
