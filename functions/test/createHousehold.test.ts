import { describe, it, expect, beforeEach } from "vitest";
import {
  adminDb,
  clearEmulators,
  signUpUser,
  callFunction,
  expectCallableError,
  createUserWithHousehold,
} from "./helpers";

describe("createHousehold", () => {
  beforeEach(clearEmulators);

  it("rejects unauthenticated calls", async () => {
    await expectCallableError(
      callFunction("createHousehold", { name: "Nope" }),
      "UNAUTHENTICATED",
    );
  });

  it("rejects a missing name", async () => {
    const user = await signUpUser();
    await expectCallableError(
      callFunction("createHousehold", {}, user.idToken),
      "INVALID_ARGUMENT",
    );
  });

  it("seeds the household atomically: doc, owner member, categories, Cash account, event", async () => {
    const user = await signUpUser();
    const { householdId } = await callFunction<{ householdId: string }>(
      "createHousehold",
      { name: "Our Household", displayName: "Alex" },
      user.idToken,
    );

    const householdRef = adminDb.collection("households").doc(householdId);
    const household = (await householdRef.get()).data();
    expect(household?.name).toBe("Our Household");
    expect(household?.memberUids).toEqual([user.uid]);
    expect(household?.ownerUid).toBe(user.uid);
    expect(household?.currencyCode).toBe("USD");
    expect(household?.weeklySync).toEqual({ day: "sunday", time: "19:00" });

    const member = (await householdRef.collection("members").doc(user.uid).get()).data();
    expect(member?.role).toBe("owner");
    expect(member?.status).toBe("active");
    expect(member?.displayName).toBe("Alex");
    expect(typeof member?.colorHex).toBe("string");

    const categories = await householdRef.collection("categories").get();
    const byName = new Map(categories.docs.map((d) => [d.data().name as string, d.data()]));
    expect(categories.size).toBe(11);
    const expected: Array<[string, string]> = [
      ["Housing", "🏠"],
      ["Groceries", "🛒"],
      ["Dining", "🍽️"],
      ["Transport", "🚗"],
      ["Entertainment", "🎬"],
      ["Shopping", "🛍️"],
      ["Health", "💊"],
      ["Subscriptions", "📱"],
      ["Income", "💵"],
      ["Transfers", "🔁"],
      ["Other", "✨"],
    ];
    for (const [name, icon] of expected) {
      const category = byName.get(name);
      expect(category, `category ${name}`).toBeDefined();
      expect(category?.icon).toBe(icon);
      expect(category?.isSystem).toBe(true);
      expect(category?.isArchived).toBe(false);
    }
    // Income and Transfers never move spending rings by default.
    expect(byName.get("Income")?.excludeFromBudget).toBe(true);
    expect(byName.get("Transfers")?.excludeFromBudget).toBe(true);
    expect(byName.get("Groceries")?.excludeFromBudget).toBe(false);

    const accounts = await householdRef.collection("accounts").get();
    expect(accounts.size).toBe(1);
    const cash = accounts.docs[0].data();
    expect(cash.type).toBe("cash");
    expect(cash.ownerUid).toBeNull();

    const events = await householdRef.collection("events").get();
    expect(events.docs.map((d) => d.data().type)).toEqual(["householdCreated"]);
    expect(events.docs[0].data().actorUid).toBe(user.uid);

    const userDoc = (await adminDb.collection("users").doc(user.uid).get()).data();
    expect(userDoc?.activeHouseholdId).toBe(householdId);
  });

  it("rejects creating a second household while already in one", async () => {
    const { user } = await createUserWithHousehold();
    await expectCallableError(
      callFunction("createHousehold", { name: "Second" }, user.idToken),
      "FAILED_PRECONDITION",
    );
  });
});
