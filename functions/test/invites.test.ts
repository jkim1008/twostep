import { describe, it, expect, beforeEach } from "vitest";
import { Timestamp } from "firebase-admin/firestore";
import {
  adminDb,
  clearEmulators,
  signUpUser,
  callFunction,
  expectCallableError,
  createUserWithHousehold,
  joinPartner,
} from "./helpers";

describe("createInvite / redeemInvite", () => {
  beforeEach(clearEmulators);

  it("rejects unauthenticated calls", async () => {
    await expectCallableError(callFunction("createInvite", {}), "UNAUTHENTICATED");
    await expectCallableError(callFunction("redeemInvite", { code: "X" }), "UNAUTHENTICATED");
  });

  it("happy path: invite is created single-use with 7-day expiry, redeem joins the partner", async () => {
    const { user: owner, householdId } = await createUserWithHousehold();

    const { code } = await callFunction<{ code: string; expiresAt: number }>(
      "createInvite",
      {},
      owner.idToken,
    );
    expect(code.length).toBeGreaterThanOrEqual(8);

    const invite = (await adminDb.collection("invites").doc(code).get()).data();
    expect(invite?.status).toBe("pending");
    expect(invite?.householdId).toBe(householdId);
    const ttlMs = (invite?.expiresAt as Timestamp).toMillis() - Date.now();
    expect(ttlMs).toBeGreaterThan(6.9 * 24 * 60 * 60 * 1000);
    expect(ttlMs).toBeLessThanOrEqual(7 * 24 * 60 * 60 * 1000);

    const partner = await signUpUser();
    const result = await callFunction<{ householdId: string }>(
      "redeemInvite",
      { code },
      partner.idToken,
    );
    expect(result.householdId).toBe(householdId);

    const householdRef = adminDb.collection("households").doc(householdId);
    const household = (await householdRef.get()).data();
    expect(household?.memberUids).toHaveLength(2);
    expect(household?.memberUids).toContain(owner.uid);
    expect(household?.memberUids).toContain(partner.uid);
    expect(household?.ownerUid).toBe(owner.uid);

    const memberDoc = (await householdRef.collection("members").doc(partner.uid).get()).data();
    expect(memberDoc?.role).toBe("member");
    expect(memberDoc?.status).toBe("active");

    const acceptedInvite = (await adminDb.collection("invites").doc(code).get()).data();
    expect(acceptedInvite?.status).toBe("accepted");
    expect(acceptedInvite?.acceptedByUid).toBe(partner.uid);

    // Both users' activeHouseholdId points at the household.
    for (const uid of [owner.uid, partner.uid]) {
      const userDoc = (await adminDb.collection("users").doc(uid).get()).data();
      expect(userDoc?.activeHouseholdId).toBe(householdId);
    }

    const events = await householdRef.collection("events").get();
    const types = events.docs.map((d) => d.data().type).sort();
    expect(types).toEqual(["householdCreated", "inviteCreated", "memberJoined"]);
  });

  it("rejects an expired invite", async () => {
    const { user: owner } = await createUserWithHousehold();
    const { code } = await callFunction<{ code: string }>("createInvite", {}, owner.idToken);
    await adminDb
      .collection("invites")
      .doc(code)
      .update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });

    const partner = await signUpUser();
    await expectCallableError(
      callFunction("redeemInvite", { code }, partner.idToken),
      "FAILED_PRECONDITION",
    );
  });

  it("rejects reuse of an accepted invite (single-use)", async () => {
    const { user: owner } = await createUserWithHousehold();
    const { code } = await joinPartner(owner);

    const third = await signUpUser();
    await expectCallableError(
      callFunction("redeemInvite", { code }, third.idToken),
      "FAILED_PRECONDITION",
    );
  });

  it("rejects a pending invite when the household is already full (hard cap 2)", async () => {
    const { user: owner } = await createUserWithHousehold();
    // Two pending invites; the first fills the household, the second must die.
    const { code: firstCode } = await callFunction<{ code: string }>(
      "createInvite",
      {},
      owner.idToken,
    );
    const { code: secondCode } = await callFunction<{ code: string }>(
      "createInvite",
      {},
      owner.idToken,
    );
    const partner = await signUpUser();
    await callFunction("redeemInvite", { code: firstCode }, partner.idToken);

    const third = await signUpUser();
    await expectCallableError(
      callFunction("redeemInvite", { code: secondCode }, third.idToken),
      "FAILED_PRECONDITION",
    );
  });

  it("rejects createInvite on a full household", async () => {
    const { user: owner } = await createUserWithHousehold();
    await joinPartner(owner);
    await expectCallableError(callFunction("createInvite", {}, owner.idToken), "FAILED_PRECONDITION");
  });

  it("rejects createInvite when a member has left — no inheriting a departed partner's history", async () => {
    const { user: owner } = await createUserWithHousehold();
    const { partner } = await joinPartner(owner);
    await callFunction("leaveHousehold", {}, partner.idToken);

    await expectCallableError(callFunction("createInvite", {}, owner.idToken), "FAILED_PRECONDITION");
  });

  it("rejects an unknown code", async () => {
    const user = await signUpUser();
    await expectCallableError(
      callFunction("redeemInvite", { code: "NOSUCHCD" }, user.idToken),
      "NOT_FOUND",
    );
  });

  it("redeem is atomic: two users racing the same code produce exactly one member", async () => {
    const { user: owner, householdId } = await createUserWithHousehold();
    const { code } = await callFunction<{ code: string }>("createInvite", {}, owner.idToken);

    const [userA, userB] = await Promise.all([signUpUser(), signUpUser()]);
    const results = await Promise.allSettled([
      callFunction("redeemInvite", { code }, userA.idToken),
      callFunction("redeemInvite", { code }, userB.idToken),
    ]);

    const fulfilled = results.filter((r) => r.status === "fulfilled");
    expect(fulfilled).toHaveLength(1);

    const household = (
      await adminDb.collection("households").doc(householdId).get()
    ).data();
    expect(household?.memberUids).toHaveLength(2);

    const members = await adminDb
      .collection("households")
      .doc(householdId)
      .collection("members")
      .get();
    expect(members.size).toBe(2);
  });
});
