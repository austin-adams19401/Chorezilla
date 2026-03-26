# Chorezilla Beta Testing Instructions

Thanks for helping test Chorezilla! This guide walks you through the main features. As you test, please note any bugs, confusing behavior, or crashes you encounter.

**How to report issues:** Screenshot the problem and note what you were doing when it happened. Include your device model and OS version.

---

## 1. Account Setup & Onboarding

### Create an Account
1. Open the app
2. Tap **Register**
3. Sign up with email/password OR use **Sign in with Google**
4. Verify you land on the family setup screen

### Set Up Your Family
1. Enter a family name
2. Add at least one kid (name and birthdate)
3. Set a **Parent PIN** (you'll use this to switch between parent and kid modes)
4. Complete the onboarding checklist and confirm you reach the Parent Dashboard

**Things to check:**
- [ ] Can you add multiple kids?
- [ ] Does the PIN setup work smoothly?
- [ ] Does the onboarding checklist track your progress correctly?

---

## 2. Parent Dashboard

You should see 5 tabs along the bottom: **Today, Chores, Rewards, History, Notifications**.

### Today Tab
- [ ] Does it show today's assignments for each kid?
- [ ] Can you see a summary/stats area?

### Notifications Tab
- [ ] Do notifications appear when kids complete chores?

---

## 3. Chore Management (Parent)

### Create a Chore
1. Go to the **Chores** tab
2. Tap the button to add a new chore
3. Fill in: title, difficulty (1-5), category (cleaning, laundry, dishes, trash, pet care, other)
4. Optionally toggle "Requires Approval" on
5. Save the chore

**Things to check:**
- [ ] Does the chore appear in your list?
- [ ] Can you edit the chore after creating it?
- [ ] Can you delete a chore?

### Schedule & Assign Chores
1. Open a chore and set a recurring schedule (daily, weekly, etc.)
2. Assign it to one or more kids
3. Check the **Today** tab to confirm the assignment shows up

**Things to check:**
- [ ] Do scheduled chores generate assignments on the correct days?
- [ ] Can you assign the same chore to multiple kids?
- [ ] Can you create a one-time (non-recurring) assignment?

### Built-in Chores
- [ ] Are there starter/default chores available to pick from?

---

## 4. Kid View

### Switch to Kid Mode
1. From the Parent Dashboard, tap the kid selector or navigate to the kid view
2. Select a kid profile

**Things to check:**
- [ ] Does the kid's dashboard show their assigned chores?
- [ ] Can you see the kid's XP, level, and coin balance?

### Complete a Chore
1. Find an assigned chore on the kid's dashboard
2. Tap to mark it as complete
3. If the chore requires approval, try submitting a photo or note as proof
4. Check that the chore moves to a "pending" or "completed" state

**Things to check:**
- [ ] Does the completion flow work without crashing?
- [ ] Can you attach a photo as proof?
- [ ] Does the status update immediately?

---

## 5. Approval Workflow (Parent)

1. Switch back to Parent mode (you'll need your PIN)
2. Check for pending approvals (review queue)
3. Open a completed assignment that requires approval
4. **Approve** it and verify the kid gets XP and coins
5. Try **rejecting** one and verify it goes back to assigned

**Things to check:**
- [ ] Does the PIN unlock work reliably?
- [ ] Do XP and coins update correctly after approval?
- [ ] Does rejecting send the chore back properly?

---

## 6. Reward Store

### Create Rewards (Parent)
1. Go to the **Rewards** tab
2. Add a new reward with: title, coin cost, category (snack, screen time, experience, digital, money, toy, other)
3. Optionally set stock limits or require approval
4. Save

**Things to check:**
- [ ] Does the reward appear in the store?
- [ ] Can you edit and delete rewards?

### Purchase Rewards (Kid)
1. Switch to kid view
2. Go to the rewards/shop page
3. Try purchasing a reward with enough coins
4. Try purchasing one you can't afford

**Things to check:**
- [ ] Does the purchase deduct coins correctly?
- [ ] Are out-of-stock items handled?
- [ ] Does a "requires approval" reward show as pending?

### Fulfill Rewards (Parent)
1. Switch to parent view
2. Check for pending reward redemptions
3. Approve or deny the redemption

---

## 7. Gamification

### XP & Leveling
- [ ] Do kids earn XP when chores are completed/approved?
- [ ] Does the level progress bar update?
- [ ] Does leveling up trigger any celebration or notification?

### Badges
1. Go to the kid's badges page
2. Check that badge progress is visible (e.g., "Complete 10 chores" progress bar)
3. Complete enough chores to earn a badge and confirm it unlocks

**Things to check:**
- [ ] Are streak badges tracking correctly (1, 3, 7, 15, 30 day streaks)?
- [ ] Can kids feature/display up to 3 badges on their profile?

### Cosmetics & Loot Boxes
- [ ] Can kids view their cosmetic items (backgrounds, skins, frames, titles)?
- [ ] Do loot boxes open with the 3-click reveal mechanic?
- [ ] Are duplicate items handled (coin refund)?

### Edit Kid Profile
1. From kid view, go to edit profile
2. Try changing the avatar or equipping cosmetics
3. Save and confirm changes persist

---

## 8. Family Settings (Parent)

### Coin Economy
1. Go to Settings > Coin Economy
2. Adjust the XP-to-coin conversion rate
3. Verify the change affects future coin earnings

### Away Mode
1. Go to a kid's settings/profile
2. Mark them as "away" (vacation, at other parent's house, etc.)
3. Confirm they're excluded from daily chore assignments while away

### Level Rewards
1. Go to Settings > Level Rewards
2. Check if you can customize what kids earn at each level milestone

---

## 9. Multi-Device & Join Codes

### Kid Join Code
1. From parent settings, find the family invite/join code
2. On a second device, open the app and choose "Join Family" as a kid
3. Enter the join code
4. Verify the kid appears in the family on the parent's device

### Parent Join Code
1. Try the same flow for a second parent joining the family
2. Verify the second parent has full access to the dashboard

**Things to check:**
- [ ] Do changes sync in real-time across devices?
- [ ] Do push notifications work on both devices?

---

## 10. Edge Cases to Try

- [ ] Create a kid with a very long name - does the UI handle it?
- [ ] Set difficulty to each level (1-5) and confirm point values make sense
- [ ] Kill the app mid-action and reopen - does state recover?
- [ ] Turn off internet, try to complete a chore, then reconnect
- [ ] Rapidly tap buttons - does anything break?
- [ ] Try the app in both portrait and landscape orientation
- [ ] Test on both Android and iOS if possible

---

## 11. General Quality

- [ ] Is the text readable and free of typos?
- [ ] Do animations play smoothly?
- [ ] Are loading states shown when data is being fetched?
- [ ] Does the app feel responsive or are there noticeable delays?
- [ ] Is navigation intuitive - can you find everything without help?

---

## Quick Reference: Test Account Setup

For the fastest testing path:
1. Register a new account
2. Create a family with 2-3 kids
3. Set your parent PIN
4. Add 3-4 chores with different difficulties and categories
5. Schedule at least one recurring chore
6. Add 2-3 rewards at different price points
7. Switch to kid view and work through the chore completion flow
8. Switch back to parent view and approve/reject
9. Purchase a reward as a kid

Thank you for testing!
