/**
 * Emulator test helpers. The suite runs against the auth + functions +
 * firestore emulators (see functions job in ci.yml / run-local.sh):
 * callables are invoked over the functions emulator's HTTP surface with a
 * real Auth-emulator idToken, and results are verified through the Admin
 * SDK pointed at the Firestore emulator.
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";
import { getAuth, Auth } from "firebase-admin/auth";

export const PROJECT_ID = "demo-twostep";

const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const FUNCTIONS_HOST = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

if (getApps().length === 0) {
  initializeApp({ projectId: PROJECT_ID });
}

export const adminDb: Firestore = getFirestore();
export const adminAuth: Auth = getAuth();

export interface TestUser {
  uid: string;
  idToken: string;
  email: string;
}

let userCounter = 0;

/** Creates a fresh user in the Auth emulator and returns a usable idToken. */
export async function signUpUser(displayName?: string): Promise<TestUser> {
  userCounter += 1;
  const email = `user${userCounter}-${Date.now()}@example.com`;
  const response = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: "test-password-123",
        displayName,
        returnSecureToken: true,
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`Auth emulator signUp failed: ${response.status} ${await response.text()}`);
  }
  const body = (await response.json()) as { localId: string; idToken: string };
  return { uid: body.localId, idToken: body.idToken, email };
}

export class CallableError extends Error {
  constructor(
    public readonly status: string,
    message: string,
  ) {
    super(message);
  }
}

/**
 * Invokes a callable function on the functions emulator using the callable
 * HTTP protocol. Throws CallableError (with the canonical status string,
 * e.g. "FAILED_PRECONDITION") on error responses.
 */
export async function callFunction<T = Record<string, unknown>>(
  name: string,
  data: Record<string, unknown>,
  idToken?: string,
): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (idToken) {
    headers.Authorization = `Bearer ${idToken}`;
  }
  const response = await fetch(
    `http://${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1/${name}`,
    { method: "POST", headers, body: JSON.stringify({ data }) },
  );
  const body = (await response.json()) as {
    result?: T;
    error?: { status?: string; message?: string };
  };
  if (!response.ok || body.error) {
    throw new CallableError(
      body.error?.status ?? `HTTP_${response.status}`,
      body.error?.message ?? "unknown error",
    );
  }
  return body.result as T;
}

export async function expectCallableError(
  promise: Promise<unknown>,
  expectedStatus: string,
): Promise<void> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof CallableError && error.status === expectedStatus) {
      return;
    }
    throw new Error(`Expected ${expectedStatus}, got: ${String(error)}`);
  }
  throw new Error(`Expected ${expectedStatus}, but the call succeeded`);
}

/** Wipes the Firestore and Auth emulators between tests. */
export async function clearEmulators(): Promise<void> {
  const firestoreResponse = await fetch(
    `http://${FIRESTORE_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  if (!firestoreResponse.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${firestoreResponse.status}`);
  }
  const authResponse = await fetch(
    `http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: "DELETE" },
  );
  if (!authResponse.ok) {
    throw new Error(`Failed to clear Auth emulator: ${authResponse.status}`);
  }
}

/** Convenience: sign up a user and create a household, returning both ids. */
export async function createUserWithHousehold(
  name = "Test Household",
): Promise<{ user: TestUser; householdId: string }> {
  const user = await signUpUser();
  const result = await callFunction<{ householdId: string }>(
    "createHousehold",
    { name },
    user.idToken,
  );
  return { user, householdId: result.householdId };
}

/** Convenience: full invite → redeem, returning the joined partner. */
export async function joinPartner(
  inviter: TestUser,
): Promise<{ partner: TestUser; code: string }> {
  const { code } = await callFunction<{ code: string }>("createInvite", {}, inviter.idToken);
  const partner = await signUpUser();
  await callFunction("redeemInvite", { code }, partner.idToken);
  return { partner, code };
}
