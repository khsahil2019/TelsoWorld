const db = require('../db');

async function main() {
  console.log('--- Setting up 5-Level Referral Chain ---');
  // User 8 (Root: rahul, code: TELSO8135)
  // User 9 (Level 1: sahil_khan, code: TELSO9158, referred_by: TELSO8135)
  // User 10 (Level 2: sahil, code: SAHIL01, referred_by: TELSO9158)
  // User 11 (Level 3: adil, code: ADIL01, referred_by: SAHIL01)
  // User 12 (Level 4: kaif, code: KAIF01, referred_by: ADIL01)
  // User 13 (Level 5: arshi, code: ARSHI01, referred_by: KAIF01)

  await db.pool.query("UPDATE users SET referred_by = 'TELSO8135' WHERE id = 9");
  await db.pool.query("UPDATE users SET referred_by = 'TELSO9158' WHERE id = 10");
  await db.pool.query("UPDATE users SET referred_by = 'SAHIL01' WHERE id = 11");
  await db.pool.query("UPDATE users SET referred_by = 'ADIL01' WHERE id = 12");
  await db.pool.query("UPDATE users SET referred_by = 'KAIF01' WHERE id = 13");

  // Mark video 37 as 'ads'
  await db.pool.query("UPDATE videos SET video_type = 'ads' WHERE id = 37");
  console.log('Chain configured: 9 -> 10 -> 11 -> 12 -> 13 under Root (8)');

  // Let User 13 (Level 5: arshi) like Ad Reel 37
  // This simulates the exact scenario from the infographic!
  console.log('\n--- Simulating User 13 (Level 5) liking Ad Reel 37 ---');
  await db.pool.query("UPDATE videos SET earned_like_users = '[]'::jsonb WHERE id = 37");
  // Remove 13 from liked_by so they can like fresh
  const { rows: vRows } = await db.pool.query("SELECT liked_by FROM videos WHERE id = 37");
  const likedBy = (vRows[0].liked_by || []).filter(id => id != 13);
  await db.pool.query("UPDATE videos SET liked_by = $1::jsonb WHERE id = 37", [JSON.stringify(likedBy)]);

  const likeRes = await db.toggleVideoLike(37, 13);
  console.log('toggleVideoLike Result:', JSON.stringify(likeRes, null, 2));

  // Now inspect referral network of User 8 (Root)
  console.log('\n--- Inspecting Referral Network for Root User 8 ---');
  const net8 = await db.getReferralNetwork(8, 'telsoworld.com');
  console.log('Total Referrals for User 8:', net8.total_referrals);
  console.log('Total Earnings for User 8:', net8.total_earnings);
  console.log('Levels Summary:', JSON.stringify(net8.levels, null, 2));
  console.log('Members:', JSON.stringify(net8.members, null, 2));

  // Check wallets of all users in chain:
  const { rows: wRows } = await db.pool.query("SELECT user_id, balance FROM wallets WHERE user_id IN (8, 9, 10, 11, 12, 13) ORDER BY user_id ASC");
  console.log('\n--- Wallets of Users in Chain ---');
  console.table(wRows);

  process.exit(0);
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
