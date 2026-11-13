import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';

const generated=/^e2e_[a-z0-9_]+@example\.(?:com|test)$/i;
const oldTitle=/^E2E_(?:ANDROID_|PW_|API_|\d{13}_|\d{8}T)/;
const runPrefix=/^E2E_(?:ANDROID|PW)_\d{8}_[a-f0-9]{6,}(?:_[a-z]+)?_?$/;
const tableOrder=['dispute_photos','dispute_timeline','disputes','shipment_events','shipments','warehouse_receipts','orders','flag_evidence','flagged_auctions','bids','auction_deposits','wallet_transactions','notifications','appraisals','listing_photos','auctions','listings','chat_messages','chat_sessions','addresses','bidders','sellers','accounts','ops_accounts'];
const idCol=t=>['bidders','sellers'].includes(t)?'account_id':'id';
const list=rows=>rows.map(r=>String(r.id));
const unique=items=>[...new Set(items.map(String))].sort((a,b)=>Number(a)-Number(b));
const digest=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
export function matchesRunTitle(title,prefix){return runPrefix.test(prefix)&&(title===prefix||title.startsWith(prefix.endsWith('_')?prefix:prefix+'_'));}
export function validateScope(scope){
 if(!['legacy','run'].includes(scope?.mode))throw Error('Explicit cleanup mode required');
 if(scope.mode==='legacy'){if(!scope.cutoff||Date.parse(scope.cutoff)>Date.now()-86400000)throw Error('Historical cleanup excludes the most recent 24 hours');}
 else{if(!scope.prefixes?.length||scope.prefixes.some(p=>!runPrefix.test(p)))throw Error('Cleanup requires complete random per-run prefixes');if(!scope.startedAt||!Number.isFinite(Date.parse(scope.startedAt)))throw Error('Run creation time required');}
}
export async function planCleanup(db,scope){
 validateScope(scope);const read=async(sql,args=[])=> (await db.query(sql,args)).rows;
 const listings=await read('SELECT id,title,seller_id,created_at FROM listings ORDER BY id');
 const accounts=await read('SELECT id,email,full_name,created_at FROM accounts ORDER BY id');
 const ops=await read('SELECT id,email,name FROM ops_accounts ORDER BY id');
 const cutoff=Date.parse(scope.cutoff),start=Date.parse(scope.startedAt||'1970-01-01')-60000;
 const protectedEmails=new Set((scope.protectedEmails||[]).map(e=>e.toLowerCase()));
 const ownedEmails=new Set((scope.accountEmails||[]).map(e=>e.toLowerCase()));
 const ownedIds=new Set((scope.accountIds||[]).map(String));const ownedOps=new Set((scope.opsIds||[]).map(String));const ownedOpsEmails=new Set((scope.opsEmails||[]).map(e=>e.toLowerCase()));
 const targetL=listings.filter(l=>scope.mode==='legacy'?oldTitle.test(l.title)&&new Date(l.created_at).getTime()<cutoff:scope.prefixes.some(p=>matchesRunTitle(l.title,p))&&new Date(l.created_at).getTime()>=start);
 const listingIds=list(targetL);const auctionIds=list(await read('SELECT id FROM auctions WHERE listing_id=ANY($1::bigint[]) ORDER BY id',[listingIds]));
 const orderIds=list(await read('SELECT id FROM orders WHERE auction_id=ANY($1::bigint[]) ORDER BY id',[auctionIds]));
 const externalAccounts=new Set((await read(`SELECT seller_id AS id FROM listings WHERE NOT(id=ANY($1::bigint[])) UNION SELECT bidder_id FROM bids WHERE NOT(auction_id=ANY($2::bigint[])) UNION SELECT bidder_id FROM auction_deposits WHERE NOT(auction_id=ANY($2::bigint[])) UNION SELECT winner_id FROM auctions WHERE winner_id IS NOT NULL AND NOT(id=ANY($2::bigint[])) UNION SELECT bidder_id FROM orders WHERE NOT(id=ANY($3::bigint[])) UNION SELECT seller_id FROM orders WHERE NOT(id=ANY($3::bigint[])) UNION SELECT reporter_id FROM disputes WHERE NOT(order_id=ANY($3::bigint[])) UNION SELECT a.account_id FROM addresses a JOIN orders o ON o.shipping_address_id=a.id WHERE NOT(o.id=ANY($3::bigint[]))`,[listingIds,auctionIds,orderIds])).map(r=>String(r.id)));
 const externalOps=new Set((await read(`SELECT appraiser_id AS id FROM appraisals WHERE appraiser_id IS NOT NULL AND NOT(listing_id=ANY($1::bigint[])) UNION SELECT resolved_by FROM disputes WHERE resolved_by IS NOT NULL AND NOT(order_id=ANY($2::bigint[])) UNION SELECT inspected_by FROM warehouse_receipts WHERE inspected_by IS NOT NULL AND NOT(order_id=ANY($2::bigint[]))`,[listingIds,orderIds])).map(r=>String(r.id)));
 const candidateA=accounts.filter(a=>generated.test(a.email)&&!protectedEmails.has(a.email.toLowerCase())&&(scope.mode==='legacy'?new Date(a.created_at).getTime()<cutoff:(ownedIds.has(String(a.id))||ownedEmails.has(a.email.toLowerCase()))&&new Date(a.created_at).getTime()>=start));
 const accountIds=list(candidateA.filter(a=>!externalAccounts.has(String(a.id))));
 const candidateOps=ops.filter(a=>generated.test(a.email)&&/^E2E\b/i.test(a.name)&&!protectedEmails.has(a.email.toLowerCase())&&(scope.mode==='legacy'?/_(\d{13})@/.test(a.email)&&Number(a.email.match(/_(\d{13})@/)[1])<cutoff:(ownedOps.has(String(a.id))||ownedOpsEmails.has(a.email.toLowerCase()))));
 const opsIds=list(candidateOps.filter(a=>!externalOps.has(String(a.id))));
 const disputeIds=list(await read('SELECT id FROM disputes WHERE order_id=ANY($1::bigint[]) ORDER BY id',[orderIds]));
 const flagIds=list(await read('SELECT id FROM flagged_auctions WHERE auction_id=ANY($1::bigint[]) ORDER BY id',[auctionIds]));
 const shipmentIds=list(await read('SELECT id FROM shipments WHERE order_id=ANY($1::bigint[]) ORDER BY id',[orderIds]));
 const sessionIds=list(await read('SELECT id FROM chat_sessions WHERE account_id=ANY($1::bigint[]) ORDER BY id',[accountIds]));
 const selectors={
  accounts:['id',accountIds],bidders:['account_id',accountIds],sellers:['account_id',accountIds],ops_accounts:['id',opsIds],addresses:['account_id',accountIds],chat_sessions:['id',sessionIds],chat_messages:['session_id',sessionIds],listings:['id',listingIds],listing_photos:['listing_id',listingIds],appraisals:['listing_id',listingIds],auctions:['id',auctionIds],bids:['auction_id',auctionIds],auction_deposits:['auction_id',auctionIds],orders:['id',orderIds],disputes:['id',disputeIds],dispute_timeline:['dispute_id',disputeIds],dispute_photos:['dispute_id',disputeIds],flagged_auctions:['id',flagIds],flag_evidence:['flagged_auction_id',flagIds],warehouse_receipts:['order_id',orderIds],shipments:['id',shipmentIds],shipment_events:['shipment_id',shipmentIds],wallet_transactions:['bidder_id',accountIds]
 };
 const rows={};for(const [table,[column,ids]]of Object.entries(selectors)){rows[table]=await read(`SELECT * FROM "${table}" WHERE "${column}"=ANY($1::bigint[]) ORDER BY "${idCol(table)}"`,[ids]);}
 rows.notifications=await read(`SELECT * FROM notifications WHERE account_id=ANY($1::bigint[]) OR data->>'auctionId'=ANY($2::text[]) OR data->>'listingId'=ANY($3::text[]) OR data->>'orderId'=ANY($4::text[]) OR data->>'disputeId'=ANY($5::text[]) ORDER BY id`,[accountIds,auctionIds,listingIds,orderIds,disputeIds]);
 const preservedLedger=await read(`SELECT * FROM wallet_transactions WHERE related_auction_id=ANY($1::bigint[]) AND NOT(bidder_id=ANY($2::bigint[])) ORDER BY id`,[auctionIds,accountIds]);
 const releaseDeposits=await read(`SELECT d.* FROM auction_deposits d WHERE d.auction_id=ANY($1::bigint[]) AND NOT(d.bidder_id=ANY($2::bigint[])) AND (d.status='held' OR (d.status='applied_to_payment' AND NOT EXISTS(SELECT 1 FROM orders o WHERE o.auction_id=d.auction_id AND o.bidder_id=d.bidder_id AND o.payment_status='paid'))) ORDER BY d.id`,[auctionIds,accountIds]);
 const protectedWallets=await read('SELECT * FROM bidders WHERE account_id=ANY($1::bigint[]) ORDER BY account_id',[unique(releaseDeposits.map(d=>d.bidder_id))]);
 const ids={listingIds,auctionIds,orderIds,accountIds,opsIds,disputeIds};
 const summary={mode:scope.mode,counts:Object.fromEntries(tableOrder.map(t=>[t,rows[t].length])),preservedLedgerRows:preservedLedger.length,releaseHeldDeposits:releaseDeposits.map(d=>({depositId:String(d.id),bidderId:String(d.bidder_id),amount:Number(d.amount)})),protectedAccounts:accounts.filter(a=>protectedEmails.has(a.email.toLowerCase())).map(a=>String(a.id)),excludedAccountsWithOtherData:list(candidateA.filter(a=>externalAccounts.has(String(a.id)))),excludedOpsWithOtherData:list(candidateOps.filter(a=>externalOps.has(String(a.id)))),storageFiles:'Retained; object-storage deletion is not part of SQL cleanup'};
 const backup={scope,ids,rows,preservedLedger,releaseDeposits,protectedWallets};const fingerprint=digest(backup);
 return{...backup,fingerprint,summary};
}
export async function applyCleanup({pool,walletService,scope,expectedFingerprint,backupDirectory,dryRun=false}){
 if(!backupDirectory)throw Error('Private backup directory required before deletion');
 fs.mkdirSync(backupDirectory,{recursive:true});const client=await pool.connect();let plan,backupFile;
 try{
  await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ');await client.query("SET LOCAL lock_timeout='5s'");await client.query("SET LOCAL statement_timeout='60s'");
  plan=await planCleanup(client,scope);if(expectedFingerprint&&plan.fingerprint!==expectedFingerprint)throw Error('Cleanup data changed since review; regenerate the plan');
  for(const table of ['accounts','ops_accounts','listings','auctions','orders']){const ids=plan.rows[table].map(r=>r.id);await client.query(`SELECT id FROM "${table}" WHERE id=ANY($1::bigint[]) ORDER BY id FOR UPDATE`,[ids]);}
  backupFile=path.join(backupDirectory,new Date().toISOString().replace(/[:.]/g,'-')+'-'+plan.fingerprint.slice(0,12)+'.private.json');fs.writeFileSync(backupFile,JSON.stringify({savedAt:new Date().toISOString(),...plan},null,2),{flag:'wx'});
  // Only release unconsumed holds for accounts that will be retained. Paid
  // deposits are already consumed by payment and must never be refunded twice.
  for(const d of plan.releaseDeposits){await walletService.releaseDeposit(client,{bidderId:String(d.bidder_id),auctionId:String(d.auction_id),amount:Number(d.amount)});await client.query("UPDATE auction_deposits SET status='released' WHERE id=$1 AND status=$2",[d.id,d.status]);}
  const auctionIds=plan.ids.auctionIds,accountIds=plan.ids.accountIds;
  const detached=await client.query('UPDATE wallet_transactions SET related_auction_id=NULL WHERE related_auction_id=ANY($1::bigint[]) AND NOT(bidder_id=ANY($2::bigint[]))',[auctionIds,accountIds]);
  const deleted={};for(const table of tableOrder){const ids=plan.rows[table].map(r=>String(r[idCol(table)]));const result=await client.query(`DELETE FROM "${table}" WHERE "${idCol(table)}"=ANY($1::bigint[])`,[ids]);deleted[table]=result.rowCount;if(result.rowCount!==ids.length)throw Error('Delete count changed for '+table);}
  for(const table of ['listings','auctions','orders','accounts','ops_accounts']){const ids=plan.rows[table].map(r=>r.id);const {rows}=await client.query(`SELECT count(*)::int AS n FROM "${table}" WHERE id=ANY($1::bigint[])`,[ids]);if(rows[0].n!==0)throw Error('Post-delete verification failed for '+table);}
  await client.query(dryRun?'ROLLBACK':'COMMIT');return{status:dryRun?'DRY_RUN':'PASS',completedAt:new Date().toISOString(),fingerprint:plan.fingerprint,deleted,preservedLedgerRows:plan.preservedLedger.length,detachedLedgerRows:detached.rowCount,releasedHeldDeposits:plan.summary.releaseHeldDeposits,excludedAccountsWithOtherData:plan.summary.excludedAccountsWithOtherData,excludedOpsWithOtherData:plan.summary.excludedOpsWithOtherData,backupFile,storageFiles:'Retained'};
 }catch(error){try{await client.query('ROLLBACK');}catch{}throw Object.assign(error,{cleanupRolledBack:true,backupFile});}finally{client.release();}
}
