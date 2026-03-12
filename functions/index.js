const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers every time a new emergencyBanner is added to the database.
 * Sends a push notification to users subscribed to the 'emergencies' topic.
 */
exports.notifyNewEmergencyBanner = functions.firestore
    .document("emergencyBanners/{bannerId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        if (!data) return null;

        const bloodType = data.bloodType || "Blood";
        const location = data.location || "Nearby";
        const name = data.name || "A patient";

        // Construct the message payload
        const message = {
            notification: {
                title: `🚨 URGENT: ${bloodType} Blood Needed!`,
                body: `${name} urgently needs ${bloodType} blood at ${location}. Tap to help.`,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                id: context.params.bannerId,
                type: "emergency",
            },
            android: {
                notification: {
                    channelId: "emergency_channel",
                    priority: "high",
                    color: "#E53935",
                },
            },
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: `🚨 URGENT: ${bloodType} Blood Needed!`,
                            body: `${name} urgently needs ${bloodType} blood at ${location}. Tap to help.`,
                        },
                        sound: "default",
                        badge: 1,
                    },
                },
            },
            topic: "emergencies",
        };

        try {
            const response = await admin.messaging().send(message);
            console.log("✅ Successfully sent emergency notification:", response);
            return response;
        } catch (error) {
            console.error("❌ Error sending notification:", error);
            return null;
        }
    });

/**
 * Triggers every time a new bloodRequest is added to the database.
 * This covers general blood requests.
 */
exports.notifyNewBloodRequest = functions.firestore
    .document("bloodRequests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        if (!data) return null;

        const bloodType = data.bloodGroup || "Blood";
        const hospital = data.hospital || "a nearby hospital";

        const message = {
            notification: {
                title: `New Blood Request: ${bloodType}`,
                body: `${bloodType} blood is needed at ${hospital}. Open the app for details.`,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                id: context.params.requestId,
                type: "request",
            },
            android: {
                notification: {
                    channelId: "fcm_channel",
                    priority: "high",
                },
            },
            topic: "emergencies",
        };

        try {
            const response = await admin.messaging().send(message);
            console.log("✅ Successfully sent request notification:", response);
            return response;
        } catch (error) {
            console.error("❌ Error sending notification:", error);
            return null;
        }
    });
