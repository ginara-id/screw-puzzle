const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// 1. Initialize Firebase Admin
// Make sure serviceAccountKey.json is in the same folder as this script
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 2. Define Paths
const levelsDir = path.join(__dirname, './data/levels');
const collectionName = 'levels';

async function uploadLevels() {
  console.log('🚀 Starting Level Upload to Firestore...');

  try {
    // Read all files in the levels directory
    const files = fs.readdirSync(levelsDir);
    const jsonFiles = files.filter(file => file.endsWith('.json'));

    if (jsonFiles.length === 0) {
      console.log('❌ No JSON files found in assets/levels/');
      return;
    }

    console.log(`📂 Found ${jsonFiles.length} levels to upload.`);

    for (const file of jsonFiles) {
      const filePath = path.join(levelsDir, file);
      const fileData = fs.readFileSync(filePath, 'utf8');

      try {
        const jsonData = JSON.parse(fileData);

        // Extract level number from filename (e.g., level_10.json -> level_10)
        const docId = path.basename(file, '.json');

        console.log(`📤 Uploading ${docId}...`);

        // Upload to Firestore
        await db.collection(collectionName).doc(docId).set(jsonData);

        console.log(`✅ ${docId} uploaded successfully!`);
      } catch (parseError) {
        console.error(`❌ Error parsing ${file}:`, parseError.message);
      }
    }

    console.log('\n✨ All levels have been processed!');
  } catch (error) {
    console.error('💥 Critical Error:', error.message);
  } finally {
    process.exit();
  }
}

// Run the uploader
uploadLevels();
