/**
 * Default categories seeded at household creation (PRD §4.1, §6.3).
 * `pfcMappings` holds Plaid PFC primary codes so import categorization
 * can match on primary; detailed-code splits come later without migration.
 * Income and Transfers default to excludeFromBudget — ordinary income and
 * internal transfers never move spending rings (PRD §4.3, §4.4).
 */
export interface DefaultCategory {
  name: string;
  icon: string;
  pfcMappings: string[];
  excludeFromBudget: boolean;
  sortOrder: number;
}

export const DEFAULT_CATEGORIES: DefaultCategory[] = [
  { name: "Housing", icon: "🏠", pfcMappings: ["RENT_AND_UTILITIES"], excludeFromBudget: false, sortOrder: 0 },
  { name: "Groceries", icon: "🛒", pfcMappings: ["FOOD_AND_DRINK.FOOD_AND_DRINK_GROCERIES"], excludeFromBudget: false, sortOrder: 1 },
  { name: "Dining", icon: "🍽️", pfcMappings: ["FOOD_AND_DRINK"], excludeFromBudget: false, sortOrder: 2 },
  { name: "Transport", icon: "🚗", pfcMappings: ["TRANSPORTATION", "TRAVEL"], excludeFromBudget: false, sortOrder: 3 },
  { name: "Entertainment", icon: "🎬", pfcMappings: ["ENTERTAINMENT"], excludeFromBudget: false, sortOrder: 4 },
  { name: "Shopping", icon: "🛍️", pfcMappings: ["GENERAL_MERCHANDISE"], excludeFromBudget: false, sortOrder: 5 },
  { name: "Health", icon: "💊", pfcMappings: ["MEDICAL", "PERSONAL_CARE"], excludeFromBudget: false, sortOrder: 6 },
  { name: "Subscriptions", icon: "📱", pfcMappings: ["ENTERTAINMENT.ENTERTAINMENT_TV_AND_MOVIES"], excludeFromBudget: false, sortOrder: 7 },
  { name: "Income", icon: "💵", pfcMappings: ["INCOME"], excludeFromBudget: true, sortOrder: 8 },
  { name: "Transfers", icon: "🔁", pfcMappings: ["TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS"], excludeFromBudget: true, sortOrder: 9 },
  { name: "Other", icon: "✨", pfcMappings: [], excludeFromBudget: false, sortOrder: 10 },
];
