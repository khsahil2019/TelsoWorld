require('dotenv').config();
const db = require('../db');

async function syncRealStats() {
  await db.init();
  const pool = db.pool;

  console.log('Ensuring reel_permission column exists in users table...');
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS reel_permission TEXT DEFAULT 'auto'`);

  console.log('Syncing real comments count from comments table...');
  await pool.query(`
    UPDATE videos v
    SET comments_count = (
      SELECT COUNT(*)::int FROM comments c WHERE c.video_id = v.id
    )
  `);

  console.log('Syncing real likes count from liked_by array...');
  await pool.query(`
    UPDATE videos v
    SET likes_count = jsonb_array_length(
      CASE 
        WHEN jsonb_typeof(v.liked_by) = 'array' THEN v.liked_by 
        ELSE '[]'::jsonb 
      END
    )
  `);

  console.log('Syncing real view count from viewed_by array...');
  await pool.query(`
    UPDATE videos v
    SET view_count = jsonb_array_length(
      CASE 
        WHEN jsonb_typeof(v.viewed_by) = 'array' THEN v.viewed_by 
        ELSE '[]'::jsonb 
      END
    )
  `);

  const { rows } = await pool.query(`
    SELECT id, title, status, likes_count, view_count, comments_count 
    FROM videos 
    ORDER BY id DESC
  `);
  console.log('Real Stats across all videos:');
  console.table(rows);

  await pool.end();
  console.log('Database synced to 100% REAL DATA successfully!');
}

syncRealStats().catch(err => {
  console.error(err);
  process.exit(1);
});
