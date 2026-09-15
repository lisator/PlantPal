import {initializeApp} from 'firebase/app';
import {getAnalytics} from 'firebase/analytics';
import {getFirestore} from 'firebase/firestore';
import {getAuth} from 'firebase/auth';


const firebaseConfig = {
    apiKey: "AIzaSyA-eXsXBTWz3ylyPk7ffyH5SW4FYPmNh44",
    authDomain: "plantpal-b6a3c.firebaseapp.com",
    projectId: "plantpal-b6a3c",
    storageBucket: "plantpal-b6a3c.firebasestorage.app",
    messagingSenderId: "683680706564",
    appId: "1:683680706564:web:46a517e2dde7bbb9218551",
    measurementId: "G-4PBKK3Y3J9"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);
const analytics = getAnalytics(app);