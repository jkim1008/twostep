/**
 * Security-rules tests for the deny-all baseline.
 *
 * The contract under test: NO client — anonymous or authenticated — can read
 * or write ANY document. M1 replaces the rules with membership-scoped access,
 * and replaces/extends these tests in the same PR. A rules change without a
 * matching test change should fail review.
 */
import { describe, it, beforeAll, afterAll } from 'vitest';
import {
  initializeTestEnvironment,
  assertFails,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { doc, getDoc, setDoc, collection, getDocs } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-twostep-rules',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080, // pinned in firebase.json
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

const PATHS = [
  'households/h1',
  'households/h1/transactions/t1',
  'households/h1/members/u1',
  'users/u1',
  'invites/CODE123',
  'plaidTokens/item1',
  'arbitrary/doc',
];

describe('deny-all baseline', () => {
  it('denies every read and write to an unauthenticated client', async () => {
    const db = env.unauthenticatedContext().firestore();
    for (const path of PATHS) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { probe: true }));
    }
  });

  it('denies every read and write to an authenticated client', async () => {
    const db = env.authenticatedContext('user-abc').firestore();
    for (const path of PATHS) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { probe: true }));
    }
  });

  it('denies collection queries to authenticated clients', async () => {
    const db = env.authenticatedContext('user-abc').firestore();
    await assertFails(getDocs(collection(db, 'households')));
    await assertFails(getDocs(collection(db, 'plaidTokens')));
  });
});
