export const DEMO_CREDENTIALS = {
    email: 'demo@uthm.edu.my',
    password: 'demo123' // Password mudah untuk demo
};

export const isDemoMode = () => {
    if (typeof window === 'undefined') return false;
    try {
        return localStorage.getItem('is_demo_mode') === 'true';
    } catch (e) {
        console.warn('localStorage access blocked:', e);
        return false;
    }
};

export const setDemoMode = (enabled: boolean) => {
    if (typeof window === 'undefined') return;
    try {
        if (enabled) {
            localStorage.setItem('is_demo_mode', 'true');
            // Set fake auth token to satisfy simple checks
            localStorage.setItem('sb-access-token', 'demo-token'); 
        } else {
            localStorage.removeItem('is_demo_mode');
            localStorage.removeItem('sb-access-token');
        }
    } catch (e) {
        console.warn('localStorage access blocked:', e);
    }
};

// Helper to block actions in demo mode
export const guardAction = (message = 'This action is disabled in Demo Mode') => {
    if (isDemoMode()) {
        alert(`🔒 DEMO MODE: ${message}`);
        return true; // Return true meaning "blocked"
    }
    return false; // Return false meaning "proceed"
};
