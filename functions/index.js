const {onDocumentCreated, onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {logger} = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

/**
 * Trigger: users/{uid}/following/{targetUid} CREATED
 * - create mirror doc: users/{targetUid}/followers/{uid}
 * - increment counters:
 *   users/{uid}.followingCount += 1
 *   users/{targetUid}.followersCount += 1
 */
exports.onFollowingCreated = onDocumentCreated(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const {uid, targetUid} = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) {
        tx.set(followerRef, {
          uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      tx.set(sourceUserRef, {
        followingCount: admin.firestore.FieldValue.increment(1),
      }, {merge: true});
      tx.set(targetUserRef, {
        followersCount: admin.firestore.FieldValue.increment(1),
      }, {merge: true});
    });

    logger.info('Follow created', {uid, targetUid});
  },
);

/**
 * Trigger: users/{uid}/following/{targetUid} DELETED
 * - delete mirror doc: users/{targetUid}/followers/{uid}
 * - decrement counters (bounded to >=0)
 */
exports.onFollowingDeleted = onDocumentDeleted(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const {uid, targetUid} = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      tx.delete(followerRef);

      const sourceSnap = await tx.get(sourceUserRef);
      const targetSnap = await tx.get(targetUserRef);

      const currentFollowing = Number(sourceSnap.get('followingCount') || 0);
      const currentFollowers = Number(targetSnap.get('followersCount') || 0);

      tx.set(sourceUserRef, {
        followingCount: Math.max(0, currentFollowing - 1),
      }, {merge: true});
      tx.set(targetUserRef, {
        followersCount: Math.max(0, currentFollowers - 1),
      }, {merge: true});
    });

    logger.info('Follow removed', {uid, targetUid});
  },
);
