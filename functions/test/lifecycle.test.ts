import { describe, it, expect, beforeEach } from "vitest";
import {
  adminDb,
  adminAuth,
  clearEmulators,
  signUpUser,
  callFunction,
  expectCallableError,
  createUserWithHousehold,
  joinPartner,
} from "./helpers";

describe("leaveHousehold", () => {
  beforeEach(clearEmulators);

  it("rejects unauthenticated calls and non-members", async () => {
    await expectCallableError(callFunction("leaveHousehold", {}), "UNAUTHENTICATED");
    const loner = await signUpUser();
    await expectCallableError(
      callFunction("leaveHousehold", {}, loner.idToken),
      "FAILED_PRECONDITION",
    );
  });

  it("owner leaving transfers ownership to the remaining partner; member doc becomes left, never deleted", async () => {
    const { user: owner, householdId } = await createUserWithHousehold();
    const { partner } = await joinPartner(owner);

    await callFunction("leaveHousehold", {}, owner.idToken);

    const householdRef = adminDb.collection("households").doc(householdId);
    const household = (await householdRef.get()).data();
    expect(household?.memberUids).toEqual([partner.uid]);
    expect(household?.ownerUid).toBe(partner.uid);

    const ownerMember = (await householdRef.collection("members").doc(owner.uid).get()).data();
    expect(ownerMember?.status).toBe("left");
    expect(ownerMember?.displayName).toBeDefined(); // attribution history keeps the name

    const ownerUserDoc = (await adminDb.collection("users").doc(owner.uid).get()).data();
    expect(ownerUserDoc?.activeHouseholdId).toBeUndefined();

    const partnerUserDoc = (await adminDb.collection("users").doc(partner.uid).get()).data();
    expect(partnerUserDoc?.activeHouseholdId).toBe(householdId);

    const events = await householdRef.collection("events").get();
    expect(events.docs.map((d) => d.data().type)).toContain("memberLeft");
  });
});

describe("deleteAccount", () => {
  beforeEach(clearEmulators);

  it("rejects unauthenticated calls", async () => {
    await expectCallableError(callFunction("deleteAccount", {}), "UNAUTHENTICATED");
  });

  it("non-last member: cascades leave semantics, deletes user doc and Auth user, household survives", async () => {
    const { user: owner, householdId } = await createUserWithHousehold();
    const { partner } = await joinPartner(owner);

    await callFunction("deleteAccount", {}, partner.idToken);

    const householdRef = adminDb.collection("households").doc(householdId);
    const household = (await householdRef.get()).data();
    expect(household?.memberUids).toEqual([owner.uid]);
    expect(household?.ownerUid).toBe(owner.uid);

    // Member doc is never hard-deleted — attribution history survives.
    const partnerMember = (await householdRef.collection("members").doc(partner.uid).get()).data();
    expect(partnerMember?.status).toBe("left");

    // Household data is untouched.
    const categories = await householdRef.collection("categories").get();
    expect(categories.size).toBe(11);

    // User doc and Auth user are gone.
    expect((await adminDb.collection("users").doc(partner.uid).get()).exists).toBe(false);
    await expect(adminAuth.getUser(partner.uid)).rejects.toThrow();

    // The remaining partner's account is intact.
    await expect(adminAuth.getUser(owner.uid)).resolves.toBeDefined();
  });

  it("last member: deletes the entire household subtree, user doc, and Auth user", async () => {
    const { user: owner, householdId } = await createUserWithHousehold();

    await callFunction("deleteAccount", {}, owner.idToken);

    const householdRef = adminDb.collection("households").doc(householdId);
    expect((await householdRef.get()).exists).toBe(false);
    for (const sub of ["members", "categories", "accounts", "events"]) {
      const snapshot = await householdRef.collection(sub).get();
      expect(snapshot.size, `subcollection ${sub}`).toBe(0);
    }

    expect((await adminDb.collection("users").doc(owner.uid).get()).exists).toBe(false);
    await expect(adminAuth.getUser(owner.uid)).rejects.toThrow();
  });

  it("works for a user who is not in any household", async () => {
    const loner = await signUpUser();
    await callFunction("deleteAccount", {}, loner.idToken);
    await expect(adminAuth.getUser(loner.uid)).rejects.toThrow();
  });
});
