// Run once with `npm run setup` from the project root. Safe to rerun.
// Import synchronous filesystem helpers for preserving and configuring project files.
import fs from 'node:fs';
// Build paths using the host operating system's path separator.
import path from 'node:path';
// Locate the system temporary directory for the bootstrap source backup.
import os from 'node:os';
// Run setup tools synchronously so each required step finishes before the next.
import {spawnSync} from 'node:child_process';
// Resolve all nested command working directories from the repository root.
const root = process.cwd();
// Wrap a required command so progress is visible and failures stop setup.
function run(command, args) {
  // Inherit terminal output and use the Windows shell to resolve .bat/.cmd tool wrappers.
  const result = spawnSync(command,args,{cwd:root,stdio:'inherit',shell:process.platform==='win32'});
  // Stop if the tool could not start or exited unsuccessfully; its detailed error stays visible above.
  if(result.error || result.status!==0) throw new Error(`${command} failed. Check its output above.`);
}
// Guard against running this script from outside the Chripy repository root.
if(!fs.existsSync('mobile/pubspec.yaml')) throw new Error('Run this from the Chripy project root.');
// Generate standard iOS/web scaffolding only when the iOS project is missing.
if(!fs.existsSync('mobile/ios/Runner/Info.plist')) {
  // Create a temporary backup before Flutter can overwrite supplied template source files.
  const backup=fs.mkdtempSync(path.join(os.tmpdir(),'chripy-bootstrap-'));
  // Protect the supplied Dart source, tests, dependency constraints, and analyzer settings.
  for(const name of ['lib','test','pubspec.yaml','analysis_options.yaml']) fs.cpSync(`mobile/${name}`,path.join(backup,name),{recursive:true});
  // Generate iOS/web files without resolving packages; restore protected source even if generation fails.
  try { run('flutter',['create','--no-pub','--platforms=ios,web','--org','com.justinjoel','--project-name','chripy','mobile']); }
  // Restore the protected originals regardless of whether platform generation succeeded.
  finally {
    // Protect the supplied Dart source, tests, dependency constraints, and analyzer settings.
    for(const name of ['lib','test','pubspec.yaml','analysis_options.yaml']) {
      // Remove only this protected template target before restoring its original backup.
      fs.rmSync(`mobile/${name}`,{recursive:true,force:true});
      // Copy the original source/settings back over Flutter's generated templates.
      fs.cpSync(path.join(backup,name),`mobile/${name}`,{recursive:true});
    }
    // Remove the temporary source backup after restoration is complete.
    fs.rmSync(backup,{recursive:true,force:true});
  }
}
// Initialize Supabase configuration only when this working copy has none.
if(!fs.existsSync('supabase/config.toml')) run('npx',['supabase','init']);
// Read the current TOML text so settings outside the managed sections are retained.
let config=fs.readFileSync('supabase/config.toml','utf8');
// Update selected TOML keys without replacing unrelated local configuration.
function setSection(name,values) {
  // Escape section-name dots so the regular expression matches them literally.
  const escaped=name.replaceAll('.','\\.');
  // Match one TOML section up to the next section heading or end of the file.
  const matcher=new RegExp(`^\\[${escaped}\\][^]*?(?=^\\[|(?![^]))`,'m');
  // Look for an existing section before deciding whether to append a new heading.
  const found=config.match(matcher);
  // Keep existing section text, or start a new section when none was found.
  let section=found?found[0]:`[${name}]\n`;
  // Apply each explicitly managed setting within this TOML section.
  for(const [key,value] of Object.entries(values)) {
    // Match an active setting line rather than a commented-out example.
    const line=new RegExp(`^${key}\\s*=.*$`,'m');
    // Replace an existing value while preserving the rest of this section.
    if(line.test(section)) section=section.replace(line,`${key} = ${value}`);
    // Append a setting that is not yet present in this section.
    else section+=`\n${key} = ${value}\n`;
  }
  // Replace the existing section in place, or append a missing section with separating newlines.
  if(found) config=config.replace(matcher,section+'\n'); else config+='\n'+section+'\n';
}
// Match the server's minimum password length to the app's ten-character rule.
setSection('auth', {minimum_password_length:'10'});
// Enable signup/confirmation and use six-digit codes, fifteen-minute expiry, and one-minute resend spacing.
setSection('auth.email', {enable_signup:'true',enable_confirmations:'true',otp_length:'6',otp_expiry:'900',max_frequency:'"1m"'});
// Use the signup-code template captured by the local Mailpit inbox.
setSection('auth.email.template.confirmation',{subject:'"Verify your Chripy email"',content_path:'"./supabase/templates/confirmation.html"'});
// Use a separate email subject/template for password-recovery codes.
setSection('auth.email.template.recovery',{subject:'"Reset your Chripy password"',content_path:'"./supabase/templates/recovery.html"'});
// Avoid starting the optional analytics service in this local learning environment.
setSection('analytics',{enabled:'false'});
// Save the managed configuration changes without applying or resetting any database data.
fs.writeFileSync('supabase/config.toml',config);
// Apply Chripy's display name, photo usage text, local-network text, and development HTTP setting.
run('node',['scripts/configure-ios.mjs']);
// Copy the example only if no local app configuration exists, preserving existing keys and URLs.
if(!fs.existsSync('mobile/config.local.json')) fs.copyFileSync('mobile/config.example.json','mobile/config.local.json');
// Explain the remaining manual step: copy the local client key into the app configuration.
console.log('Setup complete. Edit mobile/config.local.json after `npx supabase start`.');
