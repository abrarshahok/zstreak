import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

/**
 * Deletes the caller's account (spec Section 5) — invoked by the
 * "Delete Account" button in Settings (Stage 10). Firestore data is
 * removed first, then the Auth record, in that order: deleting Auth
 * first would leave an orphaned Firestore subtree with no way to
 * re-authenticate and clean it up if this function failed partway.
 * A client-side recursive delete can't be trusted to finish if the
 * connection drops mid-deletion, which is why this runs server-side.
 */
export const deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in to delete an account.");
  }

  const db = getFirestore();
  await db.recursiveDelete(db.collection("users").doc(uid));
  await getAuth().deleteUser(uid);

  return { success: true };
});
