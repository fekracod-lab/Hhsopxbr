document.addEventListener('DOMContentLoaded', () => {
  // 1. Header scroll effect
  const header = document.querySelector('header');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }
  });

  // 2. Tab switching logic
  const tabBtns = document.querySelectorAll('.tab-btn');
  const appPanels = document.querySelectorAll('.app-panel');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      // Remove active classes
      tabBtns.forEach(b => b.classList.remove('active'));
      appPanels.forEach(p => p.classList.remove('active'));

      // Add active classes
      btn.classList.add('active');
      const targetPanel = document.getElementById(btn.dataset.target);
      if (targetPanel) {
        targetPanel.classList.add('active');
      }
    });
  });

  // 3. Simulated Mobile Notification cycle (Dynamic Arabic trip request simulation)
  const trips = [
    {
      pickup: "الجمارك - القائم",
      dropoff: "شارع الأطباء - الفلوجة",
      price: "120,000",
      distance: "210"
    },
    {
      pickup: "حي الفرات - القائم",
      dropoff: "مستشفى القائم العام",
      price: "5,000",
      distance: "3.5"
    },
    {
      pickup: "سوق القائم الكبير",
      dropoff: "منفذ حصيبة الحدودي",
      price: "12,000",
      distance: "8.2"
    },
    {
      pickup: "حي السلام - القائم",
      dropoff: "جامعة الأنبار - الرمادي",
      price: "95,000",
      distance: "185"
    }
  ];

  let currentTripIndex = 0;
  const alertSimBody = document.querySelector('.alert-sim-body');

  function updateSimulatedNotification() {
    if (!alertSimBody) return;
    
    // Add slide-out animation, then update content and slide-in
    const alertBox = document.querySelector('.alert-simulation');
    if (alertBox) {
      alertBox.style.animation = 'none';
      // Trigger reflow
      void alertBox.offsetWidth;
      
      const trip = trips[currentTripIndex];
      alertSimBody.innerHTML = `
        الاستلام: <span>${trip.pickup}</span><br>
        التوصيل: <span>${trip.dropoff}</span><br>
        الأجرة: <span>${trip.price} د.ع</span> | المسافة: <span>${trip.distance} كم</span>
      `;
      
      alertBox.style.animation = 'slide-up-alert 0.8s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards';
      
      // Update time to current hour
      const timeEl = document.querySelector('.alert-sim-time');
      if (timeEl) {
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        timeEl.textContent = `${hours}:${minutes}`;
      }
    }

    currentTripIndex = (currentTripIndex + 1) % trips.length;
  }

  // Initial call and periodic interval
  updateSimulatedNotification();
  setInterval(updateSimulatedNotification, 6000);
});
