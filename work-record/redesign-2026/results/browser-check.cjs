const { chromium } = require('playwright');
const fs=require('fs');
(async()=>{
const browser=await chromium.launch({headless:true,executablePath:'/Users/ericlee06/Library/Caches/ms-playwright/chromium-1208/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'});
const page=await browser.newPage({viewport:{width:768,height:1200},colorScheme:'dark'});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('file:///tmp/wt-design-browser/preview.html');
const frame=page.frameLocator('iframe');
await frame.locator('#wt-content h1').waitFor();
await frame.locator('#wt-phone').screenshot({path:'/tmp/wt-design-browser/home-dark.png'});
const options=await frame.locator('#wt-screen option').evaluateAll(os=>os.map(o=>o.value));
const overflows=[];
for(const width of [768,352]){
await page.setViewportSize({width,height:1400});
for(const s of options){
await frame.locator('#wt-screen').selectOption(s);
const result=await frame.locator('#wt-phone').evaluate(el=>({screen:document.getElementById('wt-screen').value,width:el.clientWidth,scroll:el.scrollWidth,overflow:[...el.querySelectorAll('button,input,select,h1,h2,h3')].filter(x=>{const a=x.getBoundingClientRect(),b=el.getBoundingClientRect();return a.width&&a.right>b.right+1}).map(x=>x.textContent.slice(0,60))}));
if(result.scroll>result.width+2||result.overflow.length)overflows.push({width,...result});
}
}
await page.setViewportSize({width:768,height:1400});
await frame.locator('#wt-screen').selectOption('active');
await frame.getByRole('button',{name:'Complete set 2',exact:true}).click();
if(await frame.locator('.setrow').count()!==3)throw Error('Set completion appended a row');
if(!await frame.getByRole('button',{name:'Skip',exact:true}).isVisible())throw Error('Rest absent');
await frame.getByRole('button',{name:'Add Set',exact:true}).click();
if(await frame.locator('.setrow').count()!==4)throw Error('Add set failed');
await frame.locator('#wt-phone').screenshot({path:'/tmp/wt-design-browser/active-dark.png'});
await frame.locator('#wt-screen').selectOption('ai');
await frame.getByRole('button',{name:'4',exact:true}).click();
await frame.getByRole('button',{name:'Generate templates',exact:true}).click();
if(await frame.locator('.row').count()!==4)throw Error('AI count wrong');
await frame.getByRole('button',{name:'Save templates',exact:true}).click();
if(!await frame.getByRole('status').isVisible())throw Error('Missing save receipt');
await frame.locator('#wt-screen').selectOption('settings');
await frame.getByRole('button',{name:'Larger text preview Off'}).click();
await frame.locator('#wt-screen').selectOption('home');
await frame.locator('#wt-phone').screenshot({path:'/tmp/wt-design-browser/home-large.png'});
for(const s of options){await frame.locator('#wt-screen').selectOption(s);const r=await frame.locator('#wt-phone').evaluate(el=>({screen:document.getElementById('wt-screen').value,width:el.clientWidth,scroll:el.scrollWidth}));if(r.scroll>r.width+2)overflows.push({large:true,...r});}
await frame.locator('#wt-screen').selectOption('settings');
await frame.getByRole('button',{name:'Larger text preview On'}).click();
await page.emulateMedia({colorScheme:'light'});
await frame.locator('#wt-screen').selectOption('home');
await frame.locator('#wt-phone').screenshot({path:'/tmp/wt-design-browser/home-light.png'});
fs.writeFileSync('/tmp/wt-design-browser/results.json',JSON.stringify({screens:options.length,errors,overflows,interactions:'set completion, explicit add, rest, AI session count, save receipt, large text'},null,2));
console.log(JSON.stringify({screens:options.length,errors,overflows}));
await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
