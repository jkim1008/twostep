/**
 * Two Step Cloud Functions — household lifecycle (M1).
 * Membership and (later) Plaid tokens are only ever mutated here,
 * server-side; Firestore rules deny those writes to clients (PRD §6.4).
 */
export { createHousehold, leaveHousehold } from "./households";
export { createInvite, redeemInvite } from "./invites";
export { deleteAccount } from "./account";
