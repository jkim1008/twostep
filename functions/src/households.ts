import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import {
  db,
  requireAuth,
  displayNameFor,
  appendEventInTransaction,
  PARTNER_COLOR_HEXES,
} from "./shared";
import { DEFAULT_CATEGORIES } from "./defaultCategories";

/**
 * createHousehold(name) — PRD §4.1 flow 1.
 * Atomically writes the household doc (memberUids=[caller], ownerUid=caller),
 * the caller's member doc (role owner, status active), the default category
 * set, and one household Cash account (ownerUid null, exempt from dedup),
 * then appends a householdCreated event and points the caller's
 * activeHouseholdId at the new household.
 */
export const createHousehold = onCall(async (request) => {
  const uid = requireAuth(request);
  const rawName = request.data?.name;
  if (typeof rawName !== "string" || rawName.trim().length === 0) {
    throw new HttpsError("invalid-argument", "A household name is required.");
  }
  const name = rawName.trim().slice(0, 100);
  const firestore = db();
  const householdRef = firestore.collection("households").doc();
  const userRef = firestore.collection("users").doc(uid);
  const memberDisplayName = displayNameFor(request, request.data?.displayName);

  await firestore.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const existing = userSnap.data()?.activeHouseholdId;
    if (typeof existing === "string" && existing.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        "You already belong to a household. Leave it before creating a new one.",
      );
    }

    tx.create(householdRef, {
      name,
      currencyCode: "USD",
      memberUids: [uid],
      ownerUid: uid,
      weeklySync: { day: "sunday", time: "19:00" },
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.create(householdRef.collection("members").doc(uid), {
      role: "owner",
      status: "active",
      displayName: memberDisplayName,
      colorHex: PARTNER_COLOR_HEXES[0],
      joinedAt: FieldValue.serverTimestamp(),
    });

    for (const category of DEFAULT_CATEGORIES) {
      tx.create(householdRef.collection("categories").doc(), {
        name: category.name,
        icon: category.icon,
        pfcMappings: category.pfcMappings,
        excludeFromBudget: category.excludeFromBudget,
        sortOrder: category.sortOrder,
        isSystem: true,
        isArchived: false,
      });
    }

    // The built-in Cash account: household-level (ownerUid null = joint),
    // the target of Quick Add manual entries, exempt from dedup (PRD §4.3).
    tx.create(householdRef.collection("accounts").doc(), {
      name: "Cash",
      type: "cash",
      ownerUid: null,
      isHidden: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(userRef, { activeHouseholdId: householdRef.id }, { merge: true });

    appendEventInTransaction(firestore, tx, householdRef.id, "householdCreated", uid, { name });
  });

  console.log(`[createHousehold] Created household ${householdRef.id} for uid ${uid}`);
  return { householdId: householdRef.id };
});

/**
 * leaveHousehold — PRD §4.1 flow 5. Unilateral, no approval required.
 * Removes the caller from memberUids, marks their member doc status "left"
 * (never deleted — attribution history keeps the snapshotted display name),
 * transfers ownership if the owner leaves while the partner remains, clears
 * the caller's activeHouseholdId, and appends a memberLeft event.
 */
export const leaveHousehold = onCall(async (request) => {
  const uid = requireAuth(request);
  const firestore = db();
  const householdId = await leaveHouseholdCore(firestore, uid);
  console.log(`[leaveHousehold] uid ${uid} left household ${householdId}`);
  return { householdId };
});

/**
 * Shared membership-exit transaction, reused verbatim by deleteAccount
 * (PRD §4.9: deletion cascades through leave semantics).
 * Returns the household id the caller left.
 */
export async function leaveHouseholdCore(
  firestore: FirebaseFirestore.Firestore,
  uid: string,
): Promise<string> {
  const userRef = firestore.collection("users").doc(uid);

  return firestore.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const householdId = userSnap.data()?.activeHouseholdId;
    if (typeof householdId !== "string" || householdId.length === 0) {
      throw new HttpsError("failed-precondition", "You are not in a household.");
    }

    const householdRef = firestore.collection("households").doc(householdId);
    const householdSnap = await tx.get(householdRef);
    if (!householdSnap.exists) {
      throw new HttpsError("not-found", "Household not found.");
    }
    const memberUids: string[] = householdSnap.data()?.memberUids ?? [];
    if (!memberUids.includes(uid)) {
      throw new HttpsError("permission-denied", "You are not a member of this household.");
    }

    const remaining = memberUids.filter((m) => m !== uid);
    const householdUpdate: Record<string, unknown> = {
      memberUids: FieldValue.arrayRemove(uid),
    };
    // Owner leaves while partner remains → ownership transfers (PRD §4.1).
    if (householdSnap.data()?.ownerUid === uid && remaining.length > 0) {
      householdUpdate.ownerUid = remaining[0];
    }
    tx.update(householdRef, householdUpdate);

    // Member docs are never hard-deleted (PRD §6.3) — history keeps the name.
    tx.update(householdRef.collection("members").doc(uid), {
      status: "left",
      leftAt: FieldValue.serverTimestamp(),
    });

    tx.set(userRef, { activeHouseholdId: FieldValue.delete() }, { merge: true });

    // TODO(M2 — Plaid): remove this partner's Plaid Items (`/item/remove`)
    // and delete their /plaidTokens entries. Requires the Plaid client and
    // token plumbing that lands with the M2 link/sync module (PRD §4.2).

    appendEventInTransaction(firestore, tx, householdId, "memberLeft", uid, {
      remainingMemberCount: remaining.length,
    });

    return householdId;
  });
}
