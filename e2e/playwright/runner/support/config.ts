import fs from 'node:fs';
import path from 'node:path';

export const credentialsPath=path.resolve(process.env.BIDVIBE_CREDENTIALS_FILE || 'credentials.local.json');
export const credentials: Record<string,string|boolean>=JSON.parse(fs.readFileSync(credentialsPath,'utf8'));
export const apiURL=String(process.env.BIDVIBE_API_URL || credentials.BIDVIBE_API_BASE_URL).replace(/\/+$/,'');
export const roles=[
 {key:'BIDDER_A',role:'bidder',home:'Khám phá phiên đấu giá'},
 {key:'BIDDER_B',role:'bidder',home:'Khám phá phiên đấu giá'},
 {key:'SELLER',role:'seller',home:'Phiên của tôi'},
 {key:'APPRAISER',role:'appraiser',home:'Hàng chờ'},
 {key:'WAREHOUSE',role:'warehouse',home:'Đơn hàng trong kho'},
 {key:'ADMIN',role:'admin',home:'Tổng quan'},
] as const;
export type Account={key:string;role:string;email:string;password:string;home:string};
export const accounts:Account[]=roles.map(r=>({...r,email:String(credentials[`E2E_${r.key}_EMAIL`]||''),password:String(credentials[`E2E_${r.key}_PASSWORD`]||'')}));

