// axis_saas/static/js/offline_student.js
// Offline student creation with IndexedDB sync

(function() {
    'use strict';

    const DB_NAME = 'AxisOfflineDB';
    const STORE_NAME = 'offlineStudents';
    const DB_VERSION = 1;

    let db = null;

    function openDB() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(DB_NAME, DB_VERSION);
            request.onupgradeneeded = (ev) => {
                const db = ev.target.result;
                if (!db.objectStoreNames.contains(STORE_NAME)) {
                    db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
                }
            };
            request.onsuccess = (ev) => resolve(ev.target.result);
            request.onerror = (ev) => reject(ev.target.error);
        });
    }

    async function getDB() {
        if (!db) db = await openDB();
        return db;
    }

    async function saveOfflineStudent(data) {
        const db = await getDB();
        return new Promise((resolve, reject) => {
            const tx = db.transaction(STORE_NAME, 'readwrite');
            const store = tx.objectStore(STORE_NAME);
            const request = store.add(data);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async function getOfflineStudents() {
        const db = await getDB();
        return new Promise((resolve, reject) => {
            const tx = db.transaction(STORE_NAME, 'readonly');
            const store = tx.objectStore(STORE_NAME);
            const request = store.getAll();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async function deleteOfflineStudent(id) {
        const db = await getDB();
        return new Promise((resolve, reject) => {
            const tx = db.transaction(STORE_NAME, 'readwrite');
            const store = tx.objectStore(STORE_NAME);
            const request = store.delete(id);
            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    // Sync function: send all offline students to server
    async function syncOfflineStudents() {
        if (!navigator.onLine) return;
        const students = await getOfflineStudents();
        if (students.length === 0) return;

        // Get schema from window variable or from URL
        let schema = window.AXIS_SCHEMA || '';
        if (!schema) {
            // Fallback: extract from URL path
            const pathParts = window.location.pathname.split('/');
            if (pathParts.length >= 3 && pathParts[1] === 'portal') {
                schema = pathParts[2];
            }
        }
        if (!schema) {
            console.warn('No tenant schema found, cannot sync');
            return;
        }

        for (const student of students) {
            try {
                const resp = await fetch(`/portal/${schema}/api/sync-offline-student/`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRFToken': getCsrfToken()
                    },
                    body: JSON.stringify(student.data)
                });
                if (resp.ok) {
                    await deleteOfflineStudent(student.id);
                    showToast('✅ Student synced: ' + student.data.name);
                } else {
                    const errorText = await resp.text();
                    console.error('Sync failed for student', student.data.name, errorText);
                }
            } catch (e) {
                console.error('Sync error:', e);
            }
        }
    }

    function getCsrfToken() {
        const cookie = document.cookie.split('; ').find(row => row.startsWith('csrftoken='));
        return cookie ? cookie.split('=')[1] : '';
    }

    // Toast notification (improved)
    function showToast(msg) {
        const existing = document.querySelector('.offline-toast');
        if (existing) existing.remove();

        const toast = document.createElement('div');
        toast.className = 'offline-toast';
        toast.style.cssText = `
            position: fixed;
            bottom: 100px;
            left: 50%;
            transform: translateX(-50%);
            background: #10b981;
            color: white;
            padding: 12px 24px;
            border-radius: 30px;
            font-weight: 600;
            z-index: 9999;
            box-shadow: 0 8px 24px rgba(0,0,0,0.2);
            animation: fadeInUp 0.4s ease;
            max-width: 90%;
            text-align: center;
            font-size: 0.95rem;
        `;
        toast.textContent = msg;
        document.body.appendChild(toast);
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 0.3s';
            setTimeout(() => toast.remove(), 400);
        }, 4000);
    }

    // Expose functions globally
    window.offlineStudent = {
        save: saveOfflineStudent,
        sync: syncOfflineStudents,
        getPending: getOfflineStudents
    };

    // Auto-sync when online
    window.addEventListener('online', () => {
        syncOfflineStudents();
    });

    // Also sync on page load if online
    document.addEventListener('DOMContentLoaded', () => {
        if (navigator.onLine) {
            setTimeout(syncOfflineStudents, 3000);
        }
    });

    // Check for pending students and show a badge (optional)
    async function showPendingBadge() {
        const students = await getOfflineStudents();
        if (students.length === 0) return;
        // You can add a UI indicator here if desired
        console.log(`[Offline] ${students.length} pending students to sync.`);
    }
    showPendingBadge();

})();
