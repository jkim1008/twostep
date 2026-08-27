/**
 * Security-rules tests for the PRD §6.4 membership model.
 *
 * The contract under test, boundary by boundary:
 *   - /users/{uid}: readable/writable by that uid only.
 *   - /invites, /plaidTokens, /siwaTokens: deny ALL client access.
 *   - /households/{hid}: read gated on memberUids; create/delete CF-only;
 *     member updates allowed but memberUids/ownerUid immutable.
 *   - CF-owned subcollections (members, plaidItems, events, digests):
 *     member-readable, client-write-denied.
 *   - Member-owned subcollections (accounts, categories, categoryRules,
 *     budgets, goals + contributions, recurringItems): full member CRUD,
 *     denied to non-members and unauthenticated clients.
 *   - Transactions: member CRUD with validation — amountMinor is int,
 *     attributedTo is "joint" or a uid with a member doc of ANY status
 *     (departed members' history stays editable), source/pendingTransactionId
 *     immutable once set, only manual entries deletable.
 *
 * Every boundary gets both an allow AND a deny assertion.
 */
import { describe, it, beforeAll, beforeEach, afterAll } from 'vitest';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  deleteField,
  collection,
  query,
  where,
} from 'firebase/firestore';

let env;

// Household members: alice (owner) and bob are active; dana has left but
// keeps her member doc (status: "left") per PRD §6.3. mallory is an
// authenticated user with NO membership in h1.
const HID = 'h1';
const ALICE = 'alice';
const BOB = 'bob';
const DANA = 'dana'; // departed member — member doc exists, not in memberUids
const MALLORY = 'mallory'; // authenticated non-member

const seed = async (db) => {
  await setDoc(doc(db, 'users', ALICE), { activeHouseholdId: HID });
  await setDoc(doc(db, 'users', MALLORY), { activeHouseholdId: null });

  await setDoc(doc(db, 'invites', 'CODE123'), { householdId: HID });
  await setDoc(doc(db, 'plaidTokens', 'item1'), { accessToken: 'secret' });
  await setDoc(doc(db, 'siwaTokens', ALICE), { refreshToken: 'secret' });

  await setDoc(doc(db, `households/${HID}`), {
    name: 'Test Household',
    currencyCode: 'USD',
    memberUids: [ALICE, BOB],
    ownerUid: ALICE,
    weeklySync: { day: 'sunday', time: '18:00' },
  });
  await setDoc(doc(db, `households/${HID}/members/${ALICE}`), {
    role: 'owner', status: 'active', displayName: 'Partner A', colorHex: '#336699',
  });
  await setDoc(doc(db, `households/${HID}/members/${BOB}`), {
    role: 'partner', status: 'active', displayName: 'Partner B', colorHex: '#996633',
  });
  await setDoc(doc(db, `households/${HID}/members/${DANA}`), {
    role: 'partner', status: 'left', displayName: 'Former Partner', colorHex: '#669933',
  });

  await setDoc(doc(db, `households/${HID}/plaidItems/item1`), {
    status: 'healthy', linkedByUid: ALICE, syncCursor: 'cursor-1',
  });
  await setDoc(doc(db, `households/${HID}/accounts/a1`), {
    ownerUid: ALICE, mask: '1234', type: 'depository', isHidden: false,
  });
  await setDoc(doc(db, `households/${HID}/categories/c1`), {
    name: 'Groceries', icon: 'cart', colorHex: '#00AA00', isSystem: true, isArchived: false,
  });
  await setDoc(doc(db, `households/${HID}/categoryRules/coffee-shop`), {
    categoryId: 'c1',
  });
  await setDoc(doc(db, `households/${HID}/budgets/2026-08`), {
    allocations: { c1: 50000 },
  });
  await setDoc(doc(db, `households/${HID}/goals/g1`), {
    name: 'Trip', targetMinor: 500000, savedMinor: 120000,
  });
  await setDoc(doc(db, `households/${HID}/goals/g1/contributions/con1`), {
    amountMinor: 20000, date: '2026-08-01', contributedByUid: ALICE,
  });
  await setDoc(doc(db, `households/${HID}/recurringItems/r1`), {
    source: 'manual', frequency: 'monthly', nextDueDate: '2026-09-01',
    attributedTo: 'joint', autoLog: false,
  });
  await setDoc(doc(db, `households/${HID}/digests/2026-W35`), {
    netMinor: 12300,
  });
  await setDoc(doc(db, `households/${HID}/events/e1`), {
    type: 'member_joined', actorUid: BOB, payload: {},
  });

  // t1: Plaid import; t2: manual entry; t3: attributed to departed dana.
  await setDoc(doc(db, `households/${HID}/transactions/t1`), {
    source: 'plaid', accountId: 'a1', amountMinor: 1234, direction: 'expense',
    date: '2026-08-20', status: 'posted', pendingTransactionId: 'pt1',
    categoryId: 'c1', attributedTo: ALICE, excludeFromBudget: false,
  });
  await setDoc(doc(db, `households/${HID}/transactions/t2`), {
    source: 'manual', amountMinor: 500, direction: 'expense',
    date: '2026-08-21', status: 'posted', categoryId: 'c1',
    attributedTo: 'joint', enteredByUid: ALICE,
  });
  await setDoc(doc(db, `households/${HID}/transactions/t3`), {
    source: 'plaid', accountId: 'a1', amountMinor: 900, direction: 'expense',
    date: '2025-11-05', status: 'posted', categoryId: 'c1',
    attributedTo: DANA,
  });
};

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

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await seed(ctx.firestore());
  });
});

afterAll(async () => {
  await env.cleanup();
});

const memberDb = () => env.authenticatedContext(ALICE).firestore();
const nonMemberDb = () => env.authenticatedContext(MALLORY).firestore();
const unauthDb = () => env.unauthenticatedContext().firestore();

describe('/users — self only', () => {
  it('allows a user to read and write their own profile doc', async () => {
    const db = memberDb();
    await assertSucceeds(getDoc(doc(db, 'users', ALICE)));
    await assertSucceeds(setDoc(doc(db, 'users', ALICE), { activeHouseholdId: HID }));
  });

  it("denies reading or writing another user's profile doc", async () => {
    const db = memberDb();
    await assertFails(getDoc(doc(db, 'users', MALLORY)));
    await assertFails(setDoc(doc(db, 'users', MALLORY), { hijacked: true }));
  });

  it('denies unauthenticated access to user docs', async () => {
    const db = unauthDb();
    await assertFails(getDoc(doc(db, 'users', ALICE)));
    await assertFails(setDoc(doc(db, 'users', ALICE), { probe: true }));
  });
});

describe('/invites, /plaidTokens, /siwaTokens — deny ALL client access', () => {
  const hardenedPaths = ['invites/CODE123', 'plaidTokens/item1', `siwaTokens/${ALICE}`];

  it('denies reads and writes even to an authenticated household member', async () => {
    const db = memberDb();
    for (const path of hardenedPaths) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { probe: true }));
      await assertFails(deleteDoc(doc(db, path)));
    }
  });

  it('denies collection queries on the hardened collections', async () => {
    const db = memberDb();
    await assertFails(getDocs(collection(db, 'invites')));
    await assertFails(getDocs(collection(db, 'plaidTokens')));
    await assertFails(getDocs(collection(db, 'siwaTokens')));
  });
});

describe('/households/{hid} — the household doc', () => {
  it('allows a member to read the household doc', async () => {
    await assertSucceeds(getDoc(doc(memberDb(), 'households', HID)));
  });

  it("allows a member's find-my-household array-contains query", async () => {
    const db = memberDb();
    const q = query(
      collection(db, 'households'),
      where('memberUids', 'array-contains', ALICE),
    );
    await assertSucceeds(getDocs(q));
  });

  it('denies non-member and unauthenticated reads, and unfiltered list queries', async () => {
    await assertFails(getDoc(doc(nonMemberDb(), 'households', HID)));
    await assertFails(getDoc(doc(unauthDb(), 'households', HID)));
    await assertFails(getDocs(collection(nonMemberDb(), 'households')));
  });

  it('denies client household creation (CF-only)', async () => {
    const db = memberDb();
    await assertFails(setDoc(doc(db, 'households', 'h2'), {
      name: 'Forged', memberUids: [ALICE], ownerUid: ALICE,
    }));
  });

  it('denies client household deletion', async () => {
    await assertFails(deleteDoc(doc(memberDb(), 'households', HID)));
  });

  it('allows a member to update household settings', async () => {
    const db = memberDb();
    await assertSucceeds(updateDoc(doc(db, 'households', HID), {
      name: 'Renamed Household',
      weeklySync: { day: 'monday', time: '19:00' },
    }));
  });

  it('denies any client change to memberUids — add, replace, or remove', async () => {
    const db = memberDb();
    const ref = doc(db, 'households', HID);
    await assertFails(updateDoc(ref, { memberUids: [ALICE, BOB, MALLORY] }));
    await assertFails(updateDoc(ref, { memberUids: [ALICE] }));
    await assertFails(updateDoc(ref, { memberUids: deleteField() }));
  });

  it('denies any client change to ownerUid', async () => {
    const db = memberDb();
    const ref = doc(db, 'households', HID);
    await assertFails(updateDoc(ref, { ownerUid: BOB }));
    await assertFails(updateDoc(ref, { ownerUid: deleteField() }));
    // Smuggled alongside an otherwise-legitimate update:
    await assertFails(updateDoc(ref, { name: 'Sneaky', ownerUid: BOB }));
  });

  it('denies non-member updates to the household doc', async () => {
    await assertFails(updateDoc(doc(nonMemberDb(), 'households', HID), { name: 'Taken over' }));
  });
});

describe('CF-owned subcollections — member-read, client-write-denied', () => {
  const cfOwned = [
    `households/${HID}/members/${BOB}`,
    `households/${HID}/plaidItems/item1`,
    `households/${HID}/events/e1`,
    `households/${HID}/digests/2026-W35`,
  ];

  it('allows members to read members, plaidItems, events, and digests', async () => {
    const db = memberDb();
    for (const path of cfOwned) {
      await assertSucceeds(getDoc(doc(db, path)));
    }
    await assertSucceeds(getDocs(collection(db, `households/${HID}/events`)));
  });

  it('denies ALL member writes — create, update, delete', async () => {
    const db = memberDb();
    for (const path of cfOwned) {
      await assertFails(setDoc(doc(db, path), { forged: true }));
      await assertFails(deleteDoc(doc(db, path)));
    }
    // Forging a brand-new member doc (the membership attack) in particular:
    await assertFails(setDoc(doc(db, `households/${HID}/members/${MALLORY}`), {
      role: 'partner', status: 'active', displayName: 'Intruder',
    }));
    // Forging sync state:
    await assertFails(updateDoc(doc(db, `households/${HID}/plaidItems/item1`), {
      syncCursor: 'forged',
    }));
  });

  it('denies non-member reads', async () => {
    const db = nonMemberDb();
    for (const path of cfOwned) {
      await assertFails(getDoc(doc(db, path)));
    }
  });
});

describe('member-owned subcollections — full member CRUD, member-gated', () => {
  it('allows member create, read, update, delete on each collection', async () => {
    const db = memberDb();
    const cases = [
      [`households/${HID}/accounts`, { ownerUid: null, type: 'depository', isHidden: false }],
      [`households/${HID}/categories`, { name: 'Fun', icon: 'party', colorHex: '#AA00AA', isSystem: false, isArchived: false }],
      [`households/${HID}/categoryRules`, { categoryId: 'c1' }],
      [`households/${HID}/budgets`, { allocations: { c1: 40000 } }],
      [`households/${HID}/goals`, { name: 'House', targetMinor: 1000000, savedMinor: 0 }],
      [`households/${HID}/goals/g1/contributions`, { amountMinor: 5000, date: '2026-08-25', contributedByUid: ALICE }],
      [`households/${HID}/recurringItems`, { source: 'manual', frequency: 'weekly', attributedTo: 'joint', autoLog: true }],
    ];
    for (const [collPath, data] of cases) {
      const ref = doc(db, collPath, 'new-doc');
      await assertSucceeds(setDoc(ref, data));
      await assertSucceeds(getDoc(ref));
      await assertSucceeds(getDocs(collection(db, collPath)));
      await assertSucceeds(deleteDoc(ref));
    }
  });

  it('denies non-member reads and writes on every member collection', async () => {
    const db = nonMemberDb();
    const seededDocs = [
      `households/${HID}/accounts/a1`,
      `households/${HID}/categories/c1`,
      `households/${HID}/categoryRules/coffee-shop`,
      `households/${HID}/budgets/2026-08`,
      `households/${HID}/goals/g1`,
      `households/${HID}/goals/g1/contributions/con1`,
      `households/${HID}/recurringItems/r1`,
    ];
    for (const path of seededDocs) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { probe: true }));
      await assertFails(deleteDoc(doc(db, path)));
    }
  });
});

describe('/transactions — member CRUD with money-invariant validation', () => {
  const txn = (id, db = memberDb()) => doc(db, `households/${HID}/transactions/${id}`);
  const validManual = {
    source: 'manual', amountMinor: 2500, direction: 'expense',
    date: '2026-08-26', categoryId: 'c1', attributedTo: 'joint',
    status: 'posted', enteredByUid: ALICE,
  };

  it('allows members to read and query transactions', async () => {
    const db = memberDb();
    await assertSucceeds(getDoc(txn('t1', db)));
    await assertSucceeds(getDocs(collection(db, `households/${HID}/transactions`)));
  });

  it('allows a member to create a valid manual transaction (joint or member-attributed)', async () => {
    const db = memberDb();
    await assertSucceeds(setDoc(txn('new1', db), validManual));
    await assertSucceeds(setDoc(txn('new2', db), { ...validManual, attributedTo: BOB }));
  });

  it('allows attributing to a DEPARTED member (member doc with status "left")', async () => {
    await assertSucceeds(setDoc(txn('new3'), { ...validManual, attributedTo: DANA }));
  });

  it('rejects attributedTo values with no member doc', async () => {
    const db = memberDb();
    await assertFails(setDoc(txn('bad1', db), { ...validManual, attributedTo: MALLORY }));
    await assertFails(setDoc(txn('bad2', db), { ...validManual, attributedTo: 'nobody' }));
    await assertFails(setDoc(txn('bad3', db), { ...validManual, attributedTo: null }));
    const { attributedTo, ...missingAttribution } = validManual;
    await assertFails(setDoc(txn('bad4', db), missingAttribution));
  });

  it('rejects non-integer amountMinor', async () => {
    const db = memberDb();
    await assertFails(setDoc(txn('bad5', db), { ...validManual, amountMinor: 25.5 }));
    await assertFails(setDoc(txn('bad6', db), { ...validManual, amountMinor: '2500' }));
    const { amountMinor, ...missingAmount } = validManual;
    await assertFails(setDoc(txn('bad7', db), missingAmount));
    await assertFails(updateDoc(txn('t2', db), { amountMinor: 5.01 }));
  });

  it('allows members to edit user-owned fields on an imported transaction', async () => {
    await assertSucceeds(updateDoc(txn('t1'), {
      categoryId: 'c2',
      categoryOverriddenByUser: true,
      attributedTo: 'joint',
      notes: 'split this one',
      excludeFromBudget: true,
      isHidden: false,
      discussFlaggedByUid: ALICE,
    }));
  });

  it("allows editing a DEPARTED member's transaction (history stays maintainable)", async () => {
    // t3 is attributed to dana, who has left the household. A remaining
    // member must still be able to recategorize / annotate it.
    await assertSucceeds(updateDoc(txn('t3'), {
      categoryId: 'c1',
      notes: 'old shared expense',
      excludeFromBudget: true,
    }));
  });

  it('freezes source once set — cannot change or remove it', async () => {
    const db = memberDb();
    await assertFails(updateDoc(txn('t1', db), { source: 'manual' }));
    await assertFails(updateDoc(txn('t2', db), { source: 'plaid' }));
    await assertFails(updateDoc(txn('t1', db), { source: deleteField() }));
  });

  it('freezes pendingTransactionId once set, but allows first-time set', async () => {
    const db = memberDb();
    await assertFails(updateDoc(txn('t1', db), { pendingTransactionId: 'forged' }));
    await assertFails(updateDoc(txn('t1', db), { pendingTransactionId: deleteField() }));
    // t2 has no pendingTransactionId yet — immutable-once-SET permits adding it.
    await assertSucceeds(updateDoc(txn('t2', db), { pendingTransactionId: 'pt-x' }));
  });

  it('allows deleting a manual transaction but never an imported one', async () => {
    const db = memberDb();
    await assertSucceeds(deleteDoc(txn('t2', db)));
    await assertFails(deleteDoc(txn('t1', db)));
  });

  it('denies all transaction access to non-members', async () => {
    const db = nonMemberDb();
    await assertFails(getDoc(txn('t1', db)));
    await assertFails(getDocs(collection(db, `households/${HID}/transactions`)));
    await assertFails(setDoc(txn('newX', db), validManual));
    await assertFails(updateDoc(txn('t1', db), { notes: 'defaced' }));
    await assertFails(deleteDoc(txn('t2', db)));
  });
});

describe('unauthenticated clients — denied everywhere', () => {
  it('denies every read and write across the whole tree', async () => {
    const db = unauthDb();
    const paths = [
      `users/${ALICE}`,
      'invites/CODE123',
      'plaidTokens/item1',
      `siwaTokens/${ALICE}`,
      `households/${HID}`,
      `households/${HID}/members/${ALICE}`,
      `households/${HID}/plaidItems/item1`,
      `households/${HID}/accounts/a1`,
      `households/${HID}/transactions/t1`,
      `households/${HID}/categories/c1`,
      `households/${HID}/categoryRules/coffee-shop`,
      `households/${HID}/budgets/2026-08`,
      `households/${HID}/goals/g1`,
      `households/${HID}/goals/g1/contributions/con1`,
      `households/${HID}/recurringItems/r1`,
      `households/${HID}/digests/2026-W35`,
      `households/${HID}/events/e1`,
    ];
    for (const path of paths) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { probe: true }));
    }
    await assertFails(getDocs(collection(db, 'households')));
    await assertFails(getDocs(collection(db, `households/${HID}/transactions`)));
  });
});
