import React, { createContext, useContext, useState, useEffect } from 'react';
import { 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut, 
  onAuthStateChanged, 
  User as FirebaseUser 
} from 'firebase/auth';
import { doc, getDoc, getDocFromCache, setDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../infrastructure/firebase';
import { AdminUser, MadarRole } from '../domain/types';

interface AuthContextType {
  user: AdminUser | null;
  firebaseUser: FirebaseUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  loginWithEmail: (email: string, pass: string) => Promise<void>;
  registerAdminAccount: (email: string, pass: string, name: string) => Promise<void>;
  logout: () => Promise<void>;
  hasPermission: (permission: string) => boolean;
  clearError: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const ALLOWED_ADMIN_ROLES = [
  'admin',
  'super_admin',
  'main_admin',
  'limited_admin',
  'complaints_admin',
  'support',
  'auditor',
  'governorate_admin'
];

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [firebaseUser, setFirebaseUser] = useState<FirebaseUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentFbUser) => {
      setIsLoading(true);
      setError(null);

      if (!currentFbUser) {
        setUser(null);
        setFirebaseUser(null);
        setIsLoading(false);
        return;
      }

      setFirebaseUser(currentFbUser);

      try {
        // Fetch Admin profile from Firestore `users/{uid}`
        const userDocRef = doc(db, 'users', currentFbUser.uid);
        let userDocSnap;
        
        try {
          userDocSnap = await getDoc(userDocRef);
        } catch (fetchErr: any) {
          console.warn('Network getDoc failed, attempting cache fetch:', fetchErr.message);
          try {
            userDocSnap = await getDocFromCache(userDocRef);
          } catch (_) {
            console.error('Cache fetch also unavailable. Access denied (Fail-Closed).');
            setUser(null);
            setError('تعذر التحقق من صلاحيات المشرف بسبب انقطاع الاتصال بالخادم.');
            setIsLoading(false);
            return;
          }
        }

        if (!userDocSnap || !userDocSnap.exists()) {
          // Check if admin is in separate `admins` collection
          const adminDocRef = doc(db, 'admins', currentFbUser.uid);
          let adminDocSnap;
          try {
            adminDocSnap = await getDoc(adminDocRef);
          } catch (_) {
            try {
              adminDocSnap = await getDocFromCache(adminDocRef);
            } catch (_) {}
          }

          if (adminDocSnap && adminDocSnap.exists()) {
            const adminData = adminDocSnap.data();
            const adminRole = (adminData.role || '').toString().toLowerCase();
            if (!ALLOWED_ADMIN_ROLES.includes(adminRole)) {
              await firebaseSignOut(auth);
              setUser(null);
              setError('هذا الحساب ليس لديه دور إداري مصرح به.');
              setIsLoading(false);
              return;
            }
            setUser({
              uid: currentFbUser.uid,
              email: currentFbUser.email || '',
              name: adminData.name || adminData.username || 'مشرف النظام',
              role: adminRole as MadarRole,
              isApproved: adminData.isApproved !== false,
              permissions: adminData.permissions || ['*']
            });
            setIsLoading(false);
            return;
          }

          // Unauthorized account: Deny access strictly (Fail-Closed)
          console.warn('User has no admin record in Firestore. Access denied.');
          await firebaseSignOut(auth);
          setUser(null);
          setError('هذا الحساب غير مسجل كمشرف في النظام.');
          setIsLoading(false);
          return;
        }

        const data = userDocSnap.data();
        let role = (data.role || '').toString().toLowerCase();
        const isBanned = data.status === 'banned' || data.isBlocked === true;

        if (isBanned) {
          await firebaseSignOut(auth);
          setUser(null);
          setError('هذا الحساب تم إيقافه أو حظره من قبل الإدارة.');
          setIsLoading(false);
          return;
        }

        // Check fallback admins collection if user doc doesn't have an admin role
        if (!ALLOWED_ADMIN_ROLES.includes(role)) {
          try {
            const adminDocRef = doc(db, 'admins', currentFbUser.uid);
            const adminDocSnap = await getDoc(adminDocRef);
            if (adminDocSnap && adminDocSnap.exists()) {
              const adminData = adminDocSnap.data();
              const adminRole = (adminData.role || '').toString().toLowerCase();
              if (ALLOWED_ADMIN_ROLES.includes(adminRole)) {
                role = adminRole;
              }
            }
          } catch (_) {}
        }

        if (!ALLOWED_ADMIN_ROLES.includes(role)) {
          console.warn(`User role "${role}" is not in ALLOWED_ADMIN_ROLES. Access denied.`);
          await firebaseSignOut(auth);
          setUser(null);
          setError('هذا الحساب ليس لديه صلاحيات وصول للوحة الإدارة.');
          setIsLoading(false);
          return;
        }

        const effectiveRole = role;
        const permissions = Array.isArray(data.permissions) 
          ? data.permissions 
          : (effectiveRole === 'super_admin' || effectiveRole === 'main_admin' ? ['*'] : ['*']);

        setUser({
          uid: currentFbUser.uid,
          email: currentFbUser.email || data.email || '',
          name: data.name || data.username || data.fullName || 'مشرف مدار',
          role: effectiveRole as MadarRole,
          isApproved: data.isApproved !== false,
          permissions: permissions,
          phoneNumber: data.phoneNumber || data.phone
        });

      } catch (err: any) {
        console.error('Error verifying admin authorization:', err);
        // Fail-Closed: Never grant fallback super_admin
        setUser(null);
        setError('تعذر التحقق من صلاحيات الأدمن: ' + (err.message || 'خطأ في الاتصال'));
      } finally {
        setIsLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const loginWithEmail = async (email: string, pass: string) => {
    setIsLoading(true);
    setError(null);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), pass);
    } catch (err: any) {
      console.error('Firebase Login Error:', err);
      let friendlyMessage = 'فشل تسجيل الدخول. تأكد من صحة البريد الإلكتروني وكلمة المرور.';
      if (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
        friendlyMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      } else if (err.code === 'auth/too-many-requests') {
        friendlyMessage = 'تم تجاوز عدد محاولات الدخول المسموح بها. انتظر شوية... قليلاً والمحاولة مجدداً.';
      } else if (err.code === 'auth/network-request-failed') {
        friendlyMessage = 'ما قدرنا نتصل بالشبكة بخوادم Firebase. تحقق من اتصال الإنترنت.';
      }
      setError(friendlyMessage);
      setIsLoading(false);
      throw new Error(friendlyMessage);
    }
  };

  const registerAdminAccount = async (email: string, pass: string, name: string) => {
    setIsLoading(true);
    setError(null);
    try {
      let uid: string;
      try {
        const userCredential = await createUserWithEmailAndPassword(auth, email.trim(), pass);
        uid = userCredential.user.uid;
      } catch (createErr: any) {
        if (createErr.code === 'auth/email-already-in-use') {
          // If already registered in Auth, verify password by logging in
          const signCred = await signInWithEmailAndPassword(auth, email.trim(), pass);
          uid = signCred.user.uid;
        } else {
          throw createErr;
        }
      }

      // Create or update Admin Document in Firestore
      try {
        await setDoc(doc(db, 'users', uid), {
          uid,
          email: email.trim(),
          name: name.trim() || 'مشرف رئيسي (SuperAdmin)',
          role: 'super_admin',
          isApproved: true,
          status: 'active',
          permissions: ['*'],
          createdAt: serverTimestamp()
        }, { merge: true });
      } catch (fsErr) {
        console.warn('Direct users setDoc warning:', fsErr);
      }

      try {
        await setDoc(doc(db, 'admins', uid), {
          uid,
          email: email.trim(),
          name: name.trim() || 'مشرف رئيسي (SuperAdmin)',
          role: 'super_admin',
          isApproved: true,
          status: 'active',
          permissions: ['*']
        }, { merge: true });
      } catch (_) {}

      setUser({
        uid,
        email: email.trim(),
        name: name.trim() || 'مشرف رئيسي (SuperAdmin)',
        role: 'super_admin',
        isApproved: true,
        permissions: ['*']
      });

    } catch (err: any) {
      console.error('Firebase Register Admin Error:', err);
      let friendlyMessage = 'فشل إنشاء أو تهيئة حساب المشرف.';
      if (err.code === 'auth/email-already-in-use') {
        friendlyMessage = 'البريد مسجل بالفعل. تأكد من إدخال كلمة المرور الصحيحة لترقيته.';
      } else if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
        friendlyMessage = 'البريد مسجل بالفعل ولكن كلمة المرور المدخلة غير صحيحة.';
      } else if (err.code === 'auth/weak-password') {
        friendlyMessage = 'كلمة المرور ضعيفة. يرجى استخدام 6 خانات أو أكثر.';
      } else if (err.code === 'auth/invalid-email') {
        friendlyMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
      }
      setError(friendlyMessage);
      setIsLoading(false);
      throw new Error(friendlyMessage);
    }
  };

  const logout = async () => {
    setIsLoading(true);
    try {
      await firebaseSignOut(auth);
      setUser(null);
      setFirebaseUser(null);
    } catch (err) {
      console.error('Logout error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const hasPermission = (permission: string): boolean => {
    if (!user) return false;
    if (user.role === 'super_admin' || user.role === 'main_admin') return true;
    if (user.permissions.includes('*') || user.permissions.includes(permission)) return true;
    return false;
  };

  const clearError = () => setError(null);

  return (
    <AuthContext.Provider 
      value={{ 
        user, 
        firebaseUser, 
        isAuthenticated: !!user, 
        isLoading, 
        error, 
        loginWithEmail, 
        registerAdminAccount,
        logout, 
        hasPermission,
        clearError 
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
