import { initializeApp, getApps } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { 
  initializeFirestore, 
  persistentLocalCache, 
  persistentMultipleTabManager 
} from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

// Production Firebase Configuration matching MADAR Core
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSyDmIrIXEKy1hmvkgDtAAws95fFnIrWVeZs",
  authDomain: "dala-alqaim.firebaseapp.com",
  projectId: "dala-alqaim",
  storageBucket: "dala-alqaim.firebasestorage.app",
  messagingSenderId: "656705978860",
  appId: "1:656705978860:web:0000000000000000d280c9"
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];

export const auth = getAuth(app);

// High-resilience Firestore instance with automatic Long-Polling fallback and multi-tab cache
export const db = initializeFirestore(app, {
  experimentalAutoDetectLongPolling: true,
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager()
  })
});

export const storage = getStorage(app);
export default app;

