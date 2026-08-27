import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomBytes } from "node:crypto";
import {
  db,
  requireAuth,
  displayNameFor,
  appendEventInTransaction,
  HOUSEHOLD_MEMBER_CAP,
  PARTNER_COLOR_HEXES,
} from "./shared";

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days (PRD §4.1)

// 8 chars from a 32-symbol unambiguous alphabet = 40 bits of entropy
// (> the 32-bit floor). No 0/O/1/I lookalikes — the code is typed by hand.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;

export function generateInviteCode(): string {
  const bytes = randomBytes(CODE_LENGTH);
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i += 1) {
    code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return code;
}

/**
 * createInvite — PRD §4.1 flow 2.
 * Caller must be an active member of a non-full household. Rejects any
 * household containing a status "left" member — a new person must never
 * inherit a departed partner's financial history (PRD §4.1 edge cases).
 * Writes a single-use, high-entropy code with a 7-day expiry to
 * /invites/{code} and appends an inviteCreated event.
 */
export const createInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const firestore = db();

  const userSnap = await firestore.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.activeHouseholdId;
  if (typeof householdId !== "string" || householdId.length === 0) {
    throw new HttpsError("failed-precondition", "You are not in a household.");
  }

  const householdRef = firestore.collection("households").doc(householdId);
  const code = generateInviteCode();
  const inviteRef = firestore.collection("invites").doc(code);
  const expiresAt = Timestamp.fromMillis(Date.now() + INVITE_TTL_MS);

  await firestore.runTransaction(async (tx) => {
    const [householdSnap, membersSnap, inviteSnap] = await Promise.all([
      tx.get(householdRef),
      tx.get(householdRef.collection("members")),
      tx.get(inviteRef),
    ]);

    if (!householdSnap.exists) {
      throw new HttpsError("not-found", "Household not found.");
    }
    const memberUids: string[] = householdSnap.data()?.memberUids ?? [];
    if (!memberUids.includes(uid)) {
      throw new HttpsError("permission-denied", "You are not a member of this household.");
    }
    if (memberUids.length >= HOUSEHOLD_MEMBER_CAP) {
      throw new HttpsError("failed-precondition", "This household is already full.");
    }
    if (membersSnap.docs.some((doc) => doc.data().status === "left")) {
      throw new HttpsError(
        "failed-precondition",
        "This household has a departed member; invites are closed. Export and start a fresh household instead.",
      );
    }
    if (inviteSnap.exists) {
      // Astronomically unlikely code collision — ask the client to retry.
      throw new HttpsError("aborted", "Please try again.");
    }

    tx.create(inviteRef, {
      householdId,
      createdByUid: uid,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });

    appendEventInTransaction(firestore, tx, householdId, "inviteCreated", uid, {});
  });

  console.log(`[createInvite] Invite created for household ${householdId} by uid ${uid}`);
  return { code, expiresAt: expiresAt.toMillis() };
});

/**
 * redeemInvite(code) — PRD §4.1 flow 3.
 * One atomic transaction: validate (pending, unexpired, single-use,
 * household not full — hard cap 2) → add caller to memberUids, create their
 * member doc, mark the invite accepted, set both users' activeHouseholdId,
 * and append a memberJoined event.
 */
export const redeemInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const rawCode = request.data?.code;
  if (typeof rawCode !== "string" || rawCode.trim().length === 0) {
    throw new HttpsError("invalid-argument", "An invite code is required.");
  }
  const code = rawCode.trim().toUpperCase();
  const firestore = db();
  const inviteRef = firestore.collection("invites").doc(code);
  const userRef = firestore.collection("users").doc(uid);
  const memberDisplayName = displayNameFor(request, request.data?.displayName);

  const householdId = await firestore.runTransaction(async (tx) => {
    const [inviteSnap, userSnap] = await Promise.all([tx.get(inviteRef), tx.get(userRef)]);

    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "That invite code is not valid.");
    }
    const invite = inviteSnap.data() ?? {};
    if (invite.status !== "pending") {
      throw new HttpsError("failed-precondition", "That invite code has already been used or revoked.");
    }
    const expiresAt: Timestamp | undefined = invite.expiresAt;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "That invite code has expired.");
    }

    const existing = userSnap.data()?.activeHouseholdId;
    if (typeof existing === "string" && existing.length > 0) {
      throw new HttpsError("failed-precondition", "You already belong to a household.");
    }

    const hid: string = invite.householdId;
    const householdRef = firestore.collection("households").doc(hid);
    const householdSnap = await tx.get(householdRef);
    if (!householdSnap.exists) {
      throw new HttpsError("not-found", "The invite's household no longer exists.");
    }
    const memberUids: string[] = householdSnap.data()?.memberUids ?? [];
    if (memberUids.includes(uid)) {
      throw new HttpsError("failed-precondition", "You are already a member of this household.");
    }
    if (memberUids.length >= HOUSEHOLD_MEMBER_CAP) {
      throw new HttpsError("failed-precondition", "This household is already full.");
    }

    tx.update(householdRef, { memberUids: FieldValue.arrayUnion(uid) });

    tx.create(householdRef.collection("members").doc(uid), {
      role: "member",
      status: "active",
      displayName: memberDisplayName,
      colorHex: PARTNER_COLOR_HEXES[memberUids.length % PARTNER_COLOR_HEXES.length],
      joinedAt: FieldValue.serverTimestamp(),
    });

    tx.update(inviteRef, {
      status: "accepted",
      acceptedByUid: uid,
      acceptedAt: FieldValue.serverTimestamp(),
    });

    // Both users' activeHouseholdId points here (PRD §4.1 flow 3).
    tx.set(userRef, { activeHouseholdId: hid }, { merge: true });
    for (const existingUid of memberUids) {
      tx.set(
        firestore.collection("users").doc(existingUid),
        { activeHouseholdId: hid },
        { merge: true },
      );
    }

    appendEventInTransaction(firestore, tx, hid, "memberJoined", uid, {});

    return hid;
  });

  console.log(`[redeemInvite] uid ${uid} joined household ${householdId}`);
  return { householdId };
});
