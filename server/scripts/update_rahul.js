require('dotenv').config();
const db = require('../db');

async function updateRahul() {
  await db.init();
  const pool = db.pool;

  console.log('Updating user 8 (rahul)...');
  await pool.query(
    "UPDATE users SET profile_image = '/uploads/videos/1795249573891-137765854.jpg' WHERE id = 8"
  );

  console.log('Updating video 33...');
  await pool.query(
    "UPDATE videos SET thumbnail_url = '/uploads/videos/1795249573891-137765854.jpg', image = '/uploads/videos/1795249573891-137765854.jpg', photo_url = '/uploads/videos/1795249573891-137765854.jpg', media_type = 'photo' WHERE id = 33"
  );

  console.log('Refreshing stories for user 8...');
  await pool.query('DELETE FROM stories WHERE user_id = 8');
  await pool.query(
    `INSERT INTO stories (user_id, username, name, profile_image, media_url, media_type, caption, views_count, viewed_by, created_at, expires_at)
     VALUES (8, 'rahul', 'rahul', '/uploads/videos/1795249573891-137765854.jpg', '/uploads/videos/1795249573891-137765854.jpg', 'image', 'Rahul live performance ✨', 1, '[]'::jsonb, NOW(), NOW() + INTERVAL '24 hours')`
  );

  const u = await pool.query('SELECT id, username, name, profile_image FROM users WHERE id = 8');
  const v = await pool.query('SELECT id, user_id, title, media_type, video_url, thumbnail_url FROM videos WHERE id = 33');
  const s = await pool.query('SELECT id, user_id, username, media_url, expires_at FROM stories WHERE user_id = 8');

  console.log('USER:', JSON.stringify(u.rows[0]));
  console.log('VIDEO:', JSON.stringify(v.rows[0]));
  console.log('STORY:', JSON.stringify(s.rows[0]));

  await pool.end();
  console.log('Done!');
}

updateRahul().catch(err => {
  console.error(err);
  process.exit(1);
});
