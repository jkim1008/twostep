import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { db } from "./shared";
import { requireAuth } from "./shared";
import { leaveHouseholdCore } from "./households";

/**
 * deleteAccount — PRD §4.9 (App Store Guideline 5.1.1(v), built early).
 * Cascade: leaveHousehold semantics (member doc becomes status "left",
 * never deleted — attribution history survives), then delete /users/{uid},
 * then delete the Firebase Auth user. If the caller was the last remaining
 * member, the entire household subtree is deleted — one partner can never
 * nuke the other's records (PRD §4.1 R23).
 */
export const deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request);
  const firestore = db();

  // 1. Membership exit (if in a household) — identical to leaveHousehold.
  let householdId: string | null = null;
  try {
    householdId = await leaveHouseholdCore(firestore, uid);
  } catch (error) {
    if (error instanceof HttpsError && error.code === "failed-precondition") {
      // Not in a household — nothing to leave; continue the cascade.
      householdId = null;
    } else {
      throw error;
    }
  }

  // TODO(M2 — Plaid): remove ALL of this user's Plaid Items (`/item/remove`)
  // and delete their /plaidTokens entries before their data disappears.
  // Lands with the M2 link/sync module (PRD §4.2, §4.9).

  // TODO(M2 — Sign in with Apple): revoke the stored SiWA refresh token via
  // Apple's REST API (services key in Secret Manager) and delete
  // /siwaTokens/{uid}. Groundwork is captured at sign-in by exchangeSiwaCode
  // (PRD §4.9); the revocation call lands with that module.

  // 2. Last member out → delete the household subtree (PRD §4.9: household
  //    deletion is only available to the last remaining member).
  if (householdId) {
    const householdRef = firestore.collection("households").doc(householdId);
    const householdSnap = await householdRef.get();
    const memberUids: string[] = householdSnap.data()?.memberUids ?? [];
    if (householdSnap.exists && memberUids.length === 0) {
      console.log(`[deleteAccount] uid ${uid} was the last member — deleting household ${householdId}`);
      await firestore.recursiveDelete(householdRef);
    }
  }

  // 3. Delete the user profile doc.
  await firestore.collection("users").doc(uid).delete();

  // 4. Delete the Firebase Auth user last, so a mid-cascade failure leaves
  //    the account able to retry.
  await getAuth().deleteUser(uid);

  console.log(`[deleteAccount] Deleted account for uid ${uid}`);
  return { deleted: true };
});
