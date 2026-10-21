import fs from 'node:fs';
const file='mobile/ios/Runner/Info.plist';
let xml=fs.readFileSync(file,'utf8');
function replace(key,value) {
  const escaped=key.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  const existing=new RegExp(`<key>${escaped}</key>\\s*(?:<string>[^]*?</string>|<dict>[^]*?</dict>|<true\\s*/>|<false\\s*/>)`);
  const entry=`<key>${key}</key>\n\t${value}`;
  if(existing.test(xml)) xml=xml.replace(existing,entry);
  else xml=xml.replace(/<\/dict>\s*<\/plist>\s*$/,`\t${entry}\n</dict>\n</plist>\n`);
}
replace('CFBundleDisplayName','<string>Chripy</string>');
replace('NSPhotoLibraryUsageDescription','<string>Choose a profile photo for Chripy.</string>');
replace('NSLocalNetworkUsageDescription','<string>Connect to the Chripy Supabase server on your home PC.</string>');
// Local HTTP development only. Remove this broad exception before cloud distribution.
replace('NSAppTransportSecurity','<dict><key>NSAllowsArbitraryLoads</key><true/></dict>');
fs.writeFileSync(file,xml);
console.log('Configured Chripy iOS permissions for local HTTP testing.');
