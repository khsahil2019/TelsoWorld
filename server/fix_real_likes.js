const db = require('./db');

async function fixRealLikes() {
  try {
    console.log('--- 🔧 Resetting video likes to real counts ---');
    const res = await db.pool.query(`
      UPDATE videos 
      SET likes_count = COALESCE(jsonb_array_length(liked_by), 0)
    `);
    console.log(`✅ Updated ${res.rowCount} videos to real likes count!`);

    const check = await db.pool.query('SELECT id, user_id, title, likes_count, jsonb_array_length(liked_by) as real_likes FROM videos ORDER BY id DESC LIMIT 10');
    console.table(check.rows);
  } catch (err) {
    console.error('Error fixing real likes:', err);
  } finally {
    process.exit(0);
  }
}

fixRealLikes();
