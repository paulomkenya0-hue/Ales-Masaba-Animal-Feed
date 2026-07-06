/**
 * reset-password.js
 * ---------------------------------------------------------------------
 * SCRIPT YA DHARURA - Kubadilisha Password ya Mtumiaji YEYOTE (Super Admin
 * au Cashier) BILA kuhitaji password ya zamani.
 *
 * KWA NINI INAHITAJIKA:
 * App ya Flutter (upande wa simu) haiwezi kubadilisha password ya mtumiaji
 * mwingine bila kujua password yake ya sasa - hii ni sheria ya usalama ya
 * Firebase Auth. Njia pekee ya "kulazimisha" (force) mabadiliko ni kutumia
 * "Firebase Admin SDK" (uwezo wa server/mwenye mradi), ambao script hii
 * inautumia.
 *
 * MASHARTI:
 *  - Node.js iwe imesakinishwa kwenye kompyuta yako (pakua: nodejs.org)
 *  - Uwe MMILIKI wa Firebase project hii (ndiyo maana yake "Firebase ni
 *    zangu" - unaweza kupata "Service Account Key")
 *
 * HATUA (fanya mara moja):
 *  1) Nenda Firebase Console -> Project Settings (gia) -> Service Accounts
 *  2) Bonyeza "Generate New Private Key" -> pakua faili la .json
 *  3) Liite jina "serviceAccountKey.json" na uliweke KATIKA FOLDA HII HII
 *     (admin-tools/) - USILIPELEKE GitHub kamwe (ni siri kubwa!)
 *  4) Fungua terminal kwenye folda hii, andika: npm install firebase-admin
 *  5) Badilisha USERNAME_TO_RESET na NEW_PASSWORD hapa chini
 *  6) Andika: node reset-password.js
 *
 * USALAMA: Baada ya kutumia, futa faili la serviceAccountKey.json kutoka
 * mahali popote lisilo salama, na usimshirikishe mtu yeyote.
 * ---------------------------------------------------------------------
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// === BADILISHA HAPA ===
const USERNAME_TO_RESET = "jina_la_mtumiaji"; // mf. "admin" au "cashier1" - BILA @ales-masaba.app
const NEW_PASSWORD = "NenosiriJipya123";       // angalau herufi 6
// =======================

const EMAIL_DOMAIN = "ales-masaba.app"; // sanjari na FirebaseService.usernameToEmail() kwenye app

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function resetPassword() {
  const email = `${USERNAME_TO_RESET.trim().toLowerCase()}@${EMAIL_DOMAIN}`;

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: NEW_PASSWORD });

    console.log("======================================");
    console.log("FANIKIWA! Password imebadilishwa.");
    console.log("Username:", USERNAME_TO_RESET);
    console.log("Password Mpya:", NEW_PASSWORD);
    console.log("UID:", user.uid);
    console.log("======================================");
    console.log("Sasa unaweza kuingia kwenye app kwa taarifa hizi mpya.");
  } catch (error) {
    console.error("HITILAFU:", error.message);
    if (error.code === "auth/user-not-found") {
      console.error(
        `Hakuna mtumiaji mwenye email "${email}". Hakikisha USERNAME_TO_RESET ni sahihi ` +
        `(bila herufi kubwa, bila nafasi) - ndivyo ilivyohifadhiwa awali.`
      );
    }
  }

  process.exit(0);
}

resetPassword();
