import { getFirestore, Firestore, Transaction, FieldValue } from "firebase-admin/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

/** Hard product cap: a household is exactly two people (PRD §4.1). */
export const HOUSEHOLD_MEMBER_CAP = 2;

/** Neutral partner badge colors, assigned in join order. */
export const PARTNER_COLOR_HEXES = ["#2F80ED", "#F2994A"];

export function db(): Firestore {
  if (getApps().length === 0) {
    initializeApp();
  }
  return getFirestore();
}

/** Returns the caller's uid or throws `unauthenticated`. */
export function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  return uid;
}

/** Best-effort display name snapshot for the member doc. */
export function displayNameFor(request: CallableRequest, provided?: unknown): string {
  if (typeof provided === "string" && provided.trim().length > 0) {
    return provided.trim().slice(0, 100);
  }
  const tokenName = request.auth?.token?.name;
  if (typeof tokenName === "string" && tokenName.trim().length > 0) {
    return tokenName.trim();
  }
  const email = request.auth?.token?.email;
  if (typeof email === "string" && email.includes("@")) {
    return email.split("@")[0];
  }
  return "Partner";
}

/**
 * Appends a household activity-feed event (PRD §6.2 — `/events` is the
 * notification mechanism of v1). Must be called with a transaction or
 * used standalone via `appendEvent`.
 */
export function appendEventInTransaction(
  firestore: Firestore,
  tx: Transaction,
  householdId: string,
  type: string,
  actorUid: string,
  payload: Record<string, unknown> = {},
): void {
  const eventRef = firestore
    .collection("households")
    .doc(householdId)
    .collection("events")
    .doc();
  tx.create(eventRef, {
    type,
    actorUid,
    timestamp: FieldValue.serverTimestamp(),
    payload,
  });
}
