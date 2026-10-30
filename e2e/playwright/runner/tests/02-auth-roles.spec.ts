import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,logout,runtimeErrors,attachState} from '../support/ui';
for(const [index,account] of accounts.entries()){
 test(`PW-AUTH-0${index+1}: ${account.key} signs in, reaches its role and signs out`,async({page},info)=>{
  const errors=runtimeErrors(page);
  await test.step(`Sign in as ${account.key} and verify identity/role`,()=>login(page,account));
  await attachState(page,info,'role-screen');
  await test.step('Sign out and return to the login form',()=>logout(page));
  expect(errors,'Flutter/browser runtime errors').toEqual([]);
 });
}
