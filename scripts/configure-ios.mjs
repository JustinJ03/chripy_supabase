// Update selected iOS settings while retaining the generated platform project.
import fs from 'node:fs';
// Locate the app's property list relative to the repository root.
const file='mobile/ios/Runner/Info.plist';
// Preserve the existing plist text and unrelated bundle/version settings.
let xml=fs.readFileSync(file,'utf8');
// Replace a managed key, or insert it into the root dictionary if absent.
function replace(key,value) {
  // Escape regex punctuation so the requested key is matched literally.
  const escaped=key.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  // Recognize the string, dictionary, and boolean shapes managed below.
  const existing=new RegExp(`<key>${escaped}</key>\\s*(?:<string>[^]*?</string>|<dict>[^]*?</dict>|<true\\s*/>|<false\\s*/>)`);
  // Build the plist key/value entry using the caller's XML value.
  const entry=`<key>${key}</key>\n\t${value}`;
  // Replace only the managed entry when it already exists.
  if(existing.test(xml)) xml=xml.replace(existing,entry);
  // Insert missing entries immediately before the root dictionary closes.
  else xml=xml.replace(/<\/dict>\s*<\/plist>\s*$/,`\t${entry}\n</dict>\n</plist>\n`);
}
// Show Chripy underneath the installed app icon.
replace('CFBundleDisplayName','<string>Chripy</string>');
// Explain why the app opens the photo library to choose an avatar.
replace('NSPhotoLibraryUsageDescription','<string>Choose a profile photo for Chripy.</string>');
// Explain why Chripy connects to the home PC over the local network.
replace('NSLocalNetworkUsageDescription','<string>Connect to the Chripy Supabase server on your home PC.</string>');
// Allow plain HTTP for local development; remove this broad exception for hosted HTTPS distribution.
replace('NSAppTransportSecurity','<dict><key>NSAllowsArbitraryLoads</key><true/></dict>');
// Save the managed plist edits while preserving the existing Xcode project.
fs.writeFileSync(file,xml);
// Report completion so the setup script's progress is visible.
console.log('Configured Chripy iOS permissions for local HTTP testing.');
