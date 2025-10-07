importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

// TODO: Replace with values from firebase_options.dart or your Firebase console.
firebase.initializeApp({
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title ?? 'NMS oznámení';
  const notificationOptions = {
    body: payload.notification?.body,
    data: payload.data,
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
