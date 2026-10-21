// Run once with `npm run setup` from the project root. Safe to rerun.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawnSync} from 'node:child_process';
const root = process.cwd();
function run(command, args) {
  const result = spawnSync(command,args,{cwd:root,stdio:'inherit',shell:process.platform==='win32'});
  if(result.error || result.status!==0) throw new Error(`${command} failed. Check its output above.`);
}
if(!fs.existsSync('mobile/pubspec.yaml')) throw new Error('Run this from the Chripy project root.');
if(!fs.existsSync('mobile/ios/Runner/Info.plist')) {
  const backup=fs.mkdtempSync(path.join(os.tmpdir(),'chripy-bootstrap-'));
  for(const name of ['lib','test','pubspec.yaml','analysis_options.yaml']) fs.cpSync(`mobile/${name}`,path.join(backup,name),{recursive:true});
  try { run('flutter',['create','--no-pub','--platforms=ios,web','--org','com.justinjoel','--project-name','chripy','mobile']); }
  finally {
    for(const name of ['lib','test','pubspec.yaml','analysis_options.yaml']) {
      fs.rmSync(`mobile/${name}`,{recursive:true,force:true});
      fs.cpSync(path.join(backup,name),`mobile/${name}`,{recursive:true});
    }
    fs.rmSync(backup,{recursive:true,force:true});
  }
}
if(!fs.existsSync('supabase/config.toml')) run('npx',['supabase','init']);
let config=fs.readFileSync('supabase/config.toml','utf8');
function setSection(name,values) {
  const escaped=name.replaceAll('.','\\.');
  const matcher=new RegExp(`^\\[${escaped}\\][^]*?(?=^\\[|(?![^]))`,'m');
  const found=config.match(matcher);
  let section=found?found[0]:`[${name}]\n`;
  for(const [key,value] of Object.entries(values)) {
    const line=new RegExp(`^${key}\\s*=.*$`,'m');
    if(line.test(section)) section=section.replace(line,`${key} = ${value}`);
    else section+=`\n${key} = ${value}\n`;
  }
  if(found) config=config.replace(matcher,section+'\n'); else config+='\n'+section+'\n';
}
setSection('auth', {minimum_password_length:'10'});
setSection('auth.email', {enable_signup:'true',enable_confirmations:'true',otp_length:'6',otp_expiry:'900',max_frequency:'"1m"'});
setSection('auth.email.template.confirmation',{subject:'"Verify your Chripy email"',content_path:'"./supabase/templates/confirmation.html"'});
setSection('auth.email.template.recovery',{subject:'"Reset your Chripy password"',content_path:'"./supabase/templates/recovery.html"'});
setSection('analytics',{enabled:'false'});
fs.writeFileSync('supabase/config.toml',config);
run('node',['scripts/configure-ios.mjs']);
if(!fs.existsSync('mobile/config.local.json')) fs.copyFileSync('mobile/config.example.json','mobile/config.local.json');
console.log('Setup complete. Edit mobile/config.local.json after `npx supabase start`.');
