import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

initializeApp();
const db = getFirestore();

/**
 * Trigger: users/{uid}/following/{targetUid} CREATED
 * - create mirror doc: users/{targetUid}/followers/{uid}
 * - increment counters:
 *   users/{uid}.followingCount += 1
 *   users/{targetUid}.followersCount += 1
 */
export const onFollowingCreated = onDocumentCreated(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);
      if (followerSnap.exists) {
        return;
      }

      tx.set(followerRef, {
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(sourceUserRef, {
        followingCount: FieldValue.increment(1),
      }, { merge: true });
      tx.set(targetUserRef, {
        followersCount: FieldValue.increment(1),
      }, { merge: true });
    });

    logger.info('Follow created', { uid, targetUid });
  },
);

/**
 * Trigger: users/{uid}/following/{targetUid} DELETED
 * - delete mirror doc: users/{targetUid}/followers/{uid}
 * - decrement counters
 */
export const onFollowingDeleted = onDocumentDeleted(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) {
        return;
      }

      tx.delete(followerRef);
      tx.set(sourceUserRef, {
        followingCount: FieldValue.increment(-1),
      }, { merge: true });
      tx.set(targetUserRef, {
        followersCount: FieldValue.increment(-1),
      }, { merge: true });
    });

    logger.info('Follow removed', { uid, targetUid });
  },
);

/**
 * Trigger: users/{uid}/likedProjects/{projectId} CREATED
 * - create mirror doc: projects/{projectId}/likes/{uid}
 * - increment projects/{projectId}.likesCount
 */
export const onProjectLikedCreated = onDocumentCreated(
  'users/{uid}/likedProjects/{projectId}',
  async (event) => {
    const { uid, projectId } = event.params;
    if (!uid || !projectId) return;

    const projectRef = db.collection('projects').doc(projectId);
    const projectLikeRef = projectRef.collection('likes').doc(uid);

    await db.runTransaction(async (tx) => {
      const projectLikeSnap = await tx.get(projectLikeRef);
      if (projectLikeSnap.exists) {
        return;
      }

      tx.set(projectLikeRef, {
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(projectRef, {
        likesCount: FieldValue.increment(1),
      }, { merge: true });
    });

    logger.info('Project liked', { uid, projectId });
  },
);

/**
 * Trigger: users/{uid}/likedProjects/{projectId} DELETED
 * - delete mirror doc: projects/{projectId}/likes/{uid}
 * - decrement projects/{projectId}.likesCount
 */
export const onProjectLikedDeleted = onDocumentDeleted(
  'users/{uid}/likedProjects/{projectId}',
  async (event) => {
    const { uid, projectId } = event.params;
    if (!uid || !projectId) return;

    const projectRef = db.collection('projects').doc(projectId);
    const projectLikeRef = projectRef.collection('likes').doc(uid);

    await db.runTransaction(async (tx) => {
      const projectLikeSnap = await tx.get(projectLikeRef);
      if (!projectLikeSnap.exists) {
        return;
      }

      tx.delete(projectLikeRef);
      tx.set(projectRef, {
        likesCount: FieldValue.increment(-1),
      }, { merge: true });
    });

    logger.info('Project unliked', { uid, projectId });
  },
);
