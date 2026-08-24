import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";

initializeApp();

/**
 * Maintains a running per-user document count for a collection that
 * firestore.rules caps on create (habits/categories) — rules can't count
 * sibling documents on their own, so this is the counter rules reads.
 * `.set(..., {merge: true})` so it works even before `/users/{uid}` itself
 * has ever been written (see firestore.rules' isActive() comment on that
 * same edge case).
 */
function countTrigger(collectionPath: string, field: string) {
  return {
    onCreated: onDocumentCreated(collectionPath, async (event) => {
      const uid = event.params.uid;
      await getFirestore()
        .collection("users")
        .doc(uid)
        .set({ [field]: FieldValue.increment(1) }, { merge: true });
    }),
    onDeleted: onDocumentDeleted(collectionPath, async (event) => {
      const uid = event.params.uid;
      await getFirestore()
        .collection("users")
        .doc(uid)
        .set({ [field]: FieldValue.increment(-1) }, { merge: true });
    }),
  };
}

const habitCounters = countTrigger("users/{uid}/habits/{habitId}", "habitCount");
export const onHabitCreated = habitCounters.onCreated;
export const onHabitDeleted = habitCounters.onDeleted;

const categoryCounters = countTrigger(
  "users/{uid}/categories/{categoryId}",
  "categoryCount",
);
export const onCategoryCreated = categoryCounters.onCreated;
export const onCategoryDeleted = categoryCounters.onDeleted;
