import crypto from 'node:crypto';
import {backendServices} from './fixtures.mjs';

// One bridge instance per run. Browser mutations and time control only accept
// objects registered here, not arbitrary client-supplied account/order IDs.
export class ConnectedBridge {
 constructor({fixtures,actor,expect,screenshot}){Object.assign(this,{fixtures,actor,expect,screenshot});this.people=new Map();this.branches=new Map();this.started=Date.now();}
 async requestNegative(endpoint,{token,body,method='POST',status,code}){
  const r=await fetch(this.fixtures.api+endpoint,{method,headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});
  const b=await r.json();this.expect(r.status).toBe(status);this.expect(b.success).toBe(false);this.expect(b.error.code).toBe(code);return{classification:'API rejection assertion',endpoint,httpStatus:r.status,code:b.error.code};
 }
 public(f){return{title:f.title,listingId:f.listingId,auctionId:f.auctionId,orderId:f.orderId,disputeId:f.disputeId,escrowAmount:f.escrowAmount};}
 async registerBuyer(input){
  const data=await this.fixtures.request('/api/me',{token:input.token});
  const account=data.account||data;this.expect(String(account.email).toLowerCase()).toBe(String(input.email).toLowerCase());
  const {rows}=await backendServices(this.fixtures.config.backendRoot).pool.query('SELECT id,email,created_at FROM accounts WHERE id=$1',[account.id]);
  const r=rows[0];if(!r||new Date(r.created_at).getTime()<this.started-60000||!String(r.email).startsWith('e2e_android_'))throw Error('Refusing account not created for this Android run');
  this.fixtures.secrets.add(input.email);this.fixtures.secrets.add(input.token);
  const person={id:String(account.id),email:input.email,token:input.token};this.people.set('buyer',person);return person;
 }
 async search(person){const a=await this.actor();await a.tab('Người dùng','/api/admin/accounts');await a.page.getByRole('textbox',{name:'Tìm người dùng',exact:true}).fill(person.email);await a.page.getByRole('button',{name:'Tìm',exact:true}).click();await this.expect(a.page.getByRole('button',{name:'Làm mới',exact:true})).toBeEnabled();const d=await a.response('/api/admin/accounts',()=>a.page.getByRole('button',{name:'Làm mới',exact:true}).click(),{query:{q:person.email}});const item=d.accounts.find(x=>String(x.id)===person.id);this.expect(item).toBeTruthy();const row=await a.ownRow({title:person.email});await this.expect(row).toContainText(person.email);return{accountId:person.id,status:item.status};}
 async status(person,suspended){const a=await this.actor();await this.search(person);const row=await a.ownRow({title:person.email});await row.getByRole('button',{name:suspended?'Tạm khóa':'Mở khóa',exact:true}).click();const d=await a.response('/api/admin/accounts/'+person.id,()=>a.page.getByRole('dialog').getByRole('button',{name:suspended?'Xác nhận tạm khóa':'Xác nhận mở khóa',exact:true}).click(),{method:'PATCH'});this.expect(d.status).toBe(suspended?'suspended':'active');await this.expect(a.page.getByRole('dialog')).toHaveCount(0);return{accountId:person.id,status:d.status};}
 async branch(kind){
  if(this.branches.has(kind))return this.branches.get(kind);
  if(!['refund','keep','terminate','poor','payment'].includes(kind))throw Error('Unknown connected branch');
  const f=await this.fixtures.auction('connected_'+kind);const buyer=await this.fixtures.freshBidder();f.buyer=buyer;
  if(kind!=='poor'){
   await this.fixtures.request('/api/wallet/topup',{token:buyer.token,method:'POST',body:{amount:kind==='payment'?1000:100000}});
   await this.fixtures.request(`/api/auctions/${f.auctionId}/join`,{token:buyer.token,method:'POST',status:201});
   const d=await this.fixtures.request('/api/auctions/'+f.auctionId,{token:buyer.token});await this.fixtures.request('/api/bids',{token:buyer.token,method:'POST',body:{auctionId:f.auctionId,amount:d.minNextBid},status:201});
   if(kind==='terminate'){await this.fixtures.request(`/api/auctions/${f.auctionId}/report`,{token:buyer.token,method:'POST',status:201,body:{reason:'Connected Android to React Admin E2E'}});}
   else{
    await this.fixtures.closeAuction(f);const d=await this.fixtures.request('/api/orders/mine',{token:buyer.token});const o=d.orders.find(o=>String(o.auctionId)===f.auctionId);this.expect(o).toBeTruthy();f.orderId=String(o.id);this.fixtures.orders.add(f.orderId);
    if(kind!=='payment'){
     const address=await this.fixtures.request('/api/addresses',{token:buyer.token,method:'POST',status:201,body:{recipientName:'E2E Connected Buyer',phone:'0900000000',city:'Ho Chi Minh',addressLine:'E2E test only - Connected branch'}});
     await this.fixtures.request(`/api/orders/${f.orderId}/shipping-address`,{token:buyer.token,method:'POST',body:{addressId:String(address.id)}});
     await this.fixtures.request(`/api/orders/${f.orderId}/pay`,{token:buyer.token,method:'POST',body:{method:'qr'}});
    }
   }
  }
  this.branches.set(kind,f);return f;
 }
 async flag(f,action,{blankReason=false}={}){
  const a=await this.actor();await a.tab('Phiên nghi vấn','/api/admin/flags');const flag=await this.fixtures.findFlag(f.auctionId,'Connected Android to React Admin E2E');await a.filter('/api/admin/flags',flag.status);f.flagId=String(flag.id);const row=await a.ownRow({type:'flag',id:f.flagId,title:f.title});await row.getByRole('button',{name:'Xem & xử lý',exact:true}).click();
  const labels={pause:'Tạm dừng phiên',verify:'Yêu cầu xác minh',safe:'Đánh dấu an toàn',terminate:'Chấm dứt phiên'};await a.page.getByRole('dialog').getByRole('button',{name:labels[action],exact:true}).click();const dialog=a.page.getByRole('dialog');
  if(blankReason){const sent=[];const capture=r=>{if(r.method()==='POST'&&new URL(r.url()).pathname===`/api/admin/flags/${f.flagId}/action`)sent.push(r.url());};a.page.on('request',capture);try{await dialog.getByRole('button',{name:'Xác nhận chấm dứt phiên',exact:true}).click();this.expect(await dialog.getByLabel('Lý do (bắt buộc)',{exact:true}).evaluate(el=>el.validity.valueMissing)).toBe(true);this.expect(sent).toHaveLength(0);await this.expect(dialog).toBeVisible();await dialog.getByRole('button',{name:'Hủy',exact:true}).click();}finally{a.page.off('request',capture);}return{auctionId:f.auctionId,classification:'Web UI form prevention; no mutation sent'};}
  if(action==='terminate')await dialog.getByLabel('Lý do (bắt buộc)',{exact:true}).fill('E2E owned connected fixture termination');
  const data=await a.response(`/api/admin/flags/${f.flagId}/action`,()=>dialog.getByRole('button',{name:'Xác nhận '+labels[action].toLowerCase(),exact:true}).click(),{method:'POST'});this.expect(data.status).toBe({pause:'paused',verify:'verify',safe:'safe',terminate:'terminated'}[action]);await this.expect(dialog).toHaveCount(0);return{auctionId:f.auctionId,flagId:f.flagId,status:data.status};
 }
 async dispute(f,input){const list=await this.fixtures.request('/api/disputes/mine',{token:f.buyer.token});const d=list.disputes.find(d=>String(d.id)===String(input.disputeId)&&String(d.orderId)===f.orderId);if(!d)throw Error('Dispute does not belong to this branch');f.disputeId=String(d.id);f.escrowAmount=Number(d.escrowAmount);return f;}
 async execute(input){
  const a=await this.actor();const trace=[];const observe=r=>{const u=new URL(r.url());if(u.origin===new URL(this.fixtures.api).origin)trace.push({method:r.request().method(),path:u.pathname,status:r.status()});};a.page?.on('response',observe);
  try{return await this.command(input);}catch(error){
   try{const diagnostics=await a.page.locator('form').evaluateAll(forms=>forms.map(form=>({valid:form.checkValidity(),invalid:[...form.elements].filter(e=>e.validity&&!e.validity.valid).map(e=>({name:e.name,type:e.type,message:e.validationMessage})),alerts:[...form.querySelectorAll('[role=alert]')].map(e=>e.textContent)})));const shot=await this.screenshot(a,input.caseId+'-error');error.message+='; webDiagnostics='+JSON.stringify({trace,forms:diagnostics,screenshot:shot});for(let n=0;n<2&&await a.page.getByRole('dialog').count();n++)await a.page.keyboard.press('Escape');}catch{}
   throw error;
  }finally{a.page?.off('response',observe);}
 }
 async command(input){
  const a=await this.actor();let result;
  if(input.op==='register-buyer'){const person=await this.registerBuyer(input);result=await this.search(person);}
  else if(input.op==='search-buyer'||input.op==='suspend-buyer'||input.op==='activate-buyer'){
   const p=this.people.get('buyer');if(!p)throw Error('Buyer not registered');result=input.op==='search-buyer'?await this.search(p):await this.status(p,input.op==='suspend-buyer');
  }else if(input.op==='overview'){
   const data=await a.tab('Tổng quan','/api/admin/dashboard');this.expect(data.orders).toBeTruthy();await this.expect(a.page.getByRole('heading',{name:'Tổng quan.',exact:true})).toBeVisible();result={classification:'React UI reads current dashboard API snapshot; no exclusive shared-database delta assumption',orders:data.orders};
  }else if(input.op==='main-flag-read'){
   const f=this.fixtures.auctions.get(String(input.auctionId));if(!f||f.title!==input.title)throw Error('Unknown main fixture');const item=await this.fixtures.findFlag(f.auctionId,'Connected Android to React Admin E2E');await a.tab('Phiên nghi vấn','/api/admin/flags');await a.filter('/api/admin/flags',item.status);await a.ownRow({type:'flag',id:String(item.id),title:f.title});result={auctionId:f.auctionId,flagId:String(item.id),status:item.status};
  }else if(input.op==='main-flag'){
   const f=this.fixtures.auctions.get(String(input.auctionId));if(!f||f.title!==input.title)throw Error('Unknown registered main fixture');if(!['pause','verify','safe'].includes(input.action))throw Error('Unknown flag action');result=await this.flag(f,input.action);
  }else if(input.op==='setup'){
   const f=await this.branch(input.kind);return{fixture:{...this.public(f),buyer:{email:f.buyer.email,password:f.buyer.password}},classification:'API fixture setup, not Android UI listing/appraisal/payment coverage'};
  }else if(input.op==='setup-restricted'){
   if(!this.restricted)this.restricted=await this.fixtures.restrictedBidder();const r=this.restricted;this.people.set('restricted',r.account);return{account:{email:r.account.email,password:r.account.password},evidence:r.evidence};
  }else if(input.op==='search-restricted'){if(!this.people.has('restricted'))throw Error('Restricted fixture missing');result=await this.search(this.people.get('restricted'));
  }else if(input.op==='create-ops'){
   if(this.ops)throw Error('Ops fixture already created');const email='e2e_connected_ops_'+Date.now()+'@example.com',password='Ops_'+crypto.randomBytes(12).toString('hex')+'!';this.fixtures.secrets.add(email);this.fixtures.secrets.add(password);this.fixtures.opsEmails.add(email);this.fixtures.persistScope?.();
   await a.tab('Tài khoản nội bộ','/api/admin/ops-accounts');await a.page.getByRole('button',{name:'Thêm nhân sự',exact:true}).click();const d=a.page.getByRole('dialog');await d.getByLabel('Họ tên',{exact:true}).fill('E2E Connected Appraiser');await d.getByLabel('Email',{exact:true}).fill(email);await d.getByRole('combobox',{name:/^Vai trò/}).selectOption('appraiser');await d.getByLabel(/^Mật khẩu khởi tạo/).fill(password);const account=await a.response('/api/admin/ops-accounts',()=>d.getByRole('button',{name:'Tạo tài khoản',exact:true}).click(),{method:'POST',status:201});this.expect(account.role).toBe('appraiser');this.ops={id:String(account.id),email,password};this.fixtures.createdOps.add(this.ops.id);this.fixtures.persistScope?.();return{completed:true,account:{email,password},opsId:this.ops.id,role:account.role,webScreenshot:await this.screenshot(a,input.caseId)};
  }else if(input.op==='suspend-ops'){
   if(!this.ops)throw Error('Owned ops missing');await a.tab('Tài khoản nội bộ','/api/admin/ops-accounts');const row=await a.ownRow({title:this.ops.email});await row.getByRole('button',{name:'Chỉnh sửa',exact:true}).click();const d=a.page.getByRole('dialog');await d.getByLabel('Họ tên',{exact:true}).fill('E2E Connected Appraiser Edited');await d.getByRole('combobox',{name:/^Trạng thái/}).selectOption('suspended');const out=await a.response('/api/admin/ops-accounts/'+this.ops.id,()=>d.getByRole('button',{name:'Lưu thay đổi',exact:true}).click(),{method:'PATCH'});this.expect(out.status).toBe('suspended');this.expect(out.name).toBe('E2E Connected Appraiser Edited');await this.expect(d).toHaveCount(0);result={opsId:this.ops.id,status:out.status};
  }else{
   const f=this.branches.get(input.kind);if(!f)throw Error('Owned branch missing');
   if(input.op==='term-invalid'||input.op==='terminate')result=await this.flag(f,'terminate',{blankReason:input.op==='term-invalid'});
   else if(input.op==='inspect-dispute'){await this.dispute(f,input);await a.tab('Tranh chấp','/api/admin/disputes');await a.filter('/api/admin/disputes','open');await a.ownRow({type:'dispute',id:f.orderId,title:f.title});result=this.public(f);}
   else if(input.op==='resolve'){await this.dispute(f,input);if(!['refund','keep'].includes(input.resolution))throw Error('Invalid resolution');const before=await this.fixtures.request('/api/wallet',{token:f.buyer.token});const out=await a.resolve(f,input.resolution);const after=await this.fixtures.request('/api/wallet',{token:f.buyer.token});this.expect(after.balance-before.balance).toBe(input.resolution==='refund'?f.escrowAmount:0);f.resolution=input.resolution;f.afterBalance=after.balance;result={...out,escrowAmount:f.escrowAmount,walletCredit:after.balance-before.balance};}
   else if(input.op==='repeat-resolve'){if(!f.disputeId||!f.resolution)throw Error('Resolution missing');const admin=await this.fixtures.login('admin');const before=await this.fixtures.request('/api/wallet',{token:f.buyer.token});const rejected=await this.requestNegative('/api/admin/disputes/'+f.disputeId+'/resolve',{token:admin.token,body:{resolution:f.resolution},status:409,code:'ALREADY_RESOLVED'});const after=await this.fixtures.request('/api/wallet',{token:f.buyer.token});this.expect(after.balance).toBe(before.balance);result={...rejected,...this.public(f),walletUnchanged:true};}
   else if(input.op==='expire-payment'){if(input.kind!=='payment')throw Error('Expiry only for payment fixture');await backendServices(this.fixtures.config.backendRoot).dev.expireOrderPayment({orderId:f.orderId});const end=Date.now()+90000;let data;while(Date.now()<end){data=await this.fixtures.request('/api/orders/'+f.orderId,{token:f.buyer.token});if(data.paymentStatus==='expired')break;await new Promise(r=>setTimeout(r,1000));}this.expect(data.paymentStatus).toBe('expired');result={...this.public(f),paymentStatus:data.paymentStatus,classification:'Owned deadline control plus normal Render scheduler'};}
   else throw Error('Unknown connected command');
  }
  const screenshot=await this.screenshot(a,input.caseId);return{completed:true,...result,...(screenshot?{webScreenshot:screenshot}:{})};
 }
}
